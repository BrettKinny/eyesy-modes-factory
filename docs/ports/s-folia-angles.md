# Port report — `s-folia-angles`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Folia Angles/main.py` (202 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 12; implemented by `local-agent`, 2 iterations; structure scouted read-only first |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A 9×7 grid of 63 boxes. Each box carries a smoothed audio offset and its own
rotation angle; `knob1` selects one of seven shape families (open polylines of 1–4
segments per box), `knob2` scales the rotation, `knob3` the trail veil, `knob4`/`5`
the colours. A per-frame full-screen alpha veil toward the background colour is what
produces the trails.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` shape | `e.param("shape", 0.5, 0, 1, 1)` → seven branches, point expressions verbatim |
| `knob2` spin | `e.param("spin", 0.5, 0, 1, 2)` → `speed = (a1/yr) * knob2 * 400` per frame |
| `knob3` trail | `e.param("trail", 0.5, 0, 1, 3)` → veil alpha `knob3*45/255` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_picker_lfo(fg, 0.05)`, once per frame |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| 63-entry history + `rotation_angles` | preallocated tables mutated in place |
| `audio_in[index]*yr/32768` | `left[1 + index*10] * 720` |
| `pygame.draw.aalines` ×1–4 per box | open width-1 `e.mesh` line strips |

## Deviations (in the mode header)

1. **The veil bridged as a ping-pong render target** (ladder §3.2): the scene is
   rendered into a target, faded each frame by a full-screen `e.rect` in the
   background colour with alpha `knob3*45/255`, then blitted to the screen. The blit
   is not ported literally; the trail's look is the requirement.
2. **The never-reset `rotation_angles` accumulator is kept** (63 entries, carried
   across frames, clamped ±180°, reset only when `knob2 == 1` exactly as stock does)
   with its per-frame increment re-timed by `30 * ctx.dt`.
3. **The per-box audio history is a preallocated ring** (10 entries) mutated in
   place, so `draw` allocates nothing.
4. **Anti-aliasing dropped** — `pygame.draw.aalines` is AA and the API's lines are
   not; width stays 1 and polylines stay open.
5. **Deterministic palette**; **LFO phase offset 0.21** for the mode's own
   `inc_amt = 0.05` (`tools/lfo_offset.py --inc 0.1 --calls 1`), phase advanced
   `30 * inc * ctx.dt` per frame.
6. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
7. **Audio stride** — stock index `index` → `left[1 + index*10]`, denormalized.
8. **1-based state, 0-based stock index** — the stock box index is `row*9 + col`
   (0..62), so the state tables are indexed at `index + 1` while the audio mapping
   keeps `left[1 + index*10]`. This was the one failure of the first iteration (a nil
   arithmetic error).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-folia-angles --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `shape` | mid 0.0690, max 0.0793 |
| knob 2 `spin` | mid 0.0519, max 0.0333 |
| knob 3 `trail` | mid 1.0000, max 1.0000 |
| knob 4 `fg` | mid 0.0000, max 0.0115 |
| knob 5 `bg` | mid 0.9709, max 0.9709 |
| audio | quiet 0.0226, loud 0.0650, freq 0.0717 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | **mean 4.12–26.1**, min stddev 1.61 |
| `p50_ms` (software GL) | 16.7 (resources 6) |

## Residual risk

- **The frame is very dark** (mean luma as low as 4.12 of 255): the veil fades
  everything toward a near-black background at the baseline, so the mode sits close
  to the verifier's "blank" bound (0.0255). It passes, but a gate with a stricter
  brightness floor — or a device with a different gamma — would need the trail
  colour lifted.
- **`knob3`'s probes read 1.0000** (the whole frame changes): the veil and the clear
  both key off the trail knob, so its states are maximally different from the
  baseline. Correct, but it means the knob's *subtle* range is not exercised.
- **The persistence bridge is new machinery for this pack** — two render targets,
  an alpha fade and a blit per frame. Device tier owed; `resources 6` is the highest
  count in the pack so far.
- **`s-folia-curves` is its sibling** (sampled beziers instead of polylines, a
  7-frame history window) and should land as a copy.