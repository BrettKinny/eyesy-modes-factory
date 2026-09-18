# Port report — `s-gradient-cloud`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Gradient Cloud/main.py` (39 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 (mode sha256 `aca209934cb1…` unchanged across the run) |
| Device tier gate | measured in the P1 device batch (receipt pending) |

## What it does

360 filled circles stacked vertically (one per row): each x follows a sine of the
row index and time, each y is offset by one audio sample, the radius swells with
`knob3` and time, and the colour advances a per-circle accumulator driven by
`knob4`. Four `time.time()` calls make the cloud breathe and drift.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` cloud x | `e.param("posx", 0.5, 0, 1, 1)` → `xpos1 = trunc(posx*4*240.64) - 2*240.64` |
| `knob2` cloud y | `e.param("posy", 0.5, 0, 1, 2)` → `ypos = trunc(posy*480.24 + A/100 + trunc(30*cos(1+t)))` |
| `knob3` shape/swell | `e.param("shape", 0.5, 0, 1, 3)` → drives `xpos`, `radius` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `color_rate += knob4*0.02` per circle |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `time.time()` ×4 | `ctx.time` (the sim clock — replays must be byte-identical) |
| `audio_in[i % 99]/100` | `left[1 + (i%99)*10] * 32768 / 100` |
| `radius = int((30+20 sin(...))*yr)/yr` | both truncations reproduced |
| `pygame.gfxdraw.filled_circle` | `e.circle(x + trunc(xpos1), i + trunc(ypos), trunc(radius))` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Colour accumulator re-timed** — stock advanced `color_rate` once per circle
   (360 calls/frame at 30 fps = `216*knob4`/s); the port adds the per-frame
   catch-up `216*knob4*ctx.dt` and keeps the stock per-circle `knob4*0.02` step so
   the within-frame gradient is unchanged.
4. **Audio stride** — stock index `j = i % 99` → `left[1 + j*10]`, denormalized.
5. **`time.time()` → `ctx.time`** — the four absolute-clock sines keep their
   per-second rates; only their origin moves to the sim clock, which is what makes
   the replays byte-identical.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-gradient-cloud --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `posx` | mid 0.1516, max 0.1339 |
| knob 2 `posy` | mid 0.1117, max 0.1108 |
| knob 3 `shape` | mid 0.1018, max 0.1518 |
| knob 4 `fg` | mid 0.0672, max 0.0665 |
| knob 5 `bg` | mid 0.9324, max 0.9324 |
| audio | quiet 0.0886, loud 0.0842, freq 0.0860 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 33.42–72.11, min stddev 28.56 |
| `p50_ms` (software GL) | 16.6 (resources 0) |

Every knob is live at *both* probe points — the strongest margins in P1 so far.

## Residual risk

- **The baseline is bright** (mean 54.7, stddev 51.5): 360 circles of radius 10–50
  fill much of the frame. It passes the whiteout bound with room (mean < 251), but
  a mode with a denser cloud would need care.
- 360 `e.circle` calls per frame is the heaviest draw-call count in P1 so far;
  device tier is being measured.
- The `i % 99` audio mapping means row 359 re-reads row 0's sample — stock's own
  wrap, kept.
