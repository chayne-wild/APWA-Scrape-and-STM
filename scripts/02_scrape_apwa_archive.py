# ==============================================================================
# SCRIPT 02: SCRAPE APWA ESSAY TRANSCRIPTS & METADATA TO JSONL (PYTHON)
# Task: Read 'apwa_master_urls.csv', concurrently scrape each essay page using
#       DOM structural heuristics ('\nDetails\n' and '\nTranscript\n'), write
#       raw JSON records to 'apwa_parsed_archive.jsonl', and log untranscribed
#       PDF/Image-only pages to 'apwa_excluded_urls.csv'.
# Note: ZERO text cleaning or temporal regexing is performed here.
# ==============================================================================

import os
import requests
import json
import csv
import threading
from bs4 import BeautifulSoup
from concurrent.futures import ThreadPoolExecutor, as_completed

# 1. Strict Workspace Verification
safe_workspace = '/content/drive/MyDrive/colab_apwa_folder'
os.makedirs(safe_workspace, exist_ok=True)
os.chdir(safe_workspace)

if os.getcwd() != safe_workspace:
    raise RuntimeError(f"SECURITY HALT: Current directory is {os.getcwd()}, expected {safe_workspace}.")

# 2. File & Concurrency Configuration
master_csv = 'apwa_master_urls.csv'
output_file = 'apwa_parsed_archive.jsonl'
excluded_csv = 'apwa_excluded_urls.csv'

headers = {
    'User-Agent': 'APWA_Virginia_Tech_Research_Bot/1.0 (chayne@vt.edu)'
}

MAX_WORKERS = 15  # Concurrent threads (reduce if server returns HTTP 429)
BATCH_SIZE = 50   # Number of records buffered before flushing to Google Drive

# Thread-safe locks and memory buffers
write_lock = threading.Lock()
json_buffer = []
excluded_buffer = []
success_count = 0
excluded_count = 0

def flush_buffers():
    """Flushes in-memory buffers to disk in a single thread-safe I/O operation."""
    global json_buffer, excluded_buffer

    if json_buffer:
        with open(output_file, 'a', encoding='utf-8') as f_out:
            f_out.write('\n'.join(json_buffer) + '\n')
            f_out.flush()
        json_buffer.clear()

    if excluded_buffer:
        with open(excluded_csv, 'a', encoding='utf-8', newline='') as f_ex:
            writer = csv.writer(f_ex)
            writer.writerows(excluded_buffer)
            f_ex.flush()
        excluded_buffer.clear()

def parse_apwa_page(url):
    """
    Fetches an APWA essay page and isolates typed transcripts from metadata
    using explicit DOM string-partitioning boundaries.
    """
    try:
        response = requests.get(url, headers=headers, timeout=15)
        if response.status_code == 429:
            print(f"RATE LIMITED (429) on {url}")
            return (url, None)

        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')

        # Strip non-text script and style elements
        for element in soup(["script", "style"]):
            element.extract()

        page_text = soup.get_text(separator='\n', strip=True)

        # Heuristic 1: Isolate the Metadata block
        if '\nDetails\n' in page_text:
            main_content, _, metadata_block = page_text.partition('\nDetails\n')
        else:
            return (url, None)

        # Heuristic 2: Isolate the typed Transcript (skips scan/PDF-only pages)
        if '\nTranscript\n' in main_content:
            _, _, transcript_text = main_content.partition('\nTranscript\n')
        else:
            return (url, None)

        transcript_text = transcript_text.strip()
        metadata_block, _, _ = metadata_block.partition('\nIf this is your essay')
        meta_lines = [line.strip() for line in metadata_block.split('\n') if line.strip()]

        # Pair alternating metadata keys and values into a raw dictionary
        metadata = {}
        for i in range(0, len(meta_lines) - 1, 2):
            metadata[meta_lines[i]] = meta_lines[i + 1]

        return (url, {
            'url': url,
            'slug': url.strip('/').split('/')[-1],
            'transcript': transcript_text,
            'metadata': metadata
        })

    except Exception:
        return (url, None)

# 3. State Synchronization & Execution Block
if __name__ == "__main__":
    if not os.path.exists(master_csv):
        raise FileNotFoundError(f"Master CSV '{master_csv}' not found. Run Script 01 first.")

    processed_urls = set()

    # Load previously scraped valid URLs
    if os.path.exists(output_file):
        with open(output_file, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    data = json.loads(line)
                    if 'url' in data:
                        processed_urls.add(data['url'])
                except json.JSONDecodeError:
                    continue

    # Load previously excluded URLs
    if os.path.exists(excluded_csv):
        with open(excluded_csv, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            next(reader, None)
            for row in reader:
                if row:
                    processed_urls.add(row[0])
    else:
        with open(excluded_csv, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['excluded_url', 'reason'])

    # Identify remaining URLs to scrape
    pending_urls = []
    with open(master_csv, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if row and len(row) > 1:
                essay_url = row[1]
                if essay_url not in processed_urls:
                    pending_urls.append(essay_url)

    # Deduplicate pending list while preserving order
    pending_urls = list(dict.fromkeys(pending_urls))
    total_pending = len(pending_urls)

    print(f"State sync complete: {len(processed_urls)} URLs already processed.")
    print(f"Launching concurrent scrape on {total_pending} remaining URLs ({MAX_WORKERS} workers)...")

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(parse_apwa_page, url): url for url in pending_urls}

        for i, future in enumerate(as_completed(futures), 1):
            url, parsed_data = future.result()

            with write_lock:
                if parsed_data:
                    json_buffer.append(json.dumps(parsed_data))
                    success_count += 1
                else:
                    excluded_buffer.append([url, 'No Transcript or Parse Error'])
                    excluded_count += 1

                if (len(json_buffer) + len(excluded_buffer)) >= BATCH_SIZE:
                    flush_buffers()
                    print(f"Progress: [{i}/{total_pending}] processed and flushed to Drive.")

    # Final flush for remaining buffered items
    flush_buffers()
    print(f"\n[TASK 02 COMPLETE] Saved: {success_count} | Excluded: {excluded_count}")
    print("Python data acquisition phase finished. Proceed to R scripts (03–09).")
