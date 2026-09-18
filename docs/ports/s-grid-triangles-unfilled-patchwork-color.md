# Port report — `s-grid-triangles-unfilled-patchwork-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Triangles - Unfilled Patchwork Color/main.py` (45 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (grid family, row 10 of 11) — implemented by `local-agent`, 1 iteration |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

The intersection of the two triangle variants: 7×10 triangles drawn as 8 px
outlines (not filled) with the three-phase patchwork colour rule applied per cell.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` x offset | `e.param("offx", 0.5, 0, 1, 1)` → `floor(knob1*160)` on odd rows |
| `knob2` y offset | `e.param("offy", 0.5, 0, 1, 2)` → `floor(knob2*144)` on odd columns |
| `knob3` triangle size | `e.param("size", 0.5, 0, 1, 3)` → `width = floor(knob3*80.64)+1` |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → patchwork phases (below) |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rad = abs(audio_in[j-i]*0.00003058*320)` | `abs(left[1 + wrap(j-i)*10] * 320)` |
| `pygame.draw.polygon(points, lineWidth)` | three `e.line` calls of width 8 |

**Patchwork colour rule** (stock's order, last match wins): `phase = fg`;
`if j%2 == 1 then phase = (0.4+fg)%1`; `if (j+i)%3 == 1 then phase = (0.8+fg)%1`.

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **Negative audio index wrapped** (`j-i` reaches −6).
4. **Outlines as three lines** of width 8 (no mesh handles needed).
5. **No LFO phase offset needed** — `color_picker` with static phases.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-triangles-unfilled-patchwork-color --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `offx` | mid 0.1510, max 0.1689 |
| knob 2 `offy` | mid 0.1768, max 0.1650 |
| knob 3 `size` | mid 0.4091, max 0.4640 |
| knob 4 `fg` | mid 0.1313, max 0.0000 |
| knob 5 `bg` | mid 0.8072, max 0.8072 |
| audio | quiet 0.1983, loud 0.5107, freq 0.2884 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.54–68.09, min stddev 6.16 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk

- **`knob4`'s max probe is 0.0000** (mid 0.1313) — the family's integer-`fg`
  signature.
- **210 immediate `e.line` calls per frame** (70 triangles × 3), the same cost
  profile as the other outline rows; device tier owed.
