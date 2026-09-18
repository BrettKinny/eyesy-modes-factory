-- s-nested-ellipses-filled - port of stock "S - Nested Ellipses - Filled"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Nested Ellipses - Filled/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- `count` ellipses, all centred horizontally, fanned vertically by
-- `y_offset * i`: the vertical radius shrinks linearly with the index (from
-- yr/2 down to yr/(2*count)) and the horizontal radius is that radius times a
-- per-index running average of the audio, so the fan opens and closes with the
-- sound. Each ellipse is filled with the legacy LFO picker.
--
-- Knob roles (stock-exact):
--   1 history - audio 'history' length (int(knob1*20)+1 samples)
--   2 y pos   - per-index vertical fan offset; stock's centre detent
--               0.48..0.52 gives 0, otherwise (knob2-0.5) * (yr/2) / (count*0.5),
--               negated below 0.5
--   3 count   - nested ellipse count (int(knob3*49)+1)
--   4 fg      - foreground colour via color_picker_lfo(knob4, 0.08)
--   5 bg      - background colour via color_picker_bg(knob5)
--
-- Documented deviations from stock (see docs/PORTING-LADDER.md section 4):
--   1. Foreground palette: `color_picker_lfo` uses the legacy picker, which is
--      partly random (random.randrange for c > .96). Randomness cannot be
--      ported (replays must be byte-identical), so the deterministic middle
--      branch is substituted:
--        r = 0.5+0.5*sin(2*pi*c), g = 0.5+0.5*sin(4*pi*c), b = 0.5+0.5*sin(8*pi*c)
--   2. Background picker: stock's formula returns pure white at c = 1 and pure
--      black at c = 0, both rejected by the gate, so the phase is folded to the
--      middle of the safe range: c = (knob5 * 0.7 + 0.15) % 1. The colour path
--      and the knob's effect are otherwise untouched.
--   3. LFO re-timing 30 -> 60 fps, and the ramp runs at every knob4. Stock's
--      `color_lfo_index` advances by `inc = (knob4 - .5) * 2 * 0.08` **once per
--      picker call** (once per ellipse, count calls per 30-fps frame), so the
--      index ramps at `count * inc * 30` per second. The phase here advances
--      once per frame by `count * inc * 30 * ctx.dt` and the stock per-call step
--      is kept for the within-frame gradient (`(phase + n*inc) % 2`,
--      triangle-folded to 0..1). The phase starts at stock's index 0 and is
--      drawn per element, so it takes no `tools/lfo_offset.py` phase offset.
--
--      Why the ramp is not gated on `knob4 > .5` as in stock: stock's static
--      branch returns `picker((knob4*2) % 1)` for every call, so below knob4 =
--      .5 all bands are one colour - and stock's ellipses are *nested*, not
--      merely overlapping: every ellipse shares the top point when knob2 = 0
--      (`y_offset = -(0.5-knob2) * 2 * (yr/2)/count` cancels the radius shrink
--      exactly) and the bottom point when knob2 = 1, and the horizontal radius
--      is the vertical one times the same per-slot audio average. Nested opaque
--      shapes of one colour render as the largest ellipse alone, so the union
--      is count-independent and both knob3 and knob2 move no pixel - a
--      stock-faithful deadness (measured: 0.0000 and 0.00004 of pixels) that
--      fails the gate, whose knob probes hold knob4 at 0, and which the second
--      chance cannot rescue (this mode has no trigger; PORTING-LADDER 3.4).
--      Running the ramp at every knob4 makes the banded nesting - the mode's
--      own signature - visible at every setting, with stock's own per-element
--      colour spread. At knob4 = .5 the step is 0 and the port is byte-identical
--      to stock's static branch (a single `picker(0)` colour); knob4-max carries
--      the knob's own liveness, and neither knob2 nor knob3 needs the trigger.
--   4. Ellipse count capped at 32. Stock allows 50, but each nesting level owns
--      one mesh handle and one history ring here, and the engine caps a mode at
--      32 mesh handles. knob3 is still live across its whole range
--      (int(knob3*49)+1 spans 1..50 and reaches 32 only above knob3 ~ 0.633), so
--      the knob itself is neither wrapped nor clamped.
--   5. Ellipse count floored at 2. Stock's per-index fan offset is
--      `y_offset * i`, so at knob3 = 0 (count = 1) the index term is multiplied
--      by zero and knob2 cannot move a pixel at ANY frame count - a
--      stock-faithful deadness that nevertheless fails the gate, whose second
--      chance (a MIDI trigger; this mode has no trigger) would not even apply
--      (PORTING-LADDER section 3.4). The drawn count is floored at 2 so the
--      offset has a second ellipse to shift, the same treatment
--      s-amp-color-5gon-filled (count floored at 2) and s-0-arrival-scope (box
--      width floored at 12 px) give a knob the baseline multiplies by zero.
--      Look impact: below knob3 = 1/49 ~ 0.020 the mode draws two nested
--      ellipses where stock draws one; above that the geometry is stock-exact.
--   6. Audio divisor: stock normalises channel 1 with `abs(audio_in[i] / 15000)`
--      (a literal 15000, not 32768). Stock index i -> `left[1 + i*10]`
--      denormalized by 32768, then the same /15000 and abs.
--   7. Ellipses via mesh. The API has no ellipse primitive (`e.circle` is a
--      circle, and stock's horizontal radius is audio-scaled independently of
--      the vertical one, so no uniform transform fits), so each nesting level
--      is a triangle fan: 36 boundary segments, 37 vertices (centre + boundary)
--      and a static 1-based 108-index buffer, preallocated in setup and mutated
--      in place. 32 handles, within the engine's per-mode budget. Stock's
--      `int()` truncation of the centre and radii is kept.
--   8. History ring cadence: stock's `deque(maxlen=N)` takes one sample per
--      30-fps frame (an N/30 s window). The ring here takes one sample per
--      60-fps frame, so the window is N frames but N/60 s - the pack's existing
--      convention for this idiom (s-amp-color-circles, s-amp-color-5gon-*), and
--      knob1's mapping (int(knob1*20)+1) stays stock-exact. The ring is only
--      read for `len` samples, so an unwritten slot averages its real samples
--      rather than trailing zeros.

local e = eyesy
local PI = math.pi
local sin = math.sin
local cos = math.cos
local floor = math.floor

-- Python int() truncates toward zero (stock's int() calls).
local function trunc(v)
  if v < 0 then return -floor(-v) end
  return floor(v)
end

-- Legacy-picker deterministic middle branch (deviation 1).
local function picker(c)
  local r = 0.5 + 0.5 * sin(2 * PI * c)
  local g = 0.5 + 0.5 * sin(4 * PI * c)
  local b = 0.5 + 0.5 * sin(8 * PI * c)
  return r, g, b
end

local AUDIO_DIVISOR = 15000  -- stock's literal divisor (deviation 6)
local LFO_INC = 0.08         -- stock's `inc_amt` for this mode
local MAX_COUNT = 32         -- engine mesh handle budget (deviation 4)
local RING = 32              -- history ring depth: >= max history length 21
local SEGMENTS = 36          -- ellipse boundary segments (deviation 7)
local VERTS = SEGMENTS + 1   -- centre + boundary

-- Static 1-based index buffer: one triangle fan, SEGMENTS triangles.
local fan_idx = {}
for j = 2, SEGMENTS do
  fan_idx[#fan_idx + 1] = 1
  fan_idx[#fan_idx + 1] = j
  fan_idx[#fan_idx + 1] = j + 1
end
fan_idx[#fan_idx + 1] = 1
fan_idx[#fan_idx + 1] = VERTS
fan_idx[#fan_idx + 1] = 2

-- Preallocated per-slot state: the history ring, its length and write cursor
-- (one per nesting level, so draw allocates nothing).
local hist = {}
local hist_len = {}
local hist_write = {}
local meshes = {}
local fans = {}
for i = 1, MAX_COUNT do
  local ring = {}
  for s = 1, RING do ring[s] = 0 end
  hist[i] = ring
  hist_len[i] = 0
  hist_write[i] = 1
  local verts = {}
  for v = 1, VERTS do verts[v] = {0, 0, 0} end
  fans[i] = verts
end

-- Stock's `color_lfo_index`: 0 at launch, ramped once per picker call in stock
-- and once per frame here (deviation 3).
local lfo_index = 0

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.history
  local k2 = ctx.params.ypos
  local k3 = ctx.params.count
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with the phase remapped (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  e.clear(
    (1 - (cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- History length and ellipse count (deviations 4 and 5).
  local N = trunc(k1 * 20) + 1
  if N > RING then N = RING end
  local count = trunc(k3 * 49) + 1
  if count < 2 then count = 2 end
  if count > MAX_COUNT then count = MAX_COUNT end

  -- LFO (deviation 3): stock's ramp, run at every knob4.
  local lfo_inc = (k4 - 0.5) * 2 * LFO_INC
  lfo_index = (lfo_index + lfo_inc * count * 30 * dt) % 2

  -- Vertical fan offset (stock calculate_offset).
  local max_vertical_radius = H / 2
  local y_offset = 0
  if k2 >= 0.48 and k2 <= 0.52 then
    y_offset = 0
  elseif k2 < 0.5 then
    y_offset = (0.5 - k2) * max_vertical_radius / (count * 0.5) * -1
  else
    y_offset = (k2 - 0.5) * max_vertical_radius / (count * 0.5)
  end

  local cx = trunc(W / 2)
  local cy = trunc(H / 2)

  for i = 1, count do
    -- Audio: stock index i-1 (0-based) -> left[1 + (i-1)*10] (deviation 6).
    local current_value = 0
    if left then
      local s = left[1 + (i - 1) * 10]
      if s then
        current_value = s * 32768 / AUDIO_DIVISOR
        if current_value < 0 then current_value = -current_value end
      end
    end

    -- Stock's deque: append, drop past maxlen; average the held samples.
    local w = hist_write[i]
    hist[i][w] = current_value
    local len = hist_len[i] + 1
    if len > N then len = N end
    hist_len[i] = len
    local sum = 0
    local idx = w
    for s = 1, len do
      sum = sum + hist[i][idx]
      idx = idx - 1
      if idx < 1 then idx = RING end
    end
    w = w + 1
    if w > RING then w = 1 end
    hist_write[i] = w
    local average_value = sum / len

    -- Colour: the stock ramp, one picker call per ellipse (deviations 1 + 3).
    local x = (lfo_index + (i - 1) * lfo_inc) % 2
    if x > 1 then x = 2 - x end
    local r, g, b = picker(x)
    e.color(r, g, b)

    -- Geometry (stock-exact: int() truncation of centre and radii kept).
    local n = i - 1
    local vertical_radius = trunc(max_vertical_radius - (n * (max_vertical_radius / count)))
    local horizontal_radius = trunc(vertical_radius * average_value)
    local ecy = trunc(cy + y_offset * n)

    if horizontal_radius > 0 and vertical_radius > 0 then
      local verts = fans[i]
      local centre = verts[1]
      centre[1] = cx
      centre[2] = ecy
      for s = 1, SEGMENTS do
        local a = 2 * PI * (s - 1) / SEGMENTS
        local p = verts[s + 1]
        p[1] = cx + horizontal_radius * cos(a)
        p[2] = ecy + vertical_radius * sin(a)
      end
      e.update_mesh(meshes[i], verts, fan_idx)
      e.draw_mesh(meshes[i])
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("history", 0.5, 0, 1, 1)
    e.param("ypos", 0.5, 0, 1, 2)
    e.param("count", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    for i = 1, MAX_COUNT do
      hist_len[i] = 0
      hist_write[i] = 1
      meshes[i] = e.new_mesh()
    end
    lfo_index = 0
  end,
  draw = draw,
}