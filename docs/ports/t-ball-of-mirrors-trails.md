# Port report — `t-ball-of-mirrors-trails`

| | |
| --- | --- |
| Upstream | `critterandguitari/EYESY_Modes_OSv3`, `T - Ball of Mirrors - Trails/main.py` (38 lines) at `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` |
| Licence | BSD-2-Clause, © 2025 Critter & Guitari — derivative work, attribution in the mode header |
| Tranche | P3 — row 2; sibling of `t-ball-of-mirrors` |
| Verification | `scene_verify.py --frames 300` — **pass**, `failures: []` |
| Device tier | retired (repo-only) |

## What it does

The same trigger-gated ball and mirrored echo as its sibling, with the echo blended at an alpha
so the previous frame reads as a **trail** rather than a hard copy.

## What the sibling's port established, and where this one differs

The sibling's central finding carried over: stock calls `screen.copy()` **before** the echo blit,
so the echo source holds only bg+ball and can never contain the echo — keep only bg+ball in the
target and composite the echo at presentation.

**This mode's "trails" are not a decayed feedback loop.** Stock still takes a **fresh**
`screen.copy()` each frame; the trail is the previous frame blitted **at an alpha**, not an
accumulator that decays. The first draft assumed accumulation and was restructured once that was
checked against the source — the same trap in the opposite direction from the sibling.

## Deviations

The sibling's set, adapted: the half-resolution (640×360) ping-pong bridge for the echo; a ball
seeded at setup and re-stamped each frame (stock draws nothing until a trigger, which fails the
gate's baseline requirement); an echo-scale floor so a zero knob cannot blit a zero-size image;
the ball's radius carrying the audio level so the mode references `ctx.audio`; the deterministic
middle-branch picker; the background phase fold; and `random` → `e.random()` in stock's exact
order with `randrange`'s half-open range preserved.

## Verification — 2026-09-18

`python3 tools/verify_port.py t-ball-of-mirrors-trails --frames 60` → `"verdict": "pass"`, `failures: []`.

| Knob | fraction |
| --- | --- |
| 1 `xpos` | 0.05114 |
| 2 `ypos` | 0.00959 |
| 3 `xscale` | 0.00186 |
| 4 `yscale` | 0.01707 |
| 5 `bg` | 0.98590 |

| Check | Result |
| --- | --- |
| determinism | mean 0.0, frac 0.0 |
| audio | quiet 0.00743, loud 0.01697, **freq 0.00000** |
| `p50_ms` (software GL) | 16.6 |

## Residual risk

- **`audio-freq` reads 0.00000** — the frequency probe is dead here, as in the sibling (the only
  audio coupling is the ball's radius).
- **knob 3's margin is thin** (0.00186, about 2× the threshold) — the echo's x-scale moves few
  pixels at a single grab instant.
- **The half-resolution echo** makes the mirrored content softer than stock's.
- **The seeded ball and the scale floor** mean the all-knobs-zero baseline differs from stock's,
  which shows only background there.

## Repository note

Two new `.eyesy-no-ship` markers appeared during this row (`s-x-scope`,
`s-sound-jaws-uniform-color`). They are **not** agent errors: their content is byte-identical to
the 73 already tracked in this repo —

> Not in the gig catalog: excluded by eyesy-gig-lim1 show-set/mode-config.toml (not on the
> allow-list).

— so they are the `eyesy-gig-lim1` project applying its own allow-list convention to the two
newest modes. They are committed alongside the mode rather than removed, since fighting another
project's tooling would just be re-done on its next run.