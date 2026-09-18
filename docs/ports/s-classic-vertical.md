# Port report — `s-classic-vertical`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Classic Vertical/main.py` (36 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The horizontal twin of `s-classic-horizontal`: 100 horizontal lines at
`y = i*7.2`, each from `x = 640` to `x = 640 + sample * 1280 * (knob3 + 0.5)`,
with a filled circle of radius `knob2*50.4` on the line's far end, all in one LFO
colour per segment.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` line width | `e.param("width", 0.5, 0, 1, 1)` → `max(1, floor(knob1*7.2))` |
| `knob2` circle size | `e.param("ball", 0.5, 0, 1, 2)` → `floor(knob2*50.4)` |
| `knob3` width control | `e.param("span", 0.5, 0, 1, 3)` → reach factor `(knob3 + 0.5)` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO picker per segment (100 calls/frame) |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]/32768 * 1280 * (knob3+.5)` | `left[1 + i*10] * 1280 * (knob3 + 0.5)` |
| `pygame.draw.circle(..., 0)` | `e.circle(640 + x1, y, ball)`, only when `ball >= 1` |
| `pygame.draw.line(..., linewidth)` | `e.line(640, y, 640 + x1, y, linewidth)` |

## Deviations (in the mode header)

Identical set to `s-classic-horizontal`: deterministic middle-branch palette,
background phase remap `(bg*0.7 + 0.15) % 1`, LFO re-timed `3000 * inc * ctx.dt`
per frame with the stock per-segment fold, 100-sample audio ring mapped by
10-sample strides onto the already-normalized `ctx.audio.left`, and a 1 px floor
on the line width (pygame clamps width ≤ 0 to 1 px; `e.line` is literal).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-classic-vertical --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `width` | mid 0.0440, max 0.1320 |
| knob 2 `ball` | mid 0.1593, max 0.4424 |
| knob 3 `span` | mid 0.0219, max 0.0318 |
| knob 4 `fg` | mid 0.0000, max 0.0178 |
| knob 5 `bg` | mid 0.9781, max 0.9781 |
| audio | quiet 0.0208, loud 0.0341, freq 0.0275 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.1–73.96, min stddev 3.19 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- Same shape as its twin: `knob4`'s liveness rests on one probe point (the static
  branch at `fg = 0.5` returns the baseline grey), and the baseline frame is thin
  (100 one-pixel lines, min stddev 3.19 against a 0.51 threshold).
- Device tier gate owed.
