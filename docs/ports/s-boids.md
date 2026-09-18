# Port report — `s-boids`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Boids/main.py` (147 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 29 |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

A 250-agent flocking simulation drawn as discs, over 32 audio VU bars with a stock
`min_height` of 5.

## Determinism (the hard part of a stateful mode)

- **Every stock random draw became `e.random()`** — the engine's seeded PRNG, reset on load
  — **in stock's exact order per boid**: spawn x, spawn y, velocity x, velocity y, colour
  value. Order matters: the same seed consumed in a different sequence gives a different
  flock.
- **The per-boid colour value is fixed at setup**, so each boid's colour class and that
  class's picker colour are static and precomputed once. `draw` issues no picker call for
  the flock, which also keeps the per-frame colour-change count at **16 classes + 1 bar
  colour = 17**, not 250.
- All state — positions, velocities, the per-bar 4-slot audio-history ring, the bar/obstacle
  records and the 16 class member lists — is created in `setup` and mutated in place.
- Both time-dependent quantities (the LFO phase and the flock advance) are re-timed against
  `ctx.dt`, which is what makes the replay check land at mean 0.0 / frac 0.0.
- A degenerate zero-length velocity falls back to `+x` rather than dividing by zero.

## Cost

**Zero meshes** — `e.circle` draws the discs directly, so neither the 32-handle cap nor the
8192/49152 mesh budgets bind this mode. Per frame at the baseline bar style: 1 `e.clear` +
**17 `e.color`** (16 boid colour classes + 1 bar colour) + **128 `e.rect`** (32 bars × 4
inward outline bars) + **250 `e.circle`** = **396 draw calls**; the `knob3 ≥ 0.5` solid branch
draws 300. The colour-class grouping is what keeps this affordable — one colour per class,
not per boid, which the pack measured as the difference between the floor and +13.7 ms.

## Deviations

1. **`random` → `e.random()`** with stock's draw order preserved; a degenerate zero-length
   velocity falls back to `+x` instead of dividing by zero.
2. **Legacy picker → deterministic middle branch** (`0.5+0.5*sin(2/4/8·π·c)`) for both the
   bars' LFO colour and the boids' static colours. Look impact: no random grey / random-RGB
   speckle; the palette is the smooth cosine family.
3. **LFO re-timed 30→60 fps** with the one-call-per-frame phase offset **0.21**.
4. **Background phase fold** `c = (bg*0.7+0.15) % 1`.
5. **Audio**: stock index `i` → `left[1 + i*10]` × 32768 with stock's divisor 32768; the
   per-bar 3-sample history ring ported exactly.
6. **Flock advance re-timed**: `position += velocity * 30 * dt` (600 px/s, stock's 20 px per
   30 fps tick); wrap and bounce tests stock-exact, once per engine frame — the bounce
   resolves more finely at 60 fps.
7. **The bar outline** is four inward `e.rect` bars (`e.rect` has no border width).

## Verification — 2026-09-18

`python3 tools/verify_port.py s-boids --frames 300` → `"verdict": "pass"`, `failures: []`.

Per-probe A/B, fraction of pixels changed:

| Knob | mid | max |
| --- | --- | --- |
| 1 `size` | 0.13160 | 0.35468 |
| 2 `barwidth` | 0.03385 | 0.03475 |
| 3 `barstyle` | 0.08033 | 0.08033 |
| 4 `fg` | **0.00000** | 0.01690 |
| 5 `bg` | 0.98202 | 0.98202 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.01768, loud 0.03638, freq **0.00227** (threshold 0.001) |
| trigger | not referenced — the scene has no trigger, and no `knob*-trig` run exists in the set, so the fallback could not fire |
| luma bounds | mean 28.29–65.13, min stddev 5.68 |
| `p50_ms` (software GL) | 16.57 (resources 0) |

## Residual risk

- **`audio-freq` reads 0.00227 — about 2.3× the 0.001 threshold**, the thinnest audio margin
  in the pack so far. The mode is a flock plus VU bars, so the frequency probe changes little;
  a stricter threshold would need the bars to carry more spectral response.
- **knob 4's mid probe is exactly 0** — stock-faithful (the static picker branch maps
  `knob4 = 0.5` to `picker(0.0)`, the baseline colour); live at max (0.01690). With no
  trigger path the gate cannot be banking a false liveness.
- **396 draw calls per frame** — the highest in the pack so far, though the colour-class
  grouping keeps the colour changes at 17. The measured lever (colour changes) is addressed;
  the raw draw count is dominated by 250 `e.circle` discs, which would be the thing to batch
  if a device gate ever returns.
- **250 agents is stock's count**, kept exactly.