# Port report — `s-line-bounce-two-lfo-alternate`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Line Bounce Two - LFO Alternate/main.py` (80 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 33; sibling of `s-line-bounce-four-lfo-alternate` |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

Two strokes bouncing vertically together while a single audio sample sets their vertical
extent: the first segment (colour at `k4`) spans `rise - y` to `rise + y`, the second
(colour at `k4 + 0.5`) spans `rise - 2y` to `rise + 2y` at **double width**. When `b1`
reaches either end of its range, stock's coin flip reorders which segment is painted last
— and since both share the same vertical centre, the last one wins the overlapping pixels.

## The rate bug it found in its own sibling

This port's brief said to check each constant against the source rather than assume it
carries over, and doing that surfaced **a real defect in the four-line sibling**: it
advanced its LFOs by `2 * dt` where the correct factor is `30 * dt` — `2·step` px/s against
stock's `30·step`, i.e. **15× too slow**. The tell was in the sibling's own recorded
numbers: its *speed* knob had both probe points reading a near-identical 0.01376, which is
what a too-slow rate looks like. Fix dispatched; this mode uses `step * 30 * dt`.

## What differs from the sibling (checked, not assumed)

| | four-line | two-line |
| --- | --- | --- |
| audio divisor | 85 | **150** |
| `abs()` on the audio | yes | **none** — stock has none, so a negative sample mirrors the strokes about `rise` |
| picker calls | four at `k4`, +0.25, +0.5, +0.75 | **two** at `k4`, `k4 + 0.5` |
| LFO steps | `int()`-wrapped | **plain floats** — stock wraps only `width` in `int()` |
| coin flip | reorders the x/y line groups | reorders **which of the two overlapping segments is painted last** |

Both read `audio_in[50]`; the divisor differs between them, and this mode's source says 150.

## Deviations

1. **Legacy picker → deterministic middle branch** (static per knob value; `color_picker_lfo`
   is never called, so no phase offset applies).
2. **Background phase folded** to `c = (k5*0.7+0.15)%1`.
3. **Audio**: stock index 50 → `left[1 + 50*10]` × 32768, **divisor 150 kept exactly**, and
   stock's absent `abs()` kept — a negative sample mirrors the strokes about `rise`.
4. **Stock's coin flip made deterministic**: a fresh `random.random() < 0.5` on every `b1`
   arrival becomes a per-arrival toggle, so replays stay byte-identical.
5. **30 → 60 fps**: `step * 30 * dt` per frame — the correct factor, and the one its sibling
   got wrong.
6. **Line widths**: pygame treats a width ≤ 0 as 1 px and `e.line` takes it literally; stock's
   `int() + 1` already floors at 1, so the widths are stock-exact as written.
7. **`knob1` legibility floor** (6 px) for the vertical stroke, matching the sibling's deviation 7.

## Rendering

**Zero meshes, zero render targets** — a handful of screen-space strokes, so there is no
target-coordinate trap to fall into. Zero per-frame allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-line-bounce-two-lfo-alternate --frames 300` → `"verdict": "pass"`, `failures: []`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `bounce` | mid 0.0097, max 0.0066 |
| knob 2 `width` | mid 0.0295, max 0.0630 |
| knob 3 `speed` | mid 0.0079, max 0.0099 |
| knob 4 `fg` | mid 0.0049, max 0.0000 |
| knob 5 `bg` | mid 0.9951, max 0.9951 |
| audio | quiet 0.0046, loud 0.0065, freq **0.0009** (threshold 0.001) |
| trigger | not referenced |
| luma bounds | mean 28.02–64.19, **min stddev 1.2** |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`audio-freq` reads 0.0009 — BELOW the 0.001 threshold.** The set passes on the level
  probes (quiet 0.0046, loud 0.0065), but the frequency probe is structurally dead here: the
  mode reads **one fixed sample** (`audio_in[50]`) for its whole deflection, so a spectral
  change moves almost nothing. The pack's weakest audio probe.
- **`min stddev 1.2` is the pack's lowest luma margin** (previously 2.32 at
  `s-horizontal-trails`). Two thin strokes over a flat background is a low-contrast scene; it
  passes the flatness floor but with the least room of any port.
- **`knob4`'s max probe is exactly 0**: at `k4 = 1.0` the two static picker phases fold onto
  the same colours as `k4 = 0`, so the frame is byte-identical to the baseline — stock-faithful.
  Liveness rests on the 0.5 probe (0.0049).
- **knob 1 and knob 3 are thin** (0.0066–0.0099): the bounce-amplitude and speed knobs move few
  pixels at a single grab instant.