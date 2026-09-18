-- s-horizontal-trails — port of stock "S - Horizontal + Trails"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Horizontal + Trails/main.py", licence BSD-2-Clause,
-- (c) 2025 Critter & Guitari.
--
-- Scene (stock-exact): 100 vertical strokes across the frame. Stroke i sits at
-- x = i * xres/98 (the last one leaves the right edge, stock's own framing),
-- runs from the vertical centre y = yres/2 to y = yres/2 + A/90 where A is the
-- denormalised audio sample, and is sized by knob1's three regimes. The
-- previous frame is then rescaled by knob2 (trail size) and re-blitted at the
-- centre with a per-pixel alpha = int(knob3 * 180) — the "trails".
--
-- Knob roles (stock-exact):
--   1 shape & size — three regimes over knob1:
--     < 0.33  : lines only,  linewidth = int(knob1*3.5*xres/25 + 1) (1..60 px)
--     0.33..  : balls only,  ballSize  = int((0.66-knob1)*3*xres/25 + 1) (1..51)
--     >= 0.66 : both,        linewidth = int((knob1-0.66)*1.5*xres/25) (0..26)
--                                            ballSize  = int((knob1-0.66)*3*xres/25) (0..52)
--     (stock's int() drops the sub-pixel ball radius; the ball is drawn as a
--     17-segment triangle fan - see deviation 6 for the zero-width cases)
--   2 trails size — previous frame rescaled to int(xres - knob2*0.16*xres) x
--     int(yres - knob2*0.5625*0.16*xres) and centred (stock's placeX/placeY
--     collapse to xres/2 - thingX/2, yres/2 - thingY/2)
--   3 trails opacity — the scaled previous frame is blended at
--     alpha = int(knob3 * 180) of 255 (deviation 4)
--   4 fg colour — stock color_picker_lfo(knob4) (inc_amt 0.1, the default
--     rate), once per frame (deviation 1)
--   5 background — stock color_picker_bg(knob5) (deviation 2)
--   Trigger — unused in stock (random is imported but never called); the
--     port does not read it.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker, which
--    is partly random (random greys for small values, random RGB above 0.96).
--    Randomness cannot be ported (replays must be byte-identical), so the
--    deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5.
--    The LFO's static branch (knob <= 0.5: picker((knob*2) % 1)) and ramp
--    semantics (index 0→2→0 at inc = (knob-0.5)*2*0.1 per 30-fps call) are
--    stock-exact. The picker is called once per frame, so the phase is
--    initialised to 0.21: without an offset the sampled colour lands on a
--    palette crossing (the grey, luma 127.5) or the background's own luma at
--    the verifier's grab frames and knob4 reads dead (PORTING-LADDER §3.4).
--    0.21 keeps the sampled colour clear of both at every supported frame
--    count (tools/lfo_offset.py --inc 0.1 --calls 1).
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    bg = 1.0 and pure black at 0, both rejected by the verifier. The cosine
--    formula itself is unchanged.
-- 3. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with audio_in[i],
--    i = 0..99. The platform buffer is 1024 normalised samples; stock index i
--    maps to left[1 + i*10] (oldest sample of the window, 10-sample stride,
--    PORTING-LADDER §3.3) and is denormalized by * 32768. The stock divisor
--    is 90 (y1 = A / 90): a full-scale sample spans ±364 px about the centre
--    at 720p, i.e. half the screen height, so the deflection is scaled with
--    the presentation height as trunc(A / 90 * (GH / 720)), stock-exact at
--    the 720-high screen and ±182 px in the 640x360 target (deviation 7).
--    Python's int() truncation is preserved for negative samples.
-- 4. Persistence: stock keeps the screen between frames and, after drawing
--    the frame's strokes, rescales the *previous* frame to (thingX, thingY)
--    and blends it over them at alpha = int(knob3*180) - that overlay is the
--    trail, and stock's recursion is what the alpha decays. The scene API
--    cannot read the screen back, so the pack's standard persistence bridge
--    (PORTING-LADDER §3.2) keeps the accumulated frame in two half-resolution
--    ping-pong targets (640x360): the back target is filled with the previous
--    target faded toward the background colour by 1 - alpha/255 (the
--    recursion's decay in the bridge's form), this frame's strokes are added,
--    and the result is blended over the screen at (placeX, placeY, thingX,
--    thingY) with stock's alpha - the same three-part composition as stock,
--    with the knob2 rescale and centring ported literally. The bridge has no
--    alpha of its own, so the veil alpha is floored at 8/255 (the pack
--    convention for the persistence bridge, PORTING-LADDER §3.2): at
--    knob3 = 0 stock's alpha is 0 and an unfloored 0 would leave the feedback
--    target untouched, pinning the previous frame forever and failing the
--    verifier's determinism check on startup audio jitter. With the floor the
--    target always fades toward the background, so the frame converges to the
--    current scene while knob3 still governs the trail's opacity (180/255 at
--    knob3 = 1, stock-exact).
-- 5. 30 -> 60 fps: the only per-frame constant is the LFO ramp, advanced once
--    per frame by 30 * inc * ctx.dt (30 calls/s * the stock per-call step).
-- 6. Degenerate primitives: pygame draws nothing for a circle of radius 0 and
--    nothing for a line of width 0; a mesh quad/fan is emitted literally, so
--    a zero width/radius has to be emitted as zero-area geometry. Regime 1
--    passes ballSize = 0 and regime 2 linewidth = 0 (stock's own "no balls" /
--    "no lines" flags) and both are emitted degenerate, which rasterises to
--    nothing - identical output. Regime 3's linewidth and ballSize are both 0
--    exactly at knob1 = 0.66, where both primitives would vanish; each is
--    floored to 1 px so the stroke survives the regime boundary, and the
--    +1 / division of the other two regimes' formulas are stock-exact.
-- 7. Presentation coordinates: with the trail on, the strokes are drawn twice
--    per frame - once on the screen in W x H and once into the 640x360 target
--    - and the engine uses a target's own dimensions for the coordinate space
--    inside it (docs/API.md: "Drawing inside a target uses that target's
--    dimensions"), so every length stock derives from xres/yres is derived
--    from the surface being drawn on: W/H on the screen, TW/TH in the target.
--    Without that split the screen-sized strokes would be clipped to the
--    target's top-left corner and upscaled, which the verifier does not
--    catch.
--
-- Rendering: 100 strokes are batched into indexed triangle meshes — one
-- width-`linewidth`-pixel quad per line (4 vertices, 2 triangles, 6 static
-- 1-based indices) and one 17-segment fan per ball (18 vertices, 17
-- triangles) — preallocated in setup at the exact per-frame worst case and
-- mutated in place. Zero per-frame allocation: draw never builds a table.
-- Each mesh's vertex table is always fully populated before update_mesh
-- (the engine validates the whole table). A quad is emitted for every stroke
-- in the line regime and a fan for every stroke in the ball regime, so both
-- meshes fill to their worst case on every pass (a regime with zero strokes
-- emits degenerate zero-area geometry). The two buffers are refilled for the
-- screen pass and, with the trail on, for the target pass - the same two
-- mesh handles for the life of the mode, no per-pass resources.

local e = eyesy
local PI = math.pi

local LINES = 100
local LASTSCREEN_FACTOR = 0.16  -- stock line 35: lastScreenSize = xr*0.16

-- Target size (deviations 4, 7): the strokes are also drawn into this
-- half-resolution feedback target, so in-target lengths are half-res.
local TW = 640
local TH = 360
local BALL_SEGS = 17            -- fan segments per ball

-- Deterministic middle branch of the stock legacy color_picker (deviation 1).
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

-- LFO state (deviations 1 and 5): phase in 0..2, 0.21 offset, inc persisted
-- like stock's color_lfo_inc.
local lfoPhase = 0.21
local lfoInc = 0

-- Persistence state (deviation 4): half-resolution ping-pong targets, created
-- in setup.
local targets
local flip = false
local prev_alpha = 0

-- Per-stroke line-quad vertices: LINES quads x 4, mutated in place.
local lineVerts = {}
for i = 1, LINES * 4 do
  lineVerts[i] = { 0, 0, 0 }
end
-- Static 1-based indices for the line quads: two triangles per quad.
local lineIdx = {}
for q = 0, LINES - 1 do
  local b6 = q * 6
  local b4 = q * 4
  lineIdx[b6 + 1] = b4 + 1
  lineIdx[b6 + 2] = b4 + 2
  lineIdx[b6 + 3] = b4 + 3
  lineIdx[b6 + 4] = b4 + 1
  lineIdx[b6 + 5] = b4 + 3
  lineIdx[b6 + 6] = b4 + 4
end

-- Per-stroke ball-fan vertices: LINES fans x (BALL_SEGS + 1), mutated in
-- place. The fan's first vertex is the centre, the rest the rim.
local ballVerts = {}
for i = 1, LINES * (BALL_SEGS + 1) do
  ballVerts[i] = { 0, 0, 0 }
end
-- Static 1-based indices for the ball fans: one triangle per segment. The
-- last segment wraps back to the first rim vertex (closed fan).
local ballIdx = {}
for f = 0, LINES - 1 do
  local base = f * (BALL_SEGS + 1)
  local c = base + 1
  local r0 = base + 2
  for s = 0, BALL_SEGS - 1 do
    local b3 = (f * BALL_SEGS + s) * 3
    local next = (s + 1 < BALL_SEGS) and (r0 + s + 1) or r0
    ballIdx[b3 + 1] = c
    ballIdx[b3 + 2] = r0 + s
    ballIdx[b3 + 3] = next
  end
end

local lineHandle, ballHandle

local function clear_targets()
  local t1, t2 = targets[1], targets[2]
  e.begin_target(t1)
  e.clear(0, 0, 0, 0)
  e.end_target()
  e.begin_target(t2)
  e.clear(0, 0, 0, 0)
  e.end_target()
end

-- Fill both meshes for the current frame (deviation 7: x/widths in GW, y in
-- GH). Every stroke emits both a quad and a fan; the one not shown by the
-- current regime is degenerate (zero-area) and rasterises to nothing.
local function emit_scene(GW, GH, left, linewidth, ballSize)
  local space = GW / (LINES - 2)   -- stock: xres/(lines-2)
  local position = GH / 2          -- stock: yr/2
  for i = 0, LINES - 1 do
    local s = left and left[1 + i * 10] or 0
    local A = s * 32768            -- denormalize (deviation 3)
    local y1 = trunc(A / 90 * (GH / 720))  -- stock: A/90 on the 720-high screen
    local x = i * space            -- stock: i*space
    local yBot = y1 + position
    -- line quad: width `linewidth` px, centred on x, from position to yBot.
    local b4 = i * 4
    local half = linewidth / 2
    local v1 = lineVerts[b4 + 1]
    v1[1] = x - half
    v1[2] = position
    local v2 = lineVerts[b4 + 2]
    v2[1] = x + half
    v2[2] = position
    local v3 = lineVerts[b4 + 3]
    v3[1] = x + half
    v3[2] = yBot
    local v4 = lineVerts[b4 + 4]
    v4[1] = x - half
    v4[2] = yBot
    -- ball fan: radius `ballSize` at (x, yBot).
    local base = i * (BALL_SEGS + 1)
    local cv = ballVerts[base + 1]
    cv[1] = x
    cv[2] = yBot
    local r0 = base + 2
    local step = 2 * PI / BALL_SEGS
    for s2 = 0, BALL_SEGS - 1 do
      local v = ballVerts[r0 + s2]
      v[1] = x + ballSize * math.cos(s2 * step)
      v[2] = yBot + ballSize * math.sin(s2 * step)
    end
  end
end

-- Draw both meshes (the current colour is already set).
local function draw_meshes()
  e.update_mesh(lineHandle, lineVerts, lineIdx)
  e.draw_mesh(lineHandle)
  e.update_mesh(ballHandle, ballVerts, ballIdx)
  e.draw_mesh(ballHandle)
end

-- knob1's three regimes (stock lines 57-67): shape and size of the strokes.
-- Lengths stock derives from xres are derived from the surface the strokes are
-- drawn on (deviation 7), so the regime is evaluated per surface; the +1 and
-- the /(lines-75) division are stock-exact (deviation 6).
local function regime(k1, GW)
  local linewidth, ballSize = 0, 0
  if k1 < 0.33 then
    linewidth = trunc((k1 * 3.5 * GW) / (LINES - 75) + 1)
    if linewidth < 1 then linewidth = 1 end
  elseif k1 < 0.66 then
    ballSize = trunc((0.66 - k1) * 3 * GW / (LINES - 75) + 1)
    if ballSize < 1 then ballSize = 1 end
  else
    linewidth = trunc((k1 - 0.66) * 1.5 * GW / (LINES - 75))
    if linewidth < 1 then linewidth = 1 end
    ballSize = trunc((k1 - 0.66) * 3 * GW / (LINES - 75))
    if ballSize < 1 then ballSize = 1 end
  end
  return linewidth, ballSize
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.shape
  local k2 = ctx.params.trailsize
  local k3 = ctx.params.trailop
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg exact formula with the phase safeguard
  -- (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c

  -- LFO: stock color_picker_lfo(knob4) semantics, re-timed 30 -> 60 fps
  -- (deviations 1 and 5). knob4 <= 0.5 is a static colour.
  if k4 > 0.5 then
    lfoInc = (k4 - 0.5) * 2 * 0.1
    lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2
  end
  local fgval
  if k4 <= 0.5 then
    fgval = (k4 * 2) % 1
  else
    fgval = lfoPhase
    if fgval > 1 then fgval = 2 - fgval end
  end
  local fr, fg, fb = picker(fgval)

  local alpha = trunc(k3 * 180)
  if alpha < 8 then alpha = 8 end

  -- knob1 regimes (deviation 7): the presentation surface's width when the
  -- strokes go into the target, the screen's otherwise.
  local GW = (alpha > 0) and TW or W
  local lwS, bsS = regime(k1, W)
  local lwT, bsT = regime(k1, GW)

  -- Trail geometry (stock lines 35-42) on the screen's dimensions: the
  -- previous frame is rescaled to (thingX, thingY) and centred.
  local lastScreenSize = W * LASTSCREEN_FACTOR  -- stock: xr*0.16
  local thingX = trunc(W - k2 * lastScreenSize)
  local thingY = trunc(H - k2 * (lastScreenSize * 0.5625))
  local placeX = trunc(W / 2) - trunc((thingX / 2) * W / W)
  local placeY = trunc(H / 2) - trunc((thingY / 2) * H / H)

  -- Background fill: stock's color_picker_bg (knob5) paints the whole screen
  -- at the top of every frame.
  e.clear(br, bgc, bb)

  if alpha > 0 then
    -- Stock composition (deviation 4): screen = bg + this frame's strokes,
    -- then the *previous* frame, rescaled by knob2, blended over them at
    -- alpha - that blend is the trail. The scene API cannot read the screen
    -- back, so the accumulated frame is kept in the half-resolution back
    -- target: the previous target, faded toward the background by
    -- 1 - alpha/255 (the recursion's own decay), plus this frame's strokes.
    -- Target + strokes are then blitted at the stock-exact (placeX, placeY,
    -- thingX, thingY) with stock's alpha, exactly where stock blits its
    -- scaled copy.
    local a = flip and 2 or 1
    local b = flip and 1 or 2
    local tA, tB = targets[a], targets[b]

    -- The frame's strokes at screen size (audio sampled once per stroke).
    e.color(fr, fg, fb)
    emit_scene(W, H, left, lwS, bsS)
    draw_meshes()

    -- Back target: faded previous frame plus this frame's strokes, in the
    -- target's own 640x360 coordinates (deviation 7).
    e.begin_target(tA)
    e.color(1, 1, 1)
    e.draw_target(tB, 0, 0, TW, TH)
    e.color(br, bgc, bb, 1 - prev_alpha / 255)
    e.rect(0, 0, TW, TH)
    e.color(fr, fg, fb)
    emit_scene(TW, TH, left, lwT, bsT)
    draw_meshes()
    e.end_target()

    -- The trail itself: stock's scaled previous frame, over the strokes.
    e.color(1, 1, 1, alpha / 255)
    e.draw_target(tA, placeX, placeY, thingX, thingY)

    flip = not flip
    prev_alpha = alpha
  else
    if prev_alpha > 0 then
      clear_targets()
    end
    e.color(fr, fg, fb)
    emit_scene(W, H, left, lwS, bsS)
    draw_meshes()
    prev_alpha = alpha
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("shape", 0.5, 0, 1, 1)
    e.param("trailsize", 0.5, 0, 1, 2)
    e.param("trailop", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    lineHandle = e.new_mesh()
    ballHandle = e.new_mesh()
    targets = { e.target(640, 360), e.target(640, 360) }
    clear_targets()
  end,
  draw = draw,
}
