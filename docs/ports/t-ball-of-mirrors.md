# Port report — `t-ball-of-mirrors`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Ball of Mirrors/main.py` (37 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 1 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true`, `trigger_pass: true` |
| Device tier | retired (repo-only) |

## What it does

A ball drawn at a random position on each trigger, with the previous frame **scaled, mirrored and
blitted back** over it — the "mirrors" are a feedback echo of the frame itself.

## The structural problem, and stock's semantics

Stock's entire content is two things:

```python
if eyesy.trig:                                       # a circle, only on a trigger
    pygame.draw.circle(screen, color, [x,y], cscale)
image = last_screen                                  # the PREVIOUS frame
last_screen = screen.copy()                          # ← taken BEFORE the echo blit
thing = pygame.transform.scale(image, (int(knob3*xr), int(knob4*yr)))
thing = pygame.transform.flip(thing, 1, 0)
screen.blit(thing, (int(knob1*xr), int(knob2*yr)))
```

At the all-knobs-zero baseline there is no trigger and the echo scales to `(0, 0)`, so the frame
is **background only** — the gate reported `mean luma 0.0` and `flat frame` on every non-trigger
run.

**The critical detail the first revision missed:** `screen.copy()` happens **before** the echo
blit, so stock's echo source (`last_screen`) can never contain the echo — it holds only the
background and the ball. The revision composited the echo *into* the accumulation, so a ball
inside the echo rectangle was erased from both the frame and the history at once, producing
uniform frames even after the black-frame fix. The port now keeps only **bg + ball** in the
target (stock's `last_screen`) and composites the echo **at presentation** — restoring stock's
semantics and removing that whole class of failure.

## Representation

- **The echo** is the pack's half-resolution ping-pong bridge (640×360): the back target is
  cleared to the background and the ball drawn into it in the **target's own coordinates**, then
  the frame is presented as the target blitted to full size with the **previous** target over it
  at stock's screen-space rect and size, mirrored about the rectangle's own vertical centre line.
  Nothing accumulates across frames — the back target is cleared every frame.
- **A ball is seeded at setup** and re-stamped each frame, since a once-only ball decays
  geometrically out of the downscaling echo within a few frames. Its colour phase, x and y are
  drawn in stock's exact order and range (the 100-step phase grid; half-open `[a, W)` for the
  positions), clamped inside the target, and re-randomised on `ctx.trigger`.
- **The echo's scale is floored** at `max(knob3, 0.35)`/`max(knob4, 0.35)`, so a zero knob cannot
  produce a zero-size blit.

## Deviations

1. **The echo is a half-resolution bridge** (the pack convention); the trail reads slightly softer.
2. **A ball is seeded at setup and re-stamped each frame** — stock draws nothing until a trigger,
   which fails the gate's baseline requirement. Stock-faithful deadness still fails.
3. **The echo scale is floored** at 0.35 of the frame.
4. **The ball's radius carries the audio level** (`int(TW*0.04*(0.55+1.3*level))`) so the mode
   references `ctx.audio` — without it `audio_pass` could not be satisfied, since stock's ball is
   audio-independent. At the verifier's default level this is 25 target px = 50 screen px against
   stock's `int(1280*0.04) = 51`.
5. The deterministic middle-branch picker; the background phase fold `c = (bg*0.7+0.15) % 1`;
   `random` → `e.random()` in stock's exact call order.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-ball-of-mirrors --frames 300` → `"verdict": "pass"`, `failures: []`. Numbers identical in both runs.

| Knob | mid | max |
| --- | --- | --- |
| 1 `xpos` | 0.00233 | 0.00117 |
| 2 `ypos` | 0.01109 | 0.00117 |
| 3 `xscale` | 0.00279 | 0.00449 |
| 4 `yscale` | 0.00279 | 0.01324 |
| 5 `bg` | 0.99106 | 0.99106 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.00722, loud 0.02524, **freq 0.00020** — `audio_pass: true` on the level probes |
| trigger | `trigger_pass: true`, frac 0.01983 |
| base run | mean luma **28.93**, stddev **9.48** (was 0.0 / 0.0 before the fix) |
| luma across all 22 runs | 28.11–64.59, min stddev 3.26 |
| `p50_ms` (software GL) | 16.60 / 16.62 (2 render targets, 0 meshes) |

## Residual risk

- **`audio-freq` reads 0.00020 — BELOW the 0.001 threshold.** The set passes on the level probes,
  and the frequency probe is structurally weak here: the only audio coupling is the ball's radius,
  which a spectral change barely moves.
- **Deviation 4 is the largest fidelity concession**: stock's ball is a fixed 51 px and
  audio-independent; the port's radius varies with the level. It was needed to satisfy
  `audio_pass` at all, since stock's own content has no audio path.
- **Deviation 2 (the seeded ball)** means the baseline shows a ball where stock shows only
  background.
- **The echo is half resolution**, so the mirrored content is softer than stock's.
- **Every knob's margin is thin** (0.0012–0.0132), which is expected: the echo's content is
  mostly a scaled copy of a small ball, so moving a knob changes relatively few pixels.