# Port report — `s-radiating-square-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Radiating Square - Uniform Color/main.py` at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 42; sibling of `s-radiating-square-stepped-color` |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

The four sides of a square radiating outward as 100 lines plus a bonus stroke, swept by three
LFOs and displaced by one audio sample.

## The stock-vs-sibling diff (the verified three deltas)

| | stepped | uniform |
| --- | --- | --- |
| width | `int(knob2 * 15) + 1` | `int(knob2 * (xr * 0.012)) + 1` — ~1.5× thicker |
| colour | legacy `color_picker` with a per-element stepped ramp | **`color_picker_lfo(knob4)`** |
| globals | declares and uses `color_rate` | drops it |

Everything else — the three LFOs, the four sides, the `i == 1` bonus line, the `audio/100`
displacement and the knob semantics — is byte-identical.

## The colour: where the picker is called decides everything

Stock calls **`color_picker_lfo(knob4)` once per line**, 100 calls per frame. The runtime's LFO
is **pure in the knob at and below 0.5** (every call in a frame returns the same colour —
genuinely uniform) and **advances a phase per call above 0.5**.

The port collapses it to **one call per frame** with the documented **0.21** offset. That gives:

- **below 0.5, exactly stock's behaviour** — the pure-of-knob branch returns the same colour
  however many times it is called;
- **above 0.5, stock's first line colour** of the per-line sequence, rather than the whole
  sequence.

A mesh draw carries one `e.color`, and 100 per-frame colour changes sit at the measured cliff
(70 changes = +13.7 ms, outside tier C). The 0.21 offset is load-bearing: without it, `knob4 = 0`
samples pure black and reads as a near-dark frame.

## The LFO-range floor

Carried from the sibling: stock's ±`yr/2` sweeps the endpoints **off-screen for most of the
cycle**, so the baseline frame is nearly empty. The **LFO range** is floored to ±40 px — never
the knob — with the `knob1 == 0` / `knob3 == 0` clamps kept stock-exact.

## Rendering

**1 mesh handle**, 101 lines batched as quads: **404 vertices / 606 indices**. Per frame:
1 `e.clear` + 1 `e.color` + 1 `e.update_mesh` + 1 `e.draw_mesh` = **4 calls**, zero per-frame
allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-radiating-square-uniform-color --frames 300` → `"verdict": "pass"`, `failures: []`, `audio_pass: true`. Scene sha256 unchanged across both runs.

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.01671 | 0.01476 |
| 2 | 0.05750 | 0.08516 |
| 3 | 0.01371 | 0.01426 |
| 4 | 0.00730 | **0.00000** |
| 5 | 0.99270 | 0.99270 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.00696, loud 0.00889, freq 0.00771 — pass |
| trigger | not referenced; no trigger-fallback run |
| luma bounds | 28.05–64.9, min stddev 2.95 |
| `p50_ms` (software GL) | 16.66 |

The numbers match the sibling's closely because the two modes share the geometry, the audio
mapping and the LFOs — only the width formula and the colour differ.

## Residual risk

- **Above `knob4 = 0.5` the port reproduces only the first line colour** of stock's per-line
  sequence, not the sequence — a documented consequence of batching, and the same concession the
  stepped sibling makes for a different reason.
- **`knob4`'s max probe is 0 by phase coincidence** (the sampled colours at 0.71 and 0.5 differ
  by few pixels); the knob is live at mid (0.00730), and no trigger path exists.
- **`min stddev 2.95`** is on the thin side (floor 0.51).
- **`knob1` and `knob3` are thin** (0.015–0.017).
- **The ±40 px LFO floor** keeps the square visible where stock's sweep leaves the frame.

## Process note

This task ran with the **local model backend unreachable** (`curl http://tower:11434/api/generate`
connection refused; `ssh tower` permission denied), so the agent ported the verified sibling by
hand — the diff was three confirmed deltas and every other line was checked against the stock
source. Worth knowing if later tasks start failing: the local-model dependency is not always up.