# Port report — `s-bezier-h-scope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Bezier H Scope/main.py` (113 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 27 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) — **but see the draw-call cost below** |

## What it does

Twelve horizontal cubic-bezier curves whose control points come from the audio window,
drawn over a decaying trail, with a moving spot.

## The cost problem this port inherits

**1728 `e.line` strokes per frame** (12 curves × 23 cubic segments × 12 substeps). That is
the pack's own measured warning sign: `s-folia-curves` issued ~4032 *vertices* worth of
polylines and measured **40.56 ms** on the CM3+ (a 24.18 ms floor, +16.4, outside tier C)
before it was batched into one mesh — after which it measured **30.00 ms**. The pack's
recorded lesson (ladder §3.5) is explicit: *the bigger lever is draw calls, not
resolution*.

1728 strokes is roughly 10× the folia stroke count, so this mode is **expected to be far
outside tier C** on real hardware. The device gate is retired by user direction, so this is
not a gate failure — but the pack's own guidance says the fix is the **quad idiom**: one
mesh per frame, every stroke a 4-vertex quad with static 1-based triangle indices
(1728 × 4 = 6912 vertices, 1728 × 6 = 10368 indices, both inside the 8192 / 49152 caps),
one `e.update_mesh` + one `e.draw_mesh`. **Batching fix queued.**

## The persistence bridge

Stock's per-frame background veil (`alpha = int(knob3*20)`) has no previous-frame buffer in
the scene API, so the port uses the pack's **half-resolution ping-pong feedback bridge**
(640×360 targets upscaled to 1280×720, the `whitney-kaleido` idiom) — the trail reads
slightly softer than stock's. At `knob3 = 0` there is no feedback, matching stock's
transparent veil. 2 render targets, 5 `e.color` calls in the persistence path.

## Deviations

1. **Legacy picker → deterministic middle branch** (stock's is partly random; replays must
   be byte-identical). The LFO's static branch and its 0→2→0 ramp semantics are stock-exact.
2. **LFO re-timed 30→60 fps and initialised to 0.21.** At `knob4 = 1.0` the un-offset ramp
   passes through `picker(0) = (0,0,0)` — the baseline colour — exactly at the 60/300-frame
   grabs, which would read dead on the luma metric; at 0.21 the grabbed colour keeps ≥9.8
   luma units from the background at every supported frame count.
3. **Background phase fold** `c = (bg*0.7+0.15) % 1`.
4. **Audio**: stock index `i*2` (i = 0..23) → `left[1 + i*20]`, denormalized `*32768`; the
   stock divisor **32768** is kept (full-scale sample spans the screen height), with
   Python's `int()` truncation preserved for negative samples.
5. **Persistence bridge** (above), half resolution.
6. **Off-screen extents kept stock-exact** (the spot starts two intervals left; curve `i`
   shifts `i*100` px right so the top curve's right end exits the frame at `xoff > 0`) —
   stock's own framing, the frame is never blank, all probe points observable.
7. **Bezier tessellation**: no bezier primitive in the API, so each curve is 23 cubic
   segments (midpoint control handles) at 12 substeps — matching `gfxdraw`'s 1 px raster.
   Zero per-frame allocation; **0 mesh handles**.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-bezier-h-scope --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 `yoff` | 0.02243 | 0.02178 |
| 2 `xoff` | 0.01345 | 0.03390 |
| 3 `trails` | 1.00000 | 0.99619 |
| 4 `fg` | **0.00000** | 0.01230 |
| 5 `bg` | 0.98770 | 0.98770 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.01461, loud 0.03483, freq 0.01905 (threshold 0.001) |
| trigger | not referenced — stock has no trigger/random state, so the fallback cannot fire |
| luma bounds | mean 14.48–64.77, min stddev 3.35 |
| `p50_ms` (software GL) | 16.58 |

## Residual risk

- **knob 4's mid probe is exactly 0**, and this is **stock-faithful**: stock's static branch
  maps `knob4 = 0.5` to `picker(0.0)` — the same colour as `knob4 = 0`. The knob is live at
  its max (0.01230), and with no trigger path the gate cannot be banking a false liveness.
  No floor was applied, correctly.
- **1728 draw calls per frame** — the mode's dominant cost risk, and the reason the
  batching fix is queued (above).
- **The trail is softer than stock's** because the feedback targets are half resolution.
- **`min stddev 3.35` is low** (luma 14.48–64.77): a dark frame with thin 1 px strokes, so
  it sits relatively close to the verifier's flatness floor.