# Port report — `s-grid-polygons-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Polygons - Uniform Color/main.py` (60 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 16; implemented by `local-agent`, passed first iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The `grid-polygons` family's single-colour variant: a 7×10 grid of closed 6-vertex
polygon outlines whose vertices come from a shared random `pList`, scaled by `knob3`
and morphed per-vertex by one audio sample — every cell drawn in one LFO colour.

## Mapping

Identical to its two siblings (see `s-grid-polygons-column-color.md`): the same params
block with literal knob numbers, the same `pList` and its trigger-only regeneration, the
same `floor(i*j + 5.12)` index quirk, the same audio morph, the same closed-polygon
strips, the same documented 1 px-vs-3 px outline deviation.

**Mesh grouping:** because every cell shares one colour, all 70 cells live in **one**
preallocated mesh sized at its exact populated count (70 × 7 = **490 vertices**) —
`update_mesh` validates the whole vertices table, so the table is always fully
populated. One `e.color` per frame, sampled from `color_picker_lfo(knob4)` with the
pack's documented **0.21 phase offset** (confirmed with `tools/lfo_offset.py --inc 0.1
--calls 1`). Zero per-frame allocation, one draw call.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-polygons-uniform-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.0348, max 0.0349 |
| knob 2 `offy` | mid 0.0409, max 0.0394 |
| knob 3 `size` | mid 0.0647, max 0.0757 |
| knob 4 `fg` | mid 0.0000, max 0.0287 |
| knob 5 `bg` | mid 0.9713, max 0.9713 |
| audio | quiet 0.0455, loud 0.0877, freq 0.0542 (threshold 0.001) |
| trigger | **True** — the mode regenerates its polygons on a trigger frame |
| luma bounds | mean 29.18–65.81, **min stddev 6.85** |
| `p50_ms` (software GL) | 16.7 (resources 1) |

## Residual risk

- **`knob4`'s mid probe reads 0.0000** while its max reads 0.0287 — the mid state lands
  on a colour that renders identically to the baseline at this frame, so the knob's
  mid range is not distinguishable at 60-frame granularity. The knob does move the
  frame (max 0.0287), so this is a probe artefact rather than a dead knob.
- **Polygons are 1 px strips** where stock's outline is 3 px — the family's documented
  deviation.
- **`min stddev 6.85` is the family's healthiest margin** (its patchwork sibling sits at
  0.66), because one colour keeps all 70 lit polygons in the same luma band.
- Device tier owed; one draw call, so the cost should sit at the floor.

## Device tier — 2026-09-18

| Metric | Value |
| --- | --- |
| device p50 | **24.21 ms** |
| bookended floor | 24.18 / 24.19 ms |
| marginal | **+0.0 ms** |
| tier C (≤ 33.3 ms) | **pass** |

At the floor: one `e.color` call and one mesh draw per frame for all 70 cells.
