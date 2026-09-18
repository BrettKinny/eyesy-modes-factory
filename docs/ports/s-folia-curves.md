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

## Device tier: fixed, measured

| Revision | device p50 | marginal (floor 24.18) | tier C (≤ 33.3 ms) |
| --- | --- | --- | --- |
| full-res bridge, line strips | 52.56 | +28.4 | outside |
| half-res bridge, line strips | — | — | (superseded) |
| **quarter-res bridge, batched quads** | **30.00** | **+5.8** | **inside** |

The decisive lever was **draw calls, not resolution**: the polylines are now one
preallocated mesh per frame (every segment a 4-vertex quad with static 1-based
triangle indices — the house idiom from the bespoke library's `flow-field-drift` and
`kalachakra-stupa`), one `e.update_mesh` + one `e.draw_mesh` per frame, worst case
4032 vertices / 6048 indices. The agent explicitly rejected a single continuous line
strip, correctly: `update_mesh` without indices *is* a line strip, and it would have
drawn spurious joining segments between the four separate curves per box and across
the 63 boxes.

The mode is now **cheaper than its sibling** (30.00 vs 32.96 ms), which uses line
strips.

## Determinism: the veil floor

One 300-frame run failed the harness precondition (*"identical replays differ by mean
4.73, frac 0.98"*) while four others passed. Cause: at the baseline every knob is 0, so
the veil alpha is `knob3*45/255 = 0` — stock's baseline veil does nothing, the trail
never decays, and the engine's audio analysis arrives from a separate thread, so a
first-frames snapshot difference becomes **permanent**. The port floors the alpha at
**8/255** (~3 %, a ~30-frame time constant), which attenuates a startup difference to
~1e-4 by frame 300 while the trail still reads as a trail. Two consecutive 300-frame
runs pass with the floor in place.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-folia-curves --frames 300` → `"verdict": "pass"` (two
consecutive runs, determinism precondition holding). Software GL (llvmpipe), engine
sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 (with the veil floor) |
| knob 1 `shape` | mid 0.1327, max 0.2220 |
| knob 2 `spin` | mid 0.1241, max 0.1039 |
| knob 3 `trail` | mid 0.9955, max 0.9964 |
| knob 4 `fg` | mid 0.0000, max 0.0573 |
| knob 5 `bg` | mid 1.0000, max 1.0000 |
| audio | quiet 0.0994, loud 0.2004, freq 0.1407 (threshold 0.001) |
| luma bounds | mean 4.44–26.04, min stddev 1.28 |
| `p50_ms` (software GL) | 16.1 (resources 6) |

## Residual risk

- **The frame is very dark** (mean luma 4.44 at its lowest): the veil fades toward a
  near-black background, so the mode sits close to the verifier's blank bound. Same as
  its sibling.
- **The quads are solid 1-target-pixel rectangles** where the line strips were
  width-1 strips — the same footprint, no anti-aliasing either way (the `aalines` AA
  was already dropped).
- **The veil floor changes the baseline look**: stock's trail is permanent at
  `knob3 = 0`; the port's always decays (that is what makes the mode deterministic).
- **The batching lesson is now in the ladder** (§3.2): for polyline-heavy modes the
  tier lever is draw calls, not resolution.