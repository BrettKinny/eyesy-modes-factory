# Port report — `s-circle-row-lfo`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Circle Row - LFO/main.py` (~62 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 9; implemented by `local-agent`, **1 iteration, 0 model iterations** |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A row of circles (1..26) on a bouncing y position, each radius set by one audio
sample plus `knob2`'s offset, all in one LFO colour per frame.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` number of circles | `e.param("count", 0.5, 0, 1, 1)` → `floor(knob1*25.6)+1` |
| `knob2` circle size | `e.param("size", 0.5, 0, 1, 2)` → `offset = floor(knob2*7*29.44)` |
| `knob3` bounce speed | `e.param("bounce", 0.5, 0, 1, 3)` → `floor(knob3*248.4)` as the LFO step |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO once per frame, phase offset 0.21 |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `class LFO` bounce | file-local `current`/`direction` with stock's clamp-on-cross logic |
| `audio_in[i+3]/100` | `abs(left[1 + (i+3)*10] * 32768 / 100)` |
| `pygame.gfxdraw.filled_circle` | `e.circle(ax, trunc(y), r)` |

## Deviations (in the mode header)

1. **The LFO oscillator is re-timed** — stock adds `step` once per frame at 30 fps;
   the port advances by `step * 30 * ctx.dt`.
2. **Deterministic middle-branch palette**; **LFO phase offset 0.21**
   (`tools/lfo_offset.py --inc 0.1 --calls 1`, 38.85 luma-unit clearance) with the
   phase advanced `30 * inc * ctx.dt` per frame.
3. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
4. **Audio stride** — stock index `i+3` → `left[1 + (i+3)*10]`, denormalized by
   32768 (the `i+3` reaches 28 for 26 circles, well inside the 1024-sample window).
5. No legibility floor was needed: at the baseline `knob1 = 0` gives one circle
   whose radius is `4 + |A(3)|/100 ≈ 118 px`, so the frame is never thin.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-circle-row-lfo --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `count` | mid 0.2347, max 0.2956 |
| knob 2 `size` | mid 0.0574, max 0.1528 |
| knob 3 `bounce` | mid 0.0073, max 0.0073 |
| knob 4 `fg` | mid 0.0000, max 0.0037 |
| knob 5 `bg` | mid 0.9963, max 0.9963 |
| audio | quiet 0.0036, loud 0.0354, freq 0.0567 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.01–64.23, **min stddev 0.9** |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`min stddev 0.9` is the thinnest luma margin in the pack** (flatness floor 0.51
  at the CLI default `--flatness 0.002`): the quiet-audio grab has one circle. It
  passes with ~1.8× headroom, but a gate with a stricter flatness floor would need a
  floor here — and per the ladder's newest rule it would have to be sized against
  *this* quiet variant, not the baseline.
- **`knob4`'s max is 0.0037** — the colour change is sub-luma-visible in a 28-luma
  frame, which is exactly why the 0.21 phase offset is load-bearing.
- **`knob3`'s mid and max are identical** (0.0073): the bounce clamps, so both probes
  land in the same part of the cycle.
- Third mode this stretch with **0 model iterations** (a direct port from the source
  plus a verified peer).