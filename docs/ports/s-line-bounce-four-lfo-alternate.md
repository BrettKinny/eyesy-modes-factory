# Port report — `s-line-bounce-four-lfo-alternate`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Line Bounce Four - LFO Alternate/main.py` (98 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 32 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

Four lines bouncing under a single audio-driven deflection: `b1`/`b2` bounce horizontally
across `0..xres`, `b3`/`b4` vertically over the two halves of the screen. **All four share
one audio sample** — `abs(audio_in[50] / 85)`, the mode's own divisor — so the "bounce" is
the LFOs' motion, not four independent signals.

## What "LFO Alternate" actually means

The name is about the four bouncing **position** LFOs, not the colour. Their steps are
`int(k3*0.0125*xres)+5` and `int(k3*0.0242*xres)+5` (horizontal) and `int(k3*x100/20)+2`
(vertical), and the alternation flag swaps the draw order of the x-line pair and the y-line
pair each arrival.

**The colour is static per knob value**: four **legacy** `color_picker` calls per frame at
`k4`, `(k4+0.25)%1`, `(k4+0.5)%1`, `(k4+0.75)%1`, with no phase state. So
`color_picker_lfo` is never called and **no phase offset applies** — the 0.21 in the file is
only the stock background formula's `cos(3*pi*c)` at `c = 0.21`. Recording this because the
mode's name invites exactly the wrong assumption.

## Deviations

1. **Legacy picker → deterministic middle branch** (`0.5+0.5*sin(2/4/8·π·c)`), `c` folded to 0..1.
2. **Background phase folded** to `c = (k5*0.7+0.15)%1`; the cosine formula kept exactly.
3. **Audio**: stock index 50 → `left[1 + 50*10]` × 32768, **divisor 85 kept stock-exact**.
4. **Stock's coin flip made deterministic.** Stock calls `random.random() < 0.5` on **every
   top-x LFO arrival**; the port toggles the flag deterministically on each arrival instead, so
   replays stay byte-identical. This is the deviation the determinism gate depends on.
5. **30 → 60 fps** re-timing of the LFO steps.

## Rendering

**8 draw calls per frame** — 4 `e.color` + 4 `e.line`, in stock's order (the x-line pair and
the y-line pair swap order with the alternation flag). **Zero meshes, zero render targets**:
four screen-space strokes need neither, so there is no target-coordinate trap to fall into.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-line-bounce-four-lfo-alternate --frames 300` → `"verdict": "pass"`, `failures: []`. All 16 runs in the set passed.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 | 0.02054 | 0.03766 |
| 2 | 0.05556 | 0.10694 |
| 3 | 0.01376 | 0.01376 |
| 4 | **0.00344** | **0.00000** |
| 5 | 0.99311 | 0.99311 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet **0.00168**, loud **0.00057**, freq **0.00054** (threshold 0.001) |
| trigger | not referenced — no `knob*-trig` run exists, so the fallback could not fire |
| luma bounds | mean 28.51–64.46, min stddev 5.94 |
| `p50_ms` (software GL) | 16.67 |

## Residual risk

- **Two of the three audio probes are BELOW the 0.001 threshold** (`audio-loud` 0.00057,
  `audio-freq` 0.00054); the set passes because `audio-quiet` clears it at 0.00168. This is the
  thinnest audio margin in the pack by a wide margin, and it is structural: the mode reads one
  fixed sample (`audio_in[50]`) for a whole-frame deflection, so loud and quiet audio move few
  pixels. A stricter gate, or a different stimulus, could fail it.
- **knob 4's max probe is exactly 0** and its mid is thin (0.00344). At `k4 = 1.0` stock's four
  phases (`1.0`, `1.25`, `1.5`, `1.75` mod 1) fold onto the same four colours as `k4 = 0`, so the
  frame is byte-identical to the baseline — stock-faithful, not a defect. Liveness rests on the
  0.5 probe, as in the bezier siblings.
- **knob 3's two probes read identically** (0.01376) — the LFO step knob changes the bounce rate,
  which at a single grab instant changes little.
- No device tier claim (gate retired); the mode is 8 draw calls with no meshes or targets, so it
  should sit at the floor.