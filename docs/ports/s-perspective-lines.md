# Port report — `s-perspective-lines`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Perspective Lines/main.py` (38 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | measured in the P1 device batch (receipt: `docs/device-tier/2026-09-18.md`) |

## What it does

50 circles at `(i*26, 360 + audio)` each joined to a single shared origin
`(knob1*1280, knob2*720)` by a line, so the whole set fans out of one moving point.
Circle radius `int(knob3*10)+3`, line width `int(knob3*10)+1`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x position | `e.param("posx", 0.5, 0, 1, 1)` → the fan's origin x |
| `knob2` y position | `e.param("posy", 0.5, 0, 1, 2)` → the fan's origin y |
| `knob3` size | `e.param("size", 0.5, 0, 1, 3)` → radius `floor(knob3*10)+3`, width `floor(knob3*10)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO picker per segment (50 calls/frame) |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]*0.00003058*360` | `trunc(left[1 + i*10] * 360.6)` |
| `pygame.draw.circle` + `draw.line` | `e.circle(x, y1, radius)` then `e.line(ox, oy, x, y1, width)` |
| `last_point` global reassigned per segment | computed once per frame (it depends only on the knobs) |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO re-timed** — 50 calls/frame at 30 fps = `1500·inc` per second; the phase
   advances once per frame by `1500 * inc * ctx.dt` with the stock per-segment
   `i*inc` step. The colour varies within the frame, so no phase offset is needed.
4. **Audio stride** — stock index `i` → `left[1 + i*10]`, denormalized by 32768.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-perspective-lines --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `posx` | mid 0.0597, max 0.0735 |
| knob 2 `posy` | mid 0.0646, max 0.0736 |
| knob 3 `size` | mid 0.1244, max 0.2040 |
| knob 4 `fg` | mid 0.0000, max 0.0313 |
| knob 5 `bg` | mid 0.9618, max 0.9618 |
| audio | quiet 0.0670, loud 0.0643, freq 0.0634 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 30.73–66.41, min stddev 12.08 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s mid probe is 0.0000** (max 0.0313) — the static branch at `fg = 0.5`
  returns the palette grey, the baseline colour (the pack's usual pattern).
- **All three audio variants differ** (0.063–0.067), unlike `s-line-traveller`:
  the reach here is a fan of *positions* rather than a clamped length, so loud and
  quiet both change the geometry.
- Device tier measured in the P1 batch; 100 immediate primitives per frame.
