-- s-football-scope — port of stock "S - Football Scope"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Football Scope/main.py", licence BSD-2-Clause,
-- (c) 2025 Critter & Guitari. Stock draws 100 filled circles down one edge,
-- centred at (x1, i*12.8 - 100), each joined by a width-2 line back to
-- (i*12.8, x0) — the coordinates are transposed, which is what gives the mode
-- its look. x1 = int(knob1*1280) + audio_in[i]/50, x0 = int(knob2*720),
-- radius = int(knob3 * 12).
--
-- Knob roles (stock-exact):
--   1 posx — horizontal position: x1 = trunc(posx*1280) + audio/50
--   2 posy — vertical position: x0 = trunc(posy*720), the far end of each line
--   3 size — circle radius (trunc(size * 12) px; drawn only when >= 1)
--   4 fg — foreground colour (<0.5 = accumulating rainbow ramp, >=0.5 = static)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Foreground palette: stock color_picker is the legacy picker, which is
--    partly random (random greys / random RGB). Randomness cannot be ported
--    (replays must be byte-identical), so the deterministic middle branch is
--    substituted: r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5,
--    b = 0.5*sin(8πc)+0.5. The per-circle (i*0.01 + rate) % 1 phase step and
--    the static fg > 0.5 colour picker(1 - fg*2) are stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. Colour accumulator re-timed 30 -> 60 fps: stock advanced color_rate once
--    per circle call (100 calls/frame at 30 fps = 3000*(fg-0.5)*0.001/s); here
--    it advances once per frame by 100 * (fg-0.5)*0.001 * 30 * ctx.dt. The
--    per-circle i*0.01 term is stock-exact, keeping the rainbow ramp across
--    the 100 lines unchanged.
-- 4. Audio: stock reads a 100-sample ring (±32768) with audio_in[i]; the
--    platform buffer is 1024 normalized samples. Stock index i (0-based) maps
--    to left[1 + i*10] (oldest sample of the window, 10-sample stride),
--    denormalized by * 32768 to stock scale: A = s * 32768,
--    x1 = trunc(posx*1280) + A/50 (guard nil -> 0).
-- 5. fg == 0.5: stock leaves `color` unbound there — both branches use strict
--    inequalities, so the mode raises UnboundLocalError and dies at exactly
--    knob4 = 0.5. The verifier probes 0.5, so the port defines it: the
--    accumulating branch is taken for fg <= 0.5 (the only sane reading of a
--    mode that crashes at that knob position).
-- 6. Circle radius floor: pygame's radius-0 circle draws nothing, so the
--    circle is skipped when radius < 1 (stock-exact); the width-2 line is
--    always drawn and always lands the foreground colour on frame.

local e = eyesy
local PI = math.pi

local LINES = 100
local CIRCLESPACE = 12.8
local YOFF = -100
local RADMAX = 12

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

local colorRate = 0

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local posx = ctx.params.posx
  local posy = ctx.params.posy
  local size = ctx.params.size
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

  -- Background: stock color_picker_bg with the phase remapped to the middle
  -- of the picker's range (see header, deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Colour accumulator: stock advanced per circle call; here once per frame
  -- at the stock per-second rate (100 calls/frame * 30 fps re-timed).
  -- fg <= 0.5 takes the accumulating branch (deviation 5 defines 0.5).
  if fg <= 0.5 then
    colorRate = (colorRate + 100 * (fg - 0.5) * 0.001 * 30 * dt) % 1
  end

  -- fg > 0.5: a single static colour, stock-exact.
  local staticC = 1 - fg * 2

  local x0 = trunc(posy * H)
  local x1 = trunc(posx * W)
  local radius = trunc(size * RADMAX)

  local left = ctx.audio and ctx.audio.left

  for i = 0, LINES - 1 do
    if fg > 0.5 then
      e.color(picker(staticC))
    else
      e.color(picker((i * 0.01 + colorRate) % 1))
    end

    -- Audio: stock index i -> left[1 + i*10], denormalized to stock scale.
    local s = left and left[1 + i * 10] or 0
    local ax = x1 + s * 32768 / 50
    local y = i * CIRCLESPACE

    if radius >= 1 then
      e.circle(ax, y + YOFF, radius)
    end
    e.line(y, x0, ax, y + YOFF, 2)
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
