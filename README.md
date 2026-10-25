# Prefiguring the Carceral-Digital Turn: A Computational Linguistic Analysis of the American Prison Writing Archive (APWA)

## 1. Project Overview & Research Question
**Driving Research Question:** *How have incarcerated writers in the American Prison Writing Archive (APWA) discussed and documented the "carceral-digital turn," and did their critiques prefigure mainstream academic literature?*

The "carceral-digital turn" refers to the rapid introduction of digital tablets, electronic messaging kiosks (e.g., JPay, GTL/ViaPath, Securus), and biometric surveillance into correctional facilities. Mainstream academic consensus—largely codified around **2021**—characterizes this technological shift through a dual frame: **the commodification of connection** (extracting wealth from incarcerated people and their families under the guise of rehabilitation) and **the expansion of carceral control** (intensifying state surveillance and data collection).

This project tests the **Prefiguration Hypothesis**: the proposition that incarcerated intellectuals and writers were actively theorizing, documenting, and critiquing the structural mechanics of the carceral-digital turn *years prior* to its 2021 codification in outside academic scholarship.

---

## 2. Summary of Key Empirical Findings
Using unsupervised **Structural Topic Modeling (STM)** ($K = 40$) on **3,657 temporally normalized essays** from the APWA, combined with B-spline temporal regressions, era-specific linear models, and network correlation analysis (`igraph`), this study establishes three primary findings:

1. **The Tri-Partite Discursive Framework:** Incarcerated writers do not conceptualize technology as a monolith, nor do they rely on a simple binary. Instead, the unsupervised model isolated three mathematically distinct discursive frames:
   * **Topic 18 (Interpersonal Connection):** `kiosk, jpay, gtl, tablet, phone, family` — Early adoption and daily relational maintenance.
   * **Topic 32 (Intellectual Utility):** `tablet, learn, program, education, reading` — Digital devices as tools for self-directed pedagogy and programming.
   * **Topic 37 (State Surveillance):** `digital, surveillance, control, society, system` — Macro-structural critiques of technological monitoring and state power.
2. **Prefigurative Surge & The Pandemic "Ratchet Effect":** 
   * While interpersonal connection discourse (T18) peaked around 2017 ("the honeymoon phase") and subsequently plateaued ($p = 0.331$ from 2016–2021), critiques of state surveillance (T37) entered a sharp upward trajectory beginning in 2018—directly prefiguring the 2021 academic baseline ($p < 0.001$).
   * Plotting Topic 32 (Intellectual Utility) against **Topic 21 (COVID-19 / Quarantine: `unit, staff, virus, quarantine, pandemic`)** reveals a permanent infrastructural **Ratchet Effect**. When physical facilities locked down in 2020, digital utility spiked in tandem with bio-security discourse. However, while COVID-19 discourse receded by 2022, digital utility *never returned to its pre-2020 baseline*. Furthermore, a document-level Pearson correlation test on the $\theta$ matrix ($r = -0.045, p = 0.0064$) proves that T21 and T32 are mutually exclusive within individual essays: writers experienced the digital shift concurrently with, yet discursively separate from, the biological crisis.
3. **The Economy of Scarcity (Network Analysis):**
   * Mapping the macro-structure of the archive via `topicCorr` and `igraph` reveals that the three technology topics operate as compartmentalized "floating islands." 
   * Crucially, a single structural tie emerged linking **Topic 18 (Interpersonal Connection)** to **Topic 26 (Commissary/Food: `food, eat, meal, noodle, calorie, cheese`)**. Incarcerated writers explicitly situate digital communication within the carceral economy of scarcity, recognizing that electronic stamps/tablet minutes and supplemental nutrition are extracted from the exact same finite resource: the inmate trust account.

---

## 3. Methodological Architecture: Python and R, RMagic (rpy2)
To ensure reproducibility and adherence to **Tidy Data Principles**, the computational pipeline is strictly partitioned by language and function:
- **Python (Data Acquisition Only):** Used exclusively for polite, rate-limited web scraping, DOM heuristic parsing, and raw JSONL serialization (`01` and `02`). **Zero** data cleaning or NLP preprocessing occurs in Python.
- **R / Tidyverse (Preprocessing, NLP, & Statistical Modeling):** Used exclusively for fault-tolerant JSONL ingestion, regex temporal normalization, `tidytext` tokenization, `textstem` lemmatization, the "Plural Bypass" custom stop-word filter, STM matrix factorization, regression modeling, and visualization (`03` through `09`).
- **Rmagic in Google Colab, Stanford Library:** [https://guides.library.stanford.edu/programmatic_access_gdrive/r_colab](https://guides.library.stanford.edu/programmatic_access_gdrive/r_colab)

---

## 4. Ethical & Institutional Compliance
The APWA is hosted by Johns Hopkins University (`prisonwitness.org`) with the mission of bearing witness to the lived reality of incarceration. Because incarcerated authors write under conditions of extreme vulnerability and surveillance, our extraction protocol prioritized ethical non-interference and server respect:
- **`robots.txt` & Terms of Service Compliance:** Verified against [https://prisonwitness.org/robots.txt](https://prisonwitness.org/robots.txt) (`Allow: /`) and the Johns Hopkins University Library Privacy Policy. No unlisted Personally Identifiable Information (PII) was collected.
- **Polite Bot Identification:** All HTTP requests transmitted an explicit academic `User-Agent` header (`APWA_Virginia_Tech_Research_Bot/1.0 (chayne@vt.edu)`).
- **Rate Limiting & Fault Tolerance:** Index scraping enforced randomized delays (`1.5` to `3.0` seconds) between requests, and concurrent essay extraction used local state-tracking (`apwa_master_urls.csv` and `apwa_excluded_urls.csv`) to prevent redundant server queries.

### Archival Snapshots (Wayback Machine)
- **APWA Main Page:** [https://web.archive.org/web/20260915215456/https://prisonwitness.org/](https://web.archive.org/web/20260915215456/https://prisonwitness.org/)
- **APWA About Page:** [https://web.archive.org/web/20260915215555/https://prisonwitness.org/about-the-archive/](https://web.archive.org/web/20260915215555/https://prisonwitness.org/about-the-archive/)
- **JHU Library Privacy Policy:** [https://web.archive.org/web/20260915215139/https://www.library.jhu.edu/policies/privacy/](https://web.archive.org/web/20260915215139/https://www.library.jhu.edu/policies/privacy/)

---

## Suggested Citation

**Text Citation (APA / ASA Style):**
> Wild, Chayne. 2026. *Prefiguring the Carceral-Digital Turn: A Computational Linguistic Analysis of the American Prison Writing Archive (APWA)* (Version 1.0.0) [Computer software]. Virginia Tech. https://github.com/chayne-wild/apwa-scrape-and-stm

**BibTeX (Zotero / LaTeX / Better BibTeX):**
```bibtex
@software{wild2026apwa,
  author       = {Wild, Chayne},
  title        = {Prefiguring the Carceral-Digital Turn: A Computational Linguistic Analysis of the American Prison Writing Archive (APWA)},
  year         = {2026},
  month        = {10},
  version      = {1.0.0},
  organization = {Alliance for Social, Political, Ethical, and Cultural Thought (ASPECT), Virginia Tech},
  url          = {[https://github.com/chayne-wild/apwa-scrape-and-stm](https://github.com/chayne-wild/apwa-scrape-and-stm)},
  note         = {Replication code and Structural Topic Modeling (STM) pipeline}
}
```

**Archival Source Attribution:**
> American Prison Writing Archive (APWA). Johns Hopkins University Sheridan Libraries. [https://prisonwitness.org/](https://prisonwitness.org/)

