-- s-classic-horizontal — port of stock "S - Classic Horizontal"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Classic Horizontal/main.py", licence BSD-2-Clause,
-- (c) 2025 Critter & Guitari. Stock draws 100 vertical lines across the
-- frame at x = i * 1280/98, each running from the vertical centre (y = 360)
-- to y = 360 + audio_in[i]/32768 * 720 * (knob3 + 0.5), with a filled circle
-- of radius int(knob2 * 1280/25) sitting on each line's far end; every
-- segment takes one colour from the LFO picker.
--
-- Knob roles (stock-exact):
--   1 width — line width (int(knob1 * 12.8) px, 1 px floor, deviation 5)
--   2 ball — circle size (int(knob2 * 51.2) px; drawn only when >= 1)
--   3 height — vertical scale of the lines (720 * (knob3 + 0.5) px full)
--   4 fg — foreground colour (LFO picker; >0.5 = animated rainbow)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random (random greys / random RGB). Randomness cannot
--    be ported (replays must be byte-identical), so the deterministic
--    middle branch is substituted: r = 0.5*sin(2πc)+0.5,
--    g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5. The LFO ramp semantics
--    (0→2→0) and the per-segment (phase + i*inc) % 2 step are stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. LFO re-timed 30 -> 60 fps: stock advanced the LFO index once per
--    segment call (100 calls/frame at 30 fps = 3000*inc/s); here the phase
--    advances once per frame by 3000 * inc * dt. The per-segment c*inc step
--    is stock-exact, keeping the rainbow spread across the rows. No phase
--    offset is needed: the colour varies within the frame, so the gate's
--    single-instant sample already differs from the baseline (PORTING-LADDER
--    §3.4).
-- 4. Audio: stock reads a 100-sample ring (±32768) with audio_in[i]; the
--    platform buffer is 1024 normalized samples. Stock index i (0-based)
--    maps to left[1 + i*10] (oldest sample of the window, 10-sample
--    stride) and keeps the stock formula's own normalization:
--    length = sample * 720 * (knob3 + 0.5), sample = left[1 + i*10]
--    (guard nil -> 0). No *32768 here: stock divides by 32768 and the
--    platform buffer is already normalized.
-- 5. Line width floor: pygame treats a line width <= 0 as 1 px, while
--    e.line takes the pixel width literally, so linewidth is clamped to
--    at least 1. The circle follows pygame's radius-0-draws-nothing rule
--    and is skipped when ball < 1 (stock-exact).

local e = eyesy
local PI = math.pi

local LINES = 100
local SPACE = 1280 / 98
local POSITION = 360
local XR = 1280
local YR = 720

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

local lfoPhase = 0
local lfoInc = 0

local function draw(ctx)
  local width = ctx.params.width
  local ball = ctx.params.ball
  local height = ctx.params.height
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

  -- Background: stock color_picker_bg exact formula with the pack's phase
  -- safeguard (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- LFO: stock color_picker_lfo semantics. inc persists across frames; the
  -- phase advances once per frame by 3000 * inc * dt (deviation 3).
  -- fg <= 0.5 is a static colour: picker((fg*2) % 1).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.2 end
  lfoPhase = (lfoPhase + 3000 * lfoInc * dt) % 2

  -- Loop-invariant geometry (deviation 5: 1 px line-width floor).
  local linewidth = math.floor(width * XR / LINES)
  if linewidth < 1 then linewidth = 1 end
  local ballSize = math.floor(ball * XR / (LINES - 75))
  local hscale = YR * (height + 0.5)

  local left = ctx.audio and ctx.audio.left

  for i = 0, LINES - 1 do
    -- Foreground: static for fg <= 0.5, otherwise the stock LFO ramp
    -- (phase + i*inc) folded 0→2→0, then the deterministic palette.
    local x = (fg > 0.5) and ((lfoPhase + i * lfoInc) % 2) or ((fg * 2) % 1)
    if x > 1 then x = 2 - x end
    local r, g, b = picker(x)
    e.color(r, g, b)

    -- Audio: stock index i (0-based) -> left[1 + i*10], normalized
    -- (deviation 4).
    local s = left and left[1 + i * 10] or 0
    local y1 = s * hscale
    local px = i * SPACE
    local ty = trunc(y1) + POSITION

    -- Circle first, then line, as stock draws them.
    if ballSize >= 1 then
      e.circle(px, ty, ballSize)
    end
    e.line(px, POSITION, px, ty, linewidth)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("width", 0.5, 0, 1, 1)
    e.param("ball", 0.5, 0, 1, 2)
    e.param("height", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
