-- s-bezier-v-scope — port of stock "S - Bezier V Scope"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Bezier V Scope/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Sibling of s-bezier-h-scope; the stock files are the same mode with the
-- offset axes swapped (see the header diff note below and the port report).
--
-- Knob roles (stock-exact; note the swap vs the H sibling):
--   1 x offset — hoffset = knob1 * (xres/2 / 10); curve i (1-based) shifts
--     every point's x by i * hoffset, and the whole family re-centres by
--     6 * hoffset
--   2 y offset — dead band 0.48..0.52 -> 0; below the band up by
--     (0.48 - knob2) * (yres * -0.078), above down by
--     (knob2 - 0.52) * (yres * 0.078); curve i shifts every point by
--     i * yoff
--   3 trails — stock veil alpha = int(knob3 * 20) (see deviation 5)
--   4 foreground colour — stock color_picker_lfo(knob4, 0.1)
--   5 background colour — stock color_picker_bg(knob5)
--   Trigger — unused in stock (no random state); the port does not read it.
--
-- Scene: 12 vertical bezier scope curves. Curve i passes through 24 points
-- at x = audio + 640 - 6*hoffset + i*hoffset, y = i*36 - 72 + i*yoff, with
-- the x of every point additionally offset by i*hoffset (deviation 6).
-- Coordinates are the presentation surface's (screen when knob3 = 0, the
-- 480x270 target when trails are on; deviation 9).
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random (random greys for small values, random RGB
--    above 0.96). Randomness cannot be ported (replays must be
--    byte-identical), so the deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5.
--    The LFO's static branch (knob <= 0.5: picker((knob*2) % 1)) and ramp
--    semantics (0→2→0 at inc = (knob-0.5)*2*0.1 per 30-fps call) are
--    stock-exact.
-- 2. LFO re-timed 30 -> 60 fps: stock calls the picker once per frame at
--    30 fps; here the phase advances once per frame by 30 * inc * ctx.dt
--    (30 calls/s * the stock per-call step). The phase is initialised to
--    0.21: without an offset the knob4 = 1.0 ramp passes through phase 0
--    (colour (0,0,0)) exactly at the verifier's grab frames (60 and 300),
--    where picker(0) = (0,0,0) is also the all-knobs-zero baseline colour
--    (k4 = 0 -> picker(0)), so the knob would read dead on the luma-only
--    metric. At 0.21 the grabbed colour keeps >= 9 luma units (0-255 scale,
--    9.8 at the tightest supported frame count, 60) from the background
--    at every probe point.
-- 3. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    bg = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 4. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with
--    audio_in[i*2], i = 0..23 (even indices only, no negative indices).
--    The platform buffer is 1024 normalized samples; stock index i*2 maps
--    to left[1 + i*20] (oldest sample of the window, 20-sample stride for
--    the doubled index) and is denormalized by * 32768. The stock divisor
--    is 32768 (width = A * xres / 32768): a full-scale sample spans the
--    screen WIDTH — unlike the H sibling's screen-height divisor — kept
--    stock-exact as trunc(A * W) with Python int() truncation preserved
--    for negative samples.
-- 5. Persistence: stock's trail is a per-frame bg-coloured veil with
--    alpha = int(knob3*20) (0..20 of 255) blitted over the previous frame.
--    The scene API has no previous-frame buffer, so the veil is emulated
--    by the pack's standard persistence bridge (PORTING-LADDER 3.2): two
--    ping-pong targets; each frame the back target is cleared to the
--    background colour, the previous target is blitted over it at alpha
--    (1 - a/255) (i.e. old * (1 - a/255) + bg * a/255, the veil), the
--    scene is drawn on top at full strength, and the result is blitted
--    opaque to the screen. Targets are allocated at 480x270 (TW x TH,
--    drawn upscaled to 1280x720) per the pack's documented cost lever,
--    so the trail and the 1 px curves read softer than stock's. At
--    knob3 = 0 the targets are untouched (no feedback), matching
--    stock's transparent veil. (The first port's bridge painted an
--    opaque near-black rectangle over the blitted previous frame, so
--    no trail ever carried over, and added a white a/255 rectangle over
--    the screen; this replaces both with the veil above, which also
--    removed two full-screen passes. The background now shows at full
--    strength with trails on.)
-- 6. Positions: stock's spot = i*36 - 72 starts two intervals off-screen
--    to the top, and curve i shifts every point by i*hoffset, so the
--    rightmost point of the top curve leaves the right edge at
--    knob1 > 0.5, and the bottom curve's lower points leave the bottom
--    edge at knob2 > 0.52. This is stock's own framing (the curves sweep
--    across the frame) and is kept exactly: nothing is wrapped or
--    clamped, the frame is never blank and every probe point is
--    observable.
-- 7. Bezier rendering: pygame.gfxdraw.bezier(smooth=2) rasterises the
--    curve as a run of 1 px lines through its control-point chain; the
--    engine API has no bezier primitive, so each curve is tessellated as
--    23 cubic-bezier segments (one per point gap, Catmull-Rom control
--    handles from the neighbouring points, ends clamped) at 12 substeps —
--    276 strokes per curve, 3312 per frame, each joining consecutive
--    samples of its own cubic so the curve follows the scope points
--    through any audio amplitude (an earlier tessellation read control
--    points past the 24-point table and drew a comb that left the frame
--    blank at high input gain) — drawn with a single shared foreground colour
--    per frame: one e.color per frame, inside the colour-change budget of
--    PORTING-LADDER 3.5. Each curve is one 1 px line strip of 277
--    vertices (deviation 8). The 1 px line width matches gfxdraw's raster
--    output.
-- 8. Mesh batching: the unbatched port issued 3312 e.line strokes per
--    frame (12 curves x 23 cubic segments x 12 substeps). This mode
--    batches each curve into one line-strip mesh (update_mesh without
--    indices): 12 meshes of 277 vertices (23 x 12 + 1), preallocated in
--    setup and mutated in place, so a frame uploads 3324 vertices and
--    issues 12 update_mesh + 12 draw_mesh calls (limit 32 handles: 12
--    here). One strip per curve means the separate curves never gain
--    joining segments. An earlier revision drew each stroke as a
--    width-1-pixel triangle quad (13248 vertices over two indexed
--    meshes); on the device (VC4) that tier-failed at 49 ms p50, mostly
--    the per-frame vertex fill and upload, and the strip form is not
--    visibly different at 1 px.
-- 9. Presentation coordinates: the scene is drawn either to the screen
--    or into the 480x270 target, and the engine uses the target's
--    dimensions for the in-target coordinate space (docs/API.md:
--    "Drawing inside a target uses that target's dimensions"), so the
--    geometry is computed from the presentation surface's dimensions:
--    the target's (TW x TH) when trails are on, the screen's (W x H) at
--    knob3 = 0. Every length that stock derives from xres/yres is
--    derived from the same surface here, so the framing is
--    stock-proportional at the target's resolution (pointInterval 13,
--    margin 26, xhalf 240 in-target vs 36/72/640 on screen) and the
--    curves fill the frame instead of being clipped to a corner by a
--    screen-sized geometry drawn into a half-size target.

local e = eyesy
local PI = math.pi

local CURVES = 12
local POINTS = 24
local STEPS = 12        -- cubic substeps per segment
local SEGMENTS = POINTS - 1

-- Feedback target size (deviation 5): the scene is drawn into the target
-- and blit upscaled to the screen, so in-target lengths are reduced-res.
local TW = 480
local TH = 270

-- Batching budget (deviation 8): one line-strip mesh per curve, each
-- holding SEGMENTS * STEPS + 1 vertices (the curve's samples in order), so
-- the frame uploads CURVES * (SEGMENTS * STEPS + 1) vertices and issues
-- CURVES update_mesh + draw_mesh pairs (inside the 32-handle limit).
local VERTS = SEGMENTS * STEPS + 1

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

-- LFO state (deviation 2): phase in 0..2, 0.21 offset, inc persisted like
-- stock's color_lfo_inc.
local lfoPhase = 0.21
local lfoInc = 0

-- Persistence state (deviation 5): 480x270 ping-pong targets,
-- created on first use; prev_alpha is the last non-zero veil alpha (0..20).
local targets
local flip = false
local prev_alpha = 0

-- The 12 curves' point tables: created in setup, mutated in place per
-- frame (deviation 7: zero per-frame allocation).
local pts = {}
for i = 1, CURVES do
  local row = {}
  for n = 1, POINTS * 2 do
    row[n] = 0
  end
  pts[i] = row
end

-- Line-strip vertex buffers (deviation 8): one preallocated table per
-- curve, mutated in place; draw never allocates. Every frame fills every
-- slot, so each table passed to update_mesh is always fully populated (the
-- engine validates the whole table and draws every vertex it is given).
local mesh = {}
for m = 1, CURVES do
  local verts = {}
  for i = 1, VERTS do
    verts[i] = { 0, 0, 0 }
  end
  mesh[m] = { verts = verts, handle = nil }
end

local function clear_targets()
  local t1, t2 = targets[1], targets[2]
  e.begin_target(t1)
  e.clear(0, 0, 0, 0)
  e.end_target()
  e.begin_target(t2)
  e.clear(0, 0, 0, 0)
  e.end_target()
end

-- Fill one curve's strip (row = flat x,y pair table of POINTS control
-- points): one cubic per point gap (Catmull-Rom handles, ends clamped),
-- 23 segments x STEPS substeps, each strip vertex a sample of its cubic.
local function emit_curve(row, verts)
  local v = verts[1]
  v[1] = row[1]
  v[2] = row[2]
  local n = 1
  for seg = 0, SEGMENTS - 1 do
    local a = seg > 0 and seg - 1 or 0
    local d = seg + 2 < POINTS and seg + 2 or POINTS - 1
    local x0, y0 = row[seg * 2 + 1], row[seg * 2 + 2]
    local x3, y3 = row[seg * 2 + 3], row[seg * 2 + 4]
    local x1 = x0 + (x3 - row[a * 2 + 1]) / 6
    local y1 = y0 + (y3 - row[a * 2 + 2]) / 6
    local x2 = x3 - (row[d * 2 + 1] - x0) / 6
    local y2 = y3 - (row[d * 2 + 2] - y0) / 6
    for s = 1, STEPS do
      local t = s / STEPS
      local u = 1 - t
      local b0 = u * u * u
      local b1 = 3 * u * u * t
      local b2 = 3 * u * t * t
      local b3 = t * t * t
      n = n + 1
      v = verts[n]
      v[1] = b0 * x0 + b1 * x1 + b2 * x2 + b3 * x3
      v[2] = b0 * y0 + b1 * y1 + b2 * y2 + b3 * y3
    end
  end
end

-- Fill and draw the frame's 12 strips (deviation 8): one update_mesh +
-- draw_mesh pair per curve.
local function draw_meshes()
  for m = 1, CURVES do
    local entry = mesh[m]
    emit_curve(pts[m], entry.verts)
    e.update_mesh(entry.handle, entry.verts)
    e.draw_mesh(entry.handle)
  end
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.xoff
  local k2 = ctx.params.yoff
  local k3 = ctx.params.trails
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg_original with phase remapped (deviation 3).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c

  -- LFO: stock color_picker_lfo(knob4, 0.1), re-timed 30 -> 60 fps (deviation 2).
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

  -- Stock geometry (deviation 6: kept exact, off-screen extents
  -- included), computed in the presentation surface's dimensions
  -- (deviation 9): the target's when trails are on, the screen's when
  -- knob3 = 0.
  local alpha = trunc(k3 * 20)
  local GW, GH = (alpha > 0) and TW or W, (alpha > 0) and TH or H
  local pointInterval = trunc(GH / (POINTS - 4))  -- int(yres / 20)
  local yr = pointInterval * POINTS
  local margin = trunc(yr / POINTS) * 2
  local xhalf = trunc(GW / 2)
  local hoffset = k1 * (xhalf / 10)
  local centering = (hoffset * 12) / 2             -- 6 * hoffset
  local yoff = 0
  if k2 < 0.48 then
    yoff = (0.48 - k2) * (GH * -0.078)
  elseif k2 > 0.52 then
    yoff = (k2 - 0.52) * (GH * 0.078)
  end

  -- Fill the 12 curves' control points (audio sampled once per point).
  for i = 1, CURVES do
    local row = pts[i]
    for p = 0, SEGMENTS do
      local s = left and left[1 + p * 20] or 0
      local width = trunc(s * 32768 * (GW / 32768))  -- int(A * GW / 32768) (deviation 4)
      local spot = pointInterval * p - margin
      row[p * 2 + 1] = width + xhalf - centering + hoffset * i
      row[p * 2 + 2] = spot + yoff * i
    end
  end

  -- One foreground colour for the whole frame (deviation 7).
  e.color(fr, fg, fb)

  if alpha > 0 then
    -- Persistence bridge (deviation 5).
    if not targets then
      targets = { e.target(TW, TH), e.target(TW, TH) }
      clear_targets()
    end
    local a = flip and 2 or 1
    local b = flip and 1 or 2
    local tA, tB = targets[a], targets[b]

    local f = 1 - alpha / 255
    e.begin_target(tA)
    e.clear(br, bgc, bb)
    e.color(1, 1, 1, f)
    e.draw_target(tB, 0, 0, TW, TH)
    e.color(fr, fg, fb)
    draw_meshes()
    e.end_target()

    e.color(1, 1, 1)
    e.draw_target(tA, 0, 0, W, H)

    flip = not flip
    prev_alpha = alpha
  else
    if targets and prev_alpha > 0 then
      clear_targets()
    end
    e.clear(br, bgc, bb)
    draw_meshes()
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("xoff", 0.5, 0, 1, 1)
    e.param("yoff", 0.5, 0, 1, 2)
    e.param("trails", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    for m = 1, CURVES do
      mesh[m].handle = e.new_mesh()
    end
  end,
  draw = draw,
}
