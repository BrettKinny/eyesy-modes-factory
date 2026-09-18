-- s-two-scopes — port of stock "S - Two Scopes"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Two Scopes/main.py", licence BSD-2-Clause,
-- (c) 2025 Critter & Guitari. Stock draws two stacked audio scopes: a
-- 50-stroke scope starting at x = int(knob1*1280) and a 49-stroke scope
-- (stock's second loop runs i = 51..99, skipping i = 50) starting at
-- x = int(knob2*1280), strokes 15 px apart (yr/48) and reaching
-- audio_in[i]/35 px further; every stroke takes one colour from the
-- per-stroke LFO picker and a width of int(knob3*32.4 + 1).
--
-- Knob roles (stock-exact):
--   1 pos1 — first scope x position (int(knob1 * 1280) px)
--   2 pos2 — second scope x position (int(knob2 * 1280) px)
--   3 width — line width (int(knob3 * 32.4 + 1) px, 1 px floor, deviation 5)
--   4 fg — foreground colour (LFO picker, per stroke; >0.5 = animated)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random (random greys / random RGB). Randomness cannot
--    be ported (replays must be byte-identical), so the deterministic
--    middle branch is substituted: r = 0.5*sin(2πc)+0.5,
--    g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5. The LFO ramp semantics
--    (0→2→0) and the per-stroke (phase + i*inc) step are stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. LFO re-timed 30 -> 60 fps: stock advanced the LFO index once per
--    picker call (100 calls/frame at 30 fps); here the phase advances
--    once per frame by 3000 * inc * dt with inc = (fg - 0.5) * 0.2, and
--    the per-stroke c = (phase + i*inc) % 2 step is kept stock-exact, so
--    the colour varies within the frame (the gate's single-instant sample
--    already differs from the baseline — no phase offset needed, PORTING-
--    LADDER §3.4). For fg <= 0.5 the colour is the static
--    picker((fg * 2) % 1), stock-exact.
-- 4. Audio: stock reads a 100-sample ring (±32768) with audio_in[i]; the
--    platform buffer is 1024 normalized samples. Stock index i (0-based)
--    maps to left[1 + i*10] (oldest sample of the window, 10-sample
--    stride), denormalized back to stock scale: A = left[1 + i*10] * 32768
--    (guard nil -> 0), then the stock divisor x1 = x0 + A/35.
-- 5. Line width floor: pygame treats a line width <= 0 as 1 px, while
--    e.line takes the pixel width literally, so linewidth is clamped to
--    at least 1. Stock's "+1" stays inside the floor, as written.
--
-- Stock keeps i = 50 out of the second loop (range(51, 100)), so the
-- bottom scope has 49 strokes at y = 15..735; kept exactly.

local e = eyesy
local PI = math.pi

local XR = 1280
local YR = 720
local YSTEP = YR / 48      -- 15 px per stroke
local WMAX = YR * 0.045    -- 32.4 px, stock's max line width
local ADIV = 35            -- stock's audio divisor

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
  local pos1 = ctx.params.pos1
  local pos2 = ctx.params.pos2
  local width = ctx.params.width
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

  -- LFO: stock color_picker_lfo semantics, re-timed (deviation 3). inc
  -- persists across frames; the phase advances once per frame by
  -- 3000 * inc * dt (100 calls/frame at 30 fps = stock's per-second rate).
  -- fg <= 0.5 is a static colour: picker((fg*2) % 1).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.2 end
  lfoPhase = (lfoPhase + 3000 * lfoInc * dt) % 2

  -- Loop-invariant geometry (deviation 5: stock's +1 kept inside the
  -- floor, then clamped to 1 px).
  local x0a = math.floor(pos1 * XR)
  local x0b = math.floor(pos2 * XR)
  local linewidth = math.floor(width * WMAX + 1)
  if linewidth < 1 then linewidth = 1 end

  local left = ctx.audio and ctx.audio.left
  local animated = fg > 0.5

  -- first scope: i = 0..49, y = i * 15
  for i = 0, 49 do
    -- Foreground: static for fg <= 0.5, otherwise the stock LFO ramp
    -- (phase + i*inc) folded 0→2→0, then the deterministic palette.
    local x = animated and ((lfoPhase + i * lfoInc) % 2) or ((fg * 2) % 1)
    if x > 1 then x = 2 - x end
    e.color(picker(x))

    -- Audio: stock index i (0-based) -> left[1 + i*10], denormalized
    -- (deviation 4).
    local s = left and left[1 + i * 10] or 0
    local x1 = x0a + s * 32768 / ADIV
    e.line(x0a, i * YSTEP, trunc(x1), i * YSTEP, linewidth)
  end

  -- second scope: stock's range(51, 100) — i = 51..99, so 49 strokes at
  -- y = (i-50) * 15 = 15..735. i = 50 is intentionally absent (stock-exact).
  for i = 51, 99 do
    local x = animated and ((lfoPhase + i * lfoInc) % 2) or ((fg * 2) % 1)
    if x > 1 then x = 2 - x end
    e.color(picker(x))

    local s = left and left[1 + i * 10] or 0
    local x1 = x0b + s * 32768 / ADIV
    e.line(x0b, (i - 50) * YSTEP, trunc(x1), (i - 50) * YSTEP, linewidth)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("pos1", 0.5, 0, 1, 1)
    e.param("pos2", 0.5, 0, 1, 2)
    e.param("width", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
