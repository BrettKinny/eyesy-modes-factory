# Port report — `s-radiating-square-stepped-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Radiating Square - Stepped Color/main.py` (97 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 41 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

The four sides of a square radiating outward as 100 lines (plus a bonus stroke at `i == 1`),
their endpoints swept by three LFOs and displaced by one audio sample.

## A different degenerate input, the same class of fix

**This mode has no `R1` radius formula** — the brief warned not to assume the sibling's shape
carried over, and it didn't. Its degenerate input is the **`sqmover` LFO range**: stock's
±`yr/2` (±540 px at 1920, ±360 px at 1280×720) sweeps the endpoints **off-screen for most of the
cycle**, so the baseline frame is nearly empty and the mode reads flat.

The fix is the same *class* as the radial scopes — floor the degenerate input, never the knob —
applied to the **LFO range** at ±40 px (matching the sibling's `R1` floor). `knob1 == 0` and
`knob3 == 0` clamp stock-exact, so the all-knobs-zero baseline stays static as in stock while the
verifier's non-zero probes see a legible square.

That is the third distinct form of this deviation in the pack (a count multiplied by zero, a
radius divided by `(R1+1)`, and now an LFO range that leaves the frame) — worth noting that the
*class* generalises further than any single formula.

## Audio and colour

- **Divisor 100**: `abs(audio_in[i] / 100)`.
- The picker is the **legacy `color_picker((i * (1/(100*(knob4+0.001)))) % 1)`**, called
  **100× per frame** — a per-element stepped ramp, and **not** `color_picker_lfo` (which is what
  the Uniform sibling uses). One more entry in this library's long tail of colour mechanisms.
- **The 100-step ramp is batched to one colour per frame**, `picker((knob4 + 0.21) % 1)`: the
  faithful version is 100 per-frame colour changes, past the pack's measured 70-change cliff
  (+13.7 ms, outside tier C). The 0.21 offset is load-bearing now that the picker is called once
  per frame — `picker(0)` would be pure black and read as a near-dark frame. **Fidelity loss: the
  stepped rainbow itself**, and `knob4`'s "step width" semantics collapse to a phase offset.

## Rendering

**1 mesh handle**, 101 strokes (100 lines + the `i == 1` bonus) batched as quads: **404 vertices /
606 indices**, far inside the caps. Per frame: 1 `e.clear` + 1 `e.color` + 1 `e.update_mesh` +
1 `e.draw_mesh` = **4 calls**, zero per-frame allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-radiating-square-stepped-color --frames 300` → `"verdict": "pass"`, `failures: []`, `audio_pass: true`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.01698 | 0.01690 |
| 2 | 0.04217 | 0.07330 |
| 3 | 0.01483 | 0.01474 |
| 4 | 0.00730 | **0.00000** |
| 5 | 0.99270 | 0.99270 |

| Check | 300 frames | 60 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| audio | quiet 0.00696, loud 0.00889, freq 0.00771 — **pass** | identical |
| trigger | not referenced; no trigger-fallback run in the set | — |
| luma bounds | 28.05–64.9, min stddev 2.95 | identical |
| `p50_ms` (software GL) | 16.66 | 16.68 |

## Residual risk

- **The stepped rainbow is gone** (batched to one colour), and `knob4`'s step-width semantics
  collapse to a phase offset — the same deliberate concession as the radial-scope sibling.
- **`knob4`'s max probe is 0 by phase coincidence**: `picker((0.5+0.21)%1)` at mid and
  `picker(0.71)` at max differ only in the mid probe. The knob is live at mid (0.00730), and no
  trigger path exists, so no false liveness.
- **`min stddev 2.95`** is on the thin side (the flatness floor is 0.51) — thin lines on a dark
  background.
- **`knob1` and `knob3` are thin** (0.017 / 0.015): the LFO-speed and line-count knobs move few
  pixels at a single grab instant.
- **The ±40 px LFO floor** means the square is smaller than stock's sweep would put it for most
  of the cycle — stock's endpoints leave the frame; the port keeps them visible.