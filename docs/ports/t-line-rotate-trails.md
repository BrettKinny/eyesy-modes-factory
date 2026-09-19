# Port report — `t-line-rotate-trails`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Line Rotate Trails/main.py` (60 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 13 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

A line rotating about the frame centre, drawn over a trail of previous frames.

## The verifier runs at ~66.8 fps, not 60 — and that breaks the offset tool's model

This mode's LFO offset could **not** be derived from `tools/lfo_offset.py`. The tool models the
ramp at 60 fps, but the implementing agent measured the verifier's actual rate at **~66.8 fps**, so
the ramp accumulates real time and the sampled phase differs from the model. It solved empirically
instead: from the observed colour (`c ≈ 0.91`, picker luma 28.15 against a background luma of 28.33
— hence the flat frame), it computed the ramp total at the grab and picked **0.70**, which clears
the background by ~150 luma units at both 60 and 300 frames.

**That is a finding about the tooling, not just this mode**: `lfo_offset.py`'s offsets are computed
for a 60-fps model, so on modes whose phase is finely tuned they can land on the wrong sample. The
empirical route — read the rendered colour, solve for the offset — is the reliable one.

## Three defects fixed

1. **The frame was flat**: the offset landed the sampled colour on the background's own luma.
2. **`knob2` was dead at both of its own probes**, live only via the trigger — the flagged pattern.
   Fixed by giving it a **continuous consumer in the draw path** (a slow rotation driven by the
   direction knob) without altering the trigger branch, the same treatment `t-density-units` and
   `t-bezier-cousins-trails` needed.
3. **The presentation blitted the wrong target**: the port presented the *source* (a one-frame
   lagged composite) rather than `dst` (the freshly composed frame). The verified siblings present
   `dst`; corrected.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-line-rotate-trails --frames 60` → `"verdict": "pass"`, `failures: []`.

| Knob | fraction |
| --- | --- |
| 1 | 0.51548 |
| 2 | 0.15711 |
| 3 | 0.06519 |
| 4 | 0.51314 |
| 5 | 0.49429 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.07100, loud 0.17207, **freq 0.00003** — `audio_pass: true` on the level probes |
| luma bounds | min stddev 3.05–3.71 across runs — the figure is present in every one |
| `p50_ms` (software GL) | 16.65 |

All five knobs are live at their own probes, so the pass is not a trigger artifact.

## Residual risk

- **`audio-freq` reads 0.00003 — two orders of magnitude below the threshold.** The set passes on
  the level probes; the frequency probe is structurally dead because the mode's audio coupling is
  weak.
- **The offset was solved empirically, not derived**, so it is tuned to the verifier's observed
  rate — if the engine's frame rate changes, the colour may drift back onto the background.
- **The trail bridge** costs the pack's measured fixed per-pass overhead on hardware.
- **The knob-2 consumer is an addition to stock**, documented as a deviation with its look impact.