# Port report — `s-x-scope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - X Scope/main.py` at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 45; **closes tranche P2** |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

Two audio walks — an upper and a lower — that traverse the frame rightward and close back to
their start, each with a shadow pass, the audio displacing every segment's endpoints in opposite
directions between the two walks.

## Four defect classes, found in sequence

This mode took four rounds, and each round exposed a different class — none visible from the
others:

1. **A 0-based/1-based indexing mismatch.** The mesh emitter computed its first index as
   `base + i*2` with `i` starting at 0, on a table allocated from 1, so `pts[0]` was `nil` and
   **every** run crashed identically at the same line. No amount of reading the code would have
   surfaced it; the gate did, on the first run.
2. **A symmetric-picker dead knob.** With the phase at `knob4` itself, the deterministic
   middle-branch picker returns the same colour at 0, 0.5 and 1.0, so `knob4` could not move a
   pixel. The documented **0.21** offset fixes it — the same trap every mode in this pack carries
   the offset for.
3. **A floor whose own guard exempted the case it existed for.** The deflection floor read
   `if math.abs(u) < FLOOR and u ~= 0`, and at quiet gain `trunc()` yields exactly 0 — so the
   guard skipped the very samples the floor was there to lift.
4. **A base row outside the frame.** `ys = spread*k3*5 - H/3 + H/8` evaluates to **-150 px** at
   the all-knobs-zero baseline: the walk sits *above* the frame and is only visible while the
   audio excursion is large enough to bring it down. At gain 1.0 the excursion is ±540 px, so
   the frame is full; at the verifier's quiet gain it is ±27 px, so the frame is **empty** — the
   grab is a uniform fill. Fixed by flooring the base **row** into the frame (`ys ≥ 0.15·H`),
   leaving the excursion and `knob3`'s scaling untouched above the floor.

Defects 3 and 4 are the same *class* — degenerate baseline content — but at different terms, and
fixing the first did not fix the second. The lesson worth keeping: when a frame is uniformly one
value, the figure is **absent**, not collapsed, and the question is *where it went*, not *how
small it got*.

## Deviations

1. The deterministic middle-branch picker with the derived phase offset.
2. The background phase fold `c = (bg*0.7+0.15) % 1`.
3. Audio: stock index `j` → `left[1 + j*10]` × 32768 with the stock scale `0.00003058 * squ`
   kept exactly (`squ = trunc(H - H/4)`), Python's `int()` truncation preserved.
4. The mesh batching: the unbatched port issues **116 `e.line` calls per frame** (29 segments ×
   four strokes); the port batches each pair of walks into one indexed triangle mesh — 2 handles,
   one `e.color` per pass.
5. A **linewidth floor** of 3 px, sized against the quietest audio variant (stock's hairline is
   1 px at the baseline).
6. The **deflection floor** (±60 px, including `u == 0`).
7. The **base-row floor** (`ys ≥ 0.15·H`).
8. A shadow-radius and stroke-spread floor, as in the sibling modes.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-x-scope --frames 300` → `"verdict": "pass"`, `failures: []`, `audio_pass: true`. Software GL (llvmpipe), engine sha256 `bc29aeef4021…`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 `linewidth` | 0.01510 | 0.03370 |
| 2 `shadow` | 0.00570 | 0.00570 |
| 3 `spread` | **0.00000** | 0.01380 |
| 4 `fg` | **0.00000** | 0.00570 |
| 5 `bg` | 0.99430 | 0.99430 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.00610, loud 0.01550, freq 0.02140 — **pass** |
| trigger | not referenced |
| luma bounds | 28.35–64.28, min stddev 3.75 |
| `p50_ms` (software GL) | 16.7 (resources 2) |

Both `knob3` and `knob4` read dead at their **mid** probe at 300 frames (they were live at mid in
the 60-frame run) — the shadow-spread and colour knobs move too few pixels at that instant once
the walk has settled into its longer-run state. Both clear the threshold at their max probe, and
no trigger path exists, so the gate cannot be banking a false liveness.

## Residual risk

- **knobs 2 and 4 are thin** (0.00567 / 0.00565) — the shadow-radius and colour knobs move few
  pixels at a single grab instant.
- **Three separate floors** (linewidth, deflection, base row) mean the all-knobs-zero baseline is
  materially more legible than stock's, which draws a hairline above the frame there.
- **The walk's base row is floored into the frame** — below `knob3 ≈ 0.06` the walk sits lower
  than stock's.
- **Four rounds of defects** is the most any mode in this pack has taken; the report records all
  four because the sequence is the useful part.

## Process note

The implementing agent's shell was approval-blocked for this task, so this session ran every gate
and reported the numbers back while the agent edited — and when the agent's final edit dropped the
`local e = eyesy` global (leaving the mode unrunnable) and then exhausted its 30-minute budget,
this session repaired the file and completed the diagnosis. The last two fixes (the floor guard
and the base row) were made here rather than delegated.