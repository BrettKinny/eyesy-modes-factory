# pysey inventory — `martindefatte/pysey`

Machine-readable: `pysey.json`. Regenerate: `python3 tools/inventory/fetch_pysey.py`
(authenticated `gh`; ~40 API calls).

The living community EYESY/ETC engine. Its `modes/` tree carries the strongest
community patch set — the "GuerrillaDigital" material the ecosystem dossier
ranked highest.

## Counts (live, 2026-09-17)

| Metric | Value |
| --- | --- |
| Patch folders (`modes/*/*/main.py`) | **36** |
| Generation split | 18 `modes/V2` (v2-pygame, `setup(screen, etc)`) + 18 `modes/V3` (v3-pygame, `setup(screen, eyesy)`) |
| With a per-patch `README.md` | 33 |
| Per-patch licence: BSD 2-Clause | 31 |
| Per-patch licence: BSD 2-Clause + BSD 3-Clause base (the two Randumbizer patches) | 2 |
| Per-patch licence: undocumented (no README) | 3 |

The three undocumented patches are `modes/V3/Randumbizer LFO SWEEP O+-TR`,
`modes/V3/Randumbizer VCR O+-TR` and `modes/V3/S - Circle Grid`. They inherit
the repo root licence only: **GPL-3.0**, which the repo's own `notice.md` and
`README` do not reconcile with the per-patch BSD-2 claims. Practical reading:
the V2 set (18 patches, every one documented BSD-2) is the clean porting pool;
V3 Randumbizer/Circle Grid are GPL-3.0 unless their authors say otherwise.

Prior claims reconciled: the dossier's "18 documented BSD-2 patches" is the
**V2** set exactly. The tree now holds 36 patches (V3 was doubled up with a
second generation of the same 15 named patches plus the three above).

## Mapping to PatchStorage

pysey's READMEs almost never cite their PatchStorage upload (only
`randomizer-o-tr` does), so the mapping is name-based: the same `S - …`/`T - …`
titles appear on PatchStorage as e.g. `s-strange-attractor-2` (the `-2` upload of
`S - Strange Attractor`). The merge step normalises both to one key, so a pysey
patch and its PatchStorage upload collapse to a single coverage row with two
sources — PatchStorage carries the popularity, pysey carries the readable
licence and full README.

## Spot checks (fetched live this session)

1. `modes/V3/S - Strange Attractor/main.py` — 7574 bytes, `def setup`/`def draw`
   present, 12 `eyesy.` API references → the v3-pygame contract.
2. `modes/V2/T - Reaction Diffusion/main.py` — 11969 bytes, `def setup`/`def draw`
   present, 0 `eyesy.` references (v2 used the `etc` handler) → the v2-pygame
   contract, i.e. the generation split in `pysey.json` is real, not parsed from
   the path alone.
3. Every `main.py` in `modes/V2` and `modes/V3` was enumerated from the git tree
   by the fetch script; the counts above are the script's output, not a README
   claim.

## Not covered

- The pysey engine itself (it is an emulator, not a mode pack).
- Rendering viability per patch — that is `docs/research/PatchStorageBestOf.md`
  (ranked port specs) plus the port-pass work.
- The V2/V3 duplicate pairs are recorded as separate items; the merge step
  collapses them by normalised key, so a generation port owes both generations
  unless the dossier says the v2 original is the only difference.
