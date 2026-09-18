# Port report — `s-five-lines-spin`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Five Lines Spin/main.py` (54 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — ported by `local-agent`; the two legibility floors were designed by the session after the first gate run |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

Five lines from fixed pivots on the left (`x = i*256 + 128`, `y = 360`) to
endpoints on a circle of radius `R` centred on the frame centre; all endpoints
share the angle `speed/1000*6.28`, so the five lines sweep together like clock
hands. `speed` accumulates from `knob1` (dead zone 0.48–0.52) and the per-line
colour advances a five-step rainbow by `color_rate` from `knob4`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` spin | `e.param("spin", 0.5, 0, 1, 1)` → `speed += delta*30*dt`, never wrapped |
| `knob2` length | `e.param("length", 0.5, 0, 1, 2)` → `R = 4*(0.15+0.85*knob2)*(peak/128) + 20` |
| `knob3` thickness | `e.param("thick", 0.5, 0, 1, 3)` → `max(4, floor(knob3*99.84)+1)` |
| `knob4` colour shift | `e.param("shift", 0.5, 0, 1, 4)` → `color_rate += 5*delta*30*dt` |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `peak = max(audio_in[i*10])`, `i = 0..4` | running max of `left[1 + i*100] * 32768` |
| `color_picker((i*0.2 + color_rate) % 1)` | deterministic middle branch |
| `pygame.draw.line(..., thick)` | `e.line(i*256+128, 360, ex + i*256 - 512, ey, thick)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Accumulator re-time** — `speed` advances `delta*30*ctx.dt` per frame,
   `color_rate` `5*delta*30*ctx.dt`; `speed` is never wrapped (stock never wraps
   it), `color_rate` wraps with `% 1`.
4. **Audio stride** — stock index `j` → `left[1 + j*10]`, denormalized by 32768;
   the running maximum maps `j = i*10` → `left[1 + i*100]`.
5. **Audio floor on the reach** `(0.15 + 0.85*knob2)`. Stock routes audio to the
   geometry only through `knob2`, so at `knob2 = 0` the strokes are static and the
   verifier's audio variants were byte-identical to the baseline (0.0000). The
   floor keeps 15 % of the response and reaches ~74 px instead of 20.
6. **Stroke thickness floor of 4 px.** Stock's baseline is five one-pixel
   hairlines (~120 lit pixels). A knob change must move ≥ 0.001 of the frame
   (921 px) for the gate to see it, and rotating a hairline cannot — the first run
   measured `knob1` 0.00022 and `knob4` 0.00011, both dead. The floor keeps the
   strokes legible; `knob3` still scales 4 → 100 px.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-five-lines-spin --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `spin` | mid 0.0042, max 0.0042 |
| knob 2 `length` | mid 0.0047, max 0.0057 |
| knob 3 `thick` | mid 0.0242, max 0.0504 |
| knob 4 `shift` | mid 0.0021, max 0.0021 |
| knob 5 `bg` | mid 0.9979, max 0.9979 |
| audio | quiet 0.0016, loud 0.0042, freq 0.0002 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.05–64.13, min stddev 2.6 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **The margins are thin** (0.0021–0.0057 against the 0.001 threshold) because the
  mode is genuinely small on screen: five short strokes. Both floors were sized to
  clear the metric with the mode's own geometry; a gate with a higher threshold
  would need thicker strokes still.
- **`knob1`'s and `knob4`'s mid probes equal the max probes** (0.0042 / 0.0021):
  both knobs have a dead zone around 0.5, so the mid state leaves the accumulator
  untouched and the max state carries the check.
- **`knob2`'s mid probe is only 0.0047** — the radius changes little between
  `knob2 = 0` and `0.5` at this audio level.
- Device tier gate owed.
