# Port report — `s-grid-slide-square-filled-patchwork-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Slide Square - Filled Patchwork Color/main.py` (84 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 19; fourth mode of the `grid-slide-square` family |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier | owed — **expected to fail**; see below |

## What it does

The family's filled, per-cell-coloured variant: a 7×10 grid of filled squares slid by the
shared `sqmover` oscillator and inflated by one audio sample, with each cell's colour
chosen by three sequential overrides.

## The source diff against `Filled Uniform` (three findings)

1. **The colour rule.** `Uniform` has one `color_picker_lfo(knob4)` before the loop;
   `Patchwork` has no such line and instead carries three sequential overwrites **inside
   the `j` loop**, last match wins:

   ```python
   if i%2 == 1:      x = j*x8 - x8 + xoffset ;  color = picker(knob4)
   if j%2 == 1:      y = i*y5 - y5 + yoffset ;  color = picker(1-knob4)
   if (j+i)%3 == 1:                              color = picker((0.8+knob4)%1)
   ```

2. **The offsets are parity-conditional here.** The branches *re-assign* the base
   position plus the offset, which is equivalent to the sibling's `x = x + xoffset` on
   odd rows — so this variant shifts odd rows/columns only, unlike `Filled Uniform`,
   which shifts **every** cell unconditionally. (The ladder's family note said the
   filled variants were unconditional; corrected for this mode.)
3. **Dead code in stock.** `setup()` computes a `color` global that `draw()` never reads.
   Dropped.

All three colour branches use the **static** legacy picker — no LFO state, so **no phase
offset applies** (deviation 4). The legacy picker is partly random in stock, so the
deterministic middle branch substitutes per pack convention (deviation 1); the three
arguments and their static nature are stock-exact.

## Mapping

Otherwise the verified siblings verbatim: the 7×10 grid, the **14-advances-per-frame**
`sqmover` (two `update()` calls per row, each re-timed `step*30*dt`, both stock clamps),
the audio stride with Python's negative-index wrap, the centred-rect conversion, the bg
phase fold, and deviations 8 and 9 (the 1 px step floor and 1 px range fallback for the
mutually dependent knobs). 70 `e.rect` calls per frame, no mesh (`resources 0`).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-slide-square-filled-patchwork-color --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `step` | mid 0.0046, max 0.0051 |
| knob 2 `pos` | mid 0.2443, max 0.3073 |
| knob 3 `size` | mid 0.3294, max 0.6015 |
| knob 4 `fg` | mid 0.1724, max 0.0000 |
| knob 5 `bg` | mid 0.5015, max 0.5015 |
| audio | quiet 0.4968, loud 0.8264, freq 0.4037 (threshold 0.001) |
| trigger | `None` — the scene does not reference `ctx.trigger` |
| luma bounds | mean 28.1–78.75, min stddev 3.02 |
| `p50_ms` (software GL) | 16.6 (resources 0) |

## Residual risk

- **The device tier gate is expected to fail, for the same reason as its
  `grid-polygons-patchwork-color` cousin**: the mode issues **70 per-cell `e.color`
  calls** per frame, and that measurement isolated colour state changes as the cost
  (+13.7 ms, outside tier C) while the family's one- and ten-call modes sit on the floor
  (24.2 ms). The fix is the same — group by colour class and issue one `e.color` per
  class — and is queued behind the cousin's. Measurement owed once it lands.
- **knob 1's liveness margin is thin** (0.0046–0.0051 against 0.001), the family's shared
  1 px-floor dependency.
- **knob 4's max probe reads 0.0000** while its mid reads 0.1724 — at `knob4 = 1.0` all
  three class phases shift by whole cycles and land on the baseline's colours. The knob is
  live at its mid state, so this is a probe artefact.
- **The frame is darker than its siblings** (luma 28.1–78.75, min stddev 3.02): the
  three-class colour split puts fewer lit pixels in one luma band.