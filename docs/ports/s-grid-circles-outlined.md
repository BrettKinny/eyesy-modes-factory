# Port report — `s-grid-circles-outlined`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Circles - Outlined/main.py` (41 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 2 of 11) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A 7×10 grid of circles (160 × 144 px pitch, odd rows/columns offset by knobs 1
and 2) where each cell is split along its diagonals: the top-left and
bottom-right quadrants are **filled** and the top-right and bottom-left quadrants
are drawn as an **8 px-thick arc band**, all in one LFO colour per frame.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` circle size | `e.param("size", 0.5, 0, 1, 3)` → `restRad = floor(knob3*29.44)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_picker_lfo(fg)`, once per frame |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j+i]/32768 * 128)` | `abs(left[1 + (j+i)*10] * 128)` |
| two `pygame.draw.circle` quadrant calls | one preallocated mesh: 6-segment fans for TL/BR, 6-segment 8 px bands for TR/BL |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Audio stride** — stock index `k` → `left[1 + k*10]`, denormalized by 32768,
   with the negative-index wrap (Python's `audio_in[-6]` is `audio_in[94]`).
4. **LFO phase offset 0.21** — the picker is called once per frame here, so the
   gate samples a single instant; the offset (from `tools/lfo_offset.py`) keeps
   the sampled colour clear of both the palette grey and the background luma.
5. **Quadrants via meshes.** The API has no quadrant primitive and no filled
   arcs, so each cell is built from geometry: TL/BR filled 6-segment triangle
   fans and TR/BL bands between `R-8` and `R`. One preallocated mesh holds all 70
   cells (3080 vertices, 5040 indices — inside the 8192/49152 limits), mutated in
   place each frame, so the whole mode is **one draw call** (`resources 1`).
   `SEG = 6` puts the polygonal error below 1 px at this radius.
6. **Degenerate-radius guard** — cells with `R <= 8` are skipped (the band would
   invert); stock's radius-0 circle draws nothing anyway.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-circles-outlined --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.1901, max 0.0706 |
| knob 2 `offy` | mid 0.1390, max 0.0680 |
| knob 3 `size` | mid 0.2146, max 0.3189 |
| knob 4 `fg` | mid 0.0000, max 0.2304 |
| knob 5 `bg` | mid 0.7696, max 0.7696 |
| audio | quiet 0.2020, loud 0.6622, freq 0.1856 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 37.45–113.58, min stddev 17.27 |
| `p50_ms` (software GL) | 16.7 (resources 1) |

## Residual risk

- **The mesh is rebuilt in Lua every frame** (3080 vertex writes + 5040 index
  reads per frame). That is cheap on llvmpipe (16.7 ms) but it is Lua-side work,
  and the device tier gate is owed — a mode that is GPU-cheap can still be
  CPU-bound on a CM3+.
- **`knob4`'s mid probe is 0.0000** while its max is 0.2304: the static branch at
  `fg = 0.5` returns the palette grey, which is the baseline colour (the same
  pattern as the other LFO-sampled modes).
- The quadrant geometry is the family's most complex shape and the only one in the
  grid set that needs meshes; its sibling
  (`s-grid-circles-outlined-column-color`) groups the same geometry into ten
  per-column meshes.
