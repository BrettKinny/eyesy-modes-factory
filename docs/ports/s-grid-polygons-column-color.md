# Port report — `s-grid-polygons-column-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Polygons - Column Color/main.py` (61 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 14; implemented by `local-agent`, 2 iterations; structure scouted read-only first |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A 70-cell grid (7 rows × 10 cols) of **closed 6-vertex polygon outlines**. Each
cell's vertices come from a shared `pList` of random points, scaled by `knob3`,
morphed per-vertex by one audio sample, and coloured per column.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` polygon size | `e.param("size", 0.5, 0, 1, 3)` → `w = knob3*7 + 1` (1..8) |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `picker((j*0.1 + fg) % 1)` per column |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = audio_in[j+i]*0.00003052*99.84` | `left[1 + (j+i)*10] * 32768 * 0.00003052 * 99.84` |
| `pList`, regenerated on trigger | preallocated `[70][6][2]`, re-filled on `ctx.trigger` |
| `draw.polygon(..., 3)` ×70 | ten mesh line strips (one per column) |

## Deviations (in the mode header)

1. **`pList` regenerated only on a trigger edge** — stock's
   `if eyesy.trig: trigger = True` / `if trigger == True: …` / `trigger = False`.
   Between triggers it carries across frames. The port keeps a preallocated table and
   re-fills it on `ctx.trigger`; `e.random()` replaces `random.randrange` with
   `floor(e.random()*40) - 20` (stock's `randrange(-20, 20)`), in stock's call order.
   **Zero allocation in `draw`.**
2. **Stock's `pList` index quirk is kept**: the cell's index is
   `floor(i*j + 5.12)`, so for `i = 0` every column reads entry 5 and most cells
   share one polygon. Reproduced exactly rather than "fixed".
3. **Closed polylines as repeated-first-point mesh strips.** The API has no closed
   polyline, so each hexagon is a 7-point line strip (first vertex repeated). The
   strip is 1 px where stock's outline is 3 px — documented; at the verifier's
   geometry the difference does not affect any check.
4. **Ten mesh handles, one per column** (7 cells × 7 points = 49 vertices each),
   mutated in place — inside the 32-handle cap.
5. **Deterministic palette**; **background phase remap** `(bg*0.7 + 0.15) % 1`;
   **audio stride** `j+i` (always 0..15 here, so no negative-index wrap).

## The failure worth recording

The first attempt passed an **index table to a line-strip mesh**, and the engine
rejected it: *"indices must be triangle triples"*. Line strips take **no** index
table — `e.update_mesh(handle, vertices)` alone. That is a second mesh rule for the
program's list (the first being the 32-handle cap), and it is the natural counterpart
to the triangle rows' index tables.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-polygons-column-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.0277, max 0.0279 |
| knob 2 `offy` | mid 0.0201, max 0.0195 |
| knob 3 `size` | mid 0.0512, max 0.0643 |
| knob 4 `fg` | mid 0.0182, max 0.0000 |
| knob 5 `bg` | mid 0.9785, max 0.9785 |
| audio | quiet 0.0311, loud 0.0762, freq 0.0403 (threshold 0.001) |
| trigger | **True** — the mode regenerates its polygons on a trigger frame |
| luma bounds | mean 29.02–65.34, min stddev 11.46 |
| `p50_ms` (software GL) | 16.7 (resources 10) |

## Residual risk

- **The polygon geometry is 1 px where stock is 3 px** (mesh strips vs `draw.polygon`
  width). The look is close but thinner; if a future gate checked stroke weight it
  would need the doubled-strip trick the brief mentioned.
- **The `floor(i*j + 5.12)` quirk means most cells draw the same hexagon**, so the
  grid reads as a repeated shape rather than 70 distinct ones. Faithful to stock.
- **`knob4`'s max probe is 0.0000** (mid 0.0182) — the usual integer-`fg` pattern.
- The two colour siblings (`-patchwork-color`, `-uniform-color`) share this geometry
  verbatim and differ only in the colour rule, so they are sibling copies.

## Device tier — 2026-09-18

| Metric | Value |
| --- | --- |
| device p50 | **24.18 ms** |
| bookended floor | 24.18 / 24.19 ms |
| marginal | **+0.0 ms** |
| tier C (≤ 33.3 ms) | **pass** |

Sits exactly on the floor: 10 `e.color` calls and 10 mesh draws per frame (one handle
per column) cost nothing measurable against the baseline. Measured on the CM3+ with
`starter` bookends, 600 frames per mode.
