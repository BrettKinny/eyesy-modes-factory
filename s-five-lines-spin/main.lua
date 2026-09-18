-- s-five-lines-spin — port of EYESY OSv3 stock mode "S - Five Lines Spin".
--
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Five Lines Spin/main.py", license BSD-2-Clause, (c) 2025 Critter &
-- Guitari. The stock mode draws five lines from fixed pivots on the left
-- (x = i*256 + 128, y = 360 on the 1280x720 canvas) to endpoints on a circle
-- of radius R centred on the frame centre; all endpoints share the angle
-- speed/1000*6.28, so the five lines sweep together like a hand of clock
-- hands. speed accumulates from knob1 (dead zone 0.48-0.52) and the per-line
-- colour advances through a five-step rainbow by color_rate from knob4.
-- Stock's setup computes x8th = int(xres*0.00625) and never uses it; omitted.
--
-- Knob roles (stock-exact):
--   1 spin — rate of rotation & direction (dead zone 0.48-0.52)
--   2 length — line length (radius R)
--   3 thick — line thickness (1..100 px)
--   4 shift — foreground colour shift rate & direction (dead zone 0.48-0.52)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Palette substitution: stock's color_picker (legacy) is partly random
--    (random greys / random RGB); replays must be byte-identical, so the
--    deterministic middle branch is substituted:
--    r = 0.5+0.5*sin(2*pi*c), g = 0.5+0.5*sin(4*pi*c), b = 0.5+0.5*sin(8*pi*c).
--    The per-line phase (i*0.2 + color_rate) % 1 is stock-exact, keeping the
--    five-step rainbow spread across the lines.
-- 2. Background phase remap: stock color_picker_bg is ported exactly but
--    returns pure white at c = 1 and pure black at c = 0, both rejected by
--    the verifier, so the bg phase is folded into the middle of the range:
--    c = (bg * 0.7 + 0.15) % 1. The cosine formula itself is unchanged.
-- 3. Accumulator re-time 30 -> 60 fps: stock advanced speed once per frame at
--    30 fps and color_rate once per line (5 calls/frame at 30 fps = 15 per
--    second). Here speed advances per frame by delta * 30 * ctx.dt and
--    color_rate by 5 * delta * 30 * ctx.dt, the same rates per second. speed
--    is never wrapped (stock never does); color_rate wraps with % 1 (stock
--    does).
-- 4. Audio stride: stock reads a 100-sample ring of raw +/-32768 samples with
--    audio_in[i]; ours is ctx.audio.left, 1024 normalized samples. Stock index
--    j maps to left[1 + j*10] (oldest sample of the window, 10-sample stride)
--    and is denormalized by * 32768. Stock's peak is the running maximum of
--    audio_in[i*10] for i = 0..4 in that order (later lines see the running
--    max), so j = i*10 -> left[1 + i*100]. R = 4*knob2*(peak/128) + 20 at the
--    stock scale.
-- 5. Audio floor on the reach: R = 4*(0.15 + 0.85*knob2)*(peak/128) + 20. Stock
--    routes the audio to the geometry only through knob2, so at knob2 = 0 the
--    strokes are static and the verifier's audio variants are byte-identical to
--    the baseline (measured 0.0000). The floor keeps 15 % of the response at
--    knob2 = 0 and reaches ~74 px instead of 20; the knob still scales the
--    response from 15 % to 100 %.
-- 6. Stroke thickness floor of 4 px: stock's baseline is five one-pixel
--    hairlines, about 120 lit pixels in total, and a knob change must move
--    >= 0.001 of the frame (921 px) for the gate to see it — rotating a
--    hairline cannot. The floor keeps the strokes legible; knob3 still scales
--    them from 4 px to 100 px.

local e = eyesy
local PI = math.pi

-- Deterministic middle branch of the legacy picker.
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Stock module globals.
local speed = 0
local color_rate = 0

local function draw(ctx)
  local knob1 = ctx.params.spin
  local knob2 = ctx.params.length
  local knob3 = ctx.params.thick
  local knob4 = ctx.params.shift
  local bg = ctx.params.bg
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  -- Background: stock color_picker_bg, exact formula, with the documented
  -- phase remap (pure white at c = 1 / pure black at c = 0 are rejected).
  local c = (bg * 0.7 + 0.15) % 1
  local r = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local g = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local b = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(r, g, b)

  -- Thickness: stock int(knob3 * (1280 * 0.078)) + 1 (1..100 px), floored at
  -- 4 px (deviation 6) so the baseline strokes are legible.
  local thick = math.max(4, math.floor(knob3 * 99.84) + 1)

  -- Audio: running maximum of the five stock samples, in line order
  -- (j = i*10 -> left[1 + i*100]), denormalized to the stock scale.
  local peak = 0
  for i = 0, 4 do
    if left then
      local s = left[1 + i * 100]
      if s then
        local A = s * 32768
        if A > peak then peak = A end
      end
    end
  end

  -- Radius: stock (4 * knob2 * (peak / 128)) + 20, with a documented audio
  -- floor (deviation 5) so the strokes react at knob2 = 0.
  local R = 4 * (0.15 + 0.85 * knob2) * (peak / 128) + 20

  -- Rotation: stock delta * 500 per frame at 30 fps, re-timed. Never wrapped.
  local d = 0
  if knob1 < 0.48 then
    d = -(0.48 - knob1) * 500
  elseif knob1 > 0.52 then
    d = (knob1 - 0.52) * 500
  end
  speed = speed + d * 30 * dt

  -- Colour shift: stock delta * 0.09 per line at 30 fps (5 lines/frame),
  -- re-timed. Wrapped with % 1 as stock does.
  local cd = 0
  if knob4 < 0.48 then
    cd = -(0.48 - knob4) * 0.09
  elseif knob4 > 0.52 then
    cd = (knob4 - 0.52) * 0.09
  end
  color_rate = (color_rate + 5 * cd * 30 * dt) % 1

  -- Geometry: stock 6.28 (not 2*pi); pivots i*256 + 128 on y = 360.
  local ang = speed / 1000 * 6.28
  local ex = R * math.cos(ang) + 640
  local ey = R * math.sin(ang) + 360

  for i = 0, 4 do
    local cr, cg, cb = picker((i * 0.2 + color_rate) % 1)
    e.color(cr, cg, cb)
    e.line(i * 256 + 128, 360, ex + i * 256 - 512, ey, thick)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("spin", 0.5, 0, 1, 1)
    e.param("length", 0.5, 0, 1, 2)
    e.param("thick", 0.5, 0, 1, 3)
    e.param("shift", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
