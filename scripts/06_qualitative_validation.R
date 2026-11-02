%%R
# ==============================================================================
# SCRIPT 06: MASTER K=40 TABLE, BETA TECH AUDIT, DYNAMIC TOPIC RESOLVER &
#            QUALITATIVE EXEMPLAR VALIDATION (R)
# ==============================================================================

library(tidyverse)
library(stm)
library(gt)

safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

final_model <- readRDS("apwa_stm_model_k40_final.rds")
out         <- readRDS("apwa_stm_out_object.rds")
clean_corp  <- readRDS("apwa_clean_corpus.rds")

# ==============================================================================
# 1. EXPORT COMPLETE K = 40 TOPIC PROFILES (TABLE 2 & FIGURE 02)
# ==============================================================================
topic_labels_15 <- labelTopics(final_model, n = 15)
tidy_topic_words <- tibble(
  topic_id     = 1:40,
  highest_prob = apply(topic_labels_15$prob, 1, paste, collapse = ", "),
  frex         = apply(topic_labels_15$frex, 1, paste, collapse = ", "),
  lift         = apply(topic_labels_15$lift, 1, paste, collapse = ", "),
  score        = apply(topic_labels_15$score, 1, paste, collapse = ", ")
)
write_csv(tidy_topic_words, "top_topic_words_k40.csv")

labels_10         <- labelTopics(final_model, n = 10)
topic_proportions <- colMeans(final_model$theta)
topic_semcoh      <- semanticCoherence(final_model, out$documents)
topic_exclus      <- exclusivity(final_model)

full_k40_df <- tibble(
  Topic_Num   = 1:40,
  Topic_Label = sprintf("Topic %02d", 1:40),
  Prop_Pct    = topic_proportions * 100,
  Exclusivity = topic_exclus,
  Coherence   = topic_semcoh,
  FREX_Words  = apply(labels_10$frex, 1, paste, collapse = ", "),
  Prob_Words  = apply(labels_10$prob, 1, paste, collapse = ", "),
  Lift_Words  = apply(labels_10$lift, 1, paste, collapse = ", "),
  Score_Words = apply(labels_10$score, 1, paste, collapse = ", ")
) %>%
  arrange(desc(Prop_Pct)) %>%
  mutate(Rank = row_number()) %>%
  select(Rank, Topic_Num, Topic_Label, Prop_Pct, Exclusivity, Coherence, FREX_Words, Prob_Words, Lift_Words, Score_Words)

write_csv(full_k40_df, "tab02_full_k40_topic_profiles.csv")

gt_k40 <- full_k40_df %>%
  arrange(Topic_Num) %>%
  select(Topic_Label, Prop_Pct, Exclusivity, Coherence, FREX_Words, Prob_Words) %>%
  gt() %>%
  tab_header(
    title    = md("**Table 2. Complete Structural Topic Model (K = 40) Lexical Profiles and Corpus Prevalence**"),
    subtitle = sprintf("Estimated across N = %s APWA essays (1965–2026) with ~ s(clean_year) prevalence prior",
                       format(length(out$documents), big.mark = ","))
  ) %>%
  cols_label(
    Topic_Label = "Topic",
    Prop_Pct    = "Corpus Share (%)",
    Exclusivity = "Exclusivity",
    Coherence   = "Coherence",
    FREX_Words  = "Top 10 FREX Words (Frequency & Exclusivity)",
    Prob_Words  = "Top 10 Highest Probability Words"
  ) %>%
  fmt_number(columns = c(Prop_Pct, Exclusivity, Coherence), decimals = 2) %>%
  cols_width(
    Topic_Label ~ px(85),
    Prop_Pct    ~ px(95),
    Exclusivity ~ px(85),
    Coherence   ~ px(85),
    FREX_Words  ~ px(340),
    Prob_Words  ~ px(340)
  ) %>%
  tab_options(table.font.size = px(11), data_row.padding = px(4)) %>%
  tab_source_note(
    source_note = md("*Note:* Corpus Share (%) reflects mean posterior document-topic proportion (mean theta x 100). FREX weights tokens by the harmonic mean of topic exclusivity and frequency.")
  )

gtsave(gt_k40, "tab02_full_k40_topic_profiles.html")

# Generate Figure 02: All 40 Topics Ranked Prevalence Bar Chart
labels_5 <- labelTopics(final_model, n = 5)
plot_k40_df <- tibble(
  Topic_Num  = 1:40,
  Prop_Pct   = topic_proportions * 100,
  Short_FREX = apply(labels_5$frex, 1, paste, collapse = ", "),
  Short_Prob = apply(labels_5$prob, 1, paste, collapse = ", ")
) %>%
  mutate(
    Display_Label = sprintf("T%02d: %s", Topic_Num, Short_Prob),
    Display_Label = fct_reorder(Display_Label, Prop_Pct)
  )

p_all_topics <- ggplot(plot_k40_df, aes(x = Prop_Pct, y = Display_Label)) +
  geom_col(fill = "#2c3e50", width = 0.75) +
  geom_text(
    aes(label = sprintf("%.1f%%  [FREX: %s]", Prop_Pct, Short_FREX)),
    hjust = -0.03, size = 2.9, color = "#2d3436"
  ) +
  scale_x_continuous(limits = c(0, max(plot_k40_df$Prop_Pct) * 1.65), expand = c(0, 0)) +
  labs(
    title    = "Expected Corpus Prevalence Across All K = 40 Latent Topics",
    subtitle = "Bars ordered by mean posterior topic proportion (θ); labels show Top 5 Prob and Top 5 FREX terms",
    x        = "Expected Topic Proportion (% of Corpus)",
    y        = NULL
  ) +
  theme_bw(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), panel.grid.major.y = element_blank())

ggsave("fig02_all_40_topics_prevalence.png", plot = p_all_topics, width = 12, height = 11, dpi = 300)
print(p_all_topics)

# ==============================================================================
# 2. BETA-MATRIX CARCERAL TECHNOLOGY VOCABULARY AUDIT (TABLE 3)
# ==============================================================================
tech_lexicon <- tribble(
  ~Domain, ~Term,
  "1_Connection_Comm", "jpay",
  "1_Connection_Comm", "kiosk",
  "1_Connection_Comm", "email",
  "1_Connection_Comm", "corrlinks",
  "1_Connection_Comm", "securus",
  "1_Connection_Comm", "gtl",
  "1_Connection_Comm", "phone",
  "1_Connection_Comm", "telephone",
  "1_Connection_Comm", "call",
  "1_Connection_Comm", "video",
  "1_Connection_Comm", "mail",
  "1_Connection_Comm", "letter",
  "1_Connection_Comm", "message",
  "2_Utility_Tech",    "tablet",
  "2_Utility_Tech",    "computer",
  "2_Utility_Tech",    "digital",
  "2_Utility_Tech",    "electronic",
  "2_Utility_Tech",    "technology",
  "2_Utility_Tech",    "internet",
  "2_Utility_Tech",    "online",
  "2_Utility_Tech",    "screen",
  "2_Utility_Tech",    "typewriter",
  "2_Utility_Tech",    "program",
  "2_Utility_Tech",    "education",
  "2_Utility_Tech",    "library",
  "3_Surveillance",    "surveillance",
  "3_Surveillance",    "camera",
  "3_Surveillance",    "monitor",
  "3_Surveillance",    "record",
  "3_Surveillance",    "watch",
  "3_Surveillance",    "sensor",
  "3_Surveillance",    "speaker",
  "3_Surveillance",    "intercom",
  "3_Surveillance",    "control",
  "3_Surveillance",    "security"
)

beta_mat <- exp(final_model$beta$logbeta[[1]])
colnames(beta_mat) <- out$vocab
rank_mat <- apply(-beta_mat, 1, rank, ties.method = "min")

doc_freq <- table(unlist(map(out$documents, ~ .x[1, ])))
vocab_df_counts <- tibble(
  vocab_idx = as.integer(names(doc_freq)),
  doc_count = as.integer(doc_freq),
  term      = out$vocab[vocab_idx]
)

tech_audit <- tech_lexicon %>%
  left_join(vocab_df_counts, by = c("Term" = "term")) %>%
  rowwise() %>%
  mutate(
    In_Vocab   = !is.na(vocab_idx),
    Top1_Topic = if (In_Vocab) which.max(beta_mat[, vocab_idx]) else NA_integer_,
    Top1_Rank  = if (In_Vocab) rank_mat[vocab_idx, Top1_Topic] else NA_integer_,
    Top1_Share = if (In_Vocab) round(100 * beta_mat[Top1_Topic, vocab_idx] / sum(beta_mat[, vocab_idx]), 1) else NA_real_,
    Top2_Topic = if (In_Vocab) order(beta_mat[, vocab_idx], decreasing = TRUE)[2] else NA_integer_,
    Top2_Rank  = if (In_Vocab) rank_mat[vocab_idx, Top2_Topic] else NA_integer_
  ) %>%
  ungroup() %>%
  select(Domain, Term, doc_count, Top1_Topic, Top1_Rank, Top1_Share, Top2_Topic, Top2_Rank)

cat("\n=== TABLE 3: CARCERAL TECHNOLOGY VOCABULARY AUDIT IN K=40 MODEL ===\n")
print(as.data.frame(tech_audit), row.names = FALSE)
write_csv(tech_audit, "tab03_tech_vocabulary_beta_audit.csv")

gt_tech_audit <- tech_audit %>%
  gt() %>%
  tab_header(
    title    = md("**Table 3. Beta-Matrix Lexical Audit of Carceral-Digital & Infrastructural Vocabulary**"),
    subtitle = "Document frequency, dominant latent topic assignment, within-topic rank, and probability share"
  ) %>%
  sub_missing(columns = everything(), missing_text = "—")
gtsave(gt_tech_audit, "tab03_tech_vocabulary_beta_audit.html")

# ==============================================================================
# 3. AUTOMATIC SEMANTIC TOPIC RESOLVER (ELIMINATES HARDCODED TOPIC INTEGERS)
# ==============================================================================
resolve_topic <- function(anchor_words, code_name, label_name) {
  valid_words <- intersect(anchor_words, colnames(beta_mat))
  if (length(valid_words) == 0) stop(paste("No anchor words found for:", label_name))
  scores <- rowSums(beta_mat[, valid_words, drop = FALSE])
  best_k <- which.max(scores)
  tibble(
    Code           = code_name,
    Construct      = label_name,
    Resolved_Topic = best_k,
    Corpus_Pct     = round(100 * topic_proportions[best_k], 2),
    Top_Prob_Words = paste(labels_10$prob[best_k, 1:7], collapse = ", "),
    Top_FREX_Words = paste(labels_10$frex[best_k, 1:7], collapse = ", ")
  )
}

topic_map <- bind_rows(
  resolve_topic(c("write", "letter", "mail", "phone", "grievance", "tablet"), "T_CONNECTION",   "Interpersonal Comm, Mail & Tablets"),
  resolve_topic(c("program", "education", "class", "college", "vocational"),  "T_UTILITY",      "Educational & Programmatic Utility"),
  resolve_topic(c("rule", "staff", "correctional", "policy", "mdoc"),         "T_SURVEILLANCE", "Institutional Control & Bureaucratic Rules"),
  resolve_topic(c("covid", "virus", "quarantine", "pandemic", "mask"),        "T_COVID",        "COVID-19 Quarantine & Unit Kiosks"),
  resolve_topic(c("food", "meal", "eat", "bag", "item", "water"),             "T_COMMISSARY",   "Food Provision, Commissary & JPay"),
  resolve_topic(c("money", "pay", "lot", "job", "call", "jail"),              "T_ECONOMY",      "Carceral Economy, Wages & Phone Costs"),
  resolve_topic(c("plan", "inside", "release", "learn", "society"),           "T_REENTRY",      "Reentry Planning & Technological Readiness")
)

cat("\n=== AUTOMATICALLY RESOLVED TARGET TOPICS ===\n")
print(as.data.frame(topic_map), row.names = FALSE)
write_csv(topic_map, "resolved_target_topics_k40.csv")
saveRDS(topic_map, "resolved_target_topics_k40.rds")

# ==============================================================================
# 4. QUALITATIVE EXEMPLAR EXTRACTION (FINDTHOUGHTS + EXPLICIT VENDOR ESSAYS)
# ==============================================================================
sink("qualitative_exemplar_essays.txt")
cat("======================================================================\n")
cat("APWA QUALITATIVE VALIDATION REPORT: RESOLVED TOPICS & VENDOR EXEMPLARS\n")
cat("======================================================================\n\n")

for (i in seq_len(nrow(topic_map))) {
  t_num <- topic_map$Resolved_Topic[i]
  t_lbl <- sprintf("%s (Topic %02d): %s", topic_map$Code[i], t_num, topic_map$Construct[i])
  cat("----------------------------------------------------------------------\n")
  cat(t_lbl, "\n")
  cat("FREX Words:", tidy_topic_words$frex[t_num], "\n")
  cat("----------------------------------------------------------------------\n\n")

  thoughts <- findThoughts(model = final_model, texts = out$meta$transcript, topics = t_num, n = 5)
  doc_indices <- thoughts$index[[1]]
  for (rank_i in seq_along(doc_indices)) {
    idx <- doc_indices[rank_i]
    theta_val <- round(final_model$theta[idx, t_num], 4)
    cat(sprintf("[Rank %d | Slug: %s | Year: %d | Theta: %.4f]\n", rank_i, out$meta$slug[idx], out$meta$clean_year[idx], theta_val))
    cat("URL:", out$meta$url[idx], "\n\n")
    cat(str_sub(out$meta$transcript[idx], 1, 2500), "\n")
    cat("\n======================================================================\n\n")
  }
}

# Append Top Explicit Carceral-Digital Vendor/Hardware Essays (jpay, tablet, kiosk)
cat("======================================================================\n")
cat("EXPLICIT CARCERAL-DIGITAL HARDWARE EXEMPLARS (JPAY / TABLET / KIOSK)\n")
cat("======================================================================\n\n")

vendor_hits <- clean_corp %>%
  mutate(
    vendor_count = str_count(cleaned_text, "\\b(jpay|tablet|kiosk|securus|gtl|corrlinks)\\b")
  ) %>%
  filter(vendor_count > 0) %>%
  arrange(desc(vendor_count), desc(clean_year)) %>%
  slice_head(n = 10)

for (j in seq_len(nrow(vendor_hits))) {
  cat(sprintf("[Vendor Exemplar %d | Slug: %s | Year: %d | Tech Term Mentions: %d]\n",
              j, vendor_hits$slug[j], vendor_hits$clean_year[j], vendor_hits$vendor_count[j]))
  cat("URL:", vendor_hits$url[j], "\n\n")
  cat(str_sub(vendor_hits$transcript[j], 1, 2500), "\n")
  cat("\n----------------------------------------------------------------------\n\n")
}
sink()

cat("\n[TASK 06 COMPLETE] Exported 'tab02', 'fig02', 'tab03', 'resolved_target_topics_k40.csv', and 'qualitative_exemplar_essays.txt'.\n")
