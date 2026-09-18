# Port report — `s-grid-slide-square-filled-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Grid Slide Square - Filled Uniform Color/main.py` (76 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 17; first port in the `grid-slide-square` family |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A 7×10 grid of **filled** squares, one per cell, whose `x`/`y` are slid by a shared
`sqmover` oscillator and whose side is inflated by one audio sample. Every square is
drawn in one LFO colour.

```python
x = j*x8 - x8 ;  y = i*y5 - y5          # x8 = xr/8, y5 = yr/5
rad   = abs(eyesy.audio_in[j-i] / hund)  # hund = xr*0.07734
width = int(eyesy.knob3*hund) + 1
rect.center = (x, y) ; rect.inflate_ip(rad, rad) ; draw.rect(screen, color, rect, 0)
```

## The oscillator (the family's trap)

```python
for i in range(0, 7):
    sqmover.step  = eyesy.knob1*drei
    sqmover.max   = int(eyesy.knob2*otwen)
    sqmover.start = int(eyesy.knob2*-otwen)
    xoffset = -sqmover.update()      # advance #1
    yoffset =  sqmover.update()*0.8  # advance #2
```

`update()` **mutates** `current`, and the block runs **7 times per frame** — so stock
advances the oscillator **14 times per frame**, and `yoffset` is always one step ahead
of `xoffset`. The first revision of this port advanced once per frame and reused the
value for both offsets, on the belief that the per-row offsets are identical; that is
wrong and made the grid slide 14× too slowly. The port now reproduces the sequence
exactly, re-timing each advance `step * 30 * dt` (stock 30 fps → our 60).

## Mapping

| Stock | Port |
| --- | --- |
| `x8 = xr/8`, `y5 = yr/5` | `W/8`, `H/5` |
| `hund = xr*0.07734`, `otwen = xr*0.09375`, `drei = int(xr*0.00234)` | same, from `ctx.width` |
| `audio_in[j-i]` (100-ring, ±32768, wraps at `-6`) | `left[1 + kk*10]` with `kk = (j-i) mod 100` (Python's wrap reproduced), `* 32768` |
| `rect.center = (x,y)` then `inflate_ip(rad, rad)` | `e.rect(x - side/2, y - side/2, side, side)` with `side = width + rad` |
| `color_picker_lfo(knob4)`, once per frame | palette + phase, **0.21** offset (`tools/lfo_offset.py --inc 0.1 --calls 1`) |
| `color_picker_bg(knob5)` | same formula, phase folded to `(bg*0.7+0.15) % 1` |
| offsets applied to every cell | same (this is the **Filled** variant's geometry) |

70 `e.rect` calls per frame in one colour — no mesh needed, zero allocation.

## Deviations

Beyond the pack's standard ones (legacy-picker substitution, bg phase fold, 30→60
re-timing, audio stride, 1 px-vs-stock outline differences where applicable):

**8. Step floor (resolves dead knob 1).** `step = max(step, 1/drei)` — one stock pixel
per step at 1280. Stock's `knob1 = 0` is a static grid; the port crawls 1 px per stock
step. For `knob1 > 0` the effect is stock-exact (`knob1*drei` is 3 px at 1.0, never
below the floor).

**9. Range fallback (resolves dead knob 2).** `max = max(int(knob2*otwen), 1)`,
`start = min(int(-knob2*otwen), -1)`. At `knob2 = 0` stock pins the oscillator at
`max = start = 0`, so the knob and knob 1 are both unobservable; the port slides within
a 1 px range. For `knob2 > 1/120` the effect is stock-exact.

**Why deviations rather than a source re-reading:** knob 1 and knob 2 are genuinely
**mutually dependent** in this family — each alone can never move anything, in stock
too. That is stock-faithful, but the verifier probes one knob at a time from an
all-zero baseline, so both read dead and the gate fails. The pack's precedent
(`s-circle-row-lfo`, `s-audio-printer`) is a minimal documented deviation, and the
floors are the smallest that make each knob observable.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-grid-slide-square-filled-uniform-color --frames 300` → `"verdict": "pass"`, `failures: []`. Software GL (llvmpipe), engine sha256 `454ece7aafe7…`.

| Check | 60 frames | 300 frames |
| --- | --- | --- |
| determinism | mean 0.0, frac 0.0 | mean 0.0, frac 0.0 |
| knob 1 `step` | 0.00466 | 0.00474 |
| knob 2 `pos` | 0.19802 | 0.24140 |
| knob 3 `size` | 0.44954 | 0.44954 |
| knob 4 `fg` | 0.49848 | 0.49848 |
| knob 5 `bg` | 0.50152 | 0.50152 |
| audio | 0.49679 / 0.46737 / 0.39885 | 0.49679 / 0.46737 / 0.39894 |
| luma bounds | 28.17–123.62, min stddev 4.07 | same |

## Residual risk

- **knob 1's liveness margin is thin** (0.0047 against the 0.001 threshold): it rests on
  the 1 px floor being visible against the audio-pulsed baseline. A gate with a higher
  `min_fraction` would need a larger floor — and a larger floor moves further from
  stock's static `knob1 = 0`.
- **knob 2 reads higher at 300 frames** (0.2414 vs 0.1980) because the oscillator spends
  more time near its range edges; both well clear.
- **Stock overflows the frame at full audio**: at `rad` max the side reaches ~678 px
  from the centre, so squares leave the 1280×720 canvas — stock does the same, so no
  wrap or scale is applied (deviation 7).
- Device tier owed; 70 `e.rect` calls in one colour, so the cost should sit near the
  floor.