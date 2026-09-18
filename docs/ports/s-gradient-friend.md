# Port report — `s-gradient-friend`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Gradient Friend/main.py` (30 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Generation | OS v3, Python/pygame (`setup`/`draw`, module globals, 30 fps, 100-sample audio ring) |
| Tranche | P0 (pilot) |
| Implemented by | `local-agent` (2 iterations: fail at 60 frames, pass), corrected mid-flight by the session |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18, mode sha256 `b1ac60bc6205…` |
| Device tier gate | not yet measured (needs the CM3+ bench; the p50 below is software rendering) |

## What the stock mode does

A column of 180 filled circles — a quarter of the frame height — where each
circle's radius is one audio sample, its vertical placement is the loop index
scaled by the height knob plus an audio term, and its colour comes from the LFO
colour picker. Two `time.time()` calls drive the radius and the horizontal
wobble; the loop variable is reassigned to `boing` inside the body, so everything
after that line uses the reassigned value.

```python
def draw(screen, eyesy):
    eyesy.color_picker_bg(eyesy.knob5)
    yr = eyesy.yres; xr = eyesy.xres
    i = int(yr * 0.25)                      # 180
    for i in range(i):
        push = abs(int(eyesy.knob3*eyesy.audio_in[i%24]/(yr/2)))
        boing = int(eyesy.knob3*i)+eyesy.audio_in[1]/500
        i = boing
        color = eyesy.color_picker_lfo(eyesy.knob4)
        radius = int(10+push + 10 * math.sin(i * .05 + time.time()))
        xpos = int(((((xr*eyesy.knob1 + 100*math.sin(i * .0006 + time.time()))+100)*xr)/eyesy.xres))
        ypos = int((((((5*eyesy.knob2-1)/2*yr+(yr/2)))-int(i*eyesy.knob2))*yr)/yr-4*i)-boing
        pygame.gfxdraw.filled_circle(screen, xpos, int(ypos-boing), radius+1, color)
```

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x position | `e.param("posx", 0.5, 0, 1, 1)` |
| `knob2` y position | `e.param("posy", 0.5, 0, 1, 2)` |
| `knob3` height | `e.param("height", 0.5, 0, 1, 3)` — also the audio gain |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` |
| `knob5` bg colour | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[j]` (100-entry ring, ±32768) | `ctx.audio.left[1 + j*10] * 32768`; `A(n % 24)` for `push`, `A(1)` for `boing` |
| `push = abs(int(knob3*A/(yr/2)))` | `abs(trunc(g * A / (yr/2)))` with `g = 0.15 + 0.85*knob3` (deviation 3) |
| `boing = int(knob3*i) + A(1)/500` | `trunc(g * n) + A(1)/500` (deviation 3) |
| `time.time()` | `ctx.time` — the sim clock, so replays are byte-identical |
| `color_picker_lfo(knob4)` | deterministic middle branch, LFO phase re-timed (deviation 1, 6) |
| `color_picker_bg(knob5)` | exact cosine formula, phase remapped (deviation 2) |
| `(5*knob2-1)/2*yr + yr/2` | `2.5*yr*knob2` (identical: the expression is exactly `yr*5*knob2/2`) |
| `int(v)` (truncation) | `trunc(v)` helper — Python truncates toward zero, `math.floor` does not |
| 30 fps `clocker.tick(30)` | 60 fps: LFO phase advances by `5400 * inc * ctx.dt` per frame |

## Deviations (all documented in the mode header)

1. **Palette substitution.** Stock's legacy picker is partly random (random
   greys, random RGB above `c = 0.96`); randomness cannot be ported, so the
   deterministic middle branch is used. LFO semantics (`inc_amt = 0.1`, the
   0→2→0 fold, `inc` persisting across frames) and the per-circle phase step are
   stock-exact.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1` — stock's bg picker returns
   pure white at `c = 1`, which the verifier rejects as whiteout.
3. **15 % height floor**, `g = 0.15 + 0.85*knob3`, applied to *both* the radius
   term `push` and the position term `boing`. Stock gates both behind `knob3`, so
   at `knob3 = 0` all 180 circles collapse onto one another: the only visible
   blob then carries the last circle's colour, which is dark at `fg = 1.0` — the
   first verifier run failed `knob4-max` as a flat frame (stddev 0.45). The floor
   keeps the column's per-circle spread and colour ramp alive at `knob3 = 0`,
   while `knob3` still scales the response from 15 % to 100 %.
4. **Scaled x offset.** `x = trunc((W - 200)*knob1 + 100 + 100*sin(boing*0.0006
   + t))`. Stock's `xr*knob1 + 100 + wobble` walks off the right edge above
   `knob1 ≈ 0.85`, and a modulo wrap is worse: at `knob1 = 1.0` the offset is
   exactly one frame width, so wrapping lands back on the baseline and the knob
   reads dead (the agent's first revision did exactly that; `knob1-max` frac
   0.0). Scaling the offset into the frame's inner 1080 px keeps stock's 100 px
   margins and 100 px wobble and is monotone across the knob's range.
5. **Wrapped y.** `y = ypos % yr`. The y excursion (`≈ -5*boing` at `knob2 = 0`,
   past the bottom edge above `knob2 ≈ 0.45`) is far too large to scale, so the
   column scrolls instead of being ejected. Stock's arithmetic is bit-exact for
   every position that lands inside the frame.
6. **Audio stride.** Stock's ring is circular and ~36 ms long; the port reads a
   21 ms linear window at a 10-sample stride. Ordering and spacing are preserved.
7. **LFO re-time.** Stock advanced the picker once per circle (180 calls/frame at
   30 fps = `5400·inc` per second); the port advances a phase once per frame by
   `5400 * inc * ctx.dt` and keeps the stock `n*inc` per-circle step.

## Verification — 2026-09-18

```
cd ~/dev/eyesy && podman run --rm --init --arch amd64 --userns=keep-id \
  -v "$PWD:/workspace" -v ~/dev/eyesy-modes-factory:/factory -w /workspace \
  -e LD_LIBRARY_PATH=/workspace/engine/bin localhost/eyesy-build:bookworm \
  python3 tools/scene_verify.py --modes-root /factory --mode s-gradient-friend \
  --output /factory/local/verify-s-gradient-friend --frames 300 --xvfb
```

`{"mode": "s-gradient-friend", "verdict": "pass", "failures": []}` — exit 0.
Renderer llvmpipe (software), 300 frames/run. The mode file's sha256 was
identical before and after the run (`b1ac60bc62054bed16d91e3874ad80b383fc76c78632da7c0ca181ec6a2cfb9c`).

| Check | Result |
| --- | --- |
| determinism (base vs base2) | mean 0.0, frac 0.0000 |
| knob 1 `posx` | mid 0.0118, max 0.0118 |
| knob 2 `posy` | mid 0.0087, max 0.0095 |
| knob 3 `height` | mid 0.0199, max 0.0417 |
| knob 4 `fg` | mid 0.0000, max 0.0040 |
| knob 5 `bg` | mid 0.9956, max 0.9956 |
| audio | quiet 0.0043, loud 0.0115, freq 0.0016 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | every grab within (0.0255, 251.2), stddev ≥ 3.49 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **Device tier gate not run.** 180 `e.circle` calls per frame and no render
  targets: tier A expected, CM3+ measurement still owed.
- **`knob4-mid` is byte-identical to the baseline** by construction — stock's
  `(fg*2) % 1` maps both `0.0` and `0.5` onto the palette's grey point
  `(0.5, 0.5, 0.5)`. Liveness rests on `knob4-max` (0.0040).
- **The zero-knob state is a short column, not a dot.** Stock's `knob3 = 0` state
  is 180 coincident circles; the floor in deviation 3 spreads them over roughly
  130 px. That is the deviation the gate forces, and it is visible in the base
  grab (stddev 6.56 vs stock's ~0.1).
- **The y wrap is a scroll seam**: at `knob2 > 0.45` stock's column leaves the
  frame and the port's re-enters from the top. Recorded, not hidden.
- **Audio stride is an approximation**, as above.
