# Port report — `s-mirror-grid-inverse`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Mirror Grid - Inverse/main.py` (85 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 35; sibling of `s-mirror-grid` |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) — **but see the colour-change count below** |

## What it does

The inverse of its sibling: 72 horizontal lines with mirrored bars, plus up to 144 squares,
coloured by stock's per-element picker progression.

## The stock-vs-sibling diff (checked, not assumed)

| | `mirror-grid` | `mirror-grid-inverse` |
| --- | --- | --- |
| line count | fixed 72 | `int(39*knob2+1) + 4` (72 at default) — **the knob drives it** |
| spacing | `179.968*k2 + 18` | `int(xr/(lines-2)) = 17.6` horizontal, `int(yr/(lines-2)) = 17.3` vertical |
| `ten` (size unit) | `ZEHEN = 17.92` | `int(xr*0.0078125) = 10` |
| `recsize` | `int(ZEHEN*knob3)` | `int(ten*knob3) * 2` — **doubled** |
| audio clamps | `max(0,·)` top / `min(0,·)` bottom | **none** — both bars are unbounded, so negative samples push bars past the middle and positive ones pull the bottom bar above it |
| flat-frame risk | needed a 0.55-alpha deviation | **none** — see below |

The audio scaling is otherwise the same literal: `0.00003058 * yr` over `j = 0..71`, with the
bottom ring offset at `int(i + lines*0.5)` (36 at the default). The port keeps the `*32768`
denormalization over `left[1 + j*10]` and `left[1 + (i+36)*10]`; the largest index
(1071) stays inside the 1024-sample buffer's stride space, so no Python negative-index wrap is
needed.

**No flat-frame deviation was required.** The sibling's 72 opaque bands tile the frame at
`knob1`-max (`stddev 0.0`); here the lines are 10 px thick on a ~17.6 px pitch, so they never
tile and the grab keeps natural variance (`min stddev 4.81`). All foreground is therefore drawn
**opaque and stock-exact** — the sibling's deviation 7 does not carry over, and assuming it did
would have been a needless look change.

## Colour

Identical per-element structure to the sibling: the legacy picker is called **216× per frame**
(72 horizontal lines + 72 top bars + 72 bottom bars), `sel = knob4*2`, `sel < 1` →
`picker(knob4*2)`, `sel ≥ 1` → `color_rate = (color_rate + (sel-1)*0.1) % 1`. **No 0.21 LFO
offset** — the phase advances per element, so the documented one-call-per-frame offset does not
apply; stock's progression is kept verbatim with only the deterministic middle branch
substituted.

Stock's `random` import is unused, so no `e.random()`.

## Rendering

**216 `e.rect` per frame** (plus up to 144 squares when `recsize ≥ 1`, drawn only when their
rect intersects the frame, with the bottom square additionally gated by stock's `auDio < 0`
guard). **0 mesh handles**, zero per-frame allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-mirror-grid-inverse --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.03032 | 0.05905 |
| 2 | 0.04485 | 0.09435 |
| 3 | 0.00052 | **0.00200** |
| 4 | **0.00000** | 0.00586 |
| 5 | 0.99414 | 0.99414 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet **0.00063**, loud **0.00103**, freq **0.00115** (threshold 0.001) |
| trigger | not referenced |
| luma bounds | mean 28.51–64.37, min stddev 4.81 |
| `p50_ms` (software GL) | 16.66 |

## Residual risk

- **`audio-quiet` reads 0.00063 — BELOW the 0.001 threshold**, with `audio-loud` (0.00103) and
  `audio-freq` (0.00115) barely above it. The thinnest audio profile in the pack: all three
  probes are within ~1.8× of the threshold or under it. Structural — one fixed sample per
  element, no clamping, so audio motion is small.
- **`knob3`'s max probe is 0.00200** — about 2× the threshold, the pack's thinnest knob margin
  alongside `s-googly-eyes`' 0.00215. The size knob changes little at a single grab instant.
- **`knob4`'s mid probe is exactly 0 by design** (as in the sibling): `sel = 1.0` at mid lands on
  the branch with `(sel-1)*0.1 = 0` advance, so the colour matches the baseline. Stock-exact;
  liveness from the max probe. No trigger fallback exists, so no false liveness is possible.
- **~216 per-element colour changes per frame, with no possible grouping** — the pack's measured
  cost driver, and the same risk the sibling carries.