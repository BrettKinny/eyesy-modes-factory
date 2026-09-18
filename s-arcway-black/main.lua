-- s-arcway-black — port of EYESY OSv3 stock mode "S - Arcway Black".
--
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "S - Arcway Black/main.py",
-- license BSD-2-Clause, (c) 2025 Critter & Guitari. The stock mode draws two
-- discs of 100 arcs each (3.6 degrees per arc) on a 250 px circle: a black
-- disc rotated by rotation_factor - knob3 and a coloured disc rotated by
-- rotation_factor, each arc displaced per-arc by the audio sample and by
-- ∓0.1*width so the black disc reads as a shadow behind the coloured one.
--
-- Knob roles (stock-exact):
--   1 width — line width (stock int(knob1*65)+1 px)
--   2 rate — rotation rate; left half CCW (rate*2), right half CW (-(rate*2-1))
--   3 detune — offset (rotation shift) of the bottom black disc
--   4 fg — colour of the top disc (LFO picker)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Palette substitution: stock's color_picker_lfo uses the legacy picker,
--    which is partly random (random greys / random RGB); replays must be
--    byte-identical, so the deterministic middle branch is substituted:
--    r = 0.5+0.5*sin(2*pi*c), g = 0.5+0.5*sin(4*pi*c), b = 0.5+0.5*sin(8*pi*c).
--    LFO semantics are stock-exact: for fg <= 0.5 the colour is static,
--    picker((fg*2) % 1) (computed once per frame); above 0.5, inc =
--    (fg-0.5)*0.2 persists across frames (as stock's color_lfo_inc does) and
--    arc n uses x = (phase + n*inc) % 2, folded x <= 1 and x or 2 - x.
-- 2. LFO re-time 30 -> 60 fps: stock advanced the LFO once per arc call
--    (200 calls/frame at 30 fps = 6000*inc per second); the phase is advanced
--    once per frame by 6000 * inc * ctx.dt, keeping the per-arc step within a
--    frame stock-exact.
-- 3. Rotation re-timed against ctx.dt: stock added the signed rate once per
--    frame at 30 fps; this port adds rate * 30 * ctx.dt per frame, the same
--    rate per second. rotation_factor is never wrapped (stock never wraps it).
-- 4. Audio stride: stock reads a 100-sample ring of raw +/-32768 samples with
--    audio_in[i]; ours is ctx.audio.left, 1024 normalized samples. Stock index
--    n (0-based) maps to left[1 + n*10] and is denormalized by * 32768, so
--    the stock displacement audio_in[i]/500 becomes A/500 at the same scale.
-- 5. Background phase remap: stock color_picker_bg is ported exactly but
--    returns pure white at c = 1 and pure black at c = 0, both rejected by
--    the verifier, so the bg phase is folded into the middle of the range:
--    c = (bg * 0.7 + 0.15) % 1.
-- 6. Arcs as chords: the API has no arc primitive. pygame.draw.arc draws the
--    arc of a circle centred at the moved rect; each 3.6-degree arc of the
--    250 px circle is drawn as one thick straight line (e.line) between the
--    arc's endpoints p(theta) = (cx + 250*cos(theta), cy - 250*sin(theta)),
--    y negated because pygame angles are y-up on screen. A 3.6-degree arc of a
--    250 px circle deviates from its chord by 0.12 px: visually exact.
-- 7. Stock's setup computes toplimit/leftlimit and never uses them; they are
--    omitted.

local e = eyesy
local PI = math.pi

-- 1280x720 stock geometry (setup-time constants, never wrapped).
local XRES_HALF = 640
local YRES_HALF = 360
local SQUARE_X = 500
local SIZER = 125
local RECT_X = 391 -- XRES_HALF - 0.195 * 1280
local RECT_Y = 110 -- YRES_HALF - SQUARE_X / 2
local RADIUS = 250 -- SQUARE_X / 2

-- Deterministic middle branch of the legacy picker.
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

local rotation_factor = 0
local lfo_phase = 0
local lfo_inc = 0

local function draw(ctx)
  local knob1 = ctx.params.width
  local knob2 = ctx.params.rate
  local knob3 = ctx.params.detune
  local knob4 = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt
  local left = ctx.audio.left

  -- Background: stock color_picker_bg, exact formula, with the documented
  -- phase remap (pure white at c = 1 / pure black at c = 0 are rejected).
  local c = (bg * 0.7 + 0.15) % 1
  local r = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local g = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local b = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(r, g, b)

  -- Rotation: stock signed rate, re-timed against dt (rate*30 per second).
  local rate = (knob2 <= 0.5) and (knob2 * 2) or (-(knob2 * 2 - 1))
  rotation_factor = rotation_factor + rate * 30 * dt

  -- LFO: stock inc_amt = 0.1, advanced per arc call (200/frame at 30 fps).
  if knob4 > 0.5 then
    lfo_inc = (knob4 - 0.5) * 0.2
  end
  lfo_phase = (lfo_phase + 6000 * lfo_inc * dt) % 2

  -- Static colour for the fg <= 0.5 branch (picker((fg*2) % 1), once/frame).
  local static_r, static_g, static_b = 0, 0, 0
  if knob4 <= 0.5 then
    static_r, static_g, static_b = picker((knob4 * 2) % 1)
  end

  local width = math.floor(knob1 * 65) + 1
  local shift = 0.1 * width
  local cx0 = RECT_X + RADIUS
  local cy0 = RECT_Y + RADIUS
  local two_pi_rot = 2 * PI * rotation_factor
  local two_pi_det = 2 * PI * (rotation_factor - knob3)
  local step = PI / 50

  for n = 0, 99 do
    -- Audio: stock index n (0-based) -> left[1 + n*10], denormalized.
    local A = 0
    if left then
      local s = left[1 + n * 10]
      if s then A = s * 32768 end
    end
    local disp = A / 500
    local rad = SIZER * math.cos(2 * PI * n / 100)
    local radsin = SIZER * math.sin(2 * PI * n / 100)

    local start = n * step
    local stop = start + step

    -- Bottom (shadow) disc: black, rotated by rotation_factor - detune.
    local bdx = rad + disp - shift
    local bdy = radsin + disp - shift
    local bcx = cx0 + bdx
    local bcy = cy0 + bdy
    local a0 = start + two_pi_det
    local a1 = stop + two_pi_det
    e.color(0, 0, 0)
    e.line(bcx + RADIUS * math.cos(a0), bcy - RADIUS * math.sin(a0),
           bcx + RADIUS * math.cos(a1), bcy - RADIUS * math.sin(a1), width)

    -- Top disc: LFO colour, rotated by rotation_factor.
    local tdx = rad + disp + shift
    local tdy = radsin + disp + shift
    local tcx = cx0 + tdx
    local tcy = cy0 + tdy
    local a2 = start + two_pi_rot
    local a3 = stop + two_pi_rot
    local cr, cg, cb
    if knob4 <= 0.5 then
      cr, cg, cb = static_r, static_g, static_b
    else
      local x = (lfo_phase + n * lfo_inc) % 2
      x = x <= 1 and x or 2 - x
      cr, cg, cb = picker(x)
    end
    e.color(cr, cg, cb)
    e.line(tcx + RADIUS * math.cos(a2), tcy - RADIUS * math.sin(a2),
           tcx + RADIUS * math.cos(a3), tcy - RADIUS * math.sin(a3), width)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("width", 0.5, 0, 1, 1)
    e.param("rate", 0.5, 0, 1, 2)
    e.param("detune", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
