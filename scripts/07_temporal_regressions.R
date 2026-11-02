# %%R <- uncomment this if running inside python / colab
# ==============================================================================
# SCRIPT 07: TEMPORAL COVARIATE ESTIMATION, SURGE-ERA REGRESSIONS &
#            DIRECT CARCERAL-DIGITAL LEXICAL TRAJECTORIES (R)
# ==============================================================================

library(tidyverse)
library(stm)
library(broom)
library(modelsummary)
library(gt)

safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

final_model <- readRDS("apwa_stm_model_k40_final.rds")
out         <- readRDS("apwa_stm_out_object.rds")
clean_corp  <- readRDS("apwa_clean_corpus.rds")
topic_map   <- readRDS("resolved_target_topics_k40.rds")

# 1. Load Dynamically Resolved Topic IDs
T_CONNECTION   <- topic_map$Resolved_Topic[topic_map$Code == "T_CONNECTION"]
T_UTILITY      <- topic_map$Resolved_Topic[topic_map$Code == "T_UTILITY"]
T_SURVEILLANCE <- topic_map$Resolved_Topic[topic_map$Code == "T_SURVEILLANCE"]
T_REENTRY      <- topic_map$Resolved_Topic[topic_map$Code == "T_REENTRY"]

# 2. Estimate B-Spline Temporal Prevalence Trajectories
cat("Estimating B-spline temporal prevalence trajectories (Global uncertainty)...\n")

prep_tripartite <- estimateEffect(
  formula     = c(T_CONNECTION, T_UTILITY, T_SURVEILLANCE) ~ s(clean_year),
  stmobj      = final_model,
  metadata    = out$meta,
  uncertainty = "Global"
)

saveRDS(prep_tripartite, file = "apwa_prep_tripartite_effects.rds")

# 3. Figure 03A: Full Archive Timeline (1993-2024)
png("fig03a_tripartite_trajectories_full.png", width = 2400, height = 2400, res = 300)
plot(
  prep_tripartite,
  covariate   = "clean_year",
  model       = final_model,
  topics      = c(T_CONNECTION, T_UTILITY, T_SURVEILLANCE),
  method      = "continuous",
  xlab        = "Year of Authorship",
  ylab        = "Expected Topic Proportion",
  main        = "Tri-Partite Socio-Technical Trajectories of the APWA",
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
    sprintf("Mail, Grievance & Tablets (T%02d)", T_CONNECTION),
    sprintf("Educational Utility (T%02d)", T_UTILITY),
    sprintf("Institutional Control & Rules (T%02d)", T_SURVEILLANCE)
  ),
  col = c("blue", "green3", "red"),
  lty = 1, lwd = 2, bty = "o", bg = "white"
)
dev.off()

# 4. Figure 03B: Cropped Active Era (2010-2024)
png("fig03b_tripartite_trajectories_2010_2024.png", width = 2400, height = 2400, res = 300)
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
  main        = "Tri-Partite Socio-Technical Trajectories (2010–2024)",
  linecol     = c("blue", "green3", "red"),
  printlegend = FALSE,
  ci.level    = 0.95
)
abline(v = 2021, col = "black", lty = 2, lwd = 1.8)
legend(
  "topleft",
  legend = c(
    sprintf("Mail/Comm/Tablets (T%02d)", T_CONNECTION),
    sprintf("Educational Utility (T%02d)", T_UTILITY),
    sprintf("Institutional Control (T%02d)", T_SURVEILLANCE)
  ),
  col = c("blue", "green3", "red"),
  lty = 1, lwd = 2, bty = "o", bg = "white"
)
dev.off()

# 5. Era-Specific Linear Regressions on Resolved Document-Topic Proportions (Theta)
theta_df <- tibble(
  slug           = out$meta$slug,
  Year           = out$meta$clean_year,
  Connection     = final_model$theta[, T_CONNECTION],
  Utility        = final_model$theta[, T_UTILITY],
  Surveillance   = final_model$theta[, T_SURVEILLANCE],
  Reentry_Tech   = final_model$theta[, T_REENTRY]
)

decade_df <- theta_df %>% filter(Year >= 2010, Year <= 2021)
surge_df  <- theta_df %>% filter(Year >= 2016, Year <= 2021)

models_list <- list(
  "Comm/Mail/Tablets (2010-2021)"   = lm(Connection ~ Year, data = decade_df),
  "Educational Utility (2010-2021)" = lm(Utility ~ Year, data = decade_df),
  "Inst. Control (2010-2021)"       = lm(Surveillance ~ Year, data = decade_df),
  "Comm/Mail/Tablets (2016-2021)"   = lm(Connection ~ Year, data = surge_df),
  "Educational Utility (2016-2021)" = lm(Utility ~ Year, data = surge_df),
  "Inst. Control (2016-2021)"       = lm(Surveillance ~ Year, data = surge_df)
)

tidy_reg_summary <- map_dfr(models_list, ~ tidy(.x, conf.int = TRUE), .id = "Model") %>%
  left_join(
    map_dfr(models_list, ~ glance(.x) %>% select(r.squared, statistic, p.value, nobs), .id = "Model"),
    by = "Model",
    suffix = c("_coef", "_model_F")
  )

write_csv(tidy_reg_summary, "table01_prefigurative_regressions.csv")

ms_table <- modelsummary(
  models_list,
  stars   = c("*" = 0.05, "**" = 0.01, "***" = 0.001),
  gof_map = c("nobs", "r.squared", "F", "rmse"),
  title   = "OLS Temporal Regressions of Resolved Topic Prevalence (theta) Prior to the 2021 Academic Turn",
  output  = "gt"
)
gtsave(ms_table, filename = "table01_prefigurative_regressions.html")

# ==============================================================================
# 6. DIRECT CARCERAL-DIGITAL HARDWARE LEXICAL TRAJECTORY (TABLE 04 & FIG 06)
# Rationale: Separates unambiguous prison digital platforms/hardware
#            (jpay, tablet, kiosk, securus, gtl, corrlinks, electronic, digital)
#            from confounded general terms (e.g., 'email' in USP Tucson headers
#            and 'video' in court trial transcripts).
# ==============================================================================

rx_core_platforms <- "\\b(jpay|kiosk|tablet|corrlinks|corrlink|securus|gtl|electronic|digital)\\b"
rx_digital_surv   <- "\\b(camera|monitor|surveillance|sensor|intercom)\\b"
rx_analog_mail    <- "\\b(letter|mail|envelope|stamp|typewriter)\\b"

lex_df <- clean_corp %>%
  mutate(
    token_count        = str_count(cleaned_text, "\\S+"),
    has_core_platforms = as.integer(str_detect(cleaned_text, rx_core_platforms)),
    has_digital_surv   = as.integer(str_detect(cleaned_text, rx_digital_surv)),
    has_analog_mail    = as.integer(str_detect(cleaned_text, rx_analog_mail)),
    platform_rate_1k   = 1000 * str_count(cleaned_text, rx_core_platforms) / pmax(token_count, 1),
    surv_rate_1k       = 1000 * str_count(cleaned_text, rx_digital_surv) / pmax(token_count, 1)
  )

annual_lex <- lex_df %>%
  filter(clean_year >= 2010, clean_year <= 2024) %>%
  group_by(clean_year) %>%
  summarize(
    n_docs             = n(),
    pct_core_platforms = 100 * mean(has_core_platforms),
    pct_digital_surv   = 100 * mean(has_digital_surv),
    pct_analog_mail    = 100 * mean(has_analog_mail),
    platform_rate_1k   = mean(platform_rate_1k),
    surv_rate_1k       = mean(surv_rate_1k),
    .groups            = "drop"
  )

write_csv(annual_lex, "table04_direct_digital_lexicon_by_year.csv")

lex_reg_models <- bind_rows(
  tidy(lm(has_core_platforms ~ clean_year, data = filter(lex_df, clean_year >= 2010, clean_year <= 2024))) %>%
    filter(term == "clean_year") %>% mutate(Model = "Core Digital Platforms: JPay/Tablet/Kiosk/Securus/GTL (2010-2024)"),
  tidy(lm(platform_rate_1k ~ clean_year, data = filter(lex_df, clean_year >= 2010, clean_year <= 2024))) %>%
    filter(term == "clean_year") %>% mutate(Model = "Core Digital Platform Token Rate per 1k Words (2010-2024)"),
  tidy(lm(has_digital_surv ~ clean_year, data = filter(lex_df, clean_year >= 2010, clean_year <= 2024))) %>%
    filter(term == "clean_year") %>% mutate(Model = "Electronic Surveillance: Camera/Monitor/Sensor (2010-2024)")
) %>%
  select(Model, estimate, std.error, statistic, p.value)

cat("\n=== TABLE 4: DIRECT CARCERAL-DIGITAL LEXICAL REGRESSIONS ===\n")
print(as.data.frame(lex_reg_models), row.names = FALSE)
write_csv(lex_reg_models, "table04_direct_digital_lexical_regressions.csv")

plot_lex_long <- annual_lex %>%
  select(clean_year, n_docs,
         `Core Digital Platforms (JPay/Tablet/Kiosk/Securus/GTL/Electronic)` = pct_core_platforms,
         `Electronic Surveillance (Camera/Monitor/Surveillance/Sensor)`      = pct_digital_surv) %>%
  pivot_longer(cols = -c(clean_year, n_docs), names_to = "Lexicon_Domain", values_to = "Pct_Docs")

p_direct_tech <- ggplot(plot_lex_long, aes(x = clean_year, y = Pct_Docs, color = Lexicon_Domain)) +
  geom_smooth(method = "loess", se = TRUE, alpha = 0.15, linewidth = 1.2, span = 0.8) +
  geom_point(size = 2.4, alpha = 0.85) +
  geom_vline(xintercept = 2020, linetype = "dotted", color = "darkorange", linewidth = 0.9) +
  geom_vline(xintercept = 2021, linetype = "dashed", color = "black", linewidth = 0.9) +
  scale_color_manual(values = c(
    "Core Digital Platforms (JPay/Tablet/Kiosk/Securus/GTL/Electronic)" = "#2980b9",
    "Electronic Surveillance (Camera/Monitor/Surveillance/Sensor)"      = "#c0392b"
  )) +
  scale_x_continuous(breaks = seq(2010, 2024, 2)) +
  labs(
    title    = "Direct Lexical Prevalence of Carceral-Digital Hardware & Platforms (2010–2024)",
    subtitle = "Annual percentage of APWA essays explicitly mentioning prison digital platforms or electronic surveillance",
    x        = "Year of Authorship",
    y        = "% of Annual Essays Mentioning Domain Terms",
    color    = "Lexical Domain"
  ) +
  theme_bw(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), legend.position = "bottom", legend.direction = "vertical")

ggsave("fig06_direct_digital_lexical_trajectory.png", plot = p_direct_tech, width = 9.5, height = 6.8, dpi = 300)
print(p_direct_tech)

cat("\n[TASK 07 COMPLETE] Saved trajectory plots ('fig03a', 'fig03b', 'fig06') and regression tables ('table01', 'table04').\n")
