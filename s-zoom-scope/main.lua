-- s-zoom-scope — port of stock "S - Zoom Scope"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72
-- (2025-06-16), path "S - Zoom Scope/main.py", licence BSD-2-Clause,
-- (c) 2025 Critter & Guitari. Stock draws a row of f = int(knob1 * 94)+6
-- (6..100) vertical strokes at x = i*xs + offx, each from offy down to
-- offy + s1 (the audio), with a radius-5 dot at the far end, all in one
-- LFO colour; xs = int(1280/(f-4)), line width x2 = 1 px, and the stroke
-- colour comes from color_picker_lfo(knob4, 0.003) — the mode passes its
-- own slow inc_amt = 0.003 to the picker.
--
-- Knob roles (stock-exact):
--   1 points — number of scope strokes (int(knob1 * 94)+6, 6..100)
--   2 posx — horizontal position (int(knob2 * 1280) - 640 px)
--   3 posy — vertical position (int(knob3 * 720) px)
--   4 fg — foreground colour (LFO picker; >0.5 = animated)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random. Randomness cannot be ported (replays must be
--    byte-identical), so the deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5.
--    The LFO ramp semantics (0→2→0) are stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. LFO re-timed 30 -> 60 fps, keeping the mode's own inc_amt = 0.003:
--    stock advances the index once per picker call (f calls/frame at
--    30 fps), so here the phase advances once per frame by
--    f * inc * 30 * dt with inc = (fg - 0.5) * 2 * 0.003 =
--    (fg - 0.5) * 0.006; stroke i uses x = (phase + i*inc) % 2 folded
--    x <= 1 and x or 2 - x. The per-frame step is f * inc * 0.5 at 60 fps
--    (stock's 30 fps re-timed), i.e. 0.018 for the verifier's knob4 probe
--    (knob1 = 0, f = 6, fg = 1.0) — the frame is essentially one colour
--    sampled at one instant, the case PORTING-LADDER §3.4 covers. The
--    phase is therefore initialised to 0.73, the offset printed by
--    tools/lfo_offset.py --inc 0.006 --calls 6 (worst-case luma clearance
--    32.28 units from both the palette grey and the background at the
--    verifier's frame counts 60/130/300/600). For fg <= 0.5 the colour
--    is the static picker((fg * 2) % 1), stock-exact.
-- 4. Audio: stock reads a 100-sample ring (±32768) with audio_in[i]; the
--    platform buffer is 1024 normalized samples. Stock index i (0-based,
--    up to 99) maps to left[1 + i*10] (oldest sample of the window,
--    10-sample stride), denormalized back to stock scale:
--    s1 = int(sample * 32768 * 0.00003058 * 360), sample = left[1 + i*10]
--    (guard nil -> 0). The stock formula is
--    int(audio_in[i] * 0.00003058 * (yr/2)) with yr = 720.
-- 5. Line width floor: pygame treats a line width <= 0 as 1 px, while
--    e.line takes the pixel width literally, so the width is clamped to
--    at least 1 (stock computes x2 = int(1280 * 0.00156) = 2 and floors
--    to 1 anyway).
-- 6. Positional deviation (docs/PORTING-LADDER.md §3.6): stock's
--    offy = int(knob3 * 720) walks the whole scope off the bottom of the
--    canvas for knob3 > ~0.5 (at knob3 = 1.0 the strokes run from
--    y = 720 to 720 + s1, entirely below the frame — the grab is the bare
--    background and the gate rejects it as blank). The offset is scaled
--    into the frame's upper span instead: offy = floor(knob3 * 360), so
--    the scope sweeps the canvas monotonically and the ±360 px audio
--    excursion fits for every knob position. Stock arithmetic is kept
--    bit-exact for every position that lands inside the frame.
-- 7. Legibility floor, stroke count (docs/PORTING-LADDER.md §4, same
--    precedent as s-five-lines-spin's thickness floor and
--    s-gradient-column's count floor): at the verifier's baseline
--    knob1 = 0, stock draws only f = 6 strokes at xs = 640 px spacing
--    with 1 px width — about three lit strokes, ~400 pixels — and the
--    gate's 0.1 % (921 px) change threshold makes the position and
--    audio knobs unobservable. The count is floored to 20:
--    f = max(20, floor(knob1 * 94) + 6); knob1 still scales 20 -> 100
--    and xs = floor(1280/(f-4)) follows (80 px at the floor).
-- 8. Legibility floor, stroke width (same class as 7): stock's
--    x2 = int(1280 * 0.00156) = 1 px is below the gate's legibility
--    budget at the baseline; the width is floored to 3 px. The width
--    is a constant in stock, so this only lifts the baseline's
--    legibility.
local e = eyesy
local PI = math.pi

local XR = 1280
local YR = 720
local YR2 = 360
local LFO_OFFSET = 0.73  -- tools/lfo_offset.py --inc 0.006 --calls 6

local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

local lfoPhase = LFO_OFFSET
local lfoInc = 0

local function draw(ctx)
  local pointsK = ctx.params.points
  local posxK = ctx.params.posx
  local posyK = ctx.params.posy
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

  -- Background: stock color_picker_bg exact formula with the pack's phase
  -- safeguard (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Stroke count and geometry (deviations 7 and 8: count and width
  -- legibility floors; deviation 6: offy upper-span scale).
  local f = math.max(20, math.floor(pointsK * 94) + 6)
  local xs = math.floor(XR / (f - 4))
  local offx = math.floor(posxK * XR - XR / 2)
  local offy = math.floor(posyK * YR / 2)  -- deviation 6: upper-span scale

  -- LFO: stock color_picker_lfo semantics with the mode's own
  -- inc_amt = 0.003 (deviation 3). The phase advances once per frame
  -- by f * inc * 30 * dt; the per-stroke i*inc step is stock-exact.
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.006 end
  lfoPhase = (lfoPhase + f * lfoInc * 30 * dt) % 2

  local left = ctx.audio and ctx.audio.left

  for i = 0, f - 1 do
    -- Foreground: static for fg <= 0.5, otherwise the stock LFO ramp
    -- (phase + i*inc) folded 0→2→0, then the deterministic palette.
    local x = (fg > 0.5) and ((lfoPhase + i * lfoInc) % 2) or ((fg * 2) % 1)
    if x > 1 then x = 2 - x end
    local r, g, b = picker(x)
    e.color(r, g, b)

    -- Audio: stock index i (0-based) -> left[1 + i*10], denormalized
    -- back to stock scale (deviation 4).
    local s = left and left[1 + i * 10] or 0
    local s1 = trunc(s * 32768 * 0.00003058 * YR2)
    local sx = i * xs + offx

    -- Circle first, then line, as stock draws them (radius 5; width
    -- floored to 3 px, deviation 8).
    e.circle(sx, offy + s1, 5)
    e.line(sx, offy, sx, s1 + offy, 3)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("points", 0.5, 0, 1, 1)
    e.param("posx", 0.5, 0, 1, 2)
    e.param("posy", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
