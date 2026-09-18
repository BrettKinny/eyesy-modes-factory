-- s-cone-scope — port of stock "S - Cone Scope"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "S - Cone Scope/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: x position (fan pivot on the x axis)
-- Knob 2: angle (far-end vertical offset of each segment)
-- Knob 3: line width
-- Knob 4: foreground colour (LFO picker; >0.5 = animated rainbow across the fan)
-- Knob 5: background colour
--
-- Documented deviations from stock (1-4) and one positional note (5):
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker, which
--    is partly random (random greys / random RGB). Randomness cannot be
--    ported (replays must be byte-identical), so the deterministic middle
--    branch is substituted: r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5,
--    b = 0.5*sin(8πc)+0.5.
--    The LFO ramp semantics (0→2→0) and per-segment phase step are stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. LFO re-timed 30 -> 60 fps: stock advanced the LFO index once per segment
--    call (50 calls/frame at 30 fps = 1500*inc/s); here the phase advances
--    once per frame by 1500 * inc * dt. The per-segment c*inc step is
--    stock-exact, keeping the rainbow spread across the fan.
-- 4. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with audio_in[i];
--    the platform buffer is 1024 normalized samples. Stock index j (0-based)
--    maps to left[1 + j*10] (oldest sample of the window, 10-sample stride)
--    and is denormalized by * 32768; soundwidth = A / 35 (stock's
--    audio_in[i]*xres/(xres*35) reduces to audio_in[i]/35).
-- 5. Position: x0 = int(knob1 * xres) is kept stock-exact. At knob1 = 1.0 the
--    pivot sits on the right edge, so the segments whose sample is positive
--    reach off-frame and only the negative half of the fan is drawn — that is
--    stock's own behaviour, the frame is neither blank nor flat, and the knob
--    is still observable at both probe points, so no wrap or clamp is applied.
--    (An earlier revision wrapped x0 modulo the width, which made knob1 = 1.0
--    pixel-identical to the baseline.)

local e = eyesy
local PI = math.pi

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
  local W = ctx.width
  local H = ctx.height
  local posx = ctx.params.posx
  local angle = ctx.params.angle
  local width = ctx.params.width
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

  -- Background: stock color_picker_bg_original with phase remapped to the
  -- middle of the picker's range (see header, deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- LFO: stock color_picker_lfo semantics. Phase advances once per frame by
  -- 1500 * inc * dt (50 calls/frame * 30 fps re-timed). inc persists across
  -- frames exactly as stock's color_lfo_inc does; for fg <= 0.5 the colour is
  -- static: picker((fg*2) % 1).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 2 * 0.1 end
  lfoPhase = (lfoPhase + 1500 * lfoInc * dt) % 2

  -- Loop-invariant geometry
  local x0 = math.floor(posx * W)
  local newy = 0.8 * H - trunc(angle * 1.5972 * H)
  local linewidth = trunc(width * W * 0.016)

  local left = ctx.audio and ctx.audio.left
  local ystep = H / 50

  for i = 0, 49 do
    -- Foreground: static for fg <= 0.5, otherwise the stock LFO ramp
    -- (phase + i*inc) folded 0→2→0, then the deterministic palette.
    local x = (fg > 0.5) and (((lfoPhase + i * lfoInc) % 2)) or ((fg * 2) % 1)
    if x > 1 then x = 2 - x end
    local r, g, b = picker(x)
    e.color(r, g, b)

    -- Audio: stock index i (0-based) -> left[1 + i*10], denormalized.
    local s = left and left[1 + i * 10] or 0
    local soundwidth = s * 32768 / 35
    local y = i * ystep
    e.line(x0, y + i, x0 + soundwidth, y + i + newy, 1 + linewidth)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("posx", 0.5, 0, 1, 1)
    e.param("angle", 0.5, 0, 1, 2)
    e.param("width", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
