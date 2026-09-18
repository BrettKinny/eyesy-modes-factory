# Port report — `s-grid-triangles-unfilled-column-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Triangles - Unfilled Column Color/main.py` (40 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 9 of 11) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The grid family's outlined triangles: 7×10 triangles (160 × 144 px pitch, odd
rows/columns offset by knobs 1 and 2) drawn as 8 px outlines rather than filled,
coloured per column.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` triangle size | `e.param("size", 0.5, 0, 1, 3)` → `width = floor(knob3*80.64)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `picker((j*0.1 + fg) % 1)` per column |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j-i]*0.00003058*320)` | `abs(left[1 + wrap(j-i)*10] * 320)` — note **320**, not the filled rows' 128 |
| `pygame.draw.polygon(points, lineWidth)` | three `e.line` calls of width 8 (`int(1280*0.00625)`) |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Negative audio index wrapped** (`j-i` reaches −6).
4. **Outlines as three lines.** `pygame.draw.polygon(..., lineWidth)` draws an
   8 px outline; three `e.line` calls of width 8 between the same points are the
   direct equivalent and need no mesh handles.
5. **No LFO phase offset needed** — `color_picker` with a static per-column ramp.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-triangles-unfilled-column-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.1476, max 0.1666 |
| knob 2 `offy` | mid 0.1753, max 0.1645 |
| knob 3 `size` | mid 0.4050, max 0.4587 |
| knob 4 `fg` | mid 0.1712, max 0.0000 |
| knob 5 `bg` | mid 0.8072, max 0.8072 |
| audio | quiet 0.1965, loud 0.5193, freq 0.2847 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 29.02–76.9, min stddev 11.9 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s max probe is 0.0000** (mid 0.1712) — the integer-`fg` effect shared
  by the whole family.
- **The outline rows draw more primitives than the filled ones**: 70 triangles ×
   3 lines = 210 immediate `e.line` calls per frame, versus one mesh draw for the
   filled uniform row. Device tier is owed and this row is the family's most
   likely candidate for a cost finding.
- `resources 0` — no meshes, unlike the filled rows.
