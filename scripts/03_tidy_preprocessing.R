%%R
# ==============================================================================
# SCRIPT 03: TIDYVERSE DATA INGESTION, TEMPORAL NORMALIZATION, & NLP CLEANING (R)
# Task: Ingest 'apwa_parsed_archive.jsonl' natively in R with fault tolerance,
#       normalize 'clean_year', execute Tidyverse NLP cleaning (possessive
#       normalization, domain-guarded lemmatization, and the "Plural Bypass"
#       expanded stop-word filter), and export the 1:1 synchronized STM
#       mathematical matrix ('out') and cleaned corpus.
# ==============================================================================

library(tidyverse)
library(jsonlite)
library(tidytext)
library(textstem)
library(lexicon)
library(stm)

# 1. Verify Workspace
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (!dir.exists(safe_workspace)) {
  stop("SECURITY HALT: Workspace directory does not exist. Ensure Google Drive is mounted.")
}
if (getwd() != safe_workspace) setwd(safe_workspace)
cat("Operating inside R workspace:", getwd(), "\n")

# 2. Fault-Tolerant Line-by-Line JSONL Ingestion in R
# Rationale: Native stream_in() halts if a single line has a partial network write.
# Using read_lines() + purrr::safely() isolates and skips any corrupted JSON packet
# while keeping the pipeline 100% inside R/Tidyverse.
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

# 3. Temporal Normalization (Extracting & Bounding 4-Digit Authorship Year)
# Rationale: STM prevalence regression requires a clean numeric year covariate.
# Bounding to [1965, 2026] prevents metadata typos (e.g., '1900' or '2099')
# from acting as high-leverage outliers in STM temporal splines.
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
# Rationale: High-entropy domain words ('prison', 'inmate') and conversational
# filler ('time', 'like', 'know') cause severe cross-topic contamination and
# degrade FREX exclusivity if not aggressively pruned.
custom_stops <- tibble(
  word = c(
    "prison", "inmate", "prisoner", "cell", "guard", "officer", "c.o.", "co",
    "apwa", "criminal", "crime", "life", "time", "like", "know", "get",
    "people", "day", "year", "way", "tell", "guy", "john", "johns",
    "hopkins", "university"
  )
)

# 5. Domain-Guarded Lemmatization Dictionary (Addressing Supervisor Critique)
# Rationale: Standard lexicon::hash_lemmas is Part-of-Speech blind. It maps
# homographs to the wrong root (e.g., 'wound' -> 'wind', 'left' -> 'leave')
# and collapses institutional carceral/legal gerunds into generic verbs
# (e.g., 'hearing' -> 'hear', 'housing' -> 'house', 'programming' -> 'program').
# Below, we protect domain-critical vocabulary and verify 'cope/coping' vs 'cop'.
protected_overrides <- tribble(
  ~token,        ~lemma,
  # Psychological coping vs. police ("cop") disambiguation
  "cope",        "cope",
  "copes",       "cope",
  "coped",       "cope",
  "coping",      "coping",     # Keep psychological gerund/noun intact (or map to "cope", never "cop")
  "cop",         "cop",
  "cops",        "cop",
  # Homographs that hash_lemmas mis-lemmatizes in carceral text
  "wound",       "wound",      # Prevent 'wound' (injury) -> 'wind'
  "wounds",      "wound",
  "wounded",     "wound",
  "left",        "left",       # Prevent 'left' -> 'leave'
  "grounds",     "grounds",    # Preserve legal/institutional 'grounds'
  # Institutional, legal, & carceral nouns/gerunds to protect from verb collapse
  "hearing",     "hearing",    # Parole/court hearing (prevent -> 'hear')
  "hearings",    "hearing",
  "ruling",      "ruling",     # Court ruling (prevent -> 'rule')
  "rulings",     "ruling",
  "proceeding",  "proceeding", # Legal proceeding (prevent -> 'proceed')
  "proceedings", "proceeding",
  "finding",     "finding",    # Court finding (prevent -> 'find')
  "findings",    "finding",
  "housing",     "housing",    # Prison housing unit (prevent -> 'house')
  "programming", "programming",# Prison programming (prevent -> 'program')
  "training",    "training",   # Vocational training (prevent -> 'train')
  "building",    "building",   # Prison building (prevent -> 'build')
  "buildings",   "building",
  "beating",     "beating",    # Physical beating (prevent -> 'beat')
  "beatings",    "beating",
  "shooting",    "shooting",   # Prevent -> 'shoot'
  "shootings",   "shooting",
  "killing",     "killing",    # Prevent -> 'kill'
  "killings",    "killing",
  "feeling",     "feeling",    # Emotional feeling (prevent -> 'feel')
  "feelings",    "feeling",
  "suffering",   "suffering",  # Prevent -> 'suffer'
  "writing",     "writing",    # Prison writing (prevent -> 'write')
  "writings",    "writing"
)

apwa_lemma_dict <- as_tibble(lexicon::hash_lemmas) %>%
  rename(token = token, lemma = lemma) %>%
  mutate(
    token = tolower(token),
    lemma = tolower(lemma)
  ) %>%
  distinct(token, .keep_all = TRUE) %>%
  # Remove overridden tokens from base lexicon and bind domain-protected mappings
  anti_join(protected_overrides, by = "token") %>%
  bind_rows(protected_overrides)

# Print diagnostic audit table to verify supervisor's concern in console logs
cat("\n--- Diagnostic Audit of Domain-Guarded Lemmatizer ---\n")
audit_terms <- tibble(word = c("copes", "coping", "coped", "cops", "wound", "wounds", "hearings", "housing", "programming", "left")) %>%
  left_join(apwa_lemma_dict, by = c("word" = "token")) %>%
  mutate(final_lemma = coalesce(lemma, word)) %>%
  select(original_token = word, mapped_lemma = final_lemma)
print(as.data.frame(audit_terms), row.names = FALSE)
cat("-----------------------------------------------------\n\n")

# 6. Tidyverse NLP Pipeline & The "Plural Bypass" Fix
# Rationale: Evaluating tokens against the stop-word list both BEFORE and AFTER
# lemmatization ensures pluralized domain noise (e.g., "prisoners" -> "prisoner",
# "inmates" -> "inmate") cannot bypass the filter.
cat("Executing Tidytext tokenization, possessive normalization, lemmatization, and Plural Bypass filtering...\n")

cleaned_corpus <- clean_data %>%
  # Step 6A: Normalize typographic apostrophes so contractions & possessives parse cleanly
  mutate(transcript_norm = str_replace_all(transcript, "[\u2018\u2019\u02BC`]", "'")) %>%
  # Step 6B: Tokenize into lowercase words
  unnest_tokens(output = word, input = transcript_norm, token = "words", to_lower = TRUE) %>%
  # Step 6C: Pre-lemmatization stop-word removal (catches contractions like "don't", "can't")
  anti_join(stop_words, by = "word") %>%
  # Step 6D: Strip possessive suffixes ('s or trailing ') so nouns like "mother's" -> "mother"
  #          are rescued rather than deleted by the alphabetic regex filter below
  mutate(word = str_remove_all(word, "'s$|'$")) %>%
  # Step 6E: Keep strictly alphabetic tokens of at least 3 characters
  filter(str_detect(word, "^[a-z]{3,}$")) %>%
  # Step 6F: Pre-lemmatization stop-word removal (Standard + Custom)
  anti_join(stop_words, by = "word") %>%
  anti_join(custom_stops, by = "word") %>%
  # Step 6G: Fast, transparent Tidyverse lemmatization via domain-guarded dictionary
  left_join(apwa_lemma_dict, by = c("word" = "token")) %>%
  mutate(lemma = coalesce(lemma, word)) %>%
  # Step 6H: THE PLURAL BYPASS FIX (Post-lemmatization stop-word & length filter)
  filter(str_detect(lemma, "^[a-z]{3,}$")) %>%
  anti_join(stop_words, by = c("lemma" = "word")) %>%
  anti_join(custom_stops, by = c("lemma" = "word")) %>%
  # Step 6I: Re-aggregate cleaned lemmas per document while preserving metadata
  group_by(slug) %>%
  summarize(cleaned_text = str_c(lemma, collapse = " "), .groups = "drop") %>%
  inner_join(clean_data, by = "slug") %>%
  select(slug, url, clean_year, date_raw, transcript, cleaned_text)

# 7. Build the Synchronized STM Mathematical Matrix ('out')
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
  stem              = FALSE, # Preserves domain-guarded lemmatization
  wordLengths       = c(3, Inf)
)

# lower.thresh = 1 purges words appearing in only 1 document across the archive
out <- prepDocuments(
  documents    = processed$documents,
  vocab        = processed$vocab,
  meta         = processed$meta,
  lower.thresh = 1
)

# 8. Enforce Strict 1:1 Row Alignment After prepDocuments() Pruning
# Rationale: If prepDocuments() drops any ultra-short document consisting solely
# of hapax legomena, re-syncing cleaned_corpus from out$meta guarantees that
# nrow(cleaned_corpus) == length(out$documents) for downstream findThoughts() calls.
cleaned_corpus <- as_tibble(out$meta) %>%
  select(slug, url, clean_year, date_raw, transcript, cleaned_text)

cat(
  "Final synchronized STM corpus:",
  length(out$documents), "documents and",
  length(out$vocab), "unique vocabulary terms.\n"
)

# 9. Serialize Cleaned Data & STM Input Object to Disk
saveRDS(cleaned_corpus, file = "apwa_clean_corpus.rds")
saveRDS(out, file = "apwa_stm_out_object.rds")

cat("\n[TASK 03 COMPLETE] Saved 1:1 aligned 'apwa_clean_corpus.rds' and 'apwa_stm_out_object.rds'.\n")
