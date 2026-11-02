# ==============================================================================
# SCRIPT 01: DYNAMICALLY VERIFY & INDEX APWA ARCHIVE URLS (PYTHON)
# Task: 1. Automatically verify the exact total number of archive pages.
#       2. Paginate through all pages of the APWA web archive to collect and
#          save all unique essay URLs into 'apwa_master_urls.csv'.
#       3. Includes state-tracking (resume capability) and cross-page deduplication.
# ==============================================================================

import os
import re
import time
import random
import requests
import csv
from urllib.parse import urljoin
from bs4 import BeautifulSoup

# 1. Strict Google Drive Mount & Workspace Verification
drive_mount_point = '/content/drive'
safe_workspace = '/content/drive/MyDrive/colab_apwa_folder'

if not os.path.ismount(drive_mount_point):
    raise RuntimeError(
        f"SECURITY HALT: Google Drive is not mounted at '{drive_mount_point}'. "
        "Please run Cell 0A first."
    )

os.makedirs(safe_workspace, exist_ok=True)
os.chdir(safe_workspace)

if os.getcwd() != safe_workspace:
    raise RuntimeError(f"SECURITY HALT: Current directory is {os.getcwd()}, expected {safe_workspace}.")

# 2. Scraper Configuration
master_csv = 'apwa_master_urls.csv'
base_url = 'https://prisonwitness.org/the-archive/'
MIN_DELAY = 1.5
MAX_DELAY = 3.0
headers = {
    'User-Agent': 'APWA_Virginia_Tech_Research_Bot/1.0 (chayne@vt.edu)'
}

def get_page_essay_urls(session, page_num):
    target_url = f"{base_url}{page_num}/" if page_num > 1 else base_url
    response = session.get(target_url, headers=headers, timeout=15)
    if response.status_code == 404:
        return set(), None
    response.raise_for_status()
    soup = BeautifulSoup(response.content, 'html.parser')
    page_urls = set()
    for link in soup.find_all('a', href=True):
        href = link['href']
        if '/apwa-essay/' in href:
            full_url = urljoin(base_url, href)
            page_urls.add(full_url)
    return page_urls, soup

def verify_total_pages(session):
    print("Verifying total number of archive pages on prisonwitness.org...")
    page_1_urls, soup = get_page_essay_urls(session, 1)
    if not page_1_urls or soup is None:
        raise RuntimeError("CRITICAL ERROR: Could not find any essays on Page 1. Check archive availability.")

    candidate_max = 1
    page_num_pattern = re.compile(r'/the-archive/(?:page/)?(\d+)/?')
    for link in soup.find_all('a', href=True):
        match = page_num_pattern.search(link['href'])
        if match:
            candidate_max = max(candidate_max, int(match.group(1)))
    if candidate_max <= 1:
        candidate_max = 180

    print(f"Initial pagination hint from Page 1: ~{candidate_max} pages. Verifying exact boundary...")
    cache = {1: True}
    def has_essays(p):
        if p in cache:
            return cache[p]
        if MAX_DELAY > 0:
            time.sleep(random.uniform(0.2, 0.5))
        urls, _ = get_page_essay_urls(session, p)
        result = len(urls) > 0
        cache[p] = result
        return result

    if has_essays(candidate_max):
        low = candidate_max
        step = 1
        while has_essays(low + step):
            low += step
            step *= 2
        high = low + step
    else:
        low = 1
        high = candidate_max

    while low + 1 < high:
        mid = (low + high) // 2
        if has_essays(mid):
            low = mid
        else:
            high = mid

    print(f"Verified! The archive currently contains exactly {low} active pages.")
    return low

# 3. State Tracking (Resume Capability & Cross-Page Deduplication)
processed_pages = set()
seen_urls = set()

if os.path.exists(master_csv):
    with open(master_csv, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if row and len(row) >= 2:
                if row[0].isdigit():
                    processed_pages.add(int(row[0]))
                seen_urls.add(row[1])
    print(f"Found existing master CSV: {len(processed_pages)} pages ({len(seen_urls)} unique URLs) already indexed.")
else:
    with open(master_csv, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['source_page', 'essay_url'])
    print("Initialized new master URL index: 'apwa_master_urls.csv'.")

# 4. Dynamic Verification & Paginated Crawling Loop
with requests.Session() as session:
    max_pages = verify_total_pages(session)
    print(f"Indexing status: {len(processed_pages)}/{max_pages} pages already completed.\n")

    for page in range(1, max_pages + 1):
        if page in processed_pages:
            continue
        try:
            page_urls, _ = get_page_essay_urls(session, page)
            if not page_urls:
                print(f"WARNING: Page {page}/{max_pages} returned 0 essay URLs. Skipping so it can be retried.")
                continue
            new_urls = sorted(page_urls - seen_urls)
            with open(master_csv, 'a', encoding='utf-8', newline='') as f:
                writer = csv.writer(f)
                for essay_url in new_urls:
                    writer.writerow([page, essay_url])
                    seen_urls.add(essay_url)
            print(
                f"Page {page}/{max_pages} indexed: Found {len(page_urls)} essays "
                f"({len(new_urls)} new, {len(page_urls) - len(new_urls)} duplicates skipped)."
            )
            if MAX_DELAY > 0:
                time.sleep(random.uniform(MIN_DELAY, MAX_DELAY))
        except requests.exceptions.RequestException as e:
            print(f"Network error on page {page}: {e}")
            print("Halting index scrape to prevent data gaps. Rerun script to resume.")
            break
        except Exception as e:
            print(f"Unexpected error parsing page {page}: {e}")
            break

print(f"\n[TASK 01 COMPLETE] Master URL index ({len(seen_urls)} total unique URLs) saved to: {os.path.join(safe_workspace, master_csv)}")
