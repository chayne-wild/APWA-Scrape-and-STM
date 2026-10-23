# ==============================================================================
# MASTER PIPELINE ORCHESTRATOR: APWA CARCERAL-DIGITAL TURN
# Purpose: Executes the modular Python/R pipeline sequentially, strips Colab
#          '%%R' cell magics on the fly for CLI Rscript compatibility, routes
#          artifacts into data/ and results/ subfolders, and logs sessionInfo().
# ==============================================================================

import os
import shutil
import subprocess
import tempfile

# --- 1. EXECUTION CONFIGURATION FLAGS ---
SAFE_WORKSPACE  = '/content/drive/MyDrive/colab_apwa_folder'
RUN_SCRAPER     = False  # Set True ONLY to re-crawl and re-scrape live JHU servers (01-02)
RUN_PREPROCESS  = True   # Run Tidyverse JSONL ingestion & STM matrix creation (03)
RUN_SEARCHK     = False  # Set True to re-run computationally heavy K={10..60} grid search (04)
RUN_STM_MODEL   = True   # Train deterministic K=40 Spectral STM (05)
RUN_DOWNSTREAM  = True   # Run qualitative validation, regressions, & igraph networks (06-09)

# --- 2. DIRECTORY INITIALIZATION ---
os.makedirs(SAFE_WORKSPACE, exist_ok=True)
os.chdir(SAFE_WORKSPACE)

for folder in ['data', 'scripts', 'results/charts', 'results/figures']:
    os.makedirs(os.path.join(SAFE_WORKSPACE, folder), exist_ok=True)

def run_python_script(script_path):
    print(f"\n>>> EXECUTING PYTHON SCRIPT: {script_path}")
    subprocess.run(["python3", script_path], check=True)

def run_r_script(script_path):
    """Strips Colab '%%R' cell magic from Line 1 before executing via Rscript."""
    print(f"\n>>> EXECUTING R SCRIPT: {script_path}")
    with open(script_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Remove IPython %%R magic line so standard Rscript doesn't throw a syntax error
    clean_lines = [line for line in lines if not line.strip().startswith('%%R')]

    with tempfile.NamedTemporaryFile('w', suffix='.R', delete=False, encoding='utf-8') as tmp:
        tmp.writelines(clean_lines)
        tmp_path = tmp.name

    try:
        subprocess.run(["Rscript", tmp_path], check=True)
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

def organize_artifacts():
    """Routes flat root outputs into structured data/, results/charts/, and results/figures/ folders."""
    routing_map = {
        'data': [
            'apwa_master_urls.csv', 'apwa_parsed_archive.jsonl', 'apwa_excluded_urls.csv',
            'apwa_clean_corpus.rds', 'apwa_stm_out_object.rds', 'apwa_searchK_results.rds',
            'apwa_stm_model_k40_final.rds', 'apwa_prep_tripartite_effects.rds',
            'apwa_topic_correlations.rds'
        ],
        'results/charts': [
            'top_topic_words_k40.csv', 'qualitative_exemplar_essays.txt',
            'table01_prefigurative_regressions.csv', 'table01_prefigurative_regressions.html',
            'table02_covid_utility_correlation.csv', 'table03_economy_of_scarcity_correlation.csv'
        ],
        'results/figures': [
            'fig01_searchK_diagnostics.png', 'fig02_tripartite_trajectories_full.png',
            'fig03_tripartite_trajectories_2010_2024.png',
            'fig04_pandemic_catalyst_ratchet_effect.png',
            'fig05a_topic_correlation_network_stm.png',
            'fig05b_topic_correlation_network_igraph.png'
        ]
    }
    for target_dir, files in routing_map.items():
        for filename in files:
            if os.path.exists(filename):
                dest = os.path.join(target_dir, filename)
                shutil.copy2(filename, dest)
                print(f"Copied '{filename}' -> '{dest}'")

def export_session_info():
    """Writes R sessionInfo() to results/session_info.txt for computational reproducibility."""
    r_cmd = 'writeLines(capture.output(sessionInfo()), "results/session_info.txt")'
    subprocess.run(["Rscript", "-e", r_cmd], check=True)
    print("Exported R environment specifications to 'results/session_info.txt'.")

if __name__ == "__main__":
    if RUN_SCRAPER:
        run_python_script("scripts/01_index_apwa_urls.py")
        run_python_script("scripts/02_scrape_apwa_archive.py")

    if RUN_PREPROCESS:
        run_r_script("scripts/03_tidy_preprocessing.R")

    if RUN_SEARCHK:
        run_r_script("scripts/04_stm_searchK_diagnostics.R")

    if RUN_STM_MODEL:
        run_r_script("scripts/05_stm_model_training_k40.R")

    if RUN_DOWNSTREAM:
        run_r_script("scripts/06_qualitative_validation.R")
        run_r_script("scripts/07_temporal_regressions.R")
        run_r_script("scripts/08_pandemic_catalyst.R")
        run_r_script("scripts/09_network_analysis_igraph.R")

    organize_artifacts()
    export_session_info()
    print("\n[MASTER PIPELINE COMPLETE] All artifacts organized into data/ and results/.")
