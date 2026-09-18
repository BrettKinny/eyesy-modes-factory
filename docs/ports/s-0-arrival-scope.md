# Port report — `s-0-arrival-scope`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - 0 Arrival Scope/main.py` (63 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — first row; implemented by `local-agent`, 5 iterations plus one steered correction |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A VU meter of `count` boxes centred on the vertical middle, each box's height
driven by one audio sample, drawn as a rounded rectangle whose border thickness and
corner radius come from `knob3`.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` number of boxes | `e.param("count", 0.5, 0, 1, 1)` → `check_even(floor(knob1*80)+20)` |
| `knob2` box width | `e.param("width", 0.5, 0, 1, 2)` → `max(12, floor(knob2*spacing)+2)` (deviation 5) |
| `knob3` fill / line width | `e.param("fill", 0.5, 0, 1, 3)` → outline below 0.5, solid above (stock-exact) |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO picker once per frame, phase offset 0.21 |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `audio_in[i]*720/32768` | `floor(abs(left[1 + i*10]) * 720) + 5` |
| `pygame.draw.rect(..., fill, corner)` | `e.rect` — solid, or four bars for an outline |

## Deviations (in the mode header)

1. **Deterministic middle-branch palette** for the legacy random picker.
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **LFO phase offset 0.21** (once-per-frame picker; `tools/lfo_offset.py --inc 0.1
   --calls 1`), phase advanced `30 * inc * ctx.dt` per frame.
4. **Audio stride** — stock index `i` → `left[1 + i*10]`, denormalized by 32768.
5. **`e.rect` has no radius and no border width**, so stock's rounded rect becomes:
   the corner radius is dropped, and the outline is four `e.rect` bars with
   never-invert clamps. **Plus a box-width floor of 12 px**: at the verifier's
   baseline `knob2 = 0` the box is 2 px wide, so stock's 1 px border is
   pixel-identical to a solid fill and `knob3` reads dead (stock itself would read
   dead there). The floor makes the hollow interior visible; `knob2` still scales
   12 → 130 px.
6. **`check_even` is stateful in stock** — it remembers the last even value it saw
   (starting at 2) and returns it for an odd input; ported with a file-local.

## The correction worth recording

The agent's first passing fix **inverted `knob3`'s semantics** (solid below 0.5,
outline above) to make the knob observable. That would have mirrored the knob
across half its travel, so it was rejected and corrected to stock's own order —
outline below 0.5, solid at and above — with the *box-width floor* doing the work
instead. The mode passes either way; only one of them is still the stock scene.
This is the first case in the program where a fix was functionally sufficient but
semantically wrong, and it is the reason the correction loop exists.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-0-arrival-scope --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `count` | mid 0.0410, max 0.0631 |
| knob 2 `width` | mid 0.0201, max 0.0208 |
| knob 3 `fill` | mid 0.0479, max 0.0479 |
| knob 4 `fg` | mid 0.0000, max 0.0101 |
| knob 5 `bg` | mid 0.9899, max 0.9899 |
| audio | quiet 0.0099, loud 0.0159, freq 0.0058 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 28.18–65.24, min stddev 4.1 |
| `p50_ms` (software GL) | 16.6 (resources 0) |

## Residual risk

- **`knob3`'s mid and max probes are identical** (0.0479): stock is solid at both,
  so the knob is live only against the baseline — correct behaviour, but it means
  the knob has no *upper* travel.
- **`knob4`'s mid probe is 0.0000** (max 0.0101) — the usual static-branch pattern.
- Outline boxes issue four `e.rect` calls each, so a large `count` at
  `knob3 > 0.5` is the mode's worst draw-call case; device tier owed.
