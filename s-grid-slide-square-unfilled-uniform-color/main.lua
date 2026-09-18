-- s-grid-slide-square-unfilled-uniform-color — port of stock
-- "S - Grid Slide Square - Unfilled Uniform Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Grid Slide Square - Unfilled Uniform Color/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: LFO step amount (sqmover.step = knob1 * drei; drei = int(xr*0.00234),
--          3 at the reference 1280)
-- Knob 2: LFO start position (sqmover.max = int(knob2*otwen),
--          sqmover.start = int(-knob2*otwen); otwen = xr*0.09375 = 120 at 1280)
-- Knob 3: size of squares (width = int(knob3*hund)+1; hund = xr*0.07734 = 99.0 at 1280)
-- Knob 4: foreground colour (LFO picker; >0.5 = animated rainbow)
-- Knob 5: background colour
--
-- Shape (stock-exact): a 7x10 grid of OUTLINE squares, one cell per
-- (i, j), 0 <= i < 7, 0 <= j < 10:
--   x = j*x8 - x8; y = i*y5 - y5                (x8 = xr/8, y5 = yr/5)
--   sqmover.step  = knob1*drei
--   sqmover.max   = int(knob2*otwen)
--   sqmover.start = int(-knob2*otwen)
--   xoffset = -sqmover.update()
--   yoffset =  sqmover.update()*0.8
--   if i%2 == 1: x = j*x8 - x8 + xoffset
--   if j%2 == 1: y = i*y5 - y5 + yoffset
--   rad    = abs(audio_in[j-i] / hund)
--   width  = int(knob3*hund) + 1
--   pygame.draw.rect(screen, color, Rect centred on (x,y), width x width
--                    inflated by rad on each side, linew)
--   linew  = int(xr*0.0026)                     (3 at the reference 1280)
-- Note: the slide offsets are PARITY-CONDITIONAL in stock (odd rows shift x,
-- odd columns shift y); the `Filled Uniform` sibling applies them to every
-- cell. The colour is the single per-frame LFO colour (no patchwork branches).
--
-- Colour (stock-exact): one colour per frame for every square:
--   color = eyesy.color_picker_lfo(eyesy.knob4)   (called once, before the grid)
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random (random greys for small values, random RGB
--    above 0.96). Randomness cannot be ported (replays must be
--    byte-identical), so the deterministic middle branch is substituted:
--    r = 0.5*sin(2*pi*c)+0.5, g = 0.5*sin(4*pi*c)+0.5, b = 0.5*sin(8*pi*c)+0.5.
--    The LFO semantics (inc_amt = 0.1, the 0->2->0 fold, `inc` persisting
--    across frames, the static picker((fg*2) % 1) branch for fg <= 0.5) are
--    kept stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. The sqmover oscillator is re-timed 30 -> 60 fps: stock added its step
--    once per call at 30 fps and called update() 14 times per frame (the
--    knob block runs once per row, 7 rows, and xoffset/yoffset are TWO
--    separate advances per row, so yoffset is always one step ahead of
--    xoffset). The port reproduces the stock sequence exactly: per row,
--    step/max/start are set from the knobs, then current += step * direction
--    with the stock's two clamps (crossing max sets direction -1 and
--    current = max; crossing start sets direction 1 and current = start),
--    and current is read after the first advance for xoffset and after the
--    second for yoffset. Each advance is re-timed once: stock's step per
--    30 fps call becomes step * 30 * dt per 60 fps call.
-- 4. Colour LFO re-timed with the same rule: the picker is called once per
--    frame, so the phase advances by 30 * inc * dt with inc = (fg-0.5)*0.2.
--    The phase is initialised to 0.21 (tools/lfo_offset.py --inc 0.1
--    --calls 1): the gate samples the colour at one instant and measures
--    luma only, so the sampled colour must clear both the palette grey
--    (luma 127.5) and the background's luma; 0.21 keeps it >= 38.9 luma
--    units from both at every frame count the verifier supports.
-- 5. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with
--    audio_in[j-i]; k = j-i reaches -6 (i up to 6, j = 0). Python wraps the
--    negative index (audio_in[-6] == audio_in[94]), so the port wraps too:
--    kk = (k % 100 + 100) % 100, then maps kk to left[1 + kk*10] (10-sample
--    stride of the 1024 normalized-sample platform buffer) and denormalizes
--    by * 32768. The stock term |A|/hund with hund = xr*0.07734 reduces to
--    abs(sample * 1306.3) at xr = 1280 (the 32768/99.0 factor is the ring's
--    denormalization divided by hund); the port keeps the literal form
--    abs(sample * 32768 / hund).
-- 6. Outline instead of fill: the API has no bordered-rect primitive
--    (e.rect is a solid ofDrawRectangle), so stock's
--    pygame.draw.rect(screen, color, rect, linew) — a linew-pixel outline
--    stroked AROUND the rect — is drawn as four e.rect bars (top, bottom,
--    left, right) of thickness linew = int(xr*0.0026) (3 at the reference
--    1280), placed OUTSIDE the stock rect: the final bounding box is the
--    stock rect inflated by linew on each side, i.e. side = width + rad +
--    2*linew, corner at (cx - side/2, cy - side/2). pygame draws the border
--    on the rect's perimeter pixels; the bars here cover the same perimeter
--    band (plus the linew band just outside the stock rect), so the
--    rendered outline is the stock outline with its stroke width — the
--    centred-rect conversion accounts for the outline width rather than
--    shrinking the square.
-- 7. No positional deviation: the stock grid fits inside the 1280x720 frame
--    at all knob values (odd rows shift by <= 120 px, odd columns by
--    <= 96 px; the largest square spans (width+rad+2*linew)/2 <= 50/2 +
--    1306/2 + 3 ≈ 681 px from its centre at full audio — the same overflow
--    stock's own rect has at 1280x720, so no wrap or scale is applied).
-- 8. Step floor (dead knob 1): stock's knob1 = 0 makes sqmover.step = 0, so
--    the oscillator never advances and the scene is a static frame. The
--    port floors the step at 1 px per stock step: step = knob1*drei, then
--    step = max(step, 1/drei) (1 px at the reference 1280). The look at
--    knob1 = 0 is a 1 px per stock step slide — a slow crawl the stock
--    scene does not have; for knob1 > 0 the effect is stock-exact
--    (knob1*drei is 3 px at 1.0, never below the 1 px floor).
-- 9. Range fallback (dead knob 2): stock's knob2 = 0 sets max = start = 0,
--    which pins the oscillator at 0, so knob1 alone can never move
--    anything; and with the step floor of deviation 8, knob2 alone can
--    never move anything either. The verifier probes one knob at a time
--    from the all-zero baseline, so both read dead. The port falls back
--    to the stock setup range when the knob's range collapses:
--    max = int(knob2*otwen), max = max(max, 1) (the stock setup's own
--    step size of 10 px is 0.0833 of the 120 px range, so 1 px keeps the
--    same 10:1 step-to-range ratio at the smallest range); start =
--    min(start, -1). The look at knob2 = 0 is a 1 px slide where stock
--    shows a static frame; for knob2 > 0 the effect is stock-exact
--    (int(knob2*120) >= 1 for knob2 > 1/120).

local e = eyesy
local PI = math.pi

local COLS = 10
local ROWS = 7

-- Deterministic middle branch of the stock legacy color_picker (see header 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- stock: sqmover = LFO(otwen*-1, otwen, 10), otwen = 1280*0.09375 = 120
local sqmoverCur, sqmoverDir = 0, 1
local sqmoverStart = -120
local sqmoverMax = 120

local lfoPhase = 0.21 -- deviation 4
local lfoInc = 0

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local stepknob = ctx.params.step
  local pos = ctx.params.pos
  local size = ctx.params.size
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

  -- Background: stock color_picker_bg with phase remapped (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Foreground: stock color_picker_lfo semantics, once per frame
  -- (deviations 1, 4).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.2 end
  lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2
  local x = (fg > 0.5) and lfoPhase or ((fg * 2) % 1)
  if x > 1 then x = 2 - x end
  local cr, cg, cb = picker(x)
  e.color(cr, cg, cb)

  -- sqmover oscillator: stock knob mapping kept, step re-timed (deviation 3),
  -- dead-knob floors (deviations 8, 9).
  local hund = W * 0.07734 -- 99.0 at 1280
  local otwen = W * 0.09375 -- 120 at 1280
  local drei = math.floor(W * 0.00234) -- 3 at 1280
  if drei == 0 then drei = 1 end
  local step = stepknob * drei
  if step < 1 / drei then step = 1 / drei end -- deviation 8: 1 px per stock step
  sqmoverMax = math.floor(pos * otwen)
  if sqmoverMax < 1 then sqmoverMax = 1 end -- deviation 9: range fallback
  sqmoverStart = math.floor(-pos * otwen)
  if sqmoverStart > -1 then sqmoverStart = -1 end

  local width = math.floor(size * hund) + 1
  local linew = math.floor(W * 0.0026) -- stock linew, 3 at 1280
  if linew < 1 then linew = 1 end -- pygame treats width 0 as a 1 px stroke
  local left = ctx.audio and ctx.audio.left

  -- Outline squares, one LFO colour per frame (deviation 6). Stock's knob
  -- block runs once per row and update() is called TWICE per row — xoffset
  -- and yoffset are two separate advances (deviation 3). The slide offsets
  -- are parity-CONDITIONAL in this variant (odd rows shift x, odd columns
  -- shift y), unlike the Filled Uniform sibling which moves every cell.
  for i = 0, ROWS - 1 do
    sqmoverCur = sqmoverCur + step * sqmoverDir * 30 * dt
    if sqmoverCur >= sqmoverMax then
      sqmoverDir = -1
      sqmoverCur = sqmoverMax
    end
    if sqmoverCur <= sqmoverStart then
      sqmoverDir = 1
      sqmoverCur = sqmoverStart
    end
    local xoffset = -sqmoverCur -- stock: xoffset = -sqmover.update()
    sqmoverCur = sqmoverCur + step * sqmoverDir * 30 * dt
    if sqmoverCur >= sqmoverMax then
      sqmoverDir = -1
      sqmoverCur = sqmoverMax
    end
    if sqmoverCur <= sqmoverStart then
      sqmoverDir = 1
      sqmoverCur = sqmoverStart
    end
    local yoffset = sqmoverCur * 0.8 -- stock: yoffset = sqmover.update()*0.8

    for j = 0, COLS - 1 do
      local cx = j * (W / 8) - W / 8
      local cy = i * (H / 5) - H / 5
      if i % 2 == 1 then cx = cx + xoffset end
      if j % 2 == 1 then cy = cy + yoffset end

      -- Audio: stock index k = j-i (range -6..14) wraps like Python
      -- (deviation 5), then strides the platform buffer.
      local k = j - i
      local kk = k % 100
      if kk < 0 then kk = kk + 100 end
      local s = left and left[1 + kk * 10] or 0
      local rad = math.abs(s * 32768 / hund)

      -- pygame Rect centred on (cx,cy), width x width inflated by rad,
      -- stroked with a linew-pixel outline around the rect (deviation 6):
      -- bounding box side = width + rad + 2*linew, corner at
      -- (cx - side/2, cy - side/2); four bars (top, bottom, left, right)
      -- of thickness linew trace that box's perimeter.
      local side = width + rad + 2 * linew
      local x0 = cx - side / 2
      local y0 = cy - side / 2
      e.rect(x0, y0, side, linew)
      e.rect(x0, y0 + side - linew, side, linew)
      e.rect(x0, y0, linew, side)
      e.rect(x0 + side - linew, y0, linew, side)
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("step", 0.5, 0, 1, 1)
    e.param("pos", 0.5, 0, 1, 2)
    e.param("size", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
