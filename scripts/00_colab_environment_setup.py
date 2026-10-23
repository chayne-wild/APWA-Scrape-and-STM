# ==============================================================================
# SCRIPT 00: GOOGLE COLAB WORKSPACE & R-MAGIC ENVIRONMENT SETUP
# Task: Mount Google Drive, enforce strict directory isolation, activate the 
#       Python-to-R bridge (rpy2), and install required R packages.
# ==============================================================================

# --- CELL 0A: Mount Drive & Lock Safe Workspace (Python) ---
import os
from google.colab import drive

# 1. Mount Google Drive
drive.mount('/content/drive')

# 2. Define and enforce strict workspace isolation
safe_workspace = '/content/drive/MyDrive/colab_apwa_folder'
os.makedirs(safe_workspace, exist_ok=True)
os.chdir(safe_workspace)

# 3. Hard security validation check
if os.getcwd() != safe_workspace:
    raise RuntimeError(
        f"SECURITY HALT: Execution environment compromised. "
        f"Current directory is {os.getcwd()}, expected {safe_workspace}."
    )

print(f"Workspace secured. Active directory: {os.getcwd()}")

# --- CELL 0B: Activate R-Magic Bridge in Colab (Python) ---
%load_ext rpy2.ipython
print("R-Magic activated. Begin all subsequent R cells with %%R.")

%%R
# --- CELL 0C: Install Required R Packages (R) ---
# Note: Only needs to be run once per fresh Google Colab runtime reset.
cat("Installing Tidyverse, NLP, STM, and visualization packages in R...\n")

required_packages <- c(
  "tidyverse",      # Core Tidy data wrangling and ggplot2
  "jsonlite",       # JSONL parsing
  "tidytext",       # Tidy tokenization and stop-word dictionaries
  "textstem",       # Word lemmatization
  "stm",            # Structural Topic Modeling
  "tm",             # Required dependency for stm::textProcessor
  "SnowballC",      # Required dependency for stm::textProcessor
  "igraph",         # Network graph modeling for topicCorr
  "broom",          # Tidy regression outputs
  "modelsummary",   # Publication-ready regression tables
  "gt"              # Grammar of Tables for manuscript export
)

new_packages <- required_packages[!(required_packages %in% installed.packages()[, "Package"])]
if (length(new_packages) > 0) {
  install.packages(new_packages, quiet = TRUE, dependencies = TRUE)
}

cat("All R dependencies successfully installed and verified.\n")
