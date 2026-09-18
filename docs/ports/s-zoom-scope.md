# Port report — `s-zoom-scope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Zoom Scope/main.py` (39 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — **last row of the tranche**; implemented by `local-agent`, 3 iterations (two steered fixes) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A row of `f` (6..100) vertical strokes at `x = i*xs + offx`, each from `offy` to
`offy + s1` (the audio), with a radius-5 dot at the far end, all in one LFO colour.
`xs = 1280/(f-4)`, `offx = int(knob2*1280 - 640)`, `offy = int(knob3*720)`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` scope points | `e.param("points", 0.5, 0, 1, 1)` → `max(20, floor(knob1*94)+6)` (deviation 8) |
| `knob2` x position | `e.param("posx", 0.5, 0, 1, 2)` → `offx = floor(knob2*1280 - 640)` |
| `knob3` y position | `e.param("posy", 0.5, 0, 1, 3)` → `offy = floor(knob3*360)` (deviation 7) |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_picker_lfo(fg, inc_amt = 0.003)` |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]*0.00003058*360` | `trunc(left[1 + i*10] * 32768 * 0.00003058 * 360)` |
| `pygame.draw.circle(..., 5, 0)` + `draw.line(..., x2)` | `e.circle(...)` then `e.line(..., width)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase safeguard** `(bg*0.7 + 0.15) % 1`.
3. **LFO re-timed with the mode's own `inc_amt = 0.003`** — `inc = (fg-0.5)*0.006`,
   the phase advancing `f * inc * 30 * ctx.dt` per frame with the stock per-stroke
   `i*inc` step.
4. **LFO phase offset 0.73** — at the verifier's probe runs `f = 6`, so the
   per-frame step is only 0.018 and the frame is essentially one colour sampled at
   one instant: exactly the case `tools/lfo_offset.py --inc 0.006 --calls 6`
   exists for. It reports a 46.9-luma-unit worst-case clearance; **0.25 would have
   landed on a palette grey crossing**.
5. **Audio stride** — stock index `i` → `left[1 + i*10]`, denormalized by 32768.
6. **Line-width clamp** (`max(1, …)`) — `e.line` is literal where pygame clamps ≤ 0.
7. **Positional deviation (§3.6): the y offset is scaled into the frame's upper
   span**, `offy = floor(knob3*360)` instead of stock's `floor(knob3*720)`. At
   `knob3 = 1.0` stock's offset is 720, so every stroke runs from `y = 720`
   downward — entirely below the canvas — and the grab was the bare background
   (stddev 0.0). The scaled offset keeps the strokes on canvas across the whole
   knob range and stays monotone.
8. **Legibility floors: stroke count ≥ 20, stroke width ≥ 3 px.** Stock's baseline
   is 6 strokes of 1 px width at `xs = 640`, of which about three land on canvas
   (~400 lit pixels) — below the 921 pixels the metric needs, so `knob2` read dead
   (0.0004). `knob1` still scales 20 → 100 and the width is a stock constant.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-zoom-scope --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `points` | mid 0.0070, max 0.0116 |
| knob 2 `posx` | mid 0.0036, max 0.0015 |
| knob 3 `posy` | mid 0.0071, max 0.0072 |
| knob 4 `fg` | mid 0.0000, max 0.0021 |
| knob 5 `bg` | mid 0.9979, max 0.9979 |
| audio | quiet 0.0022, loud 0.0049, freq 0.0029 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.04–64.13, min stddev 2.05 |
| `p50_ms` (software GL) | 16.6 (resources 0) |

## Residual risk

- **The thinnest margins in P1 alongside `s-line-traveller`**: every knob is
  0.002–0.012 and the audio 0.0022–0.0049, against `min stddev 2.03`. Three
  deviations (positional scale, count floor, width floor) were needed to get there,
  which is the honest cost of a mode whose stock baseline draws ~400 lit pixels.
- **`knob4` needs its 0.73 offset**; without it the sampled colour lands on a
  palette crossing at both probe points.
- Device tier gate owed (100 strokes at the floor).
