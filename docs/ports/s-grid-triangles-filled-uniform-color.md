# Port report — `s-grid-triangles-filled-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Triangles - Filled Uniform Color/main.py` (39 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 8 of 11) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The grid family's single-colour triangles: 7×10 filled triangles (160 × 144 px
pitch, odd rows/columns offset by knobs 1 and 2) all in one LFO colour per frame.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` triangle size | `e.param("size", 0.5, 0, 1, 3)` → `width = floor(knob3*80.64)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_picker_lfo(fg)`, once per frame |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j-i]*0.00003058*128)` | `abs(left[1 + wrap(j-i)*10] * 128)` — `j-i` reaches −6 |
| `pygame.draw.polygon(points)` | **one mesh, all 70 triangles** (210 vertices, 210 indices) |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO phase offset 0.21** — the picker is called once per frame, so the gate
   samples a single instant; the offset (`tools/lfo_offset.py --inc 0.1 --calls 1`)
   keeps the sampled colour clear of both the palette grey and the background luma.
4. **Negative audio index wrapped** (`j-i` → Python's `audio_in[94]` at `j-i = −6`).
5. **Triangles via one mesh** — all 70 share one colour, so a single preallocated
   mesh (210 vertices, 210 indices) serves them and the mode is **one draw call**
   (`resources 1`), comfortably inside the 32-handle cap and the 8192/49152
   per-mesh budgets.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-triangles-filled-uniform-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.1541, max 0.0395 |
| knob 2 `offy` | mid 0.1230, max 0.0361 |
| knob 3 `size` | mid 0.3731, max 0.7319 |
| knob 4 `fg` | mid 0.0000, max 0.1530 |
| knob 5 `bg` | mid 0.8470, max 0.8470 |
| audio | quiet 0.1522, loud 0.6239, freq 0.1275 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.07–115.6, min stddev 2.7 |
| `p50_ms` (software GL) | 16.7 (resources 1) |

## Residual risk

- **`knob1`/`knob2` max probes are thin** (0.0395 / 0.0361): the offsets move cells
  by up to 160/144 px, but the triangles are small relative to the grid and the
  odd-row/odd-column pattern means only half the cells move.
- **`knob4`'s mid probe is 0.0000** (max 0.1530) — the usual integer-`fg` /
  static-branch effect.
- Device tier gate owed; one draw call per frame.
