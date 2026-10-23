# ==============================================================================
# SCRIPT 01: INDEX APWA ARCHIVE URLS (PYTHON)
# Task: Paginate through all 181 pages of the APWA web archive to collect and
#       save all 4,504 unique essay URLs into 'apwa_master_urls.csv'.
#       Includes state-tracking (resume capability) and polite rate-limiting.
# ==============================================================================

import os
import time
import random
import requests
import csv
from bs4 import BeautifulSoup

# 1. Strict Workspace Verification
safe_workspace = '/content/drive/MyDrive/colab_apwa_folder'
os.makedirs(safe_workspace, exist_ok=True)
os.chdir(safe_workspace)

if os.getcwd() != safe_workspace:
    raise RuntimeError(f"SECURITY HALT: Current directory is {os.getcwd()}, expected {safe_workspace}.")

# 2. Scraper Configuration & Polite Academic Identification Header
master_csv = 'apwa_master_urls.csv'
base_url = '[https://prisonwitness.org/the-archive/](https://prisonwitness.org/the-archive/)'
max_pages = 181
headers = {
    'User-Agent': 'APWA_Virginia_Tech_Research_Bot/1.0 (chayne@vt.edu)'
}

# 3. State Tracking (Resume Capability if Colab disconnects)
processed_pages = set()

if os.path.exists(master_csv):
    with open(master_csv, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader, None)  # Skip CSV header
        for row in reader:
            if row and row[0].isdigit():
                processed_pages.add(int(row[0]))
    print(f"Resuming index creation: {len(processed_pages)}/{max_pages} pages already indexed.")
else:
    with open(master_csv, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['source_page', 'essay_url'])
    print("Initialized new master URL index: 'apwa_master_urls.csv'.")

# 4. Paginated Crawling Loop
for page in range(1, max_pages + 1):
    if page in processed_pages:
        continue

    current_url = f"{base_url}{page}/" if page > 1 else base_url

    try:
        response = requests.get(current_url, headers=headers, timeout=10)
        response.raise_for_status()

        soup = BeautifulSoup(response.content, 'html.parser')

        # Isolate all anchor tags linking to individual APWA essays
        page_urls = set()
        for link in soup.find_all('a', href=True):
            href = link['href']
            if '/apwa-essay/' in href:
                page_urls.add(href)

        # Immediately append discovered URLs to disk
        with open(master_csv, 'a', encoding='utf-8', newline='') as f:
            writer = csv.writer(f)
            for essay_url in sorted(page_urls):
                writer.writerow([page, essay_url])

        print(f"Page {page}/{max_pages} indexed: Found {len(page_urls)} unique essay URLs.")

        # Polite randomized throttling (1.5 to 3.0 seconds) to respect JHU servers
        time.sleep(random.uniform(1.5, 3.0))

    except requests.exceptions.RequestException as e:
        print(f"Network error on page {page}: {e}")
        print("Halting index scrape to prevent data gaps. Rerun script to resume.")
        break
    except Exception as e:
        print(f"Unexpected error parsing page {page}: {e}")
        break

print(f"\n[TASK 01 COMPLETE] Master URL index saved to: {os.path.join(safe_workspace, master_csv)}")
