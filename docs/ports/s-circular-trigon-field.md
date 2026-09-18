# Port report — `s-circular-trigon-field`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Circular Trigon Field/main.py` (50 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Generation | OS v3, Python/pygame (30 fps, 100-sample audio ring, `random.randrange` per triangle) |
| Tranche | P1 (pure S, small) |
| Implemented by | `local-agent` (5 iterations, did not converge) → the session took over the two structural fixes |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What the stock mode does

50 triangles on a circle of radius `R = int(knob1*800) + audio_in[i]/100` centred
at `(640, 316.8)`: odd `i` filled with the LFO colour, even `i` 1 px outlines in a
colour from a random phase. Every triangle's second vertex carries a random x
jitter (0..77 px, re-drawn every frame) and its two non-centre vertices are placed
by knobs 2 and 3.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` radius | `e.param("radius", 0.5, 0, 1, 1)` → `int(knob1*640) + audio/100` (deviation 8) |
| `knob2` second point | `e.param("point2", 0.5, 0, 1, 2)` → `max(int(knob2*199.68), 12)` |
| `knob3` third point | `e.param("point3", 0.5, 0, 1, 3)` → `max(int(knob3*199.68), 12)` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO picker per triangle |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `random.randrange` ×2 per triangle | `e.random()` (deterministic PRNG), same call order |
| `audio_in[i]/100` | `left[1 + i*10] * 32768 / 100` |
| `pygame.gfxdraw.filled_trigon` | 25 preallocated 3-vertex meshes (one per odd `i`), mutated in place |
| `pygame.gfxdraw.trigon` | three `e.line` calls (A→B, B→C, C→A), width 1 |

## Deviations (all documented in the mode header)

1. **`e.random()`** for `random.randrange` — deterministic PRNG, same call order
   (one jitter per triangle, outline phase for even `i`).
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO phase offset 0.25** — the colour varies within the frame (per-triangle
   `i*inc` step), and 0.25 keeps the sampled band ≥ 38 luma units from both the
   palette grey and the background at every frame count the verifier supports.
4. **LFO re-time** — 50 calls/frame at 30 fps = `1500·inc` per second.
5. **Audio stride** — 100-entry ring → `left[1 + i*10]`, denormalized by 32768.
6. **Triangles via mesh handles** — 25 preallocated meshes, mutated in place;
   outlines as three lines. Stock interleaves filled and outlined triangles;
   drawing the filled set first changes only the z-order of non-overlapping
   shapes.
7. **Vestigial stock state omitted** (`x960`, `lx`/`ly`/`note_down`).
8. **Ring radius scaled into the frame: 800 → 640.** At `knob1 = 1` stock's ring
   sits at radius ~800 around `(640, 316.8)`, which the 1280×720 frame never
   intersects — the part inside the x range is outside the y range and vice versa
   — so the verifier read a blank grab (stddev 0.38). 640 is the frame's
   half-width, which keeps the ring visible across the knob's whole range; the
   audio term is unchanged.
9. **Minimum triangle extent 12 px.** With knobs 2 and 3 at 0, stock's second and
   third vertices collapse onto the centre vertex, so the filled triangles have
   zero area: they render nothing, the colour knob becomes unobservable (the gate
   read `knob4` as dead at every probe point, including the trigger retry), and
   the whole visual reduces to the random hairline jitter. Both offsets are
   floored at 12 px; the knobs still scale them to 199 px.

Deviations 8 and 9 were designed and applied by the session after five
`local-agent` iterations failed to converge (two crashes, then the blank and
dead-knob failures).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-circular-trigon-field --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `radius` | mid 0.0222, max 0.0154 |
| knob 2 `point2` | mid 0.0397, max 0.0636 |
| knob 3 `point3` | mid 0.0578, max 0.1023 |
| knob 4 `fg` | mid 0.0000, max 0.0084 |
| knob 5 `bg` | mid 0.9875, max 0.9875 |
| audio | quiet 0.0132, loud 0.0212, freq 0.0216 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.26–65.16, min stddev 6.1 |
| `p50_ms` (software GL) | 16.6 (resources 25 — the mesh handles) |

## Residual risk

- **25 mesh handles per mode** is the most resources any port has used (the P0
  ports use 0). The engine documents no handle limit; if a mode needs many more
  triangles this approach will not scale, and a single mesh with per-vertex colour
  would be the engine-side answer.
- **`knob4`'s liveness rests on the 12 px floor** (0.0084). Without it the filled
  triangles are invisible and the colour knob is unobservable — the same
  class of coupling as the other P1 modes' offsets.
- **Stock's `j - i` audio index** (`audio_in[j-i]` in the triangle family) can go
  negative; this mode uses `audio_in[i]` so it does not arise here, but the
  triangle-family briefs must decide the negative-index reading explicitly.
- Device tier gate owed.
