# %%R <- uncomment this if running inside python / colab
# ==============================================================================
# SCRIPT 09: TOPIC CORRELATION NETWORK & THE ECONOMY OF SCARCITY (R / IGRAPH)
# ==============================================================================

library(tidyverse)
library(stm)
library(igraph)
library(broom)

safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

final_model <- readRDS("apwa_stm_model_k40_final.rds")
topic_map   <- readRDS("resolved_target_topics_k40.rds")

T_CONNECTION   <- topic_map$Resolved_Topic[topic_map$Code == "T_CONNECTION"]
T_UTILITY      <- topic_map$Resolved_Topic[topic_map$Code == "T_UTILITY"]
T_SURVEILLANCE <- topic_map$Resolved_Topic[topic_map$Code == "T_SURVEILLANCE"]
T_COVID        <- topic_map$Resolved_Topic[topic_map$Code == "T_COVID"]
T_COMMISSARY   <- topic_map$Resolved_Topic[topic_map$Code == "T_COMMISSARY"]
T_ECONOMY      <- topic_map$Resolved_Topic[topic_map$Code == "T_ECONOMY"]

# 1. Estimate Topic Correlation Matrix
cormat <- topicCorr(final_model, method = "simple", cutoff = 0.03)
saveRDS(cormat, file = "apwa_topic_correlations.rds")

# 2. Export Standard STM Network Graph (Figure 05A)
png("fig05a_topic_correlation_network_stm.png", width = 2400, height = 2400, res = 300)
plot(
  cormat,
  vertex.color     = "lightblue",
  vertex.label.cex = 0.85,
  main             = "Topic Correlation Network (K = 40)"
)
dev.off()

# 3. Export Enhanced Publication Network Graph via igraph (Figure 05B)
g <- graph_from_adjacency_matrix(cormat$posadj, mode = "undirected", diag = FALSE)
V(g)$name <- sprintf("T%02d", 1:40)

node_colors <- rep("#dfe6e9", 40)
node_colors[T_CONNECTION]   <- "#3498db" # Mail, Grievance & Tablets (Blue)
node_colors[T_ECONOMY]      <- "#8e44ad" # Money, Wages & Phone Calls (Dark Purple)
node_colors[T_COMMISSARY]   <- "#d2b4de" # Food, Commissary & JPay (Light Purple)
node_colors[T_UTILITY]      <- "#2ecc71" # Educational Utility (Green)
node_colors[T_SURVEILLANCE] <- "#e74c3c" # Institutional Rules & Control (Red)
node_colors[T_COVID]        <- "#f39c12" # COVID-19 Quarantine & Kiosks (Orange)

V(g)$color <- node_colors

png("fig05b_topic_correlation_network_igraph.png", width = 2600, height = 2600, res = 300)
set.seed(42)
plot(
  g,
  layout             = layout_with_fr(g),
  vertex.size        = 13,
  vertex.color       = V(g)$color,
  vertex.frame.color = "#2d3436",
  vertex.label.cex   = 0.80,
  vertex.label.color = "black",
  vertex.label.font  = 2,
  edge.lty           = 1,
  edge.width         = 2.0,
  edge.color         = "#636e72",
  main               = "APWA Topic Correlation Network (K=40): Socio-Technical & Scarcity Nodes"
)
legend(
  "bottomleft",
  legend = c(
    sprintf("T%02d: Mail, Grievance & Tablets/Phones", T_CONNECTION),
    sprintf("T%02d: Money, Wages & Phone Calls (Linked to T%02d)", T_ECONOMY, T_COMMISSARY),
    sprintf("T%02d: Food, Commissary & JPay (Linked to T%02d)", T_COMMISSARY, T_ECONOMY),
    sprintf("T%02d: Educational & Program Utility", T_UTILITY),
    sprintf("T%02d: Institutional Rules & Control", T_SURVEILLANCE),
    sprintf("T%02d: COVID-19 Quarantine & Kiosks", T_COVID),
    "Other Archive Topics"
  ),
  pt.bg  = c("#3498db", "#8e44ad", "#d2b4de", "#2ecc71", "#e74c3c", "#f39c12", "#dfe6e9"),
  pch    = 21,
  pt.cex = 1.8,
  cex    = 0.85,
  bty    = "n"
)
dev.off()

# 4. Statistical Verification of the Economy of Scarcity Correlations (Table 03)
theta_mat <- final_model$theta

tidy_scarcity <- bind_rows(
  tidy(cor.test(theta_mat[, T_COMMISSARY], theta_mat[, T_ECONOMY], method = "pearson")) %>%
    mutate(comparison = sprintf("Food/Commissary/JPay (T%02d) vs. Money/Wages/Calls (T%02d)", T_COMMISSARY, T_ECONOMY)),
  tidy(cor.test(theta_mat[, T_CONNECTION], theta_mat[, T_ECONOMY], method = "pearson")) %>%
    mutate(comparison = sprintf("Mail/Grievance/Tablets (T%02d) vs. Money/Wages/Calls (T%02d)", T_CONNECTION, T_ECONOMY)),
  tidy(cor.test(theta_mat[, T_CONNECTION], theta_mat[, T_COMMISSARY], method = "pearson")) %>%
    mutate(comparison = sprintf("Mail/Grievance/Tablets (T%02d) vs. Food/Commissary/JPay (T%02d)", T_CONNECTION, T_COMMISSARY))
) %>%
  select(comparison, estimate, statistic, p.value, parameter, conf.low, conf.high)

write_csv(tidy_scarcity, "table03_economy_of_scarcity_correlation.csv")

cat("\n=== ECONOMY OF SCARCITY CORRELATION TESTS ===\n")
print(as.data.frame(tidy_scarcity), row.names = FALSE)
cat("\n[TASK 09 COMPLETE] Saved 'fig05a', 'fig05b', and 'table03_economy_of_scarcity_correlation.csv'.\n")
