#!/usr/bin/env python3
"""Enumerate the community pysey patch set (martindefatte/pysey).

A patch is any folder under `modes/` holding a `main.py`; its README.md carries
the per-patch Author / License / EYESY-OS-version fields the repo root licence
(GPL-3.0) does not describe. Requires an authenticated `gh` (GitHub API).

Usage: python3 tools/inventory/fetch_pysey.py
"""
import json
import re
import subprocess
from datetime import date
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/research/inventory'
REPO = 'martindefatte/pysey'


def gh(*args):
    result = subprocess.run(['gh', 'api', *args], capture_output=True, text=True)
    if result.returncode:
        raise SystemExit(f'gh api failed: {args}\n{result.stderr}')
    return result.stdout


def read_file(path, ref):
    import base64
    payload = json.loads(gh(f'repos/{REPO}/contents/{path}?ref={ref}'))
    return base64.b64decode(payload['content']).decode('utf-8', 'replace')


def field(text, name):
    match = re.search(rf'^\*\*{name}:\*\*\s*(.+)$', text, re.M)
    return match.group(1).strip() if match else None


def main():
    repo = json.loads(gh(f'repos/{REPO}'))
    ref = repo['default_branch']
    tree = json.loads(gh(f'repos/{REPO}/git/trees/{ref}?recursive=1'))['tree']
    patches = {}
    for entry in tree:
        path = entry['path']
        if entry['type'] != 'blob':
            continue
        match = re.fullmatch(r'(modes/(V\d)/[^/]+)/main\.py', path)
        if match:
            patches[match.group(1)] = {
                'path': match.group(1), 'generation': 'v2-pygame' if match.group(2) == 'V2' else 'v3-pygame',
                'entry_sha': entry['sha'], 'bytes': entry['size'],
            }
    items = []
    for path, meta in sorted(patches.items()):
        readme_path = f'{path}/README.md'
        readme = read_file(readme_path, ref) if any(
            e['path'] == readme_path for e in tree) else ''
        slug_match = re.search(r'https://patchstorage\.com/([a-z0-9][a-z0-9-]*)/', readme)
        patch_files = sorted(e['path'] for e in tree
                             if e['path'].startswith(path + '/') and e['type'] == 'blob')
        items.append({
            'key': path,
            'title': path.split('/', 2)[2],
            'author': field(readme, 'Author'),
            'generation': meta['generation'],
            'kind': 'mode',
            'url': 'https://github.com/{}/blob/{}/{}'.format(
                REPO, ref, quote(f'{path}/main.py', safe='/')),
            'repo_path': path,
            'license': field(readme, 'License'),
            'created': None,
            'metrics': {'views': None, 'likes': None, 'downloads': None},
            'technique': None,
            'notes': (f"EYESY OS version: {field(readme, 'EYESY OS Version')}; "
                      f"ported-from note: {field(readme, 'Ported from') or 'n/a'}"),
            'raw': {
                'readme': readme_path if readme else None,
                'files': patch_files,
                'entry_bytes': meta['bytes'],
                'patchstorage_slug': slug_match.group(1) if slug_match else None,
                'repo_license': (repo.get('license') or {}).get('spdx_id'),
            },
        })
    counts = {
        'total': len(items),
        'by_generation': _tally(items, 'generation'),
        'by_kind': _tally(items, 'kind'),
        'by_license': _tally(items, 'license'),
    }
    payload = {
        'source': 'pysey',
        'source_url': f'https://github.com/{REPO}',
        'fetched_at': date.today().isoformat(),
        'method': (f'gh api tree of {REPO}@{ref}; a patch is modes/<V2|V3>/<name>/ '
                   'with main.py; per-patch README.md parsed for Author/License/version'),
        'counts': counts,
        'items': items,
    }
    (OUT / 'pysey.json').write_text(json.dumps(payload, indent=2) + '\n')
    print(json.dumps(counts, indent=2))


def _tally(items, field_name):
    tally = {}
    for item in items:
        key = item[field_name] or 'unknown'
        tally[key] = tally.get(key, 0) + 1
    return dict(sorted(tally.items()))


if __name__ == '__main__':
    main()
