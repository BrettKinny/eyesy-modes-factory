-- s-grid-circles-outlined-column-color — port of stock
-- "S - Grid Circles - Outlined Column Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Grid Circles - Outlined Column Color/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: x offset (shifts odd rows right)
-- Knob 2: y offset (shifts odd columns down)
-- Knob 3: rest radius (base circle size)
-- Knob 4: foreground colour phase (per-column rainbow via the picker)
-- Knob 5: background colour
--
-- Shape (stock-exact): a 7x10 grid of cells, each a disc of radius
-- R = rad + restRad whose top-left and bottom-right quadrants are FILLED and
-- whose top-right and bottom-left quadrants are drawn as an 8 px-thick arc
-- band (pygame.draw.circle with two quadrant flags; the outline width is
-- int(1280*0.00625) = 8). Quadrants are geometric in screen coordinates
-- (y grows downward): TL = x<0,y<0, TR = x>0,y<0, BL = x<0,y>0, BR = x>0,y>0.
--
-- Colour (stock-exact): picker(((j*0.1) + fg) % 1) evaluated per column, so
-- each of the 10 columns has one colour and the 7 cells of that column share
-- it. There is no LFO in this mode.
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
-- 3. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with audio_in[j+i];
--    the platform buffer is 1024 normalized samples. Stock index k (0-based,
--    here k = j+i, always 0..15) maps to left[1 + k*10] (10-sample stride) and
--    is denormalized by * 32768. No negative-index wrap is needed in this mode.
-- 4. No LFO: the stock colour picker is called per column with a static phase
--    (j*0.1 + knob4), no time component, so no LFO re-timing is required.
-- 5. Shape via mesh: the API has no quadrant / filled-arc primitive, so each
--    cell is two filled quadrant fans (TL, BR) plus two 8 px-thick arc bands
--    (TR, BL). Because the colour is per column, the mesh is grouped per
--    column: 10 preallocated handles, one per column j, each holding that
--    column's 7 cells (7 × 44 = 308 vertices per mesh). Vertices and indices
--    are preallocated in setup and mutated in place per frame (zero
--    per-frame allocation). The fan uses SEG = 6 arcs per quadrant (polygonal
--    error < 1 px at R <= 158).
-- 6. Degenerate-radius guard: rad can be 0 and restRad >= 1, so R >= 1; when
--    R <= 8 the band would invert (inner radius negative), so such a cell is
--    skipped entirely.
-- 7. No positional deviation: the stock grid fits inside the 1280x720 frame at
--    all knob values (odd rows shift by <= 160 px, odd columns by <= 144 px,
--    both within the frame), so no wrap or scale is applied.

local e = eyesy
local PI = math.pi

local SEG = 6          -- arcs per quadrant (15 deg each)
local FILL_V = SEG + 2 -- fan vertices: centre + SEG+1 arc points
local BAND_V = 2 * (SEG + 1)
local CELL_V = 2 * FILL_V + 2 * BAND_V  -- 44 vertices per cell
local CELL_T = 2 * SEG + 4 * SEG         -- 24 triangles per cell
local COLS = 10
local ROWS = 7
local CELLS_PER_COL = ROWS

-- Deterministic middle branch of the stock legacy color_picker (see header 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Preallocated per-column meshes: 10 handles, each holding 7 cells
-- (7*44 = 308 vertices per mesh, 1680 vertices total, well inside the
-- 8192-vertex limit; 504 indices per mesh, 5040 total, inside 49152).
local meshes = {}

local function buildIndices()
  -- Indices are identical for every cell within a column mesh; the local
  -- cell base is (cell-1)*CELL_V + 1 for cell = 1..ROWS.
  local idx = {}
  local n = 1
  for cell = 1, CELLS_PER_COL do
    local b0 = (cell - 1) * CELL_V + 1
    local fi = b0 + FILL_V
    local tr = b0 + 2 * FILL_V
    local br = tr + BAND_V

    -- TL fan: centre b0, arc points b0+1 .. b0+SEG+1.
    for kk = 1, SEG do
      idx[n] = b0; idx[n + 1] = b0 + kk; idx[n + 2] = b0 + kk + 1
      n = n + 3
    end
    -- TR band: (o_k, o_{k+1}, i_{k+1}, i_k) -> two triangles.
    for kk = 0, SEG - 1 do
      local a = tr + 2 * kk
      local b = a + 2
      local c = a + 3
      local d = a + 1
      idx[n] = a; idx[n + 1] = b; idx[n + 2] = c
      n = n + 3
      idx[n] = a; idx[n + 1] = c; idx[n + 2] = d
      n = n + 3
    end
    -- BL fan: centre fi, arc points fi+1 .. fi+SEG+1.
    for kk = 1, SEG do
      idx[n] = fi; idx[n + 1] = fi + kk; idx[n + 2] = fi + kk + 1
      n = n + 3
    end
    -- BR band: (o_k, o_{k+1}, i_{k+1}, i_k) -> two triangles.
    for kk = 0, SEG - 1 do
      local a = br + 2 * kk
      local b = a + 2
      local c = a + 3
      local d = a + 1
      idx[n] = a; idx[n + 1] = b; idx[n + 2] = c
      n = n + 3
      idx[n] = a; idx[n + 1] = c; idx[n + 2] = d
      n = n + 3
    end
  end
  return idx
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local offx = ctx.params.offx
  local offy = ctx.params.offy
  local size = ctx.params.size
  local fg = ctx.params.fg
  local bg = ctx.params.bg

  local x8 = W / 8
  local y5 = H / 5
  local xoffset = math.floor(offx * x8)
  local yoffset = math.floor(offy * y5)
  local restRad = math.floor(size * (W * 0.023)) + 1
  local radScale = W * 0.1 -- stock: audio_in / 32768 * xr * 0.1

  -- Background: stock color_picker_bg_original with phase remapped (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  local left = ctx.audio and ctx.audio.left

  -- Per-column colour phases: phase = (j*0.1 + fg) % 1 (stock-exact).
  -- Computed once per column; loop-invariant over the 7 rows.
  for j = 0, 9 do
    local m = meshes[j + 1]
    local v = m.v
    local base = 1
    local step = (PI / 2) / SEG

    for i = 0, 6 do
      local x = j * x8 - x8
      local y = i * y5 - y5

      -- Audio: stock index j+i (0..15) -> left[1 + k*10], denormalized.
      local k = j + i
      local s = left and left[1 + k * 10] or 0
      local rad = math.abs(s * 32768 / 32768 * radScale)
      local R = rad + restRad

      -- Odd rows shift right, odd columns shift down (stock-exact).
      if i % 2 == 1 then x = x + xoffset end
      if j % 2 == 1 then y = y + yoffset end

      if R > 8 then
        local R2 = R - 8
        local b0 = base + 2 * FILL_V
        local fi = base + FILL_V

        -- TL filled fan: centre + arc points from 180..270 deg (x<0, y<0).
        v[base][1] = x; v[base][2] = y
        for kk = 0, SEG do
          local th = math.pi + kk * step
          local p = base + 1 + kk
          v[p][1] = x + R * math.cos(th)
          v[p][2] = y + R * math.sin(th)
        end

        -- TR band: outer then inner arc points from 270..360 deg (x>0, y<0).
        for kk = 0, SEG do
          local th = PI * 1.5 + kk * step
          v[b0 + 2 * kk][1] = x + R * math.cos(th)
          v[b0 + 2 * kk][2] = y + R * math.sin(th)
          v[b0 + 2 * kk + 1][1] = x + R2 * math.cos(th)
          v[b0 + 2 * kk + 1][2] = y + R2 * math.sin(th)
        end

        -- BL filled fan: centre + arc points from 90..180 deg (x<0, y>0).
        v[fi][1] = x; v[fi][2] = y
        for kk = 0, SEG do
          local th = PI * 0.5 + kk * step
          local p = fi + 1 + kk
          v[p][1] = x + R * math.cos(th)
          v[p][2] = y + R * math.sin(th)
        end

        -- BR band: outer then inner arc points from 0..90 deg (x>0, y>0).
        local br = base + FILL_V + FILL_V + BAND_V
        for kk = 0, SEG do
          local th = kk * step
          v[br + 2 * kk][1] = x + R * math.cos(th)
          v[br + 2 * kk][2] = y + R * math.sin(th)
          v[br + 2 * kk + 1][1] = x + R2 * math.cos(th)
          v[br + 2 * kk + 1][2] = y + R2 * math.sin(th)
        end
      end
      base = base + CELL_V
    end

    e.update_mesh(m.handle, v, m.idx)

    -- Per-column colour (deviation 1).
    local r, g, b = picker((j * 0.1 + fg) % 1)
    e.color(r, g, b)
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

    -- 10 per-column meshes, each holding 7 cells (deviation 5). Built once,
    -- mutated per frame. 10*7*44 = 3080 vertices, 10*7*24*3 = 5040 indices.
    for j = 1, COLS do
      local verts = {}
      for n = 1, CELLS_PER_COL * CELL_V do
        verts[n] = {0, 0, 0}
      end
      meshes[j] = {
        handle = e.new_mesh(),
        v = verts,
        idx = buildIndices(),
      }
    end
  end,
  draw = draw,
}
