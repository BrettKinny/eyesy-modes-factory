# Port report — `s-line-traveller`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Line Traveller/main.py` (45 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P1 (pure S, small) — implemented by `local-agent`, 3 iterations |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

One horizontal stroke that walks the frame: `y` and `x` accumulate their speeds and
wrap at the frame edge, the stroke's half-length is `L = audio_in[0]/6 + 1`, and its
thickness is `knob1*360 + 1`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` size | `e.param("size", 0.5, 0, 1, 1)` → `max(4, floor(knob1*360)+1)` (deviation 6) |
| `knob2` y speed | `e.param("yspeed", 0.5, 0, 1, 2)` → `floor(knob2*20)*30*ctx.dt` per frame |
| `knob3` x speed | `e.param("xspeed", 0.5, 0, 1, 3)` → `floor(knob3*40)*30*ctx.dt` per frame |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO picker, once per frame, phase offset 0.21 |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `peak = audio_in[0]` | `left[1] * 32768` |
| `L = peak/6 + 1` | `math.min(640, math.abs(peak)/6 + 1)` (deviation 5) |
| `pygame.draw.line(...)` | `e.line(x - L, y, x + L, y, thick)` |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO phase offset 0.21** (`tools/lfo_offset.py --inc 0.1 --calls 1`, 38.85
   luma-unit clearance) and re-time `30 * inc * ctx.dt` per frame.
4. **Accumulator re-time** — stock added the speeds once per frame at 30 fps; the
   port multiplies by `30 * ctx.dt` and keeps stock's *upper-bound-only* wrap
   (`y > 720 → 0`, `x > 1280 → 0`).
5. **Reach clamped into the frame** `L = min(640, |peak|/6 + 1)`. Stock's reach is
   ±1900 px at the verifier's audio gain, so the stroke always spans the full width
   and the audio never changes a pixel — the first gate run measured audio
   reactivity 0.0000. The clamp lets a quiet input draw a visibly shorter stroke;
   the arithmetic is stock-exact for every reach inside the frame.
6. **Stroke thickness floor of 4 px.** Stock's baseline is a one-pixel hairline
   (~640 lit pixels) at the top edge; the gate needs a knob change to move 921
   pixels, and neither a colour change nor an audio change can at 1 px. The same
   floor as `S - Five Lines Spin`; `knob1` still scales 4 → 361 px.
7. **Audio stride** — `audio_in[0]` → `left[1]`, denormalized by 32768.

Two failures preceded the pass: a draw-order bug (advancing `x`/`y` before drawing,
where stock computes the endpoints first) and the hairline/legibility problem
above.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-line-traveller --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `size` | mid 0.0688, max 0.1332 |
| knob 2 `yspeed` | mid 0.0057, max 0.0057 |
| knob 3 `xspeed` | mid 0.0016, max 0.0029 |
| knob 4 `fg` | mid 0.0000, max 0.0029 |
| knob 5 `bg` | mid 0.9971, max 0.9971 |
| audio | quiet 0.0023, **loud 0.0000, freq 0.0000** (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.06–64.18, **min stddev 2.19** |
| `p50_ms` (software GL) | 16.7 (resources 0) |

## Residual risk — the thinnest mode in the pack

- **The audio check rests entirely on the quiet variant.** With the reach clamped
  at 640, both the loud and frequency variants saturate to byte-identical frames
  (0.0000) — only `audio-quiet` differs (0.0023). A gate that probed only loud
  audio would read this mode as non-reactive, and a future revision should carry
  the audio in a second place (the stroke's y offset, say) rather than relying on
  the clamp.
- **`knob3` and `knob4` pass at ~0.0029**, three times the threshold, against
  `min stddev 2.19` (four times the flatness floor). Both are genuinely small
  effects: one thin stroke moving a few pixels.
- **`knob2`'s mid equals its max** (0.0057) — the y accumulator wraps to the same
  place at both probe points.
