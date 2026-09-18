-- s-googly-eyes - port of stock "S - Googly Eyes"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Googly Eyes/main.py" (112 lines), against the stock
-- runtime `EYESY_OS/engines/python/eyesy.py` at 51cc186e.
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Scene (stock-exact): a "mouth" of 100 connected segments at y = yres*0.833,
-- each endpoint jittered by one audio sample and each segment drawn in its own
-- color_picker_lfo phase (so the mouth carries a colour ramp), and two googly
-- eyes at y = yres/3 - audio: a sclera disc of radius int(knob1*xr*0.098)+20 in
-- the mouth's last picker colour, plus a pupil disc of radius rad/2 displaced by
-- int((rad/2)*sin(audio20*0.0001)) / -int((rad/2)*cos(audio25*0.0001)) in the
-- fixed stock (245,200,255). Both eyes bounce on two LFOs - one for the
-- vertical roll, one for the horizontal slide.
--
-- Knob roles (stock-exact):
--   1 size        - mouth line width int(knob1*xr*0.098)+1 and eye radius
--                   int(knob1*xr*0.098)+20
--   2 mouth width - the quadratic spread int(xhalf+xhalf*i/99)*knob2*i/100 +
--                   (x720 - knob2*xhalf); it also shrinks the mouth audio
--                   divisor 500 - int(knob2*499)
--   3 speed       - eye-bounce LFO step sizes knob3*xr*0.023 (roll) and
--                   knob3*xr*0.031 (slide)
--   4 foreground  - stock color_picker_lfo(knob4), inc_amt 0.1
--   5 background  - stock color_picker_bg(knob5)
--   Trigger       - unused in stock (no random state); the port does not read
--                   it, so the verifier's trigger second chance cannot fire.
--
-- Randomness: stock imports `random` but never calls it - every value is a
-- function of the knobs, the audio ring and the LFO state. The port therefore
-- uses no e.random(), and replays are byte-identical by construction.
--
-- Documented deviations from stock:
-- 1. Palette. Stock's color_picker is legacy and partly random (random greys
--    for small values, random RGB above 0.96), and color_picker_lfo calls it
--    for every mouth segment. Randomness cannot be ported (replays must be
--    byte-identical), so the deterministic middle branch is substituted:
--    r = 0.5+0.5*sin(2*pi*c), g = 0.5+0.5*sin(4*pi*c), b = 0.5+0.5*sin(8*pi*c).
--    Look impact: a smooth cosine ramp along the mouth instead of grey/RGB
--    speckle. Stock's `color = color_picker(knob4)` before the mouth loop is
--    dead code (the loop's last call always overwrites it), so the sclera
--    colour comes from the LFO call, as in stock.
-- 2. The LFO's own semantics are stock-exact (eyesy.py color_picker_lfo): the
--    index advances by the *previous* call's inc, modulo 2, before the colour
--    is taken; the colour phase is index for index <= 1 and 2-index above; the
--    static branch (knob <= 0.5) returns picker((knob*2) % 1) and does not
--    update inc; above 0.5 inc becomes (knob-0.5)*0.2. The 30 -> 60 fps rule is
--    applied to the per-call step (halved), so the mode's 100 calls per frame
--    advance the index at stock's 3000 calls/s rate: per second the ramp runs
--    100 calls x 0.5*inc x 60 = 3000*inc, exactly stock's 100 x inc x 30. The
--    within-frame spread across the mouth is therefore half of stock's - the
--    gradient is finer, not absent - and the index keeps its stock initial 0.
--    No phase offset is needed: this mode samples the LFO per element (100
--    calls per frame), and at the knob4 = 1.0 probe the index at the last call
--    is 99*0.05 = 4.95 -> 0.95, so the sclera colour is picker(0.95)
--    (luma ~58), at least 30 luma units from both the baseline grey (127.5)
--    and the background (28.3), while the mouth itself carries five colour
--    ramps across its 100 segments (PORTING-LADDER 3.4).
-- 3. Background phase fold: c = (bg*0.7 + 0.15) % 1, the pack's luma
--    safeguard - the stock cosine formula returns pure white at bg = 1 and pure
--    black at 0, both outside the verifier's bounds. The formula itself is
--    unchanged.
-- 4. Audio. Stock's ring is 100 values at 100 Hz, +-32768; the platform buffer
--    is 1024 normalized samples, so stock index j maps to left[1 + j*10]
--    * 32768 (10-sample stride, index 1 the oldest sample of the window).
--    Every stock divisor is kept: 450 for audio_in[0]/[1] (the eye positions),
--    y640 = yr*0.889 (the mouth's y offset, from audio_in[2]), and
--    500 - int(knob2*499) (the per-segment jitter, from audio_in[i]; stock's own
--    divisor, 500 at knob2 = 0 down to 1 at knob2 = 1, where the jitter grows to
--    +-32768 px and the mouth leaves the frame exactly as stock's does). A
--    missing sample reads 0, as an all-zero ring does.
-- 5. Eye LFOs 30 -> 60 fps. Stock's LFO class clamps, flips direction and steps
--    once per call, twice per frame per LFO (roll1 is the first call, roll2 the
--    negated second). The port reproduces the class exactly - including that
--    the returned value may overshoot the bound by one step, as in stock - and
--    scales the step by 30 * ctx.dt per call, which is stock's 2 x 30 = 60
--    steps/s. The int() on the four offsets and the sign pairing are kept.
-- 6. Mouth as e.line strokes. pygame's 100-segment polyline becomes 100
--    e.line(x0, y0, x1, y1, linewidth) calls (the s-aquarium / s-bits-vertical
--    idiom). e.line takes a literal pixel width, so pygame's width-0-as-1 clamp
--    is reproduced with a 1 px floor (stock's width is already >= 1). The
--    per-segment e.color is issued only when the phase actually changes, which
--    is exact for both stock branches - one colour for the whole mouth in the
--    static branch, a real ramp above it - and keeps the baseline's
--    colour-change count at 2 (mouth, pupils) instead of 102, while the
--    knob4 > 0.5 branch issues the ramp stock itself asks for.
-- 7. Pupils. Stock's int(xrad) / -int(yrad) displacement is kept, including
--    Python int()'s truncation toward zero (int(xrad) is negative for xrad < 0);
--    the pupil radius rad/2 and the fixed (245,200,255) colour are stock-exact.
-- 8. No positional deviation. The mouth spans x in [0, xhalf] plus the audio
--    jitter, the eyes sit at 2*radrat + audio1 and x1116 - audio2, and every
--    excursion (LFO max xr*0.234375, pupil displacement, eye radius) stays
--    inside the 1280x720 frame at the baseline, mid and max knob values except
--    where stock itself leaves it (knob2 = 1's jitter, knob3's bounce at the
--    LFO extremes). Nothing is wrapped or clamped.

local e = eyesy
local PI = math.pi

local SEGS = 100 -- stock mouth: for i in range(0, 100)

-- Deterministic middle branch of the stock legacy picker (deviation 1).
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

-- Stock color_picker_lfo state (deviation 2): both start at 0 (eyesy.py
-- __init__) and the index advances by the *previous* call's inc (halved here
-- for 60 fps) before the colour phase is read.
local lfo_index = 0
local lfo_inc = 0

-- One stock color_picker_lfo call -> the picker phase (deviation 2).
local function lfo_call(k4)
  lfo_index = (lfo_index + lfo_inc * 0.5) % 2
  if k4 <= 0.5 then
    return (k4 * 2) % 1
  end
  lfo_inc = (k4 - 0.5) * 0.2
  if lfo_index <= 1 then return lfo_index end
  return 2 - lfo_index
end

-- Stock LFO class (deviation 5): clamp, flip, then step; the returned value may
-- overshoot the bound by one step, exactly as stock's does.
local function lfo_step(cur, dir, lo, hi, step)
  if cur >= hi then
    dir = -1
    cur = hi
  end
  if cur <= lo then
    dir = 1
    cur = lo
  end
  return cur + step * dir, dir
end

-- LFO state (deviation 5): current = 0, direction = 1, as stock's constructor.
local lfo1_cur, lfo1_dir = 0, 1
local lfo2_cur, lfo2_dir = 0, 1

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.size
  local k2 = ctx.params.mouthwidth
  local k3 = ctx.params.speed
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg, phase folded (deviation 3).
  local c = (k5 * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Stock constants, stock-exact (W = xr, H = yr).
  local xhalf = W * 0.5
  local x720 = W * 0.563
  local x1116 = W * 0.6875
  local y3d = H / 3
  local y600 = H * 0.833
  local y640 = H * 0.889
  local widthmod = W * 0.098
  local radrat = W * 0.098
  local step1mod = W * 0.023
  local step2mod = W * 0.031

  -- Eye LFO bounds: stock rewrites start/max every frame to these values, and
  -- the accumulator only ever moves between them.
  local l1lo, l1hi = W * -0.15625, W * 0.15625
  local l2lo, l2hi = W * -0.234375, W * 0.234375

  -- Mouth line width: stock int(knob1*widthmod)+1.
  local linewidth = trunc(k1 * widthmod) + 1

  -- Audio (deviation 4): stock index j -> left[1 + j*10] * 32768. A missing
  -- sample reads 0, as an all-zero ring does.
  local audio1 = (left and left[1] or 0) * 32768 / 450    -- audio_in[0]
  local audio2 = (left and left[11] or 0) * 32768 / 450   -- audio_in[1]
  local a20 = (left and left[201] or 0) * 32768           -- audio_in[20]
  local a25 = (left and left[251] or 0) * 32768           -- audio_in[25]

  -- Mouth: stock's 100 segments, in stock's order, each segment in its own
  -- color_picker_lfo colour (deviations 1, 2, 6). The y offset is recomputed by
  -- stock per segment from the same sample, so it is hoisted here.
  local mdiv = 500 - trunc(k2 * 499)
  local yoffset = y600 - (left and left[21] or 0) * 32768 / y640 -- audio_in[2]
  local xbase = x720 - k2 * xhalf
  local lx = xbase
  local ly = yoffset
  local lastPhase = nil
  for i = 0, SEGS - 1 do
    local phase = lfo_call(k4)
    if phase ~= lastPhase then
      local pr, pg, pb = picker(phase)
      e.color(pr, pg, pb)
      lastPhase = phase
    end
    local si = left and left[1 + i * 10]
    local auDio = (si or 0) * 32768 / mdiv
    local xoffset = trunc(xhalf + xhalf / 99 * i) * k2 * i / 100 + xbase
    local x1 = xoffset - auDio
    local y1 = yoffset + auDio
    if i == 0 then
      lx = xbase - auDio
      ly = y1
    end
    e.line(lx, ly, x1, y1, linewidth)
    lx, ly = x1, y1
  end

  -- Eyes. The current colour is stock's `color` - the last mouth call - and the
  -- sclera uses it (deviation 1).
  local rad = trunc(k1 * radrat) + 20
  local xpos1 = 2 * radrat + audio1
  local ypos1 = y3d - audio1
  local xpos2 = x1116 - audio2
  local ypos2 = y3d - audio2
  local half = rad / 2
  local pdx = trunc(half * math.sin(a20 * 0.0001))
  local pdy = trunc(half * math.cos(a25 * 0.0001))

  -- Eye LFOs: two calls each per frame, stock's clamp/flip order (deviation 5).
  local step1 = k3 * step1mod * 30 * dt
  local step2 = k3 * step2mod * 30 * dt
  lfo1_cur, lfo1_dir = lfo_step(lfo1_cur, lfo1_dir, l1lo, l1hi, step1)
  local roll1 = trunc(lfo1_cur)
  lfo1_cur, lfo1_dir = lfo_step(lfo1_cur, lfo1_dir, l1lo, l1hi, step1)
  local roll2 = -trunc(lfo1_cur)
  lfo2_cur, lfo2_dir = lfo_step(lfo2_cur, lfo2_dir, l2lo, l2hi, step2)
  local slide1 = trunc(lfo2_cur)
  lfo2_cur, lfo2_dir = lfo_step(lfo2_cur, lfo2_dir, l2lo, l2hi, step2)
  local slide2 = -trunc(lfo2_cur)

  -- Sclera in stock's `color` (no colour change), then the fixed-colour pupils.
  e.circle(xpos1 + slide1, ypos1 + roll1, rad)
  e.circle(xpos2 + slide2, ypos2 + roll2, rad)
  e.color(245 / 255, 200 / 255, 1)
  e.circle(xpos1 + pdx + slide1, ypos1 - pdy + roll1, half)
  e.circle(xpos2 + pdx + slide2, ypos2 - pdy + roll2, half)
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("size", 0.5, 0, 1, 1)
    e.param("mouthwidth", 0.5, 0, 1, 2)
    e.param("speed", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
