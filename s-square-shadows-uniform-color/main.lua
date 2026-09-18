-- s-square-shadows-uniform-color — port of EYESY OSv3 stock mode "S - Square Shadows - Uniform Color".
--
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Square Shadows - Uniform Color/main.py", license BSD-2-Clause, (c) 2025 Critter &
-- Guitari. Renders 25 vertical square blocks stacked vertically (y = i * 28.94 for i = 0..24),
-- each horizontally positioned at x = floor(posx * 1280) + (audio_sample / 35), where the audio
-- sample is read from a 1024-sample normalized window at index 1 + i * 40. Each block is a
-- squaresize x squaresize rectangle (squaresize = max(16, floor(size * 125.44) + 1)) drawn in a
-- foreground color, with a black shadow copy offset diagonally by shad = 25.6 - shadow * 51.2
-- pixels behind it. The background is a deterministic color derived from the bg knob.
--
-- Knob roles (stock-exact):
--   1 size — square size (16 to 126 px)
--   2 shadow — shadow offset (0 to 51.2 px diagonal)
--   3 posx — X position (stock comment says Y but code moves x)
--   4 fg — foreground color (LFO phase)
--   5 bg — background color
--
-- Documented deviations:
-- 1. Deterministic palette: legacy picker is partly random; use deterministic middle branch
--    (r = 0.5+0.5*sin(2*pi*c), g = 0.5+0.5*sin(4*pi*c), b = 0.5+0.5*sin(8*pi*c)) for byte-identical replays.
-- 2. Background phase remap: c = (bg * 0.7 + 0.15) % 1 to avoid pure white/black extremes.
-- 3. LFO re-timed 30→60 fps, stock-exact semantics: stock color_picker_lfo is
--    static for knob <= 0.5 (picker((knob*2) % 1), the ramp index unused) and
--    ramps index 0→2→0 by inc = (knob - 0.5) * 2 * 0.1 per call above 0.5 at
--    30 fps (25 calls/frame). The ramp index and inc persist across frames;
--    here the index advances once per frame by 25 * 30 * inc * ctx.dt (the
--    stock per-second rate, re-timed) and each square keeps the per-call
--    i*inc step. fg = 0.5 reads picker(1.0) = the palette grey, byte-identical
--    to the baseline (fg = 0 → picker(0)), so the knob is live via the max
--    probe only — stock-exact, not a deviation.
-- 4. Audio stride: stock index j = i*4 maps to left[1 + j*10] = left[1 + i*40], denormalized by *32768,
--    then divided by 35.
-- 5. 16 px minimum square size floor: stock baseline at size=0 is 1x1 px dots
--    (~50 lit pixels, a flat frame the gate cannot see). An 8 px floor is
--    still too small for the colour knob to register: 25 squares of 8x8 is
--    ~1600 lit pixels, so a colour change moves ~0.0017 of the frame at best,
--    and with the shadows and grey-on-grey squares the measured fraction was
--    0.0008, under the 0.0008 gate. 16 px gives ~6400 lit pixels and ~0.007
--    for the same change; size still scales 16 → 126 px.

local e = eyesy
local PI = math.pi

-- Deterministic middle branch of the legacy picker.
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Stock module globals (the LFO ramp index and its per-call step persist
-- across frames exactly as stock's color_lfo_index / color_lfo_inc do).
local lfo_phase = 0
local lfo_inc = 0

local function draw(ctx)
  local size = ctx.params.size
  local shadow = ctx.params.shadow
  local posx = ctx.params.posx
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  -- Background: stock color_picker_bg, exact formula, with the documented phase remap.
  local c = (bg * 0.7 + 0.15) % 1
  local r = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local g = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local b = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(r, g, b)

  -- LFO: stock color_picker_lfo semantics (deviation 3). fg <= 0.5 returns a
  -- static colour, picker((fg*2) % 1); above 0.5 the ramp advances by
  -- inc = (fg - 0.5) * 2 * 0.1 per call at 30 fps (25 calls/frame). Here the
  -- ramp index advances once per frame by 25 * 30 * inc * ctx.dt (the stock
  -- per-second rate, re-timed); inc persists across frames as stock does.
  if fg > 0.5 then lfo_inc = (fg - 0.5) * 2 * 0.1 end
  lfo_phase = (lfo_phase + 750 * lfo_inc * dt) % 2

  -- Per-square constants (deviation 5: 16 px legibility floor).
  local squaresize = math.max(16, math.floor(size * 125.44) + 1)
  local shad = 25.6 - shadow * 2 * 25.6
  local base_x = math.floor(posx * 1280)

  -- Draw 25 squares.
  for i = 0, 24 do
    local y = i * 28.94
    local A = (left and left[1 + i * 40] or 0) * 32768
    local x = base_x + (A / 35)

    -- Shadow square (black).
    e.color(0, 0, 0)
    e.line(x + shad, y + shad, x + shad, y + squaresize, squaresize)

    -- Foreground square: static for fg <= 0.5, otherwise the stock LFO
    -- ramp (phase + i*inc) folded 0→2→0, then the deterministic palette.
    local p
    if fg > 0.5 then
      p = (lfo_phase + i * lfo_inc) % 2
      if p > 1 then p = 2 - p end
    else
      p = (fg * 2) % 1
    end
    local fr, fg_c, fb = picker(p)
    e.color(fr, fg_c, fb)
    e.line(x, y, x, y + squaresize, squaresize)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("size", 0.5, 0, 1, 1)
    e.param("shadow", 0.5, 0, 1, 2)
    e.param("posx", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}