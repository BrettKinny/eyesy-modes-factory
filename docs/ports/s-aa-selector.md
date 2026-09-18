# Port report — `s-aa-selector`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - AA Selector/main.py` (151 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 2; implemented by `local-agent`, 2 iterations; structure scouted read-only first |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The pack's largest mode: per frame it averages the 100 audio samples, then for each
of `floor(knob1*9)+1` layers computes eleven amplitudes `A..K` from that average,
`scaler` (`x*0.781`), `offset` (`knob2`) and a trig term, and draws **four open
13-point polylines** (top, bottom, right, left frame arcs) of width 1 in one LFO
colour. `form = floor(knob3*6)` selects a shape family; forms 5 and 6 share a
branch.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` layers | `e.param("layers", 0.5, 0, 1, 1)` → `floor(knob1*9)+1` |
| `knob2` layer offset | `e.param("offset", 0.5, 0, 1, 2)` |
| `knob3` shape selector | `e.param("shape", 0.5, 0, 1, 3)` → `floor(knob3*6)` + the corner term |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO once per frame, phase offset 0.21 |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[j]` | `left[1 + j*10] * 32768`; the `corner` term reads **index 1 → `left[11]`** |
| `pygame.draw.lines(..., False, pts, 1)` ×4 | four preallocated mesh handles (line strips) |

## Deviations (in the mode header)

1. **`avg` reset per frame.** Stock accumulates `avg = |audio_in[i]| + avg` over
   `i = 0..99` and *never resets it*, so it grows without bound and drags every
   shape amplitude with it. The port resets it — stock's accumulator is a bug, and
   the port's shapes are the intended ones.
2. **Deterministic middle-branch palette** for the legacy random picker.
3. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
4. **`time.time()` → `ctx.time`** in the trig term (replays must be
   byte-identical); the terms are absolute-clock, so only the clock source changes.
5. **LFO phase offset 0.21** (`tools/lfo_offset.py --inc 0.1 --calls 1`; 38.85
   luma-unit clearance), phase advanced `30 * inc * ctx.dt` per frame.
6. **Audio stride** — stock index `j` → `left[1 + j*10]`, denormalized by 32768.
7. **Polylines via four mesh handles**, mutated in place (the engine caps a mode at
   32 handles; `resources 4` in the verifier's report is these).
8. **Dead stock state omitted** — `size`, `count`, `R`, the module-level
   `A=B=C=…=K=5` (overwritten per layer) and the unused `random` import.

## The failure and why the fix was right

Run 1 read `knob3` dead (0.0000 in every state). The cause was structural in the
stock arithmetic: `form` enters the amplitudes only through
`scaler*offset*trig(...)`, which the all-zero baseline zeroes via `offset = knob2 =
0`; the only other `knob3` path is the `corner` term, which the first revision had
truncated to 0 because it dropped stock's ±32768 scale on the raw audio sample.
The agent's fix was **fidelity, not a floor**: `corner` now reads `left[11]`
denormalized by 32768 as the brief's stride rule requires, and `knob3` cleared the
threshold at the mid state with no trigger retry and no geometry deviation. This is
the behaviour the program wants — restore the arithmetic rather than paper over the
knob.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-aa-selector --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `layers` | mid 0.0114, max 0.0117 |
| knob 2 `offset` | mid 0.0122, max 0.0103 |
| knob 3 `shape` | mid 0.0053, max 0.0000 |
| knob 4 `fg` | mid 0.0000, max 0.0098 |
| knob 5 `bg` | mid 0.9902, max 0.9902 |
| audio | quiet 0.0146, loud 0.0112, freq 0.0072 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.16–64.62, min stddev 3.99 |
| `p50_ms` (software GL) | 16.7 (resources 4) |

## Residual risk

- **Margins are thin** (0.005–0.012 for the geometry knobs): the mode is four
  1-px polylines, so a knob change moves relatively few pixels.
- **`knob3`'s max probe is 0.0000** (mid 0.0053): forms 5 and 6 share a branch in
  stock, and the max probe lands on that duplicate — the knob is live via mid.
- **`knob4`'s mid probe is 0.0000** (max 0.0098) — the usual static-branch pattern.
- Four mesh handles, four polylines: device tier owed (the row is cheap by
  construction, but the 13-point strips are Lua-side work per frame).
