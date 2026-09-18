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

## Verification — 2026-09-18 (after the knob-4 fix)

`python3 tools/verify_port.py s-amp-color-5gon-outlines --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

| Check | 300 frames | 60 frames |
| --- | --- | --- |
| determinism | frac 0.0 | frac 0.0 |
| knob 1 `history` | 0.02431 | 0.03289 |
| knob 2 `spin` | 0.05622 | 0.05522 |
| knob 3 `count` | 0.30129 | 0.38054 |
| **knob 4 `offset`** | **0.02265** | **0.02266** |
| knob 5 `bg` | 0.97569 | 0.96711 |
| audio | quiet/loud 0.02431, freq **0.01156** | 0.03289 / 0.03289 / 0.01157 |
| luma bounds | 30.38–65.93, min stddev 12.27 | 30.69–66.67, stddev 14.51 |
| `p50_ms` (software GL) | 16.66 | 16.64 |

Knob 4's value is **stable across both run lengths** (0.02265 / 0.02266) and clears the
0.001 threshold on its own — the trigger fallback does not fire, because it only fires
when *both* probe points read dead.

## The knob-4 defect and its fix (deviation 10)

The family's shared defect, and it is **stock-faithful**: stock's per-polygon offset is
`current_rotation + i * (knob4 * 180)`, so the knob's whole excursion is multiplied by
the polygon index. At the all-knobs-zero baseline `knob3 = 0` gives `count = 1`, the loop
runs only `i = 0`, and the offset term is identically zero — **knob 4 cannot move a pixel
at any frame count, in stock too**. The gate's second chance (a MIDI trigger, which
re-randomises this mode's geometry) was masking it, which ladder §3.4 forbids banking.

**Fix:** floor the drawn count at **2** so the offset has a second shape to offset — the
same treatment the filled sibling carries, and the pack's precedent for a knob the
baseline multiplies by zero (`s-0-arrival-scope`'s 12 px box floor,
`s-circular-trigon-field`'s 12 px extent). Look impact: below `knob3 ≈ 0.017` the mode
draws two nested outlines where stock draws one, so the all-knobs-zero baseline shows an
inner outline covering roughly 12 % of the frame; above that the geometry is stock-exact.
The fix revived the `audio-freq` probe (0.0000 → 0.01156) and raised `min stddev` from
5.27 to 12.27.

## Residual risk

- **knob 4's liveness margin is thin here** (0.02265 against 0.001 — about 22×, where the
  filled sibling reads 0.11939). It rests on a 7 px outline's rotation being visible
  where a filled polygon's is more so; a stricter `min_fraction` would need the outline
  widened or the floor raised.
- **The count floor is the mode's second geometric deviation** (with the 32-handle cap):
  the all-knobs-zero baseline is not stock's single outline.
- **`audio-quiet` and `audio-loud` are the same value** — stock-faithful, since the family
  reads a waveform sample (`audio_in[i]`), not a spectrum bin.
- **Miter tips can flare** past pygame's round joins for strongly reflex triggered vertex
  sets — the same degenerate case where pygame's own outline degenerates.
- **The 32-handle count cap** is the mode's largest deviation from stock.