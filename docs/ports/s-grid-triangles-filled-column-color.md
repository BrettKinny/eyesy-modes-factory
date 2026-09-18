# Port report — `s-grid-triangles-filled-column-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Triangles - Filled Column Color/main.py` (39 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 6 of 11) — implemented by `local-agent`, 3 iterations |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A 7×10 grid of filled triangles (160 × 144 px pitch, odd rows/columns offset by
knobs 1 and 2). Each triangle is centred on its cell with half-width `knob3`-driven
size plus an audio-driven `rad` added outward on every coordinate, coloured per
column.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` triangle size | `e.param("size", 0.5, 0, 1, 3)` → `width = floor(knob3*80.64)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → `picker((j*0.1 + fg) % 1)` per column |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j-i]*0.00003058*128)` | `abs(left[1 + wrap(j-i)*10] * 128)` — **`j-i` reaches −6** |
| `pygame.draw.polygon(points)` | one mesh per column (10 handles, 7 triangles each) |
| points | `((x-width)-rad, (y+width)+rad)`, `(x, (y-width)-rad)`, `((x+width)+rad, (y+width)+rad)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Negative audio index wrapped** — Python's `audio_in[j-i]` with `j-i` as low as
   −6 is `audio_in[94]`; the port reproduces that with `(k % 100 + 100) % 100`
   before mapping to `left[1 + k*10]`.
4. **Triangles via meshes** — grouped per column (10 preallocated handles) because
   of the engine's 32-handle cap.
5. **No LFO phase offset needed** — the colour is `color_picker` with a static
   per-column ramp.

## Two failures worth recording

- **Iteration 1: "mesh budget exceeded".** The first revision created 70 per-cell
  mesh handles; the engine caps a mode at **32 meshes** (`runtime.cpp`). The fix
  was to group per column (10 handles). This limit is now recorded in
  `docs/PORTING-LADDER.md` §3.5 and in the family brief, because it constrains
  every mesh-based port in the program.
- **Iteration 2: flat frames.** The index table contained only `{1,2,3}`, so each
  column mesh rendered just its first cell — row 0 slivers off the top edge. The
  fix was to build the full 7-triple index table once at module load. The
  verifier's contact sheet caught it; the fix is now noted in the brief.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-triangles-filled-column-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.1582, max 0.1111 |
| knob 2 `offy` | mid 0.1230, max 0.0361 |
| knob 3 `size` | mid 0.3731, max 0.7321 |
| knob 4 `fg` | mid 0.1379, max 0.0000 |
| knob 5 `bg` | mid 0.8470, max 0.8470 |
| audio | quiet 0.1522, loud 0.6623, freq 0.1275 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.08–114.92, min stddev 3.36 |
| `p50_ms` (software GL) | 16.7 (resources 10) |

## Residual risk

- **The audio-*freq* variant came close to a flat frame** during iteration 2
  (stddev 0.0 at one point): the frequency change moves the audio samples' phase,
  and with `rad` added outward on every coordinate a sign flip can shrink the
  triangles toward the cell centre. It passes now (0.1275 change, stddev 3.36),
  but it is the thinnest luma margin in the grid family.
- **`knob4`'s max probe is 0.0000** (mid 0.1379) — the same integer-`fg` effect as
  the other grid rows.
- **`knob2`'s max is only 0.0361** — the odd-column y offset moves cells by up to
  144 px but the triangles are small relative to the grid.
