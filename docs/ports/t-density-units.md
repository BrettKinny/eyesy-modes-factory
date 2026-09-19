# Port report — `t-density-units`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Density Units/main.py` (53 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 8 |
| Verification | `scene_verify.py --frames 300` — **pass**, but **knobs 2 and 3 are dead and the pass rests on the trigger fallback** — see below |
| Device tier | retired (repo-only) |

## What it does

Thirty "density units" laid out across the frame, sized by a knob and coloured by an LFO.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-density-units --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B at 300 frames — **this is the table that matters**:

| Knob | mid | max | trig |
| --- | --- | --- | --- |
| 1 | 0.37167 | 0.68894 | — |
| 2 | **0.00000** | **0.00000** | 0.25942 |
| 3 | **0.00000** | **0.00000** | 0.35362 |
| 4 | **0.00000** | 0.18860 | — |
| 5 | 0.81140 | 0.81140 | — |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.18785, loud 0.77891, freq 0.11093 — **pass** |
| trigger | `trigger_pass: true`, frac 0.35362 |
| luma bounds | 28.07–123.78, min stddev 2.70 |
| `p50_ms` (software GL) | 16.64 / 16.66 |

## The false liveness — two knobs, not one

**`knob 2` and `knob 3` read `0.00000` at BOTH probe points**, and the only non-zero figures for
them in the whole table are under `trig`. So the verdict rests entirely on the verifier's
MIDI-trigger second chance for those two knobs — the pattern ladder §3.4 forbids banking.

Worse, the implementing agent reported them as live: the wrapper's summary `knob_frac` surfaces
the **trigger** value when a knob's own probes are dead, so `knob2: 0.25942` and
`knob3: 0.35362` in its report are the trigger's numbers, not the knobs'. The per-probe table is
the only place the distinction is visible.

**Fix queued.** This is the **third** mode this session to pass on a trigger fallback after the
`T -` tranche began, and the first where the agent's own summary masked it — which is worth
carrying into the briefs: *report the per-probe table, and treat a `trig` column as evidence the
knob is dead, not as the knob's number.*

## Deviations

1. The deterministic middle-branch picker (stock's legacy picker is partly random).
2. The LFO ramp re-timed 30 → 60 fps.
3. **A phase offset of 0.21** — the agent derived it for `inc_amt = 0.15` at one ramp advance per
   frame (all 30 calls see the same index, so the call count is one per frame, not 30).
4. **No degenerate floors were needed** — stock's 30 units at ~200 px cover a large fraction of
   the frame at the verifier's seed, so the baseline is not flat. Stock-exact geometry, unlike the
   `T - Bits` siblings.
5. The background phase fold `c = (knob5*0.7+0.15) % 1`.
6. **An audio term was added** (stock reads none): each unit's size extended by
   `|left[1 + j*3]| * 0.25 * W`, 30 units → 90 samples, inside the buffer.

## Rendering

30 `e.rect` calls (stock's exact loop bound), **1 `e.color` per frame** plus the clear.

## Residual risk

- **knobs 2 and 3 are dead at 300 frames** and the pass rests on the trigger — the fix is queued.
- **`min stddev 2.70`** is on the thin side (floor 0.51).
- **The audio term is an addition to stock** — the mode's reactivity is the port's design.
- **The 0.21 offset is applied to a colour that stock's own ramp would sample differently** — the
  usual documented consequence of making a once-per-frame picker legible.