# Port report — `s-grid-triangles-unfilled-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Triangles - Unfilled Uniform Color/main.py` (39 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 11 of 11 — **family complete**) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The intersection of the outline and single-colour variants: 7×10 triangles drawn
as 8 px outlines, all in one LFO colour per frame.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` triangle size | `e.param("size", 0.5, 0, 1, 3)` → `width = floor(knob3*80.64)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_picker_lfo(fg)`, once per frame |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j-i]*0.00003058*320)` | `abs(left[1 + wrap(j-i)*10] * 320)` |
| `pygame.draw.polygon(points, lineWidth)` | three `e.line` calls of width 8 |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO phase offset 0.21** (`tools/lfo_offset.py --inc 0.1 --calls 1` reports a
   38.85-luma-unit worst-case clearance from both the palette grey and the
   background).
4. **Negative audio index wrapped** (`j-i` reaches −6).
5. **Outlines as three lines** of width 8 — no mesh handles needed.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-triangles-unfilled-uniform-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.1419, max 0.1542 |
| knob 2 `offy` | mid 0.1673, max 0.1575 |
| knob 3 `size` | mid 0.3774, max 0.4275 |
| knob 4 `fg` | mid 0.0000, max 0.1928 |
| knob 5 `bg` | mid 0.8072, max 0.8072 |
| audio | quiet 0.1962, loud 0.4504, freq 0.2672 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.94–76.15, min stddev 9.62 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s mid probe is 0.0000** (max 0.1928) — the family's integer-`fg`
  signature.
- **210 immediate `e.line` calls per frame** — the outline rows' cost profile;
  device tier owed.
- This row closes the grid family: **11 of 11 rows verified**, 7 of them on the
  agent's first iteration from the shared family brief.
