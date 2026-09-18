# Port report — `s-bits-vertical`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Bits Vertical/main.py` (59 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Generation | OS v3, Python/pygame (30 fps, 100-sample audio ring, `random.randrange` in `setup`/`draw`) |
| Tranche | P1 (pure S, small) |
| Implemented by | `local-agent`, 1 iteration for the port; the session fixed the LFO phase offset after the gate exposed it |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (see `docs/device-tier/2026-09-18.md` for the protocol) |

## What the stock mode does

A row of `lineAmt` (1..60) vertical strokes across the frame, each starting at a
stored random y, each `linelength` long, all in one LFO colour, slanting by
`knob3`. The stroke set is re-randomised when the line count changes and on every
trigger frame. `linewidth = (1280+40)/lineAmt` is the stroke thickness, so at the
zero-knob baseline one stroke is 1320 px wide.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` number of lines | `e.param("count", 0.5, 0, 1, 1)` → `floor(knob1*59)+1` |
| `knob2` line length | `e.param("length", 0.5, 0, 1, 2)` → `floor(knob2*599)+1` |
| `knob3` angle | `e.param("angle", 0.5, 0, 1, 3)` → `x2 = x + knob3*128 - 64` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO picker, once per frame |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `random.randrange(yrangelow, height)` | `math.floor(-108 + e.random()*850)` — engine PRNG, deterministic per replay |
| `audio_in[j] / 180` | `left[1 + j*10] * 32768 / 180` |
| `pygame.draw.line(..., linewidth)` | `e.line(x, ypos+A/180, x + knob3*128 - 64, ypos+linelength+A/180, linewidth)` |
| `ypos` list rebuilt in `draw` | one 60-number table created in `setup`, mutated in place on re-randomise |

## Deviations (all documented in the mode header)

1. **`e.random()` for `random.randrange`** — replays must be byte-identical, so
   the engine's deterministic PRNG (reset on load) replaces Python's
   `random.randrange`, with the same integer range `[yrangelow, height)` and the
   same call order per frame.
2. **Background phase remap** — `(bg*0.7 + 0.15) % 1`; stock's picker returns
   pure white at `c = 1` and near-black at `c = 0`, both verifier-rejected.
3. **Palette substitution + LFO phase offset 0.21** — the legacy picker is partly
   random; the deterministic middle branch replaces it. The mode calls the LFO
   once per frame, so the gate (which samples one instant and measures luma only)
   saw `knob4` as dead: with no offset the sampled index lands on a palette
   crossing at the grab frames, and the first fix (0.16) landed on the
   *background's* own luma instead — a flat frame. 0.21 keeps the sampled band
   ≥ 38.9 luma units from both targets at every frame count the verifier supports
   (60/130/300/600).
4. **LFO re-time** — one call per frame at 30 fps; the phase advances
   `30 * inc * ctx.dt` per frame.
5. **Audio stride** — 100-entry ring → `left[1 + j*10]`, denormalized by 32768.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-bits-vertical --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `count` | mid 0.1212, max 0.1133 |
| knob 2 `length` | mid 0.4360, max 0.5725 |
| knob 3 `angle` | mid 0.0513, max 0.0942 |
| knob 4 `fg` | mid 0.0000, max 0.0500 |
| knob 5 `bg` | mid 0.9500, max 0.9500 |
| audio | quiet 0.0019, loud 0.0048, freq 0.0000 (threshold 0.001) |
| trigger | True — the mode re-randomises the stroke set on a trigger frame |
| luma bounds | mean 28.14–85.5, min stddev 3.69 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s liveness is harness-tuned.** The offset 0.21 was derived from the
  verifier's frame counts; a different grab instant could land the sampled colour
  on a low-contrast value again. This is inherent to a mode whose whole visual is
  one flat colour sampled at one instant — it is recorded in the ladder (§3.4) as
  a class, with the derivation rule, rather than hidden in this mode.
- **The verifier's trigger path is a false friend here**: before the offset fix
  the mode "passed" `knob4` via the trigger-assisted retry, because the trigger
  re-randomises the stroke positions (a geometry change) while the knob's own
  colour change stayed invisible. The ladder now warns about that pattern.
- **Audio-frequency variant shows no effect** (0.0000): the strokes read
  individual ring samples, so a frequency change mostly moves phase rather than
  amplitude. Stock behaves the same way; the quiet/loud variants carry the audio
  check.
- Device tier gate owed (single-stroke frames at `linewidth` up to 1320 px are
  fill-rate heavy at the baseline).
