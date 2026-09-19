# Port report — `t-draws-hashmarks-angled-stepped-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Draws Hashmarks - Angled - Stepped Color/main.py` (70 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 9; first of the four-mode `T - Draws Hashmarks` family |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

Angled hashmark strokes drawn across the frame, each coloured separately.

## The flat frame, and the answer

The first pass returned **`flat frame, stddev 0.0` on every one of its 18 runs** — the scene was a
single colour because the strokes never rendered. The implementing agent asked whether `e.line`
renders on this build at all; it does (`s-googly-eyes` draws 100 strokes per frame with it, and
both `s-line-bounce-*` modes are pure `e.line`), so the question was answered with the real cause:

**`e.line` takes its width literally — a width of 0 draws NOTHING**, where pygame treats
`width <= 0` as 1 px. A stock `int(knob*span) + 1` that loses its `+ 1`, or any path that can
compute 0, makes the whole figure vanish. That is now recorded in ladder §3 alongside the `e.rect`
note, as the same trap in the other primitive.

The earlier failing pass also listed `knob2-trig`/`knob3-trig`/`knob4-trig` rows — the knobs that
were weak *while the scene was empty* — which is a useful illustration of the verifier's
second-chance mechanics: those rows appear only for knobs already dead at both own probes.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-draws-hashmarks-angled-stepped-color --frames 300` → `"verdict": "pass"`, `failures: []`.

| Probe | mean | frac | trig |
| --- | --- | --- | --- |
| base | 33.46 | — | — |
| knob1-mid / -max | 10.30 / 34.30 | 0.10407 / **0.34645** | not run |
| knob2-mid / -max | 3.58 / 10.57 | 0.03611 / 0.10677 | not run |
| knob3-mid / -max | 3.56 / 5.78 | 0.03594 / 0.05840 | not run |
| knob4-mid / -max | 0.00 / 2.67 | **0.00000** / 0.05514 | not run |
| knob5-mid / -max | 34.01 / 26.46 | 0.94486 / 0.94486 | not run |
| audio quiet / loud / freq | 2.67 / 2.37 / 2.22 | 0.02695 / 0.02396 / 0.02246 | — |
| trigger | 1.64 | 0.01653 | — |

**No `knobK-trig` run was executed at all** — every knob is live at mid or max, so the second
chance never fired. `knob4-mid`'s 0.0 is the documented genuine no-op (`knob4 = 0.5` folds to
phase 0.0 = the baseline grey), with liveness on its max probe.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.02695, loud 0.02396, freq 0.02246 — **pass** |
| luma bounds | 32.43–67.47, min stddev 14.38 |
| `p50_ms` (software GL) | 16.66 (resources 0) |

Grab stddevs run 14.38 (the tightest probe) to 46.76 — all far above the 0.51 flatness floor, a
healthy contrast with the modes that scraped past it.

## Residual risk

- **`knob4`'s mid probe is a no-op by construction** (stock-faithful), so its liveness rests on
  max alone.
- **The `T -` tranche's audio term is an addition to stock** if this mode reads none — check the
  header's deviation list.
- **The mode's colour is per element**, so it carries the usual per-element colour-change cost.

## Family note

The three siblings differ along two axes — `Angled` vs not, and `Stepped` vs `Uniform` — and as
with the `T - Bits` family the `Stepped`/`Uniform` distinction is the **picker's call site**
(per element vs once per frame), not a different formula. The siblings are dispatched with that
stated rather than left to be rediscovered.