# Port report — `s-concentric`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Concentric/main.py` (28 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Generation | OS v3, Python/pygame (`setup`/`draw`, module globals, 30 fps, 100-sample audio ring) |
| Tranche | P0 (pilot) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | not yet measured (needs the CM3+ bench; the p50 below is software rendering) |

## What the stock mode does

Nine filled circles, each with its radius driven by one audio sample, drawn on a
cosine-palette background, with the circle colour stepping through the picker per
circle. `x` accumulates `i/3` per circle, so the nine centres walk diagonally.

```python
def draw(screen, eyesy):
    eyesy.color_picker_bg(eyesy.knob5)
    x = int(eyesy.knob1*eyesy.xres); y = int(eyesy.knob2*eyesy.yres)
    circles = 10
    for i in range(1,circles):
        x = x+i/3
        R = int((abs(eyesy.audio_in[i]/100)*eyesy.yres/eyesy.yres)*(eyesy.knob3*i))+10
        color = eyesy.color_picker((eyesy.knob4*i)%1.0)
        pygame.draw.circle(screen, color,(x,y),(R))
```

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x position | `e.param("posx", 0.5, 0, 1, 1)` → circle centre x |
| `knob2` y position | `e.param("posy", 0.5, 0, 1, 2)` → circle centre y |
| `knob3` circle scaler | `e.param("scale", 0.5, 0, 1, 3)` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` |
| `knob5` bg colour | `e.param("bg", 0.5, 0, 1, 5)` |
| `eyesy.audio_in[i]`, 100 raw ±32768 samples | `ctx.audio.left[1 + (i-1)*100] * 32768` — 10-sample-per-stock-entry stride across the 1024-sample window |
| `R = int(|A|/100 * knob3*i) + 10` | `max(40, |sample| * 327.68 * (0.15 + 0.85*scale) * i + 10)` |
| `color_picker` (legacy, partly random) | deterministic middle branch as a 24-stop table sampled with cyclic linear interpolation |
| `color_picker_bg` (deterministic) | ported exactly, phase remapped |
| `pygame.draw.circle` | `e.circle(x, y, r)` — 1 `e.clear` + 9 `e.color`/`e.circle` pairs per frame |
| 30 fps `clocker.tick(30)` | 60 fps — nothing to re-time: the mode has no LFO, no free-running phase and no trigger |

## Deviations (all documented in the mode header)

1. **Audio floor `0.15 + 0.85*scale`.** Stock gates the whole audio term behind
   `knob3`, so at `knob3 = 0` the circles are nine static 10 px dots. The
   verifier's baseline is all-knobs-zero, where a literal port shows *zero* audio
   reactivity (measured: max changed fraction 0.000). The floor keeps 15 % of the
   response at `knob3 = 0` and leaves the knob's effect intact (it scales the
   response from 15 % to 100 %).
2. **Radius floor 40 px.** At the quiet audio variant (gain 0.05) the stock
   formula draws nine ~8 px dots, which quantize to a flat 8-bit frame.
3. **Palette sampled at half-stop offsets** (`c = (i + 0.5)/24`, not `i/24`). The
   stock phase set `{(knob4*i) % 1}` for `i = 1..9` collapses onto the palette's
   grey zero-crossings at `knob4 = 0`, `0.5` and `1.0`, where the entire 9-colour
   ramp is `(0.5, 0.5, 0.5)`: the parked port measured `knob4` as a dead knob
   (0.0000 changed pixels at both probe points). The offset keeps every knob
   position off those crossings; the ramp, its spacing and the knob's effect are
   otherwise untouched.
4. **Background phase remap** `(bg*0.7 + 0.15) % 1`. Stock's bg picker returns
   pure white at `c = 1` (and near-black at `c = 0`), which the verifier rejects
   as whiteout/blank. The colour path and the knob's effect are otherwise exact.

Stock's `+10` radius floor is kept verbatim (the parked port had remapped it to
`10*scale + 1`; the audio floor in deviation 1 makes that unnecessary).

## Verification — 2026-09-18

```
cd ~/dev/eyesy && podman run --rm --init --arch amd64 --userns=keep-id \
  -v "$PWD:/workspace" -v ~/dev/eyesy-modes-factory:/factory -w /workspace \
  -e LD_LIBRARY_PATH=/workspace/engine/bin localhost/eyesy-build:bookworm \
  python3 tools/scene_verify.py --modes-root /factory --mode s-concentric \
  --output /factory/local/verify-s-concentric-3 --frames 300 --xvfb
```

`{"mode": "s-concentric", "verdict": "pass", "failures": []}` — exit 0.
Renderer llvmpipe (software), engine sha256 `454ece7aafe7…`, 300 frames/run.
The mode file's sha256 was identical before and after the run
(`7585aa9e26b357d3ff81bd839319776d68b4380829d47a851bc17d9fc2534ebc`).

| Check | Result |
| --- | --- |
| determinism (base vs base2) | mean 0.0, frac 0.0000 |
| knob 1 `posx` | mid 0.0347, max 0.0227 |
| knob 2 `posy` | mid 0.0360, max 0.0240 |
| knob 3 `scale` | mid 0.1367, max 0.4260 |
| knob 4 `fg` | mid 0.0069, max 0.0000 |
| knob 5 `bg` | mid 0.9880, max 0.9880 |
| audio | quiet 0.0100, loud 0.1128, freq 0.0158 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | every grab within (0.0255, 251.2), stddev ≥ 0.51 |
| `p50_ms` (software GL) | 16.6 (resources 0) |

## Residual risk

- **Device tier gate not run.** 10 draw calls and no render targets make tier A
  the expectation, but the CM3+ measurement is still owed.
- **`knob4-max` is byte-identical to the baseline** and always will be: `(1*i) % 1
  = 0` for every `i`, so the stock phase set degenerates at `knob4 = 1` no matter
  how the palette is sampled. Knob 4's liveness rests on the `0.5` probe
  (0.0069). A future gate that probes only `1.0` would read this knob as dead.
- **Radius floor 40 px changes the low-audio look**: the quiet state renders 40 px
  discs where stock renders ~8 px dots.
- **Audio stride is an approximation** (stock's ring is circular and 36 ms long,
  ours is a 21 ms linear window), so the exact sample-to-circle correspondence
  drifts against stock; the ordering and spacing are preserved.
