# Port report — `s-grid-slide-square-unfilled-column-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Slide Square - Unfilled Column Color/main.py` (79 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 21; sixth mode of the `grid-slide-square` family |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier | owed — blocked (see below) |

## What it does

The family's unfilled, per-column-coloured variant: a 7×10 grid of square **outlines**
slid by the shared `sqmover` oscillator and inflated by one audio sample, each column in
its own colour.

## The stock diff against `Unfilled Uniform` (one functional difference)

The colour rule moves inside the `j` loop and becomes static:

```python
color = eyesy.color_picker(((j*.1) + eyesy.knob4) % 1.0)   # per column
```

`Unfilled Uniform` instead calls `color_picker_lfo(knob4)` once per frame. Everything else
— the grid, the `sqmover`, the audio term, the `linew` outline — is identical. The picker
here is the **static** legacy one, so **no phase offset applies**; the 0.45 offset used
when a mode advances the LFO per element (see the filled-column sibling) is carried only
for the LFO path.

## Mapping

Built from two verified siblings: the outline geometry from
`s-grid-slide-square-unfilled-uniform-color` and the per-column static colour rule from
`s-grid-slide-square-filled-column-color`. Carried conventions: the outline as **four
`e.rect` bars** with the bounding box at `width + rad + 2*linew` (**280 `e.rect` calls per
frame**), the **14-advances-per-frame** `sqmover` (two `update()` calls per row, each
re-timed `step*30*dt`, both stock clamps), the audio stride with Python's negative-index
wrap, the bg phase fold, and deviations 8 and 9 (the 1 px step floor and 1 px range
fallback). **10 `e.color` calls per frame** — one per column, no per-cell colour — so it
avoids the cost that pushed the patchwork variants outside tier C.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-slide-square-unfilled-column-color --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `step` | mid 0.0109, max 0.0124 |
| knob 2 `pos` | mid 0.0611, max 0.0647 |
| knob 3 `size` | mid 0.1205, max 0.1461 |
| knob 4 `fg` | mid 0.0000, max 0.0512 |
| knob 5 `bg` | mid 0.9488, max 0.9488 |
| audio | quiet 0.0557, loud 0.1977, freq 0.0814 (threshold 0.001) |
| trigger | `None` — the scene does not reference `ctx.trigger` |
| luma bounds | mean 28.46–67.1, min stddev 7.92 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **knob 1's liveness margin** (0.0109–0.0124 against 0.001) rests on the family's 1 px
  step floor, as in every sibling.
- **knob 4's mid probe reads 0.0000** while its max reads 0.0512 — the mid-state colour
  matches the baseline at this frame; live at max, so a probe artefact.
- **280 `e.rect` calls per frame** from the four-bar outline: fill-rate cost, not
  colour-change cost. The device tier gate is owed and currently blocked.
- **Device tier blocked**: `eyesyctl package` refuses while the engine repo carries
  uncommitted source edits (*"engine_sources hash is stale; rebuild before packaging"*),
  and rebuilding would compile unfinished engine work.