%%R
# ==============================================================================
# SCRIPT 08: THE PANDEMIC CATALYST ("RATCHET EFFECT") & THETA CORRELATION (R)
# Task: 1. Regress and plot Topic 32 (Intellectual Utility) alongside Topic 21
#          (COVID-19 / Quarantine) from 2018 to 2024 to demonstrate the
#          infrastructural "Ratchet Effect" following the 2020 lockdowns.
#       2. Execute a Pearson correlation test on the document-level Theta matrix
#          to test micro-document exclusivity between T21 and T32.
# ==============================================================================

library(tidyverse)
library(stm)
library(broom)

# 1. Verify Workspace & Load Model + Metadata
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

final_model <- readRDS("apwa_stm_model_k40_final.rds")
out         <- readRDS("apwa_stm_out_object.rds")

T_COVID   <- 21
T_UTILITY <- 32

# 2. Macro-Temporal Trajectory: T32 (Utility) vs. T21 (COVID-19)
cat("Estimating temporal trajectories for COVID-19 (T21) and Digital Utility (T32)...\n")

prep_covid <- estimateEffect(
  formula     = c(T_UTILITY, T_COVID) ~ s(clean_year),
  stmobj      = final_model,
  metadata    = out$meta,
  uncertainty = "Global"
)

png("fig04_pandemic_catalyst_ratchet_effect.png", width = 2400, height = 2400, res = 300)
plot(
  prep_covid,
  covariate   = "clean_year",
  model       = final_model,
  topics      = c(T_UTILITY, T_COVID),
  method      = "continuous",
  xlim        = c(2018, 2024),
  ylim        = c(0.00, 0.15),
  xlab        = "Year of Authorship",
  ylab        = "Expected Topic Proportion",
  main        = "The Pandemic Catalyst: Digital Utility vs. COVID-19",
  linecol     = c("green3", "darkorange"),
  printlegend = FALSE,
  ci.level    = 0.95
)
abline(v = 2020, col = "black", lty = 2, lwd = 1.8)
text(x = 2020, y = 0.14, labels = "2020 (Lockdowns)", pos = 4, cex = 0.85)
legend(
  "topleft",
  legend = c("Intellectual Utility / Tablets (T32)", "COVID-19 / Quarantine (T21)"),
  col    = c("green3", "darkorange"),
  lty    = 1,
  lwd    = 2,
  bty    = "o",
  bg     = "white"
)
dev.off()

# 3. Micro-Document Exclusivity: Pearson Correlation on the Theta Matrix
# Rationale: Tests whether writers blend COVID-19 and Digital Utility within the
# same essays (positive correlation) or whether the archive split concurrently
# into mutually exclusive response domains (negative correlation).
theta_matrix <- final_model$theta

cor_covid_utility <- cor.test(
  x      = theta_matrix[, T_COVID],
  y      = theta_matrix[, T_UTILITY],
  method = "pearson"
)

tidy_cor <- tidy(cor_covid_utility) %>%
  mutate(comparison = "Topic 21 (COVID-19) vs. Topic 32 (Intellectual Utility)") %>%
  select(comparison, estimate, statistic, p.value, parameter, conf.low, conf.high, method)

write_csv(tidy_cor, "table02_covid_utility_correlation.csv")

cat("\n=== MICRO-DOCUMENT EXCLUSIVITY TEST (T21 vs. T32) ===\n")
print(tidy_cor)

cat("\n[TASK 08 COMPLETE] Saved 'fig04_pandemic_catalyst_ratchet_effect.png' and correlation table.\n")
