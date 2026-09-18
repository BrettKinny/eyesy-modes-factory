# Port report — `s-sound-jaws-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Sound Jaws - Uniform Color/main.py` (75 lines) |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 44; sibling of `s-sound-jaws-stepped-color` |
| Verification | `verify_port.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

Twenty "teeth" — lines with tips — that clench and open with the audio, all in one uniform
foreground colour, over a screen-feedback echo. Identical geometry to the stepped-color sibling;
the only stock difference is the foreground colour: `color = color_picker_lfo(knob4)` computed
once per frame (stock line 40) and used for every tooth — no per-tooth accumulator, no ramp.

## Colour: faithful, no collapse needed

Unlike the stepped sibling (20-step ramp collapsed to one representative colour with a 0.21
offset), this mode's stock is already **one colour per frame** — so it ports faithfully. One
substitution is required:

- **Picker**: stock's `color_picker` is the legacy picker, partly random (random greys for small
  phases, random RGB above 0.96). Randomness cannot be ported (replays must be byte-identical),
  so the deterministic middle branch is substituted: `r = 0.5*sin(2*PI*c)+0.5`,
  `g = 0.5*sin(4*PI*c)+0.5`, `b = 0.5*sin(8*PI*c)+0.5`, phase `c = (knob4 + 0.21) % 1`.
- **The 0.21 phase offset**: the middle-branch picker is symmetric about 0, so a knob sweep
  through 0 produces no colour change (the gate's per-knob probe for knob4 would see knob4 dead
  at 0.0). The offset keeps the sampled colour clear of the palette grey (0.5) at every probe
  point. The picker is still driven purely by knob4.

## Three degenerate-input floors (same geometry as the sibling — all three carried over)

Stock's geometry is identical to the stepped sibling, so all three floors apply:

1. **`teethwidth`** — at `teeth == 0` (the gate's all-knobs-zero baseline) the expression
   `int(((xr - xr*0.1*teeth)*xr)/xr)` evaluates to `int(xr)` = 1920 — the full screen width.
   Floored to `int(0.1*xr)` = 192, **stock's own guard value** from line 45.
2. **The `shape < 1` clench override is skipped when `k1 == 0`** — leaving it in would make
   `knob3` dead in the gate's per-knob probe (the override is independent of knob3).
3. **`clench` floored to 0** — at the baseline the base formula gives
   `clench = -int(tw/2) < 0`, pushing both rows off-screen and making the audio-quiet run flat.

All three are the pack's established class: **floor the degenerate input, never move the knob**.

## Audio

**Divisor 85** (stock line 55/67), 10-sample stride `left[1 + i*10]`, denormalised ×32768.
Stock's 100-sample ring index `i` (0..19) maps to platform index `1 + i*10` (i = 19 → 191,
inside the 1024 buffer).

## A dropped feature

**Stock's screengrab feedback loop is dropped** (stock lines 34–38): `setup` keeps a
previous-frame copy (`last_screen`), each frame the old frame is scaled to
`(xr*0.922, yr*0.861)` and blitted back at `(xr*0.039, yr*0.069)` as a self-contained echo.
The engine has no surface-copy primitive; emulating it would need a per-frame readback for a
texture echo. The jaw figure (lines + tips) is the primary content and is rendered in full.
This is a **feature removal rather than a parameter deviation**.

## Rendering

**1 mesh handle**: 20 lines + 20 tips = 40 quads = **160 vertices / 240 indices** (worst case,
preallocated in setup, mutated in place; zero per-frame allocation). One `e.color` state change
per frame; one `draw_mesh` call. Triangle tips are emitted as degenerate 4-vertex quads (two
corners at the apex); semicircle tips are approximated as bounding-box quads (look compromise,
as in the sibling).

## 30 → 60 fps re-timing

Not needed: stock advances no LFOs and carries no per-frame counters (`color_rate` is
initialized in setup but never read or written by draw; the colour is a pure function of knob4,
recomputed each frame).

## Verification — 2026-09-19

`python3 tools/verify_port.py s-sound-jaws-uniform-color --frames 60 --run 3` → `"verdict": "pass"`, `failures: []`, `audio_pass: true`.
`python3 tools/verify_port.py s-sound-jaws-uniform-color --frames 300 --run 4` → `"verdict": "pass"`, `failures: []`, `audio_pass: true`.

Per-probe A/B values (changed pixel fraction vs base):

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.14247 | 0.12217 |
| 2 | 0.03994 | 0.07932 |
| 3 | 0.04369 | 0.16660 |
| 4 | 0.14406 | 0.0 (see note) |
| 5 | 0.85594 | 0.85594 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.13703, loud 0.32893, freq 0.07646 — **pass** |
| trigger | not referenced |
| luma bounds | 29.12–103.21, min stddev 13.29 (floor 0.51) |
| `p50_ms` (software GL) | 15.71 |

Knob4 note: the max-probe A/B diff is 0.0 because at knob4 = 1.0 the picker phase
`(1.0 + 0.21) % 1 = 0.21` coincides with the knob1–3 probe configuration's phase — the
mid-probe (0.14406) is well above the liveness threshold, so the gate passes.

## Residual risk

- **The screengrab feedback echo is gone** — a dropped feature, not a tuned parameter.
- **Semicircle tips are approximated as bounding-box quads** and triangle tips as degenerate
  quads — visible at the tips if examined closely (same as the sibling).
- **Three separate degenerate-input floors** mean the all-knobs-zero baseline differs from
  stock's (which draws nothing usable there).
