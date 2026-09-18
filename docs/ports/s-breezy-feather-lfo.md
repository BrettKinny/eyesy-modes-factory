# Port report — `s-breezy-feather-lfo`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Breezy Feather LFO/main.py` (~60 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 7; implemented by `local-agent`, **1 iteration, 0 model iterations** |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A bouncing y position sweeps a horizontal baseline across the frame, and a bouncing
count of filled triangles (2..72) hangs from it, each triangle's apex displaced by
one audio sample. Two stateful `LFO` objects drive the bounce; `knob1` sets the
triangle-count rate, `knob2` the feather angle, `knob3` the y bounce speed.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` triangle-count rate | `e.param("rate", 0.5, 0, 1, 1)` → `floor(knob1*15.36)` as the `tris` step |
| `knob2` feather angle | `e.param("feather", 0.5, 0, 1, 2)` → `offset = floor((knob2*2-1)*space*4)` |
| `knob3` y bounce speed | `e.param("bounce", 0.5, 0, 1, 3)` → `floor(knob3*72)` as the `yposr` step |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO once per frame, phase offset 0.21 |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `class LFO` ×2 | file-local `current`/`direction` with stock's clamp-on-cross logic |
| `audio_in[i]/65` | `trunc(left[1 + i*10] * 32768 / 65)` |
| `gfxdraw.filled_trigon` ×72 | **one preallocated mesh** (216 vertices / 216 indices) |

## Deviations (in the mode header)

1. **Both stateful LFOs re-timed** — stock adds `step` once per frame at 30 fps; the
   port advances by `step * 30 * ctx.dt` (the `int()` truncation stays on the knob
   mapping, so the LFO's own arithmetic is float).
2. **Deterministic middle-branch palette**; **LFO phase offset 0.21**
   (`tools/lfo_offset.py --inc 0.1 --calls 1`) with the phase advanced
   `30 * inc * ctx.dt` per frame.
3. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
4. **Audio stride** — stock index `i` → `left[1 + i*10]`, denormalized by 32768.
5. **Triangles via one preallocated mesh** (all share one colour), mutated in place
   per frame — `resources 1` in the verifier's report, and one draw call.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-breezy-feather-lfo --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `rate` | mid 0.0787, max 0.0797 |
| knob 2 `feather` | mid 0.0430, max 0.0535 |
| knob 3 `bounce` | mid 0.1224, max 0.1224 |
| knob 4 `fg` | mid 0.0000, max 0.0421 |
| knob 5 `bg` | mid 0.9579, max 0.9579 |
| audio | quiet 0.0385, loud 0.0679, freq 0.0707 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.43–66.65, min stddev 6.53 |
| `p50_ms` (software GL) | 16.7 (resources 1) |

## Residual risk

- **`knob3`'s mid and max probes are identical** (0.1224): the bounce clamps at its
  start/max, so both probe points land in the same part of the cycle. The knob is
  live against the baseline.
- **`knob4`'s mid probe is 0.0000** (max 0.0421) — the usual static-branch pattern.
- The triangles' count changes with the LFO over time, so the mesh is rewritten with
  a variable number of triples each frame; the index table covers the maximum (72)
  and the extra triples are simply not referenced. Device tier owed.