#!/usr/bin/env python3
"""Enumerate every patch on the PatchStorage EYESY platform.

The WPGraphQL-ish alpha API filters by platform with an *array* parameter:
`?platforms[]=<platform-id>` (a scalar `?platform=id` is silently ignored and
returns every patch on the site). EYESY is platform id 6398; the count is
cross-checked against the platform page scrape.

Listing responses carry the counters but not the licence/file list, so each
patch is then fetched individually from its `self` URL. Raw responses are
cached under /tmp/eyesy-inventory/ps/ and are never committed.

Usage: python3 tools/inventory/fetch_patchstorage.py
"""
import json
import re
import time
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/research/inventory'
CACHE = Path('/tmp/eyesy-inventory/ps')
API = 'https://patchstorage.com/api/alpha/patches/'
PLATFORM_ID = 6398          # https://patchstorage.com/api/alpha/platforms/6398
PLATFORM_SLUG = 'eyesy'
PAGES = 4                   # 209 entries at 100/page; a 4th page is empty-proof
UA = {'User-Agent': 'eyesy-modes-factory inventory (one-off coverage sweep)'}


def fetch(url):
    CACHE.mkdir(parents=True, exist_ok=True)
    key = re.sub(r'[^a-zA-Z0-9]+', '_', url)[-120:]
    path = CACHE / f'{key}.json'
    if path.is_file():
        return json.loads(path.read_text())
    for attempt in (1, 2):
        try:
            request = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = json.loads(response.read().decode())
            break
        except Exception as exc:                      # noqa: BLE001 - retry once
            if attempt == 2:
                raise SystemExit(f'fetch failed: {url}: {exc}')
            time.sleep(2)
    path.write_text(json.dumps(payload))
    time.sleep(0.15)
    return payload


def norm(text):
    value = re.sub(r'^(s|t|u)[-_. ]+', '', (text or '').lower())
    value = re.sub(r'[-_.]v?\d+$', '', value)
    return re.sub(r'[^a-z0-9]+', '-', value).strip('-')


GEN_FROM_MAJOR = {'3': 'v3-pygame', '2': 'v2-pygame', '1': 'v1-of-lua'}
GEN_PATTERNS = [
    (re.compile(r'eyesy\s*(?:os)?\s*v?([123])\.\d', re.I), GEN_FROM_MAJOR),
    (re.compile(r'\bos\s*v?([123])\.\d', re.I), GEN_FROM_MAJOR),
]
OF_PATTERN = re.compile(r'openframeworks|\boflua\b', re.I)


def generation(record):
    """Generation only when the patch text states it; otherwise unknown."""
    text = ' '.join([
        record.get('title') or '', record.get('excerpt') or '',
        record.get('content') or '',
    ])
    for pattern, mapping in GEN_PATTERNS:
        match = pattern.search(text)
        if match:
            return mapping.get(match.group(1), 'unknown'), match.group(0).strip()
    match = OF_PATTERN.search(text)
    if match:
        return 'v1-of-lua', match.group(0)
    return 'unknown', None


def main():
    listing = {}
    page = 1
    while page <= 100:
        url = f'{API}?platforms[]={PLATFORM_ID}&limit=100&page={page}'
        try:
            records = fetch(url)
        except SystemExit as exc:
            if '400' in str(exc):       # past the last page
                break
            raise
        if not records:
            break
        for record in records:
            listing[record['id']] = record
        page += 1
    items = []
    for record in sorted(listing.values(), key=lambda r: r['slug']):
        patch = fetch(record['self'])
        platform = (patch.get('platform') or {}).get('slug')
        if platform != PLATFORM_SLUG:
            continue
        gen, gen_evidence = generation(patch)
        items.append({
            'key': patch['slug'],
            'title': patch['title'],
            'author': (patch.get('author') or {}).get('name'),
            'generation': gen,
            'kind': 'mode' if patch.get('files') else 'non-mode',
            'url': patch['link'],
            'repo_path': None,
            'license': _license(patch),
            'created': (patch.get('created_at') or '')[:10] or None,
            'metrics': {
                'views': patch.get('view_count'),
                'likes': patch.get('like_count'),
                'downloads': patch.get('download_count'),
            },
            'technique': (patch.get('excerpt') or '')[:200] or None,
            'notes': None,
            'raw': {
                'id': patch['id'],
                'generation_evidence': gen_evidence,
                'categories': [c['name'] for c in patch.get('categories') or []],
                'tags': [t['name'] for t in patch.get('tags') or []],
                'files': [{'name': f.get('name'), 'size': f.get('size')}
                          for f in patch.get('files') or []],
                'source_code_url': patch.get('source_code_url'),
                'revision': patch.get('revision'),
                'updated_at': patch.get('updated_at'),
                'self': patch.get('self'),
            },
        })

    counts = {
        'total': len(items),
        'by_generation': _tally(items, 'generation'),
        'by_kind': _tally(items, 'kind'),
        'by_license': _tally(items, 'license'),
    }
    payload = {
        'source': 'patchstorage',
        'source_url': 'https://patchstorage.com/platform/eyesy/',
        'fetched_at': date.today().isoformat(),
        'method': (f'api/alpha/patches/?platforms[]={PLATFORM_ID} listing '
                   '(100/page) + per-patch fetch of each `self` URL'),
        'counts': counts,
        'items': items,
    }
    (OUT / 'patchstorage.json').write_text(json.dumps(payload, indent=2) + '\n')
    print(json.dumps(counts, indent=2))


def _license(patch):
    value = patch.get('license')
    if isinstance(value, dict):
        return value.get('name') or value.get('slug')
    if value:
        return value
    return patch.get('custom_license_text')


def _tally(items, field):
    tally = {}
    for item in items:
        key = item[field] or 'unknown'
        tally[key] = tally.get(key, 0) + 1
    return dict(sorted(tally.items()))


if __name__ == '__main__':
    main()
