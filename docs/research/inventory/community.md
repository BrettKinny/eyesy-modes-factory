# Community inventory — the long tail

Machine-readable: `community.json` (472 items, 18 repos with modes). Regenerate:
`python3 tools/inventory/fetch_community.py` (authenticated `gh` for GitHub,
plain HTTPS for Codeberg; ~700 API calls cold).

Scope: every public repo that ships EYESY modes and is *not* the Critter & Guitari
account (`github-stock.json`) or `martindefatte/pysey` (`pysey.json`).

## Method

1. **Discovery** — three GitHub repository searches plus one code search, and the
   Codeberg repo search:

   | Query | Hits |
   | --- | --- |
   | `search/repositories?q=eyesy+in:name,description,readme` | 114 |
   | `search/repositories?q=eyesy-modes` | 14 |
   | `search/repositories?q=topic:eyesy` | 4 |
   | `search/code?q=eyesy.audio_in+in:file+filename:main.py` | 194 |
   | Codeberg `repos/search?q=eyesy` | ≤50 |

2. **Candidate scan** — each repo's git tree (default branch) is scanned for
   folders holding `main.py`/`main.lua`/`main.cpp` at depth ≤ 3. That yields 523
   candidates.
3. **Interface verification** — every candidate's entry file is fetched and
   checked for the mode contract (`def setup` + `def draw` for the Python
   generations; `require("eyesy")`/assignment-style setup for the Lua
   generation). 469 pass; 54 are rejected (see below). Counts in the JSON are
   the *verified* counts.

## Repos holding verified modes

| Repo | Modes | Licence | Last push | What it is |
| --- | --- | --- | --- | --- |
| `Arimuri/SHRTY` | 150 | NOASSERTION (custom) | 2026-03-31 | large mirror/collection, stock modes + Japanese-commented originals |
| `jeromedagustin/eyesy_projects` | 131 | **none** | 2026-06-12 | largest individual collection |
| `hdesoyres/eyesy-modes` | 72 | **none** | 2024-05-24 | mostly a stock-library mirror (`Modes/Python/…`) |
| `pmerienne/eyesy-modes` | 70 | **none** | 2021-12-02 | v2-era collection |
| `caljup/eyesy-modes` | 13 | **none** | 2025-07-23 | personal set incl. 3D pipelines, Doom wrapper |
| `stuart78/Eyesy-native` | 11 | **none** | 2026-02-09 | simulator repo with bundled example modes |
| `okyeron/EYESY_oFLua_Modes` | 8 | **none** | 2021-01-13 | **new find**: community v1-of-lua modes, not in the dossiers |
| `stuart78/eyesy_sim` | 5 | **none** | 2025-12-31 | simulator with examples |
| `Verbanderbog/eyesy-test-env` | 2 | MIT | 2022-07-19 | test env modes |
| `Syntheist/eyesy-snake` | 1 | **none** | 2020-12-08 | snake game mode |
| `balancespring/EYESY` | 1 | **none** | 2022-02-23 | one custom mode |
| `bosgood/eyesy-modes` | 1 | MIT | 2022-06-04 | one mode |
| `degiere/eyesy-simulator` | 1 | BSD-3-Clause | 2026-08-18 | simulator + one bundled example |
| `katk3n/eyesy-sandbox` | 1 | **none** | 2023-02-02 | scratch mode |
| `notmatthancock/eyesim` | 1 | MIT | 2022-06-05 | simulator + example |
| `tiroso/eyesy_module_beziertest` | 1 | **none** | — | single bezier test module |
| `twang69/hertsi` (Codeberg) | 1 | EUPL-1.2 | 2026-04-17 | Hertsi — the top-downloaded PatchStorage mode's source |
| `BrettKinny/Eyesy` | 1 | **none** | 2026-09-17 | our own engine repo's `starter` |

76 further repos matched the searches and ship no modes (engines, simulators,
docs, forks without changes, audio projects) — each with its reason in
`community.json:repos`.

## Rejected candidates (55)

All were rejected as `not-a-mode` by the interface check. Two distinct causes,
both worth knowing:

- **Our own modes** (`BrettKinny/eyesy-modes-bespoke/*`, `starter`, `milkdrop`)
  use *this platform's* table-return contract, not the stock `setup`/`draw`
  contract, so the stock interface check correctly does not apply. They are
  enumerated authoritatively in `local.json`; the rejections here are an artefact
  of running a stock-contract check over our own repo.
- Real non-modes: engine entry points, simulator apps and utilities that happen
  to contain a `main.py`.

## Licensing reality

The community tail is largely **unlicensed**: 316 of 472 items sit in repos with
no licence file at all, 150 in repos GitHub reports as `NOASSERTION` (custom or
unrecognised terms), and only 6 items sit in clearly licensed repos
(MIT ×5, BSD-3-Clause ×1) — plus `twang69/hertsi` under EUPL-1.2 on Codeberg.
Consequence: the community tail is safe to *read for technique* and to attribute,
but most of it cannot be copied or adapted without the author's permission.
Anything from this file that lands as a port needs a permission note or a
clean-room implementation from its described technique.

## Duplicates

Several of these repos are mirrors of the stock library (`hdesoyres/eyesy-modes`
carries the OSv3 set under `Modes/Python/`, `Arimuri/SHRTY` a similar set).
The merge step normalises names, so mirror items collapse onto the stock rows
and show up as extra sources rather than as separate "modes we don't have".

## Not covered

- Per-mode technique/port analysis for the tail (that is the port pass).
- Codeberg: its repo search matches **repository names only** (`q=eyesy` returns
  0 hits; `q=hertsi` returns `twang69/hertsi`), so the Codeberg sweep is an
  explicit repo list plus the search. Only `twang69/hertsi` (1 mode, EUPL-1.2)
  was found; the dossiers called it EUPL 1.1, the licence file says 1.2.
- GitLab/Gitea instances outside Codeberg, and dead-link/mail-only archives.
