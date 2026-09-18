# Port report — `s-amp-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Amp Color/main.py` (79 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 3; implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 (mode sha256 `a7fb889b8bcc…` unchanged across the run) |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

100 full-height bars whose colour is the **running average of that bar's recent
audio history**, plus a horizontal mirror of the same bars. `knob1` sets the history
length (1..21), `knob2` the bar width, `knob3` the y position (which also brings the
horizontal bars into view). Stock's `knob4` is unused.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` audio history length | `e.param("history", 0.5, 0, 1, 1)` → `floor(knob1*20)+1` |
| `knob2` bar width | `e.param("width", 0.5, 0, 1, 2)` → `floor(knob2*12.8)+2` |
| `knob3` y position | `e.param("posy", 0.5, 0, 1, 3)` → `v_place = knob3*720` |
| `knob4` — **unused in stock** | `e.param("unused", 0, 0, 1, 0)` — declared with knob argument 0, never read |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `deque(maxlen=N)` per index | two preallocated tables (`hist[100][21]` + `hist_len`/`hist_write`) mutated in place |
| `sum(history)/len(history)` | the mean of the most recent `hist_len[i]` values |
| `abs(audio_in[i]/32768)` | `math.abs(left[1 + i*10])` — already normalized |
| `pygame.draw.rect(..., 0)` ×3 | `e.rect` ×2 (stock's third call is a byte-for-byte duplicate and is dropped) |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Audio stride** — stock index `i` → `left[1 + i*10]`; the buffer is already
   normalized so the stock `/32768` is not reapplied.
4. **The deque history becomes two preallocated tables** mutated in place, so
   `draw` allocates nothing. The average is the mean of the most recent
   `min(N, 21)` values — exactly what `deque(maxlen=N)` computes.
5. **Stock's duplicate draw call is dropped**: it issues the same vertical bar
   twice per index.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-amp-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `history` | mid 0.0000, max 0.1516 |
| knob 2 `width` | mid 0.4688, max 0.8438 |
| knob 3 `posy` | mid 0.1409, max 0.2852 |
| knob 4 `unused` | not swept — declared with knob argument 0, exactly as stock leaves it |
| knob 5 `bg` | mid 0.8438, max 0.8438 |
| audio | quiet 0.1500, loud 0.1562, freq 0.1437 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 45.29–140.13, min stddev 12.13 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **The frame is bright** (mean up to 140 of the 251 bound): 100 full-height bars
  plus their mirror cover much of the canvas. It passes with room, but a denser
  variant would need care.
- **`knob1`'s mid probe is 0.0000** while max is 0.1516: a 1-step history change at
  the mid point averages over too few frames to differ from the baseline's
  single-sample colour. The knob is live via max.
- **`knob4` is deliberately inert** — stock's own comment says `[not used]`. The
  queue row records it so a future reader does not read the 0.0 as a defect.
- Device tier owed; 200 `e.rect` calls per frame at the baseline (100 vertical +
  100 horizontal).
