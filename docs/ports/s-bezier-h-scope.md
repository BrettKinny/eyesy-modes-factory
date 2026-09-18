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

## The cost problem this port inherited, and its fix

**3312 `e.line` strokes per frame** (12 curves × 23 cubic segments × 12 substeps) — note
this report first said 1728, which was an **arithmetic slip** (12 × 23 × 12 = 3312); the
batching task caught it.

That is the pack's own measured warning sign: `s-folia-curves` measured **40.56 ms** on the
CM3+ (a 24.18 ms floor, +16.4, outside tier C) before batching took it to **30.00 ms**.
Ladder §3.5: *the bigger lever is draw calls, not resolution.*

**Batched into meshes (deviation 8).** Each stroke is a 4-vertex quad with static 1-based
triangle indices. 3312 quads is 13248 vertices — **over the engine's 8192-vertex cap** — so
the frame is split across the fewest meshes that fit: **`MESHES = 2`, six curves each**,
1656 quads → **6624 vertices / 9936 indices per mesh**, inside both caps, 2 handles of the
32 allowed. Two `e.update_mesh` + two `e.draw_mesh` per frame replace the 3312 `e.line`
calls. Because each stroke is its own quad, the 12 separate curves and their segments never
gain spurious joining segments — the trap a single continuous line strip would have hit
(`update_mesh` without indices *is* a line strip). `CURVES / MESHES` is exact, so every mesh
is exactly full every frame and `update_mesh` never sees a partially-filled table.

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

## Verification — 2026-09-18 (after batching)

`python3 tools/verify_port.py s-bezier-h-scope --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 `yoff` | 0.01700 | 0.01650 |
| 2 `xoff` | 0.01020 | 0.02570 |
| 3 `trails` | 1.00000 | 0.99310 |
| 4 `fg` | **0.00000** | 0.00930 |
| 5 `bg` | 0.99070 | 0.99070 |

| Check | 300 frames (batched) | 300 frames (before) |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| audio | quiet 0.0112, loud 0.0266, freq 0.0145 | 0.0146 / 0.0348 / 0.0191 |
| trigger | not referenced | not referenced |
| luma bounds | mean 13.6–64.59, min stddev 2.94 | 14.48–64.77, min stddev 3.35 |
| `p50_ms` (software GL) | 16.7 (resources 4) | 16.6 (resources 2) |

Every value moves by a few percent and none changes character — the expected result of
rasterising each 1 px stroke as a solid quad instead of a width-1 line, the same trade the
folia sibling documented (*same footprint, no anti-aliasing either way*). `resources 4` is
the two meshes plus the two half-resolution trail targets.

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