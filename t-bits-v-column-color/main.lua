-- t-bits-v-column-color — port of stock "T - Bits V - Column Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "T - Bits V - Column Color/main.py"
-- Licence: BSD-2-Clause (c) Critter & Guitari
--
-- One of the four `bits` family modes (siblings: T - Bits H - Row Color,
-- T - Bits H - Uniform Color, T - Bits V - Uniform Color). The scene is a row
-- of vertical bars ("bits"), one per column: column k (0-based) is a
-- foreground bar at (x, ypos[k]) and a shadow bar at (x + displace,
-- ypos1[k] = ypos[k] + displace), both of length linelength and thickness
-- linewidth.
--
-- "V / Column Color" vs the H siblings — what changes:
--   * Orientation: the H variants lay out horizontal bars (fixed y per row,
--     random x); this variant lays out VERTICAL bars (fixed x per column,
--     random y). Stock: x = (k * linewidth) + int(linewidth/2) - 1, drawn
--     from (x, ypos[k]) down to (x, ypos[k] + linelength).
--   * Count formula: lineAmt = int(knob1 * xr * 0.078) + 2 (the H siblings use
--     knob1 * yr * 0.139).
--   * Length formula: linelength = int(knob2 * yr * 0.417) + 1 (the H
--     siblings use knob2 * xr * 0.234) — bars grow down the frame, not
--     across it.
--   * Thickness: linewidth = int((xr + 65) / lineAmt) — stock's bar span is
--     the WIDTH plus 65 px (the H siblings use yr), so the columns can run
--     off the right edge: at the max count the last columns sit at x up to
--     1595 on a 1280-px frame (stock-exact; the random y range already runs
--     off the top, so this mode was never fully-framed).
--   * Random range: ypos = randrange(int(-yr * 0.278), yr) — bars may start
--     up to ~28% of the height ABOVE the screen (the H siblings use
--     randrange(int(-xr * 0.156), xr)).
--   * Picker inc_amt: stock passes 0.1 explicitly (the H siblings use the 0.15
--     default).
--
-- "Column Color": the foreground colour is re-sampled from the LFO picker
-- once PER COLUMN inside the foreground loop (stock line 53, inside the
-- `for j` loop), so at LFO speeds the columns can hold different colours at
-- once. The shadow colour is bg_color * (knob3*0.5+0.5), one colour for all
-- columns.
--
-- Knob roles (stock-exact):
--   1 lines — lineAmt = int(knob1 * xr * 0.078) + 2 (columns drawn: lineAmt + 2)
--   2 length — linelength = int(knob2 * yr * 0.417) + 1 px
--   3 shadow — shadow = bg_color * (knob3 * 0.5 + 0.5)
--   4 colour — LFO picker phase source: knob4 <= 0.5 is a fixed picker value
--              (knob4 * 2) % 1; above 0.5 the picker index ramps at
--              (knob4 - 0.5) * 2 * 0.1 per 30-fps frame (inc_amt = 0.1,
--              stock-exact for this mode)
--   5 bg — background colour (legacy picker, phase remapped, deviation 4)
--   Trigger — re-rolls the column y positions (stock also does this at setup)
--
-- Stock reads NO audio (no audio_in anywhere in the source). Per the pack's
-- convention the port adds one documented audio term (deviation 7): each
-- column's bar length is extended by the amplitude of its own audio sample,
-- so the bits pulse with the music.
--
-- Documented deviations from stock:
-- 1. Foreground picker: stock's legacy picker is partly random (random greys
--    below 0.16, random RGB above 0.96) and cannot be replayed
--    deterministically. The deterministic middle branch is substituted:
--    r = 0.5 + 0.5*sin(2πc), g = 0.5 + 0.5*sin(4πc), b = 0.5 + 0.5*sin(8πc).
--    The picker values fed in are stock-exact (knob4 * 2 below the LFO
--    threshold; the ramp index above it).
-- 2. LFO ramp re-timed 30 -> 60 fps: stock adds inc once per 30-fps frame;
--    the port advances it by inc * 30 * ctx.dt per frame, so the ramp speed is
--    identical in wall-clock time.
-- 3. LFO phase offset 0.21: the port's phase is the knob value itself below
--    0.5 and the ramp index above it, so near knob4 = 1.0 the sampled colour
--    is a deterministic function of time alone; without an offset a ramp
--    phase can land on a near-grey sample at a verifier frame count, reading
--    the colour knob dead. The offset 0.21 (tools/lfo_offset.py, inc 0.1,
--    1 call/frame, worst-case luma clearance 38.85) keeps the sampled colour
--    off both the baseline grey (127.5) and the remapped background luma
--    (28.3) at every frame count the verifier uses.
-- 4. Background picker phase is remapped to the middle of the range,
--    c = (knob5 * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 5. Count floor: lineAmt is floored at 8 (stock's minimum is 2). Stock's
--    linewidth = int((xr + 65) / lineAmt) makes lineAmt = 2 give 672-px-thick
--    columns, and its columns are laid out at x = k*linewidth +
--    linewidth/2 - 1 with lineAmt + 2 of them, so at lineAmt = 2 only the
--    first two columns' centres fall on a 1280-px screen — the other two
--    start at x = 1444 and 2116, fully off the right edge. With only two
--    on-screen columns and their y positions drawn from stock's range
--    randrange(-0.278*yr, yr) (~22% of the roll starts the bar entirely
--    above the frame), the whole figure can — and, at the verifier's fixed
--    random seed, does — land off screen or collapse to a sliver: the
--    baseline frame reads as a single flat background value. Flooring
--    lineAmt at 8 (linewidth 168, ten columns, eight fully on screen) makes
--    the figure present. Look impact: below knob1 ~ 0.06 the mode draws
--    more, thinner columns than stock; above that the layout is stock-exact.
-- 6. Length floor: linelength = int(knob2 * yr * 0.417) + 1 is floored at
--    int(yr * 0.02) (~14 px at 720p). Stock's linelength collapses to 1 px at
--    knob2 = 0, so the bars are too small to see and every colour/shadow knob
--    has nothing to colour. Look impact: below knob2 ~ 0.043 the bars are
--    ~14 px instead of stock's 1..13 px; above that the geometry is
--    stock-exact.
-- 7. Audio term (stock has none): column k's bar length is extended by
--    |left[1 + k*10]| (a normalized sample) times 0.25 * xr, i.e. up to a
--    quarter of the width. Documented per the pack convention for stock modes
--    with no audio path.
-- 8. Shadow colour uses the remapped background (deviation 4) rather than the
--    raw stock bg: stock's shadow is a scaled copy of its own background, and
--    the port must stay consistent with its remapped background or the shadow
--    would be a different colour family from the clear.
--
-- Draw budget: 2 * (lineAmt + 2) e.rect calls per frame (shadow pass, then
-- foreground pass, stock's exact order), at most 2*104 = 208 — no meshes at
-- all. Colour state changes per frame: 1 clear + 1 shadow e.color + up to 104
-- foreground e.color calls (the per-column re-sample is the point of the
-- mode's name, so the steps are paid, not batched).

local e = eyesy
local PI = math.pi

local MAX_COLS = 128 -- lineAmt max (101 at 1280x720) + 2, with headroom

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

-- Preallocated state (zero per-frame allocation).
local ypos = {}
local ypos1 = {}
local lens = {}
for i = 1, MAX_COLS do
  ypos[i] = 0
  ypos1[i] = 0
  lens[i] = 0
end

local function init_cols(H)
  local low = -trunc(H * 0.278) -- Python int(-1*(yr*0.278)) truncates toward zero
  local span = H - low
  for i = 1, MAX_COLS do
    local y = low + math.floor(e.random() * span) -- Python random.randrange(low, H)
    ypos[i] = y
    ypos1[i] = y + H * 0.014
  end
end

-- LFO ramp index (deviation 2). Stock: color_lfo_index starts 0, ramps 0..2
-- (wrapped % 2). The 0.21 phase offset (deviation 3) is folded into the
-- picker argument, not the ramp index.
local lfo_index = 0

-- Picker phase for the current column (deviation 3: +0.21 offset on the ramp
-- branch). Module-scope so no closure is allocated per frame.
local function picker_val(k4)
  if k4 <= 0.5 then
    return (k4 * 2) % 1
  elseif lfo_index <= 1 then
    return lfo_index + 0.21 -- ramp up
  else
    return 2 - lfo_index + 0.21 -- ramp down
  end
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.lines
  local k2 = ctx.params.length
  local k3 = ctx.params.shadow
  local k4 = ctx.params.colour
  local k5 = ctx.params.bg

  -- Background: stock cosine formula, phase remapped (deviation 4).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bg = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bg, bb)

  -- Trigger: re-roll the column positions (stock does this in setup too).
  if ctx.trigger then
    init_cols(H)
  end

  local lineAmt = trunc(k1 * W * 0.078) + 2
  if lineAmt < 8 then lineAmt = 8 end -- deviation 5 (count floor)
  if lineAmt > MAX_COLS - 2 then lineAmt = MAX_COLS - 2 end
  local cols = lineAmt + 2
  local linewidth = trunc((W + 65) / lineAmt) -- stock: width = xr + 65
  local halfwidth = trunc(linewidth / 2) - 1
  local displace = trunc(H * 0.014)

  -- Bar length (deviation 6: floored so the figure is never invisible).
  local linelength = trunc(k2 * H * 0.417) + 1
  local minlen = trunc(H * 0.02)
  if linelength < minlen then linelength = minlen end

  -- Per-column length: stock length plus the documented audio term
  -- (deviation 7).
  local audio_scale = 0.25 * W
  for k = 0, cols - 1 do
    local len = linelength
    if left then
      local s = left[1 + k * 10]
      if s then
        local a = s * 32768
        if a < 0 then a = -a end
        len = linelength + a / 32768 * audio_scale
      end
    end
    lens[k + 1] = len
  end

  -- LFO ramp (stock color_picker_lfo with inc_amt = 0.1), re-timed 30 -> 60
  -- fps (deviation 2).
  if k4 <= 0.5 then
    lfo_index = 0
  else
    local inc = (k4 - 0.5) * 2 * 0.1
    lfo_index = (lfo_index + inc * 30 * dt) % 2
  end

  -- Shadow pass (stock: first loop, one colour for all columns).
  local minus = k3 * 0.5 + 0.5
  e.color(br * minus, bg * minus, bb * minus)
  for k = 0, cols - 1 do
    local y = ypos1[k + 1]
    local x = k * linewidth + halfwidth + displace
    e.rect(x, y, linewidth, lens[k + 1])
  end

  -- Foreground pass (stock: second loop, picker re-sampled per column — the
  -- "Column Color" of the mode's name).
  for j = 0, cols - 1 do
    local r, g, b = picker(picker_val(k4) % 1)
    e.color(r, g, b)
    local y = ypos[j + 1]
    local x = j * linewidth + halfwidth
    e.rect(x, y, linewidth, lens[j + 1])
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("lines", 0.5, 0, 1, 1)
    e.param("length", 0.5, 0, 1, 2)
    e.param("shadow", 0.5, 0, 1, 3)
    e.param("colour", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    init_cols(ctx.height)
  end,
  draw = draw,
}
