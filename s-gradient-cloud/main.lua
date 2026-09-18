-- s-gradient-cloud — port of EYESY OSv3 stock mode "S - Gradient Cloud".
--
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "S - Gradient Cloud/main.py",
-- license BSD-2-Clause, (c) 2025 Critter & Guitari, vendored revision
-- 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6. The stock mode draws a column of
-- 360 filled circles (one per row, half of the 720 px frame height); each
-- circle's x follows a sine of the row index and time around a common
-- cloud-centre offset, its y is offset by one audio sample per row, its
-- radius swells with the shape knob and time, and its colour advances a
-- per-circle accumulator driven by the foreground knob — the "gradient".
--
-- Knob roles (1 cloud x position, 2 cloud y position, 3 pattern shape and
-- swell range, 4 foreground colour, 5 background colour):
--   1 posx — cloud x position (0..1 of width)
--   2 posy — cloud y position (0..1 of height)
--   3 shape — pattern shape and swell range
--   4 fg — foreground colour phase
--   5 bg — background colour phase
--
-- Documented deviations:
-- 1. Palette substitution: stock's color_picker is legacy and partly RANDOM
--    (random greys below 0.5, a sin(2 pi c)/sin(4 pi c)/sin(8 pi c) rainbow in
--    the middle, random RGB above 0.96). This port uses the deterministic
--    middle branch directly, {0.5+0.5 sin(2 pi c), 0.5+0.5 sin(4 pi c),
--    0.5+0.5 sin(8 pi c)}, so replays are byte-identical.
-- 2. Background phase remap: stock color_picker_bg is ported exactly but
--    returns pure white at c = 1, which the verifier rejects as whiteout, so
--    the bg phase is remapped to (bg * 0.7 + 0.15) % 1.
-- 3. Colour accumulator re-time 30 -> 60 fps: stock advanced color_rate once
--    per circle, 360 times per frame at 30 fps (21600 * knob4 * 0.02 per
--    second). The port keeps the stock per-circle step (knob4 * 0.02, so the
--    within-frame gradient is stock-exact) and advances the frame phase once
--    per frame by 216 * knob4 * ctx.dt, the same per-second rate.
-- 4. Audio stride: stock reads a 100-sample ring of raw +/-32768 samples;
--    ours is ctx.audio.left, 1024 normalized samples. Stock index j (0-based,
--    j = i % 99) maps to left[1 + j*10], denormalized by 32768; the term is
--    A/100 with A = sample * 32768 (missing sample -> 0). Index 1 is the
--    oldest sample of the window.
-- 5. time.time() -> ctx.time (the sim clock, so replays are byte-identical).
--    All four clock terms (sin(0.5 + t), cos(1 + t), sin(i*knob3*3 + t),
--    sin(i + t)) are absolute-clock sines already expressed per-second, so no
--    re-timing is applied to them.

local e = eyesy
local PI = math.pi

local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

-- Stock color_picker (legacy) deterministic middle branch.
local function picker(c)
  return 0.5 + 0.5 * math.sin(2 * PI * c),
         0.5 + 0.5 * math.sin(4 * PI * c),
         0.5 + 0.5 * math.sin(8 * PI * c)
end

local color_rate = 0

return {
  api_version = 1,
  setup = function(ctx)
    e.param("posx", 0.5, 0, 1, 1)
    e.param("posy", 0.5, 0, 1, 2)
    e.param("shape", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = function(ctx)
    local xr = ctx.width
    local yr = ctx.height
    local t = ctx.time
    local dt = ctx.dt
    local knob1 = ctx.params.posx
    local knob2 = ctx.params.posy
    local knob3 = ctx.params.shape
    local knob4 = ctx.params.fg
    local bg = ctx.params.bg
    local left = ctx.audio.left

    -- Background: stock color_picker_bg, exact formula, with the documented
    -- phase remap (pure white at c = 1 is verifier-rejected).
    local c = (bg * 0.7 + 0.15) % 1
    local r = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
    local g = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
    local b = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
    e.clear(r, g, b)

    -- Colour accumulator: per-frame catch-up at the stock per-second rate
    -- (360 circles/frame * 30 fps * knob4 * 0.02 = 216 * knob4 * dt).
    color_rate = color_rate + 216 * knob4 * dt

    local x240 = xr * 0.188
    local xhalf = xr / 2
    local yhalf = yr / 2
    local y480 = yr * 0.667
    local cool = trunc(yhalf)
    local xpos1 = trunc(knob1 * 4 * x240) - 2 * x240
    local s01 = math.sin(0.5 + t) * knob3
    local c1 = math.cos(1 + t)

    for i = 0, cool - 1 do
      local A = 0
      if left then
        local s = left[1 + (i % 99) * 10]
        if s then A = s * 32768 end
      end
      local xpos = trunc(x240 + trunc(xhalf * s01))
      local ypos = trunc(knob2 * y480 + A / 100 + trunc(30 * c1))
      local radius = trunc((30 + 20 * math.sin(i * knob3 * 3 + t)) * yr) / yr
      xpos = trunc(xr / 2 + xpos * math.sin(i + t))
      local cr, cg, cb = picker((color_rate + i * knob4 * 0.02) % 1)
      e.color(cr, cg, cb)
      e.circle(xpos + xpos1, i + ypos, trunc(radius))
    end
  end,
}
