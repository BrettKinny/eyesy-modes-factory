-- s-perspective-lines — port of stock "S - Perspective Lines"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Perspective Lines/main.py", licence BSD-2-Clause,
-- (c) 2025 Critter & Guitari. Stock draws 50 circles at
-- x = int(i * int(xr/48)) = i * 26 along the mid-frame row, each pushed off the
-- centre line by y1 = 360 + int(audio_in[i] * 0.00003058 * (yr/2)); every circle
-- is joined by a line to one shared origin, last_point = [int(knob1*xr),
-- int(knob2*yr)], so the whole set fans out of a single moving point. Circle
-- radius is int(knob3 * ((10*xr)/xr)) + 3 = int(knob3*10) + 3 and the line
-- width is int(knob3*10) + 1; every segment takes one colour from the LFO
-- picker.
--
-- Knob roles (stock-exact):
--   1 posx — x position (fan origin x = int(posx * 1280))
--   2 posy — y position (fan origin y = int(posy * 720))
--   3 size — line & circle size (radius = int(size*10)+3, width = int(size*10)+1)
--   4 fg — foreground colour (LFO picker; >0.5 = animated rainbow across the fan)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random (random greys / random RGB). Randomness cannot
--    be ported (replays must be byte-identical), so the deterministic
--    middle branch is substituted: r = 0.5*sin(2πc)+0.5,
--    g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5. The LFO ramp semantics
--    (0→2→0) and the per-segment (phase + i*inc) % 2 step are stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. LFO re-timed 30 -> 60 fps: stock advanced the LFO index once per
--    segment call (50 calls/frame at 30 fps = 1500*inc/s); here the phase
--    advances once per frame by 1500 * inc * dt. The per-segment c*inc step
--    is stock-exact, keeping the rainbow spread across the fan. No phase
--    offset is needed: the colour varies within the frame, so the gate's
--    single-instant sample already differs from the baseline (PORTING-LADDER
--    §3.4).
-- 4. Audio: stock reads a 100-sample ring (±32768) with audio_in[i]; the
--    platform buffer is 1024 normalized samples. Stock index i (0-based)
--    maps to left[1 + i*10] (oldest sample of the window, 10-sample
--    stride) and the stock scale is restored: y1 = 360 + trunc(sample *
--    32768 * 0.00003058 * 360) = 360 + trunc(sample * 360.59776) — stock's
--    int() truncates toward zero, hence trunc, not floor (guard nil -> 0).

local e = eyesy
local PI = math.pi

local SEGMENTS = 50
local XOFFSET = 26
local Y0 = 360
local AUDIO_SCALE = 32768 * 0.00003058 * 360

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

local lfoPhase = 0
local lfoInc = 0

local function draw(ctx)
  local posx = ctx.params.posx
  local posy = ctx.params.posy
  local size = ctx.params.size
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

  -- LFO: stock color_picker_lfo semantics. inc persists across frames; the
  -- phase advances once per frame by 1500 * inc * dt (deviation 3).
  -- fg <= 0.5 is a static colour: picker((fg*2) % 1).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.2 end
  lfoPhase = (lfoPhase + 1500 * lfoInc * dt) % 2

  -- Loop-invariant geometry. last_point is recomputed once per frame: stock
  -- assigns it inside seg(), but the value depends only on the knobs.
  local ox = math.floor(posx * ctx.width)
  local oy = math.floor(posy * ctx.height)
  local radius = math.floor(size * 10) + 3
  local width = math.floor(size * 10) + 1

  local left = ctx.audio and ctx.audio.left

  for i = 0, SEGMENTS - 1 do
    -- Foreground: static for fg <= 0.5, otherwise the stock LFO ramp
    -- (phase + i*inc) folded 0→2→0, then the deterministic palette.
    local x = (fg > 0.5) and ((lfoPhase + i * lfoInc) % 2) or ((fg * 2) % 1)
    if x > 1 then x = 2 - x end
    local r, g, b = picker(x)
    e.color(r, g, b)

    -- Audio: stock index i (0-based) -> left[1 + i*10], stock scale
    -- restored (deviation 4).
    local s = left and left[1 + i * 10] or 0
    local y1 = Y0 + trunc(s * AUDIO_SCALE)
    local x = math.floor(i * XOFFSET)

    -- Circle first, then line, as stock draws them.
    e.circle(x, y1, radius)
    e.line(ox, oy, x, y1, width)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("posx", 0.5, 0, 1, 1)
    e.param("posy", 0.5, 0, 1, 2)
    e.param("size", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
