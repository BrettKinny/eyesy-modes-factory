# Port report — `t-bits-h-row-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Bits H - Row Color/main.py` (56 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 4; first of the four-mode `T - Bits` family |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

Rows of horizontal bars whose length and shadow come from two knobs, each row coloured
separately.

## Stock reads no audio — in any of the four family modes

**None of the four `T - Bits *` sources reference audio at all** (no `audio_in`, no `eyesy.audio`
in any of them). So `audio_pass` is `null` for stock, and the pack's convention applies: the port
**adds one documented audio term** (deviation 7). The term is the normalised sample scaled into
pixels — `|left[1 + row*10]| * 0.25 * ctx.width`, at most a quarter of the width — with
out-of-range indices nil-guarded.

That makes **three P3 modes in four** whose stock source never touches audio, which confirms the
pattern: the `T -` tranche is the smaller, older stock scenes, and the gate's reactivity
requirement is a constraint the originals were never written against.

## Two degenerate floors were required

1. **The row count** (`lineAmt` floored at 8; stock's minimum is 2). At `lineAmt = 2` stock's
   linewidth is `int(yr/2)` = 360 px and it lays out `lineAmt + 2` = 4 rows at `y = k*360 + 179`,
   so only two land on a 720-px screen — and with their x drawn from stock's
   `randrange(-0.156*xr, xr)`, the whole figure lands off-screen at the verifier's fixed seed. The
   baseline grab was **a single flat colour** (verified: 1 colour, stddev 0.0).
2. **The bar length** (`int(knob2*xr*0.234)+1` floored at `int(xr*0.02)` ≈ 25 px). Stock collapses
   to 1 px at `knob2 = 0`, so every colour and shadow knob had nothing to colour.

Look impact documented in the header: below `knob1 ≈ 0.06` the rows are more numerous and thinner;
below `knob2 ≈ 0.082` the bars are ~25 px.

## Colour

- **Foreground**: `color_picker_lfo(knob4, inc_amt = 0.15)` — this mode passes **0.15 explicitly**,
  and it is called **once per row** inside the foreground loop. The legacy picker is partly
  random, so the deterministic middle branch substitutes (deviation 1).
- **`knob4 = 0.5` is a genuine no-op**: `(knob4*2) % 1 = 0` → `picker(0)` = grey, the same colour
  as the all-zero baseline, so its mid probe reads 0.0 by construction. Live at max (0.03977).
- **Background**: stock's cosine formula exactly, phase folded to `c = (knob5*0.7+0.15) % 1`.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-bits-h-row-color --frames 300` → `"verdict": "pass"`, `failures: []`. Numbers identical in both runs.

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.16410 | 0.18468 |
| 2 | 0.09236 | 0.20890 |
| 3 | 0.00598 | 0.00598 |
| 4 | **0.00000** | 0.03977 |
| 5 | 0.96023 | 0.96023 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.03411, loud 0.14737, freq 0.03798 — **pass** |
| trigger | `trigger_pass: true` — but **every knob is live at ≥1 probe point on its own**, so no false liveness is involved |
| luma bounds | 29.03–66.31, min stddev 10.39 |
| `p50_ms` (software GL) | 16.61 / 16.62 |

## Residual risk

- **The audio term is an addition to stock** — the mode's reactivity is the port's design.
- **Two degenerate floors** mean the all-knobs-zero baseline is materially more legible than
  stock's, which draws a single flat colour there.
- **`knob3`'s margin is thin** (0.00598, about 6× the threshold) — the shadow recolour moves few
  pixels.
- **`knob4`'s mid probe is a no-op by construction** (stock-faithful), so its liveness rests on the
  max probe alone.