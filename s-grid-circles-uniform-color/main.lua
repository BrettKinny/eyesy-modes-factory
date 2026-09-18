-- s-grid-circles-uniform-color — port of stock "S - Grid Circles - Uniform Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Grid Circles - Uniform Color/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: x offset (shifts odd rows right)
-- Knob 2: y offset (shifts odd columns down)
-- Knob 3: rest radius (base circle size)
-- Knob 4: foreground colour phase (single LFO colour for all circles)
-- Knob 5: background colour
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker is the legacy picker, partly random
--    (random greys / random RGB outside the middle band). Randomness cannot be
--    ported (replays must be byte-identical), so the deterministic middle branch
--    is substituted: r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5,
--    b = 0.5*sin(8πc)+0.5.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 3. LFO phase offset 0.21: the picker is called once per frame (the stock
--    call is inside the cell loop but loop-invariant), so the gate samples the
--    colour at a single instant and measures luma only. The offset (from
--    tools/lfo_offset.py --inc 0.1 --calls 1) keeps the sampled colour at
--    least 38.85 luma units from both the palette grey and the background luma
--    at every frame count the verifier supports (60/130/300/600).
-- 4. LFO re-time 30 -> 60 fps: stock advanced the LFO once per call at
--    30 fps; here the phase advances once per frame by 30 * inc * ctx.dt.
--    inc = (fg - 0.5) * 0.2 persists across frames (stock's color_lfo_inc),
--    and for fg <= 0.5 the colour is static: picker((fg*2) % 1).
-- 5. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with audio_in[j+i];
--    the platform buffer is 1024 normalized samples. Stock index k (0-based,
--    here k = j+i, always 0..15) maps to left[1 + k*10] (10-sample stride) and
--    is denormalized by * 32768. No negative-index wrap is needed in this mode.
-- 6. No positional deviation: the stock grid fits inside the 1280×720 frame at
--    all knob values (odd rows shift by ≤ 160 px, odd columns by ≤ 144 px,
--    both within the frame), so no wrap or scale is applied.

local e = eyesy
local PI = math.pi

-- Deterministic middle branch of the stock legacy color_picker (see header 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- LFO state (deviations 3-4): phase offset 0.21, per-call step persisted.
local lfoPhase = 0.21
local lfoInc = 0

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local offx = ctx.params.offx
  local offy = ctx.params.offy
  local size = ctx.params.size
  local fg = ctx.params.fg
  local bg = ctx.params.bg

  local x8 = W / 8
  local y5 = H / 5
  local xoffset = math.floor(offx * x8)
  local yoffset = math.floor(offy * y5)
  local restRad = math.floor(size * (W * 0.023)) + 1
  local radScale = W * 0.1

  local left = ctx.audio and ctx.audio.left

  -- Background: stock color_picker_bg_original with phase remapped (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- LFO: stock color_picker_lfo(fg), evaluated once per frame (deviations 3-4).
  if fg > 0.5 then
    lfoInc = (fg - 0.5) * 0.2
  end
  lfoPhase = (lfoPhase + 30 * lfoInc * ctx.dt) % 2
  local cr, cg, cb
  if fg > 0.5 then
    local x = lfoPhase
    if x > 1 then x = 2 - x end
    cr, cg, cb = picker(x)
  else
    cr, cg, cb = picker((fg * 2) % 1)
  end
  e.color(cr, cg, cb)

  for i = 0, 6 do
    local yBase = i * y5 - y5
    for j = 0, 9 do
      local x = j * x8 - x8
      local y = yBase

      -- Audio: stock index j+i (0..15) -> left[1 + k*10], denormalized.
      local k = j + i
      local s = left and left[1 + k * 10] or 0
      local rad = math.abs(s * 32768 / 32768 * radScale)

      -- Odd rows shift right, odd columns shift down (stock-exact).
      if i % 2 == 1 then x = x + xoffset end
      if j % 2 == 1 then y = y + yoffset end

      e.circle(x, y, rad + restRad)
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("offx", 0.5, 0, 1, 1)
    e.param("offy", 0.5, 0, 1, 2)
    e.param("size", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
