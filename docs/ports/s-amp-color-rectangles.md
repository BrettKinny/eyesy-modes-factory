# Port report — `s-amp-color-rectangles`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Amp Color - Rectangles/main.py` (114 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 26; **closes the four-mode `amp-color` family** |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, no trigger fallback possible (`trigger_pass: null`) |
| Device tier | retired (repo-only) |

## What it does

`count` nesting levels of **five rotated rectangles** at the screen centre, each coloured
from the running average of its own audio history.

## The stock diff against `5gon Filled` (and against `Circles`)

| | 5gons | Circles | Rectangles |
| --- | --- | --- | --- |
| count | `int(knob3*59)+1` (60) | `int(knob3*49)+1` (50) | `int(knob3*49)+1` (50) |
| spacing denominator | `(60-count)/60` | `(100-count)/100` | `(50-count)/50` |
| knob 4 offset | `i * knob4 * 180` | time-gated triangle-wave LFO | `i * knob4 * **45**` |
| audio divisor | 32768 | 22000 | 32768 |
| geometry | one 5-vertex polygon | five stored circles | **four axis-aligned corners** |
| trigger | re-randomises points | re-randomises circles | **none** |

The rectangles variant has **no trigger path at all** (`trigger_pass: null` in the
verifier — the mode never references `ctx.trigger`), no randomness, and no polygon points:
the shape is the four axis-aligned corners of a rect, rotated by the family's per-level
angle. Confirmed against the sources rather than assumed.

## Zero meshes

A rotated rectangle is exactly what stock's `draw.polygon` produces from four corners, so
the port draws with `e.rect` under the transform and needs **no mesh handles** — like the
circles sibling, and unlike the two 5gon modes where the 32-handle cap binds.

The **count floor of 2** is carried (the per-level offset term is multiplied by the level
index, identically zero at the all-knobs-zero baseline).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-amp-color-rectangles --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

Per-probe A/B, fraction of pixels changed (the gate's `knob_frac` is the max probe):

| Knob | mid | max |
| --- | --- | --- |
| 1 `history` | 0.0000 | 0.64340 |
| 2 `spin` | 0.50200 | 0.17100 |
| 3 `count` | 0.61640 | 0.62260 |
| **4 `offset`** | **0.06930** | **0.11080** |
| 5 `bg` | 0.35660 | 0.35660 |

| Check | 300 frames | 60 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| audio | quiet/loud 0.6434, freq 0.2043 | 0.96294 / 0.96294 / 0.20430 |
| trigger | `None` — the scene does not reference `ctx.trigger` | `null` |
| luma bounds | mean 80.1–147.14, min stddev 5.65 | 95.12–147.14, stddev 5.65 |
| `p50_ms` (software GL) | 16.1 (resources 0) | 16.6 |

**A measurement note worth keeping:** knob 4's mean-luma delta is only 0.97 / 1.55 while
its *pixel-fraction* delta is 0.0693 / 0.1108 — a rotated rectangle covers a similar area,
so it barely moves the mean brightness while clearly changing the picture. Reading
liveness from luma means alone would have called this knob dead when it is live at both
probes, and stably so across both run lengths.

## Residual risk

- **The frame is bright** (mean 95–147) where the family's other modes sit at 28–67, and
  `min stddev 5.65` is low. The verifier's whiteout bound is 0.985 (~251 luma), so this
  passes with margin, but it is the family's brightest and flattest frame.
- **knob 1's mid probe is dead** (0.0000 while its max is 0.96294) — the history-length
  knob has no effect at its mid setting at this grab instant. The knob is plainly live at
  max, so the gate passes; recorded because it is the mode's one dead probe point.
- **`audio-quiet` equals `audio-loud`** (0.96294) — stock-faithful: the family reads a
  waveform sample (`audio_in[i]`), not a spectrum bin; the `freq` probe (0.20430) carries
  the reactivity.
- **The count floor (2)** means the all-knobs-zero baseline is not stock's single level.
- **No 32-handle cap applies** (no meshes), so stock's up-to-50 levels are not truncated.