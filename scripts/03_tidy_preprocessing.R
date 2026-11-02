%%R
# ==============================================================================
# SCRIPT 03 (OPTIMIZED & DETERMINISTIC): PARALLEL INGESTION & NLP CLEANING (R)
# ==============================================================================

library(tidyverse)
library(jsonlite)
library(tidytext)
library(textstem)
library(lexicon)
library(stm)

use_parallel <- requireNamespace("furrr", quietly = TRUE) && requireNamespace("future", quietly = TRUE)
if (use_parallel) {
  library(future)
  library(furrr)
  plan(multisession, workers = max(1, parallel::detectCores() - 1))
  cat("Multi-core CPU acceleration ENABLED with", nbrOfWorkers(), "workers.\n")
}

# 1. Verify Workspace
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (!dir.exists(safe_workspace)) {
  stop("SECURITY HALT: Workspace directory does not exist. Ensure Google Drive is mounted.")
}
if (getwd() != safe_workspace) setwd(safe_workspace)
cat("Operating inside R workspace:", getwd(), "\n")

# 2. Fault-Tolerant Line-by-Line JSONL Ingestion
cat("Reading raw JSONL archive with fault tolerance...\n")
raw_lines <- read_lines("apwa_parsed_archive.jsonl")

safe_json_parse <- safely(function(x) {
  parsed <- fromJSON(x, simplifyVector = TRUE)
  tibble(
    url        = parsed$url %||% NA_character_,
    slug       = parsed$slug %||% NA_character_,
    transcript = parsed$transcript %||% NA_character_,
    date_raw   = parsed$metadata[["Date"]] %||% NA_character_
  )
})

if (use_parallel) {
  parsed_results <- future_map(raw_lines, safe_json_parse)
} else {
  parsed_results <- map(raw_lines, safe_json_parse)
}

failed_lines <- which(!map_lgl(parsed_results, ~ is.null(.x$error)))
if (length(failed_lines) > 0) {
  cat("Bypassed corrupted JSON records on line(s):", paste(failed_lines, collapse = ", "), "\n")
}

# CRITICAL REPRODUCIBILITY LOCK: arrange(slug) ensures identical document/vocab
# indexing regardless of concurrent HTTP completion order in Script 02.
raw_df <- parsed_results %>%
  map("result") %>%
  compact() %>%
  bind_rows() %>%
  distinct(slug, .keep_all = TRUE) %>%
  arrange(slug)

cat("Successfully loaded", nrow(raw_df), "valid transcribed documents.\n")

# 3. Temporal Normalization
clean_data <- raw_df %>%
  mutate(
    clean_year = as.integer(str_extract(date_raw, "\\b(19|20)\\d{2}\\b"))
  ) %>%
  filter(
    !is.na(clean_year),
    clean_year >= 1965,
    clean_year <= 2026,
    !is.na(transcript),
    str_squish(transcript) != ""
  ) %>%
  select(slug, url, clean_year, date_raw, transcript)

cat("Dropped", nrow(raw_df) - nrow(clean_data), "document(s) missing a verifiable 4-digit year (1965-2026).\n")
cat("Temporally normalized corpus size:", nrow(clean_data), "documents.\n")

# 4. Expanded Domain-Specific Stop-Word Lexicon
custom_stops <- tibble(
  word = c(
    "prison", "inmate", "prisoner", "cell", "guard", "officer", "c.o.", "co",
    "apwa", "criminal", "crime", "life", "time", "like", "know", "get",
    "people", "day", "year", "way", "tell", "guy", "john", "johns",
    "hopkins", "university"
  )
)

all_stops_vec <- unique(c(stop_words$word, custom_stops$word))

# 5. Domain-Guarded Lemmatization Dictionary (Protects Carceral-Digital & Legal Nouns)
protected_overrides <- tribble(
  ~token,        ~lemma,
  "jpay",        "jpay",
  "corrlinks",   "corrlinks",
  "corrlink",    "corrlinks",
  "securus",     "securus",
  "gtl",         "gtl",
  "kiosk",       "kiosk",
  "kiosks",      "kiosk",
  "tablet",      "tablet",
  "tablets",     "tablet",
  "cope",        "cope",
  "copes",       "cope",
  "coped",       "cope",
  "coping",      "coping",
  "cop",         "cop",
  "cops",        "cop",
  "wound",       "wound",
  "wounds",      "wound",
  "wounded",     "wound",
  "left",        "left",
  "grounds",     "grounds",
  "hearing",     "hearing",
  "hearings",    "hearing",
  "ruling",      "ruling",
  "rulings",     "ruling",
  "proceeding",  "proceeding",
  "proceedings", "proceeding",
  "finding",     "finding",
  "findings",    "finding",
  "housing",     "housing",
  "programming", "programming",
  "training",    "training",
  "building",    "building",
  "buildings",   "building",
  "beating",     "beating",
  "beatings",    "beating",
  "shooting",    "shooting",
  "shootings",   "shooting",
  "killing",     "killing",
  "killings",    "killing",
  "feeling",     "feeling",
  "feelings",    "feeling",
  "suffering",   "suffering",
  "writing",     "writing",
  "writings",    "writing"
)

apwa_lemma_dict <- as_tibble(lexicon::hash_lemmas) %>%
  rename(token = token, lemma = lemma) %>%
  mutate(
    token = tolower(token),
    lemma = tolower(lemma)
  ) %>%
  distinct(token, .keep_all = TRUE) %>%
  anti_join(protected_overrides, by = "token") %>%
  bind_rows(protected_overrides)

# 6. High-Speed Vectorized NLP Pipeline
cat("Executing high-speed Tidytext tokenization and unique-type lemmatization...\n")

raw_tokens <- clean_data %>%
  select(slug, transcript) %>%
  mutate(transcript_norm = str_replace_all(transcript, "[\u2018\u2019\u02BC`]", "'")) %>%
  select(-transcript) %>%
  unnest_tokens(output = raw_word, input = transcript_norm, token = "words", to_lower = TRUE)

vocab_lookup <- raw_tokens %>%
  distinct(raw_word) %>%
  filter(!(raw_word %in% stop_words$word)) %>%
  mutate(word = str_remove_all(raw_word, "'s$|'$")) %>%
  filter(str_detect(word, "^[a-z]{3,}$")) %>%
  filter(!(word %in% all_stops_vec)) %>%
  left_join(apwa_lemma_dict, by = c("word" = "token")) %>%
  mutate(lemma = coalesce(lemma, word)) %>%
  filter(
    str_detect(lemma, "^[a-z]{3,}$"),
    !(lemma %in% all_stops_vec)
  ) %>%
  select(raw_word, lemma)

cleaned_corpus <- raw_tokens %>%
  inner_join(vocab_lookup, by = "raw_word") %>%
  group_by(slug) %>%
  summarize(cleaned_text = str_c(lemma, collapse = " "), .groups = "drop") %>%
  inner_join(clean_data, by = "slug") %>%
  arrange(slug) %>%
  select(slug, url, clean_year, date_raw, transcript, cleaned_text)

rm(raw_tokens, vocab_lookup)
gc(verbose = FALSE)

# 7. Build the Synchronized STM Mathematical Matrix ('out')
cat("Constructing STM document-term matrix and pruning hapax legomena...\n")

processed <- textProcessor(
  documents         = cleaned_corpus$cleaned_text,
  metadata          = as.data.frame(cleaned_corpus),
  lowercase         = FALSE,
  removestopwords   = FALSE,
  removenumbers     = FALSE,
  removepunctuation = FALSE,
  stem              = FALSE,
  wordLengths       = c(3, Inf)
)

out <- prepDocuments(
  documents    = processed$documents,
  vocab        = processed$vocab,
  meta         = processed$meta,
  lower.thresh = 1
)

# 8. Enforce Strict 1:1 Row Alignment After prepDocuments() Pruning
cleaned_corpus <- as_tibble(out$meta) %>%
  select(slug, url, clean_year, date_raw, transcript, cleaned_text)

cat(
  "Final synchronized STM corpus:",
  length(out$documents), "documents and",
  length(out$vocab), "unique vocabulary terms.\n"
)

# 9. Serialize Cleaned Data & STM Input Object to Disk
saveRDS(cleaned_corpus, file = "apwa_clean_corpus.rds", compress = FALSE)
saveRDS(out, file = "apwa_stm_out_object.rds", compress = FALSE)

cat("\n[TASK 03 COMPLETE] Saved 1:1 aligned 'apwa_clean_corpus.rds' and 'apwa_stm_out_object.rds'.\n")
