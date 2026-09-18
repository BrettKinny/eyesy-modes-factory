# Port report — `s-aquarium`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Aquarium/main.py` (82 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 8; implemented by `local-agent`, 4 runs (two steered floor revisions) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

Up to 20 "fish", each a vertical line whose y-extent carries one audio sample, whose
x slides by a per-fish speed, and whose colour steps a bouncing accumulator. Stock
re-randomises its three per-fish lists (speed, y, width) on a `knob1` change, on a
`knob2` change and on every trigger frame.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` number of fish | `e.param("fish", 0.5, 0, 1, 1)` → `max(8, floor(knob1*19)+1)` (deviation 7) |
| `knob2` fish length | `e.param("length", 0.5, 0, 1, 2)` → `max(8, floor(knob2*19)+1)` columns |
| `knob3` line width | `e.param("width", 0.5, 0, 1, 3)` → `max(4, floor(knob3*99.84+1))` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → the bouncing accumulator's `picker` |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| three `random.randrange` lists | three 20-entry tables + a count list, all preallocated and mutated in place |
| `audio_in[j+i]/499.68` | `left[1 + max(0, j+i-2)*10] * 32768 / 499.68` (deviation 5) |
| `pygame.draw.line(..., linewidth)` | `e.line(x, y1, x, y0, linewidth)` |

## Deviations (in the mode header)

1. **`e.random()` for `random.randrange`** on all three lists, with stock's exact
   ranges and all three re-randomise occasions in stock's per-list order.
2. **Deterministic middle-branch palette**; no LFO phase offset needed (the
   accumulator advances up to 20 phases per frame, so the colour varies within the
   frame).
3. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
4. **Both accumulators re-timed** by `30 * ctx.dt` with the per-pair order kept.
5. **Audio index floored at 0** — stock's ring never holds negative indices, and the
   port's `j+i-2` expression reaches −1 at the baseline.
6. **`y0` clamped at 0** so a negative stored y cannot put the stroke entirely above
   the frame.
7. **Legibility floors: fish ≥ 8, columns ≥ 8, stroke width ≥ 4 px.** Stock's
   baseline is one fish × one column = a single ~23 px hairline (~23 lit pixels),
   which the luma metric reads as a flat frame and no knob can move; at the quiet
   audio gain the strokes are ~1 px long, so the floors are sized against the
   *quiet* variant (~256 lit pixels), not the baseline. Same class as
   `s-five-lines-spin`, `s-zoom-scope` and `s-0-arrival-scope`.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-aquarium --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `fish` | mid 0.0108, max 0.0167 |
| knob 2 `length` | mid 0.0114, max 0.0178 |
| knob 3 `width` | mid 0.0176, max 0.0310 |
| knob 4 `fg` | mid 0.0000, max 0.0040 |
| knob 5 `bg` | mid 0.9956, max 0.9956 |
| audio | quiet 0.0041, loud 0.0109, freq 0.0057 (threshold 0.001) |
| trigger | **True** — the mode re-randomises its fish on a trigger frame |
| luma bounds | mean 28.02–64.27, min stddev 1.47 |
| `p50_ms` (software GL) | 16.6 (resources 0) |

## Residual risk

- **The floors cost range**: the bottom ~40 % of `knob1`/`knob2`/`knob3` is constant
  (8 fish, 8 columns, 4 px), so those knobs read flat below ~0.4. Deliberate and
  documented; it is the price of a mode whose stock baseline is invisible.
- **Determinism is against the engine PRNG's sequence**, not Python's `random`
  module, so the fish layout differs from stock run-to-run by design (the ranges
  match exactly).
- **`knob4`'s mid probe is 0.0000** (max 0.0040) — the usual static-branch pattern.
- The quiet-variant margin is the thinnest in the mode (`min stddev 1.47` against
  0.51); a gate with a higher flatness floor would need larger floors still.