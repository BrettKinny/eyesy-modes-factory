# Port report — `s-amp-color-5gon-filled`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Amp Color - 5gon Filled/main.py` (132 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 23; first mode of the `amp-color` family |
| Verification | `scene_verify.py --frames 300` — **pass**, but **`knob 4` is dead at that length and the verdict rests on the verifier's trigger fallback** — see below |
| Device tier | retired (repo-only) |

## What it does

`count` nested pentagons at the screen centre, each scaled by the family's spacing
formula, rotated by an accumulating angle, and coloured from the running average of
**its own** audio history.

## Family reconnaissance (recorded in ladder §3, "Family: `amp-color`")

- `count` nested shapes at the centre, scaled
  `size = full - (i * (full/count) * (1 + 0.1*(N-count)/N))` with `N = 60` for the 5gons.
- **Per-shape colour** from that shape's own audio-history deque, `maxlen = int(knob1*20)+1`.
- **Per-shape rotation** `current_rotation + i*(knob4*180)`°, where `current_rotation`
  accumulates from knob2 — dead zone `0.49..0.51` resets it to 0, rate
  `|knob2-0.48| * 52` deg/frame at 30 fps.
- **Trigger re-randomises** 5 points in `[-1,1]` (stock's default pentagon otherwise).
- Background `color_picker_bg(knob5)`; the audio index for shape `i` is `audio_in[i]`
  (0-based, **no wrap**); `count = int(knob3*59)+1` (max 60).

## The 32-handle cap binds this mode (documented deviation 6)

Stock draws up to **60** nested polygons, and each needs **its own mesh handle** because
its colour comes from its own audio history — there is nothing to group by. The engine
allows **32 mesh handles per mode**, so the port caps the drawn count at **32**:

- stock-exact for `knob3 ≤ 0.53`;
- above that the port draws 32 polygons where stock draws more.

That is a real fidelity loss, not a rounding detail. The spacing formula keeps stock's
literal `60` denominator, so with the capped count the spacing factor never reaches its
stock maximum.

## Verification — 2026-09-18 (after the knob-4 fix)

`python3 tools/verify_port.py s-amp-color-5gon-filled --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

| Check | Result (300 frames) | 60 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| knob 1 `history` | mid 0.0000, max 0.5590 | 0.75066 |
| knob 2 `spin` | mid 0.2880, max 0.1424 | 0.43583 |
| knob 3 `count` | mid 0.5357, max 0.5372 | 0.70757 |
| **knob 4 `offset`** | **mid 0.0000, max 0.11939** | **0.11938** |
| knob 5 `bg` | mid 0.4410, max 0.4410 | 0.24934 |
| audio | quiet 0.5590, loud 0.5590, freq **0.15505** | 0.75066 / 0.75066 / 0.15504 |
| trigger | True | True |
| luma bounds | mean 34.21–118.55, min stddev 26.38 | 38.66–126.39, stddev 34.11 |
| `p50_ms` (software GL) | 16.6 (resources 32) | 16.64 |

The mode's own 60-frame run before the fix read knob 4 as `0.74932` — which the
diagnosis showed was the **trigger's** number, not the knob's; knob 4 was in fact dead at
both lengths.

## The knob-4 defect and its fix (deviation 9)

Stock's per-polygon rotation offset is `current_rotation + i * (knob4 * 180)` — the
knob's whole excursion is **multiplied by the polygon index**. At the verifier's
all-knobs-zero baseline `knob3 = 0` gives `count = int(0*59)+1 = 1`, so the loop runs only
`i = 0`, the offset term is multiplied by zero, and **knob 4 cannot move a single pixel at
any frame count — in stock too**. Stock-faithful, but it fails the gate, and the gate's
second chance (a MIDI trigger, which re-randomises this mode's geometry) would have banked
a **false liveness** — forbidden by ladder §3.4.

**Fix:** floor the drawn count at **2**, so the offset has a second shape to offset. Look
impact: below `knob3 ≈ 0.017` the mode draws two nested pentagons where stock draws one,
so the all-knobs-zero baseline shows an inner pentagon covering roughly 12 % of the frame;
above that the geometry is stock-exact. The pack's precedent for this treatment is
`s-0-arrival-scope` (a 12 px box-width floor) and `s-circular-trigon-field` (a 12 px
triangle extent). The fix also revived the `audio-freq` probe (0.0000 → 0.15505) and
raised `min stddev` from 20.33 to 26.38.

**This is family-wide**: `s-amp-color-5gon-outlines` showed the identical deadness, and
the same fix is being applied there.

## Residual risk

- **The count floor is the mode's second geometric deviation** (with the 32-handle cap):
  the all-knobs-zero baseline is not stock's single polygon.
- **`audio-quiet` and `audio-loud` are the same value** — the mode responds to the audio
  level but not to frequency in the level probes, which is stock-faithful (it reads
  `audio_in[i]`, a waveform sample, not a spectrum bin).
- **The 32-handle count cap** (above) is the mode's largest deviation from stock.
- **Up to 32 `e.color` calls per frame** — one per polygon, below the 70-call measurement
  that took a mode outside tier C, so within the known budget.