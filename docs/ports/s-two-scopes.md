# Port report — `s-two-scopes`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Two Scopes/main.py` (41 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

Two stacked scopes of horizontal strokes 15 px apart, starting at `knob1*1280`
(top) and `knob2*1280` (bottom) and reaching one audio sample further, all in a
per-stroke LFO colour with a width from `knob3`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` first scope y | `e.param("pos1", 0.5, 0, 1, 1)` → `floor(knob1*1280)` |
| `knob2` second scope y | `e.param("pos2", 0.5, 0, 1, 2)` → `floor(knob2*1280)` |
| `knob3` line width | `e.param("width", 0.5, 0, 1, 3)` → `max(1, floor(knob3*32.4 + 1))` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → per-stroke LFO picker (100 calls/frame) |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]/35` | `left[1 + i*10] * 32768 / 35` |
| `pygame.draw.line(...)` ×99 | `e.line(x0, y, x1, y, width)` |

Stock's loop bounds are kept exactly: the top scope is `i = 0..49` at `y = i*15`
and the bottom is `i = 51..99` (**49** strokes, `i = 50` absent) at
`y = (i-50)*15`.

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO re-timed** — 100 calls/frame at 30 fps = `3000·inc` per second; the phase
   advances `3000 * inc * ctx.dt` per frame with the stock per-stroke `i*inc` step.
   **No phase offset is needed**: the within-frame spread already varies the sampled
   colour (ladder §3.4's exception).
4. **Audio stride** — stock index `i` → `left[1 + i*10]`, denormalized by 32768.
5. **1 px width floor** — pygame treats a width ≤ 0 as 1 px; `e.line` is literal.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-two-scopes --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `pos1` | mid 0.0207, max 0.0135 |
| knob 2 `pos2` | mid 0.0210, max 0.0147 |
| knob 3 `width` | mid 0.1925, max 0.2172 |
| knob 4 `fg` | mid 0.0000, max 0.0108 |
| knob 5 `bg` | mid 0.9867, max 0.9867 |
| audio | quiet 0.0127, loud 0.0285, freq 0.0109 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.06–64.84, min stddev 2.52 |
| `p50_ms` (software GL) | 15.8 (resources 0) |

## Residual risk

- **`knob4`'s margin is thin** (0.0108) and rests on the per-stroke spread rather
  than a phase offset — the ladder's exception case. If the gate's probe frames ever
  change, this knob is the first place to look.
- **`knob4`'s mid probe is 0.0000** — the usual static-branch pattern.
- 99 immediate `e.line` calls per frame; device tier owed (sibling scope rows
  measured at the floor).
