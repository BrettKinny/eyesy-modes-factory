# Port report — `s-circle-scope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Circle Scope/main.py` (85 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 10; implemented by `local-agent`, 2 iterations |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

50 segments around a circle of radius `R` (audio-driven), joined into a polyline
(`lx`/`ly` carry the previous point), the whole ring rotated by `rotation_angle`,
with a per-segment colour from `knob4` and a size regime from `knob1`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` line & circle sizes | `e.param("size", 0.5, 0, 1, 1)` → stock's three `sizer` regimes |
| `knob2` scope diameter | `e.param("diameter", 0.5, 0, 1, 2)` → `R = (knob2*2)*400.64 - 149.76 + A/100` |
| `knob3` rotation rate | `e.param("spin", 0.5, 0, 1, 3)` → `±delta*50*30*ctx.dt`, dead zone 0.48–0.52, never wrapped |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `picker(((i*fg) + 0.5) % 1)` per segment |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| per-frame `j` walk | `j` increments for `i = 0..24`, decrements for `i = 25..49` — kept exactly |
| `lx`/`ly`/`begin` globals | file-locals persisting across frames, `begin` included |
| `audio_in[j]/100` | `left[1 + j*10] * 32768 / 100` |

## Deviations (in the mode header)

1. **Deterministic palette sampled from a 24-stop table at half-stop offsets**
   (`c = (i+0.5)/24`) with cyclic linear interpolation — the same deviation as
   `s-concentric`, applied for the same reason: stock's phase set
   `((i*fg) + 0.5) % 1` lands on the legacy palette's grey zero-crossings at every
   verifier probe point, so `knob4` read dead (0.0000 at both probes) until the
   table was offset.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Rotation re-timed** against `ctx.dt`; `rotation_angle` never wrapped (stock
   never wraps it).
4. **Audio stride** — stock index `j` → `left[1 + j*10]`, denormalized by 32768.
5. **`e.line` width floored at 1 px** and the dot drawn only when its radius ≥ 1
   (pygame's radius-0 circle draws nothing).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-circle-scope --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `size` | mid 0.0194, max 0.1391 |
| knob 2 `diameter` | mid 0.0150, max 0.0088 |
| knob 3 `spin` | mid 0.0133, max 0.0132 |
| knob 4 `fg` | mid 0.0031, max 0.0000 |
| knob 5 `bg` | mid 0.9932, max 0.9932 |
| audio | quiet 0.0097, loud 0.0226, freq 0.0220 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.24–64.58, min stddev 5.35 |
| `p50_ms` (software GL) | 16.6 (resources 0) |

## Residual risk

- **`knob4`'s liveness rests on the mid probe** (0.0031) — at `fg = 1.0` every
  segment's phase is the constant 0.5, so the max probe is byte-identical to the
  baseline. Same residual as `s-concentric` and `s-grid-circles-column-color`.
- **The margins are thin across the board** (0.0088–0.14): the mode is 50 chords of
  a ring, so a knob change moves relatively few pixels.
- **This is the first time an agent reached for a documented precedent on its own**:
  it recognised the `s-concentric` phase-crossing failure, cited
  `docs/ports/s-concentric.md` deviation 3 in its header, and applied the identical
  fix without being told. The pack's conventions are propagating through the porters.
- Device tier owed.