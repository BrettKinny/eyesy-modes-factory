# GitHub stock inventory — `critterandguitari`

Inventory of every mode shipped in the Critter & Guitari GitHub account, produced
live from the GitHub API on 2026-09-17. Machine-readable data:
`github-stock.json` (same directory). Regenerate with
`python3 tools/inventory/fetch_github_stock.py`.

Covered account: https://github.com/critterandguitari (a **user** account, not an
org). The account hosts 100+ repos; exactly **7** are EYESY-related, and only
**3** of those contain modes.

## Method

For each EYESY repo:

1. Metadata via `gh api repos/critterandguitari/<name>` (default branch,
   archived, stars, pushed_at, license, description).
2. Full file list via `gh api .../git/trees/<default_branch>?recursive=1`.
   A **mode folder** is any folder holding the generation's entry file
   (`main.py` for the Python generations, `main.lua` for the Lua generation).
   One item per mode folder: entry filename, file count, total bytes, permalink
   to the entry file on the default branch.
3. Root LICENSE file detection (contents fetched verbatim; stored in each item's
   `raw`/repo metadata).
4. Branch/tag survey (`/branches`, `/tags`) to catch any alternative mode set.

Errors/unknowns are never invented: per-mode `created`, `technique` and the
`metrics` block are `null` (GitHub does not expose them per file/dir, and
per-mode technique was not read for all 188 items).

## Counts

```
$ jq -r '.counts' docs/research/inventory/github-stock.json
{
  "total": 188,
  "by_generation": {
    "v3-pygame": 108,
    "v2-pygame": 66,
    "v1-of-lua": 14
  },
  "by_kind": {
    "mode": 174,
    "example": 14
  },
  "by_license": {
    "BSD-2-Clause": 108,
    "none": 80
  }
}
```

## Per-repo table

| Repo | Generation | Mode count | Licence | Archived | Last push | Created | Stars |
|---|---|---|---|---|---|---|---|
| EYESY_Modes_OSv3 | v3-pygame (`main.py`; `setup(screen, eyesy)` / `draw(screen, eyesy)`) | 108 | BSD-2-Clause (`LICENSE`) | no | 2025-06-16 | 2025-03-10 | 5 |
| EYESY_Modes_Pygame | v2-pygame (`main.py`; `setup(screen, etc)` / `draw(screen, etc)`) | 66 | **NO LICENSE FILE** | no | 2021-07-29 | 2020-08-10 | 32 |
| EYESY_oFLua_Examples | v1-of-lua (`main.lua`; `require("eyesy")`) | 14 | **NO LICENSE FILE** | no | 2023-01-26 | 2020-11-15 | 18 |
| EYESY_OF | v1-of-lua engine (C++/openFrameworks; no mode folders) | 0 | BSD-3-Clause (`LICENSE.txt`) | no | 2022-08-08 | 2020-04-04 | 4 |
| EYESY_OS | v3 OS/engine (Python engine + web editor; **no bundled modes**) | 0 | BSD-3-Clause (`LICENSE.txt`) | no | 2025-10-30 | 2020-05-16 | 69 |
| EYESY_Manual | docs (manual.md + images) | 0 | NO LICENSE FILE | no | 2022-04-08 | 2020-06-26 | 2 |
| EYESY_Selector | OF app (video-engine selector; no mode folders) | 0 | BSD-3-Clause (`LICENSE.txt`) | no | 2022-08-08 | 2022-08-08 | 1 |

Total: **188 items** (108 + 66 + 14 modes/examples; 174 `mode` + 14 `example`).

## Reconciliation against prior dossier claims

Claims in `docs/research/EyesyEcosystemMiner.md` (treated as claims, verified here):

| Prior claim | Observed | Delta |
|---|---|---|
| "~100 official OSv3.1 modes" in EYESY_Modes_OSv3 | 108 | +8 |
| "~65 v2.3 modes" in EYESY_Modes_Pygame | 66 | +1 |
| "14 early Lua examples" in EYESY_oFLua_Examples | 14 | 0 ✓ |
| "EYESY_OS (108 v3.1 modes + engine, 69*)" | EYESY_OS bundles **0 modes**; the 108 live in EYESY_Modes_OSv3; the "69*" star count does match EYESY_OS (69) | attribution error in old dossier |
| EYESY_Modes_OSv3 "S-/T-/U- prefixes" | confirmed: 78 `S`, 29 `T`, 1 `U` (U - Timer) = 108 | — |

## Overlap analysis

- **EYESY_OS bundled modes vs EYESY_Modes_OSv3: 0.** EYESY_OS, on every branch
  and tag surveyed (`master`, `oflua`, `dependabot/*`; tags `v3.1`, `v2.3`,
  `v2.1`, all `EYESY_v*.img` / `EY_v3*.img`), bundles **no mode folders**. Its
  only `main.py`-holding folder is `engines/python/` (the engine itself —
  excluded; see below). The claimed "108 v3.1 modes + engine" for EYESY_OS is
  wrong: the mode set ships in the separate EYESY_Modes_OSv3 repo.
- **Cross-repo overlap, OSv3 ↔ Pygame: 33 modes** are present in both repos
  (identical folder basenames; e.g. `S - Aquarium`, `S - AA Selector`, all the
  `Grid *` family). Both sides carry a "same mode also in …" note in
  `github-stock.json`; the merge step must collapse these 33 pairs.
  75 OSv3 modes have no Pygame counterpart; 33 Pygame modes have no OSv3
  counterpart (e.g. `S - Binary Star`, `S - Floating Ball`, `S - Interference -
  LFO`, `S - Big City Scroll`, `T - BoM OG Trans`, `S - Slinky Clock Text`).
- **Near-miss worth knowing:** `T- Trigon Traveller` (Pygame, missing space
  after `T-`) is the same mode as `T - Trigon Traveller` (OSv3) but is not
  caught by exact folder-name matching, and therefore not flagged in the JSON
  notes. After normalisation the handoff key for both is
  `t-trigon-traveller` — the merge step will see them as duplicates of each
  other. Villain: C&G's own naming inconsistency, not the normaliser.

## Branch/tag survey

- EYESY_Modes_OSv3: single branch `main`, no tags.
- EYESY_Modes_Pygame: single branch `master`, no tags (the v2.3 set).
- EYESY_oFLua_Examples: single branch `main`, no tags.
- EYESY_OF: single branch `master`, no tags.
- EYESY_OS: branches `master`, `oflua`, 4 `dependabot/pip/*`; tags `v3.1`,
  `v2.3`, `v2.1`, `EYESY_v3.1/3.0*/…img`. Inspected `v2.3`, `v2.1` and
  `oflua` trees: none contains mode folders (v2.3 bundles the `pd/` engine and
  `engines/oflua` + `engines/python` engines, not modes — the v2 mode set lives
  in EYESY_Modes_Pygame). Nothing to enumerate separately.
- EYESY_Manual / EYESY_Selector: single branches, no tags.

## Spot-checks (3 modes, entry files fetched live this session)

1. `EYESY_Modes_OSv3` · `S - Aquarium/main.py` — contains
   `def setup(screen, eyesy) :` and `def draw(screen, eyesy) :`
   (plus `def update_color`). v3-pygame contract confirmed.
   https://github.com/critterandguitari/EYESY_Modes_OSv3/blob/main/S%20-%20Aquarium/main.py
2. `EYESY_Modes_Pygame` · `T - Reckie/main.py` — contains
   `def setup(screen, etc) :` and `def draw(screen, etc) :`.
   v2-pygame contract confirmed (note the `etc` handler name, distinct from
   OSv3's `eyesy`).
   https://github.com/critterandguitari/EYESY_Modes_Pygame/blob/master/T%20-%20Reckie/main.py
3. `EYESY_oFLua_Examples` · `Rect/main.lua` — line 2 is
   `require("eyesy")   -- include the eyesy library`. v1-of-lua contract
   confirmed.
   https://github.com/critterandguitari/EYESY_oFLua_Examples/blob/main/Rect/main.lua

## Rejected candidates (non-modes)

- `EYESY_OS/engines/python/main.py` — the OSv3 engine entry, excluded via
  `EXCLUDE_FOLDERS` (`engines/python`). Not a mode.
- `EYESY_OF` — a C++/openFrameworks engine: `src/main.cpp`, `src/ofApp.cpp`,
  `src/ofApp.h`. No Lua/Python mode entry files exist in this repo, so nothing
  was counted; it is the engine repo, not a mode repo.
- `EYESY_Selector` — likewise pure OF app code (`src/main.cpp` …); no modes.
- `EYESY_Manual` — documentation only (`manual.md` + screenshots).
- Repo roots elsewhere in the account (ETC_*, Organelle_*, Video-Critter-*,
  etc.) belong to other Critter & Guitari instruments and carry no EYESY modes.

## Licensing and porting blockers

- `EYESY_Modes_OSv3` is explicitly **BSD-2-Clause** (`LICENSE`, © 2025
  Critter & Guitari) — clean for porting.
- `EYESY_Modes_Pygame` and `EYESY_oFLua_Examples` have **no LICENSE file** and
  GitHub reports no license. With OSv3 licensed, the practical questions are
  whether the v2 modes are cumulative ancestors of the licensed v3 set and
  whether the Lua examples are covered by the OSv3 BSD-2-Clause or the
  EYESY_OS/EYESY_OF BSD-3-Clause texts — but as stands they are **porting
  blockers** and must not be treated as licensed.
- `EYESY_OS` / `EYESY_OF` / `EYESY_Selector` carry a BSD-3-Clause `LICENSE.txt`
  (© 2020/2025 Owen Osborn, Critter & Guitari, Inc.) — relevant if engine
  semantics inform ports.

## Surprises

1. The old dossier's "EYESY_OS (108 v3.1 modes + engine)" misattributes the
   count; EYESY_OS ships no modes.
2. The Pygame set is not "a historical curiosity": 33 of its 66 modes were
   carried forward into OSv3; the 33 Pygame-only ones (Binary Star, Floating
   Ball, Interference, Big City Scroll, BoM OG Trans, Slinky Clock Text, …) are
   latest-known-shipped in the v2 generation only.
3. `T- Trigon Traveller` naming glitch (see overlap section).
4. OSv3 folder `S - 0 Arrival Scope` starts with a digit — sorted first, and
   its normalised key `s-0-arrival-scope` sorts first after merging.

## Not covered by this file

- PatchStorage EYESY platform entries → separate inventories.
- Community repos (pysey, caljup/eyesy-modes, degiere/eyesy-simulator) →
  separate inventories.
- Per-mode `technique`/porting analysis of all 188 items (spot-checked only);
  `raw.filelist` gives every file per mode for the port pass.