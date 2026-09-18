# Port report — `s-oscilloscope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Oscilloscope/main.py` (82 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 38 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

An audio waveform drawn as a thick traced line with a drop shadow, the trace's thickness and
vertical position on two knobs.

## Audio and picker

- **Divisor 32768**: `y1 = int(knob2*yres + (audio_in[i*2]*yres)/32768)` — so the port reads
  **even indices of the 100-sample ring**, mapping `audio_in[i*2]` (i = 0..49) to
  `left[1 + i*20]`. The doubled index doubles the stride, and there are no negative indices in
  this mode, so no Python wrap is needed.
- **`color_picker_lfo(knob4, 0.01)` called once per stroke** — 50 calls per 30-fps frame — so its
  phase advances **per element** and the documented 0.21 offset does **not** apply. Stock's
  progression is kept; only the legacy picker's random branches are replaced by the deterministic
  middle branch.
- Stock's `random` import is **unused**.

## The fidelity tradeoff the batching forced (deviation 2)

Stock colours **each of the 50 segments separately**, advancing the ramp per stroke. A mesh draw
carries **one** `e.color`, and the port batches the trace into two meshes, so the whole trace
takes a **single** colour — the frame's final phase (stock's `i = 49`), measured as
`picker(0.25)` = `(255,127,127)` over 15,903 px.

**Stock's trace is a gradient along its length; the port's is one flat colour.** Restoring the
gradient would need one draw per segment — 50 `e.color` calls per frame, which sits against the
pack's measured cost cliff (70 calls measured +13.7 ms, outside tier C). The port chose the
batched form and documented the look impact; this is the clearest fidelity-for-cost trade in the
pack, and it is worth revisiting if the device gate ever returns with a different ceiling.

## Deviations

1. **Legacy picker → deterministic middle branch**; static branch and ramp semantics stock-exact.
2. **The batched single colour** (above), with the LFO re-timed to the per-element rate:
   phase advances `50 * 30 * inc * dt` per frame (0.25/frame at `knob4 = 1.0`).
3. **Background phase fold** `c = (bg*0.7+0.15) % 1`.
4. **Audio** re-mapped from the 100-sample ring to the 1024-sample buffer (`left[1 + i*20]`,
   ×32768), divisor 32768 kept exact, Python's `int()` truncation preserved.
5. Plus the usual: 30 → 60 fps re-timing, the drop shadow drawn per stock.

## Rendering

**2 mesh handles**, both filled exactly every frame — worst case **863 vertices / 2136 indices**
per mesh, inside the 8192 / 49152 caps with room. Per frame: 1 `e.clear` + 2 `e.color` +
2 `e.update_mesh` + 2 `e.draw_mesh` = **7 engine calls**, zero transcendental calls, zero
per-frame allocation.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-oscilloscope --frames 300` → `"verdict": "pass"`, `failures: []`. All 16 runs passed and the trigger fallback never fired.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 `thickness` | 0.39815 | 0.63303 |
| 2 `ypos` | 0.06678 | 0.05566 |
| 3 `shadow` | 0.02002 | **0.00000** |
| 4 `fg` | **0.00000** | 0.01726 |
| 5 `bg` | 0.98274 | 0.98274 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.02368, loud 0.03428, freq 0.06168 (threshold 0.001) |
| trigger | not referenced; 0 trigger-fallback runs in the set |
| luma bounds | 28.68–92.38, **min stddev 8.17** (max 48.78) |
| `p50_ms` (software GL) | 16.67 (resources 2) |

## Residual risk

- **The trace is one flat colour where stock ramps along its length** — the mode's most visible
  deviation from stock, forced by batching (above).
- **`knob3`'s max probe is exactly 0 and `knob4`'s mid is exactly 0** — both stock-faithful:
  `knob4 = 0.5` folds to `picker(0)`, the baseline grey, and the shadow knob saturates at its
  top setting. Each is live at its other probe point (0.02002 and 0.01726, both above the
  threshold), and with no trigger path the gate cannot be banking a false liveness.
- **`knob2` (0.0557–0.0668), `knob3` (0.0200) and `knob4` (0.0173) are thin** — a thin trace
  moves few pixels, and the shadow and colour knobs act on narrow bands.
- **Sound margins otherwise**: `min stddev 8.17` is comfortable against the 0.51 floor, and the
  frame reaches luma 92.38.