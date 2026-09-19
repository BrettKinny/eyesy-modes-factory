# Port report — `t-bits-v-column-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Bits V - Column Color/main.py` (56 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 6; third of the four-mode `T - Bits` family, first V variant |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) — **but see the colour-change count below** |

## What it does

Columns of vertical bars whose length and shadow come from two knobs, each column coloured
separately.

## The V-vs-H differences (checked against the source, not assumed)

| | H | V |
| --- | --- | --- |
| bar orientation | horizontal, fixed y per row | **vertical**, fixed x per column |
| count formula | `knob1*yr*0.139 + 2` | `knob1*xr*0.078 + 2` |
| length formula | `knob2*xr*0.234 + 1` | `knob2*yr*0.417 + 1` |
| thickness | `yr / lineAmt` | `int((xr + 65) / lineAmt)` — **stock's span is WIDTH + 65, not the height** |
| displace | `xr*0.008` | `yr*0.014` |
| picker `inc_amt` | 0.15 (the default) | **0.1, passed explicitly** |
| random placement | x from `randrange(-0.156*xr, xr)` | y from `randrange(int(-yr*0.278), yr)` — up to 28 % of the height **above** the screen |

**Stock's own framing overflows**: at maximum count the last columns sit at x = 1427/1595 on a
1280-px frame, partly off the right edge, and the random y already runs off the top. Kept
stock-exact — the frame is never blank, so no wrap or scale is applied.

## Colour

`color_picker_lfo(knob4, 0.1)` is called **inside the foreground loop** — once per column — so
this is a Column variant and needs **one `e.color` per element per frame** (up to 104 foreground
colour changes), matching the H Row sibling's structure rather than the Uniform one. The
**0.21 phase offset was re-derived for `inc_amt = 0.1`** with `tools/lfo_offset.py` (worst-case
luma clearance 38.85) rather than copied from the 0.15 siblings — the offset depends on the step.

`knob4 = 0.5` is again a genuine no-op (`picker(0)` = grey = the baseline colour), confirmed by
the grab stats: `knob4-mid` is **exactly** the baseline frame (mean 31.61, stddev 18.93).

## The rest, carried from the verified siblings

Stock reads **no audio** in any of the four `T - Bits` modes, so the port adds the pack's one
documented audio term (column `k`'s bar length extended by `|left[1 + k*10]| * 0.25 * ctx.width`,
nil-guarded). The two degenerate floors carry over (count floored at 8, length floored at
~`int(xr*0.02)`), as does the deterministic middle branch, the background phase fold and the
30 → 60 fps re-timing.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-bits-v-column-color --frames 300` → `"verdict": "pass"`, `failures: []`. Per-probe table **identical at 60 and 300 frames** (to 2e-5 on one value).

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.18713 | 0.22790 |
| 2 | 0.15841 | 0.35387 |
| 3 | 0.00849 | 0.00849 |
| 4 | **0.00000** | 0.03771 |
| 5 | 0.96229 | 0.96229 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.03982, loud 0.23179, freq 0.05610 — **pass** |
| trigger | `trigger_pass: true` — every knob is live on its own, so no false liveness |
| luma bounds | 28.54–66.10, min stddev 7.71 |
| `p50_ms` (software GL) | 16.64 / 16.67 (0 meshes) |

## Residual risk

- **Up to 104 foreground colour changes per frame** — above the pack's measured cliff (70
  changes = +13.7 ms, outside tier C). Unlike the patchwork modes there is no colour class to
  batch by: every column carries its own colour. This is a **predicted** device cost with no
  measurement available (the tier gate is retired), and the faithful alternative is one draw per
  column.
- **The audio term is an addition to stock** — the mode's reactivity is the port's design.
- **Two degenerate floors** mean the baseline is more legible than stock's.
- **Stock's own geometry overflows the frame** at high counts and at the top of the y range;
  kept stock-exact.
- **`knob3`'s margin is thin** (0.00849) — the shadow recolour moves few pixels.