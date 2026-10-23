%%R
# ==============================================================================
# SCRIPT 09: TOPIC CORRELATION NETWORK & THE ECONOMY OF SCARCITY (R / IGRAPH)
# Task: 1. Compute the MAP topic correlation network across all 40 topics using
#          stm::topicCorr(cutoff = 0.05).
#       2. Visualize the network via igraph, highlighting our target topics to
#          demonstrate both the compartmentalization of tech discourses and the
#          T18 (Connection) <-> T26 (Commissary/Food) "Economy of Scarcity" link.
# ==============================================================================

library(tidyverse)
library(stm)
library(igraph)
library(broom)

# 1. Verify Workspace & Load Final Model
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

final_model <- readRDS("apwa_stm_model_k40_final.rds")

# 2. Estimate Topic Correlation Matrix
# Rationale: Calculates positive covariance across document-topic proportions.
cormat <- topicCorr(final_model, method = "simple", cutoff = 0.05)
saveRDS(cormat, file = "apwa_topic_correlations.rds")

# 3. Export Standard STM Network Graph (Replication Benchmark)
png("fig05a_topic_correlation_network_stm.png", width = 2400, height = 2400, res = 300)
plot(
  cormat,
  vertex.color     = "lightblue",
  vertex.label.cex = 0.85,
  main             = "Topic Correlation Network (K=40)"
)
dev.off()

# 4. Build Enhanced Publication Network Graph via igraph
# Highlighting Target Nodes: T18 (Connection), T32 (Utility), T37 (Surveillance),
# T21 (COVID-19), and T26 (Commissary/Food).
g <- graph_from_adjacency_matrix(cormat$posadj, mode = "undirected", diag = FALSE)
V(g)$name <- paste0("Topic ", 1:40)

# Color-code target nodes vs. general archive topics
node_colors <- rep("#b2bec3", 40)
node_colors[18] <- "#3498db" # Interpersonal Connection (Blue)
node_colors[32] <- "#2ecc71" # Intellectual Utility (Green)
node_colors[37] <- "#e74c3c" # State Surveillance (Red)
node_colors[21] <- "#f39c12" # COVID-19 / Quarantine (Orange)
node_colors[26] <- "#9b59b6" # Commissary / Food (Purple)

V(g)$color <- node_colors

png("fig05b_topic_correlation_network_igraph.png", width = 2600, height = 2600, res = 300)
set.seed(42)
plot(
  g,
  layout             = layout_with_fr(g),
  vertex.size        = 13,
  vertex.color       = V(g)$color,
  vertex.frame.color = "#2d3436",
  vertex.label.cex   = 0.75,
  vertex.label.color = "black",
  vertex.label.font  = 2,
  edge.lty           = 2,
  edge.width         = 1.8,
  edge.color         = "#636e72",
  main               = "APWA Topic Correlation Network (K=40): Isolating the Economy of Scarcity"
)
legend(
  "bottomleft",
  legend = c(
    "T18: Interpersonal Connection",
    "T26: Commissary / Food (Linked to T18)",
    "T32: Intellectual Utility (Isolated)",
    "T37: State Surveillance (Isolated)",
    "T21: COVID-19 / Quarantine (Isolated)",
    "Other Archive Topics"
  ),
  pt.bg  = c("#3498db", "#9b59b6", "#2ecc71", "#e74c3c", "#f39c12", "#b2bec3"),
  pch    = 21,
  pt.cex = 1.8,
  cex    = 0.85,
  bty    = "n"
)
dev.off()

# 5. Direct Statistical Verification of the T18 (Connection) <-> T26 (Commissary) Tie
cor_scarcity <- cor.test(
  x      = final_model$theta[, 18],
  y      = final_model$theta[, 26],
  method = "pearson"
)

tidy_scarcity <- tidy(cor_scarcity) %>%
  mutate(comparison = "Topic 18 (Interpersonal Connection) vs. Topic 26 (Commissary/Food)") %>%
  select(comparison, estimate, statistic, p.value, parameter, conf.low, conf.high)

write_csv(tidy_scarcity, "table03_economy_of_scarcity_correlation.csv")

cat("\n=== ECONOMY OF SCARCITY LINK (T18 vs. T26) ===\n")
print(tidy_scarcity)

cat("\n[TASK 09 COMPLETE] All pipeline scripts, figures, and tables finished!\n")
