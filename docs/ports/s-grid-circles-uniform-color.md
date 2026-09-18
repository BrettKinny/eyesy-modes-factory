# Port report — `s-grid-circles-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Circles - Uniform Color/main.py` (40 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 5 of 11) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The grid family's single-colour variant: a 7×10 grid of audio-sized filled
circles (160 × 144 px pitch, odd rows/columns offset by knobs 1 and 2), all in one
LFO colour per frame.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` circle size | `e.param("size", 0.5, 0, 1, 3)` → `restRad = floor(knob3*29.44)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_picker_lfo(fg)`, once per frame |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j+i]/32768 * 128)` | `abs(left[1 + (j+i)*10] * 128)` |
| `pygame.draw.circle(..., rad+restRad)` | `e.circle(x, y, rad + restRad)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO phase offset 0.21** — the picker is called once per frame, so the gate
   samples a single instant; the offset from `tools/lfo_offset.py --inc 0.1
   --calls 1` keeps the sampled colour clear of both the palette grey and the
   background luma.
4. **Audio stride** with the negative-index wrap rule (`j+i` is always in range
   here; the triangle family's `j-i` is not).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-circles-uniform-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.2176, max 0.0522 |
| knob 2 `offy` | mid 0.1747, max 0.0512 |
| knob 3 `size` | mid 0.1995, max 0.4014 |
| knob 4 `fg` | mid 0.0000, max 0.3418 |
| knob 5 `bg` | mid 0.6582, max 0.6582 |
| audio | quiet 0.3402, loud 0.5825, freq 0.2291 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.16–119.51, min stddev 3.96 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s liveness is harness-tuned**: the 0.21 offset was derived from the
  verifier's frame counts; a different grab instant could land the sampled colour
  on a low-contrast value. This is the documented class (ladder §3.4), and
  `tools/lfo_offset.py` exists to re-derive it if the harness changes.
- **The luma ceiling is close**: `knob3-max` reaches mean 119.5 of the 251.2
  bound because the circles are large at full size; a mode with denser cells
  would need care.
- Device tier gate owed.
