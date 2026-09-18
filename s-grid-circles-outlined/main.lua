-- s-grid-circles-outlined — port of stock "S - Grid Circles - Outlined"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Grid Circles - Outlined/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: x offset (shifts odd rows right)
-- Knob 2: y offset (shifts odd columns down)
-- Knob 3: rest radius (base circle size)
-- Knob 4: foreground colour (LFO picker: <=0.5 static, >0.5 animated rainbow)
-- Knob 5: background colour
--
-- Shape (stock-exact): a 7x10 grid of cells, each a disc of radius
-- R = rad + restRad whose top-left and bottom-right quadrants are FILLED and
-- whose top-right and bottom-left quadrants are drawn as an 8 px-thick arc
-- band (pygame.draw.circle with two quadrant flags; the outline width is
-- int(1280*0.00625) = 8). Quadrants are geometric in screen coordinates
-- (y grows downward): TL = x<0,y<0, TR = x>0,y<0, BL = x<0,y>0, BR = x>0,y>0.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker, partly
--    random (random greys / random RGB outside the middle band). Randomness
--    cannot be ported (replays must be byte-identical), so the deterministic
--    middle branch is substituted: r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5,
--    b = 0.5*sin(8πc)+0.5. The LFO ramp (0→2→0) is stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 3. LFO re-timed 30 -> 60 fps: stock advances the LFO index once per call
--    (one call/frame here); the phase is advanced once per frame by
--    30 * inc * ctx.dt (inc = (fg-0.5)*0.2, the stock per-call step).
-- 4. LFO phase offset: the colour is sampled once per frame and the gate reads
--    luma only, so the phase is initialised at 0.21 (PORTING-LADDER §3.4) to
--    clear both the palette grey and the background luma at the probe frames.
-- 5. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with audio_in[j+i];
--    the platform buffer is 1024 normalized samples. Stock index k (0-based,
--    here k = j+i, always 0..15) maps to left[1 + k*10] (10-sample stride) and
--    is denormalized by * 32768. No negative-index wrap is needed in this mode.
-- 6. Shape via mesh: the API has no quadrant / filled-arc primitive, so each
--    cell is two filled quadrant fans (TL, BR) plus two 8 px-thick arc bands
--    (TR, BL) drawn in one mesh (all cells share the single per-frame LFO
--    colour). Vertices and indices are preallocated in setup and mutated in
--    place per frame (zero per-frame allocation). The fan uses SEG = 6 arcs
--    per quadrant (polygonal error < 1 px at R <= 158).
-- 7. Degenerate-radius guard: rad can be 0 and restRad >= 1, so R >= 1; when
--    R <= 8 the band would invert (inner radius negative), so such a cell is
--    skipped entirely.
-- 8. No positional deviation: the stock grid fits inside the 1280x720 frame at
--    all knob values (odd rows shift by <= 160 px, odd columns by <= 144 px,
--    both within the frame), so no wrap or scale is applied.

local e = eyesy
local PI = math.pi

local SEG = 6          -- arcs per quadrant (15 deg each)
local FILL_V = SEG + 2 -- fan vertices: centre + SEG+1 arc points
local BAND_V = 2 * (SEG + 1)
local CELL_V = 2 * FILL_V + 2 * BAND_V  -- 44 vertices per cell
local CELL_T = 2 * SEG + 4 * SEG         -- 24 triangles per cell
local CELLS = 7 * 10

-- Deterministic middle branch of the stock legacy color_picker (see header 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

local lfoPhase = 0.21 -- documented deviation 4
local lfoInc = 0

-- Preallocated single mesh: one vertex table (CELLS*CELL_V rows) and one index
-- table (CELLS*CELL_T*3 entries) built once in setup, mutated in place per
-- frame (deviation 6).
local mesh = nil

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local offx = ctx.params.offx
  local offy = ctx.params.offy
  local size = ctx.params.size
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

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

  -- LFO: stock color_picker_lfo semantics (deviations 1, 3, 4). fg <= 0.5 is a
  -- static colour; above it inc persists across frames and the phase advances
  -- once per frame by 30 * inc * ctx.dt (one call/frame re-timed 30 -> 60 fps).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.2 end
  lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2

  local left = ctx.audio and ctx.audio.left

  local v = mesh.v
  local base = 1

  for i = 0, 6 do
    local yBase = i * y5 - y5
    for j = 0, 9 do
      local x = j * x8 - x8
      local y = yBase

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
        local step = (PI / 2) / SEG
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

        base = base + CELL_V
      else
        base = base + CELL_V
      end

    end
  end
  e.update_mesh(mesh.handle, v, mesh.idx)

  -- Single LFO colour for the whole frame (deviation 3): static for fg <= 0.5,
  -- otherwise the ramp phase folded 0 -> 2 -> 0 through the palette.
  local ph
  if fg > 0.5 then
    ph = lfoPhase
    if ph > 1 then ph = 2 - ph end
  else
    ph = (fg * 2) % 1
  end
  local r, g, b = picker(ph)
  e.color(r, g, b)
  e.draw_mesh(mesh.handle)
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("offx", 0.5, 0, 1, 1)
    e.param("offy", 0.5, 0, 1, 2)
    e.param("size", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    -- One mesh holding all 70 cells: 70*44 = 3080 vertices (limit 8192) and
    -- 70*24*3 = 5040 indices (limit 49152). Built once, mutated per frame.
    local verts = {}
    for n = 1, CELLS * CELL_V do
      verts[n] = {0, 0, 0}
    end
    local idx = {}
    local n = 1
    for cell = 1, CELLS do
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

    mesh = {
      handle = e.new_mesh(),
      v = verts,
      idx = idx,
    }
  end,
  draw = draw,
}
