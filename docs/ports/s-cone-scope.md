# Port report — `s-cone-scope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Cone Scope/main.py` (33 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Generation | OS v3, Python/pygame (`setup`/`draw`, module globals, 30 fps, 100-sample audio ring) |
| Tranche | P0 (pilot) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | not yet measured (needs the CM3+ bench; the p50 below is software rendering) |

## What the stock mode does

Fifty line segments fan out of a pivot on the x axis. Each segment's horizontal
reach is one audio sample (`soundwidth`), its far end is offset vertically by the
angle knob, its thickness is the width knob, and its colour steps through the
LFO colour picker across the fan.

```python
def draw(screen, eyesy):
    eyesy.color_picker_bg(eyesy.knob5)
    for i in range(0, 50) : seg(screen, eyesy, i)

def seg(screen, eyesy, i) :
    color = eyesy.color_picker_lfo(eyesy.knob4)
    x0 = (int(eyesy.knob1*eyesy.xres))
    soundwidth = ((eyesy.audio_in[i] * eyesy.xres)/(eyesy.xres*35))
    x1 = x0 + soundwidth
    linespacing = eyesy.yres/50
    y = i * linespacing
    newy = (0.8*eyesy.yres-(int(eyesy.knob2*(1.5972 * eyesy.yres))))
    linewratio = eyesy.xres * 0.016
    linewidth = int(eyesy.knob3*linewratio)
    pygame.draw.line(screen, color, [x0, y +i], [x1, y+i+newy], 1+linewidth)
```

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x position | `e.param("posx", 0.5, 0, 1, 1)` → fan pivot |
| `knob2` angle | `e.param("angle", 0.5, 0, 1, 2)` → far-end vertical offset |
| `knob3` line width | `e.param("width", 0.5, 0, 1, 3)` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` |
| `knob5` bg colour | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]` (100-entry ring, ±32768) | `ctx.audio.left[1 + i*10] * 32768` — 10-sample stride across the 1024-sample window |
| `soundwidth = audio_in[i]*xres/(xres*35)` | `A / 35` (the `xres` cancels) |
| `newy = 0.8*yres - int(knob2*1.5972*yres)` | identical, with Python-`int()` truncation preserved for negative values |
| `linewidth = int(knob3*xres*0.016)` | identical; `pygame` width `1+linewidth` → `e.line(..., 1 + linewidth)` |
| `color_picker_lfo(knob4)` | deterministic middle branch + LFO phase re-timed (below) |
| `color_picker_bg(knob5)` | exact cosine formula, phase remapped |
| 30 fps `clocker.tick(30)` | 60 fps: the LFO phase advances by `1500 * inc * dt` per frame |

## Deviations (all documented in the mode header)

1. **Palette substitution.** Stock's legacy picker is partly random (random
   greys, random RGB above `c = 0.96`) and randomness cannot be ported — replays
   must be byte-identical — so the deterministic middle branch
   `(0.5 sin(2πc) + 0.5, 0.5 sin(4πc) + 0.5, 0.5 sin(8πc) + 0.5)` is used. The
   LFO ramp (0→2→0) and the per-segment phase step are stock-exact.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`. Stock's bg picker returns
   pure white at `c = 1` and pure black at `c = 0`, both rejected by the verifier.
3. **LFO re-time.** Stock advanced the picker index once per segment call: 50
   calls per frame at 30 fps = `1500·inc` per second. The port advances a phase
   once per frame by `1500 * inc * ctx.dt` and keeps the stock `i*inc` per-segment
   step, so both the temporal rate and the rainbow spread across the fan match.
   `inc` persists across frames exactly as stock's `color_lfo_inc` does.
4. **Audio stride.** Stock's ring is circular and ~36 ms long; the port reads a
   21 ms linear window at a 10-sample stride. Ordering and spacing are preserved;
   the exact sample-to-segment correspondence drifts against stock.

**Not a deviation, recorded because an earlier revision got it wrong:** `x0 =
int(knob1 * xres)` is kept stock-exact. At `knob1 = 1.0` the pivot sits on the
right edge and only the segments with a negative sample stay in frame — stock's
own behaviour, and the grab is neither blank nor flat, so no wrap is applied. The
first revision wrapped `x0` modulo the width, which made `knob1 = 1.0`
pixel-identical to the baseline and hid the knob's upper half.

## Verification — 2026-09-18

```
cd ~/dev/eyesy && podman run --rm --init --arch amd64 --userns=keep-id \
  -v "$PWD:/workspace" -v ~/dev/eyesy-modes-factory:/factory -w /workspace \
  -e LD_LIBRARY_PATH=/workspace/engine/bin localhost/eyesy-build:bookworm \
  python3 tools/scene_verify.py --modes-root /factory --mode s-cone-scope \
  --output /factory/local/verify-s-cone-scope --frames 300 --xvfb
```

`{"mode": "s-cone-scope", "verdict": "pass", "failures": []}` — exit 0.
Renderer llvmpipe (software), 300 frames/run.

| Check | Result |
| --- | --- |
| determinism (base vs base2) | mean 0.0, frac 0.0000 |
| knob 1 `posx` | mid 0.0288, max 0.0197 |
| knob 2 `angle` | mid 0.0167, max 0.0200 |
| knob 3 `width` | mid 0.0664, max 0.1079 |
| knob 4 `fg` | mid 0.0000, max 0.0068 |
| knob 5 `bg` | mid 0.9909, max 0.9909 |
| audio | quiet 0.0133, loud 0.0250, freq 0.0172 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | every grab within (0.0255, 251.2), stddev ≥ 0.51 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **Device tier gate not run.** 50 `e.line` calls per frame and no render
  targets: tier A expected, CM3+ measurement still owed.
- **`knob4-mid` is byte-identical to the baseline** by construction: stock's
  `(fg*2) % 1` maps both `0.0` and `0.5` to the palette's grey point
  `(0.5, 0.5, 0.5)`. Liveness rests on `knob4-max` (0.0068).
- **At `knob1 = 1.0` only half the fan is drawn** (the pivot is on the right
  edge, stock-exact). The frame is non-blank, but a future gate that probes only
  the extreme knob positions would see less of the mode than at mid.
- **Audio stride is an approximation**, as above.
- **LFO temporal rate is matched per second, not per frame** — at 60 fps the
  colour ramp is sampled twice as often as stock's 30 fps, so the flicker is
  smoother than stock's (deliberate, and the alternative — halving the per-segment
  step — would flatten the rainbow spread across the fan).
