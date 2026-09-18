# Port report — `s-arcway`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Arcway/main.py` (61 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 4; implemented by `local-agent`, **0 iterations** (sibling copy) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

Identical to `s-arcway-black` — two discs of 100 arcs on a 250 px circle, a black
shadow disc and a coloured disc, with the same rotation, audio displacement and
width rules — except the **bottom disc is a bounced gradient** rather than black:

```python
if i < 49 : color = eyesy.color_picker(i*.02)
else:       color = eyesy.color_picker((99-i)*.02)
```

## Mapping

Identical to `s-arcway-black` (see `docs/ports/s-arcway-black.md`): same params,
same `rotation_factor` accumulation with the signed rate, same `rotation_detune`,
same 100 arcs of `math.pi/50` at radius 250 with the audio offset and the
∓`0.1*width` shadow offset, same `width = int(knob1*65)+1`, same
`color_picker_lfo(knob4)` for the top disc. Only the bottom disc's colour changes.

## Deviations (in the mode header)

Carried verbatim from the verified sibling:

1. **Ring radius scaled into the frame** (`RMAX = 640`, not stock's 800) — at
   `knob1 = 1` stock's ring at radius ~800 never intersects the 1280×720 frame, so
   the grab would be blank.
2. **Arcs as chords** — each 3.6° arc of the 250 px circle drawn as one thick
   `e.line` between the arc's endpoints; the chord deviates 0.12 px at that radius.
3. **Deterministic middle-branch palette** for the legacy random picker (the bottom
   disc uses `color_picker`, the top uses `color_picker_lfo`).
4. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
5. **LFO re-timed** `6000 * inc * ctx.dt` per frame with the stock per-arc `n*inc`
   step; **rotation re-timed** `rate * 30 * ctx.dt`, never wrapped.
6. **Audio stride** — stock index `n` → `left[1 + n*10]`, denormalized by 32768.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-arcway --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `width` | mid 0.0638, max 0.1282 |
| knob 2 `rate` | mid 0.0036, max 0.0036 |
| knob 3 `detune` | mid 0.0017, max 0.0000 |
| knob 4 `fg` | mid 0.0000, max 0.0014 |
| knob 5 `bg` | mid 0.9980, max 0.9980 |
| audio | quiet 0.0039, loud 0.0040, freq 0.0038 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.16–64.13, min stddev 3.01 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

The numbers are identical to the sibling's, which is the expected result: the two
modes differ only in the colour of one of the two discs.

## Residual risk

- The sibling's risks carry over unchanged: **`knob3` passes at 0.0017** (at the
  verifier's baseline `width = 1` makes the shadow offset only 0.2 px, so rotating
  it barely changes a pixel — stock's own behaviour) and **`knob4` at 0.0014**.
- **The sibling-copy pattern worked**: one brief, zero iterations, 3m47s — the
  cheapest row in the program so far. Nine more P2 rows are colour/size variants of
  a verified sibling and should go the same way.
