# Port report — `t-draws-hashmarks-angled-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Draws Hashmarks - Angled - Uniform Color/main.py` (69 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 10; second of the four-mode `T - Draws Hashmarks` family |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

Angled hashmark strokes across the frame, all in **one** colour sampled once per frame.

## The family's Stepped/Uniform rule, confirmed structurally

The two ports differ exactly where they should, verified by diffing them:

| | `Stepped` | `Uniform` |
| --- | --- | --- |
| `e.color` call sites | **two, inside the loops** (lines 234, 255) | **one, at the top** (line 227) |
| `inc_amt` | — | **0.07** |
| derived offset | — | **0.22** (`tools/lfo_offset.py --inc 0.07 --calls 1`, worst-case clearance 35.28) |

So the Uniform port needs **no batching concession** — 3 colour state changes per frame (clear +
one foreground colour).

**The two ports' verifier numbers are identical across all five knobs, the luma range and the
stddev, and that is correct rather than suspicious.** `frac` counts pixels that differ *at all*
from the base grab; the geometry is shared between the modes and the knob probes change geometry
(count, widths, spans), so every stroke pixel differs from the base in both modes whatever colour
it receives. The colours differ; the changed-pixel *count* does not.

## The `T -` tranche's standing rules, applied

- **Stock reads no audio**, so the pack's one documented audio term is added (deviation 11):
  vertical stroke `k`'s start x nudged by `|left[1 + k*8]| * 0.15 * xr`, nil-guarded; horizontals
  untouched.
- **Six degenerate floors were needed** — the most any mode in this tranche has required, and each
  one load-bearing:
  1. vertical line count `>= 6`;
  2. `width >= 160`, x in `[0, W-200]`, y in `[-160, H-120]`, `height >= max(y+120, 120)` (span
     floors);
  3. linewidth `>= 3 px` — the **`e.line` width-0 trap**, which returned a flat frame on every run
     for the sibling;
  4. the `knob3`-scaled draw count `n = max(6, floor(knob3*vertLines))`, so `knob3` stays live
     between triggers;
  5. the horizontal gate `knob1 > 0` removed;
  6. the initial spans set in `setup` instead of zero.
- **`knob4 = 0.5` folds to the baseline colour** — its mid probe is a genuine no-op and liveness
  rests on max.

## Rendering

`n + lines` `e.line` calls per frame — up to ~178 (78 vertical + 100 horizontal) — and **no meshes
at all**. One `e.color` per frame.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-draws-hashmarks-angled-uniform-color --frames 300` → `"verdict": "pass"`, `failures: []`.

| Knob | mid | max | trig |
| --- | --- | --- | --- |
| 1 | 0.10407 | 0.34645 | not run |
| 2 | 0.03611 | 0.10677 | not run |
| 3 | 0.03594 | 0.05840 | not run |
| 4 | **0.00000** | 0.05514 | not run |
| 5 | 0.94486 | 0.94486 | not run |

**No `knobK-trig` run was executed** — every knob is live on its own probes, so the second chance
never fired and the verdict is not a trigger artifact.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.02695, loud 0.02396, freq 0.02246 — **pass** |
| trigger | frac 0.01653, pass |
| luma bounds | 32.43–67.47, min stddev 14.38 |
| `p50_ms` (software GL) | 15.96 / 16.50 |

## Residual risk

- **Six degenerate floors** mean the all-knobs-zero baseline is materially more legible than
  stock's; each is documented with its look impact in the header.
- **The audio term is an addition to stock** — the mode's reactivity is the port's design.
- **`knob4`'s mid probe is a no-op by construction**, so liveness rests on max.
- **~178 `e.line` calls per frame** at the extreme knob settings — draw calls are cheap in the
  pack's measurements (the cost lever is colour *state* changes, and there is one), but it is the
  tranche's highest stroke count.