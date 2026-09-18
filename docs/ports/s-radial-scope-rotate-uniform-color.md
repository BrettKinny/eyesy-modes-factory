# Port report — `s-radial-scope-rotate-uniform-color`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Radial Scope - Rotate Uniform Color/main.py` (68 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 40; sibling of `s-radial-scope-rotate-stepped-color` |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []`, `audio_pass: true` |
| Device tier | retired (repo-only) |

## What it does

75 radiating strokes from the screen centre — lines with tip circles below `knob3 = 0.5`, lines
only above it — rotating at a rate set by `knob1`, with the radius carrying the audio.

## The family's real difference is the picker, not the drawing

Both radial scopes call **`color_picker_lfo(knob4)` inside `seg()`** — the same call site. What
separates "stepped" from "uniform" is how the runtime's LFO behaves, and the agent read the real
implementation to settle it:

```python
def color_picker_lfo(self, knob_val, inc_amt=.1):
    self.color_lfo_index = (self.color_lfo_index + self.color_lfo_inc) % 2
    if knob_val <= .5:
        return self.color_picker((knob_val * 2) % 1)     # PURE — uniform
    else:
        self.color_lfo_inc = (knob_val - .5) * 2 * inc_amt
        ...                                              # per-call phase → stepped
```

So **at and below `knob4 = 0.5` the LFO is a pure function of the knob** — every call in a frame
returns the same colour, and the scope is genuinely uniform. Above 0.5 it advances a phase **per
call**, which is where the stepped sibling's rainbow comes from. The distinction is in the
runtime, not in the two modes' sources — which is why reading the mode's own `main.py` would
never have revealed it.

## The `R1` floor

Carried from the sibling, and it is essential here too: stock's radius is
`R1 + abs(audio_in[i]) / ((x800*20/(R1+1)) + 1)` with `R1 = int(knob2*x800)`, so the
all-knobs-zero baseline collapses the whole scope to a ~2 px dot — a flat frame, a dead rotation
knob and no audio reactivity, three gate failures from one cause. The floor goes on **`R1`**, the
size input, never on the knob.

## Rendering

**1 mesh handle**, one quad per spoke, with **one `e.color` per frame** — the honest case here,
since the uniform branch genuinely is one colour. The pack's measured cost is colour *state
changes*, and there is one.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-radial-scope-rotate-uniform-color --frames 300` → `"verdict": "pass"`, `failures: []`, `audio_pass: true`.

| Knob | fraction (max probe) |
| --- | --- |
| 1 `rotation` | 0.08753 |
| 2 `diameter` | 0.47624 |
| 3 `linewidth` | 0.03204 |
| 4 `fg` | 0.04334 |
| 5 `bg` | 0.95666 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.02009, loud 0.06002, freq 0.00314 (threshold 0.001) — pass |
| trigger | not referenced |
| luma bounds | mean 29.8–…, **min stddev 16.8** |
| `p50_ms` (software GL) | 16.6 |

**`knob1` reads 0.08753 here against the stepped sibling's 0.00585** — a fifteenfold better
rotation margin, because the uniform mode draws a legible scope at the floored radius without
the sibling's colour collapse muddying the frame.

## Residual risk

- **`knob4`'s max probe is 0 by construction**: at `knob4 = 1.0` the LFO's `(knob_val*2) % 1`
  folds back to the same colour as `knob4 = 0`, so the frame is byte-identical to the baseline.
  Stock-exact; the knob is live at mid (0.04334). No trigger path exists, so no false liveness.
- **The `R1` floor** means below `knob2 ≈ 0.05` the scope is a 40 px star where stock draws a
  sub-pixel dot.
- **`audio-freq` is thin** (0.00314) though clear of the threshold — the radius carries the
  waveform, not the spectrum.
- **Above `knob4 = 0.5` the mode is *not* uniform in stock**: the LFO's per-call phase makes the
  75 segments differ. The port follows whatever the source does there; the deviation record
  should be read alongside the stepped sibling's, since the two modes share this picker.