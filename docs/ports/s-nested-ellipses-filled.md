# Port report — `s-nested-ellipses-filled`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Nested Ellipses - Filled/main.py` (75 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 36 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

Up to 50 filled ellipses nested inside one another, each sized and coloured by its own slot
in an audio history ring.

## Audio and picker

- **Divisor 15000, with `abs`**: `current_value = abs(audio_in[i] / 15000)`, stock index `i` →
  `left[1 + i*10]` × 32768 then `/ 15000`. Another one-off value from this library's long tail.
- **`color_picker_lfo(knob4, 0.08)`** with a per-call step `inc = (knob4-0.5)*2*0.08`, ramped at
  `count * inc * 30` per second — so the port advances its index by `inc * count * 30 * dt` per
  frame, keeping the per-element step and applying **no `lfo_offset` phase**. The deterministic
  middle branch substitutes for the legacy picker.

## Deviations

1. **Legacy picker → deterministic middle branch**, with the per-element ramp preserved.
2. **Background phase fold** `c = (bg*0.7+0.15) % 1`.
3. **The LFO ramp runs at every `knob4`.** Stock's static branch (below 0.5) renders **one solid
   ellipse**, which makes `knob2` and `knob3` unobservable — a stock-faithful deadness that fails
   the gate. At `knob4 = 0.5` the port is byte-identical to stock's static branch; below it the
   look changes from one solid ellipse to banded nesting. This is the pack's
   "knob the baseline multiplies by zero" treatment applied to a branch rather than an index.
4. **Count floored at 2** (stock's `count = 1` makes `knob2`'s index term identically zero — the
   family's known trap).
5. **Count capped 50 → 32** by the 32-mesh-handle budget, since each ellipse needs its own
   handle for its own colour.
6. **History ring pushes once per 60-fps frame**, so its window is `N/60` s against stock's
   `N/30` s — the pack's existing convention for this idiom.

## Rendering

**32 mesh handles** (the engine cap, `resources: 32`), each a 36-segment triangle fan
(37 vertices: centre + boundary) with a static **1-based** 108-index buffer. Per frame:
1 `e.clear` + up to 32 `e.color` + up to 32 `e.update_mesh` + up to 32 `e.draw_mesh` (≤97
calls), zero allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-nested-ellipses-filled --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed (300 frames):

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.11473 | 0.14284 |
| 2 | 0.10059 | 0.16483 |
| 3 | 0.41515 | 0.32868 |
| 4 | 0.41512 | 0.41512 |
| 5 | 0.58488 | 0.58488 |

| Check | 300 frames | 60 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| audio | quiet 0.40100, loud 0.64431, freq 0.02319 | same profile |
| trigger | not referenced — and no knob was weak, so the second-chance path never fired |
| luma bounds | 31.93–**207.76**, min stddev **26.98** | 30.65–141.64, stddev 18.48 |
| `p50_ms` (software GL) | 16.67 (resources 32) | 16.65 |

**The healthiest margins in the pack so far** — `min stddev 26.98` against the 0.51 flatness
floor, and four of the five knobs above 0.1.

## Residual risk

- **Deviation 3 changes the look below `knob4 = 0.5`**: banded nesting where stock draws one
  solid ellipse. Above 0.5 and at exactly 0.5 the port is stock-exact. The alternative was a
  permanently dead `knob2`/`knob3`.
- **The count cap (50 → 32)** is the family's recurring fidelity loss: stock's largest settings
  draw more ellipses than the handle budget allows.
- **The 300-frame luma maximum is 207.76**, against the verifier's whiteout bound of ~251. It
  passes with room, but it is the brightest frame in the pack — a stricter bound or a brighter
  palette could approach it.
- **The history window is half as long** (`N/60` s vs `N/30` s) because the ring pushes once per
  60-fps frame.
- **`freq`'s probe is thin** (0.02319) relative to the level probes (0.40 / 0.64).