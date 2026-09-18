# Port report — `s-audio-printer`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `S - Audio Printer/main.py` (91 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P2 (large S) — row 5; implemented by `local-agent`, 5 runs (two steered fixes) |
| Verification | `scene_verify.py --frames 300` — **pass**, 2026-09-18 |
| Device tier gate | owed (protocol: `docs/device-tier/2026-09-18.md`) |

## What it does

A 100×72 grid (12.8 × 10 px cells) printing a rolling history of "this column's
audio sample exceeded the threshold": each frame the oldest row is dropped and a new
row appended, and every lit cell is drawn in the LFO colour that was current when
its row was created. `knob1` selects the scan mode (2× bottom, 2× top, top+bottom),
`knob2` the horizontal shift and `knob3` the audio level gate.

## Mapping

| Stock | Port |
| --- | --- |
| `knob1` scan direction | `e.param("scan", 0.5, 0, 1, 1)` → `floor(knob1*2)` (0, 1, 2) |
| `knob2` horizontal shift | `e.param("shift", 0.5, 0, 1, 2)` → dead zone 0.40–0.60, `3.8*12.8` max |
| `knob3` audio level | `e.param("level", 0.5, 0, 1, 3)` → `volume = 10000 - level*10000` (stock-exact) |
| `knob4` fg colour | `e.param("fg", 0.5, 0, 1, 4)` → LFO once per frame, phase offset 0.21 |
| `knob5` background | `e.param("bg", 0.5, 0, 1, 5)` |
| `list.pop(0)` + `append` over 72 rows | a preallocated 72×100 flag table + 72 row colours + a `head` index |
| `abs(audio_in[i]) > volume` | `abs(left[1 + i*10]) * 32768 > volume` |

## Deviations (in the mode header)

1. **Palette** — deterministic middle branch; LFO re-timed `30 * inc * ctx.dt` per
   frame with phase offset 0.21 (`tools/lfo_offset.py --inc 0.1 --calls 1`).
2. **Background phase remap** `(bg*0.7 + 0.15) % 1`.
3. **The rolling history is a ring** — two preallocated tables mutated in place, so
   `draw` allocates nothing; the oldest row is overwritten at `head`.
4. **Never-empty floor.** Stock's threshold spans "almost nothing" to "everything"
   over the ±32768 range — which is what gives `level` its wide range at normal
   audio — but at the verifier's quiet gain (≈ ±573) `level = 0` lights nothing and
   the frame is blank. The port keeps stock's threshold **exactly** and, when no
   column in a newly printed row exceeds it, lights the row's **loudest column**.
   The frame is then never empty while the knob's range is untouched.
5. **Merged horizontal runs.** At `level = 1` every cell is lit, so stock issues
   7200 `draw.rect` calls per frame (14400 at scan mode 2). Adjacent lit cells in a
   row share the row's colour, so each maximal run is drawn as one `e.rect` —
   visually identical and inside the engine's draw-call budget.

## Two failed fixes worth recording

- **Runs 1–3 (`audio-quiet: flat frame`).** Stock's threshold is unreachable at the
  verifier's quiet gain, so the baseline printed nothing.
- **Run 4.** The first fix *rescaled* the threshold to `(1-level)*300`; that cured
  the blank frame but killed `level` (0.0000), because thresholds of 300 and 150 sit
  so low that normal audio saturates both and the lit sets are identical. The
  second fix kept stock's threshold and floored only the degenerate case — the same
  choice made for `s-0-arrival-scope`: restore or preserve the stock semantics, fix
  the collapse, do not move the knob.

## Verification — 2026-09-18

`python3 tools/verify_port.py s-audio-printer --frames 300` → `"verdict": "pass"`. Software GL (llvmpipe), 300 frames/run, engine sha256 `454ece7aafe7…`.

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| knob 1 `scan` | mid 0.4392, max 0.2999 |
| knob 2 `shift` | mid 0.5691, max 0.4066 |
| knob 3 `level` | mid 0.1040, max 0.1498 |
| knob 4 `fg` | mid 0.0000, max 0.3001 |
| knob 5 `bg` | mid 0.6999, max 0.6999 |
| audio | quiet 0.2897, loud 0.1420, freq 0.1497 (threshold 0.001) |
| trigger | n/a — the mode does not reference `ctx.trigger` |
| luma bounds | mean 29.03–94.0, min stddev 10.07 |
| `p50_ms` (software GL) | 16.2 (resources 0) |

## Residual risk

- **The quiet state differs visibly from stock**: one lit cell per row (a single-dot
  trace) instead of a blank frame. That is the documented cost of the never-empty
  floor, and it is the smallest change that satisfies the gate without touching the
  knob's scale.
- **`knob4`'s mid probe is 0.0000** (max 0.3001) — the usual static-branch pattern.
- **7200 cells is the largest logical canvas in the pack**; the merged runs keep the
  draw-call count low, but the per-frame scan over 72×100 cells is Lua-side work.
  Device tier owed.