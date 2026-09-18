# Port report — `s-football-scope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Football Scope/main.py` (42 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

100 circles down one edge at `(x1, i*12.8 - 100)`, each joined by a width-2 line to
`(i*12.8, x0)` — the coordinates are transposed, which is what gives the mode its
look. `x1 = knob1*1280 + audio_in[i]/50`, `x0 = knob2*720`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x position | `e.param("posx", 0.5, 0, 1, 1)` → `trunc(posx*1280) + A/50` |
| `knob2` y position | `e.param("posy", 0.5, 0, 1, 2)` → `trunc(posy*720)` |
| `knob3` diameter | `e.param("size", 0.5, 0, 1, 3)` → `trunc(size*12)`, drawn only when ≥ 1 |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → accumulating ramp below 0.5, static above |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]/50` | `left[1 + i*10] * 32768 / 50` |
| `pygame.draw.circle(..., 0)` | `e.circle(ax, y - 100, radius)` — skipped when `radius < 1` |
| `pygame.draw.line(..., 2)` | `e.line(y, x0, ax, y - 100, 2)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Colour accumulator re-timed** — stock advanced `color_rate` once per circle
   (100 calls/frame at 30 fps = `3000*(fg-0.5)*0.001`/s); the port advances it once
   per frame by `100*(fg-0.5)*0.001*30*ctx.dt`, keeping the stock `i*0.01` term.
4. **Audio stride** — stock index `i` → `left[1 + i*10]`, denormalized by 32768.
5. **The branch stock leaves undefined.** At `fg = 0.5` exactly, both of stock's
   strict inequalities are false, `color` is never bound and the mode raises
   `UnboundLocalError`. The verifier probes `0.5`, so the port defines it: the
   accumulating branch is taken for `fg <= 0.5`. This is the only sane reading of
   a mode that crashes at that knob position.
6. **Radius gate** — pygame's radius-0 circle draws nothing, so the circle is
   skipped when `radius < 1` (stock-exact); the width-2 line always draws, so the
   foreground colour always lands on the frame.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-football-scope --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `posx` | mid 0.2191, max 0.2299 |
| knob 2 `posy` | mid 0.2105, max 0.1757 |
| knob 3 `size` | mid 0.0024, max 0.0105 |
| knob 4 `fg` | mid 0.1264, max 0.1243 |
| knob 5 `bg` | mid 0.8721, max 0.8721 |
| audio | quiet 0.2434, loud 0.2277, freq 0.2209 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 34.06–72.74, min stddev 29.43 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s mid probe is live here** (0.1264) unlike the other P1 ports: the
  accumulating branch is taken at `fg = 0.5`, so the ramp differs from the
  baseline rather than returning the same grey. That is a consequence of
  deviation 5, not of the stock behaviour (stock crashes there).
- **`knob3`'s margin is thin** (0.0024) because the circle is the only thing it
  scales and the circle is small (radius ≤ 12) against a busy line field.
- Device tier gate owed; 200 draw calls per frame at the baseline.
