# Porting ladder — standing goal: port everything, one local-agent task at a time

**Goal (standing):** keep going until every stock EYESY mode is ported into this
pack — the **factory** set (`critterandguitari/EYESY_Modes_OSv3`, 108 modes) and
the **example** set (`critterandguitari/EYESY_oFLua_Examples`, 14 examples) —
with **all implementation done by `local-agent`, one tightly scoped task at a
time**, each port passing the same gate as an original scene.

Machine-readable queue: `docs/porting-queue.json` (108 rows, one per OSv3 mode,
with stock name, slug, size, assets, licence, status, verdict, device p50).

## 1. What "ported" means here

A port is a mode folder in this repo (`main.lua` + its `.frag` files, plus any
upstream assets it needs) that:

1. plays the **same scene** as the stock mode — same visual idea, same knob
   behaviour, recognisably the upstream piece;
2. passes `tools/scene_verify.py` at `--frames 300` (all five knobs live against
   an all-knobs-zero baseline, audio and trigger above threshold, determinism
   byte-identical, no blank/flat/white grab, no shader warning, no mode errors);
3. ~~passes the **device tier gate**~~ — **SUSPENDED 2026-09-18 by user
   direction: modes go into the repository only and are never put on the live
   unit.** The measurement deploys the packaged pack to the spare CM3+, so it is
   retired; the 42 rows measured before the direction stand as a record, and new
   ports are gated on the 300-frame contract run alone. The *findings* from those
   measurements remain binding design guidance — draw calls over resolution,
   colour-change cost, the four-bar outline (see "Device tier gate" below);
4. carries a header citing the upstream repo, path and licence, and a report at
   `docs/ports/<slug>.md` recording the mapping, the deviations, the verification
   numbers and the residual risk.

Ports are derivative works: upstream name, source path and licence in the header
(`EYESY_Modes_OSv3` is BSD-2-Clause, © 2025 Critter & Guitari).

### Verification command

The workstation has no engine shared libraries and no `xvfb-run`; the verifier
only runs inside the build image (`localhost/eyesy-build:bookworm`), which
carries `xvfb-run`, llvmpipe and the engine's dependencies. Run it from the
engine repo, mounting this pack as `/factory` so the mode resolves as a
`--modes-root` child:

```sh
cd ~/dev/eyesy && podman run --rm --init --arch amd64 --userns=keep-id \
  -v "$PWD:/workspace" -v ~/dev/eyesy-modes-factory:/factory -w /workspace \
  -e LD_LIBRARY_PATH=/workspace/engine/bin localhost/eyesy-build:bookworm \
  python3 tools/scene_verify.py --modes-root /factory --mode <slug> \
  --output /factory/local/verify-<slug> --frames 300 --xvfb
```

Exit 0 iff the verdict passes. Evidence per run: `local/verify-<slug>/` with
`00-<slug>/summary.json`, `contact-sheet.png` and `run-*/{replay.json,engine.log,report.json,grabs/}`.
`local/` is gitignored: the durable record is the `docs/ports/<slug>.md` report.
`--output` must not already exist, so a re-run needs a fresh directory name.
Software rendering means `p50_ms` here is a correctness-side number, **not** the
device tier gate (item 3 above, measured on the CM3+).

### Device tier gate

**Retired 2026-09-18 by user direction: modes are added to the repository only and
are never put on the live unit.** `headless-test` deploys the packaged pack to the
CM3+ to measure it, so these runs have stopped. What follows is kept for two
reasons: the numbers it produced are still the pack's design guidance (they are
what identified draw calls as the real lever, and colour changes as the cost that
takes a mode outside tier C), and the method is what any future re-measurement
would follow.

Measured on the spare CM3+ (DEVICE_IP, clone `CLONE_ID`),
600 frames offscreen, with the live platform running — the documented shared-load
condition:

```sh
cd ~/dev/eyesy
./eyesyctl package --arm                      # ARM release carrying the port
./eyesyctl headless-test dist/<release>-armhf.tar.gz \
  --host DEVICE_IP --clone-id CLONE_ID \
  --mode <slug> --frames 600 --output local/tier-<date>-<slug>
```

**The gate is floor-relative, not absolute.** The engine's own no-op baseline
(`starter`, which draws nothing) measures **36.7–37.0 ms** on this device under
shared load — above the tier-C ceiling of 33.3 ms — so an absolute threshold is
not measurable here and must not be claimed. Instead, run `starter` and the mode
back-to-back from the *same* release in the same session and compare:

| | |
| --- | --- |
| Floor (`starter`, same session) | measured at least twice, interleaved with the modes; the **minimum** is the reference |
| Pass condition | `p50(mode) ≤ min(p50(starter)) + 8.0 ms` |
| Rationale | half a tier-A frame (16.7 ms). If the engine's unloaded floor is ~8 ms, a mode with ≤ 8 ms of its own work still lands in tier A; on the loaded device the same marginal cost keeps the mode in the same band as the shipped library |
| Reference | the shipped bespoke scene `aurora` measures +8.1 ms over the floor — a port should not be materially heavier than that |
| Caveat | the shared load swings by 4–13 ms over tens of seconds, so a mode that measures *below* the floor is recorded as "at the floor, load-limited"; only a mode *above* `min(floor) + 8 ms` is a real failure |

Record the floor, the mode's absolute p50 and the marginal cost in the port
report and in the queue row's `device_p50_ms` (as `"<marginal> over <floor> ms"`).
A session's absolute numbers drift by several ms between sessions (measured
2026-09-18: `s-cone-scope` 36.7 ms in one session, 43.9 ms in another, with a
stable 36.7–36.9 ms floor), which is exactly why only same-session comparisons
are meaningful. Receipts land in `docs/device-tier/<date>.md`.

## 2. Licensing gate (read before porting anything)

| Source | Count | Licence | Status |
| --- | --- | --- | --- |
| `EYESY_Modes_OSv3` | 108 | BSD-2-Clause (LICENSE in repo) | **portable now** |
| `EYESY_Modes_Pygame` (v2) | 66 | **no licence file** | blocked — no port until licensing is clear |
| `EYESY_oFLua_Examples` (v1 Lua) | 14 | **no licence file** | blocked — no port until licensing is clear |
| `EYESY_OS` / `EYESY_OF` / `EYESY_Selector` | engine | BSD-3-Clause | read-only reference (semantics, palette formulas) |
| PatchStorage EYESY platform | 209 | per patch, unrecorded | not started; triaged in `docs/research/PatchStorageBestOf.md` |

The two unlicensed sets are exactly the "example" half of the goal. They are
recorded as **blocked-pending-licence** in the queue, not skipped silently: the
inventory (`docs/research/inventory/github-stock.md`) flags them as porting
blockers, and a port is a derivative work. Unblocking options, in order of
preference: (a) upstream adds a licence; (b) written permission; (c) a
documented clean-room reimplementation of the *technique* from public
documentation (manual + API), never a transliteration of the unlicensed source —
which changes the deliverable from "port" to "original scene inspired by".

### Vendored upstream revisions

Read-only clones under `~/dev/.scratch/eyesy-stock/` (`gh repo clone`), pinned
per port so a port names the revision it was made against:

| Clone | Repo | Revision |
| --- | --- | --- |
| `OSv3` | `critterandguitari/EYESY_Modes_OSv3` | `22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6` (2025-06-16, upstream `main` head) |
| `oFLua` | `critterandguitari/EYESY_oFLua_Examples` | `2dfb3b3f14b39cfb401edf57cbdc974b92329f16` |
| `v2Pygame` | `critterandguitari/EYESY_Modes_Pygame` | `db8815152baa3f083842d875f421132195cf0b38` |
| `OS` | `critterandguitari/EYESY_OS` | `51cc186eedebc1a5b5f632b64a4af8db636ed196` |

## 3. The bridge every port uses

Stock OSv3 modes are `main.py` with `setup(screen, eyesy)` / `draw(screen, eyesy)`
and module globals. The mapping table is in `README.md` ("What a port has to
bridge"); the five things that are never mechanical, each with the convention
this pack has settled on:

1. **Frame rate** — stock ticks at a hard 30 fps, ours at 60: re-time every
   per-frame constant against `ctx.dt` (or halve the increments).
2. **Persistence** — stock trails are a veil alpha-fill over the previous
   surface; ours is a decayed ping-pong feedback target. Port the look, never
   the veil literally. **The bridge costs three full-screen passes per frame**
   (scene → target, alpha fade, blit) and is the only thing in the pack that has
   failed the device tier gate: `s-folia-angles` measured **+21.0 ms** and
   `s-folia-curves` **+28.4 ms** over a 24.18 ms floor, against a gate of +8.0.
   **Allocate the ping-pong pair at half resolution** (`e.target(640, 360)` with
   `draw_target(handle, 0, 0, 1280, 720)`) — the lever the shipped bespoke library
   uses (`whitney-kaleido`'s 640×360 targets) — and document the softer trail.
   Measured progression on the CM3+ (same device, floor ~24.2 ms): full resolution
   **+21.0 ms**, half **+11.7**, quarter **+8.8** (absolute 32.96 ms, inside tier C's
   33.3 ms ceiling). The shrinking gains identify the cost as **fixed per-pass
   overhead** — target binds, the blit, the fade rect — not fill rate, so the
   resolution lever runs out around quarter resolution. Any mode needing stock
   persistence pays ~9 ms of bridge overhead on this device; the engine-side answer,
   if that ever matters, is a feedback path that samples the previous target as a
   texture instead of blitting it (what the shipped shader scenes do).
   **The bigger lever is draw calls, not resolution.** Batching a polyline-heavy mode
   into **one** mesh per frame — every segment a 4-vertex quad with static 1-based
   triangle indices, the house idiom from the bespoke library's `flow-field-drift` and
   `kalachakra-stupa` — took `s-folia-curves` from **40.56 ms to 30.00 ms** on the same
   device (+16.4 → +5.8 over the floor, absolute inside tier C), while the resolution
   lever had only reached the bridge's fixed per-pass overhead. Never use a single
   continuous line strip for disconnected polylines: `update_mesh` without indices is a
   line strip, so it draws joining segments between them.
3. **Audio shape** — stock is a 100-value ring at 100 Hz, ±32768; ours is 1024
   normalized samples + 513 FFT bins + 3 bands + rms. Waveform-reading modes
   need the index mapping recomputed; never copy `audio_in[i]` verbatim. The
   pack convention is a 10-sample stride with the stock scale restored:

   ```lua
   local left = ctx.audio.left           -- 1024 normalized samples, ±1
   local s = left and left[1 + j * 10] or 0   -- stock index j, 0-based
   local A = s * 32768                        -- stock-scale sample, ±32768
   ```

   Stock's ring is circular and ours is a linear window, so the stride is an
   approximation (100 stock entries ≈ 36 ms, 1024 samples ≈ 21 ms); it keeps the
   ordering and the spacing across the buffer. Index 1 must be the *oldest*
   sample of the window and the mapping must be stated in the mode header.
4. **Colour** — stock's default picker is *legacy and partly random*
   (`color_picker_original`: random greys for small values, a
   `sin(2πc)/sin(4πc)/sin(8πc)` rainbow in the middle, random RGB above 0.96).
   Randomness cannot be ported (the contract requires byte-identical replays),
   so ports implement the **deterministic middle branch** as a palette and
   document the substitution:

   ```lua
   -- stock color_picker (legacy) middle branch, deterministic form
   --   r = sin(2*pi*c)*0.5+0.5, g = sin(4*pi*c)*0.5+0.5, b = sin(8*pi*c)*0.5+0.5
   local stops = {}
   for i = 0, 15 do
     local c = i / 16
     stops[#stops + 1] = {0.5 + 0.5 * math.sin(2 * math.pi * c),
                          0.5 + 0.5 * math.sin(4 * math.pi * c),
                          0.5 + 0.5 * math.sin(8 * math.pi * c)}
   end
   e.define_palette("<slug>-fg", stops)
   ```

   `e.define_palette` accepts only 2–16 stops (`docs/API.md`), so a mode that
   needs the stock 24-stop spacing either registers 16 stops or — as
   `s-concentric` does — keeps the 24-stop table in Lua and samples it with the
   same cyclic linear interpolation. Either way the substitution is documented.

   The stock background picker *is* deterministic and is ported exactly:
   `r = (1-(cos(3πc)*0.5+0.5))*c`, `g = (1-(cos(7πc)*0.5+0.5))*c`,
   `b = (1-(cos(11πc)*0.5+0.5))*c` — **except** for one safeguard: the formula
   returns pure white at `c = 1` and pure black at `c = 0`, both of which the
   verifier rejects as whiteout/blank, so the bg phase is folded into the middle
   of the range: `c = (bg * 0.7 + 0.15) % 1`. The colour path and the knob's
   effect are otherwise untouched.

   `color_picker_lfo(knob, inc_amt = .1)` is time-based and needs the frame-rate
   rule: for `knob <= .5` it returns `picker((knob * 2) % 1)` (a static colour);
   above `.5` it ramps an index 0→2→0 by `inc = (knob - .5) * 2 * inc_amt` **per
   call**, with 30 frames/s. Port it as a phase advanced once per frame by
   `1500 * inc * ctx.dt` (calls/frame × 30 = the stock per-second rate), keeping
   the stock per-call step for any within-frame gradient.

   **A mode that calls the LFO once per frame needs a phase offset.** The gate
   samples the colour at a single instant and its metric is **luma only**, so the
   sampled colour must differ in luma from *both* the baseline colour (the
   palette's grey `0.5`, luma 127.5) *and* the background. With no offset the
   sampled index lands exactly on a palette crossing at the verifier's grab frames
   (the knob event is applied at frame 5), so `knob4` reads dead; a quarter-cycle
   offset lands on the *other* crossing, and 0.16 lands on the background's own
   luma (`S - Bits Vertical` measured 0.0000 and then a flat frame before this was
   understood). Initialise the phase to **0.21**, which keeps the sampled colour
   ≥ 38.9 luma units from both targets at every frame count the verifier supports
   (60/130/300/600), and say so in the mode header. Derive the value with
   `tools/lfo_offset.py` — `--inc <per-call step at knob4 = 1.0> --calls <picker
   calls per frame>` — rather than by hand: it prints the offset maximising the
   worst-case clearance across those frame counts (0.21 for one call per frame,
   0.73 for a mode with a slow `inc_amt`). Modes that call the LFO once per
   *element* (per line, per arc) do not need this when their within-frame spread
   already varies the sampled colour, but a mode whose per-element step is tiny
   (e.g. `inc_amt = 0.003` over 6 calls) does.

   Beware the verifier's second chance: when both probe points read dead it
   retries with a MIDI trigger, and a mode whose trigger re-randomises geometry
   can then "pass" on the trigger's effect rather than the knob's. That is a
   false liveness — fix the knob's own visibility instead of relying on it.

5. **Cost** — stock was written for a CPU rasterizer at 30 fps. Tier C is a hard
   gate; the levers are in the engine repo's `docs/SCENE-LIBRARY.md`. Two hard
   engine budgets apply to mesh-based ports:
   - **at most 32 mesh handles per mode** (`engine/src/runtime.cpp`), so
     per-element handles are illegal past 32 elements — group geometry per colour
     (the grid family uses one mesh per column, 10 handles) or per shape;
   - **8192 vertices / 49152 indices** per mesh.
   Both were hit in practice: `s-grid-triangles-filled-column-color`'s first
   revision created 70 per-cell handles and the engine rejected it with "mesh
   budget exceeded".

   **Per-element colour changes are a real device cost.** Measured on the CM3+ with
   bookended `starter` floors at ~24.2 ms, three modes of the same family:

   | Mode | `e.color` calls/frame | device p50 | marginal |
   | --- | --- | --- | --- |
   | `s-grid-polygons-uniform-color` | 1 | 24.21 | +0.0 |
   | `s-grid-polygons-column-color` | 10 | 24.18 | +0.0 |
   | `s-grid-slide-square-filled-uniform-color` | 1 | 25.33 | +1.1 |
   | `s-grid-polygons-patchwork-color` | **70** | **37.89** | **+13.7 — outside tier C** |

   The patchwork mode already *groups* its geometry by colour class (three meshes) but
   then draws per cell, so it issues 70 colour changes where **three** would do: one
   `e.color` per class, immediately before that class's mesh draw. Group the geometry
   by colour class *and* draw each class in one call — the grouping alone buys nothing
   if the draw loop still changes colour per element.

   **`e.rect` has no border width.** pygame's `pygame.draw.rect(screen, color, rect,
   linew)` outline must be drawn as **four `e.rect` bars** — top, bottom, left, right —
   of thickness `linew` forming a perimeter band around the stock rect, with the bounding
   box growing to `width + rad + 2*linew` (the centred-rect conversion accounts for the
   outline width; it is not a shrink). That quadruples the rect count (the slide-square
   family goes from 70 to 280 per frame), which is **fill-rate** cost rather than
   colour-change cost — the two levers are different, and only the latter has so far
   pushed a mode outside tier C.

   **`update_mesh` validates the ENTIRE vertices table.** A mesh preallocated at a
   fixed capacity and uploaded with only its filled prefix throws *"attempt to
   index a nil value"* (found porting `s-grid-polygons-patchwork-color`). Size each
   mesh at its **exact** populated vertex count so the table is never partially
   filled; a trailing `nil` is fatal, and a fourth count argument is ignored.

6. **Positions that leave the frame** — many stock modes place content by raw
   pixel arithmetic that walks it off the 1280×720 canvas for part of a knob's
   range (`S - Gradient Friend` ejects its column for `knob2 > ~0.45`,
   `S - Cone Scope` starts its fan at `x = 1280` at `knob1 = 1`). Stock shows
   nothing there; the verifier fails a blank or whiteout grab, and a knob whose
   `0.5` and `1.0` states are both empty reads as dead. The pack convention is a
   **documented positional deviation**, and the choice matters:

   - **Scale the offset into the frame's inner span** when the knob is a
     position (`x = (W - margin*2) * knob + margin + stock_wobble`): monotone,
     no seam, live at every probe point. This is the default.
   - **Wrap** (`p % size`) when the knob's excursion is far larger than the frame
     and the look is a scroll (stock's `ypos ≈ -5*boing` in `S - Gradient
     Friend`).
   - **Never wrap an offset that is exactly one frame span** — `xr*knob1 + 100`
     at `knob1 = 1` is one width beyond the origin, so it wraps back onto the
     baseline and the knob reads dead at `1.0`. Two ports in the P0 tranche hit
     this; both now scale instead.

   Record the deviation in the mode header and the port report, and keep the
   stock arithmetic bit-exact for every position that lands inside the frame.

### Family: `grid-slide-square` (6 modes)

The family differs along **two** axes and neither is cosmetic — diff the sources
rather than assuming a copy:

- **`Filled` vs `Unfilled`**: filled draws `pygame.draw.rect(screen, color, rect, 0)`
  and applies the slide offsets to *every* cell; unfilled draws an outline of
  `linew = int(xr*0.0026)` and makes the offsets **conditional** on the same parity
  branches (`if i%2==1: x = ...`, `if j%2==1: y = ...`).
- **Colour**: `Uniform` is one `color_picker_lfo(knob4)` per frame; `Column` calls the
  **static** legacy picker — `color_picker((j*0.1 + knob4) % 1)`, *inside* the `j` loop,
  so once per column (10 calls per frame, no LFO state, and all 7 rows of a column share
  the colour); `Patchwork` overwrites sequentially — `i%2==1 → picker(knob4)`,
  `j%2==1 → picker(1-knob4)`, `(j+i)%3==1 → picker((0.8+knob4)%1)`, last match wins.
  Do not assume the family shares one picker: `Column` is *not* time-based, so it needs
  no `lfo_offset` phase — but if a port calls the LFO once per element, derive the offset
  for **its own call count** (`tools/lfo_offset.py --calls <n>`) rather than copying the
  one-call-per-frame 0.21.

Shared: the 7×10 grid (`x = j*x8 - x8`, `y = i*y5 - y5`), `rad = |audio_in[j-i]| /
hund` with `hund = xr*0.07734`, `width = int(knob3*hund)+1`, and the `sqmover` LFO
(`start = -otwen`, `max = otwen`, `otwen = xr*0.09375`).

**The `sqmover` oscillator advances 14 times per frame** — the knob block runs 7 times
(once per row) and calls `update()` **twice** each time, and `xoffset`/`yoffset` are two
*separate* advances, so `yoffset` is always one step ahead of `xoffset`. Advancing once
per frame and reusing the value for both is wrong.

**knob1 and knob2 are mutually dependent.** `knob2 = 0` sets `max = start = 0`, which
pins the oscillator at 0, so knob1 alone can never move anything; `knob1 = 0` makes the
step zero, so knob2 alone can never move anything either. The verifier probes one knob
at a time from an all-zero baseline, so both read dead — a **stock-faithful** deadness
that nonetheless fails the gate, and so needs the documented-deviation treatment of §4
rather than a re-reading of the source.

### Family: `amp-color` (4 modes)

Shared skeleton (all four):

- **`count` nested shapes at the screen centre**, each scaled by
  `size = full - (i * (full/count) * (1 + 0.1*(N-count)/N))` where `N` is the mode's
  own max-count constant (**60** for the 5gons, **100** for circles — the constant is
  part of the formula, not the shape count).
- **Per-shape colour from that shape's own audio history**: a running average over a
  deque of `maxlen = int(knob1*20)+1`.
- **Per-shape rotation** `current_rotation + i*offset`, where `current_rotation` is a
  stock global accumulated per frame from knob2 — dead zone `0.49..0.51` resets it to 0,
  rate `|knob2-0.48| * 52` deg/frame at 30 fps.
- **Trigger re-randomises the geometry** (5 random points for the 5gons, 5 random
  circles for circles, nothing for rectangles).
- Background from `color_picker_bg(knob5)`; the audio index for shape `i` is
  `audio_in[i]` (0-based, **no wrap**).

Per mode:

| Mode | shape | draw | count | `N` | offset | audio scale |
| --- | --- | --- | --- | --- | --- | --- |
| `5gon Filled` | 5-vertex polygon | `draw.polygon(..., pts)` filled | `int(knob3*59)+1` (60) | 60 | `i*(knob4*180)` deg | `abs(audio_in[i]/32768)` |
| `5gon Outlines` | same | `draw.polygon(..., pts, 7)` — 7 px outline | same | 60 | same | same |
| `Circles` | 5 circles (r + pos) | `draw.circle(..., int(scaled_radius))` | `int(knob3*49)+1` (50) | 100 | — | — |
| `Rectangles` | — | — | — | — | — | — |

**The 32-mesh-handle cap binds here.** Stock draws up to **60** nested polygons; the
engine allows at most **32 mesh handles per mode**, and each polygon needs its own
handle because its colour comes from its own audio history — so there is nothing to
group by. The port therefore caps the drawn count at 32 and documents the deviation:
the mode is stock-exact for `knob3 ≤ 0.53` and draws 32 polygons where stock draws more
above that. That is a real fidelity loss, not a rounding detail, and it is the second
time this budget has forced a shape (see `s-grid-triangles-filled-column-color`'s
rejected 70 handles).

## 4. Deviations the gate forces

Three deviation classes recur, and all three are documented per mode rather
than silently applied:

| Class | Why | Convention |
| --- | --- | --- |
| Randomness | replays must be byte-identical | deterministic middle branch of the legacy picker (§3.4); `e.random()` for `randrange` |
| Blank/white extremes | verifier bounds at `c = 0` and `c = 1` | bg phase folded to `(bg*0.7+0.15) % 1` (§3.4); radius/geometry floors where a zero knob draws nothing |
| Degenerate baseline content | the all-knobs-zero state draws too little for the luma metric (a hairline, one dot, a single stroke) | floor the *count*, *extent* and *thickness* so the baseline is legible. **Size the floor against the quietest audio variant, not the baseline**: `s-aquarium`'s strokes are ~1 px long at the verifier's quiet gain, so floors that sufficed at normal gain still read flat |
| Content outside the frame | verifier bounds + dead-knob check | scale the offset into the frame (default), wrap only for scroll-like excursions, never wrap a one-frame span (§3.6) |
| Zero-area geometry | stock's shape collapses when its size knobs are 0, so it renders nothing and the colour knob becomes unobservable | floor the shape's extent (e.g. `S - Circular Trigon Field`'s 12 px vertex offsets), keeping the knobs' scaling above the floor |
| One-instant colour sampling | the LFO colour is a pure function of time and the gate samples one instant | phase offset 0.21 (§3.4) so the sampled colour clears both the palette grey and the background luma |
| A branch stock does not define | stock raises or leaves a name unbound at an exact knob value (`S - Football Scope` at `knob4 = 0.5`) | pick the branch, document the choice, and say that stock crashes there |

## 5. The local-agent rule

- **All port implementation is delegated to `agent: "local-agent"`** — the
  qwen3.8:27b model on tower, not this session's model. No port is hand-written
  here; this session designs, scopes, verifies and integrates.
- **One task at a time, tightly scoped**: exactly one mode per task, with the
  stock source path, the mapping (knobs, audio, colour), the acceptance criteria
  and the verification command spelled out. `local-agent` may only run one task
  at a time, so the queue is strictly serial — no fan-out, ever.
- **Scope is one mode folder.** A brief names exactly one mode folder plus
  `local/` for verification output. `local-agent` never runs `eyesyctl`, never
  marks a mode `.eyesy-no-ship` (that marker excludes a mode from packaging), and
  never edits another mode — including the ones already verified. The session
  owns everything outside the mode folder: the pack sync, the queue, the reports
  and the commits. (2026-09-18: one task overstepped on both counts — it marked
  the verified `s-concentric` `.eyesy-no-ship` and ran `eyesyctl modes sync`
  itself. Both were reverted; the marker would have silently dropped a verified
  port from every release.)
- **The task brief is prescriptive** (the local model implements; it does not
  design). Each brief names: the stock file to read, the target folder and slug,
  the knob roles with their stock meaning, the audio mapping, the palette
  formulas, the content resolution strategy, and the exact container command.
- **This session verifies every port** (300-frame contract run + device gate)
  before it enters the ladder's "done" column, and commits ports in tranches.
- **Stage explicitly.** Never `git add -A` while a porting task is mid-flight: a
  mode folder that exists on disk is not a mode that has passed the gate.
  (2026-09-18: `git add -A` swept an in-flight folder — which at that moment had
  a Lua syntax error — into a tranche commit; it was corrected in the next commit
  and nothing was released from it, but the rule exists because the tree and the
  commit must agree on what is verified.) A work-in-progress mode that must sit in
  the pack during development carries `.eyesy-no-ship` until it passes.

## 6. Queue and tranches

Tranche order (see `docs/porting-queue.json` for the authoritative rows):

| Tranche | Contents | Rows | Status |
| --- | --- | --- | --- |
| **P0 — pilot** | `s-concentric`, `s-gradient-friend`, `s-cone-scope` | 3 | contract run done (3 × pass); device tier gate owed |
| **P1 — pure S, small** | pure-`S` rows under 60 source lines, alphabetically | 26 | queued |
| **P2 — pure S, large** | remaining pure-`S` rows (60–202 lines) | 45 | queued |
| **P3 — pure T** | `T - …` rows with no assets | 23 | queued |
| **P4 — pure U** | `u-timer` | 1 | queued |
| **P5 — assets** | the image/font rows (copy upstream `Images/`; font rows need `e.text` or a baked atlas) | 10 | queued |
| **P6 — blocked** | 66 v2 + 14 oFLua examples | 80 | blocked-pending-licence (§2) |

The `tranche` field in `docs/porting-queue.json` carries these labels; the rule
that produced them is recorded there as `tranche_rule` and the pre-existing
pure/asset split is kept as `kind`.

Progress rule: a tranche is done when every row in it is `done` (port landed,
300-frame verdict recorded, device p50 recorded in the queue JSON) or explicitly
`not-worth` / `blocked` with a reason. **The ladder never stops for a missing
answer**: unblocked rows keep moving while a blocked row waits.

## 7. Status log

- 2026-09-17: program opened. Sources vendored read-only to
  `~/dev/.scratch/eyesy-stock/{OSv3,oFLua,v2Pygame,OS}` (`gh repo clone`).
  Queue built (108 rows, 98 pure / 10 asset-dependent, slug collisions: none).
  Pilot tranche P0 dispatched to `local-agent`.
- 2026-09-18: ecosystem inventory landed (`docs/research/CoverageMatrix.md`,
  `docs/research/inventory/`, `tools/inventory/`) — 406 distinct modes, 401 of
  them not covered at that point (398 once the P0 ports landed; the matrix now
  tracks ports directly). Ladder and queue restored into this repo; queue rows
  re-tranched P0–P5. Verification command pinned to the build container (the host
  has no engine libraries or `xvfb-run`).
- 2026-09-18: `s-concentric` verified at 300 frames. The parked port failed the
  gate on two counts — `knob4` was dead (the stock phase set `{(knob4*i)%1}`
  lands on the palette's grey zero-crossings at 0.5 and 1.0) and audio was
  invisible at the all-zero baseline (stock gates the audio term behind `knob3`)
  — both fixed as documented deviations in the mode header, not by weakening the
  gate. Verifier-driven integration fix, this session; recorded in
  `docs/ports/s-concentric.md`.
- 2026-09-18: `s-cone-scope` implemented by `local-agent` (one iteration, first
  pass at 60 frames) and verified at 300 frames. On review the brief's positional
  rule was *not* kept: the agent had wrapped `x0` modulo the frame width, which
  made `knob1 = 1.0` pixel-identical to the baseline and hid half the knob's
  range. The stock-exact pivot was restored and the port re-verified — knob 1 is
  now live at both probe points (0.0288 / 0.0197). Report:
  `docs/ports/s-cone-scope.md`.
- 2026-09-18: `build_coverage.py` now scans this repo's mode folders for the
  upstream citation a port must carry and marks the matching upstream row
  `have-ported` instead of `missing`, so the coverage matrix tracks the porting
  program rather than going stale. Matrix, README and inventory counts updated
  (406 upstream modes: 3 ported, 5 derived, 398 not covered). The merge stays
  offline and deterministic — the committed per-source inventories are untouched.
- 2026-09-18: incident. `s-concentric/.eyesy-no-ship` — contents "s-concentric
  excluded pending completion" — appeared in the pack at 10:39:54, in the same
  minute as an `eyesyctl modes sync` run that copied the factory modes into the
  engine repo. The marker would have dropped a *verified* port from every
  release (`eyesyctl package` excludes marked modes and reports them as
  excluded); both the pack copy and the synced copy were removed, and §5 now
  states the scope rule for `local-agent` tasks explicitly. Attribution is
  unproven — both porting tasks deny writing it and the timeline does not place
  either in `s-concentric/` — so the record is the fact, not a culprit. Removal
  was unconditional because the mode had passed its 300-frame gate and the
  marker contradicts the program's own acceptance criterion (the pack must
  expose every verified port).
- 2026-09-18: `s-gradient-friend` failed its first verifier run
  (`knob4-max` flat, stddev 0.45; `knob1-max` identical to the baseline) and was
  corrected by steering rather than by weakening the gate: a scaled x offset
  instead of a wrap, and the 15 % audio floor extended from `push` to the
  position term `boing` so the zero-knob state keeps the column's per-circle
  spread and colour ramp. §3.6 now records the lesson — never wrap an offset that
  is exactly one frame span.
- 2026-09-18: `s-gradient-friend` verified at 300 frames (mode sha256
  `b1ac60bc62054bed…` identical before and after the run): all five knobs live,
  audio reactive, determinism 0.0, no blank/whiteout grab. Report:
  `docs/ports/s-gradient-friend.md`. P0 is therefore complete on the contract run;
  the device tier gate is owed for all three ports, which is what keeps their
  queue rows at `verified-300` rather than `done`.
- 2026-09-18: pack integration verified end to end — `./eyesyctl modes sync`
  assembles the three ports into `modes/` (catalog pack `eyesy-modes-factory`),
  `./eyesyctl modes list` shows them with no exclusion marker, `./eyesyctl
  package` ships 49 modes including all three (only `zzprobe` excluded), and
  `./eyesyctl preview <mode> --headless --frames 120` renders each with zero mode
  errors and no shader warning.
- 2026-09-18: P1 opened (`s-arcway-black`, `s-bits-vertical` ported and verified
  at 300 frames) and the loop was made repeatable: `tools/verify_port.py` runs the
  gate in the build container, prints the numbers a report cites, and
  `--markdown` emits the report's verification table.
- 2026-09-18: **device tier gate restated.** The absolute `p50 ≤ 33.3 ms` is not
  measurable on the spare CM3+ under the documented shared load: the engine's own
  no-op baseline (`starter`) measures 36.7–37.0 ms, stable to 0.2 ms within a
  session and 35.8–37.0 ms across three builds (so it is device state, not an
  engine regression). The gate is now the mode's marginal cost over the
  same-session floor, pass if ≤ 8.0 ms; all three P0 ports pass (+1.8 to +7.0 ms,
  against +8.1 ms for the shipped bespoke scene `aurora`). Receipt:
  `docs/device-tier/2026-09-18.md`; the maintainer's call on whether to measure
  on a quiet device (platform service stopped) is recorded there as an open
  question.
- 2026-09-18: the gate exposed a class of defect worth naming: a mode whose LFO
  colour is sampled once per frame can read `knob4` as dead because the sampled
  index lands on the palette's grey (or, after a partial fix, on the
  *background's* luma — a flat frame), and the verifier's trigger-assisted retry
  can then "pass" the knob on an unrelated geometry change. §3.4 now carries the
  rule (initialise the phase to 0.21, which clears both targets at 60/130/300/600
  frames) and the warning about the false-liveness path.
- 2026-09-18: `s-circular-trigon-field` needed two structural deviations the
  agent's five iterations did not reach, and the session applied them: the ring
  radius scaled into the frame (stock's 800 px ring never intersects the canvas
  at `knob1 = 1`, so the grab was blank) and a 12 px minimum triangle extent
  (stock's triangles collapse to zero area with knobs 2 and 3 at 0, which made
  the colour knob unobservable and left only the random hairline jitter). Both
  are now §4 classes ("zero-area geometry", "content outside the frame"). The
  task was cancelled after the takeover; the mode passes the 300-frame gate.
- 2026-09-18: `tools/lfo_offset.py` added — the LFO phase offset that used to be
  derived by hand per mode (and cost two failed iterations on `s-bits-vertical`)
  is now a computation: give it the per-call step and the calls per frame, and it
  prints the offset that maximises the sampled colour's worst-case luma distance
  from both the palette grey and the background across the verifier's frame
  counts. §3.4 points at it.
- 2026-09-18: `s-five-lines-spin` failed its first gate run on three checks with
  one root cause — the mode's baseline is five one-pixel hairlines (~120 lit
  pixels), so no knob change could move the 921 pixels the metric needs, and the
  audio reached the geometry only through `knob2`. Two legibility floors (an audio
  floor on the reach, a 4 px stroke thickness floor) were designed by the session
  and applied after the agent's iteration stalled; the mode then passed at 300
  frames. §4's "blank/white extremes" row already covers this class.
- 2026-09-18: nine modes verified (3 P0 + 6 P1), each with a port report and a
  queue row. P1 stands at 6 of 26 rows; the remaining P1 rows have briefs staged
  (`classic-*`, `five-lines-spin`, `football-scope`, `gradient-cloud`,
  `gradient-column`, the 11-mode grid family, `line-traveller`, `two-scopes`,
  `zoom-scope`), and the loop is one `local-agent` task at a time with the session
  running every 300-frame gate.
- 2026-09-18: `s-gradient-column` is the clearest lesson in P1 so far: the *same
  bytes* passed at 60 frames and failed at 300 (`knob3` dead at both probe
  points), because stock's swell enters the radius as the frequency of a sine of
  the circle index, so its effect vanishes whenever the sine sits near an
  extremum. Three legibility deviations (circle-count floor 30, radius floor 8,
  swell phase coefficient widened 0.1 → 0.3) make the knob observable at any
  instant; the 300-frame gate then passes with all five knobs live.
- 2026-09-18: the device gate's protocol needed a correction the P1 batch caught:
  the floor itself moved 13 ms between two back-to-back `starter` runs, so a
  single floor reading at the start of a long batch is not a valid reference —
  `s-football-scope` was reported at +13.6 ms and is actually +1.1 ms over a quiet
  floor. The protocol is now floor → mode → floor, accepting a marginal only when
  the two floors agree within 2 ms. Receipt updated:
  `docs/device-tier/2026-09-18.md`.
- 2026-09-18: the 11-mode grid family is complete (`s-grid-circles-*` and
  `s-grid-triangles-*`): every row verified at 300 frames, seven of them on the
  agent's first iteration from the shared family brief. The brief earned its keep
  twice over — the per-mode delta table removed the per-mode design work, and the
  two mesh warnings (32-handle cap, index table must match its own mesh) were
  learned once and applied to the remaining rows.
- 2026-09-18: **P2's dominant pattern is the sibling copy.** `s-arcway` was ported
  in zero iterations and 3m47s by copying the verified `s-arcway-black` verbatim and
  changing one colour rule — the cheapest row in the program so far. Most of P2 is
  built this way: the amp family (5 rows), grid-polygons (3), grid-slide-square (6),
  and the circle/bezier/folia/line-bounce/mirror/nested/radial/radiating/sound-jaws
  pairs are all colour, size or fill variants of one another. **Write the brief as a
  diff against the verified sibling** — name the sibling, say which expressions
  change, and carry the sibling's deviation list verbatim — rather than restating
  the whole mapping. The first of each family still needs a full brief; the rest do
  not.
