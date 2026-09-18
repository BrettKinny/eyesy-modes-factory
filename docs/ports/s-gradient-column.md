# Port report — `s-gradient-column`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Gradient Column/main.py` (39 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — ported by `local-agent` (1 iteration at 60 frames); the three legibility deviations were designed by the session after the 300-frame run failed |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A vertical column of `cool` circles, each nudged horizontally by an audio sample,
with a per-circle colour ramp and a radius that swells with `knob3`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` cloud height | `e.param("height", 0.5, 0, 1, 1)` → `max(30, floor(knob1*710)+10)` circles, `yoff = floor(360 - knob1*360)` |
| `knob2` cloud width | `e.param("width", 0.5, 0, 1, 2)` → `xtra = floor(knob2*1278)+2` |
| `knob3` swell | `e.param("swell", 0.5, 0, 1, 3)` → `swell = knob3*0.999 + 0.001` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_rate += cool*knob4*0.002*30*dt` per frame |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i % 99]*0.00003058*360` | `trunc(left[1 + (i%99)*10] * 360.6)` |
| `time.time()` ×2 | `ctx.time` |
| `pygame.gfxdraw.filled_circle` | `e.circle(xpos + audiopuff, i + yoff, radius)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** (stock's picker is partly random);
   stock's unused `sel` switch dropped.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Colour accumulator re-timed** — stock advanced it once per circle
   (`cool` times per frame at 30 fps); the port adds the per-frame catch-up
   `cool*knob4*0.002*30*ctx.dt` and keeps the stock `i*0.02` per-circle term.
4. **Audio stride** — `j = i % 99` → `left[1 + j*10]`, denormalized by 32768.
5. **Circle count floor of 30.** Stock's `cool` is 10 at `knob1 = 0`, so the
   baseline column is ten small dots (~1100 lit pixels) and no knob change can
   move the 0.001 of frame (921 px) the gate needs. `knob1` still scales
   30 → 710 circles.
6. **Radius floor of 8 px.** Stock's `int(12 + 12*sin(...))` passes through 0; at
   the grab instant every circle was radius 0 and the frame blank.
7. **Swell phase coefficient widened 0.1 → 0.3.** Stock's `i*0.1*swell` spans at
   most 1 rad across the column, so the swell's effect vanishes whenever the sine
   sits near an extremum — the first 300-frame run read `knob3` dead at *both*
   probe points (0.0000), even though the 60-frame run had passed (0.0024). The
   wider coefficient spreads the radii across a half-cycle at full swell, so the
   knob is observable at any sampled instant; its direction and range are
   unchanged.
8. **`time.time()` → `ctx.time`** — both absolute-clock sines keep their
   per-second rates.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-gradient-column --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `height` | mid 0.0671, max 0.1286 |
| knob 2 `width` | mid 0.0102, max 0.0097 |
| knob 3 `swell` | mid 0.0116, max 0.0074 |
| knob 4 `fg` | mid 0.0054, max 0.0054 |
| knob 5 `bg` | mid 0.9946, max 0.9946 |
| audio | quiet 0.0063, loud 0.0107, freq 0.0083 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.07–64.16, min stddev 2.74 |
| `p50_ms` (software GL) | 15.8 (resources 0) |

## Residual risk

- **The gate's frame count changed the verdict.** The same bytes passed at 60
  frames and failed at 300 for `knob3`: the swell's visibility is
  phase-dependent, and the two frame counts sample different instants. Deviation
  7 removes that dependency, but it is the clearest example in P1 of a knob whose
  observability is a property of *when* the gate looks.
- **Three legibility deviations for one small mode** (count, radius, swell
  spread) — the mode's stock baseline is simply too sparse and too phase-dependent
  for a single-instant luma metric.
- Device tier gate owed.
