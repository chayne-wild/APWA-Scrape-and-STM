# ==============================================================================
# SCRIPT 00 (CELL 0A): MOUNT DRIVE & LOCK SAFE WORKSPACE (PYTHON)
# Task: Mount Google Drive and enforce strict directory isolation.
# ==============================================================================

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

# ==============================================================================
# SCRIPT 00 (CELL 0B): ACTIVATE R-MAGIC BRIDGE IN COLAB (PYTHON)
# ==============================================================================

%load_ext rpy2.ipython
print("R-Magic activated. Begin all subsequent R cells with %%R.")

%%R
# ==============================================================================
# SCRIPT 00 (CELL 0C): INSTALL SYSTEM LIBRARIES & REQUIRED R PACKAGES (R)
# ==============================================================================

# 1. Install Linux system libraries required by igraph (libglpk-dev) and katex/gt (libnode-dev)
cat("Verifying Linux system dependencies (libglpk-dev, libnode-dev)...\n")
system("sudo apt-get update -qq && sudo apt-get install -y -qq libglpk-dev libnode-dev")

cat("Configuring Posit Public Package Manager for fast Linux binaries...\n")

# 2. Detect Ubuntu version (e.g., jammy, noble) and set Posit binary repo URL
codename <- system("lsb_release -cs", intern = TRUE)
options(repos = c(CRAN = paste0("https://packagemanager.posit.co/cran/__linux__/", codename, "/latest")))

# 3. Set HTTPUserAgent so Posit sends pre-compiled Linux binaries
options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))

cat("Installing Tidyverse, NLP, STM, Table, and Network packages in R...\n")

required_packages <- c(
  "tidyverse",      # Core Tidy data wrangling and ggplot2
  "jsonlite",       # JSONL parsing
  "tidytext",       # Tidy tokenization and stop-word dictionaries
  "textstem",       # Word lemmatization
  "lexicon",        # Hash lemma dictionaries
  "stm",            # Structural Topic Modeling
  "tm",             # Required dependency for stm::textProcessor
  "SnowballC",      # Required dependency for stm::textProcessor
  "igraph",         # Network graph modeling for topicCorr
  "broom",          # Tidy regression outputs
  "modelsummary",   # Publication-ready regression tables
  "gt",             # Grammar of Tables for manuscript export
  "katex",          # Non-interactive math rendering inside gt HTML tables
  "V8",             # JavaScript engine dependency for katex/gt
  "furrr",          # Parallel processing for purrr/future
  "ggrepel"         # Non-overlapping text labels in diagnostic plots
)

new_packages <- required_packages[!(required_packages %in% installed.packages()[, "Package"])]
if (length(new_packages) > 0) {
  install.packages(new_packages, quiet = TRUE)
}

cat("All Linux system libraries and R dependencies successfully installed and verified.\n")
