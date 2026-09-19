# Port report — `t-draws-hashmarks-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Draws Hashmarks - Uniform Color/main.py` (69 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 12; **closes the four-mode `T - Draws Hashmarks` family** |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

Vertical and horizontal hashmark strokes across the frame, all in **one** colour sampled once per
frame.

## The family's four offsets, all derived

`color_picker_lfo(knob4, 0.075)` is called **once per frame, before both loops** — the Uniform
rule — so the port needs one `e.color` per frame and no batching concession. The offset was
**derived for this mode's own step**: `tools/lfo_offset.py --inc 0.075 --calls 1` → **0.72**.

That completes a family where **every mode needed its own offset**, and none could be inherited:

| mode | `inc_amt` | calls/frame | derived offset |
| --- | --- | --- | --- |
| Angled Stepped | — | per element | — |
| Angled Uniform | 0.07 | 1 | **0.22** |
| Stepped | 0.25 | **110** | **0.79** |
| Uniform | 0.075 | 1 | **0.72** |

Two modes with one call per frame still land on different offsets (0.22 vs 0.72) because their
`inc_amt` differs — which is exactly why the briefs require deriving rather than copying.

## The `T -` tranche's standing rules

- **Stock reads no audio**, so the pack's one documented audio term is added.
- **Six degenerate floors** carry over from the siblings (count, span on width/x/y/height, the
  3 px linewidth floor from the `e.line` width-0 trap, a knob-scaled draw-count floor so `knob3`
  stays live between triggers, and initial spans set in `setup`).
- **`random` is consumed only in the trigger branch**, so `e.random()` is used exactly there, in
  stock's order.
- **`knob4 = 0.5` folds to the baseline colour** — a genuine mid-probe no-op, liveness on max.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-draws-hashmarks-uniform-color --frames 300` → `"verdict": "pass"`, `failures: []`. Per-probe table identical at 60 and 300 frames.

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
| trigger | frac 0.01648, pass |
| luma bounds | 32.42–67.47, min stddev 14.38 |
| `p50_ms` (software GL) | 16.65 / 16.65 |

## Residual risk

- **Six degenerate floors** mean the all-knobs-zero baseline is more legible than stock's; each is
  documented with its look impact.
- **The audio term is an addition to stock** — the mode's reactivity is the port's design.
- **`knob4`'s mid probe is a no-op by construction**, so liveness rests on max.
- **No per-element colour cost here** — the Uniform rule means one colour per frame, unlike the
  Stepped sibling's ~110 changes.

## Family close-out

Four modes, and the family's variation is two axes: **Angled vs flat** (whether the verticals carry
an angle roll) and **Stepped vs Uniform** (the picker's call site — per element vs once per frame).
Neither is visible from the mode's name, and the four modes needed **four separately derived phase
offsets** because their `inc_amt` values and call counts all differ.