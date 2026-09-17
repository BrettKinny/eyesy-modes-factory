# PatchStorage inventory — EYESY platform

Machine-readable: `patchstorage.json` (209 items). Regenerate:
`python3 tools/inventory/fetch_patchstorage.py` (no auth; ~230 HTTP requests,
~5 min cold, seconds warm).

Source: <https://patchstorage.com/platform/eyesy/> (platform id 6398).

## Method

The alpha API's platform filter is an **array** parameter:
`/api/alpha/patches/?platforms[]=6398` returns `x-wp-total: 209`. Every scalar
spelling (`platform=`, `platform_slug=`, `target=`) is silently ignored and
returns all 17 445 patches on the site — that trap is why this file exists as a
script. Listing responses carry the counters but not the licence or file list,
so each patch is fetched once more from its own `self` URL. Responses are cached
under `/tmp/eyesy-inventory/ps/`.

The server-rendered platform pages (`/platform/eyesy/page/N/`, 12 pages) yield
only **191** entries with `item-title` links. The API's 209 is authoritative:
the page listing omits entries (hidden/unlisted patches still counted by
`x-wp-total`). Both numbers were reproduced twice; the dossier's "209 entries"
is confirmed.

## Counts (live, 2026-09-17)

| Metric | Value |
| --- | --- |
| Patches | **209** (all with downloadable files → all `kind: mode`) |
| Uploads by Critter & Guitari themselves | 27 |
| Created range | 2020-11-10 … 2026-05-29 |
| With a machine-readable source link | 1 |

Top uploaders: `DudeTheDev` 53, `Turbulent Resonant Colon` 38,
`guerrilladigital` 36, `CritterandGuitari` 27, `jbohn` 9, `cuppofruppo` 7.

Categories (patch may carry several): Video 83, Effect 70, Synthesizer 66,
Composition 15, Game 6, Utility 5.

Top 12 by downloads: T - Isometric Wave Runner 870, T - Font Recedes (Update)
785, T - Isometric Wave 742, T - 10 Print 716, TwoCircleScope 666,
S - A ZACH Reactive 646, S - A ZACH Twisted Lotus 630, S - A ZACH Spiral 595,
Webcam 541, ofLua_SineWaveGradations 540, Boxwalk 522, S - A ZACH Runner 472.

## Licence distribution

Every patch states a licence; the spread decides what may be ported.

| Licence | n | Porting read |
| --- | --- | --- |
| The Unlicense | 41 | public domain — clean |
| BSD 2-Clause | 32 | clean with attribution |
| BSD 3-Clause | 31 | clean with attribution |
| WTFPL | 31 | clean |
| CC-BY-SA 4.0 | 18 | share-alike: derived mode must carry the same licence |
| Academic Free License 3.0 | 17 | permissive-with-conditions — read before porting |
| CC0 1.0 | 9 | clean |
| CC-BY 4.0 | 9 | clean with attribution |
| GNU GPL 3.0 | 2 | copyleft: the derived mode inherits GPL-3.0 |
| Open Software License 3.0 | 3 | copyleft |
| EUPL 1.1 | 1 | copyleft (EU) |
| Artistic 2.0 | 1 | permissive |
| MIT | 1 | clean |
| "Creative Commons license family" | 5 | unspecified CC variant — resolve per patch |
| "Custom License" | 8 | read the patch body before porting |

## Generation

Patch pages rarely say which API generation a mode targets: only 11 of 209 state
a version in text (6 openFrameworks/Lua, 3 v3, 2 v2). `generation` is therefore
`unknown` for 198 items, and `raw.generation_evidence` records the matched
phrase when one exists. **Do not trust a guess here** — read the mode's
`main.py` at port time (the merged coverage row says which generations the same
mode exists in elsewhere, which is the useful signal).

## Handoff to the merge step

PatchStorage's `S - …`/`T - …` uploads of the same mode come in pairs (`-2`
suffix = the later upload). Normalised keys collapse those pairs and collapse
Critter & Guitari's 27 stock uploads onto the stock inventory rows, so a mode
that exists on PatchStorage *and* in `EYESY_Modes_OSv3` becomes one coverage row
with three sources.
