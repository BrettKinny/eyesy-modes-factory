# Port report — `s-sound-jaws-stepped-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Sound Jaws - Stepped Color/main.py` at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 43 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

Twenty "teeth" — lines with tips — that clench and open with the audio, over a screen-feedback
echo.

## Three degenerate-input floors were required (deviation 7)

An earlier attempt at this mode **drew nothing at all** — every run flat, `stddev 0.0`. Three
separate degenerate inputs were collapsing the figure:

1. **`teethwidth`** — at `teeth == 0` stock's expression evaluates to the **full screen width**
   (1920), and the clench override then pushes both rows off-screen. Floored to
   `int(0.1*W)`, **stock's own guard value** from line 44.
2. **The `shape < 1` clench override is skipped when `k1 == 0`** — leaving it in would make
   `knob3` dead in the gate's per-knob probe.
3. **`clench` floored to 0** — at the baseline the base formula gives a *negative* clench, pushing
   the rows off-screen and making `audio-quiet` flat.

All three are the pack's established class: **floor the degenerate input, never move the knob**.
This is the densest instance of it so far — three inputs in one mode, each independently capable
of emptying the frame.

## Audio and colour

- **Divisor 85**, 10-sample stride `left[1 + i*10]`, denormalised ×32768.
- The picker is the **legacy `color_picker`** (partly random in stock), substituted with the
  deterministic middle branch.
- **The 20-step ramp is collapsed to one per-frame colour** (deviation 5): `picker((lastcol2 +
  0.21) % 1)`, where `lastcol2` is stock's own carried accumulator advanced by its final-`i`
  value (19) once per frame. `knob4` drives the per-frame step size, so a knob change recolours
  the whole figure. **Fidelity loss: the stepped ramp itself.**

## A dropped feature (deviation 4)

**Stock's screengrab feedback loop is dropped.** The engine has no surface-copy primitive, and
emulating it would need a per-frame readback for a texture echo — so the mode loses that echo.
This is a **feature removal rather than a parameter deviation**, and it is the most significant
fidelity loss in the pack after the colour collapses. It should be revisited if the engine ever
gains a screen-feedback path.

## Rendering

**1 mesh handle**: 20 lines + 20 tips = 40 quads = **160 vertices / 240 indices**, preallocated
and mutated in place. Triangle tips are emitted as degenerate quads; semicircle tips are
approximated as bounding-box quads (deviation 6) — both are look compromises worth noting.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-sound-jaws-stepped-color --frames 300` → `"verdict": "pass"`, `failures": []`, `audio_pass: true`.

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.14247 | 0.12217 |
| 2 | 0.03994 | 0.07932 |
| 3 | 0.04369 | 0.16660 |
| 4 | 0.14406 | 0.14406 |
| 5 | 0.85594 | 0.85594 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.13703, loud 0.32893, freq 0.07646 — **pass**, and comfortably live |
| trigger | not referenced |
| luma bounds | 28.3–64.86, min stddev 2.11 |
| `p50_ms` (software GL) | 16.61 / 16.65 |

The audio margins are among the healthiest in the pack (0.137 / 0.329 / 0.076) — a sharp
contrast with the line-bounce and mirror-inverse modes that sat below or barely above the
threshold.

## Residual risk

- **The screengrab feedback echo is gone** (deviation 4) — a dropped feature, not a tuned
  parameter.
- **The 20-step colour ramp is collapsed to one colour** (deviation 5).
- **Semicircle tips are approximated as bounding-box quads** and triangle tips as degenerate
  quads (deviation 6) — visible at the tips if examined closely.
- **`min stddev 2.11`** is thin (floor 0.51).
- **Three separate degenerate-input floors** mean the all-knobs-zero baseline differs from
  stock's (which draws nothing usable there).

## Process note

This is the second attempt at this mode. The first was given a **stock path that does not exist**
(`S - Sound Jaws`, where the library has `- Stepped Color` and `- Uniform Color`), spent its full
budget hunting, and produced a port that drew nothing. Ladder §5 now requires verifying the stock
path and slug from `porting-queue.json` before writing a brief.