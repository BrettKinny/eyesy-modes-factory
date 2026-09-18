# Port report — `s-nested-ellipses-outlines`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Nested Ellipses - Outlines/main.py` (75 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 37; sibling of `s-nested-ellipses-filled` |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` — **but see the flatness margin below** |
| Device tier | retired (repo-only) |

## What it does

Up to **100** nested ellipse **outlines**, each sized and coloured by its own slot in an audio
history ring.

## The outline representation

A **36-segment quad ring**: 0.5 px inside and 0.5 px outside the stock boundary (a 1 px band
centred on the path), one quad per boundary segment in the same ordering the 5gon-outlines
sibling uses, with **mitered corners** (unit bisector of the two adjacent segment normals, dot
clamped at 0.2 for a 5:1 miter limit). 144 vertices / 216 static **1-based** indices per mesh,
mutated in place. This is the pack's established answer to "the mesh primitive is filled and
`e.rect` has no border width", reused rather than reinvented.

**Look impact vs `pygame.gfxdraw.ellipse`:** a hard-edged 1 px band with no anti-aliasing
(stock is faintly anti-aliased with rounded line ends); the band is **centred** on the path
where pygame's 1 px line sits ~0.5 px inside, so the port's outline is ~0.5 px larger; and at
sub-pixel radii the quad ring can self-overlap where stock draws nothing. Stock's `int()`
truncation of centres and radii is kept.

## The stock-vs-sibling diff (verified)

- `count = int(knob3*99)+1` — **100 ellipses**, not 50.
- `color_picker_lfo(knob4, 0.008)` — a ramp **10× slower** than the sibling's 0.08.
- `gfxdraw.ellipse` instead of `filled_ellipse`.
- Geometry, the offset function, the audio history and the knob roles are otherwise identical.

The slower ramp and the larger count both enter the per-frame ramp rate (`inc * count * 30 * dt`).

## Deviations

Carried from the sibling where they apply, each verified rather than inherited: the
deterministic middle-branch picker with the per-element ramp; the background phase fold; the
**LFO ramp running at every `knob4`** (stock's static branch below 0.5 renders one shape and
kills `knob2`/`knob3`); the **count floor of 2** (stock's `count = 1` makes `knob2`'s index term
identically zero); the count **cap of 32** by the mesh-handle budget (a larger deviation here,
100 → 32); the history ring pushing once per 60-fps frame; and **divisor 15000 with `abs`**.

## Rendering

**32 mesh handles** (the engine cap), 144 vertices / 216 indices each. `p50_ms` 16.62 in
software GL. Zero per-frame allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-nested-ellipses-outlines --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed (300 frames):

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.00583 | 0.00614 |
| 2 | 0.00214 | 0.00214 |
| 3 | 0.03176 | 0.03176 |
| 4 | 0.00339 | 0.00339 |
| 5 | 0.99661 | 0.99661 |

| Check | 300 frames | 60 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| audio | quiet 0.00572, loud 0.00825, freq 0.00212 | identical |
| trigger | not referenced | not referenced |
| luma bounds | 28.11–64.03, **min stddev 0.59** | 28.14–64.1, stddev 1.71 |
| `p50_ms` (software GL) | 16.62 (resources 32) | — |

## Residual risk

- **`min stddev 0.59` against a flatness floor of 0.51 — a margin of 0.08, the thinnest in the
  program.** The offending frame is `knob5`-mid (the bright-background probe: mean 64.03,
  stddev 0.59) — a bright, nearly uniform background with thin outlines over it. At 60 frames the
  same probe reads 1.71, so the margin shrinks as the run lengthens. **This mode is the closest
  anything in the pack has come to failing the gate**, and a slightly different palette or grab
  instant could tip it.
- **knobs 1, 2 and 4 are all thin** (0.0058, 0.0021, 0.0034). Thin outlines move few pixels by
  nature, and `knob2`'s two probes read identically — the count knob changes which ellipses are
  drawn but the outlines are thin enough that the changed-pixel fraction barely moves.
- **The count cap (100 → 32)** is the largest fidelity deviation in the family: stock's top
  settings draw more than three times the ellipses the handle budget allows.
- **The 0.5 px offset in the outline** (centred band vs pygame's inner line) makes every ellipse
  marginally larger than stock's.
- **The history window is half as long** (`N/60` s vs stock's `N/30` s).