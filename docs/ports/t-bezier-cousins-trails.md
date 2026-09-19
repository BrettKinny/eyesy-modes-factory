# Port report — `t-bezier-cousins-trails`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Bezier Cousins - Trails/main.py` (75 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 3 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

A row of cubic-bezier spans whose control points come from the audio window, drawn over a
decaying trail.

## Two defects found, one structural

**1. The cubic span loop overran its own row.** With 21 control points (20 plus a wrap point),
a 4-point window admits only **19** spans, but the loop ran `count` = 20 and read past the end of
the row. The header's own deviation note already said `(pointNumber-1)*6` strokes = 19 spans, so
the loop bound was the error: it is now bounded at `count - 2` and each row is extended by one
wrapped point (`count + 2` = point 2) so the last window fits.

**2. `audio_pass` was `null` — stock reads no audio at all.** The mode passed on every other
check while being structurally incapable of satisfying the gate's reactivity requirement. The
pack's convention (established by `t-ball-of-mirrors-trails`, deviation 5) is to add a
**documented audio term** when stock has no audio path, and that is what this port does: a
level-driven shrink on the primary fill.

That is the second mode in P3 alone whose stock source never touches audio, and it is worth
stating as a general property of the `T -` tranche: the gate requires reactivity, so a mode with
no audio path needs a documented coupling added, not a workaround.

## Deviations

1. **The trail is the pack's half-resolution ping-pong bridge** (640×360), with the veil alpha
   floored at 8/255 so the trail always decays — stock's alpha is 0 at the baseline, which makes
   the trail and any startup audio jitter permanent and fails the determinism precondition.
2. **Geometry inside the target uses the target's dimensions** (`GW`/`GH`), so the figure is not
   clipped to the target's corner — the defect that shipped silently in both P2 bezier modes.
3. **The strokes are batched into meshes** with the quad idiom (never a bare line strip, which
   would join the separate spans).
4. **The audio term added to the fill** (above).
5. The deterministic middle-branch picker, the background phase fold, the 30 → 60 fps re-timing,
   and the stock audio mapping with its own divisor.

## Verification — 2026-09-18 (after the knob-1 fix)

`python3 tools/verify_port.py t-bezier-cousins-trails --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B at 300 frames:

| Knob | mid | max | trig |
| --- | --- | --- | --- |
| 1 `complexity` | **0.03104** | **0.05340** | — |
| 2 `cousins` | 0.01426 | 0.02406 | — |
| 3 `spacing` | 1.00000 | 1.00000 | — |
| 4 `fg` | 0.00000 | 0.00854 | — |
| 5 `bg` | 0.99293 | 0.00314 | — |

**The `trig` column is empty for every knob** — no second-chance run was generated, so knob 1's
figures are its own probes. The table is identical at 60 and 300 frames.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.01624, loud 0.01487, freq 0.00343 — **pass** |
| trigger | standalone variant frac 0.01539, pass |
| luma bounds | 9.26–21.46, min stddev 3.23 |
| `p50_ms` (software GL) | 15.29 / 15.75 |

## The knob-1 defect: the same class as `t-density-units`

Stock computes its point count `int(knob1*16)+4` **only inside its trigger branch**, so between
triggers `pointNumber` stays pinned at the setup roll of 20 and the knob's own probes drew a
byte-identical figure — the ladder §4 class *"a knob whose only consumer is trigger-scoped"*.

The **run-length dependence** explains why it passed at 60 frames and failed at 300: the trail
bridge's fade leaves the 20-point setup figure ~62 % covered at 60 frames (the knob's 4-point
shape partly visible → 0.09928) but ~95 % covered by 300, so the setup figure fully dominates and
the knob's own pixels are gone. Only the trigger's re-roll moved the frame.

**The fix** gives the knob a consumer in the draw path — re-deriving `pointNumber` live each frame
with stock's exact formula (floor of 4, a 3-segment diamond, never degenerate) while keeping
stock's trigger behaviour intact. Documented as deviation 13. Look impact: turning the complexity
knob now re-shapes the closed curve continuously (4..20 points) instead of snapping at the next
trigger; the baseline and the post-trigger figure are unchanged.

Determinism stayed byte-identical despite the per-frame count change, because the engine seeds its
RNG identically for every replay and the trigger — the only per-frame `e.random()` source — does
not fire on the knob probes.