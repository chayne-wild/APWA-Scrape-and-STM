%%R
# ==============================================================================
# SCRIPT 04: STM HYPERPARAMETER TUNING & SEARCHK DIAGNOSTICS (R)
# Task: Execute searchK() across K = {10, 20, 30, 40, 50, 60} to empirically
#       justify selecting K = 40 based on Held-Out Likelihood, Residuals,
#       Semantic Coherence, and Lower Bound. Exports a Tidy ggplot2 figure.
# ==============================================================================

library(tidyverse)
library(stm)

# 1. Verify Workspace & Load Synchronized STM Corpus
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

out <- readRDS("apwa_stm_out_object.rds")
cat("Loaded STM corpus:", length(out$documents), "documents and", length(out$vocab), "vocab terms.\n")

# 2. Execute searchK Grid Search across Macroscopic Range
# Rationale: K < 30 collapses niche technology signals into general prison "soup",
# whereas K > 50 fragments coherent themes into statistical "crumbs".
k_grid <- c(10, 20, 30, 40, 50, 60)

cat("Beginning searchK evaluation across K =", paste(k_grid, collapse = ", "), "...\n")
set.seed(42)

search_results <- searchK(
  documents  = out$documents,
  vocab      = out$vocab,
  K          = k_grid,
  prevalence = ~ s(clean_year),
  data       = out$meta,
  init.type  = "Spectral",
  cores      = 2
)

# Immediately serialize searchK results to Google Drive
saveRDS(search_results, file = "apwa_searchK_results.rds")
cat("Saved 'apwa_searchK_results.rds' to Drive.\n")

# 3. Extract Metrics into a Tidy Tibble & Plot Publication-Ready Diagnostics
sk_df <- tibble(
  K                               = unlist(search_results$results$K),
  `Held-Out Likelihood (Maximize)` = unlist(search_results$results$heldout),
  `Residuals (Minimize)`           = unlist(search_results$results$residual),
  `Semantic Coherence (Maximize)`  = unlist(search_results$results$semcoh),
  `Lower Bound (Maximize)`         = unlist(search_results$results$lbound)
) %>%
  pivot_longer(cols = -K, names_to = "Metric", values_to = "Value")

p_searchk <- ggplot(sk_df, aes(x = K, y = Value)) +
  geom_line(linewidth = 1, color = "#2c3e50") +
  geom_point(size = 2.8, color = "#2c3e50") +
  geom_vline(xintercept = 40, linetype = "dashed", color = "#e74c3c", linewidth = 0.8) +
  facet_wrap(~ Metric, scales = "free_y", ncol = 2) +
  scale_x_continuous(breaks = k_grid) +
  labs(
    title    = "Structural Topic Model Diagnostic Metrics Across K = {10..60}",
    subtitle = "Red dashed line marks optimal dimensionality inflection point at K = 40",
    x        = "Number of Latent Topics (K)",
    y        = "Diagnostic Metric Value"
  ) +
  theme_bw(base_size = 12) +
  theme(
    strip.background = element_rect(fill = "#ecf0f1"),
    strip.text       = element_text(face = "bold"),
    plot.title       = element_text(face = "bold")
  )

ggsave("fig01_searchK_diagnostics.png", plot = p_searchk, width = 9, height = 6, dpi = 300)
print(p_searchk)

cat("\n[TASK 04 COMPLETE] Diagnostic plot saved to 'fig01_searchK_diagnostics.png'.\n")
