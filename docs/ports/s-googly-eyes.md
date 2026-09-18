# Port report — `s-googly-eyes`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Googly Eyes/main.py` (112 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 30 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

Two googly eyes whose pupils track the audio, with a 100-segment mouth whose per-segment
colour ramps along the LFO.

## Two fidelity findings

- **Stock imports `random` but never calls it.** Every value is a function of the knobs, the
  100-value audio ring and the LFO state, so the port calls **no `e.random()`** and creates no
  stochastic state — which is why `base` vs `base2` is byte-identical without any seeding work.
- **The LFO was ported from the real runtime** (`EYESY_OS eyesy.py`), not from the mode's own
  usage: the index is advanced by the **previous** call's `inc` mod 2 **before** sampling;
  `phase = index` for `index ≤ 1` else `2 - index`; the static branch returns
  `picker((knob*2)%1)` and does **not** update `inc`; `inc = (knob-0.5)*0.2` above 0.5. At
  60 fps the per-call step halves, so **100 calls per frame advance at stock's 3000 calls/s**.

  **No phase offset is needed here**, and the agent showed why rather than copying the pack's
  0.21: at `knob4 = 1.0` the last call's index lands at 4.95 → 0.95, giving a sclera luma of
  ~58 — at least 30 luma units from both the baseline grey (127.5) and the background (28.3)
  — and the mouth carries five ramps. The offset is a tool for a mode that would otherwise
  sample a crossing; this one provably does not.

## Cost

**Zero meshes**; 105 draw calls per frame at the baseline (1 `e.clear` + 100 `e.line` mouth
segments + 4 `e.circle` for two scleras and two pupils). **2 colour changes** at the baseline
(the mouth's static branch returns one colour for all 100 calls, then the fixed-colour
pupils) — rising to ~101 when `knob4 > 0.5`, where stock's own ramp changes the phase on
nearly every segment. Measured in the gate's renderer: the `knob4`-max run's p50 is 16.65 ms
against the baseline's 16.64, so the extra colour changes are invisible in software
rendering — but the pack's device measurement says they would not be on hardware, so this is
the mode to watch if the tier gate ever returns.

## Deviations

1. **Legacy picker → deterministic middle branch** for the per-segment mouth colour: a smooth
   cosine ramp instead of random grey/RGB speckle. Stock's `color = color_picker(knob4)`
   before the loop is **dead code** (overwritten by the loop's last call), so the sclera takes
   the LFO colour, as in stock.
2. **`color_picker_lfo` ported from the real runtime** (above).
3. **Background phase fold** `c = (bg*0.7+0.15) % 1` — the reason `knob5`'s frac is 0.997 at
   every probe.
4. **Audio**: stock index `j` → `left[1 + j*10] * 32768` with all stock divisors kept — 450
   (eye positions), `y640 = yr*0.889` (mouth y offset), and `500 - int(knob2*499)` (per-segment
   jitter, reaching ±32768 px at `knob2 = 1` where the mouth leaves the frame exactly as
   stock's does). A missing sample reads 0.
5. **Eye LFO class re-timed**: clamp-then-step (so the value may overshoot by one step, as in
   stock), 2 calls per LFO per frame, each step scaled by `30*dt` = stock's 60 steps/s.
   `int()` truncation on the four offsets kept.
6. **Mouth as 100 `e.line` strokes** (the pygame polyline equivalent), width floored at 1 px to
   reproduce pygame's width-0-as-1 clamp; `e.color` issued only when the phase changes.
7. **Pupils**: `int(xrad)`/`-int(yrad)` displacement including Python's truncation toward zero;
   radius `rad/2` and the fixed `(245,200,255)` colour stock-exact.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-googly-eyes --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 `size` | 0.05108 | 0.15779 |
| 2 `mouthwidth` | 0.00202 | 0.00873 |
| 3 `speed` | 0.00550 | 0.00550 |
| 4 `fg` | **0.00000** | 0.00215 |
| 5 `bg` | 0.99718 | 0.99718 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.00533, loud 0.00575, freq **0.00163** (threshold 0.001) |
| trigger | not referenced — no `knob*-trig` run exists in the 16-run set, so the fallback could not fire |
| luma bounds | mean 28.2–64.24, min stddev 4.98 |
| `p50_ms` (software GL) | 16.66 |

## Residual risk

- **knobs 2, 3 and 4 are all thin**: 0.00873, 0.00550 and 0.00215 against the 0.001 threshold.
  The mouth-width and eye-speed knobs move few pixels by nature, and `knob4`'s max probe sits
  at ~2× the threshold. The pack's thinnest knob margins so far.
- **`audio-freq` reads 0.00163** — about 1.6× the threshold, the pack's thinnest audio margin,
  edging out `s-boids`' 0.0031.
- **knob 4's mid probe is exactly 0** — stock-faithful (the static branch maps `knob4 = 0.5` to
  the baseline colour); live at max. No trigger path exists, so the gate cannot be banking a
  false liveness.
- **~101 colour changes per frame at `knob4 > 0.5`** — the mode's one cost risk, invisible in
  software rendering but the pattern the device measurement flagged.