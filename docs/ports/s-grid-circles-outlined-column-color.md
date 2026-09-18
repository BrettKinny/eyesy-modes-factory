# Port report — `s-grid-circles-outlined-column-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Circles - Outlined Column Color/main.py` (41 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 3 of 11) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The same quadrant checkerboard as `s-grid-circles-outlined` — a 7×10 grid of
cells whose top-left and bottom-right quadrants are filled and whose top-right and
bottom-left quadrants are 8 px arc bands — but coloured **per column** by
`picker((j*0.1 + fg) % 1)` instead of one LFO colour per frame.

## Mapping

Identical to `s-grid-circles-outlined` (grid pitch 160 × 144, odd row/column
offsets from knobs 1 and 2, `rad = abs(A(j+i)/32768 * 128)`,
`restRad = floor(knob3*29.44)+1`, 6-segment fans and bands, `SEG = 6`, the
degenerate-radius guard) with one change: the mesh is grouped **per column** —
ten preallocated handles of 308 vertices / 504 indices each (7 cells × 44
vertices) — so each column can carry its own colour. `resources 10` in the
verifier's report is those ten meshes.

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Audio stride** with the negative-index wrap (`j+i` here, `j-i` in the
   triangle family).
4. **Quadrants via meshes** — as the sibling, with the per-column grouping.
5. **No LFO phase offset is needed**: the colour is `color_picker` (not
   `color_picker_lfo`) and the per-column phase ramp already varies the colour
   within the frame.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-circles-outlined-column-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.1999, max 0.1497 |
| knob 2 `offy` | mid 0.1390, max 0.0680 |
| knob 3 `size` | mid 0.2146, max 0.3189 |
| knob 4 `fg` | mid 0.1940, max 0.0000 |
| knob 5 `bg` | mid 0.7696, max 0.7696 |
| audio | quiet 0.2020, loud 0.8140, freq 0.1856 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 44.42–102.2, min stddev 35.04 |
| `p50_ms` (software GL) | 16.7 (resources 10) |

## Residual risk

- **`knob4`'s max probe is 0.0000** (mid 0.1940): at `fg = 1.0` the per-column
  ramp returns the same colour *set* rotated by five columns, and with the grid
  symmetric in x the rotation lands identically — the same effect documented for
  `s-grid-circles-column-color`.
- **Ten meshes instead of one** doubles the per-frame `update_mesh`/`draw_mesh`
  traffic versus the sibling (still 10 draw calls). Device tier is owed; if the
  grid family ever needs fewer handles, a single mesh with per-vertex colour is
  the engine-side answer.
- The `j+i` audio index is always in `[0, 15]` for this mode, so the wrap rule is
  not exercised here (it is in the triangle family, where `j-i` goes negative).
