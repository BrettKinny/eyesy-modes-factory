# Port report — `t-bits-v-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Bits V - Uniform Color/main.py` (56 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 7; **closes the four-mode `T - Bits` family** |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` (all 17 runs passed) |
| Device tier | retired (repo-only) |

## What it does

Columns of vertical bars whose length and shadow come from two knobs, all in one foreground colour.

## The family's call-site rule, confirmed from both directions

| | call site | `inc_amt` | phase offset |
| --- | --- | --- | --- |
| H Row | inside the loop | 0.15 (default) | — |
| H Uniform | before the loops | 0.15 (default) | 0.21 → **0.01** |
| V Column | inside the loop | **0.1** explicit | 0.21 |
| V Uniform | before the loops | 0.15 explicit | **0.01** |

The **offset was derived, not copied** — `tools/lfo_offset.py --inc 0.15 --calls 1` gives **0.01**
(step 0.075/frame, worst-case luma clearance 42.04), where the Column sibling's `inc_amt = 0.1`
gives 0.21. The offset depends on the step, and the four modes split two-and-two on both axes.

The port is faithful with **one `e.color` per frame** for the whole foreground pass — 3 colour
state changes per frame in total (clear, shadow, foreground) — and no batching concession, since
the Uniform rule genuinely means one colour.

## V geometry and the floors

The V siblings share their geometry: vertical bars, `count = knob1*xr*0.078 + 2`,
`length = knob2*yr*0.417 + 1`, `thickness = int((xr + 65)/lineAmt)`, random y from
`randrange(int(-yr*0.278), yr)`. Two degenerate floors carry over and are both required: the
**count** (floored at 8 — at stock's minimum of 2 the 672-px-thick columns land off-screen at the
verifier's fixed seed and the baseline goes flat) and the **length** (floored at `int(yr*0.02)`
≈ 14 px — stock collapses to 1 px at `knob2 = 0`).

Stock reads **no audio**, so the pack's one documented audio term is added as in all four modes.

## Rendering

**No meshes**: `2*(lineAmt+2)` `e.rect` calls (shadow pass then foreground pass, stock order) —
10 rects at the baseline knobs, 208 at maximum. **3 colour state changes** per frame.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-bits-v-uniform-color --frames 300` → `"verdict": "pass"`, `failures: []`. All 17 runs passed; per-probe table identical at 60 and 300 frames (to 2e-5).

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.18713 | 0.22790 |
| 2 | 0.15841 | 0.35387 |
| 3 | 0.00849 | 0.00849 |
| 4 | **0.00000** | 0.03771 |
| 5 | 0.96229 | 0.96229 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.03982, loud 0.23179, freq 0.05610 — **pass** |
| trigger | `trigger_pass: true` — every knob is live on its own, so no false liveness |
| luma bounds | 28.54–66.10, min stddev 7.71 |
| `p50_ms` (software GL) | 16.64 / 16.66 |

The numbers match the V Column sibling exactly, as the H pair did — shared geometry, floors and
audio term, with only the call site differing.

## Residual risk

- **The audio term is an addition to stock** — the mode's reactivity is the port's design.
- **Two degenerate floors** mean the baseline is more legible than stock's, which draws a single
  flat colour there.
- **`knob3`'s margin is thin** (0.00849) — the shadow recolour moves few pixels.
- **`knob4`'s mid probe is a no-op by construction** (stock-faithful), so liveness rests on max.
- **Stock's own geometry overflows the frame** at high counts; kept stock-exact.

## Family close-out

Four modes, four ports, and the family's entire internal variation turned out to be **two axes**:
the bar orientation (H/V, which changes five constants) and the picker's **call site** (per element
vs per frame, which decides whether the mode needs one colour or one per element). Neither axis is
visible from the mode's name — `T - Bits V - Uniform Color` and `T - Bits H - Uniform Color` differ
in five geometry constants, and `Row`/`Column` differ from `Uniform` only in where one call sits.