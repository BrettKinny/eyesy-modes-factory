# Port report — `s-bits-horizontal`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Bits Horizontal/main.py` (60 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 6; implemented by `local-agent`, **1 iteration, 3m30s** (sibling copy) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The horizontal transpose of `s-bits-vertical`: a row of `lineAmt` (1..60) horizontal
strokes, each starting at a stored random x, each `linelength` long, all in one LFO
colour, slanting by `knob3`. The stroke set is re-randomised when the count changes
and on every trigger frame.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` number of lines | `e.param("count", 0.5, 0, 1, 1)` → `floor(knob1*59)+1` |
| `knob2` line length | `e.param("length", 0.5, 0, 1, 2)` → `floor(knob2*320+10)` |
| `knob3` angle | `e.param("angle", 0.5, 0, 1, 3)` → `floor(knob3*100-50)` vertical offset |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO once per frame, phase offset 0.21 |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `random.randrange(-204, 1280)` | `floor(-204 + e.random()*1484)` in one 62-entry table mutated in place |
| `audio_in[i]/180` | `trunc(abs(left[1 + i*10]) * 32768 / 180)` |
| `linewidth = 720/lineAmt` | `floor(720/lineAmt)` |

## Deviations (in the mode header)

Identical set to the vertical sibling, carried verbatim:

1. **`e.random()` for `random.randrange`** — deterministic, same ranges, same
   re-randomise occasions (count change and `ctx.trigger`), same per-list call order.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO phase offset 0.21** (`tools/lfo_offset.py --inc 0.1 --calls 1`), phase
   advanced `30 * inc * ctx.dt` per frame.
4. **Audio stride** — stock index `i` → `left[1 + i*10]`, denormalized by 32768 with
   `abs` and integer truncation, as stock writes it.
5. **No thickness floor needed**: `floor(720/lineAmt)` is 720 px at the baseline (one
   full-height band), so the frame is never a hairline — the vertical sibling's
   problem does not arise.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-bits-horizontal --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `count` | mid 0.0584, max 0.0577 |
| knob 2 `length` | mid 0.1166, max 0.1267 |
| knob 3 `angle` | mid 0.0348, max 0.0467 |
| knob 4 `fg` | mid 0.0000, max 0.0281 |
| knob 5 `bg` | mid 0.9719, max 0.9719 |
| audio | quiet 0.0203, loud 0.0367, freq 0.0000 (threshold 0.001) |
| trigger | **True** — the mode re-randomises the stroke set on a trigger frame |
| luma bounds | mean 28.77–65.77, min stddev 6.78 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **The `audio-freq` variant shows no effect** (0.0000), exactly as its vertical
  sibling documented: the strokes read individual ring samples, so a frequency change
  moves phase rather than amplitude. The quiet/loud variants carry the audio check.
- **`knob4`'s mid probe is 0.0000** (max 0.0281) — the usual static-branch pattern.
- Second consecutive **sibling copy at ~3.5 minutes and one iteration**; nine more P2
  rows should go the same way.