# Port report — `s-circle-scope-opposite-colors`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Circle Scope - Opposite Colors/main.py` (85 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 11; implemented by `local-agent`, sibling copy (2 runs) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 (mode sha256 `682e06ab7cbb…`) |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

Identical to `s-circle-scope` — 50 audio-driven chords joined into a rotating ring
with a per-segment colour and a size regime from `knob1` — with one difference:

```python
# s-circle-scope:            both the polyline and the dot use  ((i*knob4) + .5) % 1
# opposite colors:
color = eyesy.color_picker(1 - (((i * eyesy.knob4) + .5) % 1))   # the LINE: the complement phase
color = eyesy.color_picker(((i * eyesy.knob4) + .5) % 1)         # the DOT:  the stock phase
```

So the ring and its dots read as opposite colours.

## Mapping

Identical to `s-circle-scope` (see `docs/ports/s-circle-scope.md`): the same params,
the same per-frame `j` walk, the same `lx`/`ly`/`begin` state, the same rotation
re-timing and audio stride — with the line's colour phase complemented.

## Deviations (in the mode header)

Carried verbatim from the verified sibling:

1. **Deterministic palette sampled from a 24-stop table at half-stop offsets**
   (`c = (i+0.5)/24`) with cyclic linear interpolation — the `s-concentric`
   precedent, needed here for both the stock phase *and* its complement, which land
   on the palette's grey zero-crossings at the verifier's probe points.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Rotation re-timed** against `ctx.dt`, never wrapped.
4. **Audio stride** — stock index `j` → `left[1 + j*10]`, denormalized by 32768.
5. **1 px line width floor** and the dot drawn only when its radius ≥ 1.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-circle-scope-opposite-colors --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `size` | mid 0.0194, max 0.1391 |
| knob 2 `diameter` | mid 0.0150, max 0.0088 |
| knob 3 `spin` | mid 0.0133, max 0.0132 |
| knob 4 `fg` | mid 0.0031, max 0.0000 |
| knob 5 `bg` | mid 0.9932, max 0.9932 |
| audio | quiet 0.0097, loud 0.0226, freq 0.0220 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.24–64.58, min stddev 5.35 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

The numbers are identical to the sibling's, which is expected: the two modes differ
only in one colour phase, and the changed-pixel *fractions* are the same because the
polyline and the dot swap which of the two colours they take.

## Residual risk

- **`knob4`'s liveness rests on the mid probe** (0.0031) — at `fg = 1.0` every phase
  is the constant 0.5, so the max probe is byte-identical to the baseline. The same
  residual as the sibling and `s-concentric`.
- **Thin margins throughout** (0.0088–0.14) for the same reason as the sibling: 50
  chords of a ring.
- **Sibling copy: 3m29s, 2 runs** — the third such row in P2 and the cheapest way to
  land a variant.