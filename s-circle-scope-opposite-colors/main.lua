-- s-circle-scope-opposite-colors — port of stock "S - Circle Scope - Opposite Colors"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Circle Scope - Opposite Colors/main.py" (85 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: line & circle sizes (three size regimes)
-- Knob 2: scope diameter (radius R)
-- Knob 3: rotation rate (dead zone 0.48..0.52, ±(delta)*50 per frame at 30 fps)
-- Knob 4: foreground color (line phase 1-((i*fg+0.5)%1), circle phase (i*fg+0.5)%1)
-- Knob 5: background color
--
-- Scene: 50 segments around a circle of radius R (audio-driven), joined into a
-- polyline — lx/ly carry the previous point across the segment and across
-- frames — the whole ring rotated by rotation_angle about the frame centre,
-- with a per-segment colour from knob4 and a size regime from knob1. The
-- per-frame j walk increments for i = 0..24 and decrements for i = 25..49,
-- so segment i reads audio index j = 1,2,...,25,24,...,1.
--
-- Difference from s-circle-scope (stock "S - Circle Scope"): the polyline uses
-- the complement of the palette phase, 1 - ((i*fg + 0.5) % 1), while the circle
-- keeps the stock phase ((i*fg + 0.5) % 1); both sample the same 24-stop
-- half-stop table, so the two elements read as opposite colours.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker is legacy and partly random
--    (random greys for small values, random RGB above 0.96). Randomness cannot
--    be ported (replays must be byte-identical), so the deterministic middle
--    branch is substituted (see deviation 4 for how it is sampled).
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. Rotation re-timed 30 -> 60 fps: stock adds ±(delta) * 50 once per frame
--    at 30 fps; here the angle advances by (0.52 - knob3) * 50 * 30 * ctx.dt
--    (signed by the dead-zone side) each frame. rotation_angle is never
--    wrapped (stock never wraps it); the dead zone 0.48..0.52 is kept.
-- 4. Foreground palette sampling (same defect and same fix as s-concentric,
--    docs/ports/s-concentric.md deviation 3): stock's phase set
--    {(i*knob4 + 0.5) % 1} collapses onto the middle-branch palette's grey
--    zero-crossings at every knob4 probe the verifier uses — c = 0.5 and
--    c = 0/1.0 both make sin(2*pi*c) = sin(4*pi*c) = sin(8*pi*c) = 0, so the
--    whole ring is (0.5, 0.5, 0.5) and knob4 measured dead (0.0000 at both
--    probe points). The palette is therefore built with stops at half-stop
--    offsets, c = (i + 0.5)/24, and sampled with cyclic linear interpolation:
--    no knob position lands on a grey crossing, while the rainbow ramp, its
--    per-segment spacing and the knob's effect are otherwise untouched.
--    (knob4 = 1.0 stays byte-identical to the baseline — the phase is
--    constant 0.5 for every i — exactly as in s-concentric; knob liveness
--    rests on the 0.5 probe.)
-- 5. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with
--    audio_in[j] / 100; the platform buffer is 1024 normalized samples. Stock
--    index j (0-based, 1..25 here) maps to left[1 + j*10] (oldest sample of
--    the window, 10-sample stride), denormalized by * 32768 (guard nil -> 0).
--    The /100 division is kept stock-exact.
-- 6. Line width: pygame clamps a width <= 0 to 1 px; e.line takes the pixel
--    width literally, so the width is clamped to at least 1. Circle radius is
--    truncated to an integer (stock's int(circ_size)); a radius < 1 is not
--    drawn (pygame's radius-0 circle draws nothing).
-- 7. Legibility floor, stroke thickness (docs/PORTING-LADDER.md §4, same
--    precedent as s-five-lines-spin and s-zoom-scope): at the verifier's
--    all-knobs-zero baseline stock's sizer < 1 branch draws 50 one-pixel
--    chords of ~76 px — about 2500 lit pixels — and moving a 1 px ring by a
--    few pixels changes far less than the 0.001 fraction (921 px) the metric
--    needs, so knob1 and the audio check would read dead. The width is
--    floored to 3 px: knob1 still scales 3 -> 44 px across its range (and the
--    regime structure is otherwise stock-exact), and the audio term moves the
--    ring by ~32 px at the verifier's loud gain, which at 3 px width clears
--    the threshold.
local e = eyesy
local PI = math.pi
local DEG = math.rad

-- 24-stop deterministic middle branch, stops at half-stop offsets so no knob
-- position lands on the palette's grey zero-crossings (deviation 4). Built
-- once; the per-frame draw path allocates nothing.
local FG_STOPS = {}
do
  for i = 0, 23 do
    local c = (i + 0.5) / 24
    FG_STOPS[i + 1] = {
      0.5 + 0.5 * math.sin(2 * PI * c),
      0.5 + 0.5 * math.sin(4 * PI * c),
      0.5 + 0.5 * math.sin(8 * PI * c),
    }
  end
end

-- Sample the 24-stop palette at cyclic phase p in [0,1): linear interpolation
-- between stops i/n segments apart (same spacing as e.palette(name, phase)).
local function fg_pick(p)
  local n = 24
  local x = p % 1
  if x < 0 then x = x + 1 end
  local f = x * n
  local i = math.floor(f) + 1
  local t = f - (i - 1)
  local a, b = FG_STOPS[i], FG_STOPS[i % n + 1]
  return a[1] + (b[1] - a[1]) * t,
         a[2] + (b[2] - a[2]) * t,
         a[3] + (b[3] - a[3]) * t
end

local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

-- stock globals, persistent across frames (setup sets lx/ly to the centre and
-- begin to 0; j is a per-frame walk, so it is a local inside the loop).
local rotation_angle = 0
local lx, ly = 640, 360
local begin = 0

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local size = ctx.params.size
  local diameter = ctx.params.diameter
  local spin = ctx.params.spin
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

  -- Background: stock color_picker_bg with phase remap (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Rotation: stock ±(delta) * 50 per frame at 30 fps, re-timed (deviation 3).
  if spin < 0.48 then
    rotation_angle = rotation_angle - (0.48 - spin) * 50 * 30 * dt
  elseif spin > 0.52 then
    rotation_angle = rotation_angle + (spin - 0.52) * 50 * 30 * dt
  end

  local rad_angle = DEG(rotation_angle)
  local cs = math.cos(rad_angle)
  local sn = math.sin(rad_angle)
  local crad = W * 0.016
  local sizer = size * 3
  local line_size, circ_size
  if sizer < 1 then
    line_size = 1
    circ_size = sizer * 2 * crad
  elseif sizer <= 2 then
    line_size = (sizer - 1) * 22 + 1
    circ_size = 0
  else
    line_size = (sizer - 2) * 22 + 1
    circ_size = (sizer - 2) * 2 * crad + 3
  end
  local width = math.max(3, trunc(line_size))  -- deviations 6, 7
  local Rbase = (diameter * 2) * (W * 0.313) - (W * 0.117)
  local left = ctx.audio and ctx.audio.left

  local j = 0
  for i = 0, 49 do
    -- stock per-frame j walk: +1 for i <= 24, -1 for i >= 25.
    if i <= 24 then
      j = j + 1
    else
      j = j - 1
    end

    -- Audio: stock index j -> left[1 + j*10], denormalized (deviation 4).
    local A = 0
    if left then
      local s = left[1 + j * 10]
      if s then A = s * 32768 end
    end
    local R = Rbase + A / 100

    local ang = (i / 50) * 6.28
    local x = R * math.cos(ang) + W / 2
    local y = R * math.sin(ang) + H / 2
    local px = x - W / 2
    local py = y - H / 2
    local rotated_x = px * cs - py * sn + W / 2
    local rotated_y = px * sn + py * cs + H / 2

    -- Opposite colours (stock `seg` difference vs "S - Circle Scope"): the
    -- line uses the complement of the palette phase, the circle keeps the
    -- stock phase; both sample the same 24-stop table.
    local r, g, b = fg_pick(1 - (((i * fg) + 0.5) % 1))
    e.color(r, g, b)
    e.line(lx, ly, rotated_x, rotated_y, width)

    lx = rotated_x
    ly = rotated_y

    local cr = trunc(circ_size)
    if cr >= 1 then
      local r2, g2, b2 = fg_pick(((i * fg) + 0.5) % 1)
      e.color(r2, g2, b2)
      e.circle(rotated_x, rotated_y, cr)
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("size", 0.5, 0, 1, 1)
    e.param("diameter", 0.5, 0, 1, 2)
    e.param("spin", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
