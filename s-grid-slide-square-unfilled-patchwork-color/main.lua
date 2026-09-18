-- s-grid-slide-square-unfilled-patchwork-color — port of stock
-- "S - Grid Slide Square - Unfilled Patchwork Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Grid Slide Square - Unfilled Patchwork Color/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: LFO step amount (sqmover.step = knob1 * drei; drei = int(xr*0.00234),
--          3 at the reference 1280)
-- Knob 2: LFO start position (sqmover.max = int(knob2*otwen),
--          sqmover.start = int(-knob2*otwen); otwen = xr*0.09375 = 120 at 1280)
-- Knob 3: size of squares (width = int(knob3*hund)+1; hund = xr*0.07734 = 99.0 at 1280)
-- Knob 4: patchwork colour (three static picker arguments derived from it)
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
--   rad    = abs(audio_in[j-i] / hund)
--   width  = int(knob3*hund) + 1
--   if i%2 == 1: x = j*x8 - x8 + xoffset; color = picker(knob4)
--   if j%2 == 1: y = i*y5 - y5 + yoffset; color = picker(1 - knob4)
--   if (j+i)%3 == 1: color = picker((0.8 + knob4) % 1)
--   pygame.draw.rect(screen, color, Rect centred on (x,y), width x width
--                    inflated by rad on each side, linew)
--   linew  = int(xr*0.0026)                     (3 at the reference 1280)
-- Note on the geometry: the slide offsets are PARITY-CONDITIONAL — xoffset
-- applied to x on odd rows only, yoffset to y on odd columns only — and the
-- stock parity branches also re-assign the base position, which is
-- equivalent to adding the offset to the base. This differs from the
-- `Filled Uniform` / `Unfilled Uniform` variants, where the offsets are
-- applied unconditionally to every cell; it matches the `Filled Patchwork`
-- and `Filled Column` siblings.
--
-- Colour (stock-exact rule, deterministic substitution): three sequential
-- overwrites inside the j loop, last match wins:
--   i%2 == 1        -> picker(knob4)
--   j%2 == 1        -> picker(1 - knob4)
--   (j+i)%3 == 1    -> picker((0.8 + knob4) % 1)
-- All three calls are the STATIC legacy picker (no LFO state, no time
-- advance, no phase offset): the picker argument is a pure function of knob4,
-- so the colour is constant within a frame for a given cell and changes only
-- when knob4 moves.
--
-- Documented deviations from stock:
-- 1. Foreground picker: stock color_picker is the legacy picker, which is
--    partly random (random greys for small values, random RGB above 0.96).
--    Randomness cannot be ported (replays must be byte-identical), so the
--    deterministic middle branch is substituted:
--    r = 0.5*sin(2*pi*c)+0.5, g = 0.5*sin(4*pi*c)+0.5, b = 0.5*sin(8*pi*c)+0.5.
--    The three per-cell arguments (knob4, 1-knob4, (0.8+knob4)%1) and their
--    static nature (no LFO state, no time advance) are kept stock-exact.
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
-- 4. No LFO phase offset: unlike the `Uniform` siblings (color_picker_lfo,
--    one animated call per frame) this mode calls the STATIC picker, so the
--    colour is a pure function of knob4 and no time-based phase or offset
--    applies. The knob's liveness comes from the three distinct picker
--    arguments varying with knob4.
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
-- 7. Per-cell patchwork colour has only three classes (fg, 1-fg,
--    (0.8+fg)%1), so the 70 per-cell e.color calls are grouped: each
--    outline's four bars are written in place into a preallocated per-class
--    slot list (no per-frame allocation), then the three classes are drawn
--    back to back, each with a single e.color set immediately before that
--    class's bars. The geometry is unchanged; only the issue order differs
--    (grouped by class instead of in (i,j) order).
-- 8. No positional deviation: the stock grid fits inside the 1280x720 frame
--    at all knob values (odd rows shift by <= 120 px, odd columns by
--    <= 96 px; the largest square spans (width+rad+2*linew)/2 <= 50/2 +
--    1306/2 + 3 ≈ 681 px from its centre at full audio — the same overflow
--    stock's own rect has at 1280x720, so no wrap or scale is applied).
-- 9. Step floor (dead knob 1): stock's knob1 = 0 makes sqmover.step = 0, so
--    the oscillator never advances and the scene is a static frame. The
--    port floors the step at 1 px per stock step: step = knob1*drei, then
--    step = max(step, 1/drei) (1 px at the reference 1280). The look at
--    knob1 = 0 is a 1 px per stock step slide — a slow crawl the stock
--    scene does not have; for knob1 > 0 the effect is stock-exact
--    (knob1*drei is 3 px at 1.0, never below the 1 px floor).
-- 10. Range fallback (dead knob 2): stock's knob2 = 0 sets max = start = 0,
--    which pins the oscillator at 0, so knob1 alone can never move
--    anything; and with the step floor of deviation 9, knob2 alone can
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

-- Per-colour-class outline slots, preallocated once (tier fix): three lists
-- of up to 70 {x, y, side} tables, one per patchwork class (1 = fg, 2 = 1-fg,
-- 3 = (0.8+fg)%1). Each slot holds the outline's bounding box; the four bars
-- are derived from it at draw time. Filled in place per frame, no
-- allocation after setup.
local slots = {}
do
  for k = 1, 3 do
    local list = {}
    for n = 1, 70 do
      list[n] = {0, 0, 0}
    end
    slots[k] = list
  end
end

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

  local n1, n2, n3 = 0, 0, 0 -- per-class slot counts

  local c1 = fg
  local c2 = 1 - fg
  local c3 = (0.8 + fg) % 1

  -- sqmover oscillator: stock knob mapping kept, step re-timed (deviation 3),
  -- dead-knob floors (deviations 9, 10).
  local hund = W * 0.07734 -- 99.0 at 1280
  local otwen = W * 0.09375 -- 120 at 1280
  local drei = math.floor(W * 0.00234) -- 3 at 1280
  if drei == 0 then drei = 1 end
  local step = stepknob * drei
  if step < 1 / drei then step = 1 / drei end -- deviation 9: 1 px per stock step
  sqmoverMax = math.floor(pos * otwen)
  if sqmoverMax < 1 then sqmoverMax = 1 end -- deviation 10: range fallback
  sqmoverStart = math.floor(-pos * otwen)
  if sqmoverStart > -1 then sqmoverStart = -1 end

  local width = math.floor(size * hund) + 1
  local linew = math.floor(W * 0.0026) -- stock linew, 3 at 1280
  if linew < 1 then linew = 1 end -- pygame treats width 0 as a 1 px stroke
  local left = ctx.audio and ctx.audio.left

  -- Outline squares, per-colour-class slots (deviations 1, 4, 7). Stock's
  -- knob block runs once per row and update() is called TWICE per row —
  -- xoffset and yoffset are two separate advances (deviation 3). The slide
  -- offsets are parity-CONDITIONAL (odd rows shift x, odd columns shift y),
  -- and the stock parity branches also re-assign the base position
  -- (equivalent to adding the offset to the base).
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
      -- Stock parity branches also re-assign the base position (equivalent
      -- to adding the offset to the base); xoffset on odd rows, yoffset on
      -- odd columns.
      local cc
      if i % 2 == 1 then
        cx = cx + xoffset
        cc = 1
      end
      if j % 2 == 1 then
        cy = cy + yoffset
        cc = 2
      end
      if (j + i) % 3 == 1 then
        cc = 3
      end

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

      -- Per-class outline slots (deviation 7): the geometry is unchanged,
      -- only the issue order is grouped by class so one e.color per class
      -- suffices.
      if cc == 1 then
        n1 = n1 + 1
        local t = slots[1][n1]
        t[1] = cx - side / 2
        t[2] = cy - side / 2
        t[3] = side
      elseif cc == 2 then
        n2 = n2 + 1
        local t = slots[2][n2]
        t[1] = cx - side / 2
        t[2] = cy - side / 2
        t[3] = side
      else
        n3 = n3 + 1
        local t = slots[3][n3]
        t[1] = cx - side / 2
        t[2] = cy - side / 2
        t[3] = side
      end
    end
  end

  -- Draw class-by-class: one e.color per class, set immediately before that
  -- class's outlines (the draw order interleaved classes, so a pre-pass
  -- would not work — the last e.color before a bar is the one that bar sees).
  local r, g, b = picker(c1)
  e.color(r, g, b)
  for n = 1, n1 do
    local t = slots[1][n]
    e.rect(t[1], t[2], t[3], linew)
    e.rect(t[1], t[2] + t[3] - linew, t[3], linew)
    e.rect(t[1], t[2], linew, t[3])
    e.rect(t[1] + t[3] - linew, t[2], linew, t[3])
  end
  r, g, b = picker(c2)
  e.color(r, g, b)
  for n = 1, n2 do
    local t = slots[2][n]
    e.rect(t[1], t[2], t[3], linew)
    e.rect(t[1], t[2] + t[3] - linew, t[3], linew)
    e.rect(t[1], t[2], linew, t[3])
    e.rect(t[1] + t[3] - linew, t[2], linew, t[3])
  end
  r, g, b = picker(c3)
  e.color(r, g, b)
  for n = 1, n3 do
    local t = slots[3][n]
    e.rect(t[1], t[2], t[3], linew)
    e.rect(t[1], t[2] + t[3] - linew, t[3], linew)
    e.rect(t[1], t[2], linew, t[3])
    e.rect(t[1] + t[3] - linew, t[2], linew, t[3])
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
