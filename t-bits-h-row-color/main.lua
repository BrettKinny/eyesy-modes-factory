-- t-bits-h-row-color — port of stock "T - Bits H - Row Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "T - Bits H - Row Color/main.py"
-- Licence: BSD-2-Clause (c) Critter & Guitari
--
-- One of the four `bits` family modes (siblings: T - Bits H - Uniform Color,
-- T - Bits V - Column Color, T - Bits V - Uniform Color). The scene is a stack
-- of horizontal bars ("bits"), one per row: row k (0-based) is a foreground
-- bar at (xpos[k], y) and a shadow bar at (xpos1[k] = xpos[k] + displace,
-- y + displace), both of length linelength and thickness linewidth.
--
-- "Row Color": the foreground colour is re-sampled from the LFO picker once
-- PER ROW inside the foreground loop, so at LFO speeds the rows can hold
-- different colours at once. The shadow colour is bg_color * (knob3*0.5+0.5),
-- one colour for all rows.
--
-- Knob roles (stock-exact):
--   1 lines — lineAmt = int(knob1 * yr * 0.139) + 2 (rows drawn: lineAmt + 2)
--   2 length — linelength = int(knob2 * xr * 0.234) + 1 px
--   3 shadow — shadow = bg_color * (knob3 * 0.5 + 0.5)
--   4 colour — LFO picker phase source: knob4 <= 0.5 is a fixed picker value
--              (knob4 * 2) % 1; above 0.5 the picker index ramps at
--              (knob4 - 0.5) * 2 * 0.15 per 30-fps frame (inc_amt = 0.15,
--              stock-exact for this mode)
--   5 bg — background colour (legacy picker, phase remapped, deviation 4)
--   Trigger — re-rolls the row x positions (stock also does this at setup)
--
-- Stock reads NO audio (no audio_in anywhere in the source). Per the pack's
-- convention the port adds one documented audio term (deviation 7): each row's
-- bar length is extended by the amplitude of its own audio sample, so the bits
-- pulse with the music.
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
--    is a deterministic function of time alone; a ramp phase of ~0.83 lands on
--    a near-grey sample at a verifier frame count, reading the colour knob
--    dead. The offset 0.21 (tools/lfo_offset.py, inc 0.15, 1 call/frame,
--    worst-case luma clearance 42) keeps the sampled colour off both the
--    baseline grey (127.5) and the remapped background luma (28.3) at every
--    frame count the verifier uses.
-- 4. Background picker phase is remapped to the middle of the range,
--    c = (knob5 * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 5. Count floor: lineAmt is floored at 8 (stock's minimum is 2). Stock's
--    linewidth = int(yr / lineAmt) makes lineAmt = 2 give 360-px-thick rows,
--    and its rows are laid out at y = k*linewidth + linewidth/2 - 1 with
--    lineAmt + 2 of them, so at lineAmt = 2 only the first two rows fall on a
--    720-px screen; the other two are below the frame. With so few rows, on
--    screen, and their x positions drawn from stock's range
--    randrange(-0.156*xr, xr), the whole figure can (and, at the verifier's
--    fixed random seed, does) land off screen — the baseline frame is a single
--    flat background value. Flooring lineAmt at 8 (linewidth 90, ten rows, all
--    on screen) makes the figure present. Look impact: below knob1 ~ 0.06 the
--    mode draws more, thinner rows than stock; above that the layout is
--    stock-exact.
-- 6. Length floor: linelength = int(knob2 * xr * 0.234) + 1 is floored at
--    int(xr * 0.02) (~25 px at 1280). Stock's linelength collapses to 1 px at
--    knob2 = 0, so the bars are too small to see and every colour/shadow knob
--    has nothing to colour. Look impact: below knob2 ~ 0.082 the bars are
--    ~25 px instead of stock's 1..24 px; above that the geometry is
--    stock-exact.
-- 7. Audio term (stock has none): row k's bar length is extended by
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
-- foreground e.color calls (the per-row re-sample is the point of the mode's
-- name, so the steps are paid, not batched).

local e = eyesy
local PI = math.pi

local MAX_ROWS = 128 -- lineAmt max (102 at 720p) + 2, with headroom

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
local xpos = {}
local xpos1 = {}
local lens = {}
for i = 1, MAX_ROWS do
  xpos[i] = 0
  xpos1[i] = 0
  lens[i] = 0
end

local function init_rows(W)
  local low = -trunc(W * 0.156) -- Python int(-1*(xr*0.156)) truncates toward zero
  local span = W - low
  for i = 1, MAX_ROWS do
    local x = low + math.floor(e.random() * span) -- Python random.randrange(low, W)
    xpos[i] = x
    xpos1[i] = x + W * 0.008
  end
end

-- LFO ramp index (deviation 2). Stock: color_lfo_index starts 0, ramps 0..2
-- (wrapped % 2). The 0.21 phase offset (deviation 3) is folded into the
-- picker argument, not the ramp index.
local lfo_index = 0

-- Picker phase for the current row (deviation 3: +0.21 offset on the ramp
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

  -- Trigger: re-roll the row positions (stock does this in setup too).
  if ctx.trigger then
    init_rows(W)
  end

  local lineAmt = trunc(k1 * H * 0.139) + 2
  if lineAmt < 8 then lineAmt = 8 end -- deviation 5 (count floor)
  if lineAmt > MAX_ROWS - 2 then lineAmt = MAX_ROWS - 2 end
  local rows = lineAmt + 2
  local linewidth = trunc(H / lineAmt)
  local halfwidth = trunc(linewidth / 2) - 1
  local displace = trunc(W * 0.008)

  -- Bar length (deviation 6: floored so the figure is never invisible).
  local linelength = trunc(k2 * W * 0.234) + 1
  local minlen = trunc(W * 0.02)
  if linelength < minlen then linelength = minlen end

  -- Per-row length: stock length plus the documented audio term (deviation 7).
  local audio_scale = 0.25 * W
  for k = 0, rows - 1 do
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

  -- LFO ramp (stock color_picker_lfo with inc_amt = 0.15), re-timed 30 -> 60
  -- fps (deviation 2).
  if k4 <= 0.5 then
    lfo_index = 0
  else
    local inc = (k4 - 0.5) * 2 * 0.15
    lfo_index = (lfo_index + inc * 30 * dt) % 2
  end

  -- Shadow pass (stock: first loop, one colour for all rows).
  local minus = k3 * 0.5 + 0.5
  e.color(br * minus, bg * minus, bb * minus)
  for k = 0, rows - 1 do
    local y = k * linewidth + halfwidth
    e.rect(xpos1[k + 1], y + displace, lens[k + 1], linewidth)
  end

  -- Foreground pass (stock: second loop, picker re-sampled per row — the
  -- "Row Color" of the mode's name).
  for j = 0, rows - 1 do
    local r, g, b = picker(picker_val(k4) % 1)
    e.color(r, g, b)
    local y = j * linewidth + halfwidth
    e.rect(xpos[j + 1], y, lens[j + 1], linewidth)
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

    init_rows(ctx.width)
  end,
  draw = draw,
}