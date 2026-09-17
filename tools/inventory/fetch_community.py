#!/usr/bin/env python3
"""Enumerate community EYESY mode repositories (GitHub + Codeberg).

Discovery is by GitHub repository search (`eyesy`, `eyesy-modes`, `topic:eyesy`),
a code search for the stock mode interface (`eyesy.audio_in` in `main.py`), and
the Codeberg repo search. Every hit is deduplicated by full name; each repo's
tree is then scanned for mode folders (a folder holding `main.py`/`main.lua` at
depth <= 3). Repos that only ship engines/tools/docs produce no items but are
listed in the notes file with the reason.

Repos covered by the sibling inventories are excluded here:
`critterandguitari/*` -> github-stock.json, `martindefatte/pysey` -> pysey.json.

Requires an authenticated `gh`; Codeberg is plain HTTPS.

Usage: python3 tools/inventory/fetch_community.py
"""
import json
import re
import subprocess
import time
import urllib.request
from datetime import date
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/research/inventory'
CACHE = Path('/tmp/eyesy-inventory/community')

QUERIES = [
    'search/repositories?q=eyesy+in:name,description,readme&per_page=100',
    'search/repositories?q=eyesy-modes&per_page=100',
    'search/repositories?q=topic:eyesy&per_page=100',
    'search/code?q=eyesy.audio_in+in:file+filename:main.py&per_page=100',
]
EXCLUDE = ('critterandguitari/', 'martindefatte/pysey')
MODE_FILES = ('main.py', 'main.lua', 'main.cpp')
CODEPLAN_ERROR = 'API rate limit exceeded'
# A real EYESY mode entry file declares the mode interface. Anything else
# (`main.py` in an engine, a script, a tool) is not a mode.
INTERFACE = {
    'main.py': (r'def\s+setup\s*\(', r'def\s+draw\s*\('),
    'main.lua': (r'require\s*\(?\s*["\']eyesy', r'function\s+setup|setup\s*=|draw\s*='),
    'main.cpp': (r'eyesy', r'setup'),
}


def cache_path(url):
    return CACHE / (re.sub(r'[^a-zA-Z0-9]+', '_', url)[-140:] + '.json')


def get(url, kind='gh'):
    path = cache_path(url)
    if path.is_file():
        return json.loads(path.read_text())
    if kind == 'gh':
        for attempt in range(4):
            result = subprocess.run(['gh', 'api', url], capture_output=True, text=True)
            if result.returncode == 0:
                payload = json.loads(result.stdout)
                break
            if 'Not Found' in result.stderr or 'HTTP 404' in result.stderr:
                return None
            time.sleep(2 * (attempt + 1))            # secondary rate limit / 5xx
        else:
            if CODEPLAN_ERROR in result.stderr:
                raise SystemExit('GitHub rate limit exhausted; rerun later')
            return None
    else:
        request = urllib.request.Request(url, headers={'User-Agent': 'eyesy inventory'})
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode())
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload))
    time.sleep(0.1)
    return payload


def discover():
    repos, queries = {}, []
    for query in QUERIES:
        payload = get(query)
        if not payload:
            queries.append({'query': query, 'total_count': None, 'error': 'failed'})
            continue
        queries.append({'query': query, 'total_count': payload.get('total_count')})
        for entry in payload.get('items') or []:
            full = entry.get('repository', {}).get('full_name') or entry.get('full_name')
            if not full or full.startswith(EXCLUDE):
                continue
            repos[full] = {
                'full_name': full,
                'fork': entry.get('fork'),
                'stars': entry.get('stargazers_count'),
                'description': entry.get('description'),
                'default_branch': entry.get('default_branch'),
                'via': repos.get(full, {}).get('via', []) + [query],
            }
    return repos, queries


def generation_of(path, repo, entry_file):
    name = (path + ' ' + repo).lower()
    if 'v2' in name and entry_file == 'main.py':
        return 'v2-pygame'
    if 'mode/python' in name or 'osv3' in name or 'v3' in name:
        return 'v3-pygame' if entry_file == 'main.py' else 'unknown'
    if entry_file == 'main.lua' or 'oflua' in name or 'lua' in name:
        return 'v1-of-lua'
    return 'unknown'


def get_text(url):
    """Fetch a raw text file (the codeberg raw endpoint), cached by URL."""
    path = cache_path(url)
    if path.is_file():
        return path.read_text()
    request = urllib.request.Request(url, headers={'User-Agent': 'eyesy inventory'})
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status != 200:
            return None
        text = response.read().decode('utf-8', 'replace')
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    time.sleep(0.1)
    return text


def entry_source(repo, path, branch):
    """Fetch and decode one entry file (cached)."""
    url = f'repos/{repo}/contents/{path}?ref={branch}'
    payload = get(url)
    if not payload or isinstance(payload, list):
        return None
    import base64
    try:
        return base64.b64decode(payload['content']).decode('utf-8', 'replace')
    except Exception:                                 # noqa: BLE001
        return None


def verify(item, source):
    patterns = INTERFACE.get(item['raw']['entry_file'], ())
    if source is None:
        return 'unreachable'
    if all(re.search(pattern, source) for pattern in patterns) and patterns:
        return 'verified'
    return 'not-a-mode'


def scan(repo, meta):
    detail = get(f'repos/{repo}')
    if not detail:
        return [], {'full_name': repo, 'modes': 0, 'reason': 'metadata fetch failed'}
    branch = detail.get('default_branch') or meta.get('default_branch') or 'main'
    tree = get(f'repos/{repo}/git/trees/{branch}?recursive=1')
    if not tree:
        return [], {'full_name': repo, 'modes': 0, 'reason': 'tree fetch failed'}
    blobs = [e for e in tree.get('tree', []) if e.get('type') == 'blob']
    folders = {}
    for blob in blobs:
        path = blob['path']
        base = path.rsplit('/', 1)
        if base[-1] not in MODE_FILES:
            continue
        folder = base[0] if len(base) == 2 else '.'
        if folder != '.' and folder.count('/') > 2:
            continue
        folders[folder] = base[-1]
    items = []
    for folder, entry_file in sorted(folders.items()):
        label = repo.split('/')[-1] if folder == '.' else folder.rsplit('/', 1)[-1]
        prefix = '' if folder == '.' else folder + '/'
        files = [b['path'] for b in blobs if b['path'].startswith(prefix)]
        items.append({
            'key': f'{repo}/{label}',
            'title': label,
            'author': repo.split('/')[0],
            'generation': generation_of(folder, repo, entry_file),
            'kind': 'mode',
            'url': ('https://github.com/{}/blob/{}/{}'.format(
                repo, branch, quote(f'{prefix}{entry_file}', safe='/'))),
            'repo_path': folder,
            'license': (detail.get('license') or {}).get('spdx_id'),
            'created': (detail.get('created_at') or '')[:10] or None,
            'metrics': {'views': None, 'likes': None, 'downloads': None},
            'technique': None,
            'notes': (f"fork={detail.get('fork')}; "
                      f"upstream={(detail.get('parent') or {}).get('full_name') or 'n/a'}; "
                      f"last push {(detail.get('pushed_at') or '')[:10]}"),
            'raw': {'entry_file': entry_file, 'entry_path': f'{prefix}{entry_file}',
                    'files': files, 'branch': branch, 'repo': repo,
                    'report': 'inferred from path/entry-file; interface verified separately'},
        })
    summary = {
        'full_name': repo, 'modes': len(items),
        'license': (detail.get('license') or {}).get('spdx_id'),
        'stars': detail.get('stargazers_count'), 'fork': detail.get('fork'),
        'pushed_at': (detail.get('pushed_at') or '')[:10],
        'description': detail.get('description'),
        'reason': None if items else 'no mode folders (engine/tool/docs/asset repo)',
    }
    return items, summary


def codeberg():
    # Codeberg's repo search matches repository names only, so `q=eyesy` returns
    # nothing (verified: `q=hertsi` returns twang69/hertsi, `q=eyesy` returns 0).
    # Known EYESY-mode hosts therefore have to be listed explicitly.
    known = ['twang69/hertsi']
    payload = get('https://codeberg.org/api/v1/repos/search?q=eyesy&limit=50', kind='http')
    repos, items, summaries = {}, [], []
    for entry in (payload or {}).get('data') or []:
        full = entry.get('full_name')
        if not full:
            continue
        repos[full] = entry
    for full in known:
        if full in repos:
            continue
        entry = get(f'https://codeberg.org/api/v1/repos/{full}', kind='http')
        if entry and entry.get('full_name'):
            repos[full] = entry
    for full, entry in repos.items():
        branch = entry.get('default_branch') or 'main'
        tree = get(f'https://codeberg.org/api/v1/repos/{full}/git/trees/{branch}?recursive=true',
                   kind='http')
        blobs = [e for e in ((tree or {}).get('tree') or []) if e.get('type') == 'blob']
        folders = {}
        for blob in blobs:
            base = blob['path'].rsplit('/', 1)
            if base[-1] not in MODE_FILES:
                continue
            folder = base[0] if len(base) == 2 else '.'
            if folder != '.' and folder.count('/') > 1:
                continue
            folders[folder] = base[-1]
        for folder, entry_file in sorted(folders.items()):
            label = full.split('/')[-1] if folder == '.' else folder.rsplit('/', 1)[-1]
            prefix = '' if folder == '.' else folder + '/'
            items.append({
                'key': f'{full}/{label}', 'title': label,
                'author': full.split('/')[0],
                'generation': generation_of(folder, full, entry_file), 'kind': 'mode',
                'url': ('https://codeberg.org/{}/src/branch/{}/{}'.format(
                    full, branch, quote(f'{prefix}{entry_file}', safe='/'))),
                'repo_path': folder, 'license': entry.get('license'),
                'created': None,
                'metrics': {'views': None, 'likes': None, 'downloads': None},
                'technique': None,
                'notes': f"codeberg; last push {(entry.get('updated_at') or '')[:10]}",
                'raw': {'entry_file': entry_file, 'entry_path': f'{prefix}{entry_file}',
                        'repo': full, 'branch': branch, 'codeberg': True},
            })
        summaries.append({'full_name': full, 'modes': len(folders),
                          'license': entry.get('license'),
                          'pushed_at': (entry.get('updated_at') or '')[:10],
                          'description': entry.get('description'),
                          'reason': None if folders else 'no mode folders'})
    return items, summaries


def main():
    repos, queries = discover()
    items, summaries = [], []
    for repo in sorted(repos):
        found, summary = scan(repo, repos[repo])
        items.extend(found)
        summaries.append(summary)
    cb_items, cb_summaries = codeberg()
    items.extend(cb_items)
    summaries.extend(cb_summaries)

    from concurrent.futures import ThreadPoolExecutor
    def check(item):
        raw = item['raw']
        if raw.get('codeberg'):
            url = (f"https://codeberg.org/{raw['repo']}/raw/branch/"
                   f"{raw['branch']}/{raw['entry_path']}")
            try:
                source = get_text(url)
            except Exception:                          # noqa: BLE001
                source = None
        else:
            source = entry_source(raw['repo'], raw['entry_path'], raw['branch'])
        raw['interface'] = verify(item, source)
        return item

    with ThreadPoolExecutor(max_workers=3) as pool:
        items = list(pool.map(check, items))
    kept = [i for i in items if i['raw']['interface'] == 'verified']
    rejected = [{'key': i['key'], 'interface': i['raw']['interface']} for i in items
                if i['raw']['interface'] != 'verified']
    items = kept

    by_repo = {}
    for item in items:
        repo = item['raw'].get('repo') or item['key'].rsplit('/', 1)[0]
        by_repo[repo] = by_repo.get(repo, 0) + 1
    for summary in summaries:
        summary['modes'] = by_repo.get(summary['full_name'], 0)
        if summary['modes'] and summary.get('reason'):
            summary['reason'] = None

    counts = {
        'total': len(items),
        'verified': len(items),
        'rejected': len(rejected),
        'repos_with_modes': sum(1 for s in summaries if s['modes']),
        'by_generation': _tally(items, 'generation'),
        'by_kind': _tally(items, 'kind'),
        'by_license': _tally(items, 'license'),
    }
    payload = {
        'source': 'community',
        'source_url': 'https://github.com/search?q=eyesy',
        'fetched_at': date.today().isoformat(),
        'method': ('GitHub repo/code search + Codeberg search; per-repo git tree scan '
                   'for folders holding main.py/main.lua/main.cpp (depth <= 3); '
                   'repos with no mode folders are listed in community.md'),
        'counts': counts,
        'items': items,
        'rejected': rejected,
        'repos': summaries,
        'queries': queries,
    }
    (OUT / 'community.json').write_text(json.dumps(payload, indent=2) + '\n')
    print(json.dumps({'counts': counts, 'repos_with_modes':
                      [s['full_name'] for s in summaries if s.get('modes')]}, indent=2))


def _tally(items, field):
    tally = {}
    for item in items:
        key = item[field] or 'unknown'
        tally[key] = tally.get(key, 0) + 1
    return dict(sorted(tally.items()))


if __name__ == '__main__':
    main()
