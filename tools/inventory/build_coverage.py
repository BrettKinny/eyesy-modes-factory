#!/usr/bin/env python3
"""Merge the per-source inventory files into one coverage matrix.

Inputs (docs/research/inventory/): patchstorage.json, github-stock.json,
pysey.json, community.json, local.json. Outputs: coverage.json (full merged
rows) and coverage.csv (spreadsheet view, gap list first).

Offline and deterministic: no network, no clock, no ordering drift.
"""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / 'docs/research/inventory'
SOURCES = ['patchstorage', 'github-stock', 'pysey', 'community']
LOCAL = 'local'

# A mode we author is not a port of the upstream it shares a technique with.
LOCAL_STATUS = {'ours': 'have-derived', 'engine': 'have-engine'}

# Licence verdicts: permissive = derivative port may carry the upstream
# attribution; copyleft = port is allowed but binds the derived mode; 'none' =
# no licence stated, so nothing may be copied or adapted (technique only).
COPYLEFT = ('gpl', 'agpl', 'eupl', 'cc-by-sa', 'share alike', 'by-sa', 'mpl',
            'lgpl', 'open software license', 'copyleft')
PERMISSIVE = ('mit', 'bsd', 'apache', 'cc0', 'cc-by', 'wtfpl', 'unlicense',
              'public domain', 'isc', 'zlib', 'artistic')


def norm(key):
    """Canonical comparison key: family prefix + version suffix stripped."""
    value = (key or '').lower()
    value = value.rsplit('/', 1)[-1]          # repo-relative path -> folder
    value = re.sub(r'^(s|t|u)[-_. ]+', '', value)
    value = re.sub(r'[-_.]v?\d+$', '', value)
    plain = re.sub(r'[^a-z0-9]+', '-', value).strip('-')
    if plain:
        return plain
    # Non-ASCII mode names (e.g. the PatchStorage upload titled "𝟝 𝕎𝕠𝕣𝕕𝕤")
    # normalise to nothing in ASCII; keep their unicode alphanumerics instead.
    return re.sub(r'[^\w]+', '-', value, flags=re.UNICODE).strip('-')


def license_verdict(text):
    if not text:
        return 'none'
    low = text.lower()
    if any(token in low for token in COPYLEFT):
        return 'copyleft'
    if any(token in low for token in PERMISSIVE):
        return 'permissive'
    return 'check'


def load_verdicts():
    path = INVENTORY / 'verdicts.json'
    if not path.is_file():
        return {}
    return json.loads(path.read_text()).get('verdicts', {})


def load(name):
    path = INVENTORY / f'{name}.json'
    if not path.is_file():
        raise SystemExit(f'missing inventory file: {path}')
    data = json.loads(path.read_text())
    data.setdefault('items', [])
    return data


def main():
    sources = {name: load(name) for name in SOURCES}
    local = load(LOCAL)

    have, have_engine = {}, {}
    for item in local['items']:
        entry = {
            'local_key': item['key'], 'local_pack': item.get('raw', {}).get('pack'),
            'local_path': item.get('repo_path'), 'notes': item.get('notes'),
        }
        (have_engine if item.get('generation') == 'engine' else have)[norm(item['key'])] = entry

    rows, seen = [], {}
    for name in SOURCES:
        for item in sources[name]['items']:
            row = seen.get(norm(item['key']))
            if row is None:
                row = {
                    'key': norm(item['key']),
                    'titles': [], 'sources': [], 'generations': set(),
                    'kinds': set(), 'authors': set(), 'licenses': set(),
                    'downloads': None, 'views': None, 'likes': None,
                    'urls': [], 'notes': [],
                }
                seen[row['key']] = row
                rows.append(row)
            row['titles'].append(item.get('title') or item['key'])
            row['sources'].append(f"{name}:{item['key']}")
            row['generations'].add(item.get('generation') or 'unknown')
            row['kinds'].add(item.get('kind') or 'unknown')
            if item.get('author'):
                row['authors'].add(item['author'])
            if item.get('license'):
                row['licenses'].add(item['license'])
            metrics = item.get('metrics') or {}
            for field in ('downloads', 'views', 'likes'):
                value = metrics.get(field)
                if isinstance(value, int) and (row[field] is None or value > row[field]):
                    row[field] = value
            if item.get('url'):
                row['urls'].append(item['url'])
            if item.get('notes'):
                row['notes'].append(f"{name}: {item['notes']}")

    matrix = []
    for row in rows:
        licenses = sorted(row['licenses'])
        verdicts = sorted({license_verdict(text) for text in licenses}) or ['none']
        match = have.get(row['key'])
        if match:
            status = 'have-derived'
        elif have_engine.get(row['key']):
            status = 'have-engine'
            match = have_engine[row['key']]
        elif not licenses:
            status = 'missing-no-licence'
        elif 'copyleft' in verdicts and 'permissive' not in verdicts:
            status = 'missing-copyleft'
        else:
            status = 'missing'
        curated = load_verdicts().get(row['key'], {})
        if curated.get('have_as'):
            status = 'have-derived'
            match = {'local_key': curated['have_as'], 'local_path': None}
        matrix.append({
            'key': row['key'],
            'title': sorted(row['titles'])[0],
            'status': status,
            'verdict': curated.get('verdict'),
            'verdict_reason': curated.get('reason'),
            'have_as': match['local_key'] if match else None,
            'local_path': match['local_path'] if match else None,
            'sources': sorted(row['sources']),
            'generations': sorted(row['generations']),
            'kinds': sorted(row['kinds']),
            'authors': sorted(row['authors']),
            'licenses': licenses,
            'license_verdict': sorted(verdicts),
            'downloads': row['downloads'],
            'views': row['views'],
            'likes': row['likes'],
            'urls': sorted(set(row['urls'])),
            'notes': row['notes'],
        })

    matrix.sort(key=lambda r: (r['status'], r['verdict'] or '', -(r['downloads'] or 0), r['key']))
    payload = {
        'sources': {name: sources[name]['counts'] for name in SOURCES},
        'counts': {},
        'rows': matrix,
    }
    counts = {}
    for row in matrix:
        counts[row['status']] = counts.get(row['status'], 0) + 1
    payload['counts'] = dict(sorted(counts.items()))
    (INVENTORY / 'coverage.json').write_text(json.dumps(payload, indent=2) + '\n')

    with (INVENTORY / 'coverage.csv').open('w', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['key', 'title', 'status', 'verdict', 'have_as',
                         'local_path', 'generations', 'kinds', 'authors',
                         'licenses', 'license_verdict', 'downloads', 'views',
                         'likes', 'sources', 'urls'])
        for row in matrix:
            writer.writerow([
                row['key'], row['title'], row['status'], row['verdict'] or '',
                row['have_as'] or '',
                row['local_path'] or '', ';'.join(row['generations']),
                ';'.join(row['kinds']), ';'.join(row['authors']),
                ';'.join(row['licenses']), ';'.join(row['license_verdict']),
                row['downloads'] if row['downloads'] is not None else '',
                row['views'] if row['views'] is not None else '',
                row['likes'] if row['likes'] is not None else '',
                ';'.join(row['sources']), ';'.join(row['urls']),
            ])
    print(json.dumps({'rows': len(matrix), 'counts': payload['counts']}, indent=2))


if __name__ == '__main__':
    main()
