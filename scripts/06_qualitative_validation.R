%%R
# ==============================================================================
# SCRIPT 06: QUALITATIVE TOPIC IDENTIFICATION & EXEMPLAR VALIDATION (R)
# Task: Extract top words (Highest Prob, FREX, Lift, Score) for all 40 topics
#       into a tidy CSV, and execute findThoughts() on Topics 18, 32, and 37
#       to pull un-lemmatized full-text essays for qualitative validation.
# ==============================================================================

library(tidyverse)
library(stm)

# 1. Verify Workspace & Load Model + Corpus
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

final_model <- readRDS("apwa_stm_model_k40_final.rds")
out         <- readRDS("apwa_stm_out_object.rds")

# 2. Extract Word Weighting Metrics (Highest Prob, FREX, Lift, Score)
# Rationale: FREX (Frequency and Exclusivity) balances how frequent a token is
# within a topic against how exclusive it is to that topic across the archive.
topic_labels <- labelTopics(final_model, n = 15)

tidy_topic_words <- tibble(
  topic_id     = 1:40,
  highest_prob = apply(topic_labels$prob, 1, paste, collapse = ", "),
  frex         = apply(topic_labels$frex, 1, paste, collapse = ", "),
  lift         = apply(topic_labels$lift, 1, paste, collapse = ", "),
  score        = apply(topic_labels$score, 1, paste, collapse = ", ")
)

write_csv(tidy_topic_words, "top_topic_words_k40.csv")
cat("Exported all 40 topic word-weighting profiles to 'top_topic_words_k40.csv'.\n\n")

# Print target topics to console for immediate inspection
target_topics <- c(18, 32, 37, 21, 26)
cat("=== TARGET TOPIC PROFILES (FREX & HIGHEST PROBABILITY) ===\n")
tidy_topic_words %>%
  filter(topic_id %in% target_topics) %>%
  select(topic_id, frex, highest_prob) %>%
  print(n = Inf)

# 3. Qualitative Validation via findThoughts()
# Rationale: Mitigates the "Sub-Topic Dilution Problem" by pulling the original,
# un-lemmatized transcripts of the top 5 highest-probability essays for each
# technology topic so the researcher can verify digital vs. analog context.
tech_topics <- c(
  "Topic 18: Interpersonal Connection (JPay/Kiosks/Tablets)" = 18,
  "Topic 32: Intellectual Utility (Tablets/Education)"       = 32,
  "Topic 37: State Surveillance (Digital Control/System)"    = 37
)

sink("qualitative_exemplar_essays.txt")
cat("======================================================================\n")
cat("APWA QUALITATIVE VALIDATION REPORT: TOP 5 EXEMPLAR ESSAYS PER TOPIC\n")
cat("======================================================================\n\n")

for (label in names(tech_topics)) {
  t_num <- tech_topics[[label]]
  cat("----------------------------------------------------------------------\n")
  cat(label, "\n")
  cat("FREX Words:", tidy_topic_words$frex[t_num], "\n")
  cat("----------------------------------------------------------------------\n\n")

  thoughts <- findThoughts(
    model  = final_model,
    texts  = out$meta$transcript,
    topics = t_num,
    n      = 5
  )

  doc_indices <- thoughts$index[[1]]
  for (rank_i in seq_along(doc_indices)) {
    idx <- doc_indices[rank_i]
    theta_val <- round(final_model$theta[idx, t_num], 4)
    cat(sprintf("[Rank %d | Slug: %s | Year: %d | Topic Proportion (Theta): %.4f]\n",
                rank_i, out$meta$slug[idx], out$meta$clean_year[idx], theta_val))
    cat("URL:", out$meta$url[idx], "\n\n")
    cat(str_sub(out$meta$transcript[idx], 1, 2500), "\n")
    cat("\n======================================================================\n\n")
  }
}
sink()

cat("\n[TASK 06 COMPLETE] Full-text exemplar essays written to 'qualitative_exemplar_essays.txt'.\n")
