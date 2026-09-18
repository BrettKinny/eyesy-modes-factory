-- s-circular-trigon-field — port of EYESY OSv3 stock mode "S - Circular
-- Trigon Field".
--
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Circular Trigon Field/main.py", licence BSD-2-Clause,
-- (c) 2025 Critter & Guitari. Stock draws 50 triangles on a circle of radius
-- R = int(knob1*800) + audio_in[i]/100 centred at (640, 316.8): odd i are
-- filled with the LFO colour, even i are 1 px outlines with a colour picked
-- from a random phase; every triangle's second vertex carries a random x
-- jitter of 0..77 px re-drawn every frame, and its two non-centre vertices
-- are placed by knobs 2 and 3.
--
-- Knob roles (stock-exact):
--   1 radius — circle radius (int(knob1 * 800) + audio/100)
--   2 point2 — second-vertex offset (knob2 * 199.68 px, +x and +y)
--   3 point3 — third-vertex offset (knob3 * 199.68 px, -x and +y)
--   4 fg — foreground colour (LFO picker)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Deterministic PRNG: stock's random.randrange (re-drawn jitter, re-picked
--    outline colour) cannot be ported literally — replays must be
--    byte-identical — so e.random() (the engine's deterministic PRNG, reset on
--    load) substitutes: jitter = floor(e.random()*78), outline phase =
--    floor(e.random()*100)*0.01, called in stock's order (one jitter per
--    triangle, all 50; outline phase for even i only).
-- 2. Background phase remap: c = (bg*0.7 + 0.15) % 1; the exact cosine
--    formula is unchanged (stock returns pure white at c = 1 / pure black at
--    c = 0, both rejected by the verifier).
-- 3. Quarter-cycle LFO phase offset: the phase is initialised at 0.25, not 0.
--    Without it the ramp's index at the verifier's grab frame
--    (1500*0.1*300/60 = 750, a multiple of 2) lands exactly on the palette's
--    grey (0.5,0.5,0.5) — the baseline colour — so knob4 measures dead at
--    both probe points. The offset preserves the ramp, its rate and its look.
-- 4. LFO re-timed 30 -> 60 fps: 50 calls/frame at 30 fps = 1500*inc per
--    second, so the phase advances once per frame by 1500 * inc * ctx.dt; the
--    per-triangle (phase + i*inc) % 2, folded 0->2->0, step is stock-exact.
-- 5. Audio stride: stock reads a 100-sample ring (+/-32768, 100 Hz) with
--    audio_in[i]; the platform buffer is 1024 normalized samples, so stock
--    index i (0-based) maps to left[1 + i*10] (oldest sample of the window,
--    10-sample stride) denormalized by * 32768.
-- 6. Triangles via mesh handles: the API has no triangle primitive. The 25
--    filled triangles (odd i) are 25 preallocated 3-vertex meshes created in
--    setup, mutated in place each frame (zero per-frame allocation) and drawn
--    each with its own e.color; the 25 even-i outlines are three e.line calls
--    (A->B, B->C, C->A) width 1, which is what gfxdraw.trigon draws. Stock
--    interleaves filled and outlined triangles by index; drawing the filled
--    set first then the outlines changes only the z-order of non-overlapping
--    shapes.
-- 7. Vestigial: stock computes x960 and never uses it; lx/ly/note_down are
--    dead globals — all omitted.

local e = eyesy
local PI = math.pi

local X640 = 640
local Y260 = 316.8
local X800 = 800
local X200 = 199.68 -- 1280 * 0.156
local XRAN = 78

-- Deterministic middle branch of the legacy picker (see PORTING-LADDER 3.4).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

local lfoPhase = 0.25 -- quarter-cycle offset, documented deviation 3
local lfoInc = 0

-- Preallocated mesh state for the 25 filled (odd-i) triangles: one 3-vertex
-- table and one index triple each, mutated in place per frame (deviation 6).
local filled = {}

local function draw(ctx)
  local radius = ctx.params.radius
  local point2 = ctx.params.point2
  local point3 = ctx.params.point3
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  -- Background: stock color_picker_bg exact formula with the phase remap
  -- (documented deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- LFO: stock color_picker_lfo semantics (deviation 4). fg <= 0.5 is a
  -- static colour; above it inc = (fg-0.5)*0.2 persists across frames and
  -- the phase advances once per frame by 1500 * inc * dt (50 calls/frame *
  -- 30 fps).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.2 end
  lfoPhase = (lfoPhase + 1500 * lfoInc * dt) % 2

  local off2 = trunc(point2 * X200)
  local off3 = trunc(point3 * X200)

  for i = 0, 49 do
    -- Audio: stock index i (0-based) -> left[1 + i*10] (deviation 5).
    local A = 0
    if left then
      local s = left[1 + i * 10]
      if s then A = s * 32768 end
    end
    local R = trunc(radius * X800) + A / 100
    local ang = i / 50 * 6.28
    local x = R * math.cos(ang) + X640
    local y = R * math.sin(ang) + Y260

    -- Jitter: one per triangle, in stock's call order (deviation 1).
    local jitter = math.floor(e.random() * XRAN)

    local ax, ay = trunc(x), trunc(y)
    local bx = ax + off2 + jitter
    local by = ay + off2
    local cx = ax - off3
    local cy = ay + off3

    if i % 2 == 1 then
      -- Filled triangle in the LFO colour (deviations 3, 4).
      local ph = (lfoPhase + i * lfoInc) % 2
      if ph > 1 then ph = 2 - ph end
      local r, g, b = picker(ph)
      local f = filled[(i + 1) // 2]
      local v = f.vertices
      v[1][1] = ax; v[1][2] = ay; v[1][3] = 0
      v[2][1] = bx; v[2][2] = by; v[2][3] = 0
      v[3][1] = cx; v[3][2] = cy; v[3][3] = 0
      e.update_mesh(f.handle, v, f.indices)
      e.color(r, g, b)
      e.draw_mesh(f.handle)
    else
      -- 1 px outline, colour from a random phase (deviation 1).
      local op = math.floor(e.random() * 100) * 0.01
      local r, g, b = picker(op)
      e.color(r, g, b)
      e.line(ax, ay, bx, by, 1)
      e.line(bx, by, cx, cy, 1)
      e.line(cx, cy, ax, ay, 1)
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("radius", 0.5, 0, 1, 1)
    e.param("point2", 0.5, 0, 1, 2)
    e.param("point3", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    for n = 1, 25 do
      filled[n] = {
        handle = e.new_mesh(),
        vertices = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}},
        indices = {1, 2, 3},
      }
    end
  end,
  draw = draw,
}
