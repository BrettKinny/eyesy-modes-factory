# Port report — `t-draws-hashmarks-stepped-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Draws Hashmarks - Stepped Color/main.py` (69 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 11; third of the four-mode `T - Draws Hashmarks` family |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) — **but see the colour-change count below** |

## What it does

Vertical and horizontal hashmark strokes across the frame, each coloured separately.

## The offset was derived for this mode's own call count

The picker is called **per element, inside both loops** (verticals once per stroke, horizontals
once per stroke) with `inc_amt = 0.25` — and at the verifier's all-mid baseline that is **110 calls
per frame** (20 verticals + 91 horizontals).

`tools/lfo_offset.py --inc 0.25 --calls 110` gives **0.79** (step 13.75/frame, worst-case luma
clearance 38.85). The sibling's **0.99 was deliberately not copied**, because it was derived for a
different call count — which is exactly the discipline the family needed, since the four modes
have four different `inc_amt` values and call counts.

## The `T -` tranche's standing rules

- **Stock reads no audio**, so the pack's one documented audio term is added: vertical stroke `k`'s
  x nudged by `|left[1 + k*8]| * 0.15 * xr`, nil-guarded.
- **Six degenerate floors** carry over from the Angled siblings — count, span (width/x/y/height),
  linewidth `>= 3 px` (the `e.line` width-0 trap), a knob-scaled draw-count floor so `knob3` stays
  live between triggers, and initial spans set in `setup`.
- **`random` is imported but consumed only in the trigger branch** (the `vertLines`/x/y/width/
  height rolls); the draw path uses none, so `e.random()` is used exactly there, in stock's order.
- **`knob4 = 0.5` folds to the baseline colour** — its mid probe is a genuine no-op and liveness
  rests on max.
- The flat variant's verticals are `(xpos, y) → (xpos, height)` with **no angle roll**, which is
  the whole Angled-vs-flat difference.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-draws-hashmarks-stepped-color --frames 300` → `"verdict": "pass"`, `failures: []`. Per-probe table identical at 60 and 300 frames.

| Knob | mid | max | trig |
| --- | --- | --- | --- |
| 1 | 0.10407 | 0.34645 | not run |
| 2 | 0.03611 | 0.10677 | not run |
| 3 | 0.03594 | 0.05840 | not run |
| 4 | **0.00000** | 0.05514 | not run |
| 5 | 0.94486 | 0.94486 | not run |

**No `knobK-trig` run was executed** — every knob is live at mid or max, so the wrapper's
max-over-probes figure is not masking a dead knob.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.02695, loud 0.02396, freq 0.02246 — **pass** |
| luma bounds | 32.42–67.47, min stddev 14.38 |
| `p50_ms` (software GL) | 16.65 / 16.67 |

Grab stddevs run 14.38 (the tightest probe) to 46.76 — the figure is present everywhere, far above
the 0.51 flatness floor.

## Residual risk

- **Up to ~110 per-element colour changes per frame** — **above** the pack's measured 70-change
  cliff (+13.7 ms, outside tier C). There is no colour class to batch by: every stroke carries its
  own colour, and that per-stroke re-sample *is* the mode's look. A **predicted** device cost with
  no measurement available (the tier gate is retired), and the third mode in P3 alone carrying one
  (`t-bits-v-column-color` ~104, `s-mirror-grid` ~216).
- **Six degenerate floors** mean the baseline is more legible than stock's; each is documented.
- **The audio term is an addition to stock** — the mode's reactivity is the port's design.
- **`knob4`'s mid probe is a no-op by construction**, so liveness rests on max.