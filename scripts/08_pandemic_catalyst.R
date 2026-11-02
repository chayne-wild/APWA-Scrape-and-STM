# %%R <- uncomment this if running inside python / colab
# ==============================================================================
# SCRIPT 08: THE PANDEMIC CATALYST & THETA EXCLUSIVITY CORRELATIONS (R)
# ==============================================================================

library(tidyverse)
library(stm)
library(broom)

safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

final_model <- readRDS("apwa_stm_model_k40_final.rds")
out         <- readRDS("apwa_stm_out_object.rds")
topic_map   <- readRDS("resolved_target_topics_k40.rds")

T_COVID      <- topic_map$Resolved_Topic[topic_map$Code == "T_COVID"]
T_UTILITY    <- topic_map$Resolved_Topic[topic_map$Code == "T_UTILITY"]
T_CONNECTION <- topic_map$Resolved_Topic[topic_map$Code == "T_CONNECTION"]

cat(sprintf("Estimating pandemic trajectories for COVID-19 (T%02d), Utility (T%02d), and Mail/Comm (T%02d)...\n",
            T_COVID, T_UTILITY, T_CONNECTION))

prep_covid <- estimateEffect(
  formula     = c(T_UTILITY, T_COVID, T_CONNECTION) ~ s(clean_year),
  stmobj      = final_model,
  metadata    = out$meta,
  uncertainty = "Global"
)

png("fig04_pandemic_catalyst_ratchet_effect.png", width = 2400, height = 2400, res = 300)
plot(
  prep_covid,
  covariate   = "clean_year",
  model       = final_model,
  topics      = c(T_UTILITY, T_COVID, T_CONNECTION),
  method      = "continuous",
  xlim        = c(2018, 2024),
  ylim        = c(0.00, 0.15),
  xlab        = "Year of Authorship",
  ylab        = "Expected Topic Proportion",
  main        = "The Pandemic Catalyst: Utility & Communication vs. COVID-19",
  linecol     = c("green3", "darkorange", "blue"),
  printlegend = FALSE,
  ci.level    = 0.95
)
abline(v = 2020, col = "black", lty = 2, lwd = 1.8)
text(x = 2020, y = 0.14, labels = "2020 (Lockdowns)", pos = 4, cex = 0.85)
legend(
  "topleft",
  legend = c(
    sprintf("Educational Utility (T%02d)", T_UTILITY),
    sprintf("COVID-19 Quarantine & Kiosks (T%02d)", T_COVID),
    sprintf("Mail, Grievance & Tablets (T%02d)", T_CONNECTION)
  ),
  col = c("green3", "darkorange", "blue"),
  lty = 1, lwd = 2, bty = "o", bg = "white"
)
dev.off()

theta_matrix <- final_model$theta

tidy_cor_covid <- bind_rows(
  tidy(cor.test(theta_matrix[, T_COVID], theta_matrix[, T_UTILITY], method = "pearson")) %>%
    mutate(comparison = sprintf("COVID-19 (T%02d) vs. Educational Utility (T%02d)", T_COVID, T_UTILITY)),
  tidy(cor.test(theta_matrix[, T_COVID], theta_matrix[, T_CONNECTION], method = "pearson")) %>%
    mutate(comparison = sprintf("COVID-19 (T%02d) vs. Mail/Communication (T%02d)", T_COVID, T_CONNECTION))
) %>%
  select(comparison, estimate, statistic, p.value, parameter, conf.low, conf.high, method)

write_csv(tidy_cor_covid, "table02_covid_utility_correlation.csv")

cat("\n=== MICRO-DOCUMENT EXCLUSIVITY TEST (COVID-19 vs. UTILITY & COMM) ===\n")
print(as.data.frame(tidy_cor_covid), row.names = FALSE)
cat("\n[TASK 08 COMPLETE] Saved 'fig04_pandemic_catalyst_ratchet_effect.png' and 'table02_covid_utility_correlation.csv'.\n")
