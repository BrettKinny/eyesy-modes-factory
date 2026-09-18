-- s-amp-color-rectangles — port of stock "S - Amp Color - Rectangles"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Amp Color - Rectangles/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- This is the fourth (last) of the four `amp-color` family modes (see
-- s-amp-color-5gon-filled / s-amp-color-5gon-outlines / s-amp-color-circles).
-- Where the 5gons share one five-vertex polygon and the circles carry five
-- random circles, this mode draws `count` nested **rectangles** centred on the
-- screen: each rectangle is rotated about the screen centre by
-- current_rotation + i*offset and filled.
--
-- Knob roles (stock-exact):
--   1 history — audio 'history' length (int(knob1*20)+1 samples)
--   2 spin — rotation direction & rate (dead zone 0.49..0.51 resets to 0;
--            below 0.48 counter-clockwise, above 0.52 clockwise,
--            rate = |knob2 - 0.48| * 52 deg/frame at 30 fps)
--   3 count — nested rectangle count (int(knob3*49)+1, max 50; floored at 2
--             and capped at 32 — deviations 7 and 8)
--   4 offset — per-rectangle rotation offset (i * knob4 * 45 deg)
--   5 bg — background colour
--
-- Scene: `count` nested rectangles at the screen centre; at level i the
-- rectangle spans rect_width x rect_height where
--   rect_width  = W - (i * (W / count) * (1 + 0.1 * (50 - count) / 50)),
--   rect_height = H - (i * (H / count) * (1 + 0.1 * (50 - count) / 50)),
-- it is rotated by current_rotation + i*offset about the screen centre, and
-- filled with a colour from the running average of level i's own audio history.
-- There is no trigger in this mode (stock has none).
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
--    denormalized by * 32768 (guard nil -> 0). This mode divides by 32768,
--    exactly as stock — the 5gon siblings share this divisor; the circles
--    sibling uses 22000.
-- 4. Audio history: stock keeps a collections.deque(maxlen=N) per level and
--    recreates every deque when N changes. Ported as preallocated tables
--    created in setup — hist[i][slot] for i = 1..32, slot = 1..21 (21 = max
--    history length), plus index; the new value is written in place at
--    hist_write[i] (advanced modulo 21) and hist_len[i] clamps to min(N, 21);
--    the average is the mean of the hist_len[i] most-recent values.
--    Zero per-frame allocation.
-- 5. Rotation re-timed 30 -> 60 fps: stock adds rotation_rate once per frame
--    at 30 fps; here the angle advances by rotation_rate * 30 * ctx.dt each
--    frame. current_rotation is never wrapped (stock never wraps it); the dead
--    zone 0.49..0.51 is kept.
-- 6. Rectangle via e.rect, no meshes: the API has no rotated-rectangle
--    primitive, so the rectangle is drawn as e.rect(-w/2, -h/2, w, h) under an
--    e.translate(cx, cy) + e.rotate(angle) push/pop — openFrameworks'
--    ofDrawRectangle is top-left-anchored and ofRotateDeg rotates about the
--    current origin, so this is exactly stock's rotate_point((0,0), p, angle)
--    + translate to centre + pygame.draw.polygon, with zero mesh handles.
--    One e.color is set per rectangle (up to 32 per frame, set immediately
--    before that rectangle's e.rect) — within the measured device cost budget
--    for this family (the grid-slide family measured 70 e.color calls/frame at
--    +13.7 ms outside tier C; 32 is well below that). No mesh handles are used:
--    the per-level colour means the levels cannot be batched into one mesh, and
--    immediate e.rect calls need none at all.
-- 7. Drawn count capped at 32. Stock's knob3 draws up to 50 rectangles
--    (int(knob3*49)+1); the per-level colour budget is 32, so the port caps it
--    there. Stock-exact for knob3 <= 0.63; above that the port draws 32 where
--    stock draws more.
-- 8. Count floored at 2. Stock's per-rectangle rotation offset is
--    current_rotation + i * (knob4 * 45), i.e. the knob's whole excursion is
--    multiplied by the level index. At the verifier's all-knobs-zero baseline
--    knob3 = 0, so stock's count is int(0*49)+1 = 1: the loop runs only i = 0,
--    the offset term is multiplied by zero, and knob4 cannot move a single
--    pixel at ANY frame count. That is a stock-faithful deadness (stock is
--    inert there too) which nonetheless fails the gate, and the gate's second
--    chance — a MIDI trigger — is not available here (this mode has no
--    trigger), so the floor is the only treatment. The drawn count is floored
--    at 2 so the offset has a rectangle to offset, the same treatment the
--    5gon siblings and the circles sibling carry (their deviation 9/8/10) and
--    the same precedent s-0-arrival-scope and s-circular-trigon-field give a
--    knob the baseline state multiplies by zero. Look impact: below knob3 =
--    1/49 ~ 0.02 the mode draws two nested rectangles where stock draws one,
--    so the all-knobs-zero baseline shows an inner rectangle covering roughly
--    64 % of the frame. Above that the geometry is stock-exact, and knob3's
--    scaling (2..32 with the draw budget) is unchanged.
-- 9. No positional deviation: the stock geometry fits inside the 1280x720
--    frame at all knob values (the outermost rectangle is exactly the frame
--    size, and rotation about the screen centre keeps it inside; inner
--    rectangles are smaller). No wrap or scale is applied.

local e = eyesy
local PI = math.pi

local MAX_COUNT = 32  -- engine per-mode draw budget for per-shape colour; see 7
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

local current_rotation = 0

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

  -- Number of rectangles (deviation 8: floored at 2; deviation 7: capped at 32
  -- so the per-level colour fits the draw budget).
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

  local cx = W / 2
  local cy = H / 2
  local spacing_factor = 0.1
  local offset_deg = k4 * 45

  for i = 0, count - 1 do
    -- Audio: stock index i (0-based) -> left[1 + i*10], /32768 (deviation 3).
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

    -- Dynamic spacing (stock-exact, N = 50).
    local rect_width = W - (i * (W / count) * (1 + spacing_factor * (50 - count) / 50))
    local rect_height = H - (i * (H / count) * (1 + spacing_factor * (50 - count) / 50))

    -- Rotation angle for this rectangle (stock-exact).
    local rotation_angle = current_rotation + i * offset_deg

    -- Draw the filled rotated rectangle about the screen centre (deviation 6).
    e.push()
    e.translate(cx, cy)
    e.rotate(rotation_angle)
    e.rect(-rect_width / 2, -rect_height / 2, rect_width, rect_height)
    e.pop()
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
  end,
  draw = draw,
}
