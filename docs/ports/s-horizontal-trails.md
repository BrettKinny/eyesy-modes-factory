# Port report — `s-horizontal-trails`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Horizontal + Trails/main.py` (72 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 31 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

100 horizontal strokes (lines or balls, in three `knob1` regimes) whose deflection is one
audio sample each, over a rescaled, re-blitted copy of the previous frame.

## The trail, ported literally

Stock keeps the screen between frames, then rescales the **previous frame** to
`(thingX, thingY)` and blends it over the current strokes at `alpha = int(knob3*180)`. The
scene API cannot read the screen back, so the port uses the pack's half-resolution
ping-pong bridge (640×360), but keeps stock's three-part composition:

1. the back target is filled with the previous target faded toward the background by
   `1 - alpha/255` — the recursion's own decay in the bridge's form;
2. this frame's strokes are added;
3. the result is blended over the screen at stock's `(placeX, placeY, thingX, thingY)` with
   stock's alpha.

**The veil alpha is floored at 8/255** (pack convention): at `knob3 = 0` stock's alpha is 0,
and an unfloored 0 would leave the feedback target untouched — pinning the previous frame
forever and failing determinism on startup audio jitter. With the floor the target always
fades toward the background, while `knob3` still governs the trail's opacity (180/255 at
`knob3 = 1`, stock-exact).

## The coordinate split (deviation 7)

With the trail on, the strokes are drawn **twice per frame** — once on the screen in `W × H`
and once into the 640×360 target — and the engine uses a target's own dimensions for the
coordinate space inside it, so **every length stock derives from `xres`/`yres` is derived from
the surface being drawn on**: `W`/`H` on the screen, `TW`/`TH` in the target (`GW = (alpha > 0)
and TW or W`). Without that split the screen-sized strokes would be clipped to the target's
top-left corner and upscaled — **which the verifier does not catch**. That is the bug that
shipped in both bezier modes, and this port avoids it by construction.

## Other deviations

1. **Legacy picker → deterministic middle branch**; the LFO is `color_picker_lfo(knob4)` at the
   default `inc_amt 0.1`, once per frame, so it takes the documented **0.21** offset.
2. **Background phase fold** `c = (bg*0.7+0.15) % 1`.
3. **Audio**: stock index `i` → `left[1 + i*10]` × 32768; the stock **divisor is 90**
   (`y1 = A/90`, a full-scale sample spanning ±364 px at 720p — half the screen height), so the
   deflection scales with the presentation height as `trunc(A/90 * (GH/720))`: stock-exact at
   720 and ±182 px in the 640×360 target. Python's `int()` truncation preserved.
4. **Persistence bridge** (above), half resolution, veil floored.
5. **30 → 60 fps**: the only per-frame constant is the LFO ramp, advanced once per frame by
   `30 * inc * ctx.dt`.
6. **Degenerate primitives**: pygame draws nothing for a radius-0 circle or a width-0 line, but
   a mesh quad/fan is emitted literally, so zero width/radius has to be emitted as **zero-area
   geometry**. Regime 1 passes `ballSize = 0` and regime 2 `linewidth = 0` (stock's own "no
   balls" / "no lines"), so both are emitted degenerate.
7. **Presentation coordinates** (above).

## Rendering

100 strokes batched into **indexed triangle meshes** — one quad per line and one fan per ball,
the one not shown by the current regime emitted degenerate. The two buffers are refilled for
the screen pass and, with the trail on, for the target pass, using **the same two mesh handles**
for the mode's life — no per-pass resources, zero per-frame allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-horizontal-trails --frames 300` → `"verdict": "pass"`, `failures: []`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `shape` | 0.39778 |
| knob 2 `trail size` | 0.07529 |
| knob 3 `trails` | 0.12756 |
| knob 4 `fg` | 0.04911 |
| knob 5 `bg` | 0.98773 |
| audio | quiet 0.04688, loud 0.07556, freq 0.06186 (threshold 0.001) |
| trigger | not referenced |
| luma bounds | mean 28.06–66.87, min stddev 2.32 |
| `p50_ms` (software GL) | 16.6 |

## Residual risk

- **`min stddev 2.32` is the pack's lowest luma margin** — a dark frame with thin strokes over
  a decayed trail. It passes the flatness floor with room, but a stricter gate would be close.
- **The trail is softer than stock's** because the feedback targets are half resolution, and the
  bridge has no alpha of its own (hence the veil floor, which makes the baseline trail decay
  where stock's would persist).
- **The mode draws twice per frame when the trail is on** (screen + target), so its real cost is
  roughly double the stroke count; the two mesh handles make that two mesh draws per pass.
- **Deviation 6 is a genuine visual difference at regime boundaries**: stock's zero-width lines
  and zero-radius balls draw nothing, and the port emits zero-area geometry instead — same
  result, but the mechanism differs if a future engine changes degenerate handling.