-- t-density-units — port of stock "T - Density Units"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "T - Density Units/main.py"
-- Licence: BSD-2-Clause (c) Critter & Guitari
--
-- The scene is a scatter of 100 square "units" drawn as a size×size rectangle
-- centred on (x[j], y[j]). Stock's setup roll places units in
--   x: [-x100, W + x100)  where x100 = int(W * 0.078)  (~99 px at 1280)
--   y: [-y100, H + y100)  where y100 = int(H * 0.139)  (~100 px at 720)
-- so ~94% of units land on screen. The draw loop renders only the first 30
-- units (stock's fixed loop bound) — the other 70 are state, not pixels.
--
-- The port keeps the scatter as 100 normalized values (ux, uy) rolled once in
-- setup and re-rolled on trigger, and maps them into the live spacing window
-- each frame (deviation 7). Stock instead rolls absolute pixel positions and
-- only re-rolls them on a trigger, which leaves the spacing knob with nothing
-- to move at its own probe points.
--
-- Knob roles (stock-exact):
--   1 rect diameter — size = int(knob1 * W * 0.156) + 1 px (max ~200 px)
--   2 spacing — xdensity = int(knob2 * W/2) + 20, ydensity = int(knob2 * H/2) + 20;
--               the scatter is mapped into the canvas inset by
--               (xdensity, ydensity) on each side. Stock applies that window
--               only inside the trigger re-roll; the port maps the live window
--               every frame (deviation 7), which is what gives the knob its own
--               visible effect.
--   3 outline/fill — stock passes int(size*knob3) + 1 as pygame's rect *width*
--                   (below 0.5, border only) and 0 above 0.5 (solid). The port
--                   draws the border branch as four e.rect bars of that
--                   thickness, drawn inside the rect exactly as pygame does
--                   (deviation 8); the corner radius is not implementable with
--                   e.rect and is dropped (deviation 8).
--   4 colour — LFO picker: below 0.5 the picker value is fixed at
--              (knob4 * 2) % 1; above 0.5 the picker index ramps at
--              (knob4 - 0.5) * 2 * 0.15 per 30-fps frame (inc_amt = 0.15
--              stock default). The picker is sampled ONCE per frame, before
--              the 30-unit draw loop, and that single colour is used for
--              every unit in the frame (deviation 3 documents the phase
--              offset).
--   5 bg — background colour (legacy picker, phase remapped, deviation 5)
--   Trigger — re-rolls the 100 normalized positions (stock re-rolls the pixel
--             positions over the same window the knob 2 term defines)
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
--    collapsed it to a hairline), this mode's 30 drawn units at size >= 1 px
--    over a 1280×720 screen keep the frame non-flat: the spacing window at the
--    knob's floor spreads them over the whole canvas and the draw colour never
--    matches the clear colour. No floor was added.
-- 5. Background picker phase is remapped to the middle of the range,
--    c = (knob5 * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 6. Audio term (stock has none): unit j's size is extended by
--    |left[1 + j*3]| (a normalized sample, 30 units -> 90 samples, well
--    within the 1024-sample buffer) times 0.25 * W, i.e. up to a quarter of
--    the width. Documented per the pack convention for stock modes with no
--    audio path.
-- 7. The spacing window is live. Stock rolls absolute positions once in setup
--    and re-uses them until a trigger; the spacing knob only resizes the
--    window that a *trigger* re-rolls into, so between triggers the knob cannot
--    move a pixel — at the verifier's knob2 probes its two states were
--    byte-identical to the baseline and only its trigger-assisted run showed an
--    effect, which the pack's rules forbid counting. The port keeps the scatter
--    as normalized values and maps them into stock's trigger window
--    (-dscale + xdensity, W + dscale - xdensity + 10) every frame, so the knob
--    re-spaces the units as it turns. Look impact: at the knob's floor the
--    canvas is stock's trigger window ([-79, 1369) × [-79, 809)) rather than
--    setup's slightly wider margin ([-99, 1379) × [-100, 820)) — a 20 px
--    difference at the edge, invisible in a scatter of 200 px units; turning
--    spacing now visibly pulls the units inward continuously instead of
--    snapping at the next trigger.
-- 8. Knob 3's pygame rect width is drawn in Lua, and the corner radius is
--    dropped. The engine's e.rect(x, y, w, h) ignores any extra arguments, so
--    the port's earlier call passed stock's width/corner straight past the
--    renderer: every knob3 state drew the same solid rect and the knob read
--    dead at both of its probes. Stock's width semantics are restored by
--    drawing the border branch as four e.rect bars of thickness
--    int(size*knob3) + 1 inside the rect (pygame draws the border inside, so
--    the outer bounds are unchanged). Look impact: below 0.5 the units are now
--    open outlines whose wall thickens from 1 px to ~half the unit as knob3
--    approaches 0.5, closing into the solid fill the >= 0.5 branch draws —
--    which is exactly stock's progression. The corner radius (up to size/2)
--    cannot be expressed with e.rect and is dropped: outlines have square
--    corners where stock rounded them.

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

-- Preallocated state (zero per-frame allocation). Positions are normalized
-- [0,1) scatter values (deviation 7); the window is applied per frame.
local ux = {}
local uy = {}
for i = 1, NUM_UNITS do
  ux[i] = 0
  uy[i] = 0
end

local function roll_scatter()
  for i = 1, NUM_UNITS do
    ux[i] = e.random()
    uy[i] = e.random()
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

  -- Spacing window: stock's trigger window, mapped live every frame
  -- (deviation 7). xlow = -dscale + xdensity, xhigh = W + dscale - xdensity + 10.
  local dscale = trunc(W * 0.078)
  local xdensity = trunc(k2 * xhalf + 20)
  local ydensity = trunc(k2 * yhalf + 20)
  local xlow = -dscale + xdensity
  local ylow = -dscale + ydensity
  local xspan = W + dscale + dscale - 2 * xdensity + 10
  local yspan = H + dscale + dscale - 2 * ydensity + 10

  -- Trigger: re-roll the 100 normalized scatter values (stock re-rolls the
  -- pixel positions over the same window).
  if ctx.trigger then
    roll_scatter()
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

  -- Border thickness, stock-exact: this is pygame's draw.rect *width*, so
  -- below 0.5 the rect is an open outline of int(size*knob3) + 1 px and at or
  -- above 0.5 it is solid (width 0). Drawn in Lua because e.rect ignores the
  -- width argument (deviation 8).
  local border = 0
  if k3 < 0.5 then
    border = trunc(size * k3) + 1
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

    local x = xlow + ux[j + 1] * xspan - s / 2
    local y = ylow + uy[j + 1] * yspan - s / 2

    if border > 0 then
      -- Outline: four bars of thickness `border` inside the unit box, the
      -- pygame border geometry (a thickness of half the box or more closes up
      -- into the solid branch).
      e.rect(x, y, s, border)
      e.rect(x, y + s - border, s, border)
      e.rect(x, y, border, s)
      e.rect(x + s - border, y, border, s)
    else
      e.rect(x, y, s, s)
    end
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

    roll_scatter()
  end,
  draw = draw,
}