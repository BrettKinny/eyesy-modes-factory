-- s-grid-triangles-unfilled-patchwork-color — port of stock
-- "S - Grid Triangles - Unfilled Patchwork Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Grid Triangles - Unfilled Patchwork Color/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: x offset (shifts odd rows right)
-- Knob 2: y offset (shifts odd columns down)
-- Knob 3: size of triangles
-- Knob 4: foreground colour phase (patchwork: per-cell phase per the stock rule)
-- Knob 5: background colour
--
-- Shape (stock-exact): a 7x10 grid of cells, each an OUTLINE upward triangle
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
--    by * 32768. The stock term A*0.00003058*(xr*0.25) reduces to
--    abs(sample * 320 * 1.002) at xr = 1280, i.e. rad = abs(sample * 320.64);
--    the 0.00003058 factor is the ring's 1/32768 denormalization. (The
--    unfilled variant scales rad by xr*0.25, not the filled variant's xr*0.1.)
-- 4. width: stock int(knob3 * (xr * 0.063)) + 1 — the constant 80.64 is the
--    stock product at the reference xr = 1280 (the stock comment
--    int(knob3*(80*xr)/xr)+1 shows the intent is 80 px at 1280).
-- 5. No LFO: the stock colour picker is called per cell with a static phase
--    derived from knob4, no time component, so no LFO re-timing is required.
-- 6. Outline instead of mesh: the API has no polygon primitive, so the
--    stock pygame.draw.polygon(points, lineWidth) outline is drawn as three
--    e.line calls of width int(xr*0.00625) = 8 (LINE_W) between the same
--    three points, per cell. No meshes are used in this mode.
-- 7. No positional deviation: the stock grid fits inside the 1280x720 frame at
--    all knob values (odd rows shift by <= 160 px, odd columns by <= 144 px;
--    the largest triangle spans width+rad <= 41+320.6 px from its centre,
--    still within the frame), so no wrap or scale is applied.

local e = eyesy
local PI = math.pi

local COLS = 10
local ROWS = 7
local LINE_W = 8 -- stock lineWidth = int(xr * 0.00625) at xr = 1280

-- Deterministic middle branch of the stock legacy color_picker (see header 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Phase of cell (i, j) under the stock patchwork rule (deviation 1):
-- phase = fg; j odd -> (0.4+fg)%1; (j+i)%3 == 1 -> (0.8+fg)%1 (last wins).
local function phase_of(i, j, fg)
  local p = fg
  if j % 2 == 1 then p = (0.4 + fg) % 1 end
  if (j + i) % 3 == 1 then p = (0.8 + fg) % 1 end
  return p
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
  local width = math.floor(size * 80.64) + 1

  -- Background: stock color_picker_bg_original with phase remapped (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  local left = ctx.audio and ctx.audio.left

  -- Patchwork colour per cell (deviation 1), outline per cell (deviation 6).
  for i = 0, ROWS - 1 do
    for j = 0, COLS - 1 do
      local r, g, b = picker(phase_of(i, j, fg))
      e.color(r, g, b)

      local x = j * x8 - x8
      local y = i * y5 - y5

      -- Audio: stock index k = j-i (range -6..14) wraps like Python
      -- (deviation 3), then strides the platform buffer; the unfilled
      -- variant scales by W * 0.25 (= 320 at 1280).
      local k = j - i
      local kk = k % 100
      if kk < 0 then kk = kk + 100 end
      local s = left and left[1 + kk * 10] or 0
      local rad = math.abs(s * 32768 * 0.00003058 * (W * 0.25))

      -- Odd rows shift right, odd columns shift down (stock-exact).
      if i % 2 == 1 then x = x + xoffset end
      if j % 2 == 1 then y = y + yoffset end

      -- Triangle points, stock-exact (deviation 6).
      local x0 = x - width - rad; local y0 = y + width + rad
      local x1 = x;              local y1 = y - width - rad
      local x2 = x + width + rad; local y2 = y + width + rad

      -- Outline: three lines of stock lineWidth, same three points.
      e.line(x0, y0, x1, y1, LINE_W)
      e.line(x1, y1, x2, y2, LINE_W)
      e.line(x2, y2, x0, y0, LINE_W)
    end
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
  end,
  draw = draw,
}
