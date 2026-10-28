Repository Script Sequence (Google Colab Execution Order)

| Script File | Language | Single Task Accomplished | Output Artifact(s) |
| :--- | :--- | :--- | :--- |
| `00_colab_environment_setup.py` | Python / R | Mounts Google Drive, locks working directory, activates `rpy2` R-Magic, and installs R packages. | Configured Colab Runtime |
| `01_index_apwa_urls.py` | Python | Paginates through all 181 archive pages to map and collect all unique essay URLs. | `apwa_master_urls.csv` |
| `02_scrape_apwa_archive.py` | Python | Scrapes raw transcripts and metadata blocks into JSONL; logs untranscribed image/PDF pages. | `apwa_parsed_archive.jsonl`, `apwa_excluded_urls.csv` |
| `03_tidy_preprocessing.R` | R (`%%R`) | Fault-tolerant JSONL ingestion, year extraction, `tidytext` tokenization, `textstem` lemmatization, "Plural Bypass" stop-word removal, and STM matrix creation. | `apwa_clean_corpus.rds`, `apwa_stm_out_object.rds` |
| `04_stm_searchK_diagnostics.R` | R (`%%R`) | Runs `searchK` across $K \in \{10, 20, 30, 40, 50, 60\}$ and plots diagnostic metrics to justify $K=40$. | `apwa_searchK_results.rds`, `fig01_searchK_diagnostics.png` |
| `05_stm_model_training_k40.R` | R (`%%R`) | Trains the final deterministic $K=40$ STM (`init.type = "Spectral"`) with `clean_year` prevalence prior. | `apwa_stm_model_k40_final.rds` |
| `06_qualitative_validation.R` | R (`%%R`) | Extracts `FREX` and `Highest Prob` matrices (`labelTopics`) and pulls top full-text essays (`findThoughts`). | `top_topic_words_k40.csv`, `qualitative_exemplar_essays.txt` |
| `07_temporal_regressions.R` | R (`%%R`) | Estimates B-spline temporal trajectories (`estimateEffect`), runs Surge-Era OLS regressions (2010–2021 vs. 2016–2021), and exports publication tables. | `apwa_prep_tripartite_effects.rds`, `fig02_tripartite_trajectories_full.png`, `fig03_tripartite_trajectories_2010_2024.png`, `table01_prefigurative_regressions.csv`, `table01_prefigurative_regressions.html` |
| `08_pandemic_catalyst.R` | R (`%%R`) | Plots T32 (Utility) vs. T21 (COVID-19) ("Ratchet Effect") and runs $\theta$ Pearson correlation test. | `fig04_pandemic_catalyst_ratchet_effect.png`, `table02_covid_utility_correlation.csv` |
| `09_network_analysis_igraph.R` | R (`%%R`) | Generates the 40-topic correlation network (`topicCorr` & `igraph`) isolating the T18–T26 "Economy of Scarcity" link. | `apwa_topic_correlations.rds`, `fig05a_topic_correlation_network_stm.png`, `fig05b_topic_correlation_network_igraph.png`, `table03_economy_of_scarcity_correlation.csv` |
