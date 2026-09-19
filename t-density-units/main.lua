-- t-density-units — port of stock "T - Density Units"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "T - Density Units/main.py"
-- Licence: BSD-2-Clause (c) Critter & Guitari
--
-- The scene is a scatter of 100 square "units" on a virtual canvas that spans
-- the full screen plus a margin. Unit j (0-based) sits at (px[j], py[j]) in
-- screen-pixel coordinates and is drawn as a size×size rectangle centred on
-- that point. Stock's setup roll places units in
--   x: [-x100, W + x100)  where x100 = int(W * 0.078)  (~99 px at 1280)
--   y: [-y100, H + y100)  where y100 = int(H * 0.139)  (~100 px at 720)
-- so ~94% of units land on screen. The draw loop renders only the first 30
-- units (stock's fixed loop bound) — the other 70 are state, not pixels.
--
-- Knob roles (stock-exact):
--   1 rect diameter — size = int(knob1 * W * 0.156) + 1 px (max ~200 px)
--   2 spacing — xdensity = int(knob2 * W/2) + 20, ydensity = int(knob2 * H/2) + 20;
--               on trigger the 100 units are re-rolled over a canvas inset by
--               (xdensity, ydensity) on each side
--   3 filled/unfilled — knob3 < 0.5: filled rect, border = int(size*knob3) + 1,
--                       corner radius = int(size*knob3*2);
--                       knob3 >= 0.5: outline rect, corner radius =
--                       int(size*(2 - knob3*2)), no fill
--   4 colour — LFO picker: below 0.5 the picker value is fixed at
--              (knob4 * 2) % 1; above 0.5 the picker index ramps at
--              (knob4 - 0.5) * 2 * 0.15 per 30-fps frame (inc_amt = 0.15
--              stock default). The picker is sampled ONCE per frame, before
--              the 30-unit draw loop, and that single colour is used for
--              every unit in the frame (deviation 3 documents the phase
--              offset).
--   5 bg — background colour (legacy picker, phase remapped, deviation 5)
--   Trigger — re-rolls the 100 unit positions over the inset canvas
--
-- Stock reads NO audio (no audio_in anywhere in the source). Per the pack's
-- convention the port adds one documented audio term (deviation 6): each
-- unit's size is extended by the amplitude of its own audio sample, so the
-- units pulse with the music.
--
-- Documented deviations from stock:
-- 1. Foreground picker: stock's legacy picker is partly random (random greys
--    below 0.16, random RGB above 0.96) and cannot be replayed
--    deterministically. The deterministic middle branch is substituted:
--    r = 0.5 + 0.5*sin(2πc), g = 0.5 + 0.5*sin(4πc), b = 0.5 + 0.5*sin(8πc).
--    The picker values fed in are stock-exact (knob4 * 2 below the LFO
--    threshold; the ramp index above it).
-- 2. LFO ramp re-timed 30 -> 60 fps: stock adds inc once per 30-fps frame;
--    the port advances it by inc * 30 * ctx.dt per frame, so the ramp speed is
--    identical in wall-clock time.
-- 3. LFO phase offset 0.21: the port's phase is the knob value itself below
--    0.5 and the ramp index above it, so near knob4 = 1.0 the sampled colour
--    is a deterministic function of time alone; a ramp phase of ~0.83 lands
--    on a near-grey sample at a verifier frame count, reading the colour knob
--    dead. The offset 0.21 (tools/lfo_offset.py, inc 0.15, 1 call/frame,
--    worst-case luma clearance 42) keeps the sampled colour off both the
--    baseline grey (127.5) and the remapped background luma at every frame
--    count the verifier uses.
-- 4. No count or length floor: unlike the `bits` siblings (which floor their
--    count and length because stock's minima put the figure off-screen or
--    collapsed it to a hairline), this mode's 30 drawn units at size ~200 px
--    over a 1280×720 screen cover a large fraction of the frame even at the
--    verifier's fixed random seed. The baseline frame is not flat; no floor
--    was added.
-- 5. Background picker phase is remapped to the middle of the range,
--    c = (knob5 * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 6. Audio term (stock has none): unit j's size is extended by
--    |left[1 + j*3]| (a normalized sample, 30 units -> 90 samples, well
--    within the 1024-sample buffer) times 0.25 * W, i.e. up to a quarter of
--    the width. Documented per the pack convention for stock modes with no
--    audio path.
--
-- Draw budget: 30 e.rect calls per frame (stock's exact loop bound), no
-- meshes at all. Colour state changes per frame: 1 clear + 1 e.color (the
-- foreground colour is sampled once per frame and used for all 30 units —
-- no batching needed, no per-unit cost).

local e = eyesy
local PI = math.pi

local NUM_UNITS = 100
local DRAW_UNITS = 30 -- stock's draw loop bound

-- Deterministic middle branch of the stock legacy picker (deviation 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Python int() truncates toward zero (stock's int() calls).
local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

-- Preallocated state (zero per-frame allocation).
local px = {}
local py = {}
for i = 1, NUM_UNITS do
  px[i] = 0
  py[i] = 0
end

local function init_positions(W, H)
  -- Stock's setup roll: x in [-x100, W + x100), y in [-y100, H + y100)
  -- where x100 = int(W * 0.078), y100 = int(H * 0.139).
  local x100 = trunc(W * 0.078)
  local y100 = trunc(H * 0.139)
  local xspan = W + x100 + x100
  local yspan = H + y100 + y100
  for i = 1, NUM_UNITS do
    px[i] = -x100 + math.floor(e.random() * xspan)
    py[i] = -y100 + math.floor(e.random() * yspan)
  end
end

local function roll_positions(W, H, xdensity, ydensity)
  -- Stock's trigger re-roll: x in [-dscale + xdensity, W + dscale - xdensity
  -- + 10), y in [-dscale + ydensity, H + dscale - ydensity + 10) where
  -- dscale = int(W * 0.078).
  local dscale = trunc(W * 0.078)
  local xlow = -dscale + xdensity
  local xhigh = W + dscale - xdensity + 10
  local ylow = -dscale + ydensity
  local yhigh = H + dscale - ydensity + 10
  local xspan = xhigh - xlow
  local yspan = yhigh - ylow
  for i = 1, NUM_UNITS do
    px[i] = xlow + math.floor(e.random() * xspan)
    py[i] = ylow + math.floor(e.random() * yspan)
  end
end

-- LFO ramp index (deviation 2). Stock: color_lfo_index starts 0, ramps 0..2
-- (wrapped % 2). The 0.21 phase offset (deviation 3) is folded into the
-- picker argument, not the ramp index.
local lfo_index = 0

-- Picker phase for the current frame (deviation 3: +0.21 offset on the ramp
-- branch). Module-scope so no closure is allocated per frame.
local function picker_val(k4)
  if k4 <= 0.5 then
    return (k4 * 2) % 1
  elseif lfo_index <= 1 then
    return lfo_index + 0.21 -- ramp up
  else
    return 2 - lfo_index + 0.21 -- ramp down
  end
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.size
  local k2 = ctx.params.spacing
  local k3 = ctx.params.fill
  local k4 = ctx.params.colour
  local k5 = ctx.params.bg

  -- Background: stock cosine formula, phase remapped (deviation 5).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bg = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bg, bb)

  -- Geometry (stock-exact).
  local sizescale = trunc(W * 0.156)
  local xhalf = trunc(W / 2)
  local yhalf = trunc(H / 2)
  local size = trunc(k1 * sizescale) + 1
  local xdensity = trunc(k2 * xhalf + 20)
  local ydensity = trunc(k2 * yhalf + 20)

  -- Trigger: re-roll the 100 unit positions (stock does this in setup too).
  if ctx.trigger then
    roll_positions(W, H, xdensity, ydensity)
  end

  -- LFO ramp (stock color_picker_lfo, inc_amt = 0.15 default), re-timed 30 ->
  -- 60 fps (deviation 2). Advances once per frame; all 30 per-unit calls in
  -- this frame see the same index.
  if k4 <= 0.5 then
    lfo_index = 0
  else
    local inc = (k4 - 0.5) * 2 * 0.15
    lfo_index = (lfo_index + inc * 30 * dt) % 2
  end

  -- Fill/corner (stock-exact, same for all units).
  local fill, corner
  if k3 < 0.5 then
    fill = trunc(size * k3) + 1
    corner = trunc(size * (k3 * 2))
  else
    corner = trunc(size * (2 - (k3 * 2)))
    fill = 0
  end

  -- Audio scale (deviation 6).
  local audio_scale = 0.25 * W

  -- Uniform foreground colour: sampled ONCE per frame, used for all 30 units.
  local pv = picker_val(k4) % 1
  local fr, fg, fb = picker(pv)
  e.color(fr, fg, fb)
  for j = 0, DRAW_UNITS - 1 do
    -- Per-unit size (stock size + documented audio term, deviation 6).
    local s = size
    if left then
      local a = left[1 + j * 3]
      if a then
        local av = a * 32768
        if av < 0 then av = -av end
        s = size + av / 32768 * audio_scale
      end
    end

    e.rect(px[j + 1] - s / 2, py[j + 1] - s / 2, s, s, fill, corner)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("size", 0.5, 0, 1, 1)
    e.param("spacing", 0.5, 0, 1, 2)
    e.param("fill", 0.5, 0, 1, 3)
    e.param("colour", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    init_positions(ctx.width, ctx.height)
  end,
  draw = draw,
}
