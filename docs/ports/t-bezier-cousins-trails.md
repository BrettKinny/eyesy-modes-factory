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

## Verification — 2026-09-18

`python3 tools/verify_port.py t-bezier-cousins-trails --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 `complexity` | **0.00000** | **0.00000** |
| 2 `cousins` | 0.09360 | 0.15250 |
| 3 `spacing` | 1.00000 | 1.00000 |
| 4 `fg` | 0.00000 | 0.05480 |
| 5 `bg` | 0.96330 | 0.01220 |

| Check | 300 frames | 60 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| audio | quiet 0.10070, loud 0.08680, freq 0.01490 — **pass** | 0.10066 / 0.08677 / 0.01491 |
| trigger | **True** — a trigger run was performed | — |
| luma bounds | 9.41–23.58, min stddev 5.77 | — |
| `p50_ms` (software GL) | 16.7 (resources 3) | 16.6 |

Knob 3's full-frame fraction (1.00000) means it changes every pixel — it is the spacing control,
so its states differ from the baseline by construction.

## Residual risk

- **`knob 1` is dead at 300 frames and the pass rests on the trigger fallback.** Both of its probe
  points read `0.00000` there, while the same knob read **0.09928** at 60 frames — so its liveness
  is run-length dependent, and the gate's second chance (a MIDI trigger, which this mode does
  reference) is what carries the verdict. `docs/PORTING-LADDER.md` §3.4 forbids banking that:
  *"a mode whose trigger re-randomises geometry can then 'pass' on the trigger's effect rather
  than the knob's. That is a false liveness — fix the knob's own visibility instead of relying on
  it."* **Fix queued.** Note this is the *second* mode in this session to show the pattern at 300
  frames after passing at 60 (`s-amp-color-5gon-filled` was the first), which suggests it is worth
  checking every future port's 300-frame per-probe table rather than only the verdict.
- **The audio term is an addition to stock**, not a port of it: the mode's reactivity is the
  port's design, not the original's behaviour.
- **The trail is half resolution**, so it reads softer than stock's.
- **The veil-alpha floor** means the baseline trail decays where stock's would persist.
- **The mesh batching** collapses the spans' individual geometry into batched draws; the look is
  the same (solid 1 px quads), but the construction differs.