# Port report — `s-grid-triangles-filled-patchwork-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Triangles - Filled Patchwork Color/main.py` (44 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 7 of 11) — implemented by `local-agent`, 2 iterations |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The grid family's patchwork triangles: 7×10 filled triangles (160 × 144 px pitch,
odd rows/columns offset by knobs 1 and 2) coloured per *cell* by the three-phase
patchwork rule rather than per column.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` triangle size | `e.param("size", 0.5, 0, 1, 3)` → `width = floor(knob3*80.64)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → three phase classes (below) |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j-i]*0.00003058*128)` | `abs(left[1 + wrap(j-i)*10] * 128)` — `j-i` reaches −6 |
| `pygame.draw.polygon(points)` | **3 meshes, one per colour class** |

**Patchwork colour rule** (stock's assignment order; last match wins):

```lua
local phase = fg
if j % 2 == 1 then phase = (0.4 + fg) % 1 end
if (j + i) % 3 == 1 then phase = (0.8 + fg) % 1 end
```

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Negative audio index wrapped** (`j-i` → Python's `audio_in[94]` at `j-i = -6`).
4. **Triangles via three meshes grouped by colour class.** The colour depends only
   on `(i, j)`, so the class membership is static: `setup` builds each class's cell
   list and its own index table, and `draw` mutates three vertex tables in place —
   three handles against the 32-handle cap, zero per-frame allocation.
5. **No LFO phase offset needed** — `color_picker` with three static phases.

## One failure worth recording

The first revision used a single shared 70-triangle index table for all three
class meshes; because the classes have different vertex counts the engine rejected
it with "mesh index out of range". The fix was per-class index tables built in
`setup` — the same lesson as the sibling row's `{1,2,3}`-only table, from the other
direction: **an index table must match its own mesh's vertex list exactly.**

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-triangles-filled-patchwork-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.1582, max 0.1111 |
| knob 2 `offy` | mid 0.1276, max 0.0739 |
| knob 3 `size` | mid 0.3739, max 0.7471 |
| knob 4 `fg` | mid 0.1073, max 0.0000 |
| knob 5 `bg` | mid 0.8470, max 0.8470 |
| audio | quiet 0.1522, loud 0.6947, freq 0.1275 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.04–72.93, **min stddev 1.72** |
| `p50_ms` (software GL) | 15.1 (resources 3) |

## Residual risk

- **`min stddev 1.72` is the thinnest luma margin in the pack** (threshold 0.51).
  The patchwork splits the 70 triangles across three phases, so at any instant one
  class can be dark against the background; a gate with a higher flatness
  threshold would fail this mode, and a future revision might want a slightly
  brighter background or a phase offset per class.
- **`knob4`'s max probe is 0.0000** (mid 0.1073) — the integer-`fg` effect.
- Device tier gate owed; 3 draw calls, so the device cost should be near the floor.
