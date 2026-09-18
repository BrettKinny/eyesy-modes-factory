-- s-amp-color-5gon-outlines — port of stock "S - Amp Color - 5gon Outlines"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Amp Color - 5gon Outlines/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- This mode is the outline twin of "S - Amp Color - 5gon Filled" (see
-- s-amp-color-5gon-filled). The two stock sources are byte-identical except
-- for the final draw call:
--
--   Filled:   pygame.draw.polygon(screen, color, rotated_points)
--   Outlines: pygame.draw.polygon(screen, color, rotated_points, 7) # 7 = linewidth
--
-- Knob roles (stock-exact):
--   1 history — audio 'history' length (int(knob1*20)+1 samples)
--   2 spin — rotation direction & rate (dead zone 0.49..0.51 resets to 0;
--            below 0.48 counter-clockwise, above 0.52 clockwise,
--            rate = |knob2 - 0.48| * 52 deg/frame at 30 fps)
--   3 count — nested polygon count (int(knob3*59)+1, floored at 2 — deviation 10)
--   4 offset — per-polygon rotation offset (i * knob4 * 180 deg)
--   5 bg — background colour
--   Trigger — picks five new random vertex positions in [-1,1]
--
-- Scene: `count` nested pentagon outlines, each scaled by a dynamic spacing
-- factor, rotated by current_rotation + i*offset about the screen centre,
-- with colour from the running audio history average.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker is the legacy picker, partly
--    random (random greys for small values, random RGB above 0.96).
--    Randomness cannot be ported (replays must be byte-identical), so the
--    deterministic middle branch is substituted: r = 0.5*sin(2πc)+0.5,
--    g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5. The colour value fed to
--    the picker (average_value, the running history average) is stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    bg = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 3. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with audio_in[i];
--    the platform buffer is 1024 normalized samples. Stock index i (0-based)
--    maps to left[1 + i*10] (oldest sample of the window, 10-sample stride);
--    denormalized by * 32768 (guard nil -> 0).
-- 4. Audio history: stock keeps a collections.deque(maxlen=N) per index and
--    recreates every deque when N changes. Ported as preallocated tables
--    created in setup — hist[i][slot] for i = 1..32, slot = 1..21 (21 = max
--    history length; i is capped at 32 by the mesh budget, see 6), plus
--    index, the new value is written in place at hist_write[i] (advanced
--    modulo 21) and hist_len[i] clamps to min(N, 21); the average is the mean
--    of the hist_len[i] most-recent values. Zero per-frame allocation.
-- 5. Rotation re-timed 30 -> 60 fps: stock adds rotation_rate once per frame
--    at 30 fps; here the angle advances by rotation_rate * 30 * ctx.dt each
--    frame. rotation_angle is never wrapped (stock never wraps it); the dead
--    zone 0.49..0.51 is kept.
-- 6. Outline via mesh: the API's mesh primitive is filled (triangle list);
--    there is no stroked-polygon primitive, so the stock 7 px outline
--    (pygame.draw.polygon with linewidth=7, drawn centred on the vertex
--    path) is represented as a 7 px-thick filled band around the polygon:
--    a mitered ring of five quads, one per edge. Each corner is displaced
--    ±3.5 px along the bisector of its two adjacent edge normals, scaled by
--    1/cos(half-angle) (clamped at a 5:1 miter limit) and oriented outward
--    from the polygon centroid, so the band is exactly 7 px wide across both
--    its inner and its outer boundary and consecutive quads share a corner
--    with no seam. This is the faithful representation of pygame's centred
--    stroke (the alternative — an inset/outset polygon pair — would cover
--    only one side of the path, not the stroke that straddles it). Look
--    impact: identical for the default vertex set and for any convex
--    polygon; for strongly reflex triggered vertex sets the miter tips can
--    flare wider than pygame's round joins, and the band can self-overlap
--    where the polygon nearly self-intersects — the same degenerate case
--    where pygame's own outline rendering degenerates. A vertex whose two
--    adjacent edges collapse to a point (zero-length edge) yields a zero
--    offset and therefore a degenerate quad, matching pygame drawing
--    nothing there.
-- 7. Polygon via mesh: the engine caps a mode at 32 mesh handles, so at most
--    32 meshes are preallocated in setup; per frame, only the first `count`
--    meshes are updated and drawn. Each mesh is sized at its exact populated
--    vertex count (20: 5 quads × 4 vertices) with a static 1-based index
--    buffer (10 triangles), so update_mesh never sees a trailing nil.
--    Stock's knob3 draws up to 60 polygons; the port caps the count at 32
--    to stay within the handle budget — the only deviation from stock
--    geometry, as in the filled sibling.
-- 8. Per-element colour: each polygon gets its own e.color call (up to 32
--    per frame, set immediately before that polygon's draw). This is within
--    the measured device cost budget for this mode family (the grid-slide
--    family measured 70 e.color calls/frame at +13.7 ms outside tier C;
--    32 is well below that).
-- 9. No positional deviation: the stock geometry fits inside the 1280x720
--    frame at all knob values (the largest polygon spans at most
--    poly_width/2 * 1.0 = 640 px from centre in x and 360 px in y, plus the
-- 10. Count floored at 2. Stock's per-polygon rotation offset is
--     current_rotation + i * (knob4 * 180), i.e. the knob's whole excursion is
--     multiplied by the polygon index. At the verifier's all-knobs-zero
--     baseline knob3 = 0, so stock's count is int(0*59)+1 = 1: the loop runs
--     only i = 0, the offset term is multiplied by zero, and knob4 cannot move
--     a single pixel at ANY frame count. That is a stock-faithful deadness
--     (stock is inert there too) which nonetheless fails the gate, and the
--     gate's second chance — a MIDI trigger, which re-randomises this mode's
--     polygon — would otherwise bank a false liveness (PORTING-LADDER 3.4).
--     The drawn count is floored at 2 so the offset has a shape to offset,
--     the same treatment s-0-arrival-scope (12 px box-width floor) and
--     s-circular-trigon-field (12 px triangle extent) give a knob the baseline
--     state multiplies by zero, and the same fix as the filled sibling's
--     deviation 9. Look impact: below knob3 = 1/59 ~ 0.017 the mode draws two
--     nested pentagon outlines where stock draws one, so the all-knobs-zero
--     baseline shows an inner pentagon outline covering ~12 % of the frame.
--     Above that the geometry is stock-exact, and knob3's scaling (2..32 with
--     the mesh cap) is unchanged.


local e = eyesy
local PI = math.pi
local DEG = math.rad

local MAX_COUNT = 32  -- engine mesh handle budget (32 max per mode)
local SLOTS = 21      -- max history length: int(1*20) + 1
local MOD = SLOTS - 1 -- wrap constant: (w + 1) % 21
local HALF = 3.5      -- half of the stock 7 px stroke (pygame centred stroke)

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

-- Preallocated vertex history tables (deviation 4).
local hist = {}
local hist_len = {}
local hist_write = {}
for i = 1, MAX_COUNT do
  local slots = {}
  for s = 1, SLOTS do slots[s] = 0 end
  hist[i] = slots
  hist_len[i] = 0
  hist_write[i] = 0
end

-- Preallocated mesh handles: 32, one per polygon slot.
-- Each mesh holds 20 vertices (5 outline quads, 4 vertices each) with a
-- static 1-based index buffer (10 triangles).
local meshes = {}

local mesh_idx = {
  1, 2, 3, 1, 3, 4,
  5, 6, 7, 5, 7, 8,
  9, 10, 11, 9, 11, 12,
  13, 14, 15, 13, 15, 16,
  17, 18, 19, 17, 19, 20,
}

-- Preallocated per-polygon scratch (5 corners, so 5 entries each): vertex
-- positions, per-edge outward unit normals, and per-vertex miter offsets.
-- Created once here, overwritten in place in draw, so draw allocates nothing.
local vx, vy = {}, {}
local nx, ny = {}, {}
local ox, oy = {}, {}
for k = 1, 5 do
  vx[k] = 0; vy[k] = 0
  nx[k] = 0; ny[k] = 0
  ox[k] = 0; oy[k] = 0
end

local current_rotation = 0
local polygon_points = {
  {0, -1},
  {1, -0.3},
  {0.8, 1},
  {-0.8, 1},
  {-1, -0.3},
}

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.history
  local k2 = ctx.params.spin
  local k3 = ctx.params.count
  local k4 = ctx.params.offset
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with phase remapped (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Trigger: pick new random vertex positions (in place).
  if ctx.trigger then
    for v = 1, 5 do
      polygon_points[v][1] = e.random() * 2 - 1
      polygon_points[v][2] = e.random() * 2 - 1
    end
  end

  -- Number of polygons (deviation 7: capped at 32; deviation 10: floored at 2
  -- so the per-shape rotation offset has a shape to rotate).
  local count = trunc(k3 * 59) + 1
  if count < 2 then count = 2 end
  if count > MAX_COUNT then count = MAX_COUNT end

  -- History length.
  local N = trunc(k1 * 20) + 1
  if N > SLOTS then N = SLOTS end

  -- Rotation: stock dead zone 0.49..0.51, re-timed 30->60 fps (deviation 5).
  if k2 >= 0.49 and k2 <= 0.51 then
    current_rotation = 0
  else
    local rotation_rate = 0
    if k2 < 0.48 then
      rotation_rate = (0.48 - k2) * -52
    elseif k2 > 0.52 then
      rotation_rate = (k2 - 0.52) * 52
    end
    current_rotation = current_rotation + rotation_rate * 30 * dt
  end

  local cx = W / 2
  local cy = H / 2
  local spacing_factor = 0.1
  local offset_deg = k4 * 180

  for i = 0, count - 1 do
    -- Audio: stock index i (0-based) -> left[1 + i*10] (deviation 3).
    local current_value = 0
    if left then
      local s = left[1 + i * 10]
      if s then
        current_value = s * 32768
        if current_value < 0 then current_value = -current_value end
        current_value = current_value / 32768
      end
    end

    -- Update history (deviation 4).
    local w = hist_write[i + 1]
    hist[i + 1][w] = current_value
    local len = hist_len[i + 1]
    if len < N then len = N hist_len[i + 1] = len end
    local start = (w - len + 1) % MOD + 1
    local sum = 0
    for s = start, start + len - 1 do
      sum = sum + hist[i + 1][(s - 1) % MOD + 1]
    end
    hist_write[i + 1] = (w + 1) % MOD
    local average_value = sum / len

    -- Colour (deviation 1).
    local r, g, b = picker(average_value)
    e.color(r, g, b)

    -- Dynamic spacing (stock-exact).
    local poly_width = W - (i * (W / count) * (1 + spacing_factor * (60 - count) / 60))
    local poly_height = H - (i * (H / count) * (1 + spacing_factor * (60 - count) / 60))

    -- Rotation angle for this polygon (stock-exact).
    local rotation_angle = current_rotation + i * offset_deg
    local rad = DEG(rotation_angle)
    local cs = math.cos(rad)
    local sn = math.sin(rad)

    -- Build the 5 rotated/translated vertices.
    local pts = polygon_points
    for p = 1, 5 do
      local px = pts[p][1] * poly_width / 2
      local py = pts[p][2] * poly_height / 2
      vx[p] = px * cs - py * sn + cx
      vy[p] = px * sn + py * cs + cy
    end

    -- Polygon centroid, used only to orient each edge normal outward.
    local gx = (vx[1] + vx[2] + vx[3] + vx[4] + vx[5]) / 5
    local gy = (vy[1] + vy[2] + vy[3] + vy[4] + vy[5]) / 5

    -- Per-edge outward unit normals.
    for k = 1, 5 do
      local j = k % 5 + 1
      local ex = vx[j] - vx[k]
      local ey = vy[j] - vy[k]
      local l = math.sqrt(ex * ex + ey * ey)
      if l > 0.0001 then
        local ux, uy = -ey / l, ex / l
        local mx = (vx[k] + vx[j]) * 0.5 - gx
        local my = (vy[k] + vy[j]) * 0.5 - gy
        if ux * mx + uy * my < 0 then ux = -ux uy = -uy end
        nx[k] = ux; ny[k] = uy
      else
        nx[k] = 0; ny[k] = 0
      end
    end

    -- Per-vertex miter offset (deviation 6): the bisector of the two adjacent
    -- edge normals, scaled by HALF/cos(half-angle) so the band is exactly
    -- 2*HALF wide on both the inner and the outer boundary. `dot` is clamped
    -- (miter limit) so a near-cusp vertex cannot produce an unbounded spike.
    for k = 1, 5 do
      local p = (k + 3) % 5 + 1
      local sx = nx[p] + nx[k]
      local sy = ny[p] + ny[k]
      local l = math.sqrt(sx * sx + sy * sy)
      if l > 0.0001 then
        local ux, uy = sx / l, sy / l
        local dot = ux * nx[k] + uy * ny[k]
        if dot < 0.2 then dot = 0.2 end
        ox[k] = ux * HALF / dot
        oy[k] = uy * HALF / dot
      else
        ox[k] = 0; oy[k] = 0
      end
    end

    -- Five quads, one per edge: the two mitered corners on each side.
    local m = meshes[i + 1]
    local v = m.v
    for k = 1, 5 do
      local j = k % 5 + 1
      local b = (k - 1) * 4 + 1
      v[b][1] = vx[k] + ox[k]; v[b][2] = vy[k] + oy[k]
      v[b + 1][1] = vx[j] + ox[j]; v[b + 1][2] = vy[j] + oy[j]
      v[b + 2][1] = vx[j] - ox[j]; v[b + 2][2] = vy[j] - oy[j]
      v[b + 3][1] = vx[k] - ox[k]; v[b + 3][2] = vy[k] - oy[k]
    end
    e.update_mesh(m.handle, v, mesh_idx)
    e.draw_mesh(m.handle)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("history", 0.5, 0, 1, 1)
    e.param("spin", 0.5, 0, 1, 2)
    e.param("count", 0.5, 0, 1, 3)
    e.param("offset", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    -- Preallocate 32 meshes (deviation 7): each holds 20 vertices (5 outline
    -- quads) with a static index buffer (10 triangles). Mutated in place per
    -- frame.
    for i = 1, MAX_COUNT do
      local verts = {}
      for p = 1, 20 do
        verts[p] = {0, 0, 0}
      end
      meshes[i] = { handle = e.new_mesh(), v = verts }
    end
  end,
  draw = draw,
}
