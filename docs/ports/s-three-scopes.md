# Port report — `s-three-scopes`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Three Scopes/main.py` (55 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

Three scopes in one frame: a 30-stroke ramp below the upper third, a 30-stroke ramp
above the lower third, and a 34-stroke centre-line scope to the right. All strokes
share ONE LFO colour computed once per frame.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` left-scope angles | `e.param("steppy", 0.5, 0, 1, 1)` → `floor(knob1*16)` per-stroke step |
| `knob2` left-scope y position | `e.param("leftpoint", 0.5, 0, 1, 2)` → `floor(knob2*720)` |
| `knob3` line thickness | `e.param("width", 0.5, 0, 1, 3)` → `max(1, floor(knob3*41.98 + 1))` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_picker_lfo(fg)`, **once per frame** |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]/128` and `/80` | `left[1 + i*10] * 32768 / 128` and `/80` |
| `pygame.draw.line(...)` ×94 | `e.line(ax, ay1, ax, ay0, linewidth)` |

Stock's three loops are reproduced exactly, including the right-hand scope's `ax`
running from 640 to 1344 (its last few strokes fall off the right edge — stock's own
behaviour, kept).

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO phase offset 0.21** — the picker is called once per frame, so the gate
   samples a single instant; the offset (`tools/lfo_offset.py --inc 0.1 --calls 1`,
   38.85 luma-unit clearance) keeps the sampled colour clear of both the palette
   grey and the background luma. Phase advances `30 * inc * ctx.dt` per frame.
4. **Audio stride** — stock index `i` → `left[1 + i*10]`, denormalized by 32768.
5. **1 px width floor** — pygame treats a width ≤ 0 as 1 px; `e.line` is literal.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-three-scopes --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `steppy` | mid 0.0077, max 0.0064 |
| knob 2 `leftpoint` | mid 0.0075, max 0.0049 |
| knob 3 `width` | mid 0.1915, max 0.2249 |
| knob 4 `fg` | mid 0.0000, max 0.0095 |
| knob 5 `bg` | mid 0.9905, max 0.9905 |
| audio | quiet 0.0090, loud 0.0136, freq 0.0120 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.05–64.6, min stddev 2.17 |
| `p50_ms` (software GL) | 16.1 (resources 0) |

## Residual risk

- **`knob1`/`knob2` pass at ~0.005–0.008** — the two ramps move by at most 16 px per
  stroke, so the geometry change is small against 94 hairlines.
- **`knob4`'s mid probe is 0.0000** (max 0.0095) — the pack's usual static-branch
  pattern.
- **94 immediate `e.line` calls** per frame; the sibling batch measured comparable
  rows at the device floor, so tier is not in question, but it is owed.
