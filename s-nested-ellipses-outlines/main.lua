-- s-nested-ellipses-outlines - port of stock "S - Nested Ellipses - Outlines"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Nested Ellipses - Outlines/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- The outline twin of s-nested-ellipses-filled. Stock's `count` ellipses are
-- all centred horizontally, fanned vertically by `y_offset * i`: the vertical
-- radius shrinks linearly with the index (from yr/2 down to yr/(2*count)) and
-- the horizontal radius is that radius times a per-index running average of
-- the audio, so the fan opens and closes with the sound. Unlike the filled
-- sibling, stock draws them with `pygame.gfxdraw.ellipse` - a 1 px outline,
-- no fill - so nested ellipses never occlude one another: at knob4 = 0 the
-- whole fan is one colour yet every level is still visible, and the count
-- knob is more visible here than in the filled mode.
--
-- Knob roles (stock-exact):
--   1 history - audio 'history' length (int(knob1*20)+1 samples)
--   2 y pos   - per-index vertical fan offset; stock's centre detent
--               0.48..0.52 gives 0, otherwise (knob2-0.5) * (yr/2) / (count*0.5),
--               negated below 0.5
--   3 count   - nested ellipse count (int(knob3*99)+1)
--   4 fg      - foreground colour via color_picker_lfo(knob4, 0.008)
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
--      `color_lfo_index` advances by `inc = (knob4 - .5) * 2 * 0.008` **once per
--      picker call** (once per ellipse, count calls per 30-fps frame), so the
--      index ramps at `count * inc * 30` per second. The phase here advances
--      once per frame by `count * inc * 30 * ctx.dt` and the stock per-call step
--      is kept for the within-frame gradient (`(phase + n*inc) % 2`,
--      triangle-folded to 0..1). The phase starts at stock's index 0 and is
--      drawn per element, so it takes no `tools/lfo_offset.py` phase offset.
--
--      Because stock's `inc_amt` here is 0.008 - ten times slower than the
--      filled sibling's 0.08 - the between-call spread across the fan is
--      `(count-1) * 2 * 0.008`, which is 1.6 at count = 100 (a full sweep of
--      the picker) but only 0.5 at the port's 32 cap (a fifth of a sweep): at
--      low counts the fan is nearly one colour and the LFO colour drifts
--      visibly with time instead; at high counts the fan spans most of the
--      palette at once. The rate also scales with `count` per frame, so the
--      knob3 sweep carries extra colour motion on top of the geometry.
--
--      Why the ramp is not gated on `knob4 > .5` as in stock: stock's static
--      branch returns `picker((knob4*2) % 1)` for every call, so below knob4 =
--      .5 every ellipse is one colour. With *outlines* the whole fan is still
--      visible (no occlusion, unlike the filled sibling), but the geometry
--      knobs still die where stock's geometry dies: at knob2 = 0 (or 1) the
--      per-index fan offset `y_offset * i` cancels the radius shrink exactly
--      (`y_offset = (0.5-knob2) * 2 * (yr/2)/count`), so every ellipse's centre
--      sits at the fan's shared apex and the fan collapses to a stack of
--      concentric ellipses whose union is count- and offset-independent -
--      stock-faithful deadness that fails the gate, whose knob probes hold
--      knob4 at 0, and which this mode has no trigger to rescue (PORTING-LADDER
--      3.4). Running the ramp at every knob4 makes the banded nesting - the
--      mode's own signature - visible at every setting, with stock's own
--      per-element colour spread. At knob4 = .5 the step is 0 and the port is
--      byte-identical to stock's static branch (a single `picker(0)` colour);
--      knob4-max carries the knob's own liveness, and neither knob2 nor knob3
--      needs the trigger.
--   4. Ellipse count capped at 32. Stock allows 100 (int(knob3*99)+1), but each
--      nesting level owns one mesh handle and one history ring here, and the
--      engine caps a mode at 32 mesh handles. knob3 is still live across its
--      whole range (int(knob3*99)+1 spans 1..100 and reaches 32 only above
--      knob3 ~ 0.303), so the knob itself is neither wrapped nor clamped. The
--      100 -> 32 cap is a larger deviation from stock than the filled sibling's
--      50 -> 32: the upper ~70 % of the stock knob range draws the same 32
--      ellipses here.
--   5. Ellipse count floored at 2. Stock's per-index fan offset is
--      `y_offset * i`, so at knob3 = 0 (count = 1) the index term is multiplied
--      by zero and knob2 cannot move a pixel at ANY frame count - a
--      stock-faithful deadness that nevertheless fails the gate, whose second
--      chance (a MIDI trigger; this mode has no trigger) would not even apply
--      (PORTING-LADDER section 3.4). The drawn count is floored at 2 so the
--      offset has a second ellipse to shift, the same treatment
--      s-amp-color-5gon-filled (count floored at 2) and s-0-arrival-scope (box
--      width floored at 12 px) give a knob the baseline multiplies by zero.
--      Look impact: below knob3 = 1/99 ~ 0.010 the mode draws two nested
--      ellipse outlines where stock draws one; above that the geometry is
--      stock-exact.
--   6. Audio divisor: stock normalises channel 1 with `abs(audio_in[i] / 15000)`
--      (a literal 15000, not 32768). Stock index i -> `left[1 + i*10]`
--      denormalized by 32768, then the same /15000 and abs.
--   7. Ellipse outlines via mesh. The API has no ellipse primitive (`e.circle`
--      is a circle, and stock's horizontal radius is audio-scaled independently
--      of the vertical one, so no uniform transform fits), and `e.rect` has no
--      border width, so a 1 px ellipse outline cannot be stroked: each nesting
--      level is a ring of 36 quads, one per boundary segment, spanning 0.5 px
--      inside and 0.5 px outside the stock ellipse boundary (a band 1 px wide
--      centred on the path, the same idiom s-amp-color-5gon-outlines uses for
--      stock's 7 px pentagon stroke). 144 vertices (36 segments x 4 corners) and
--      a static 1-based 216-index buffer, preallocated in setup and mutated in
--      place. 32 handles, within the engine's per-mode budget. Look impact vs
--      stock's `pygame.gfxdraw.ellipse`: stock rasterises a 1 px line that is
--      slightly antialiased and whose corners round off; here the band is a
--      hard-edged 1 px quad ring (no antialiasing), the outline is centred on
--      the stock path (stock's 1 px line is drawn on the inside of the path,
--      so the port's outline sits ~0.5 px larger), and at sub-pixel radii the
--      quad ring can self-overlap where stock draws nothing. Stock's `int()`
--      truncation of the centre and radii is kept.
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
local LFO_INC = 0.008        -- stock's `inc_amt` for this mode (10x slower than the filled sibling)
local MAX_COUNT = 32         -- engine mesh handle budget (deviation 4)
local RING = 32              -- history ring depth: >= max history length 21
local SEGMENTS = 36          -- ellipse boundary segments (deviation 7)
local VERTS = SEGMENTS * 4   -- quad ring: 4 corners per segment
local HALF = 0.5             -- band half-width: 1 px total, centred on the stock path

-- Static 1-based index buffer: 36 quads, two triangles each.
local ring_idx = {}
for j = 1, SEGMENTS do
  local base = (j - 1) * 4
  ring_idx[#ring_idx + 1] = base + 1
  ring_idx[#ring_idx + 1] = base + 2
  ring_idx[#ring_idx + 1] = base + 3
  ring_idx[#ring_idx + 1] = base + 1
  ring_idx[#ring_idx + 1] = base + 3
  ring_idx[#ring_idx + 1] = base + 4
end

-- Per-frame scratch tables for the outline ring (boundary points, normals and
-- miter offsets); preallocated so draw allocates nothing.
local bpx = {}
local bpy = {}
local bnx = {}
local bny = {}
local bux = {}
local buy = {}
for k = 1, SEGMENTS do
  bpx[k], bpy[k], bnx[k], bny[k], bux[k], buy[k] = 0, 0, 0, 0, 0, 0
end

-- Preallocated per-slot state: the history ring, its length and write cursor,
-- and the quad-ring vertex table (one per nesting level, so draw allocates
-- nothing).
local hist = {}
local hist_len = {}
local hist_write = {}
local meshes = {}
local rings = {}
for i = 1, MAX_COUNT do
  local ring = {}
  for s = 1, RING do ring[s] = 0 end
  hist[i] = ring
  hist_len[i] = 0
  hist_write[i] = 1
  local verts = {}
  for v = 1, VERTS do verts[v] = {0, 0, 0} end
  rings[i] = verts
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
  local count = trunc(k3 * 99) + 1
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
      -- Deviation 7: the 1 px outline is a quad ring, 0.5 px inside and
      -- outside the stock boundary. Each boundary vertex k carries an outward
      -- normal and a miter offset: the unit bisector of the two adjacent
      -- segment normals, scaled by HALF/cos(half-angle) (`dot` clamped at 0.2,
      -- the same miter limit s-amp-color-5gon-outlines uses for stock's 7 px
      -- pentagon stroke), so the band is 1 px wide on both its inner and its
      -- outer boundary. Edge k's quad is (outer@k, outer@k+1, inner@k+1,
      -- inner@k) - the 5gon-outlines ordering, which winds consistently.
      -- Boundary points, normals and miter offsets are scratch tables reused
      -- every frame (no allocation).
      local a0 = -PI / 2
      for k = 1, SEGMENTS do
        local a = a0 + 2 * PI * (k - 1) / SEGMENTS
        local ca = cos(a)
        local sa = sin(a)
        bpx[k] = cx + horizontal_radius * ca
        bpy[k] = ecy + vertical_radius * sa
        local nxk = ca / horizontal_radius
        local nyk = sa / vertical_radius
        local l = math.sqrt(nxk * nxk + nyk * nyk)
        if l > 0 then
          bnx[k] = nxk / l
          bny[k] = nyk / l
        else
          bnx[k] = 0
          bny[k] = 0
        end
      end
      for k = 1, SEGMENTS do
        local p = k - 1
        if p < 1 then p = SEGMENTS end
        local sx = bnx[p] + bnx[k]
        local sy = bny[p] + bny[k]
        local l = math.sqrt(sx * sx + sy * sy)
        if l > 0.0001 then
          local ux = sx / l
          local uy = sy / l
          local dot = ux * bnx[k] + uy * bny[k]
          if dot < 0.2 then dot = 0.2 end
          bux[k] = ux * HALF / dot
          buy[k] = uy * HALF / dot
        else
          bux[k] = 0
          buy[k] = 0
        end
      end
      local verts = rings[i]
      for k = 1, SEGMENTS do
        local j = k % SEGMENTS + 1
        local b = (k - 1) * 4 + 1
        local v1 = verts[b]
        local v2 = verts[b + 1]
        local v3 = verts[b + 2]
        local v4 = verts[b + 3]
        v1[1] = bpx[k] + bux[k]
        v1[2] = bpy[k] + buy[k]
        v2[1] = bpx[j] + bux[j]
        v2[2] = bpy[j] + buy[j]
        v3[1] = bpx[j] - bux[j]
        v3[2] = bpy[j] - buy[j]
        v4[1] = bpx[k] - bux[k]
        v4[2] = bpy[k] - buy[k]
      end
      e.update_mesh(meshes[i], verts, ring_idx)
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
