# Coverage matrix — what we have, what we do not

The answer to "which EYESY modes do we have?" as of **2026-09-17**, built from
live sources by the per-source inventories in `docs/research/inventory/`
(regeneration commands at the bottom). Machine-readable form:
`inventory/coverage.csv` (every row) and `inventory/coverage.json` (same rows
plus provenance).

## Headline

| | Count |
| --- | --- |
| Upstream mode/patch items enumerated | **905** (across 4 upstream sources; +38 local) |
| Distinct upstream modes after name-normalisation | **406** |
| Covered by a scene we already ship | **5** (all *derived* — a bespoke original, not a stock port) |
| **Not covered** | **401** |
| — of those, licence-clear enough to port | 295 |
| — of those, copyleft-only (port inherits the licence) | 21 |
| — of those, **no licence at all** (technique-only, needs permission) | 85 |
| Modes in this repo (`eyesy-modes-factory`) | **0** |

Read "not covered" precisely: no mode in the factory pack ports it. Several
missing rows *are* reachable as technique because a bespoke scene already covers
the same algorithm (the five `have-derived` rows below) or because the mode is a
mirror of another source we do have.

## What we have

The 37 scenes we ship live in `eyesy-modes-bespoke` (36) and
`eyesy-modes-milkdrop` (1), plus the engine-owned `starter`. Five of them line up
with an upstream mode:

| Upstream row | Upstream title | Our scene | Evidence |
| --- | --- | --- | --- |
| `reaction-diffusion` | T - Reaction Diffusion (pysey + PatchStorage) | `reaction-diffusion` | same name; bespoke README batch-1 table |
| `flow-field-drift` | T - Flow Field Drift (pysey + PatchStorage) | `flow-field-drift` | bespoke `docs/batch2-plan/PLAN.md:21` ("port (pysey)") |
| `strange-attractor` | S - Strange Attractor (pysey + PatchStorage) | `lorenz-trail` | bespoke README batch-1 table |
| `whitney-fans` | S - Whitney Fans (pysey + PatchStorage) | `whitney-kaleido` | bespoke README batch-1 table |
| `chladni-resonance` | S - Chladni Resonance (pysey + PatchStorage) | `chladni-plate` | bespoke README batch-1 table |

Derived, not ported: different names, different code, and the coverage goal is
"every stock mode", so the stock port of each is still owed. The curation lives
in `inventory/verdicts.json` with its evidence.

## Coverage by source family

| Family | Rows | What it is | Inventory file |
| --- | --- | --- | --- |
| Critter & Guitari stock set | 151 | 108 OSv3 modes + 29 Pygame-only modes + 14 oFLua examples | `github-stock.json` |
| PatchStorage community uploads | 190 | the EYESY platform's 209 entries (updates/`-2` pairs collapsed) | `patchstorage.json` |
| Community repositories | 249 | GitHub/Codeberg tail incl. mirrors of the stock set | `community.json` |
| pysey patch set | 18 | the community engine's V2/V3 patches | `pysey.json` |

(Rows carry multiple families: 115 rows are stock+community, 23 stock+community+
PatchStorage, 18 PatchStorage+pysey, 23 community+PatchStorage.)

Stock-set breakdown — this is the part the README's coverage goal names
explicitly:

| Stock subset | Rows | Licence situation |
| --- | --- | --- |
| `EYESY_Modes_OSv3` (v3.1, Python/pygame) | 108 | BSD-2-Clause — clean to port with attribution |
| `EYESY_Modes_Pygame` (v2.3) modes with no OSv3 counterpart | 29 | **repo has no licence file** — permission needed |
| `EYESY_oFLua_Examples` (v1, Lua/openFrameworks) | 14 | **repo has no licence file** — permission needed |
| Pygame modes that were carried forward into OSv3 | 37 | collapsed into the OSv3 rows above |

The 29 v2-only modes: `big-city-scroll`, `binary-star`, `bits-h`, `bits-v`,
`bom-og-trans`, `circle-scope-connected`, `circle-scope-img`,
`dancing-circle-img`, `density-squares`, `draws-hashmarks-new`, `floating-ball`,
`grid-circles-filled`, `grid-polygons`, `grid-slide-square`,
`grid-slide-square-filled`, `grid-triangles`, `h-circles-img`,
`image-circle-img`, `interference-lfo`, `line-bounce-four-lfo`,
`line-bounce-two-lfo`, `marching-four-img`, `perspective-lines-lfo`,
`radial-scope`, `radiating-square`, `slinky-clock-text`, `sound-jaws-ag`,
`square-shadows`, `x-scope-new`.

## The gap list

Full list with licence, downloads and provenance: `inventory/coverage.csv`
(sorted `missing` first, highest downloads first within each status).

Highest-demand gaps (PatchStorage download counts, collected live):

| Key | Title | Downloads | Licence |
| --- | --- | --- | --- |
| `isometric-wave-runner` | T - Isometric Wave Runner | 870 | The Unlicense |
| `font-recedes-update` | T - Font Recedes (Update) | 785 | BSD 3-Clause |
| `isometric-wave` | T - Isometric Wave | 742 | Custom |
| `10-print` | T - 10 PRINT | 716 | Custom / MIT |
| `twocirclescope` | TwoCircleScope | 666 | CC-BY-SA 4.0 (copyleft) |
| `a-zach-reactive` | S - A ZACH Reactive | 646 | Custom |
| `a-zach-twisted-lotus` | S - A ZACH Twisted Lotus | 630 | The Unlicense |
| `a-zach-spiral` | S - A ZACH Spiral | 595 | The Unlicense |
| `webcam` | U - Webcam | 541 | CC0 |
| `oflua-sinewavegradations` | ofLua_SineWaveGradations | 540 | CC-BY 4.0 |
| `boxwalk` | Boxwalk | 522 | CC-BY-SA 4.0 (copyleft) |
| `a-zach-runner` | S - A ZACH Runner | 472 | Custom |
| `oflua-filledcolors` | ofLua_FilledColors | 452 | CC-BY 4.0 |
| `spirocircles` | spirocircles | 447 | CC-BY-SA 4.0 (copyleft) |
| `spirograph` | Spirograph | 443 | CC-BY-SA 4.0 (copyleft) |
| `phyllotaxis` | Phyllotaxis | 441 | WTFPL |
| `a-zach-trailing-spiral` | S - A ZACH Trailing Spiral | 424 | The Unlicense |
| `z-voxel-starfield-jammed` | Z - Voxel Starfield Jammed | 385 | AFL-3.0 |
| `dancing-image-triggered` | Dancing Image Triggered | 335 | CC-BY-SA 4.0 (copyleft) |
| `arroyo-boids` | Arroyo Boids | 309 | CC-BY 4.0 |

Technique ranking (which of these is worth the port) is already worked out in
`docs/research/PatchStorageBestOf.md`; this file only fixes *what exists* and
*what is licensed*.

## Gates that decide whether a gap is portable

| Gate | Rows affected | Consequence |
| --- | --- | --- |
| No licence anywhere (repo or patch) | 85 | technique only: clean-room or written permission |
| Copyleft only (GPL/AGPL/EUPL/CC-BY-SA/OSL) | 21 | port is allowed, the ported mode inherits the licence |
| Copyleft + permissive across the same mode's sources | 11 | the most restrictive source wins |
| `check` verdict present (custom/AFL/"Creative Commons license family") | 232 | read the patch body before porting |
| Engine gap: `ctx.auto_clear` not exposed | all persist/trail modes | blocked on engine work, not porting effort (see the parity plan in the engine repo) |

## Decided not worth porting

Curated in `inventory/verdicts.json`, carried from `PatchStorageBestOf.md`:
`words` (label-only text), `branded-backdrop` (cycling branding text),
`smpte-standby` (broadcast test pattern). They stay in the matrix as `missing`
with a `not-worth` verdict so the decision is visible rather than silently
dropped.

## Known limits of this matrix

- **Name normalisation, not content hashing.** Keys strip the `S - `/`T - `/`U - `
  family prefix and a trailing version suffix (`-2`, `_v2`) and collapse
  non-alphanumerics. That correctly merges C&G's own spelling variants
  (`T- Trigon Traveller` = `T - Trigon Traveller`), PatchStorage's `-2` re-uploads
  and the community mirrors — but two genuinely different modes that share a name
  would merge. Nothing observed does.
- **PatchStorage "(Update)" uploads stay separate rows** (`font-recedes-update`
  vs stock `font-recedes`) because the page does not say it replaces the earlier
  upload.
- **Generation is often unknown** for PatchStorage rows (198 of 209 pages do not
  state an API generation). The merged row's `generations` list shows what the
  same mode looks like in the sources that do state it.
- **Community-tail items are interface-verified, not technique-verified**: a row
  proves a mode folder exists and implements `setup`/`draw` (or the Lua
  contract), not that it is interesting or shippable.
- Counts move: rerun the fetch scripts; PatchStorage gains entries every month.

## Regenerate

```sh
python3 tools/inventory/fetch_patchstorage.py     # 209 EYESY patches
python3 tools/inventory/fetch_github_stock.py     # critterandguitari account
python3 tools/inventory/fetch_pysey.py            # pysey patch set
python3 tools/inventory/fetch_community.py        # community repos + discovery
python3 tools/inventory/build_coverage.py         # merge -> coverage.json/.csv
```

Raw HTTP responses cache under `/tmp/eyesy-inventory/`; nothing fetched is
committed. Each `inventory/*.md` documents its own method, counts, spot-checks
and reconciliations against the older dossiers in `docs/research/`.
