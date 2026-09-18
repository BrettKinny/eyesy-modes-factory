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

## Verification — 2026-09-18

`python3 tools/verify_port.py s-amp-color-5gon-filled --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

| Check | Result (300 frames) | (60 frames, implementing agent) |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| knob 1 `history` | mid 0.0000, max 0.5590 | 0.75066 |
| knob 2 `spin` | mid 0.2880, max 0.1424 | 0.32289 |
| knob 3 `count` | mid 0.5357, max 0.5372 | 0.70757 |
| **knob 4 `offset`** | **mid 0.0000, max 0.0000** | **0.74932** |
| knob 5 `bg` | mid 0.4410, max 0.4410 | 0.24934 |
| audio | quiet 0.5590, loud 0.5590, freq 0.0000 | 0.75066 / 0.75066 / 0.0000 |
| trigger | **True** | True |
| luma bounds | mean 32.57–120.72, min stddev 23.17 | 37.02–128.56, stddev 20.33 |
| `p50_ms` (software GL) | 16.6 (resources 32) | 16.66 |

## Residual risk

- **`knob 4` is dead at 300 frames and the pass is a false liveness.** Both of its probe
  points read `0.0000`, and the verdict survives only because the verifier's second
  chance fires a MIDI trigger (`trigger_pass: True`) and this mode re-randomises its
  polygon geometry on a trigger. The ladder states the rule explicitly: *"a mode whose
  trigger re-randomises geometry can then 'pass' on the trigger's effect rather than the
  knob's. That is a false liveness — fix the knob's own visibility instead of relying on
  it."* **Fix queued.** Note the knob is live at 60 frames (0.74932), so the failure is
  frame-count dependent — the accumulated rotation or the audio history reaches a state
  where the per-shape offset no longer changes pixels.
- **`audio-freq` reads 0.0000** at both lengths, and `audio-quiet`/`audio-loud` are the
  *same* value (0.5590) — the mode responds to the audio level but not to frequency,
  which is stock-faithful (it reads `audio_in[i]`, a waveform sample, not a spectrum
  bin), but it means the frequency probe is structurally inapplicable here.
- **The 32-handle count cap** (above) is the mode's largest deviation from stock.
- **Up to 32 `e.color` calls per frame** — one per polygon, below the 70-call measurement
  that took a mode outside tier C, so within the known budget.