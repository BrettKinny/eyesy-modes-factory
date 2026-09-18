# Inventory corpus — upstream mode coverage

Machine-readable enumeration of every EYESY mode/patch we know of in the wild,
one file per source, plus the local packs. These files are *inputs* to
`docs/research/CoverageMatrix.md` (the merged have/missing verdict); they are
not hand-edited — regenerate them from the live sources instead.

| File | Source | Enumerated by |
| --- | --- | --- |
| `patchstorage.json` | patchstorage.com EYESY platform | `tools/inventory/fetch_patchstorage.py` |
| `github-stock.json` | critterandguitari GitHub account | `tools/inventory/fetch_github_stock.py` |
| `pysey.json` | `martindefatte/pysey` community patch set | `tools/inventory/fetch_pysey.py` |
| `community.json` | community repos + repo discovery (GitHub, Codeberg) | `tools/inventory/fetch_community.py` |
| `local.json` | the packs on this machine | filesystem walk (see `local.md`); the pack's *ports* are scanned live by `build_coverage.py` |
| `verdicts.json` | curated portability verdicts (technique triage, licence facts) | hand-maintained; consumed by the merge |
| `coverage.csv`, `coverage.json` | merged matrix | `tools/inventory/build_coverage.py` |

Every file carries the same shape:

```json
{
  "source": "<source id>",
  "source_url": "<root url>",
  "fetched_at": "YYYY-MM-DD",
  "method": "<how items were enumerated>",
  "counts": {"total": 0, "by_generation": {}, "by_kind": {}, "by_license": {}},
  "items": [
    {
      "key": "<source-stable id>",
      "title": "<human title>",
      "author": "<name or null>",
      "generation": "v1-of-lua|v2-pygame|v3-pygame|engine|ours|unknown",
      "kind": "mode|example|library|non-mode|unknown",
      "url": "<live permalink>",
      "repo_path": "<path inside its repo, or null>",
      "license": "<string or null>",
      "created": "YYYY-MM-DD or null",
      "metrics": {"views": null, "likes": null, "downloads": null},
      "technique": "<one short line or null>",
      "notes": "<short, factual>",
      "raw": {}
    }
  ]
}
```

Rules the files follow:

- **Evidence only.** Every item carries a URL that was fetched at
  `fetched_at`. `null`/`"unknown"` beats a guess.
- **Keys are verbatim** upstream ids (PatchStorage slug, repo-relative folder
  path). The merge step normalises a *copy*: lowercase, strip a leading
  `s-`/`t-`/`u-` family prefix, strip a trailing version suffix (`-2`, `_v2`),
  collapse runs of non-alphanumerics to `-`. Normalisation never rewrites the
  stored keys.
- **Duplicates are recorded, not dropped.** A mode that exists in two sources
  appears in both files and is flagged in `notes`.

Regenerating everything (network, ~5 min):

```sh
python3 tools/inventory/fetch_patchstorage.py
python3 tools/inventory/fetch_github_stock.py
python3 tools/inventory/fetch_pysey.py
python3 tools/inventory/fetch_community.py
python3 tools/inventory/build_coverage.py   # offline; merges the four above + local.json
```

Raw HTTP responses are cached under `/tmp/eyesy-inventory/` and are never
committed.
