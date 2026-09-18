# Port report — `s-classic-horizontal`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Classic Horizontal/main.py` (35 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

100 vertical lines across the frame at `x = i*1280/98`, each from the vertical
centre (`y = 360`) to `y = 360 + sample * 720 * (knob3 + 0.5)`, with a filled
circle of radius `knob2*51.2` on the line's far end, all in one LFO colour per
segment.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` line width | `e.param("width", 0.5, 0, 1, 1)` → `max(1, floor(knob1*12.8))` |
| `knob2` circle size | `e.param("ball", 0.5, 0, 1, 2)` → `floor(knob2*51.2)` |
| `knob3` height control | `e.param("height", 0.5, 0, 1, 3)` → length factor `(knob3 + 0.5)` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO picker per segment (100 calls/frame) |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]/32768 * 720 * (knob3+.5)` | `left[1 + i*10] * 720 * (knob3 + 0.5)` — the buffer is already normalized |
| `pygame.draw.circle(..., 0)` | `e.circle(x, y, ball)`, drawn only when `ball >= 1` |
| `pygame.draw.line(..., linewidth)` | `e.line(x, 360, x, y1, linewidth)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** — stock's legacy picker is partly random.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1` (stock is white at `c = 1`).
3. **LFO re-time** — 100 calls/frame at 30 fps = `3000·inc` per second; the phase
   advances `3000 * inc * ctx.dt` per frame, keeping the stock per-segment
   `(phase + i*inc)` fold. The colour varies within the frame, so no phase offset
   is needed (ladder §3.4).
4. **Audio stride** — stock index `i` → `left[1 + i*10]`; no `*32768` because the
   stock formula divides by 32768 and our buffer is already normalized.
5. **1 px line-width floor** — pygame treats a width ≤ 0 as 1 px; `e.line` takes
   the pixel width literally, so a width of 0 would draw nothing.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-classic-horizontal --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `width` | mid 0.0606, max 0.1333 |
| knob 2 `ball` | mid 0.1555, max 0.3562 |
| knob 3 `height` | mid 0.0122, max 0.0176 |
| knob 4 `fg` | mid 0.0000, max 0.0098 |
| knob 5 `bg` | mid 0.9879, max 0.9879 |
| audio | quiet 0.0116, loud 0.0189, freq 0.0153 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.05–64.76, min stddev 2.32 |
| `p50_ms` (software GL) | 16.6 (resources 0) |

## Residual risk

- `knob4`'s liveness rests on the max probe (0.0098) — at `fg = 0.5` the static
  branch returns the palette's grey, which *is* the baseline colour, so the mid
  probe is 0.0000 by stock construction (same pattern as the other P1 ports).
- The baseline frame is thin (100 one-pixel lines): `min_stddev 2.32` against the
  0.51 threshold. It passes, but a mode whose baseline is thinner would need a
  documented floor.
- Device tier gate owed; 200 draw calls per frame at the baseline.
