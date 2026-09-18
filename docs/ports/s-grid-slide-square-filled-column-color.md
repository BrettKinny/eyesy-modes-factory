# Port report — `s-grid-slide-square-filled-column-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Slide Square - Filled Column Color/main.py` (79 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 18; third mode of the `grid-slide-square` family |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier | **24.18 ms** (+0.0 over a 24.18/24.19 ms floor) — **pass**, 2026-09-18 |

## What it does

The family's filled, per-column-coloured variant: a 7×10 grid of filled squares slid by
the shared `sqmover` oscillator and inflated by one audio sample, with each column
drawn in its own colour.

## The colour rule (read from the source, not assumed)

```python
color = eyesy.color_picker(((j*.1) + eyesy.knob4) % 1.0)   # inside the j loop
```

Two things this corrects relative to the family's other variants:

- It is the **static legacy `color_picker`**, *not* `color_picker_lfo` — no time-based
  state, so **no phase offset applies** (the pack's 0.21 is for one LFO call per frame
  and would have been wrong here twice over).
- It is called **once per column** (10 calls per frame), and all seven rows of a column
  share the colour.

Where a port *does* call the LFO once per element, the offset must be derived for its own
call count: `tools/lfo_offset.py --calls <n>`. For 10 calls per frame the agent derived
**0.45** by grid search, maximising the worst-case luma clearance across the verifier's
frame counts (60/130/300/600) *and* all ten columns against both targets (palette grey
127.5, background 28.33) — ≈5.7 luma units clearance, with the ten column colours
spanning lumas ~34–221.

## Mapping

The verified `s-grid-slide-square-filled-uniform-color` sibling copied verbatim — the
7×10 grid, the **14-advances-per-frame** `sqmover` (two `update()` calls per row, each
re-timed `step*30*dt`, with both stock clamps), the audio stride with Python's
negative-index wrap, the centred-rect conversion, the bg phase fold, and deviations 8
and 9 (the 1 px step floor and 1 px range fallback for the mutually dependent knobs).
Only the colour block changed.

70 `e.rect` calls per frame, no mesh (`resources 0`), zero allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-slide-square-filled-column-color --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `step` | mid 0.0046, max 0.0049 |
| knob 2 `pos` | mid 0.2326, max 0.2984 |
| knob 3 `size` | mid 0.2971, max 0.5347 |
| knob 4 `fg` | mid 0.0000, max 0.4985 |
| knob 5 `bg` | mid 0.5015, max 0.5015 |
| audio | quiet 0.4968, loud 0.8543, freq 0.3990 (threshold 0.001) |
| trigger | `None` — the scene does not reference `ctx.trigger` |
| luma bounds | mean 28.16–122.19, min stddev 4.61 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **knob 1's liveness margin is thin** (0.0046–0.0049 against the 0.001 threshold), the
  same 1 px-floor dependency as its uniform sibling.
- **knob 4's mid probe reads 0.0000** while its max reads 0.4985: at `knob4 = 0.5` the
  per-column phases land on colours that render identically to the baseline at this
  frame. The knob is plainly live at its max, so this is a probe artefact — but it is the
  mode's least robust probe.
- **Worst-case luma clearance is ≈5.7 units** at 10 calls per frame: the within-frame
  spread across columns is what keeps knob 4 live, so a different grab instant or a
  stricter brightness floor could be more sensitive.
- **Stock's rect geometry is unchanged** — squares leave the frame at full audio, as in
  stock (the family's deviation 7).