# %%R <- uncomment this if running inside python / colab
# ==============================================================================
# SCRIPT 04 (CHECKPOINTED): STM HYPERPARAMETER TUNING & DIAGNOSTICS (R)
# Task: Execute fault-tolerant searchK evaluation across K = {10..60}, print
#       Table 1, and export publication-grade figures (fig01 & fig01b) + gt HTML.
# ==============================================================================

library(tidyverse)
library(stm)
library(gt)
library(ggrepel)

safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

out <- readRDS("apwa_stm_out_object.rds")
cat("Loaded STM corpus:", length(out$documents), "documents and", length(out$vocab), "vocab terms.\n")

# 1. Construct Deterministic Held-Out Split (10% of documents, 50% words held out)
k_grid <- c(10, 20, 30, 40, 50, 60)
heldout_file <- "apwa_searchK_heldout_split.rds"

if (file.exists(heldout_file)) {
  heldout <- readRDS(heldout_file)
  cat("Loaded existing deterministic held-out split from Drive.\n")
} else {
  set.seed(42)
  heldout <- make.heldout(
    documents  = out$documents,
    vocab      = out$vocab,
    N          = floor(0.1 * length(out$documents)),
    proportion = 0.5,
    seed       = 42
  )
  saveRDS(heldout, heldout_file, compress = FALSE)
  cat("Created and saved deterministic held-out split (10% docs).\n")
}

# 2. Fault-Tolerant Checkpointed Grid Search Across K = {10..60}
checkpoint_file <- "apwa_searchK_checkpoint.rds"
if (file.exists(checkpoint_file)) {
  checkpoint_list <- readRDS(checkpoint_file)
  completed_k <- map_dbl(checkpoint_list, ~ .x$summary$K)
  cat("Resuming from checkpoint! Already completed K =", paste(completed_k, collapse = ", "), "\n")
} else {
  checkpoint_list <- list()
  completed_k <- numeric(0)
}

for (k_val in k_grid) {
  if (k_val %in% completed_k) {
    cat(sprintf("[SKIP] K = %d already in checkpoint.\n", k_val))
    next
  }

  cat(sprintf("\n======================================================\n"))
  cat(sprintf("Fitting STM for K = %d (Start: %s)...\n", k_val, format(Sys.time(), "%H:%M:%S")))
  cat(sprintf("======================================================\n"))

  t_start <- Sys.time()
  set.seed(42)

  fit_k <- stm(
    documents   = heldout$documents,
    vocab       = heldout$vocab,
    K           = k_val,
    prevalence  = ~ s(clean_year),
    data        = out$meta,
    init.type   = "Spectral",
    max.em.its  = 100,
    emtol       = 1e-4,
    verbose     = TRUE,
    reportevery = 20
  )

  topic_semcoh <- semanticCoherence(fit_k, heldout$documents)
  topic_exclus <- exclusivity(fit_k)
  ho_eval      <- eval.heldout(fit_k, heldout$missing)
  res_eval     <- checkResiduals(fit_k, heldout$documents)
  max_bound    <- max(fit_k$convergence$bound)
  lbound_val   <- max_bound + lfactorial(fit_k$settings$dim$K)
  em_its       <- length(fit_k$convergence$bound)
  mins_elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))

  checkpoint_list[[as.character(k_val)]] <- list(
    summary = tibble(
      K        = k_val,
      heldout  = ho_eval$expected.heldout,
      residual = res_eval$dispersion,
      semcoh   = mean(topic_semcoh),
      exclus   = mean(topic_exclus),
      bound    = max_bound,
      lbound   = lbound_val,
      em.its   = em_its,
      minutes  = round(mins_elapsed, 2)
    ),
    topic_metrics = tibble(
      K      = k_val,
      topic  = seq_len(k_val),
      semcoh = topic_semcoh,
      exclus = topic_exclus
    )
  )

  saveRDS(checkpoint_list, file = checkpoint_file, compress = FALSE)
  rm(fit_k)
  gc(verbose = FALSE)
  cat(sprintf("[DONE] K = %d finished in %.1f mins and saved to checkpoint.\n", k_val, mins_elapsed))
}

# 3. Assemble & Save 'apwa_searchK_results.rds'
results_df     <- map_dfr(checkpoint_list, "summary") %>% arrange(K)
topic_level_df <- map_dfr(checkpoint_list, "topic_metrics") %>% arrange(K, topic)

search_results <- list(
  results       = as.data.frame(results_df),
  topic_metrics = topic_level_df,
  call          = match.call()
)
class(search_results) <- "searchK"
saveRDS(search_results, file = "apwa_searchK_results.rds")

# 4. Print & Export Table 1 (CSV + GT HTML)
table_df <- results_df %>%
  mutate(
    delta_heldout = heldout - lag(heldout),
    delta_exclus  = exclus - lag(exclus)
  ) %>%
  select(K, heldout, delta_heldout, exclus, semcoh, residual, lbound, em.its, minutes)

cat("\n=== TABLE 1: STM HYPERPARAMETER DIAGNOSTICS ===\n")
print(as.data.frame(table_df), row.names = FALSE)
write_csv(table_df, "tab01_searchK_diagnostics.csv")

gt_searchk <- table_df %>%
  gt() %>%
  tab_header(
    title    = md("**Table 1. Structural Topic Model (STM) Hyperparameter Tuning Diagnostics**"),
    subtitle = "Out-of-sample evaluation and semantic-exclusivity metrics across K = {10..60}"
  ) %>%
  cols_label(
    K             = "Topics (K)",
    heldout       = "Held-Out Likelihood",
    delta_heldout = "Δ Held-Out",
    exclus        = "Exclusivity (FREX)",
    semcoh        = "Semantic Coherence",
    residual      = "Residual Dispersion",
    lbound        = "Lower Bound",
    em.its        = "EM Iterations",
    minutes       = "Runtime (Min)"
  ) %>%
  fmt_number(columns = c(heldout, delta_heldout, exclus, semcoh, residual), decimals = 3) %>%
  fmt_number(columns = c(lbound), decimals = 0) %>%
  fmt_number(columns = c(minutes), decimals = 1) %>%
  sub_missing(columns = everything(), missing_text = "—") %>%
  tab_style(
    style = list(cell_fill(color = "#fdebd0"), cell_text(weight = "bold")),
    locations = cells_body(rows = K == 40)
  ) %>%
  tab_source_note(
    source_note = md("*Note:* Highlighted row (**K = 40**) marks the selected dimensionality inflection point balancing Held-Out Likelihood, Semantic Coherence, and FREX Exclusivity.")
  )

gtsave(gt_searchk, "tab01_searchK_diagnostics.html")

# 5. Export Figure 01: 6-Panel Macroscopic Diagnostic Plot
sk_long <- results_df %>%
  transmute(
    K,
    `1. Held-Out Likelihood (Maximize ↑)` = heldout,
    `2. Exclusivity / FREX (Maximize ↑)`  = exclus,
    `3. Semantic Coherence (Maximize ↑)`  = semcoh,
    `4. Residual Dispersion (Minimize ↓)` = residual,
    `5. Variational Lower Bound (Max ↑)`  = lbound,
    `6. Convergence Effort (EM Steps)`    = em.its
  ) %>%
  pivot_longer(cols = -K, names_to = "Metric", values_to = "Value")

p_searchk <- ggplot(sk_long, aes(x = K, y = Value)) +
  geom_line(linewidth = 1, color = "#2c3e50") +
  geom_point(size = 2.8, color = "#2c3e50") +
  geom_point(data = filter(sk_long, K == 40), color = "#e74c3c", size = 4) +
  geom_vline(xintercept = 40, linetype = "dashed", color = "#e74c3c", linewidth = 0.8) +
  facet_wrap(~ Metric, scales = "free_y", ncol = 2) +
  scale_x_continuous(breaks = k_grid) +
  labs(
    title    = "Structural Topic Model Diagnostic Metrics Across K = {10..60}",
    subtitle = "Red dashed line & point mark optimal dimensionality inflection point at K = 40",
    x        = "Number of Latent Topics (K)",
    y        = "Diagnostic Metric Value",
    caption  = "Prevalence specification: ~ s(clean_year) | Initialization: Spectral | Held-out evaluation: 10% documents"
  ) +
  theme_bw(base_size = 12) +
  theme(
    strip.background = element_rect(fill = "#ecf0f1"),
    strip.text       = element_text(face = "bold"),
    plot.title       = element_text(face = "bold")
  )

ggsave("fig01_searchK_diagnostics.png", plot = p_searchk, width = 10, height = 8, dpi = 300)
print(p_searchk)

# 6. Export Figure 01B: Coherence vs. Exclusivity Pareto Frontier Plot
frontier_topics <- topic_level_df %>%
  filter(K %in% c(30, 40, 50)) %>%
  mutate(K_label = factor(paste0("K = ", K), levels = c("K = 30", "K = 40", "K = 50")))

frontier_centroids <- results_df %>%
  filter(K %in% c(30, 40, 50)) %>%
  mutate(K_label = factor(paste0("K = ", K), levels = c("K = 30", "K = 40", "K = 50")))

p_frontier <- ggplot() +
  geom_point(
    data = frontier_topics,
    aes(x = semcoh, y = exclus, color = K_label, shape = K_label),
    alpha = 0.45, size = 2.5
  ) +
  geom_point(
    data = frontier_centroids,
    aes(x = semcoh, y = exclus, fill = K_label),
    shape = 21, size = 6, color = "black", stroke = 1.2
  ) +
  geom_text(
    data = frontier_centroids,
    aes(x = semcoh, y = exclus, label = paste0("Mean\nK=", K)),
    vjust = -1.1, fontface = "bold", size = 3.5
  ) +
  scale_color_manual(values = c("K = 30" = "#3498db", "K = 40" = "#e74c3c", "K = 50" = "#9b59b6")) +
  scale_fill_manual(values  = c("K = 30" = "#3498db", "K = 40" = "#e74c3c", "K = 50" = "#9b59b6")) +
  labs(
    title    = "Semantic Coherence vs. Exclusivity (FREX) Trade-Off Frontier",
    subtitle = "Individual topic distributions (translucent) and model centroids (large circles) for K = {30, 40, 50}",
    x        = "Semantic Coherence (Higher = More Internally Cohesive Topics →)",
    y        = "Exclusivity / FREX (Higher = More Distinct Topic Vocabulary ↑)",
    color    = "Candidate Model",
    fill     = "Candidate Model",
    shape    = "Candidate Model",
    caption  = "Upper-right quadrant represents the Pareto frontier of high semantic coherence and high vocabulary exclusivity."
  ) +
  theme_bw(base_size = 12) +
  theme(
    plot.title      = element_text(face = "bold"),
    legend.position = "bottom"
  )

ggsave("fig01b_coherence_exclusivity_frontier.png", plot = p_frontier, width = 9, height = 6.5, dpi = 300)
print(p_frontier)

cat("\n[TASK 04 COMPLETE] Saved 'tab01_searchK_diagnostics.csv/.html', 'fig01_searchK_diagnostics.png', and 'fig01b_coherence_exclusivity_frontier.png'.\n")
