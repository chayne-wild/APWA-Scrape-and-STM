%%R
# ==============================================================================
# SCRIPT 05: TRAIN FINAL K = 40 STRUCTURAL TOPIC MODEL (R)
# Task: Train the deterministic K = 40 STM using Spectral initialization and
#       inject 'clean_year' into the topic prevalence prior distribution.
#       Serialize the converged model to 'apwa_stm_model_k40_final.rds'.
# ==============================================================================

library(tidyverse)
library(stm)

# 1. Verify Workspace & Load STM Matrix Object
safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

out <- readRDS("apwa_stm_out_object.rds")

# 2. Train the Final K = 40 Structural Topic Model
# Rationale: Spectral initialization is deterministic and guarantees global
# stability without sensitivity to random starting seeds.
cat("Training final K = 40 Structural Topic Model...\n")
set.seed(42)

final_model <- stm(
  documents  = out$documents,
  vocab      = out$vocab,
  K          = 40,
  prevalence = ~ s(clean_year),
  data       = out$meta,
  init.type  = "Spectral",
  verbose    = TRUE
)

# 3. Serialize Converged Model to Disk
saveRDS(final_model, file = "apwa_stm_model_k40_final.rds")

cat("\n[TASK 05 COMPLETE] Final K=40 model saved to 'apwa_stm_model_k40_final.rds'.\n")
