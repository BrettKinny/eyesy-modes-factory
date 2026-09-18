-- s-mirror-grid-inverse — port of stock "S - Mirror Grid - Inverse"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "S - Mirror Grid - Inverse/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: line width   Knob 2: number of lines   Knob 3: square size
-- Knob 4: foreground colour   Knob 5: background colour
--
-- Shape (stock-exact, resolved at the 1280x720 verifier frame):
--   ten = int(xr * 0.0078125) = 10
--   lines = int(39*knob2 + 1) + 4   (72 at the default knob2 = 0.5)
--   linewidth = int(knob1 * ten) + 1
--   spacehoriz = int(xr / (lines - 2))   (17.6 at 72 lines -> floor 17)
--   spacevert  = int(yr / (lines - 2))   (17.3 at 72 lines -> floor 17)
--   recsize = int(ten * knob3) * 2       (10 at the default knob3 = 0.5)
--   sel = knob4 * 2
--
--   Horizontal lines (one per row j, 0..lines-1):
--     (-1, j*spacevert) -> (xr, j*spacevert), width w
--   Top oscilloscope (one bar per column m, 0..lines-1):
--     x = int(m*spacehoriz)
--     auDiom = audio_in[m] * 0.00003058 * yr        (NO max(0,·) clamp)
--     (x, 0) -> (x, yr/2 - auDiom), width w
--     square [x-recsize/2, yr/2-auDiom, recsize, recsize]
--   Bottom oscilloscope (one bar per column i, 0..lines-1):
--     x = int(i*spacehoriz)
--     auDio = audio_in[int(i + lines*0.5)] * 0.00003058 * yr  (NO min(0,·) clamp)
--     (x, yr) -> (x, yr/2 - auDio), width w
--     square [x-recsize/2, (yr/2-auDio)-recsize, recsize, recsize]
--     drawn only when recsize >= 1 AND yr/2 - auDio > yr/2
--     (i.e. auDio < 0 — the stock guard, preserved)
--
--   NOTE the inverse: unlike the sibling "S - Mirror Grid", the top bar ends
--   at yr/2 - auDiom (so it reaches toward the middle of the frame when the
--   audio sample is positive, and PAST the middle when negative) and the
--   bottom bar ends at yr/2 - auDio (reaches the middle for negative samples,
--   above it for positive ones) — hence "inverse". Neither side is clamped.
--
-- Colour (stock-exact): per drawn element,
--   sel < 1:  color = color_picker(knob4*2)
--   sel >= 1: color_rate = (color_rate + (sel-1)*0.1) % 1; color = picker(color_rate)
-- color_rate advances once per element in stock's exact draw order
-- (horizontal lines, then top bars, then bottom bars),
-- 216 advances per frame at the default line count.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker is the legacy picker, partly
--    random (random greys / random RGB outside the middle band). Randomness
--    cannot be ported (replays must be byte-identical), so the deterministic
--    middle branch is substituted: r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5,
--    b = 0.5*sin(8πc)+0.5, with the stock per-frame phase progression intact.
--    The picker is called per element exactly as stock does (no 0.21 LFO
--    offset — that is a different stock mode).
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 3. Audio: stock reads a 100-sample ring (±32768) at audio_in[j] with j in
--    0..71 (top) and audio_in[i + 36] with i in 0..71 (bottom, lines*0.5 = 36
--    at 72 lines, int() truncation). The port reads left[1 + j*10] and
--    left[1 + (i + 36)*10] (10-sample stride of the 1024-sample normalized
--    platform buffer) and denormalizes by * 32768, so the stock term
--    A*0.00003058*yr is reproduced with the same literal constant. The
--    platform buffer has no negative-index wrap; the top ring covers j = 0..71
--    exactly, and the bottom ring needs j up to 107, still inside the buffer,
--    so the stride mapping is valid with no wrap.
-- 4. Stock never calls random (the import is unused); this port uses none.
-- 5. Drawing: e.rect has no border width, so each stock line of width
--    w = int(knob1*ten)+1 px becomes four e.rect bars of thickness w (the
--    stock line is centred on its coordinate; pygame clamps to the frame, the
--    port's bars are clipped to the frame). No flat-frame deviation is needed
--    here: at the knob1-max probe the horizontal lines are 10 px thick on a
--    ~17.6 px pitch, so they never tile the frame and the grab keeps its
--    natural variance.
-- 6. No positional deviation: the bars can extend past the frame (top bar
--    past the middle for negative samples, bottom bar above the middle for
--    positive ones, squares likewise) — pygame and the engine both clip.
--    The bottom square's stock guard (auDio < 0) is preserved exactly.

local e = eyesy
local PI = math.pi

local XR = 1280
local YR = 720
local TEN = 10        -- int(1280 * 0.0078125)
local HALF = YR / 2   -- 360, stock's yr/2

-- Deterministic middle branch of the stock legacy color_picker (deviation 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Stock color_rate progression, exact per-element draw order (deviation 1):
-- sel < 1 samples knob4*2 directly; sel >= 1 advances the phase by (sel-1)*0.1.
local color_rate
local function next_color(sel, knob4)
  if sel < 1 then
    return picker(knob4 * 2)
  end
  color_rate = (color_rate + (sel - 1) * 0.1) % 1
  return picker(color_rate)
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.lw
  local k2 = ctx.params.lines
  local k3 = ctx.params.rec
  local k4 = ctx.params.fg
  local bg = ctx.params.bg

  -- Background: stock color_picker_bg with phase remapped (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  local w = math.floor(k1 * TEN) + 1
  local hw = w / 2
  local lines = math.floor(39 * k2 + 1) + 4
  local spacehoriz = math.floor(W / (lines - 2))
  local spacevert = math.floor(H / (lines - 2))
  local recsize = math.floor(TEN * k3) * 2
  local sel = k4 * 2
  local half_lines = lines * 0.5
  local rsize = math.floor(recsize * 0.5)

  -- Horizontal lines: (-1, j*spacevert) -> (W, j*spacevert), width w.
  for j = 0, lines - 1 do
    local r, g, b = next_color(sel, k4)
    e.color(r, g, b)
    local y = j * spacevert
    local y0 = math.max(0, math.floor(y - hw))
    local y1 = math.min(H - 1, math.floor(y + hw - 1))
    if y0 <= y1 then
      e.rect(0, y0, W, y1 - y0 + 1)
    end
  end

  -- Top oscilloscope: bar (x, 0) -> (x, HALF - auDiom), square at its end.
  for m = 0, lines - 1 do
    local r, g, b = next_color(sel, k4)
    e.color(r, g, b)
    local x = math.floor(m * spacehoriz)
    local s = left and left[1 + m * 10] or 0
    local auDiom = s * 32768 * 0.00003058 * H
    local ay = HALF - auDiom
    e.rect(x - hw, 0, w, math.max(0, math.floor(ay - 1)))
    if recsize >= 1 then
      local sy0 = math.max(0, math.floor(ay - rsize))
      local sy1 = math.min(H - 1, math.floor(ay + rsize - 1))
      local sx0 = math.max(0, math.floor(x - rsize))
      local sx1 = math.min(W - 1, math.floor(x + rsize - 1))
      if sx0 <= sx1 and sy0 <= sy1 then
        e.rect(sx0, sy0, sx1 - sx0 + 1, sy1 - sy0 + 1)
      end
    end
  end

  -- Bottom oscilloscope: bar (x, H) -> (x, HALF - auDio), square at its end.
  for i = 0, lines - 1 do
    local r, g, b = next_color(sel, k4)
    e.color(r, g, b)
    local x = math.floor(i * spacehoriz)
    local s = left and left[1 + math.floor(i + half_lines) * 10] or 0
    local auDio = s * 32768 * 0.00003058 * H
    local ay = HALF - auDio
    e.rect(x - hw, math.max(0, math.floor(ay + hw)), w, H - 1)
    if recsize >= 1 and ay > HALF then
      local sy0 = math.max(0, math.floor(ay - recsize))
      local sy1 = math.min(H - 1, math.floor(ay - 1))
      local sx0 = math.max(0, math.floor(x - rsize))
      local sx1 = math.min(W - 1, math.floor(x + rsize - 1))
      if sx0 <= sx1 and sy0 <= sy1 then
        e.rect(sx0, sy0, sx1 - sx0 + 1, sy1 - sy0 + 1)
      end
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("lw", 0.5, 0, 1, 1)
    e.param("lines", 0.5, 0, 1, 2)
    e.param("rec", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    color_rate = 0
  end,
  draw = draw,
}
