# Port report — `s-arcway-black`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Arcway Black/main.py` (57 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Generation | OS v3, Python/pygame (30 fps, 100-sample audio ring) |
| Tranche | P1 (pure S, small) |
| Implemented by | `local-agent`, 1 iteration (first 60-frame run passed) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | see "Device tier" below — the absolute threshold is not measurable on the current device state |

## What the stock mode does

Two discs of 100 arcs each (3.6° per arc, 250 px radius) on a cosine-palette
background: a black disc rotated by `rotation_factor - knob3` and an LFO-coloured
disc rotated by `rotation_factor`. Each arc is displaced per-arc by one audio
sample and by ∓`0.1*width`, so the black disc reads as a shadow behind the
coloured one. `knob2` sets a signed rotation rate (left half counter-clockwise,
right half clockwise); `toplimit`/`leftlimit` are computed in stock `setup` and
never used.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` width | `e.param("width", 0.5, 0, 1, 1)` → `floor(knob1*65)+1` px |
| `knob2` rotation rate | `e.param("rate", 0.5, 0, 1, 2)` → signed rate `rate = knob2*2` or `-(knob2*2-1)` |
| `knob3` bottom-disc offset | `e.param("detune", 0.5, 0, 1, 3)` → angular shift of the black disc |
| `knob4` disc colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO picker |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `rotation_factor += rate` per frame @30 fps | `rotation_factor += rate * 30 * ctx.dt` |
| `audio_in[i]` (100-entry ring, ±32768) | `ctx.audio.left[1 + i*10] * 32768`, displacement `A/500` |
| `color_picker_lfo(knob4)` (200 calls/frame) | deterministic middle branch; phase advances `6000 * inc * ctx.dt` per frame |
| `color_picker_bg(knob5)` | exact cosine formula, phase remapped |
| `pygame.draw.arc(..., width)` | `e.line` chord between the arc endpoints (deviation 6) |
| 200 arcs × 2 discs | 200 `e.color` + `e.line` pairs per frame, no render targets |

## Deviations (all documented in the mode header)

1. **Palette substitution** — the legacy picker is partly random; the
   deterministic middle branch replaces it, with stock's LFO semantics
   (`inc_amt = 0.1`, 0→2→0 fold, `inc` persisting across frames) intact.
2. **LFO re-time** — 200 calls/frame at 30 fps = `6000·inc` per second; the phase
   advances once per frame by `6000 * inc * ctx.dt`, keeping the within-frame
   per-arc step stock-exact.
3. **Rotation re-time** — stock added the signed rate once per frame at 30 fps;
   the port adds `rate * 30 * ctx.dt`, the same rate per second. The factor is
   never wrapped, exactly as stock never wrapped it.
4. **Audio stride** — 100-sample ring → `left[1 + i*10]`, denormalized by 32768.
5. **Background phase remap** — `(bg*0.7 + 0.15) % 1`; stock returns pure white at
   `c = 1` and near-black at `c = 0`, both verifier-rejected.
6. **Arcs as chords** — the API has no arc primitive. Each 3.6° arc of the 250 px
   circle is one thick `e.line` between the arc's endpoints
   `p(θ) = (cx + 250·cos θ, cy − 250·sin θ)` (y negated: pygame angles are y-up).
   The chord deviates from the arc by 0.12 px at this radius — visually exact.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-arcway-black --frames 300` →
`"verdict": "pass"`, exit 0. Software GL (llvmpipe), 300 frames/run, engine
sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0000 |
| knob 1 `width` | mid 0.0638, max 0.1282 |
| knob 2 `rate` | mid 0.0036, max 0.0036 |
| knob 3 `detune` | mid 0.0017, max 0.0000 |
| knob 4 `fg` | mid 0.0000, max 0.0014 |
| knob 5 `bg` | mid 0.9980, max 0.9980 |
| audio | quiet 0.0039, loud 0.0040, freq 0.0038 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | every grab within (0.0255, 251.2), stddev ≥ 2.84 |
| `p50_ms` (software GL) | 15.9 (resources 0) |

## Residual risk

- **Knobs 2–4 pass with thin margins** (0.0014–0.0036 against a 0.001 threshold).
  Knob 3 is the interesting one: at the verifier's baseline `width = 1`, the black
  disc is offset by only `0.2*width = 0.2 px`, so rotating it by π barely changes
  a pixel — that is stock's own behaviour, not a port defect, but a re-run on a
  different harness could read the knob as dead.
- **`rotation_factor` grows without bound** (stock's did too). At the verifier's
  300 frames it reaches ~75 rad; a long soak would reach ~10⁵ rad, where
  `cos`/`sin` precision is still adequate in doubles but the factor is no longer
  meaningful as an angle.
- **200 draw calls per frame** — the heaviest P0/P1 port so far. Device tier is
  owed; see the ladder's device-gate note (the device's floor is currently above
  the tier-C ceiling, so the gate is measured against the floor).
