# Port report — `s-grid-polygons-patchwork-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Polygons - Patchwork Color/main.py` (66 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 15; implemented by `local-agent`, 2 iterations (sibling copy) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The `grid-polygons` family's patchwork variant: the same 70-cell grid of closed
6-vertex polygon outlines whose vertices come from a shared random `pList`, scaled by
`knob3` and morphed per-vertex by one audio sample — with the colour chosen **per
cell** from three phase offsets rather than per column.

## The colour rule (confirmed against the source, not assumed)

```python
if i%2 == 1:      color = color_picker(knob4)          # base — a no-op, same value
if j%2 == 1:      color = color_picker((0.4+knob4)%1)
if (j+i)%3 == 1:  color = color_picker((0.8+knob4)%1)
```

Sequential overwrite, last match wins. The port computes one class per cell:
`(j+i)%3==1` → +0.8, else `j%2==1` → +0.4, else base.

## Mapping

Identical to `s-grid-polygons-column-color` (see that report): the same params, the
same `pList` and its trigger-only regeneration, the same `floor(i*j + 5.12)` index
quirk, the same audio morph, the same closed-polygon strips — with the per-cell colour
rule above.

## Mesh grouping (the choice this mode forced)

The colour varies per **cell**, so the column sibling's ten per-column handles do not
apply. The port groups by **colour class**: three preallocated handles (base, +0.4,
+0.8), sized at each class's exact static vertex count (23/24/23 cells × 7 points =
161/168/161 vertices). Cells are written in `(i, j)` order into per-class slot
counters reset each frame, so each class's vertices form a contiguous prefix. Per
frame: 70 `e.color` calls + 3 `e.update_mesh` + 3 `e.draw_mesh`, zero allocation.

**Engine lesson recorded:** the first attempt allocated each mesh at a fixed 490-vertex
capacity and uploaded it whole — the engine threw *"attempt to index a nil value"*
because `update_mesh` validates the **entire** vertices table and a preallocated table
with a trailing `nil` is invalid. The fix is to size each mesh at its exact populated
count, so the table is never partially filled. (A fourth count argument to
`update_mesh` is ignored.)

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-polygons-patchwork-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.0599, max 0.0611 |
| knob 2 `offy` | mid 0.0604, max 0.0579 |
| knob 3 `size` | mid 0.1034, max 0.1135 |
| knob 4 `fg` | mid 0.0506, max 0.0000 |
| knob 5 `bg` | mid 0.9494, max 0.9494 |
| audio | quiet 0.0853, loud 0.1246, freq 0.0944 (threshold 0.001) |
| trigger | **True** — the mode regenerates its polygons on a trigger frame |
| luma bounds | mean 27.85–64.3, **min stddev 0.66** |
| `p50_ms` (software GL) | 16.6 (resources 3) |

## Residual risk

- **`min stddev 0.66` is the second-thinnest luma margin in the pack** (flatness floor
  0.51, after `s-circle-row-lfo`'s 0.9). The patchwork splits the 70 polygons across
  three colour classes, so a quiet-audio grab can put most lit pixels in one low-luma
  class. A gate with a stricter flatness floor would need a class-phase adjustment.
- **Polygons are 1 px strips** where stock's outline is 3 px — the same documented
  deviation as the column sibling.
- **`knob4`'s max probe is 0.0000** (mid 0.0506): at `fg = 1.0` all three classes shift
  by whole cycles and land on the baseline's colours.
- Device tier owed; three draw calls, so the cost should sit at the floor.

## Device tier — 2026-09-18

| Metric | Value |
| --- | --- |
| device p50 | **37.89 ms** |
| bookended floor | 24.18 / 24.19 ms |
| marginal | **+13.7 ms** |
| tier C (≤ 33.3 ms) | **FAIL — outside** |

**The cost is the 70 per-frame `e.color` calls, not the geometry.** The port already
groups its geometry by colour class into three meshes, but the draw loop still issues one
`e.color` per cell — so it pays 70 colour state changes where **three** would do (one per
class, immediately before that class's mesh draw). The family's measurements isolate the
cause cleanly:

| Mode | `e.color` calls/frame | device p50 | marginal |
| --- | --- | --- | --- |
| `s-grid-polygons-uniform-color` | 1 | 24.21 | +0.0 |
| `s-grid-polygons-column-color` | 10 | 24.18 | +0.0 |
| **this mode** | **70** | **37.89** | **+13.7** |

Fix queued: draw each colour-class mesh in one call with a single `e.color` before it,
keeping the class grouping the port already computes. Recorded in ladder §3.5.
