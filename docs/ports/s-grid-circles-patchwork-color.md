# Port report — `s-grid-circles-patchwork-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Circles - Patchwork Color/main.py` (45 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 4 of 11) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A 7×10 grid of audio-sized filled circles (160 × 144 px pitch, odd rows/columns
offset by knobs 1 and 2) whose colour is picked per cell from three phase offsets
— a patchwork rather than a ramp or a single colour.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` circle size | `e.param("size", 0.5, 0, 1, 3)` → `restRad = floor(knob3*29.44)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → three phase offsets (below) |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j+i]/32768 * 256)` | `abs(left[1 + (j+i)*10] * 256)` |
| `pygame.draw.circle(..., rad+restRad)` | `e.circle(x, y, rad + restRad)` |

**Patchwork colour rule**, in stock's assignment order (the last match wins):

```lua
local phase = fg                       -- every cell
if j % 2 == 1 then phase = (0.4 + fg) % 1 end
if (j + i) % 3 == 1 then phase = (0.8 + fg) % 1 end
```

Stock's `if (i%2) == 1` branch re-assigns `picker(knob4)` — the same value as the
initial assignment, so it is a no-op and the port omits it (documented).

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Audio stride** with the negative-index wrap rule (`j+i` here; the triangle
   family's `j-i` is the one that actually goes negative).
4. **No LFO phase offset needed** — the colour is `color_picker` with three static
   phase offsets, so it does not sample a time-varying ramp.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-circles-patchwork-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.2619, max 0.4041 |
| knob 2 `offy` | mid 0.2062, max 0.3222 |
| knob 3 `size` | mid 0.1595, max 0.3054 |
| knob 4 `fg` | mid 0.5373, max 0.0000 |
| knob 5 `bg` | mid 0.1891, max 0.1891 |
| audio | quiet 0.8063, loud 0.6856, freq 0.5085 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.27–82.67, min stddev 4.39 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s max probe is 0.0000** (mid 0.5373): at `fg = 1.0` every phase offset
  shifts by a whole cycle, so the three colour classes come out identical to the
  baseline. The knob is live via mid; a gate probing only `1.0` would read it
  dead. This is the third grid row with that signature — it is a property of
  `picker((k + fg) % 1)` when `fg` is an integer.
- Device tier gate owed.
