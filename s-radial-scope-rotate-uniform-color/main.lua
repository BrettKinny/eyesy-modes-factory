-- s-radial-scope-rotate-uniform-color - port of stock
-- "S - Radial Scope - Rotate Uniform Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Radial Scope - Rotate Uniform Color/main.py" (68 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob roles (stock-exact):
--   1 rotation rate and direction - increment 0 while 0.48 <= knob1 <= 0.52,
--     else (knob1 - 0.5) * 20 degrees per stock 30-fps frame
--   2 scope diameter - R1 = int(knob2 * x800), x800 = xres * 0.625
--   3 line width & circle size - sel = knob3 * 2: sel < 1 draws each radial
--     segment with width int((1-sel)*x20)+1 plus a filled circle of radius
--     int((1-sel)*(x20-2))+1 at the tip; sel >= 1 draws the same line with
--     width int((sel-1)*x20)+1 and no circle (x20 = xres * 0.016)
--   4 foreground colour - the "uniform" term: picker(knob4) computed ONCE per
--     frame (stock calls color_picker_lfo(knob4) before the segment loop), so
--     all 75 segments share one colour
--   5 background colour - stock color_picker_bg(knob5)
--
-- Scene: 75 radial segments from the centre (xr2, yr2) to P_i,
--   R1 = int(knob2 * x800)
--   R  = R1 + abs(audio_in[i]) / ((x800 * 20 / (R1 + 1)) + 1)
--   P_i = (R * cos(i/75 * 6.28) + xr2, R * sin(i/75 * 6.28) + yr2)
-- rotated about the centre by rotation_angle (degrees, converted to radians
-- once per frame and applied per segment), drawn with the stock order:
-- for i = 0..74 a line from the centre to the rotated P_i, then (sel < 1
-- only) a filled circle at the same rotated P_i.
--
-- The platform renders at 1280 x 720 (ctx.width/height) - stock's own
-- xres/yres - so x800 = 800, x20 = 20.48, and the geometry is derived from
-- ctx.width/height so it scales with the surface rather than assuming those
-- numbers.
--
-- Documented deviations from stock:
-- 1. Foreground picker: stock color_picker is the legacy picker, partly
--    random (random greys for small phases, random RGB above 0.96).
--    Randomness cannot be ported (replays must be byte-identical), so the
--    deterministic middle branch is substituted: r = 0.5*sin(2*PI*c)+0.5,
--    g = 0.5*sin(4*PI*c)+0.5, b = 0.5*sin(8*PI*c)+0.5. The call pattern is
--    stock-exact: once per frame, argument knob4, before the segment loop.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock cosine formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier's luma
--    bounds. The cosine formula itself is unchanged.
-- 3. Audio: stock reads a 100-sample ring (+-32768, 100 Hz) with
--    audio_in[i] (i = 0..74, no negative indices). The platform buffer is 1024
--    normalized samples; stock index i maps to left[1 + i * 10] (oldest
--    sample of the window, 10-sample stride; i = 74 maps to index 741).
--    Denormalized by * 32768 - the stock divisor is 32768, kept stock-exact.
-- 4. Rotation re-timed 30 -> 60 fps (PORTING-LADDER 3.4): stock advances
--    0.48..0.52 dead zone, else (knob1 - 0.5) * 20).
-- 5. Per-frame uniform colour, ported faithfully: stock's color_picker_lfo is
--    called once per frame with knob4 and the result is reused by all 75
--    segments, so the port makes exactly one e.color change per frame -
--    the stock call pattern, no representative-colour collapse (the sibling
--    "Stepped Color" mode needed that concession; here the stock code
--    already uses one colour).
-- 6. Picker offset 0.21 (PORTING-LADDER 3.4, tools/lfo_offset.py --calls 1):
--    the picker is called once per frame, so the gate samples one instant.
--    At picker(0.5) (the all-knobs-0.5 baseline) the middle branch is pure
--    grey (0.5, 0.5, 0.5), and knob4's two probe points sit symmetrically
--    around 0.5 on a sine that is flat at its peak (dR/dc = PI*0.5*sin(4PIc)
--    = 0 there): the recolour is sub-pixel and knob4 reads dead. Shifting
--    the phase by 0.21 moves both probes off the flat peak, where the
--    recolour is large.
-- 7. Mesh batching for the strokes: the 75 separate lines are batched into
--    one indexed triangle mesh - one quad (4 vertices, 2 triangles) per
--    segment, preallocated at the exact worst case in setup and mutated in
--    place (house idiom: s-oscilloscope deviation 5, s-bezier-h-scope
--    deviation 8). Every frame fills every slot (75 * 4 = 300 vertices,
--    75 * 6 = 450 indices), so the table passed to update_mesh is always fully
--    populated (update_mesh validates the WHOLE vertices table). Each segment
--    is its own quad, so the 75 separate spokes never gain the joining
--    geometry a line strip would draw (update_mesh without indices is a line
--    strip). One mesh handle (the cap is 32), 300 vertices / 450 indices
--    (the caps are 8192 / 49152).
-- 8. Legibility floor on R1, the scope's diameter (PORTING-LADDER 4,
--    "A radius the baseline collapses to nothing"). At the all-knobs-zero
--    baseline stock's R1 = int(0 * x800) = 0, which makes the audio divisor
--    (x800*20/(R1+1))+1 maximal (16001) and the whole scope a ~2 px dot at the
--    screen centre: the frame reads near-flat, rotating a dot changes nothing
--    (dead knob1), and the audio term moves the radius by ~2 px (no audio
--    reactivity). The floor is applied to R1 (the figure's size input), never
--    to any knob: R1 is floored at 40 px. The stock radius is otherwise
--    untouched - above the floor the audio term still adds
--    (abs(sample) / ((800*20/(R1+1))+1)) px per sample and knob2 still scales
--    the diameter 40 -> 800 px. At the baseline the scope is now a 40 px star
--    of 75 radiating strokes with tip circles. Look impact: below knob2 ~ 0.05
--    (R1 < 40 px) the scope draws a 40 px figure where stock draws a sub-pixel
--    dot; above that the geometry is stock-exact.
local e = eyesy
local PI = math.pi

local SEGMENTS = 75              -- radial segments (stock's i = 0..74)
local VERTS_PER_MESH = SEGMENTS * 4   -- one quad per segment: 300
local IDX_PER_MESH = SEGMENTS * 6     -- two triangles per quad: 450
local R1_FLOOR = 40             -- px (deviation 8): legible scope at the baseline

-- Python int() truncates toward zero (stock's int() calls).
local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

-- Deterministic middle branch of the stock legacy color_picker (deviation 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Rotation state (deviation 4): degrees, advanced once per platform frame by
-- stock's per-30-fps-frame increment scaled by 30 * dt.
local rotationAngle = 0

-- Batched triangle-mesh buffer (deviation 7): one quad per segment,
-- preallocated at the exact worst case and mutated in place; draw never
-- allocates. One handle (the cap is 32), 300 vertices / 450 indices (the caps
-- are 8192 / 49152).
local mesh = nil
local mverts = {}
for i = 1, VERTS_PER_MESH do
  mverts[i] = { 0, 0, 0 }
end
local midx = {}
do
  local n = 0
  for q = 0, SEGMENTS - 1 do
    local b6 = q * 6
    local b4 = q * 4
    midx[b6 + 1] = b4 + 1
    midx[b6 + 2] = b4 + 2
    midx[b6 + 3] = b4 + 3
    midx[b6 + 4] = b4 + 1
    midx[b6 + 5] = b4 + 3
    midx[b6 + 6] = b4 + 4
    n = b6 + 6
  end
end

-- The per-segment endpoints, flat x,y pairs: pts[2i+1..2i+2] = rotated P_i,
-- i = 0..74. Allocated once, mutated in place, zero per-frame allocation.
local pts = {}
for i = 1, SEGMENTS * 2 do pts[i] = 0 end

-- Append one spoke as its quad: half the width perpendicular on each side,
-- matching the width-`w` e.line it replaces. A zero-length spoke emits a
-- degenerate (zero-area) quad, which rasterises to nothing.
local function push_line(x1, y1, x2, y2, w, slot)
  local b4 = (slot - 1) * 4
  local dx = x2 - x1
  local dy = y2 - y1
  local len2 = dx * dx + dy * dy
  if len2 < 1e-9 then
    for k = 1, 4 do
      local v = mverts[b4 + k]
      v[1] = x1
      v[2] = y1
    end
    return
  end
  local half = (w * 0.5) / math.sqrt(len2)
  local nx = -dy * half
  local ny = dx * half
  local v1 = mverts[b4 + 1]
  v1[1] = x1 + nx
  v1[2] = y1 + ny
  local v2 = mverts[b4 + 2]
  v2[1] = x1 - nx
  v2[2] = y1 - ny
  local v3 = mverts[b4 + 3]
  v3[1] = x2 + nx
  v3[2] = y2 + ny
  local v4 = mverts[b4 + 4]
  v4[1] = x2 - nx
  v4[2] = y2 - ny
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.rotation
  local k2 = ctx.params.diameter
  local k3 = ctx.params.width
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with the phase remapped (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bgc, bb)

  -- Rotation (deviation 4): stock's per-30-fps-frame increment, dt-scaled.
  local inc
  if k1 >= 0.48 and k1 <= 0.52 then
    inc = 0
  else
    inc = (k1 - 0.5) * 20
  end
  rotationAngle = rotationAngle + inc * 30 * dt

  local xr2 = W * 0.5
  local yr2 = H * 0.5
  local x800 = W * 0.625
  local x20 = W * 0.016

  local rad = math.rad(rotationAngle)
  local cosA = math.cos(rad)
  local sinA = math.sin(rad)

  -- R1 carries the legibility floor (deviation 8); the stock radius formula is
  -- otherwise untouched (deviation 3: the stock divisor 32768, abs() exact).
  local R1 = trunc(k2 * x800)
  if R1 < R1_FLOOR then R1 = R1_FLOOR end
  local sel = k3 * 2
  local lw
  local cr = 0
  if sel < 1 then
    lw = trunc((1 - sel) * x20) + 1
    cr = trunc((1 - sel) * (x20 - 2)) + 1
  else
    lw = trunc((sel - 1) * x20) + 1
  end

  -- Fill the spokes once.
  for i = 0, SEGMENTS - 1 do
    local s = left and left[1 + i * 10] or 0
    local R = R1 + (math.abs(s * 32768) / ((x800 * 20 / (R1 + 1)) + 1))
    local a = (i / 75) * 6.28
    local x = R * math.cos(a) + xr2
    local y = R * math.sin(a) + yr2
    local rx = (x - xr2) * cosA - (y - yr2) * sinA + xr2
    local ry = (x - yr2) * sinA + (y - yr2) * cosA + yr2
    local p = i * 2 + 1
    pts[p] = rx
    pts[p + 1] = ry
  end

  -- The one per-frame colour (deviations 5 + 6): stock's call pattern -
  -- picker(knob4) once per frame, reused by all 75 segments - with the
  -- pack's documented 0.21 phase offset for a once-per-frame call.
  local r0, g0, b0 = picker((k4 + 0.21) % 1)
  e.color(r0, g0, b0)

  -- Batched spokes (deviation 7): one quad per spoke in a single mesh draw.
  for i = 0, SEGMENTS - 1 do
    local p = i * 2 + 1
    push_line(xr2, yr2, pts[p], pts[p + 1], lw, i + 1)
  end
  e.update_mesh(mesh, mverts, midx)
  e.draw_mesh(mesh)

  -- Tip circles (stock's sel < 1 branch), one fill loop in the same colour.
  if sel < 1 then
    for i = 0, SEGMENTS - 1 do
      local p = i * 2 + 1
      e.circle(pts[p], pts[p + 1], cr)
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("rotation", 0.5, 0, 1, 1)
    e.param("diameter", 0.5, 0, 1, 2)
    e.param("width", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    mesh = e.new_mesh()
  end,
  draw = draw,
}
