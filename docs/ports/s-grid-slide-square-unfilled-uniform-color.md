# Port report — `s-grid-slide-square-unfilled-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Slide Square - Unfilled Uniform Color/main.py` (78 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 20; fifth mode of the `grid-slide-square` family, first of the three **Unfilled** variants |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier | owed — blocked (see below) |

## What it does

The family's unfilled, single-colour variant: a 7×10 grid of square **outlines** slid by
the shared `sqmover` oscillator and inflated by one audio sample, all in one per-frame
LFO colour.

## The filled-vs-unfilled diff (confirmed, exactly three differences)

1. `setup()` adds `linew = int(xr*0.0026)` (3 px at the reference 1280) and drops the
   filled variant's unused `color` global.
2. `draw()` gains two parity branches — `if (i%2)==1: x = j*x8-x8+xoffset` and
   `if (j%2)==1: y = i*y5-y5+yoffset` — so the slide offsets are **parity-conditional**
   (odd rows shift `x`, odd columns shift `y`) where the filled variant shifts every cell.
3. The draw call becomes `pygame.draw.rect(screen, color, rect, linew)` — an **outline**.

Everything else — the LFO class, the knob block, the two `update()` advances per row,
`rad = abs(audio_in[j-i]/hund)`, `width = int(knob3*hund)+1`, the centred-rect conversion
and `inflate_ip`, and the single per-frame `color_picker_lfo(knob4)` — is byte-identical,
so the 0.21 phase offset and the LFO re-timing carry over unchanged from the filled
sibling.

## The outline idiom

`e.rect` has **no border-width argument**, so stock's outline is drawn as **four `e.rect`
bars** (top/bottom/left/right) of thickness `linew` forming a perimeter band, with the
bounding box at `width + rad + 2*linew` — the centred-rect conversion accounts for the
outline width rather than shrinking for it. That is **280 `e.rect` calls per frame**
(4 × 70) in **one** colour class (`e.color` once per frame), which is fill-rate cost, not
colour-change cost.

## Mapping

The family's documented conventions throughout: the **14-advances-per-frame** `sqmover`
(two `update()` calls per row, each re-timed `step*30*dt`, both stock clamps), the audio
stride with Python's negative-index wrap (`left[1 + kk*10] * 32768 / hund`), the bg phase
fold `(bg*0.7+0.15) % 1`, the deterministic middle-branch picker, and deviations 8 and 9
(the 1 px step floor and 1 px range fallback for the mutually dependent knobs).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-slide-square-unfilled-uniform-color --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), 300 frames/run, engine sha256 `bc29aeef4021…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `step` | mid 0.0108, max 0.0122 |
| knob 2 `pos` | mid 0.0605, max 0.0638 |
| knob 3 `size` | mid 0.1154, max 0.1436 |
| knob 4 `fg` | mid 0.0000, max 0.0512 |
| knob 5 `bg` | mid 0.9488, max 0.9488 |
| audio | quiet 0.0557, loud 0.1893, freq 0.0806 (threshold 0.001) |
| trigger | `None` — the scene does not reference `ctx.trigger` |
| luma bounds | mean 28.45–67.22, min stddev 6.66 |
| `p50_ms` (software GL) | 16.7 (resources 0) |

**Note on the engine hash:** this run reports engine sha256 `bc29aeef4021…` where every
earlier port in this session reported `454ece7aafe7…` — the engine moved during the
program. The gate passes on both.

## Residual risk

- **knob 1's liveness margin** (0.0108–0.0122 against 0.001) rests on the family's 1 px
  step floor, as in every sibling.
- **knob 4's mid probe reads 0.0000** while its max reads 0.0512 — the sampled LFO colour
  at the mid state matches the baseline at this frame. Live at max, so a probe artefact.
- **280 `e.rect` calls per frame** (the four-bar outline). Same draw-call shape as the
  filled sibling plus 4× the fill; expected to sit near the floor, but the device tier
  gate is owed and currently blocked.
- **Device tier blocked**: `eyesyctl package` refuses while the engine repo carries
  uncommitted source edits (*"engine_sources hash is stale; rebuild before packaging"*),
  and rebuilding would compile unfinished engine work.