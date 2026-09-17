# eyesy-modes-factory

Ports of the stock Critter & Guitari EYESY mode library to this platform's
Lua/GLES2 engine. Sibling repos: `eyesy` (engine/OS), `eyesy-modes-bespoke`
(original scenes), `eyesy-modes-milkdrop` (MilkDrop engine and presets).

**This repo holds no modes yet.** Nothing from `EYESY_Modes_OSv3` or
`EYESY_oFLua_Examples` has been ported. The directory is the agreed home for
them; the contract they must be ported *into* is below.

## What a port has to bridge

Stock modes come from two API generations, neither of which is our engine's.

**OSv3 Python/pygame** (`critterandguitari/EYESY_Modes_OSv3`, ~100 modes) — each
mode is a folder with `main.py` exposing `setup(screen, eyesy)` and
`draw(screen, eyesy)`, with everything else in module globals:

| Stock | Ours |
| --- | --- |
| `eyesy.knob1..5` (0..1) | `ctx.knobs[1..5]` |
| `eyesy.audio_in`, `audio_in_r` — 100 samples, ±32768, 100 Hz | `ctx.audio` — 1024 samples/channel + 513 FFT bins + 3 bands + rms/peak |
| `eyesy.audio_peak`, `audio_peak_r` — peak threshold 20000, no attack/release | onset detector |
| `eyesy.trig` — True for one frame | `ctx.trigger` — one frame, the only beat event (no tempo estimate) |
| `eyesy.midi_notes[128]`, `midi_note_new` | `ctx.midi` |
| `eyesy.auto_clear` — False keeps the frame, i.e. trails | `ctx.auto_clear` (see below) |
| `eyesy.color_picker(v)` / `_lfo(v, rate)` / `_bg(v)`, `get_color_from_phase(t, i)` | `e.palette(name, phase)`, `e.define_palette`, `e.color` |
| `eyesy.set_led(n)`, `eyesy.screengrab()` | OSC `/led`, screenshot key |
| `pygame.draw.rect/circle/line/lines/polygon` on a software surface | immediate prims, meshes, ES2 fragment shaders, ping-pong feedback targets |

**Legacy EYESY_OF Lua** (`EYESY_OF` + `EYESY_oFLua_Examples`, 14 examples) —
`require("eyesy")`, `of.*` full openFrameworks surface (meshes, 3D, lighting,
video), globals `knob1..5`, `inL`, `trig`, `midiNote`/`midiVel`, `colorPickHsb`.
This generation is the closer ancestor of our API: the two share the
`w`/`h`/knob/trigger shape, so the port is mostly a namespace rename
(`of.*` → our primitives, `require("eyesy")` → the `eyesy` table) plus the
shader/mesh upgrades.

## Porting rules that are not mechanical

1. **Frame rate.** Stock runs at a hard 30 fps (`clocker.tick(30)`), ours at 60.
   Any per-frame constant — decay factors, counters, phase increments, animation
   speeds — runs twice as fast unless it is re-timed against `ctx.dt`.
2. **Persistence is a different mechanism.** Stock trails come from a "veil":
   an alpha fill over the background surface every frame. Ours is a decayed
   ping-pong feedback target. Do not port the veil literally; port the look.
3. **Audio buffers are not the same instrument.** Stock is a 100-value ring at
   100 Hz — good for scopes, useless for detail, and its peak-detect trigger has
   no attack/release. Ours is 1024 samples with real spectra. Modes that read
   `audio_in[i]` as a waveform need the index mapping recomputed, not copied.
4. **Palettes.** Stock's `A + B·cos(2π(Ct + D))` formula is worth preserving:
   register it via `e.define_palette` so the mode's authored look survives, and
   keep palette-critical colours hardcoded — `e.palette` stop spacing is cyclic
   with `i/n` segments and unreliable for exact hues.
5. **Cost is a design constraint, not a porting detail.** Stock modes were
   written for a CPU rasterizer at 30 fps; our tier budget is measured on VC4
   V3D 2.1 (A ≤ 16.7 ms / B ≤ 22.2 ms / C ≤ 33.3 ms). A faithful port that does
   not meet tier C is not shippable — see `docs/SCENE-LIBRARY.md` in the engine
   repo for the levers that delivered.

Open engine item a port may hit: `ctx.auto_clear` is not yet exposed to Lua and
the toggle is inert across the fleet, so a persist-dependent mode cannot be
ported faithfully until that lands. Status and the pilot plan:
`docs/EYESY-OS-V3-PARITY-PLAN.md` in the engine repo.

## Port specifications

The two dossiers in `docs/research/` (see its README) carry the port specs:

- `docs/research/EyesyEcosystemMiner.md` — the whole ecosystem mapped
  (`EYESY_OS`, `EYESY_Modes_OSv3`, `EYESY_Modes_Pygame`, `EYESY_OF`,
  `EYESY_oFLua_Examples`, pysey, PatchStorage), with port viability per technique.
- `docs/research/PatchStorageBestOf.md` — ranked best-of-community spec, with
  popularity data and the shared pygame idiom worked out.

These two stay in the `eyesy` engine repo — they document the platform a port
has to land on:

- `01-architecture.md` at the engine repo root — how the stock engine, mode API,
  and hardware layer actually work.
- `docs/API.md` and `docs/SCENE-LIBRARY.md` — the contract a port must satisfy.
- `docs/EYESY-OS-V3-PARITY-PLAN.md` — the instrument-interface gap analysis
  (trigger audio synthesis, shift shortcuts, knob sequencer, OSD, menu).

## Consuming this repo

A pack is a flat collection of mode folders — the same shape a PatchStorage
upload and the stock `/sdcard/Modes` directory use.

```sh
./eyesyctl modes sync      # from the engine repo; assembles all packs into modes/
./eyesyctl modes list      # what every pack holds
```

`sync` is required before `./eyesyctl package`; `preview`/`test` resolve across
the packs directly.

## Adding a port

```sh
./eyesyctl new-mode my-port --pack ~/dev/eyesy-modes-factory
```

Keep the stock mode's name where the original name is meaningful to users, and
record the upstream source plus the API generation it came from in the mode
header. Ported modes are derivative works: check the upstream licence and carry
its attribution.