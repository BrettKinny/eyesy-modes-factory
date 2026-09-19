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

## Verification — 2026-09-18 (after the knob fix)

`python3 tools/verify_port.py t-density-units --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B at 300 frames:

| Knob | mid | max | trig |
| --- | --- | --- | --- |
| 1 | 0.02351 | 0.03076 | — |
| 2 | **0.01924** | **0.01887** | — |
| 3 | **0.19361** | **0.19361** | — |
| 4 | 0.00000 | 0.00788 | — |
| 5 | 0.99212 | 0.99212 | — |

**The `trig` column is empty for every knob** — the verifier only generates a second-chance run
when a knob's mid *and* max both read zero, so no `knob2-trig`/`knob3-trig` run exists at all.
Every non-zero number for knobs 2 and 3 is now their **own** probe.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.00829, loud 0.03218, freq 0.01623 — **pass** |
| trigger | standalone variant frac 0.01656, pass |
| luma bounds | 28.04–64.50, min stddev 1.99 |
| `p50_ms` (software GL) | 16.58 / 16.64 |

Visual confirmation from the grabs: at `knob3 = 0` the units are thin 1 px outlines (stock's
`width = int(size*0)+1`); at mid/max they are solid (stock's `width 0` = filled), 0.79 % → 20.1 %
bright pixels. At `knob2` mid/max the scatter is visibly pulled inward from the frame edges and
then into a centre band.

## The false liveness, and its root cause

Before the fix, knobs 2 and 3 read `0.00000` at **both** of their own probe points, with their
only non-zero figures under `trig` — the verifier's MIDI-trigger second chance, which ladder §3.4
forbids banking.

**The root cause is a genuine stock subtlety**: stock computes `xdensity`/`ydensity` from `knob2`
but consumes them **only inside the trigger re-roll** (`if trigger: pList = [...randrange(-dscale
+ xdensity, ...)]`). The port rolled absolute pixel positions once in `setup()` and never re-mapped
them, so **between triggers `knob2` had no consumer in the draw path at all** — its probes were
byte-identical to the baseline. Stock behaves the same way; the knob only acts when a trigger
fires.

**The trap in the tooling**, worth carrying forward: the verifier wrapper's summary `knob_frac`
surfaces the **trigger** value when a knob's own probes are dead, so the implementing agent
reported `knob2: 0.25942` and `knob3: 0.35362` as live numbers. **The per-probe table is the only
place the distinction is visible**, and every brief now requires it.

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