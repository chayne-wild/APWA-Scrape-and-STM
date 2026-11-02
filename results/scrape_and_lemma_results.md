**Yes, everything ran 100% correctly with zero errors!** 

Both of your output files (`apwa_clean_corpus.rds` and `apwa_stm_out_object.rds`) are now safely saved to your Google Drive and ready for your STM modeling script.

Furthermore, the numbers printed in this log are the exact statistics you will want to report in the **Data & Methods section** of your paper. Here is a breakdown of what each section of the output means:

---

### 1. Corpus Ingestion & Temporal Filtering
```text
Successfully loaded 3714 valid transcribed documents.
Dropped 1 document(s) missing a verifiable 4-digit year (1965-2026).
Temporally normalized corpus size: 3713 documents.
```
* **Zero Corrupted JSONs:** Notice that the script did *not* print `"Bypassed corrupted JSON records..."`. That means every single line of your `.jsonl` file parsed cleanly.
* **3,714 Unique Documents:** After deduplicating by `slug`, you had 3,714 valid essays/transcripts.
* **3,713 Temporally Valid Documents:** Only **1 document** in the entire archive was missing a valid 4-digit year (or had an empty transcript) and was dropped. Your final dataset has **3,713 documents**.

---

### 2. Lemmatizer Audit Table
```text
--- Diagnostic Audit of Domain-Guarded Lemmatizer ---
 original_token mapped_lemma
          copes         cope
         coping       coping
          coped         cope
           cops          cop
          wound        wound
...
```
* This confirms that your custom override dictionary worked as intended: psychological coping (`copes`/`coped` $\rightarrow$ `cope`, `coping` $\rightarrow$ `coping`) was kept completely separate from police (`cops` $\rightarrow$ `cop`), `wound` was not mis-lemmatized into `wind`, and institutional terms (`hearing`, `housing`, `programming`) were protected from collapsing into generic verbs.

---

### 3. Vocabulary & Token Pruning (`prepDocuments`)
```text
Removing 26371 of 51216 terms (26371 of 1040320 tokens) due to frequency 
Your corpus now has 3713 documents, 24845 terms and 1013949 tokens.
Final synchronized STM corpus: 3713 documents and 24845 unique vocabulary terms.
```
This is the most important mathematical diagnostic in the output:
* **1,040,320 Initial Cleaned Tokens:** After removing stop-words, possessives, and words under 3 letters, your corpus contained over **1.04 million total word occurrences**, made up of **51,216 unique words (terms)**. *(This also shows why the optimization was so fast: R only had to lemmatize ~51k unique words instead of >1 million rows!)*
* **Pruning *Hapax Legomena* (`lower.thresh = 1`):** Notice that `prepDocuments` removed **26,371 terms** and **26,371 tokens**. Because the number of terms removed equals the exact number of tokens removed, every single one of those 26,371 words appeared **only once** in the entire 3,713-document archive (mostly OCR typos, rare proper names, or misspellings).
* **Zero Documents Lost in Pruning:** Your document count stayed at **3,713** before and after `prepDocuments()`. Not a single document was emptied out by the pruning.
* **Final STM Matrix Size:** Your STM model will train on **3,713 documents**, a vocabulary of **24,845 unique lemmas**, and **1,013,949 total tokens**.

---

### 4. Two Minor Quirks in the Log (Totally Normal)

1. **Why did package messages (`jsonlite`, `koRpus`, `stm`) print at the very bottom?**
   In Google Colab, `%%R` uses two separate text streams: Standard Output (`stdout`, used by `cat()` and `print()`) and Standard Message/Error (`stderr`, used by `library()` startup notifications). Colab prints all of your script's `cat()` statements first, and then dumps all the harmless `library()` startup notifications at the very end of the cell.
2. **Why did it say `"Multi-core CPU acceleration ENABLED with 1 workers"`?**
   Standard Google Colab instances only provide **2 virtual CPU cores** (`detectCores()` = 2). Because the script used `detectCores() - 1` (standard practice on laptops to leave 1 core free for the operating system), `2 - 1 = 1`. In future scripts on Colab, if you want to use both virtual cores, you can just use `workers = parallel::detectCores()`.
