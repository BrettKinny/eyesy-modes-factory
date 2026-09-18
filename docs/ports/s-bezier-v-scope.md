# Port report — `s-bezier-v-scope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Bezier V Scope/main.py` (99 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 28; sibling of `s-bezier-h-scope` |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

Twelve vertical cubic-bezier curves whose control points come from the audio window, drawn
over a decaying trail, with a moving spot.

## The stock H-vs-V diff (a clean transpose)

The two modes are exact transposes of one another, with the knob roles swapped:

| | H | V |
| --- | --- | --- |
| knob 1 | `y` offset (`voffset = knob1*yhalf/10`, curves shift `i*voffset` vertically) | **`x` offset** (`hoffset = knob1*xhalf/10`, curves shift horizontally) |
| knob 2 | `x` dead-band offset (`xres*0.078`) | **`y` dead-band offset** (`yres*0.078`) |
| setup | horizontal (`pointInterval = int(xres/20)`, `xr=1536`, `margin=128`, `yhalf=360`) | vertical (`pointInterval = int(yres/20)=36`, `yr=864`, `margin=72`, `xhalf=640`) |
| audio drives | height into `y` (`int(A*yres/32768)`) | **`x`** (`int(A*xres/32768)`), with the divisor `xres = 1280` — **not** `yres` |

Identical in both: 12 curves, 24 points, `gfxdraw.bezier smooth=2`, `color_picker_lfo(knob4,
0.1)`, `color_picker_bg(knob5)`, veil `alpha = int(knob3*20)`, the 0.48 dead band, and no
trigger or random state.

## Batching (deviation 8), applied from the start

**3312 strokes per frame** (12 curves × 23 cubic segments × 12 substeps) = 13248 quad
vertices — **over the 8192 cap** — so the frame is split across `MESHES = 2` meshes of six
curves each: 1656 quads → **6624 vertices / 9936 indices per mesh**, 2 of 32 handles, every
mesh exactly full every frame. Each stroke is a 4-vertex quad with static 1-based indices;
no continuous line strip (which would join the separate curves).

This is the sibling's deviation 8, carried in the brief rather than rediscovered — the
lesson from the H scope's batching task, where the count had to be corrected mid-flight.

## Other deviations

The sibling's full set, with this mode's own axes: the deterministic middle-branch palette;
the LFO re-timed 30→60 fps with the **0.21** phase offset (without it the ramp passes
through `picker(0)`, the baseline colour, exactly at the grab frames and knob 4 reads dead);
the background phase fold `(bg*0.7+0.15)%1`; the audio stride `left[1 + i*20] * 32768` with
the divisor **W** (not H, as stock V uses) and `int()` truncation preserved; the
**half-resolution** (640×360) ping-pong feedback bridge for stock's veil, so the trail reads
slightly softer; stock-exact off-screen extents (the spot starts two intervals above the top;
the bottom curve's lower points exit the bottom edge at `knob2 > 0.52`, the top curve's right
end exits at `knob1 > 0.5`) — stock's own framing, and the frame is never blank.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-bezier-v-scope --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 `xoff` | 0.02820 | 0.02718 |
| 2 `yoff` | 0.01694 | 0.04195 |
| 3 `trails` | 1.00000 | 0.99641 |
| 4 `fg` | **0.00000** | 0.01549 |
| 5 `bg` | 0.98451 | 0.98451 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.01681, loud 0.04376, freq 0.02280 (threshold 0.001) |
| trigger | not referenced — stock has no trigger or random state |
| luma bounds | mean 15.44–64.98, min stddev 3.77 |
| `p50_ms` (software GL) | 16.62 (resources 4) |

## Residual risk

- **knob 4's mid probe is exactly 0**, and this is **stock-faithful**: stock's static branch
  maps `knob4 = 0.5` to `picker(0.0)` — the same colour as `knob4 = 0`. It is live at its max
  (0.01549), and with no trigger path the gate cannot be banking a false liveness. No floor
  applied, correctly.
- **The trail is softer than stock's** because the feedback targets are half resolution.
- **`min stddev 3.77` is low** (luma 15.44–64.98): a dark frame with thin 1 px strokes.
- **The device cost is now the two mesh draws** rather than 3312 strokes, but the
  half-resolution feedback pair still costs the pack's measured ~9 ms bridge overhead on
  hardware.