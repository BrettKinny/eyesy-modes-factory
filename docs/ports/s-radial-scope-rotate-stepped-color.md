# Port report — `s-radial-scope-rotate-stepped-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Radial Scope - Rotate Stepped Color/main.py` (78 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 39 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

75 radiating strokes from the screen centre — lines with tip circles below `knob3 = 0.5`, lines
only above it — whose radii carry the audio, rotating at a rate and direction set by `knob1`.

## Three failures, one cause (the diagnosis)

The first revision failed with a **flat frame**, a **dead rotation knob** and **no audio
reactivity**. One cause:

```python
R1 = int(knob2 * x800)                                        # x800 = 800 at 1280
R  = R1 + (abs(audio_in[i]) / ((x800 * 20 / (R1 + 1)) + 1))
```

At the all-knobs-zero baseline `knob2 = 0` → `R1 = 0` → the divisor becomes `16001`, so `R` is
at most **~2 px at full-scale audio**. The whole scope is a dot at the centre: a dot gives a
uniform frame, rotating a dot changes nothing, and the audio moves the radius by ~2 px.

**The first fix floored the wrong term** — it floored `R`, still a dot. The floor belongs on
**`R1`**, the figure's size input, which is what the knob multiplies by zero. Deviation 7 sets
`R1_FLOOR = 40 px`: below `knob2 ≈ 0.05` the scope draws a 40 px star where stock draws a
sub-pixel dot; above that, `knob2` scales 40 → 800 px stock-exact.

This is now ladder §4 as its own deviation class ("a radius the baseline collapses to nothing"),
because the same shape recurs wherever a stock radius is divided by `(R1+1)`.

## Other deviations

4. **Rotation re-timed**: `inc * 30 * ctx.dt` per frame, with `inc` stock-exact (`0` inside
   `0.48..0.52`, else `(knob1-0.5)*25` degrees per 30-fps frame).
5. **The stepped colour is collapsed to one per frame — deliberately.** Stock gives each of the
   75 segments its own colour, `picker((i * (1/(75*(knob4+0.001)))) % 1)` — a 75-step ramp. That
   is **75 per-frame colour changes**, and the pack's measured cliff is exactly that (70 changes
   = **+13.7 ms**, outside tier C). The ladder's resolution is one colour per colour class, and
   here the 75 steps are 75 classes, so the within-budget choice is one representative colour:
   `picker((knob4 + 0.21) % 1)`. The **0.21 offset is load-bearing** — the picker is now called
   once per frame, and the gate samples one instant, so `picker(0)` would be pure black and read
   as a near-dark frame; `picker(0.21)` sits 0.238 from the palette grey and 0.627 from the
   background. **Fidelity loss: the stepped rainbow itself.** `knob4` stays live by recolouring
   the whole scope.
6. The usual: the deterministic middle-branch picker, the background phase fold, 30 → 60 fps.

## Rendering

**1 mesh handle**, allocated once in setup: **300 vertices / 450 indices** (one quad per spoke),
far inside the caps. Per frame: 1 `e.clear` + 1 `e.update_mesh` + 1 `e.draw_mesh` + up to 75
`e.circle` fills, with exactly **one colour change**. The draws are cheap — the pack's measured
cost is colour *state changes*, and there is one.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-radial-scope-rotate-stepped-color --frames 300` → `"verdict": "pass"`, `failures: []`, `audio_pass: true`.

Per-probe A/B, fraction of pixels changed (300 frames):

| Knob | mid | max |
| --- | --- | --- |
| 1 `rotation` | 0.00352 | 0.00585 |
| 2 `diameter` | 0.45756 | 0.49760 |
| 3 `linewidth` | 0.02573 | 0.01021 |
| 4 `fg` | 0.02937 | **0.00000** |
| 5 `bg` | 0.97063 | 0.97063 |

| Check | 300 frames | 60 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| audio | quiet 0.01702, loud 0.07128, freq 0.00414 — **pass** | 0.01700 / 0.07127 / 0.00416 |
| luma bounds | 28.58–111.79, **min stddev 9.57** | 28.58–111.73, stddev 9.55 |
| `p50_ms` (software GL) | 16.65 | 16.63 |

All three original failures are gone, and the audio probes went from 0.0 to live.

## Residual risk

- **The stepped rainbow is gone** — the mode draws one colour for all 75 spokes where stock ramps
  through 75. This is the largest deliberate fidelity concession in the pack, taken because the
  faithful version costs 75 colour changes against a measured cliff at 70.
- **`knob1`'s probes are thin** (0.0035–0.0066): rotation moves the spokes but a single grab
  instant sees little change, especially at the floored 40 px radius where the star is small.
- **`knob4`'s max probe is exactly 0**: at `knob4 = 1.0` the single colour folds back to the
  baseline's. Live at mid (0.02937).
- **The `R1` floor (deviation 7)** means the baseline is not stock's dot, and below
  `knob2 ≈ 0.05` the scope is larger than stock's.
- **`audio-freq` is thin** (0.00414) though clearly above the threshold — the radius carries the
  waveform, not the spectrum.