# Port report — `s-amp-color-5gon-outlines`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Amp Color - 5gon Outlines/main.py` (132 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 24; second mode of the `amp-color` family |
| Verification | `scene_verify.py --frames 300` — **pass**, but `knob 4` is dead at that length and the verdict rests on the trigger fallback — **family-wide, see below** |
| Device tier | retired (repo-only) |

## What it does

The `amp-color` family's 5-vertex polygon in **outline** form: `count` nested pentagons
at the screen centre, each scaled by the family spacing formula, rotated by the
accumulating angle, and coloured from the running average of its own audio history.

## The stock diff (one hunk in 132 lines)

```
132c132
< pygame.draw.polygon(screen, color, rotated_points)          # Filled
> pygame.draw.polygon(screen, color, rotated_points, 7)       # Outlines, 7 px
```

Nothing else differs — the expected single draw-argument difference, confirmed against
the sources rather than assumed.

## Representing a centred stroke with filled meshes

The engine's mesh primitive is **filled**, and pygame's `linewidth` is a **centred**
stroke that straddles the path — so an inset or outset polygon would cover only one side
of it. The port builds a **mitered ring of five filled quads**, one per polygon edge,
each corner displaced ±3.5 px along the bisector of its two adjacent edge normals and
scaled by `1/cos(half-angle)` with a 5:1 miter limit, normals oriented outward from the
centroid. That reproduces the 7 px band on **both** boundaries (documented as deviation 6).

Its first two revisions failed: a bad miter scale factor (dividing half the width by the
endpoint-centroid projection instead of offsetting along the normal) collapsed the quads
and rendered a near-blank frame. Fixed by offsetting along the normal.

## Mapping

Structure copied from the verified `s-amp-color-5gon-filled`: the nested-shape loop with
the stock spacing factor, the per-shape audio-history running average (preallocated
32×21 in-place tables standing in for stock's `deque(maxlen=N)`), the rotation
accumulation with its `0.49..0.51` dead zone and the 30→60 fps re-timing, the trigger
re-randomisation of 5 points in `[-1,1]`, the background picker with its phase remap, and
the **32-handle cap** with its documented count deviation (stock draws up to 60 nested
polygons; each needs its own handle because its colour comes from its own audio history).

32 handles, 20 vertices / 30 indices each (5 quads, 10 triangles, **1-based** indices),
up to 32 `e.color` calls per frame. Zero per-frame allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-amp-color-5gon-outlines --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `history` | mid 0.0000, max 0.0127 |
| knob 2 `spin` | mid 0.0341, max 0.0271 |
| knob 3 `count` | mid 0.2762, max 0.2959 |
| **knob 4 `offset`** | **mid 0.0000, max 0.0000** |
| knob 5 `bg` | mid 0.9872, max 0.9872 |
| audio | quiet 0.0127, loud 0.0127, freq 0.0000 (threshold 0.001) |
| trigger | **True** |
| luma bounds | mean 28.6–65.1, min stddev 5.27 |
| `p50_ms` (software GL) | 16.6 (resources 32) |

## Residual risk

- **`knob 4` is dead at 300 frames here too, and this pass is also a false liveness.**
  Both probe points read `0.0000` and the verdict survives on the trigger fallback
  (`trigger_pass: True`) because the mode re-randomises its polygon geometry on a
  trigger. **This makes it family-wide, not a one-off**: the sibling `5gon-filled` shows
  the identical pattern (dead at 300 frames, live at 60 at 0.74932), so the cause is the
  family's shared rotation mechanism rather than either port's implementation. The
  `5gon-filled` fix is in flight and its diagnosis will be applied here; the two
  remaining family modes (`Circles`, `Rectangles`) will need it as well.
- **`audio-freq` reads 0.0000** and quiet/loud are identical — stock-faithful, since the
  family reads a waveform sample (`audio_in[i]`), not a spectrum bin.
- **The 32-handle count cap** is the mode's largest deviation from stock.
- **Miter tips can flare** past pygame's round joins for strongly reflex triggered vertex
  sets — the same degenerate case where pygame's own outline degenerates.