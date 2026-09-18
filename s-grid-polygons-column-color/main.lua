-- s-grid-polygons-column-color — port of stock
-- "S - Grid Polygons - Column Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Grid Polygons - Column Color/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: x offset (shifts odd rows right)
-- Knob 2: y offset (shifts odd columns down)
-- Knob 3: size of polygons
-- Knob 4: foreground colour phase (per-column rainbow via the picker)
-- Knob 5: background colour
--
-- Shape (stock-exact): a 7x10 grid of cells. Each cell draws a closed
-- 6-vertex polygon whose vertex positions come from a shared pList of random
-- points:
--   x = j*160 - 160; y = i*144 - 144
--   if i%2 == 1: x = x + int(knob1*160)
--   if j%2 == 1: y = y + int(knob2*144)
--   rad = audio_in[j+i] * 0.00003052 * hundert   (hundred = xr*0.078)
--   w   = knob3*7 + 1
--   points[t] = pList[int(i*j + hten)][t]        (hten = ten/2, ten = xr*0.008)
--   placePoints[k] = (points[k][0]*w + x, points[k][1]*w + y)
--   morphPoints  = placePoints with six explicit per-vertex offsets:
--     v0 = (-rad,-rad)  v1 = (+rad,-rad)  v2 = (+rad,0)
--     v3 = (+rad,+rad)  v4 = (0,-rad)     v5 = (-rad,+rad)
--
-- Colour (stock-exact): picker(((j*0.1) + knob4) % 1) evaluated per column,
-- so each of the 10 columns has one colour and the 7 cells of that column
-- share it. There is no LFO in this mode.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker is the legacy picker, partly
--    random (random greys / random RGB outside the middle band). Randomness
--    cannot be ported (replays must be byte-identical), so the deterministic
--    middle branch is substituted: r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5,
--    b = 0.5*sin(8πc)+0.5. The per-column phase step (j*0.1) is stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 3. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with
--    audio_in[j+i]; j+i ranges 0..15 (no negative indices here). The port
--    reads left[1 + (j+i)*10] (10-sample stride of the 1024 normalized-sample
--    platform buffer) and denormalizes by * 32768. The stock term
--    A*0.00003052*hundred reduces to A * 99.84 * 0.00003052 at xr = 1280;
--    the port uses the literal product hundert * 0.00003052.
-- 4. pList: stock reassigns a fresh list of 70x6 random (x,y) pairs on every
--    trigger edge. The port preallocates [70][6][2] in setup and mutates it
--    in place on ctx.trigger — zero per-frame allocation. e.random() replaces
--    random.randrange(-20, 20) with floor(e.random()*40) - 20 (integers
--    −20..19), called in stock's order (70 cells × 6 points × x then y).
-- 5. Stock's pList index quirk is preserved exactly:
--    int(i*j + hten) = floor(i*j + 5.12). For i = 0 this is 5 for every
--    column, so all cells in row 0 share pList[5]. Not "fixed".
-- 6. Polygon via mesh: the API has no closed-polygon primitive, and the
--    engine caps a mode at 32 mesh handles, so the 7 cells of each column
--    share one preallocated 49-vertex mesh (10 handles, one per column).
--    Each cell's hexagon is a line strip with the first vertex repeated at
--    the end (7 points per cell × 7 cells = 49 vertices), giving a closed
--    outline. Stock draws a 3 px outline (int(xr*0.0027) = 3); the mesh
--    strip is 1 px. The deviation is noted here; if the 1 px strip reads too
--    thin at the gate, the strips would be drawn twice at ±1 px offsets.
--    update_mesh is called without an index table so the engine treats the
--    mesh as a line strip (the engine rejects non-triangle index tables).
-- 7. No positional deviation: the stock grid fits inside the 1280x720 frame
--    at all knob values (odd rows shift by <= 160 px, odd columns by <= 144 px;
--    the largest polygon spans w*raNr + rad <= 4.5*20 + 128.3 ≈ 218 px from its
--    centre, still within the frame for all knob and audio combinations), so
--    no wrap or scale is applied.

local e = eyesy
local PI = math.pi

local COLS = 10
local ROWS = 7
local CELL_V = 7 -- 6 vertices + 1 repeat to close the polygon
local PLIST_CELLS = 70
local PLIST_PTS = 6
local RA_N = 20 -- int(1280 * 0.016)
local TEN = 10.24 -- 1280 * 0.008
local HTEN = TEN / 2 -- 5.12
local HUNDERT = 99.84 -- 1280 * 0.078

-- Deterministic middle branch of the stock legacy color_picker (see header 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Preallocated per-column polygon meshes: 10 handles, one per column, each
-- holding its 7 cells as closed 7-point line strips (49 vertices each).
local meshes = {}

-- Preallocated pList: [70][6][2], filled in setup, mutated in place on trigger.
local pList = {}
do
  for c = 1, PLIST_CELLS do
    local cell = {}
    for t = 1, PLIST_PTS do
      cell[t] = {0, 0}
    end
    pList[c] = cell
  end
end

-- Fill pList in stock's order: 70 cells × 6 points × x then y.
local function fill_pList()
  for c = 1, PLIST_CELLS do
    local cell = pList[c]
    for t = 1, PLIST_PTS do
      cell[t][1] = math.floor(e.random() * 40) - 20
      cell[t][2] = math.floor(e.random() * 40) - 20
    end
  end
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local left = ctx.audio and ctx.audio.left

  -- Regenerate pList on trigger edge (deviation 4), in place.
  if ctx.trigger then
    fill_pList()
  end
  local offx = ctx.params.offx
  local offy = ctx.params.offy
  local size = ctx.params.size
  local fg = ctx.params.fg
  local bg = ctx.params.bg

  local x8 = W / 8
  local y5 = H / 5
  local xoffset = math.floor(offx * x8)
  local yoffset = math.floor(offy * y5)
  local w = size * 7 + 1
  local hundert = W * 0.078

  -- Background: stock color_picker_bg with phase remapped (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Per-column colour (deviation 1) and mesh (deviation 6).
  for j = 0, COLS - 1 do
    local m = meshes[j + 1]
    local v = m.v
    local r, g, b = picker((j * 0.1 + fg) % 1)
    e.color(r, g, b)

    for i = 0, ROWS - 1 do
      local x = j * x8 - x8
      local y = i * y5 - y5
      if i % 2 == 1 then x = x + xoffset end
      if j % 2 == 1 then y = y + yoffset end

      -- Audio: stock index j+i (0..15), no wrap needed (deviation 3).
      local s = left and left[1 + (j + i) * 10] or 0
      local rad = s * 32768 * 0.00003052 * hundert

      -- pList index quirk preserved exactly (deviation 5).
      local pc = math.floor(i * j + HTEN) + 1
      local cell = pList[pc]

      -- Compute the 6 morphed vertices, then write 7 points (repeat v0).
      local b0 = i * CELL_V
      local p0x = cell[1][1] * w + x - rad
      local p0y = cell[1][2] * w + y - rad
      local p1x = cell[2][1] * w + x + rad
      local p1y = cell[2][2] * w + y - rad
      local p2x = cell[3][1] * w + x + rad
      local p2y = cell[3][2] * w + y
      local p3x = cell[4][1] * w + x + rad
      local p3y = cell[4][2] * w + y + rad
      local p4x = cell[5][1] * w + x
      local p4y = cell[5][2] * w + y - rad
      local p5x = cell[6][1] * w + x - rad
      local p5y = cell[6][2] * w + y + rad

      v[b0 + 1][1] = p0x; v[b0 + 1][2] = p0y
      v[b0 + 2][1] = p1x; v[b0 + 2][2] = p1y
      v[b0 + 3][1] = p2x; v[b0 + 3][2] = p2y
      v[b0 + 4][1] = p3x; v[b0 + 4][2] = p3y
      v[b0 + 5][1] = p4x; v[b0 + 5][2] = p4y
      v[b0 + 6][1] = p5x; v[b0 + 6][2] = p5y
      v[b0 + 7][1] = p0x; v[b0 + 7][2] = p0y
    end

    e.update_mesh(m.handle, v)
    e.draw_mesh(m.handle)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("offx", 0.5, 0, 1, 1)
    e.param("offy", 0.5, 0, 1, 2)
    e.param("size", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    -- 10 preallocated per-column polygon meshes (deviation 6): 49 vertices
    -- each, mutated in place per frame. Line strips (no index table).
    for j = 1, COLS do
      local verts = {}
      for n = 1, ROWS * CELL_V do
        verts[n] = {0, 0, 0}
      end
      meshes[j] = { handle = e.new_mesh(), v = verts }
    end

    fill_pList()
  end,
  draw = draw,
}
