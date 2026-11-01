# ==============================================================================
# SCRIPT 02: PARSE & EXTRACT APWA ESSAYS AND METADATA (PYTHON)
# Task: Read 'apwa_master_urls.csv', concurrently scrape each essay's transcript
#       and metadata, and save results in batches to 'apwa_parsed_archive.jsonl'.
#       Distinguishes between genuine exclusions (no transcript) and transient
#       network errors (429/5xx/timeouts) so network glitches can be retried.
# ==============================================================================

import os
import time
import random
import requests
import json
import csv
import threading
from bs4 import BeautifulSoup
from concurrent.futures import ThreadPoolExecutor, as_completed

# 1. Strict Google Drive Mount & Workspace Isolation
drive_mount_point = '/content/drive'
safe_workspace = '/content/drive/MyDrive/colab_apwa_folder'

if not os.path.ismount(drive_mount_point):
    raise RuntimeError(
        f"SECURITY HALT: Google Drive is not mounted at '{drive_mount_point}'. "
        "Please run `from google.colab import drive; drive.mount('/content/drive')` first."
    )

os.makedirs(safe_workspace, exist_ok=True)
os.chdir(safe_workspace)

if os.getcwd() != safe_workspace:
    raise RuntimeError(
        f"SECURITY HALT: Execution environment compromised. "
        f"Current directory is {os.getcwd()}, expected {safe_workspace}. Script terminated."
    )

master_csv = 'apwa_master_urls.csv'
output_file = 'apwa_parsed_archive.jsonl'
excluded_csv = 'apwa_excluded_urls.csv'

# ==============================================================================
# 2. CONCURRENCY & RATE-LIMITING CONFIGURATION (CHOOSE MODE A OR MODE B)
# ==============================================================================

# --- [MODE A: POLITE ACADEMIC CONFIGURATION (DEFAULT)] ---
MAX_WORKERS = 4   # Gentle concurrency that respects university servers
BATCH_SIZE = 50   # Number of items to hold in memory before writing to Drive
MIN_DELAY = 0.5   # Minimum delay (seconds) per worker before each request
MAX_DELAY = 1.5   # Maximum delay (seconds) per worker before each request
headers = {
    'User-Agent': 'APWA_Virginia_Tech_Research_Bot/1.0 (chayne@vt.edu)'
}

# --- [MODE B: AGGRESSIVE 15-WORKER "SPEED RUN" CONFIGURATION (COMMENTED OUT)] ---
# Uncomment the block below (and comment out Mode A above) to speed-run with
# 15 simultaneous workers and zero artificial throttling.
# MAX_WORKERS = 15  # High concurrency speed-run. Reduce if server returns 429 errors.
# BATCH_SIZE = 50   # Number of items to hold in memory before writing to Drive.
# MIN_DELAY = 0.0   # Zero artificial delay
# MAX_DELAY = 0.0   # Zero artificial delay
# headers = {
#     'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
# }
# ==============================================================================

# Thread-safe buffers, locks, and thread-local HTTP sessions
write_lock = threading.Lock()
thread_local = threading.local()

json_buffer = []
excluded_buffer = []
success_count = 0
excluded_count = 0
retry_error_count = 0


def get_thread_session():
    """
    Provides each worker thread with its own persistent requests.Session()
    for TCP/TLS connection pooling (HTTP Keep-Alive).
    """
    if not hasattr(thread_local, "session"):
        thread_local.session = requests.Session()
    return thread_local.session


def flush_buffers():
    """Writes buffered data to Google Drive in a single batch operation."""
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
    Extracts the transcript and metadata from an APWA essay page.
    Returns a 3-tuple: (url, status, payload)
      - status == 'SUCCESS': payload is the parsed dictionary
      - status == 'EXCLUDE': payload is the exclusion reason string (permanent skip)
      - status == 'RETRY':   payload is the transient error string (will retry on next run)
    """
    try:
        if MAX_DELAY > 0:
            time.sleep(random.uniform(MIN_DELAY, MAX_DELAY))

        session = get_thread_session()
        response = session.get(url, headers=headers, timeout=15)

        # Transient server/rate-limit errors -> Do NOT permanently exclude!
        if response.status_code == 429:
            print(f"RATE LIMITED (429) on {url} - Marked for retry on next run.")
            return (url, 'RETRY', 'HTTP 429 Rate Limited')
        if response.status_code >= 500:
            print(f"SERVER ERROR ({response.status_code}) on {url} - Marked for retry on next run.")
            return (url, 'RETRY', f'HTTP {response.status_code} Server Error')

        # 404 Not Found -> Essay was pulled or URL is dead (permanent exclusion)
        if response.status_code == 404:
            return (url, 'EXCLUDE', 'HTTP 404 Page Not Found')

        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')

        for element in soup(["script", "style"]):
            element.extract()

        page_text = soup.get_text(separator='\n', strip=True)

        # Use rpartition to split on the LAST occurrence of '\nDetails\n'
        # so essays containing the word "Details" are never truncated.
        if '\nDetails\n' in page_text:
            main_content, _, metadata_block = page_text.rpartition('\nDetails\n')
        else:
            return (url, 'EXCLUDE', 'Missing Details Section')

        if '\nTranscript\n' in main_content:
            _, _, transcript_text = main_content.partition('\nTranscript\n')
        else:
            return (url, 'EXCLUDE', 'No Typed Transcript Available (Scan Only)')

        transcript_text = transcript_text.strip()
        if not transcript_text:
            return (url, 'EXCLUDE', 'Empty Transcript Text')

        metadata_block, _, _ = metadata_block.partition('\nIf this is your essay')
        meta_lines = [line.strip() for line in metadata_block.split('\n') if line.strip()]

        metadata = {}
        for i in range(0, len(meta_lines) - 1, 2):
            metadata[meta_lines[i]] = meta_lines[i + 1]

        return (url, 'SUCCESS', {
            'url': url,
            'slug': url.strip('/').split('/')[-1],
            'transcript': transcript_text,
            'metadata': metadata
        })

    except requests.exceptions.RequestException as e:
        # Network timeouts or dropped connections should be retried, not excluded
        return (url, 'RETRY', f'Network Error: {e}')
    except Exception as e:
        return (url, 'RETRY', f'Unexpected Parser Error: {e}')


# --- Execution Block ---
if __name__ == "__main__":
    processed_urls = set()

    # 1. Read already successful URLs
    if os.path.exists(output_file):
        with open(output_file, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    data = json.loads(line)
                    processed_urls.add(data['url'])
                except json.JSONDecodeError:
                    continue

    # 2. Read already excluded URLs
    if os.path.exists(excluded_csv):
        with open(excluded_csv, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            next(reader, None)  # Skip header
            for row in reader:
                if row:
                    processed_urls.add(row[0])
    else:
        with open(excluded_csv, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['excluded_url', 'reason'])

    # 3. Build deduplicated list of pending URLs
    pending_urls = []
    if not os.path.exists(master_csv):
        raise FileNotFoundError(f"Master CSV '{master_csv}' missing. Run Script 01 first.")

    with open(master_csv, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader, None)  # Skip header
        for row in reader:
            if row and len(row) > 1:
                essay_url = row[1].strip()
                if essay_url and essay_url not in processed_urls:
                    pending_urls.append(essay_url)
                    # Add to processed_urls immediately to prevent duplicate threads
                    # if master_csv contains any duplicate rows
                    processed_urls.add(essay_url)

    total_pending = len(pending_urls)
    print(f"Database sync: {len(processed_urls) - total_pending} unique URLs already handled.")
    print(f"Beginning concurrent scrape on remaining {total_pending} URLs using {MAX_WORKERS} workers...")

    # 4. Execute concurrent scraping
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(parse_apwa_page, url): url for url in pending_urls}

        for i, future in enumerate(as_completed(futures), 1):
            url, status, payload = future.result()

            # Thread-safe write to buffers
            with write_lock:
                if status == 'SUCCESS':
                    json_buffer.append(json.dumps(payload))
                    success_count += 1
                elif status == 'EXCLUDE':
                    excluded_buffer.append([url, payload])
                    excluded_count += 1
                else:
                    # status == 'RETRY': Do not write to excluded_csv so a future run retries it
                    retry_error_count += 1

                # Check batch threshold
                if (len(json_buffer) + len(excluded_buffer)) >= BATCH_SIZE:
                    flush_buffers()
                    print(
                        f"Progress: [{i}/{total_pending}] | "
                        f"Saved: {success_count} | Excluded: {excluded_count} | "
                        f"Transient Errors (to retry): {retry_error_count}"
                    )

    # 5. Final flush for remaining items in buffer after threads complete
    flush_buffers()
    print(
        f"\n[TASK 02 COMPLETE] Extraction finished.\n"
        f"  -> Successfully Saved : {success_count}\n"
        f"  -> Permanently Excluded (No Transcript/404): {excluded_count}\n"
        f"  -> Transient Network Errors (Run script again to retry): {retry_error_count}"
    )
