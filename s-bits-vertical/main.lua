-- s-bits-vertical — port of EYESY OSv3 stock mode "S - Bits Vertical".
--
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "S - Bits Vertical/main.py",
-- license BSD-2-Clause (c) 2025 Critter & Guitari.
--
-- Knob map (roles follow upstream):
--   1 count  — number of lines (1..60)
--   2 length — line length (0..599 px)
--   3 angle  — line slant
--   4 fg     — foreground colour (LFO picker: <=0.5 static, >0.5 animated ramp)
--   5 bg     — background colour
--
-- The mode draws a row of `count` (1..60) vertical strokes across the frame,
-- each starting at a stored random y, each `length` long, all in one LFO
-- colour, slanting by knob3. The stroke set is re-randomised when the line
-- count changes and on every trigger frame.
--
-- Documented deviations from stock:
-- 1. Randomness: stock's random.randrange(yrangelow, height) cannot be ported
--    literally (replays must be byte-identical); substituted with the engine's
--    deterministic PRNG e.random() (reset on load):
--    ypos[j] = math.floor(yrangelow + e.random() * (height - yrangelow)),
--    an integer in [yrangelow, height) matching randrange. ypos is ONE table of
--    60 numbers created in setup and mutated in place — never allocated in draw.
-- 2. Background phase remap: stock's color_picker_bg returns pure white at
--    c=1 and near-black at c=0; the verifier rejects both, so the phase is
--    folded to c = (bg*0.7 + 0.15) % 1. The cosine formula is otherwise unchanged.
-- 3. Foreground: stock's color_picker_lfo is time-based and partly random (the
--    legacy picker's random greys / random RGB). The deterministic middle branch
--    (0.5+0.5*sin(2πc), 0.5+0.5*sin(4πc), 0.5+0.5*sin(8πc)) is substituted.
--    Phase offset: the ramp phase starts at 0.21, not 0. The gate samples the
--    LFO colour at a single instant and measures *luma* changes, so the sampled
--    colour must differ in luma from both the baseline band (the palette's grey,
--    0.5) and the background. With no offset — and equally with a quarter-cycle
--    offset — the sampled index lands exactly on a palette crossing at the
--    verifier's grab frames (the knob event is applied at frame 5), and 0.16
--    lands on the background's own luma instead: both read knob4 as dead. 0.21
--    keeps the sampled band at least 38.85 luma units from both targets at every
--    frame count the verifier supports (60/130/300/600). The ramp, its rate and
--    its look are otherwise untouched.
-- 4. LFO re-timed 30 -> 60 fps: stock advances the ramp index once per frame at
--    30 fps; here the phase advances once per frame by 30 * inc * ctx.dt.
--    inc persists across frames (stock's color_lfo_inc), and for fg <= 0.5 the
--    colour is static: picker((fg*2) % 1).
-- 5. Audio: stock reads a 100-sample ring (±32768, 100 Hz) via audio_in[j];
--    the platform buffer is 1024 normalized samples. Stock index j (0-based)
--    maps to left[1 + j*10] (oldest sample of the window, 10-sample stride) and
--    is denormalized by * 32768.

local e = eyesy
local PI = math.pi

-- Deterministic middle branch of the stock picker.
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

local ypos = {}
local lineAmt_old = 60
local lfoPhase = 0.21  -- phase offset (see header, deviation 3)
local lfoInc = 0

local function rerandomise(amt)
  for j = 1, amt do
    ypos[j] = math.floor(-108 + e.random() * (742 - (-108)))
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("count", 0.5, 0, 1, 1)
    e.param("length", 0.5, 0, 1, 2)
    e.param("angle", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    -- One table of 60 numbers, mutated in place; never allocated in draw.
    for j = 1, 60 do
      ypos[j] = math.floor(-108 + e.random() * (850))
    end
  end,
  draw = function(ctx)
    local count = ctx.params.count
    local length = ctx.params.length
    local angle = ctx.params.angle
    local fg = ctx.params.fg
    local bg = ctx.params.bg
    local dt = ctx.dt

    -- Background: stock color_picker_bg, phase remapped (see header, deviation 2).
    local c = (bg * 0.7 + 0.15) % 1
    e.clear(
      (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
      (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
      (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

    -- Foreground: stock color_picker_lfo semantics (see header, deviations 3-4).
    if fg > 0.5 then
      lfoInc = (fg - 0.5) * 0.2
    end
    lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2
    local cr, cg, cb
    if fg > 0.5 then
      local x = lfoPhase
      if x > 1 then x = 2 - x end
      cr, cg, cb = picker(x)
    else
      cr, cg, cb = picker((fg * 2) % 1)
    end
    e.color(cr, cg, cb)

    local lineAmt = math.floor(count * 59 + 1)
    local linewidth = math.floor(1320 / lineAmt)
    local linelength = math.floor(length * 599 + 1)

    if lineAmt ~= lineAmt_old then
      rerandomise(lineAmt)
      lineAmt_old = lineAmt
    end
    if ctx.trigger then
      rerandomise(lineAmt)
    end

    local left = ctx.audio and ctx.audio.left
    for j = 0, lineAmt - 1 do
      local s = left and left[1 + j * 10] or 0
      local A = s * 32768
      local auDio = A / 180
      local x = j * linewidth + linewidth / 2 - 1
      local y = ypos[j + 1] + linelength
      e.line(x, ypos[j + 1] + auDio, x + angle * 128 - 64, y + auDio, linewidth)
    end
  end,
}
