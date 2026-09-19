# Port report — `t-bits-h-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Bits H - Uniform Color/main.py` (55 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 5; second of the four-mode `T - Bits` family |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

Rows of horizontal bars whose length and shadow come from two knobs, all in one foreground colour.

## The family difference: where the picker is sampled

This is the whole of the Row-vs-Uniform distinction, and it is a **call site**, not a formula:

| | `T - Bits H - Row Color` | `T - Bits H - Uniform Color` |
| --- | --- | --- |
| picker call | **once per row**, inside the foreground loop | **once per frame**, before both loops (stock line 31) |
| picker args | `color_picker_lfo(knob4, 0.15)` | `color_picker_lfo(knob4, 0.15)` — identical |
| result | a colour per row | one `(r, g, b)` reused for every bar |

So the port is faithful with **one `e.color` per frame** for the foreground — no per-element
handling, and none of the batching concessions the Row variant needs. The shadow is one more
`e.color` (`bg * (knob3*0.5+0.5)`) for its whole pass.

That is the same lesson the radial-scope pair taught in P2: **two modes can call the identical
picker with identical arguments and differ entirely in where the call sits** — and reading the
mode's own source is the only way to tell.

## The rest, carried from the verified sibling

- **Stock reads no audio** (no `audio_in`, no `eyesy.audio` anywhere in the four `T - Bits`
  sources), so the port adds the pack's one documented audio term — row `k`'s bar length extended
  by `|left[1 + k*10]| * 0.25 * ctx.width`, nil-guarded past the buffer.
- **Two degenerate floors**, both required for a legible baseline: the **row count** (`lineAmt`
  floored at 8 — stock's minimum of 2 puts the figure off-screen at the verifier's fixed seed) and
  the **bar length** (floored at `int(xr*0.02)` ≈ 25 px, since stock collapses to 1 px at
  `knob2 = 0`).
- **`knob4 = 0.5` is a genuine no-op** — `picker(0)` is grey, the baseline colour — so its mid
  probe reads 0.0 by construction and liveness rests on max.
- **The LFO phase offset 0.21** on the ramp branch (derived for `inc_amt = 0.15` at one call per
  frame), the deterministic middle branch, the background phase fold, and the 30 → 60 fps
  re-timing.

## Rendering

**No meshes**: `2*(lineAmt+2)` `e.rect` calls (shadow pass then foreground pass, in stock's
order), at most 208 draws, with **3 colour state changes** per frame (clear, shadow, foreground).
`xpos`/`xpos1`/`lens` are preallocated at `MAX_ROWS = 128` and mutated in place.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-bits-h-uniform-color --frames 300` → `"verdict": "pass"`, `failures: []`. Per-probe fractions **identical at 60 and 300 frames** (scene sha256 unchanged across both).

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.16410 | 0.18468 |
| 2 | 0.09236 | 0.20890 |
| 3 | 0.00598 | 0.00598 |
| 4 | **0.00000** | 0.03977 |
| 5 | 0.96023 | 0.96023 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.03411, loud 0.14737, freq 0.03817 — **pass** |
| trigger | `trigger_pass: true` — but every knob is live on its own, so no false liveness |
| luma bounds | 29.03–66.31, min stddev 10.39 |
| `p50_ms` (software GL) | 16.64 / 16.65 |

The numbers match the Row-colour sibling exactly, which is expected: the two modes share the
geometry, the floors and the audio term, and differ only in how many times the picker is sampled.

## Residual risk

- **The audio term is an addition to stock** — the mode's reactivity is the port's design.
- **Two degenerate floors** mean the baseline is more legible than stock's, which draws a single
  flat colour there.
- **`knob3`'s margin is thin** (0.00598) — the shadow recolour moves few pixels.
- **`knob4`'s mid probe is a no-op by construction** (stock-faithful), so liveness rests on max.