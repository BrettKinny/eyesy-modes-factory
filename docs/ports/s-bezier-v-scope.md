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

Tessellation: each curve is 23 cubic segments with Catmull-Rom control handles from the
neighbouring points (ends clamped); each stroke joins consecutive samples of its own cubic.
An earlier tessellation indexed past the 24-point table (comb artefact, blank frame at the
verifier's loud-audio state) and was fixed (same fix as the H sibling).

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

- **FIXED 2026-09-18: the geometry was clipped inside the feedback target.** Same defect as
  the H sibling: `docs/API.md` states that *"drawing inside a target uses that target's
  dimensions"*, so geometry emitted inside the 640×360 target must be in **640×360
  coordinates** — this mode computed it from `ctx.width`/`ctx.height` and drew it inside the
  target anyway. The mode now derives its geometry from the presentation surface's
  dimensions (`TW`/`TH` = 640×360 when the trail is on, `W`/`H` when `knob3 = 0`), recorded
  as header deviation 9.
  **Verification of the fix is by frame comparison, not by the luma summary:** the base and
  `knob5`-mid probes are byte-identical before and after (correctly — both have `knob3 = 0`,
  so they take the screen path and nothing should change), while the **trail-on probes
  changed**: `knob3-mid` 27,961 → 20,364 bytes and `knob3-max` 29,033 → 21,121 bytes,
  the smaller files reflecting the darker, fuller-frame trail picture. The luma-range summary
  barely moves because its maximum comes from the bright-background probe.
- **knob 4's mid probe is exactly 0**, and this is **stock-faithful**: stock's static branch
  maps `knob4 = 0.5` to `picker(0.0)` — the same colour as `knob4 = 0`. Live at its max
  (0.01549), and with no trigger path the gate cannot be banking a false liveness.
- **The trail is softer than stock's** because the feedback targets are half resolution.
- **`min stddev 3.77`** belongs to the dark-veil trail frame, unchanged by the fix.

## Device tier re-tune — 2026-10-22

Headless offscreen on the CM3+ (`headless-test`, 300 frames, same session; `starter`
floor 24.16 ms): **49.41 ms p50 / 50.21 p95 before, 30.88 / 31.12 after** (+6.7 over the
floor; tier C ≤ 33.3 passes). Live-service 25.4 fps before.

What was slow: the two-mesh quad batching (13248 vertices filled and uploaded per frame)
and the persistence bridge. The 4e665cf rewrite had not changed the draw-call count but
the quad form is the expensive part. Changes (header deviations 5, 8, 9):

- Each curve is now one **line-strip mesh** (277 vertices, 12 meshes, 3324 vertices per
  frame) instead of 3312 quads. 49.4 → 35.2 ms. Reducing substeps 12 → 6 measured no
  further gain (35.06), so the 12 substeps stay.
- The bridge's **screen-sized white a/255 rectangle** was dropped and the back target is
  built as `clear(bg)` + previous frame blitted at alpha `1 - a/255` instead of blit +
  rectangle: 35.2 → 32.1 ms. **This also fixes a bug**: the old rectangle was an
  opaque near-black fill over the blitted previous frame, so no trail ever carried over
  (the knob 3 trails were effectively off) and the screen got a white tint. The trail now
  works as stock's veil, and the background shows at full strength with trails on (a
  large, intended visual change for `knob3 > 0`).
- Targets 640×360 → **480×270** (geometry derives from `TW`/`TH`): 32.1 → 30.9 ms; the
  curves and trail read softer.

A/B vs the unmodified port (`scene_verify --frames 300`, final grab, luma diff): trails
off (base, knob1-mid) 1.2 % of pixels differ (line strip vs quad); trails on (knob3-mid)
all pixels differ because of the background/trail fix above. Desktop: pass
(persist warning expected).
