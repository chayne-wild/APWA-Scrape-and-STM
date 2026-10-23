%%R
# ==============================================================================
# SCRIPT 03: TIDYVERSE DATA INGESTION, TEMPORAL NORMALIZATION, & NLP CLEANING (R)
# Task: Ingest 'apwa_parsed_archive.jsonl' natively in R with fault tolerance,
#       normalize 'clean_year', execute Tidyverse NLP cleaning (tokenization,
#       lemmatization, and the "Plural Bypass" expanded stop-word filter), and
#       export the synchronized STM mathematical matrix ('out').
# ==============================================================================

library(tidyverse)
library(jsonlite)
library(tidytext)
library(textstem)
library(stm)

# 1. Verify Workspace
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)
cat("Operating inside R workspace:", getwd(), "\n")

# 2. Fault-Tolerant Line-by-Line JSONL Ingestion in R
# Rationale: Native stream_in() halts if a single line has a partial network write
# (such as line 2,650). Using read_lines() + purrr::safely() isolates and skips
# any corrupted JSON packet while keeping the pipeline 100% inside R/Tidyverse.
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

parsed_results <- map(raw_lines, safe_json_parse)

# Log any skipped corrupted lines
failed_lines <- which(!map_lgl(parsed_results, ~ is.null(.x$error)))
if (length(failed_lines) > 0) {
  cat("Bypassed corrupted JSON records on line(s):", paste(failed_lines, collapse = ", "), "\n")
}

raw_df <- parsed_results %>%
  map("result") %>%
  compact() %>%
  bind_rows() %>%
  distinct(slug, .keep_all = TRUE)

cat("Successfully loaded", nrow(raw_df), "valid transcribed documents.\n")

# 3. Temporal Normalization (Extracting 4-Digit Authorship Year)
# Rationale: STM prevalence regression requires a clean numeric year covariate.
clean_data <- raw_df %>%
  mutate(
    clean_year = as.integer(str_extract(date_raw, "\\b(19|20)\\d{2}\\b"))
  ) %>%
  filter(!is.na(clean_year), !is.na(transcript), str_squish(transcript) != "") %>%
  select(slug, url, clean_year, date_raw, transcript)

cat("Dropped", nrow(raw_df) - nrow(clean_data), "document(s) missing a verifiable 4-digit year.\n")
cat("Temporally normalized corpus size:", nrow(clean_data), "documents.\n")

# 4. Expanded Domain-Specific Stop-Word Lexicon
# Rationale: High-entropy domain words ('prison', 'inmate') and conversational
# filler ('time', 'like', 'know') cause severe cross-topic contamination and
# degrade FREX exclusivity if not aggressively pruned.
custom_stops <- tibble(
  word = c(
    "prison", "inmate", "prisoner", "cell", "guard", "officer", "c.o.", "co",
    "apwa", "criminal", "crime", "life", "time", "like", "know", "get",
    "people", "day", "year", "way", "tell", "guy", "john", "hopkins", "university"
  )
)

# 5. Tidyverse NLP Pipeline & The "Plural Bypass" Fix
# Rationale: Evaluating tokens against the stop-word list both BEFORE and AFTER
# lemmatization ensures pluralized domain noise (e.g., "prisoners" -> "prisoner",
# "inmates" -> "inmate") cannot bypass the filter.
cat("Executing Tidytext tokenization, lemmatization, and Plural Bypass filtering...\n")

cleaned_corpus <- clean_data %>%
  # Step 5A: Tokenize into lowercase words, stripping punctuation
  unnest_tokens(output = word, input = transcript, token = "words", to_lower = TRUE) %>%
  # Step 5B: Keep strictly alphabetic tokens of at least 3 characters
  filter(str_detect(word, "^[a-z]{3,}$")) %>%
  # Step 5C: Pre-lemmatization stop-word removal (Standard + Custom)
  anti_join(stop_words, by = "word") %>%
  anti_join(custom_stops, by = "word") %>%
  # Step 5D: Lemmatize words to base morphological root via textstem
  mutate(lemma = tolower(lemmatize_words(word))) %>%
  # Step 5E: THE PLURAL BYPASS FIX (Post-lemmatization stop-word & length filter)
  filter(str_detect(lemma, "^[a-z]{3,}$")) %>%
  anti_join(stop_words, by = c("lemma" = "word")) %>%
  anti_join(custom_stops, by = c("lemma" = "word")) %>%
  # Step 5F: Re-aggregate cleaned lemmas per document while preserving metadata order
  group_by(slug) %>%
  summarize(cleaned_text = str_c(lemma, collapse = " "), .groups = "drop") %>%
  inner_join(clean_data, by = "slug") %>%
  select(slug, url, clean_year, date_raw, transcript, cleaned_text)

# 6. Build the Synchronized STM Mathematical Matrix ('out')
# Rationale: Passing our Tidy-cleaned text into textProcessor (with default R
# cleaning disabled) and prepDocuments() removes hapax legomena (single-use terms)
# and guarantees 1:1 row alignment between out$documents, out$meta, and raw transcripts.
cat("Constructing STM document-term matrix and pruning hapax legomena...\n")

processed <- textProcessor(
  documents         = cleaned_corpus$cleaned_text,
  metadata          = as.data.frame(cleaned_corpus),
  lowercase         = FALSE, # Handled in Tidyverse
  removestopwords   = FALSE, # Handled in Tidyverse
  removenumbers     = FALSE, # Handled in Tidyverse
  removepunctuation = FALSE, # Handled in Tidyverse
  stem              = FALSE, # Preserves textstem lemmatization
  wordLengths       = c(3, Inf)
)

# lower.thresh = 1 purges words appearing in only 1 document across the archive
out <- prepDocuments(
  documents    = processed$documents,
  vocab        = processed$vocab,
  meta         = processed$meta,
  lower.thresh = 1
)

# 7. Serialize Cleaned Data & STM Input Object to Disk
saveRDS(cleaned_corpus, file = "apwa_clean_corpus.rds")
saveRDS(out, file = "apwa_stm_out_object.rds")

cat("\n[TASK 03 COMPLETE] Saved 'apwa_clean_corpus.rds' and 'apwa_stm_out_object.rds'.\n")
