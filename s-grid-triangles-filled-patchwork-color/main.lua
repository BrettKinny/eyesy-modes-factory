-- s-grid-triangles-filled-patchwork-color — port of stock
-- "S - Grid Triangles - Filled Patchwork Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Grid Triangles - Filled Patchwork Color/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: x offset (shifts odd rows right)
-- Knob 2: y offset (shifts odd columns down)
-- Knob 3: size of triangles
-- Knob 4: foreground colour phase (patchwork: per-cell phase per the stock rule)
-- Knob 5: background colour
--
-- Shape (stock-exact): a 7x10 grid of cells, each a filled upward triangle
-- centred on the cell with half-width `width` (knob3) and the audio-driven
-- `rad` added outward on every coordinate:
--   points = [((x-width)-rad, (y+width)+rad),
--             (x, (y-width)-rad),
--             ((x+width)+rad, (y+width)+rad)]
--
-- Colour (stock-exact): the stock picker is called per cell and overwritten in
-- this order, so the LAST matching assignment wins:
--   color = picker(fg)                    -- initial, every cell
--   if i%2 == 1:  color = picker(fg)      -- same value, a stock no-op
--   if j%2 == 1:  color = picker((0.4+fg) % 1)
--   if (j+i)%3 == 1: color = picker((0.8+fg) % 1)
-- Implemented as: phase = fg; if j%2 == 1 then phase = (0.4+fg) % 1 end;
-- if (j+i)%3 == 1 then phase = (0.8+fg) % 1 end; colour = picker(phase).
-- There is no LFO in this mode.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker is the legacy picker, partly
--    random (random greys / random RGB outside the middle band). Randomness
--    cannot be ported (replays must be byte-identical), so the deterministic
--    middle branch is substituted: r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5,
--    b = 0.5*sin(8πc)+0.5. The patchwork phase rule itself is stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 3. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with
--    audio_in[j-i]; k = j-i reaches -6 (i up to 6, j = 0). Python wraps the
--    negative index (audio_in[-6] == audio_in[94]), so the port wraps too:
--    kk = (k % 100 + 100) % 100, then maps kk to left[1 + kk*10] (10-sample
--    stride of the 1024 normalized-sample platform buffer) and denormalizes
--    by * 32768. The stock term A*0.00003058*(xr*0.1) reduces to
--    abs(sample * 128 * 1.002) at xr = 1280, i.e. rad = abs(sample * 128.256);
--    the 0.00003058 factor is the ring's 1/32768 denormalization.
-- 4. width: stock int(knob3 * (xr * 0.063)) + 1 — the constant 80.64 is the
--    stock product at the reference xr = 1280 (the stock comment
--    int(knob3*(80*xr)/xr)+1 shows the intent is 80 px at 1280).
-- 5. No LFO: the stock colour picker is called per cell with a static phase
--    derived from knob4, no time component, so no LFO re-timing is required.
-- 6. Triangle via mesh: the API has no polygon primitive, and the engine
--    caps a mode at 32 meshes. Unlike the column-colour sibling, the colour
--    here varies per *cell* (phase depends on j and i), but only through
--    three possible phases — fg, (0.4+fg)%1, (0.8+fg)%1 — so the cells are
--    grouped into three preallocated meshes, one per phase, each holding
--    its cells (up to 70) as 3-vertex triangles (up to 210 vertices).
--    Cell membership is static (it depends only on j and i), so it is
--    computed once in setup along with the class's own index table covering
--    exactly its cells; draw only rewrites vertex coordinates. Vertices are
--    mutated in place per frame (zero per-frame allocation), then
--    e.update_mesh + e.draw_mesh per class; the class colour is set once
--    per class.
-- 7. No positional deviation: the stock grid fits inside the 1280x720 frame at
--    all knob values (odd rows shift by <= 160 px, odd columns by <= 144 px;
--    the largest triangle spans width+rad <= 41+128.3 px from its centre,
--    still within the frame), so no wrap or scale is applied.

local e = eyesy
local PI = math.pi

local COLS = 10
local ROWS = 7
local CELL_V = 3 -- vertices per triangle
local CLASSES = 3 -- phase classes: 1 = fg, 2 = (0.4+fg)%1, 3 = (0.8+fg)%1

-- Deterministic middle branch of the stock legacy color_picker (see header 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Phase class of cell (i, j) under the stock patchwork rule (deviation 6).
local function class_of(i, j)
  local c = 1 -- phase = fg
  if j % 2 == 1 then c = 2 end
  if (j + i) % 3 == 1 then c = 3 end
  return c
end

-- Preallocated per-phase-class triangle meshes: 3 handles, one per phase
-- class, each holding its cells as 3-vertex triangles (up to 210 vertices
-- and 210 indices). Populated in setup.
local meshes = {}

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
  local width = math.floor(size * 80.64) + 1

  -- Background: stock color_picker_bg_original with phase remapped (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  local left = ctx.audio and ctx.audio.left

  -- Per-class colour (deviation 1) and mesh (deviation 6).
  for class = 1, CLASSES do
    local m = meshes[class]
    local v = m.v
    local phase = fg
    if class == 2 then phase = (0.4 + fg) % 1 end
    if class == 3 then phase = (0.8 + fg) % 1 end
    local r, g, b = picker(phase)
    e.color(r, g, b)

    for idx = 1, m.n do
      local i = m.cells[idx][1]
      local j = m.cells[idx][2]
      local x = j * x8 - x8
      local y = i * y5 - y5

      -- Audio: stock index k = j-i (range -6..14) wraps like Python
      -- (deviation 3), then strides the platform buffer.
      local k = j - i
      local kk = k % 100
      if kk < 0 then kk = kk + 100 end
      local s = left and left[1 + kk * 10] or 0
      local rad = math.abs(s * 32768 * 0.00003058 * (W * 0.1))

      -- Odd rows shift right, odd columns shift down (stock-exact).
      if i % 2 == 1 then x = x + xoffset end
      if j % 2 == 1 then y = y + yoffset end

      -- Filled triangle, stock points verbatim (deviation 6).
      local b0 = (idx - 1) * CELL_V + 1
      v[b0][1] = x - width - rad; v[b0][2] = y + width + rad
      v[b0 + 1][1] = x;           v[b0 + 1][2] = y - width - rad
      v[b0 + 2][1] = x + width + rad; v[b0 + 2][2] = y + width + rad
    end

    e.update_mesh(m.handle, v, m.idx)
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

    -- 3 preallocated per-phase-class triangle meshes (deviation 6). Cell
    -- membership is static (stock patchwork rule depends only on i, j),
    -- so it is computed once here, with each class's own 1-based index
    -- table covering exactly its cells; draw only rewrites vertex
    -- coordinates.
    for class = 1, CLASSES do
      local cells = {}
      local n = 0
      for i = 0, ROWS - 1 do
        for j = 0, COLS - 1 do
          if class_of(i, j) == class then
            n = n + 1
            cells[n] = { i, j }
          end
        end
      end
      local verts = {}
      for n2 = 1, n * CELL_V do
        verts[n2] = {0, 0, 0}
      end
      local idx = {}
      for n2 = 1, n do
        local b0 = (n2 - 1) * 3
        idx[n2 * 3 - 2] = b0 + 1
        idx[n2 * 3 - 1] = b0 + 2
        idx[n2 * 3] = b0 + 3
      end
      meshes[class] = { handle = e.new_mesh(), v = verts, cells = cells, idx = idx, n = n }
    end
  end,
  draw = draw,
}
