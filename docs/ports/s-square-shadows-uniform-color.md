# Port report — `s-square-shadows-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Square Shadows - Uniform Color/main.py` (39 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 3 iterations (two steered corrections) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

25 "squares" down the frame — each a vertical line of length `squaresize` drawn
with width `squaresize`, so it reads as a block — with a black copy offset
diagonally behind it. `x` carries one audio sample per square.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` square size | `e.param("size", 0.5, 0, 1, 1)` → `max(16, floor(knob1*125.44)+1)` (deviation 5) |
| `knob2` shadow control | `e.param("shadow", 0.5, 0, 1, 2)` → `shad = 25.6 - knob2*51.2` |
| `knob3` y position (moves x) | `e.param("posx", 0.5, 0, 1, 3)` → `base_x = floor(knob3*1280)` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → stock-exact `color_picker_lfo` semantics |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i*4]/35` | `left[1 + i*40] * 32768 / 35` |
| shadow then square | `e.line(x+shad, y+shad, x+shad, y+squaresize, squaresize)` then the coloured one |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO re-timed, stock-exact semantics** — static `picker((fg*2) % 1)` for
   `fg <= 0.5`, ramp above with a *persistent* `inc = (fg-0.5)*2*0.1`, advanced
   `25 * 30 * inc * ctx.dt` per frame and sampled with the per-square `i*inc` step,
   folded 0→2→0.
4. **Audio stride** — stock index `i*4` → `left[1 + i*40]`, denormalized by 32768.
5. **16 px square-size floor.** Stock's baseline is 1×1 px dots (25 dots plus their
   shadows ≈ 50 lit pixels), which the gate reads as a flat frame; at 8 px the
   colour knob still only moved 0.0008 of the frame. 16 px gives ~6400 lit pixels;
   `knob1` still scales 16 → 126 px.

## Two failures worth recording

- **Run 1 (0.0008):** the LFO branch was not stock-exact — `inc` was computed
  unconditionally, so the baseline drifted through a ramp instead of holding the
  static colour, and the 8 px floor left too little area for the knob to register.
- **Run 2 (0.0000):** after the semantics fix the `if fg > 0.5 then lfo_inc = …`
  assignment was missing entirely, so the ramp never advanced and `fg = 1.0`
  rendered the baseline grey. A read-but-never-assigned variable is exactly the
  kind of defect the gate's dead-knob check exists to catch.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-square-shadows-uniform-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `size` | mid 0.0577, max 0.1959 |
| knob 2 `shadow` | mid 0.0020, max 0.0095 |
| knob 3 `posx` | mid 0.0162, max 0.0111 |
| knob 4 `fg` | mid 0.0000, max 0.0032 |
| knob 5 `bg` | mid 0.9948, max 0.9948 |
| audio | quiet 0.0119, loud 0.0071, freq 0.0094 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.11–64.07, min stddev 3.96 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s mid probe is 0.0000** (max 0.0032) — stock's own construction
  (`fg = 0.5` → `picker(1.0)` = the baseline grey), not a port defect.
- **`knob2`'s margin is thin** (0.0020): the shadow offset moves 51 px, but the
  shadow is black on a dark background.
- Device tier gate owed.
