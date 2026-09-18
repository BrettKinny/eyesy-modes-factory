# Port report — `s-folia-curves`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Folia Curves/main.py` (197 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 13; implemented by `local-agent`, **first run, 0 model iterations** (sibling copy) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

Identical to `s-folia-angles` — the 9×7 grid of rotating boxes with per-box smoothed
audio offsets, the seven `knob1` shape families, the never-reset rotation
accumulator and the per-frame alpha veil — with two differences.

## The two differences

1. **Every stock `pygame.gfxdraw.bezier(..., 4, color)` becomes its own 4-step
   quadratic tessellation** — 5 points sampled at `t = 0, ¼, ½, ¾, 1` — emitted as an
   open width-1 line strip. The box outlines in `knob1` modes 4/5/6 stay 2-point
   polylines, matching stock's `aalines` there. The API has no bezier primitive, so
   the sampled curve is the substitution, at stock's own step count.
2. **The per-box audio-history window is 7 frames** instead of 10 (`HIST = 7`), with
   the ring-buffer mechanics unchanged.

## Deviations (in the mode header)

Carried verbatim from the verified sibling: the veil bridged as a **ping-pong render
target** faded by an alpha `e.rect` (ladder §3.2); the never-reset `rotation_angles`
accumulator kept exactly (reset only when `knob2 == 1`) with its increment re-timed
by `30 * ctx.dt`; the per-box history as a preallocated ring; `aalines`'
anti-aliasing dropped; the deterministic palette with the 0.21 LFO phase offset for
the mode's own `inc_amt = 0.05`; the background phase remap; the 10-sample audio
stride; and the 1-based-state / 0-based-stock-index fix.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-folia-curves --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `shape` | mid 0.0613, max 0.0576 |
| knob 2 `spin` | mid 0.0309, max 0.0262 |
| knob 3 `trail` | mid 1.0000, max 1.0000 |
| knob 4 `fg` | mid 0.0000, max 0.0106 |
| knob 5 `bg` | mid 0.9755, max 0.9755 |
| audio | quiet 0.0214, loud 0.0503, freq 0.0418 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | **mean 4.13–26.09**, min stddev 1.56 |
| `p50_ms` (software GL) | 16.7 (resources 6) |

## Residual risk

- **The frame is very dark** (mean luma 4.13 at its lowest), the same as the
  sibling: the veil fades toward a near-black background, so the mode sits close to
  the verifier's blank bound. The bezier substitution makes it marginally darker
  still than the polylines it replaces (fewer, thinner strokes).
- **`knob3`'s probes read 1.0000** — the veil keys off the trail knob, so its states
  are maximally different from the baseline; the knob's subtle range is untested.
- **The persistence bridge transferred between siblings without rework** — the second
  mode in the pack to carry a ping-pong render target, and the copy passed first try.
- Device tier owed.