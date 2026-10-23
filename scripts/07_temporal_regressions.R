%%R
# ==============================================================================
# SCRIPT 07: TEMPORAL COVARIATE ESTIMATION & SURGE-ERA REGRESSIONS (R)
# Task: 1. Run estimateEffect() with B-splines s(clean_year) for Topics 18, 32, 37.
#       2. Generate publication plots for full timeline and active era (2010-2024).
#       3. Extract the Theta matrix to test linear regressions over the broad
#          decade (2010-2021) vs. the Prefigurative Surge Era (2016-2021).
#       4. Export publication-ready regression tables via modelsummary & gt.
# ==============================================================================

library(tidyverse)
library(stm)
library(broom)
library(modelsummary)
library(gt)

# 1. Verify Workspace & Load Model + Metadata
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

final_model <- readRDS("apwa_stm_model_k40_final.rds")
out         <- readRDS("apwa_stm_out_object.rds")

# Define target Tri-Partite topic indices
T_CONNECTION   <- 18
T_UTILITY      <- 32
T_SURVEILLANCE <- 37

# 2. Estimate Temporal Prevalence Effects via Smoothing Splines
# Rationale: Technology adoption in correctional facilities is non-linear;
# s(clean_year) allows trajectories to bend and capture sudden rollouts.
cat("Estimating B-spline temporal prevalence trajectories (Global uncertainty)...\n")

prep_tripartite <- estimateEffect(
  formula     = c(T_CONNECTION, T_UTILITY, T_SURVEILLANCE) ~ s(clean_year),
  stmobj      = final_model,
  metadata    = out$meta,
  uncertainty = "Global"
)

saveRDS(prep_tripartite, file = "apwa_prep_tripartite_effects.rds")

# 3. Plot A: Full Archive Timeline (1993-2024)
png("fig02_tripartite_trajectories_full.png", width = 2400, height = 2400, res = 300)
plot(
  prep_tripartite,
  covariate   = "clean_year",
  model       = final_model,
  topics      = c(T_CONNECTION, T_UTILITY, T_SURVEILLANCE),
  method      = "continuous",
  xlab        = "Year of Authorship",
  ylab        = "Expected Topic Proportion",
  main        = "Tri-Partite Trajectories of the Carceral-Digital Turn",
  ylim        = c(0.00, 0.15),
  linecol     = c("blue", "green3", "red"),
  printlegend = FALSE,
  ci.level    = 0.95
)
abline(v = 2021, col = "black", lty = 2, lwd = 1.8)
text(x = 2021, y = 0.14, labels = "2021 (Academic Turn)", pos = 2, cex = 0.85)
legend(
  "topleft",
  legend = c(
    "Interpersonal Connection (T18)",
    "Intellectual Utility (T32)",
    "State Surveillance (T37)"
  ),
  col = c("blue", "green3", "red"),
  lty = 1,
  lwd = 2,
  bty = "o",
  bg  = "white"
)
dev.off()

# 4. Plot B: Cropped Active Era (2010-2024) Eliminating 1990s Sparse-Data CIs
png("fig03_tripartite_trajectories_2010_2024.png", width = 2400, height = 2400, res = 300)
plot(
  prep_tripartite,
  covariate   = "clean_year",
  model       = final_model,
  topics      = c(T_CONNECTION, T_UTILITY, T_SURVEILLANCE),
  method      = "continuous",
  xlim        = c(2010, 2024),
  ylim        = c(0.00, 0.10),
  xlab        = "Year of Authorship",
  ylab        = "Expected Topic Proportion",
  main        = "Tri-Partite Trajectories (2010-2024)",
  linecol     = c("blue", "green3", "red"),
  printlegend = FALSE,
  ci.level    = 0.95
)
abline(v = 2021, col = "black", lty = 2, lwd = 1.8)
legend(
  "topleft",
  legend = c("Connection (T18)", "Utility (T32)", "Surveillance (T37)"),
  col    = c("blue", "green3", "red"),
  lty    = 1,
  lwd    = 2,
  bty    = "o",
  bg     = "white"
)
dev.off()

# 5. Era-Specific Linear Regressions on the Document-Topic Matrix (Theta)
# Rationale: Because T37 (Surveillance) exhibits a non-linear early hump in
# 2010-2015 before dipping and surging in 2016-2021, we compare the full decade
# window (2010-2021) against the isolated "Prefigurative Surge Era" (2016-2021).
theta_df <- tibble(
  slug             = out$meta$slug,
  Year             = out$meta$clean_year,
  Connection_T18   = final_model$theta[, T_CONNECTION],
  Utility_T32      = final_model$theta[, T_UTILITY],
  Surveillance_T37 = final_model$theta[, T_SURVEILLANCE]
)

decade_df <- theta_df %>% filter(Year >= 2010, Year <= 2021)
surge_df  <- theta_df %>% filter(Year >= 2016, Year <= 2021)

models_list <- list(
  "T18 Connection (2010-2021)"   = lm(Connection_T18 ~ Year, data = decade_df),
  "T32 Utility (2010-2021)"      = lm(Utility_T32 ~ Year, data = decade_df),
  "T37 Surveillance (2010-2021)" = lm(Surveillance_T37 ~ Year, data = decade_df),
  "T18 Connection (2016-2021)"   = lm(Connection_T18 ~ Year, data = surge_df),
  "T32 Utility (2016-2021)"      = lm(Utility_T32 ~ Year, data = surge_df),
  "T37 Surveillance (2016-2021)" = lm(Surveillance_T37 ~ Year, data = surge_df)
)

# Export tidy regression summary CSV
tidy_reg_summary <- map_dfr(models_list, ~ tidy(.x, conf.int = TRUE), .id = "Model") %>%
  left_join(
    map_dfr(models_list, ~ glance(.x) %>% select(r.squared, statistic, p.value, nobs), .id = "Model"),
    by = "Model",
    suffix = c("_coef", "_model_F")
  )

write_csv(tidy_reg_summary, "table01_prefigurative_regressions.csv")

# Export publication-ready HTML table via modelsummary + gt
ms_table <- modelsummary(
  models_list,
  stars   = c("*" = 0.05, "**" = 0.01, "***" = 0.001),
  gof_map = c("nobs", "r.squared", "F", "rmse"),
  title   = "Table 1: OLS Temporal Regressions of Topic Prevalence (theta) Prior to the 2021 Academic Turn",
  output  = "gt"
)

gtsave(ms_table, filename = "table01_prefigurative_regressions.html")

cat("\n[TASK 07 COMPLETE] Saved trajectory plots and publication regression tables.\n")
