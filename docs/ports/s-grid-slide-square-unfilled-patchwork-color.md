# Port report — `s-grid-slide-square-unfilled-patchwork-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Slide Square - Unfilled Patchwork Color/main.py` (83 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 22; **closes the six-mode `grid-slide-square` family** |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier | owed — blocked (see below) |

## What it does

The family's unfilled, per-cell-coloured variant: a 7×10 grid of square **outlines** slid
by the shared `sqmover` oscillator and inflated by one audio sample, each cell's colour
chosen by three sequential overrides.

## The stock diff against `Unfilled Uniform` (one functional difference)

The colour rule is the only change: `Unfilled Uniform` calls `color_picker_lfo(knob4)`
once per frame; this mode carries three sequential overwrites **inside the `j` loop**,
last match wins:

```python
if i%2 == 1:      x = j*x8 - x8 + xoffset ;  color = picker(knob4)
if j%2 == 1:      y = i*y5 - y5 + yoffset ;  color = picker(1-knob4)
if (j+i)%3 == 1:                              color = picker((0.8+knob4)%1)
```

All three use the **static** legacy picker — no LFO state, so **no phase offset applies**
— and the parity branches also assign `x`/`y`, which is the Unfilled geometry (parity-
conditional offsets) rather than an addition to it.

## Mapping

Geometry from the verified `s-grid-slide-square-unfilled-uniform-color` (outline as four
`e.rect` bars, bounding box `width + rad + 2*linew`), the per-class colour grouping from
`s-grid-slide-square-filled-patchwork-color`, and the colour rule above.

**Three `e.color` calls per frame** (one per patchwork class), grouped from the start via
the sibling's preallocated per-class rect slot lists — no per-frame allocation, and the
geometry loop is **not** reordered, so the stateful `sqmover` advances exactly as stock
does. That is the fix applied proactively rather than after a device failure, which is
what the sibling's measurement bought.

Carried conventions: the **14-advances-per-frame** `sqmover` (two `update()` calls per
row, each re-timed `step*30*dt`, both stock clamps), the audio stride with Python's
negative-index wrap, the bg phase fold, and the 1 px step floor / 1 px range fallback for
the mutually dependent knobs.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-slide-square-unfilled-patchwork-color --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `step` | mid 0.0122 |
| knob 2 `pos` | mid 0.0610 |
| knob 3 `size` | mid 0.1456 |
| knob 4 `fg` | mid 0.0258 |
| knob 5 `bg` | mid 0.9488 |
| audio | quiet 0.0557, loud 0.1943, freq 0.0812 (threshold 0.001) |
| luma bounds | mean 28.3–65.52, min stddev 4.98 |
| `p50_ms` (software GL) | 16.6 |

## Residual risk

- **knob 1's liveness margin** rests on the family's 1 px step floor, as in every sibling.
- **knob 4's probes are the family's weakest** (mid 0.0258): the three class colours sit
  close in luma, so the patchwork variants have the thinnest colour-knob margin.
- **280 `e.rect` calls per frame** from the four-bar outline — fill-rate cost, not
  colour-change cost.
- **Device tier blocked**: `eyesyctl package` refuses while the engine repo carries
  uncommitted source edits (*"engine_sources hash is stale; rebuild before packaging"*),
  and rebuilding would compile unfinished engine work.