%%R
# ==============================================================================
# SCRIPT 05: TRAIN FINAL K = 40 STRUCTURAL TOPIC MODEL (R)
# Task: Train the deterministic K = 40 STM using Spectral initialization and
#       inject 'clean_year' into the topic prevalence prior distribution.
# ==============================================================================

library(tidyverse)
library(stm)

safe_workspace <- "/content/drive/MyDrive/colab_apwa_folder"
if (getwd() != safe_workspace) setwd(safe_workspace)

out <- readRDS("apwa_stm_out_object.rds")
model_file <- "apwa_stm_model_k40_final.rds"
FORCE_RETRAIN <- FALSE # Set TRUE to force re-estimation even if saved model exists

if (file.exists(model_file) && !FORCE_RETRAIN) {
  final_model <- readRDS(model_file)
  cat("Loaded existing converged K = 40 STM from 'apwa_stm_model_k40_final.rds'.\n")
} else {
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
  saveRDS(final_model, file = model_file, compress = FALSE)
  cat("\n[TASK 05 COMPLETE] Final K=40 model saved to 'apwa_stm_model_k40_final.rds'.\n")
}
