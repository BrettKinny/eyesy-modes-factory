# Port report — `s-amp-color-circles`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Amp Color - Circles/main.py` at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 25; third mode of the `amp-color` family |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, **no trigger fallback** |
| Device tier | retired (repo-only) |

## What it does

`count` nesting levels of **five scattered discs**, all rotating about the screen centre,
each disc coloured from the running average of its own audio history.

## The family is not uniform (the stock diff against `5gon Filled`)

Diffing this source against the stock 5gon-filled source gives **89 insertions, 41
deletions** — the shared skeleton is there, but five things differ, and two of them would
have been wrong if assumed:

| | 5gons | Circles |
| --- | --- | --- |
| audio divisor | 32768 | **22000** |
| `N` in the spacing formula | 60 | **100** |
| count | `int(knob3*59)+1` (60) | `int(knob3*49)+1` (**50**) |
| **knob 4's mechanism** | static `i*(knob4*180)` | **a time-gated triangle-wave LFO** (`lfo_angle` via `calculate_ending_angle`, 7.5° for `count ≤ 8` to 3.0° for `≥ 50`) |
| geometry | one 5-vertex polygon | **five stored circles** `(x, y, radius)`, re-randomised at setup *and* on trigger |

Also: the circles rotate each **centre about the screen centre**, where the 5gons rotate
about the origin and then translate.

Shared and confirmed: the 5-knob roles, the rotation accumulation (dead zone `0.49..0.51`,
rate `|knob2-0.48|*52` deg/frame at 30 fps), the per-shape audio-history
`deque(maxlen=int(knob1*20)+1)` with `color_picker(average)`, the background picker, the
trigger re-randomisation, and the `0.1` spacing factor.

## Zero meshes

`e.circle` draws the discs directly, so this mode needs **no mesh handles at all** —
`resources 0` in the verifier, and the 32-handle cap does not bind it. Per frame: 1
`e.clear`, up to 32 `e.color` (one per nesting level), up to 160 `e.circle` (5 per level),
zero allocation.

The **count floor of 2** (deviation 8) is still needed, because the per-disc angle is
`current_rotation + i * lfo_angle` and at the all-knobs-zero baseline `count = 1` makes
the `i` term identically zero.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-amp-color-circles --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

| Check | 300 frames | 60 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| knob 1 `history` | mid 0.0000, max 0.0230 | 0.0489 |
| knob 2 `spin` | mid 0.3012, max 0.2303 | 0.31218 |
| knob 3 `count` | mid 0.1172, max 0.1198 | 0.21447 |
| **knob 4 `lfo`** | **mid 0.0000, max 0.0069** | mid 0.03023, max 0.00646 |
| knob 5 `bg` | mid 0.8710, max 0.8710 | 0.77151 |
| audio | quiet/loud 0.1290, freq 0.0230 | 0.22849 / 0.22849 / 0.0489 |
| luma bounds | 33.29–64.81, **min stddev 2.3** | 35.15–65.48, stddev 3.05 |
| `p50_ms` (software GL) | 16.7 (resources 0) | 16.666 |

**The trigger fallback did not fire** — it fires only when *both* probe points read dead,
and knob 4's max reads 0.0069 at 300 frames.

## Residual risk

- **knob 4's mid probe reads 0.0000 at 300 frames** while its max reads 0.0069 — so the
  knob clears the gate on one probe point with only ~7× the threshold. This is the
  family's thinnest knob margin and its liveness is genuinely marginal: the mechanism is
  a **time-gated triangle wave**, so at a given instant the offset may be at a turning
  point where it barely moves pixels. A stricter gate, or a different grab instant, could
  lose it.
- **`min stddev 2.3` is the family's lowest** (filled 26.38, outlines 12.27) — five
  scattered discs on a mid-luma background is simply a lower-contrast scene than nested
  filled polygons. It passes the flatness floor with margin, but it is the closest of the
  family to it.
- **`audio-quiet` equals `audio-loud`** (0.1290) — stock-faithful: the family reads a
  waveform sample (`audio_in[i]`), not a spectrum bin, so the level probes read
  identically and the `freq` probe (0.0230) carries the reactivity.
- **The count floor (2)** means the all-knobs-zero baseline is not stock's single level.
- **The 50 → 32 count cap does not apply here** (no meshes), but the drawn level count is
  still floored at 2 by the deviation above.