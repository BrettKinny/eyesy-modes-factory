-- s-amp-color-circles — port of stock "S - Amp Color - Circles"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Amp Color - Circles/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- This is the third of the four `amp-color` family modes (see
-- s-amp-color-5gon-filled / s-amp-color-5gon-outlines). Where the 5gons share
-- a single five-vertex polygon scaled/rotated about the centre, this mode
-- carries **five random circles** (centre + radius) that are scaled by the
-- nesting level, rotated about the screen centre, and each filled.
--
-- Knob roles (stock-exact):
--   1 history — audio 'history' length (int(knob1*20)+1 samples)
--   2 spin — rotation direction & rate (dead zone 0.49..0.51 resets to 0;
--            below 0.48 counter-clockwise, above 0.52 clockwise,
--            rate = |knob2 - 0.48| * 52 deg/frame at 30 fps)
--   3 count — nested circle count (int(knob3*49)+1, max 50; floored at 2 and
--             capped at 32 — deviations 7 and 8)
--   4 lfo — triangle-wave LFO step size (knob4 * 0.5 deg per 30-fps frame);
--           the per-circle offset is i * lfo_angle
--   5 bg — background colour
--   Trigger — picks five new random circles (diameter, centre); also the
--             setup-time initialisation
--
-- Scene: `count` nesting levels; at each level i the five stored circles are
-- scaled by `circle_radius / (xr/2)` where
--   circle_radius = (xr/2) - (i * (xr/(2*count)) * (1 + 0.1*(100-count)/100)),
-- rotated by current_rotation + i * lfo_angle about the screen centre, and
-- drawn filled with a colour from the running average of level i's own audio
-- history.
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
--    maps to left[1 + i*10] (oldest sample of the window, 10-sample stride).
--    The divisor is stock-exact: this mode divides by 22000 (the 5gons use
--    32768), so the port reproduces `abs(sample*32768 / 22000)` with a
--    nil-guard of 0.
-- 4. Audio history: stock keeps a collections.deque(maxlen=N) per level and
--    recreates every deque when N changes. Ported as preallocated tables
--    created in setup — hist[i][slot] for i = 1..32, slot = 1..21 (21 = max
--    history length; i is capped at 32 by the draw budget, see 7), plus
--    index, the new value is written in place at hist_write[i] (advanced
--    modulo 21) and hist_len[i] clamps to min(N, 21); the average is the mean
--    of the hist_len[i] most-recent values. Zero per-frame allocation.
-- 5. Rotation re-timed 30 -> 60 fps: stock adds rotation_rate once per frame
--    at 30 fps; here the angle advances by rotation_rate * 30 * ctx.dt each
--    frame. current_rotation is never wrapped (stock never wraps it); the dead
--    zone 0.49..0.51 is kept.
-- 6. LFO re-timed 30 -> 60 fps and clocked by ctx.time: stock's update_lfo is
--    a triangle wave that adds step_size = knob4*0.5 once per 30-fps frame,
--    clamping at calculate_ending_angle(count) (7.5 deg for count <= 8, 3.0
--    for count >= 50, linear between) and at 0, then pausing 0.5 s (gated by
--    time.time()) before reversing. The port advances lfo_angle by
--    step_size * 30 * ctx.dt per frame and gates the pause by ctx.time so
--    replays are byte-identical. calculate_ending_angle is reproduced exactly
--    (it is a pure function of count). knob4 == 0 still forces lfo_angle to 0.
-- 7. Circle via e.circle: each nested level draws its five stored circles as
--    filled e.circle calls, coloured by that level's audio-history average
--    (one e.color per level, set before the five circles — up to 32 per frame,
--    within the measured device cost budget for this family). Because the
--    colour is per-level, the levels cannot be batched into a single mesh; the
--    engine caps a mode at 32 mesh handles, so the drawn count is capped at
--    32 levels. Stock's knob3 draws up to 50 levels; the port caps it at 32
--    (one of the two geometric deviations; the other is the count floor, 8).
-- 8. Count floored at 2. Stock's per-circle offset is
--    current_rotation + i * lfo_angle, i.e. the LFO's whole excursion is
--    multiplied by the level index. At the verifier's all-knobs-zero
--    baseline knob3 = 0, so stock's count is int(0*49)+1 = 1: the loop runs
--    only i = 0, the offset term is multiplied by zero, and knob4 cannot move
--    a single pixel at ANY frame count. That is a stock-faithful deadness
--    (stock is inert there too) which nonetheless fails the gate, and the
--    gate's second chance — a MIDI trigger, which re-randomises this mode's
--    circles — would otherwise bank a false liveness (PORTING-LADDER 3.4).
--    The drawn count is floored at 2 so the offset has a level to offset, the
--    same treatment the 5gon siblings carry (their deviation 9/10) and the
--    same precedent s-0-arrival-scope and s-circular-trigon-field give a knob
--    the baseline state multiplies by zero. Look impact: below knob3 =
--    1/49 ~ 0.02 the mode draws two nesting levels where stock draws one, so
--    the all-knobs-zero baseline shows a second, smaller set of five circles.
--    Above that the geometry is stock-exact, and knob3's scaling
--    (2..32 with the draw budget) is unchanged.
-- 9. No positional deviation: the stock geometry fits inside the 1280x720
--    frame at all knob values. Each circle's centre is drawn within [r, xr-r]
--    x [r, yr-r] by construction, so after any rotation about the centre the
--    centre stays at most sqrt((xr/2)^2 + (yr/2)^2) = 728 px from the screen
--    centre, and its radius is scaled down by circle_radius/(xr/2) <= 1 (the
--    factor reaches its stock maximum of 1.1 only at the outermost level i = 0
--    of a single level, where the centre is on screen anyway). The whole disc
--    therefore stays inside the 1280x720 frame; no wrap or scale is applied.


local e = eyesy
local PI = math.pi
local DEG = math.rad

local MAX_COUNT = 32  -- engine mesh handle budget (32 max per mode); see 7
local SLOTS = 21      -- max history length: int(1*20) + 1
local MOD = SLOTS - 1 -- wrap constant: (w + 1) % 21

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

-- stock calculate_ending_angle(count) (deviation 6).
local function ending_angle(count)
  if count <= 8 then
    return 7.5
  elseif count >= 50 then
    return 3.0
  else
    return 7.5 - (7.5 - 3.0) * (count - 8) / (50 - 8)
  end
end

-- Preallocated audio-history tables (deviation 4): one per draw slot.
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

-- The five stored circles: {x, y, radius}, mutated in place (setup + trigger).
local circles = {}
for i = 1, 5 do
  circles[i] = {0, 0, 0}
end

local function init_circles(W, H)
  for i = 1, 5 do
    local diameter = (0.03 * W) + e.random() * (0.37 * W)  -- uniform(0.03*W, 0.4*W)
    local radius = diameter / 2
    circles[i][1] = radius + e.random() * (W - 2 * radius)  -- uniform(radius, W-radius)
    circles[i][2] = radius + e.random() * (H - 2 * radius)  -- uniform(radius, H-radius)
    circles[i][3] = radius
  end
end

local current_rotation = 0
local lfo_angle = 0
local lfo_direction = 1
local pause_until = 0

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local now = ctx.time
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.history
  local k2 = ctx.params.spin
  local k3 = ctx.params.count
  local k4 = ctx.params.lfo
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with phase remapped (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Trigger: pick five new random circles (in place).
  if ctx.trigger then
    init_circles(W, H)
  end

  -- Number of nesting levels (deviation 8: floored at 2; deviation 7: capped
  -- at 32 so the per-level colour fits the draw budget).
  local count = trunc(k3 * 49) + 1
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

  -- LFO: triangle wave, re-timed 30->60 fps, clocked by ctx.time (deviation 6).
  local step_size = k4 * 0.5
  if k4 == 0 then
    lfo_angle = 0
  elseif now >= pause_until then
    local end_a = ending_angle(count)
    if lfo_direction == 1 then
      lfo_angle = lfo_angle + step_size * 30 * dt
      if lfo_angle >= end_a then
        lfo_angle = end_a
        lfo_direction = -1
      end
    else
      lfo_angle = lfo_angle - step_size * 30 * dt
      if lfo_angle <= 0 then
        lfo_angle = 0
        pause_until = now + 0.5
        lfo_direction = 1
      end
    end
  end

  local cx = W / 2
  local cy = H / 2
  local spacing_factor = 0.1
  local half = W / 2

  for i = 0, count - 1 do
    -- Audio: stock index i (0-based) -> left[1 + i*10], /22000 (deviation 3).
    local current_value = 0
    if left then
      local s = left[1 + i * 10]
      if s then
        current_value = s * 32768 / 22000
        if current_value < 0 then current_value = -current_value end
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

    -- Dynamic spacing (stock-exact, N = 100).
    local circle_radius = half - (i * (W / (2 * count)) * (1 + spacing_factor * (100 - count) / 100))
    local scale = circle_radius / half

    -- Rotation angle for this level (stock-exact).
    local rotation_angle = current_rotation + i * lfo_angle
    local rad = DEG(rotation_angle)
    local cs = math.cos(rad)
    local sn = math.sin(rad)

    -- Draw the five stored circles: scale radius, rotate centre about screen
    -- centre, fill (deviation 7: e.circle; deviation 9: stays on frame).
    for k = 1, 5 do
      local p = circles[k]
      local px = p[1] - cx
      local py = p[2] - cy
      local rx = px * cs - py * sn + cx
      local ry = px * sn + py * cs + cy
      local rr = p[3] * scale
      if rr > 0.5 then
        e.circle(rx, ry, rr)
      end
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("history", 0.5, 0, 1, 1)
    e.param("spin", 0.5, 0, 1, 2)
    e.param("count", 0.5, 0, 1, 3)
    e.param("lfo", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    -- Initialize the five random circles at launch (stock does this in setup).
    init_circles(ctx.width, ctx.height)
  end,
  draw = draw,
}
