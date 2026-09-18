# Port report — `s-grid-circles-column-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Circles - Column Color/main.py` (41 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure grid family, row 1 of 11) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A 7×10 grid of audio-sized filled circles: 160 px apart in x, 144 px in y, with
every odd row shifted by `knob1`'s offset and every odd column by `knob2`'s, and
the colour stepped per column by `knob4`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` circle size | `e.param("size", 0.5, 0, 1, 3)` → `restRad = floor(knob3*29.44)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `picker((j*0.1 + fg) % 1)` per column |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j+i]/32768 * 256)` | `abs(left[1 + (j+i)*10] * 32768 / 32768 * 256)` with the negative-index wrap |
| `pygame.draw.circle(..., rad+restRad)` | `e.circle(x, y, rad + restRad)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Audio stride** — stock index `k` → `left[1 + k*10]`, denormalized by 32768;
   `k` can be negative here (`j+i` is not, but the triangle family's `j-i` is), so
   the port wraps `k` modulo 100 exactly as Python's negative indexing does.
4. No LFO call in this mode (the colour is `color_picker`, not
   `color_picker_lfo`), so no phase offset is needed — the per-column phase ramp
   already varies the colour within the frame.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-circles-column-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.2528, max 0.4021 |
| knob 2 `offy` | mid 0.1146, max 0.1748 |
| knob 3 `size` | mid 0.1231, max 0.2277 |
| knob 4 `fg` | mid 0.6867, max 0.0000 |
| knob 5 `bg` | mid 0.1891, max 0.1891 |
| audio | quiet 0.8063, loud 0.6588, freq 0.3847 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.44–116.49, min stddev 7.37 |
| `p50_ms` (software GL) | 15.4 (resources 0) |

## Residual risk

- **`knob4`'s max probe is 0.0000** while its mid probe is 0.6867: at `fg = 1.0`
  the per-column phase ramp `(j*0.1 + 1.0) % 1` returns the *same set* of colours
  as the baseline `(j*0.1) % 1`, just rotated by five columns — and with the grid
  symmetric in x the rotated set lands identically. The knob is live (0.69 at
  mid), but a gate probing only `1.0` would read it dead.
- **`knob5` is only 0.19** — the background is largely covered by the circles, so
  the knob's visible effect is small.
- The grid family's remaining 10 rows reuse this structure; the family brief is
  `local://brief-grid-family.md`.
- Device tier gate owed.
