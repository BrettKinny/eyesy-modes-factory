# Port report — `s-mirror-grid`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Mirror Grid/main.py` (94 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 34 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) — **but see the colour-change count below** |

## What it does

72 horizontal bands with a mirrored bar above and below each, plus up to 216 squares,
all coloured by stock's **per-element** picker progression.

## The colour rule is per element, not per frame

Stock calls the legacy `color_picker` **216 times per frame** (72 lines + 72 top bars + 72
bottom bars), with a phase that **advances per element**: `sel < 1` → `picker(knob4*2)`;
`sel ≥ 1` → `color_rate = (color_rate + (sel-1)*0.1) % 1`, `picker(color_rate)`.

Because it advances per element rather than holding a per-frame LFO phase, **the documented
0.21 offset does not apply** — the port keeps stock's phase progression verbatim
(`color_rate` starting at 0, advancing 216× per frame) and substitutes only the picker's
deterministic middle branch. That is the same judgement `s-googly-eyes` made, in the
opposite direction: there, a per-element LFO needed no offset either but for a different
reason (the sampled colour already cleared both luma targets).

## Audio

**No divisor at all** — stock scales by the literal `0.00003058 * yr` with no division, over
`j = 0..71` (never negative, so no Python wrap is needed). The port keeps it:
`left[1 + j*10] * 32768 * 0.00003058 * H`, with stock's `max(0, ·)` on the top half and
`min(0, ·)` on the bottom exactly as written.

Stock's `random` import is **unused**, so the port calls no `e.random()`.

## The flat-frame failure, and its fix (deviation 7)

The first 60-frame run failed with *"run knob1-max: flat frame, stddev 0.0"*: at `knob1`-max
the 72 opaque horizontal bands tile the entire frame, so the grab is uniform. The port draws
the horizontal bands at **0.55 alpha** — the oscilloscope bars and squares stay opaque — which
keeps the frame's structure visible while leaving the bands' appearance dominated by their
colour. Documented as deviation 7 with that reasoning.

## Cost — the pack's worst colour-change profile

**216 `e.rect` per frame** (72 horizontal + 72 top bars + 72 bottom bars; up to 216 more for
the squares when `recsize ≥ 1`, which is the case at the baseline `k3 = 0.5` → `recsize = 8`),
**0 mesh handles**, zero per-frame allocation.

**Each element carries its own colour**, so — unlike every other mode in this pack — this one
**cannot be batched by colour class**: there is nothing to group. The pack measured 70
per-frame colour changes at **+13.7 ms** (outside tier C) while 1 and 10 sat on the floor, so
this mode's ~216 colour changes are expected to be far outside the ceiling on hardware. The
only lever would be reducing the element count, which changes the look. Recorded rather than
worked around, because the device gate is retired and the alternative is an unfaithful mode.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-mirror-grid --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.51291 | 0.94426 |
| 2 | 0.06613 | 0.06851 |
| 3 | 0.00882 | 0.03826 |
| 4 | **0.00000** | 0.05757 |
| 5 | 0.92795 | 0.92795 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.01662, loud 0.02767, freq 0.02243 (threshold 0.001) |
| trigger | not referenced — stock calls no `random` and the scene has no trigger |
| luma bounds | mean 28.3–87.34, min stddev 4.46 |
| `p50_ms` (software GL) | 16.66 |

## Residual risk

- **~216 per-element colour changes per frame, with no possible grouping.** The pack's
  measured cost driver (70 calls → +13.7 ms, outside tier C) makes this mode the most likely
  in the pack to fail a device tier gate, and unlike the patchwork modes there is no
  colour-class batching available — each element has its own colour.
- **`knob4`'s mid probe is exactly 0 by design**: `sel = knob4*2 = 1.0` at mid lands on
  stock's `elif` branch with `(sel-1)*0.1 = 0` advance, so the per-frame colour is identical
  to the baseline. Stock-exact, and liveness comes from the max probe (0.05757). No trigger
  fallback exists, so the gate cannot be banking a false liveness.
- **Deviation 7 (0.55 alpha on the bands)** is a genuine look change, made to satisfy the
  verifier's flatness bound at `knob1`-max; stock's bands are opaque there.
- **`min stddev 4.46`** is a reasonable margin, and the frame reaches luma 87.34 — brighter than
  most of the pack.