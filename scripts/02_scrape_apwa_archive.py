# ==============================================================================
# SCRIPT 02: SCRAPE APWA ESSAY TRANSCRIPTS & METADATA TO JSONL (PYTHON)
# Task: Read 'apwa_master_urls.csv', concurrently scrape each essay page using
#       DOM structural heuristics ('\nDetails\n' and '\nTranscript\n'), write
#       raw JSON records to 'apwa_parsed_archive.jsonl', and log untranscribed
#       PDF/Image-only pages to 'apwa_excluded_urls.csv'.
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

# 1. Strict Workspace & Google Drive Mount Verification
drive_mount_point = '/content/drive'
safe_workspace = '/content/drive/MyDrive/colab_apwa_folder'

if not os.path.ismount(drive_mount_point):
    raise RuntimeError(
        f"SECURITY HALT: Google Drive is not mounted at '{drive_mount_point}'. "
        "Run Cell 0A first."
    )

os.makedirs(safe_workspace, exist_ok=True)
os.chdir(safe_workspace)

if os.getcwd() != safe_workspace:
    raise RuntimeError(f"SECURITY HALT: Current directory is {os.getcwd()}, expected {safe_workspace}.")

# 2. File & Concurrency Configuration
master_csv = 'apwa_master_urls.csv'
output_file = 'apwa_parsed_archive.jsonl'
excluded_csv = 'apwa_excluded_urls.csv'

BATCH_SIZE = 50
MAX_WORKERS = 4
MIN_DELAY = 0.5
MAX_DELAY = 1.5
headers = {
    'User-Agent': 'APWA_Virginia_Tech_Research_Bot/1.0 (chayne@vt.edu)'
}

write_lock = threading.Lock()
thread_local = threading.local()

json_buffer = []
excluded_buffer = []
success_count = 0
excluded_count = 0
retry_count = 0

def get_thread_session():
    if not hasattr(thread_local, "session"):
        thread_local.session = requests.Session()
    return thread_local.session

def flush_buffers():
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
    try:
        if MAX_DELAY > 0:
            time.sleep(random.uniform(MIN_DELAY, MAX_DELAY))
        session = get_thread_session()
        response = session.get(url, headers=headers, timeout=15)

        if response.status_code == 429:
            print(f"RATE LIMITED (429) on {url} -> Will retry on next run.")
            return (url, 'RETRY', 'HTTP 429 Rate Limited')
        if response.status_code >= 500:
            print(f"SERVER ERROR ({response.status_code}) on {url} -> Will retry on next run.")
            return (url, 'RETRY', f'HTTP {response.status_code}')
        if response.status_code == 404:
            return (url, 'EXCLUDE', 'HTTP 404 Not Found')

        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')
        for element in soup(["script", "style"]):
            element.extract()
        page_text = soup.get_text(separator='\n', strip=True)

        if '\nDetails\n' in page_text:
            main_content, _, metadata_block = page_text.rpartition('\nDetails\n')
        else:
            return (url, 'EXCLUDE', 'No Details Block')

        if '\nTranscript\n' in main_content:
            _, _, transcript_text = main_content.partition('\nTranscript\n')
        else:
            return (url, 'EXCLUDE', 'No Transcript (PDF/Scan Only)')

        transcript_text = transcript_text.strip()
        if not transcript_text:
            return (url, 'EXCLUDE', 'Empty Transcript')

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
        return (url, 'RETRY', f'Network Error: {e}')
    except Exception:
        return (url, 'EXCLUDE', 'No Transcript or Parse Error')

# 3. State Synchronization & Execution Block
if __name__ == "__main__":
    if not os.path.exists(master_csv):
        raise FileNotFoundError(f"Master CSV '{master_csv}' not found. Run Script 01 first.")

    processed_urls = set()
    if os.path.exists(output_file):
        with open(output_file, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    data = json.loads(line)
                    if 'url' in data:
                        processed_urls.add(data['url'])
                except json.JSONDecodeError:
                    continue

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

    pending_urls = []
    with open(master_csv, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if row and len(row) > 1:
                essay_url = row[1].strip()
                if essay_url and essay_url not in processed_urls:
                    pending_urls.append(essay_url)

    pending_urls = list(dict.fromkeys(pending_urls))
    total_pending = len(pending_urls)

    print(f"State sync complete: {len(processed_urls)} URLs already processed.")
    print(f"Launching concurrent scrape on {total_pending} remaining URLs ({MAX_WORKERS} workers)...")

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(parse_apwa_page, url): url for url in pending_urls}
        for i, future in enumerate(as_completed(futures), 1):
            url, status, payload = future.result()
            with write_lock:
                if status == 'SUCCESS':
                    json_buffer.append(json.dumps(payload))
                    success_count += 1
                elif status == 'EXCLUDE':
                    excluded_buffer.append([url, payload])
                    excluded_count += 1
                else:
                    retry_count += 1
                if (len(json_buffer) + len(excluded_buffer)) >= BATCH_SIZE:
                    flush_buffers()
                    print(
                        f"Progress: [{i}/{total_pending}] processed and flushed to Drive "
                        f"(Saved: {success_count} | Excluded: {excluded_count} | Retry Queue: {retry_count})."
                    )

    flush_buffers()
    print(f"\n[TASK 02 COMPLETE] Saved: {success_count} | Excluded: {excluded_count} | Transient Errors (Re-run to retry): {retry_count}")
    print("Python data acquisition phase finished. Proceed to R scripts (03–10).")
