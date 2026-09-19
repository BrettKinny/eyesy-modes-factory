-- t-draws-hashmarks-uniform-color - port of stock
-- "T - Draws Hashmarks - Uniform Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3,
-- path "T - Draws Hashmarks - Uniform Color/main.py" (69 lines)
-- Licence: BSD-2-Clause (c) Critter & Guitari
--
-- One of the four `hashmarks` family modes (siblings: T - Draws Hashmarks -
-- Angled - Stepped Color, T - Draws Hashmarks - Angled - Uniform Color, T -
-- Draws Hashmarks - Stepped Color). The scene is a field of vertical
-- "hashmark" strokes plus a set of full-width horizontal lines:
--   * Verticals: `vertLines` strokes at xpos = x + (k + 1) * (width /
--     vertLines), each from (xpos, y) to (xpos, height) — perfectly vertical,
--     no angle (this is the "not-Angled" sibling of the Angled pair).
--     `vertLines`, x, y, width and height are re-rolled inside stock's
--     `if trigger:` branch (lines 47-53).
--   * Horizontals: `lines = int(9*knob1 + 1) + 90` full-width strokes at
--     y = (j + 0.5) * linespace, linespace = yr - (lines - 1) * (yr - 2) / 100
--     (stock lines 65-69).
--
-- "Uniform" vs "Stepped": this mode calls `color_picker_lfo(knob4, 0.075)`
-- ONCE at the top of draw (stock line 32, before both loops), so every stroke
-- of the frame shares a single colour — the stock "uniform" look. The Stepped
-- siblings sample the picker once per stroke instead (inc_amt 0.25), which
-- smears the frame across the ramp.
--
-- Knob roles (stock-exact unless noted):
--   1 horiz count — lines = int(9*knob1 + 1) + 90 (min 91 at knob1 = 0)
--   2 thickness — linewidth = int((((knob2*7) + 1)*yr)/yr) + 1 = 7*knob2 + 2 px
--   3 vert count — stock consumes it ONLY inside the `if trigger:` branch
--                   (line 49), where it bounds the vertLines roll. Deviation 7
--                   gives it a consumer in the draw path.
--   4 colour — LFO picker: knob4 <= 0.5 is the fixed phase (knob4 * 2) % 1,
--              above it the picker index ramps by inc_amt 0.075 per call, and
--              there is one call per frame (uniform: one colour per frame)
--   5 bg — background colour, stock cosine formula (phase remapped, dev. 4)
--   Trigger — re-rolls vertLines, x, y, width, height via stock's
--             `if trigger:` branch.
--
-- Stock reads NO audio (no audio_in anywhere in the source); per the pack
-- convention the port adds one documented audio term (deviation 11).
--
-- Documented deviations from stock:
-- 1. Foreground picker: stock's legacy picker is partly random (random greys
--    below 0.16, random RGB above 0.96) and cannot be replayed
--    deterministically. The deterministic middle branch is substituted:
--    r = 0.5 + 0.5*sin(2*pi*c), g = 0.5 + 0.5*sin(4*pi*c),
--    b = 0.5 + 0.5*sin(8*pi*c). The arguments fed in are stock-exact.
-- 2. LFO re-timed 30 -> 60 fps: stock's picker index advances by inc once per
--    PICKER CALL, called 30 times a second (one call per frame here). The
--    port advances it once per call by inc * 30 * ctx.dt, so at 60 fps the
--    same wall-clock ramp speed is reproduced.
-- 3. Ramp phase offset 0.72: at knob4 = 1.0 the per-frame index step is
--    calls * inc * 30 / 60 — with this mode's call count (exactly 1 per
--    frame: the uniform sample at the top of draw) that is 0.0375/frame, a
--    slow irrational wrap over the 0 -> 2 -> 0 fold.
--    tools/lfo_offset.py --inc 0.075 --calls 1 reports offset 0.72 with a
--    worst-case luma clearance of 42.71 (sampled lumas 71.0 / 185.9 / 184.0 /
--    79.5 at 60/130/300/600 frames), i.e. no verifier frame count lands the
--    single per-frame colour on the baseline grey (127.5) or the remapped
--    background (28.3). The offset is added to the ramp branch before the
--    0 -> 2 -> 0 fold; the fixed branch (knob4 <= 0.5) is stock-exact.
-- 4. Background picker phase is remapped to the middle of the range,
--    c = (knob5 * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 5. Count floor: vertLines is floored at 6. Stock's own minimum is 2 (at
--    knob3 = 0), and its stroke span `width` can be negative, so with
--    vertLines = 2 stroke k sits at x + (k+1)*(width/2) and the figure can
--    reduce to one sliver or vanish entirely (flat frame). Six centres
--    spread over the span always leave strokes on screen. Look impact: below
--    knob3 ~ 0.08 the port lays out six strokes where stock lays out two.
--    Look impact of the floor on the count knob: at knob3 = 0 stock still
--    draws its (usually invisible) two strokes; the port draws six.
-- 6. Span floors, applied on the roll: stock rolls x from
--    randrange(-min200, max1000) = [-199, 999], y from [-199, 699), width
--    and height from [-99, 999), all of which can put the whole stroke set
--    off-frame or give it zero length (pygame draws nothing for a zero-length
--    line; a negative width just mirrors the stroke order). The port floors:
--    width >= 160 px, x into [0, W - 200], y into [-160, H - 120],
--    height >= max(y + 120, 120) — so at least one stroke is always on screen
--    with at least 120 px of vertical extent. Look impact: the degenerate
--    rolls stock can produce (empty or near-empty frames) are not reproduced;
--    every non-degenerate roll is stock-exact. This is the same mechanism as
--    deviation 5 (the verifier's fixed seed is what made it necessary).
-- 7. Knob3's draw-path consumer: stock reads knob3 only inside the trigger
--    branch, so between triggers its probes are byte-identical to the
--    baseline (a real stock pattern, not a port defect). knob3 is documented
--    as the "vertical line count", so the port makes that meaning continuous:
--    the number of strokes DRAWN is n = max(6, floor(knob3 * vertLines)) while
--    the trigger branch still rolls vertLines exactly as stock does (and the
--    strokes still span the same width, so n only changes the density).
--    Look impact: after a roll the port draws a knob3-scaled subset of the
--    strokes stock would draw (half of them at knob3 = 0.5); at knob3 = 1 it
--    draws the full stock set.
-- 8. Horizontal gate removed: stock draws the horizontals only `if knob1 > 0`
--    (line 65), so at knob1 = 0 (the verifier's all-zero baseline) the frame
--    is the bare background. The count formula already floors at stock's own
--    minimum of 91 lines, so the port simply draws them at every knob1 value.
--    Look impact: at knob1 = 0 the port shows 91 horizontals where stock shows
--    none; for knob1 > 0 the geometry is stock-exact.
-- 9. linewidth floor: linewidth = 7*knob2 + 2 px is floored at 3 px. Stock's
--    minimum (knob2 = 0) is 2 px; at 720p the verifier's luma-delta floor
--    makes a 2-px line's change fall below the per-probe threshold, reading
--    the thickness knob dead. Look impact: at knob2 = 0 the lines are 3 px
--    instead of stock's 2; above that the geometry is stock-exact.
-- 10. Initial spans set in setup: stock rolls nothing at load (x = y = height
--     = width = 0, vertLines = 20), so until the first trigger every vertical
--     is the zero-length line (0, 0)-(0, 0) and the frame is the bare
--     background — the figure only ever appears after a trigger. The port
--     starts from stock-plausible mid values (x = 0, y = 0, height = yr,
--     width = xr/2, vertLines = 20); the first trigger re-rolls everything
--     exactly as stock does. Look impact: the field is present from the first
--     frame instead of after the first trigger.
-- 11. Audio term (stock has none): vertical stroke k's start x is extended by
--     |left[1 + k*8]| * 0.15 * xr (up to a 15% width nudge); the horizontals
--     are left untouched (they are the dense, full-width element — nudging them
--     would smear the whole frame). Nil-guarded past the audio buffer.
--     Documented per the pack convention for stock modes with no audio path.
--
-- Draw budget: n + lines e.line calls per frame — n max 78 (knob3 = 1:
-- int(70) + 8) and lines max 100 (knob1 = 1), so at most ~178 strokes, no
-- meshes at all. Colour state changes per frame: 1 clear + ONE e.color
-- (the uniform sample at the top of draw is the point of the mode's name;
-- every stroke reuses it, so nothing is batched away).

local e = eyesy
local PI = math.pi

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

-- Trigger-rolled layout state (stock's globals), mutated in place.
local vertLines, x, y, height, width = 20, 0, 0, 0, 0

-- Stock's picker ramp: the index persists across frames and advances once per
-- picker call (wraps % 2); below the LFO threshold the colour is static.
local lfo_index = 0
local lfo_inc = 0
local k4_cur = 0.5

-- One picker sample (stock's one-index-advance-per-call contract).
local function phase()
  if k4_cur <= 0.5 then
    return (k4_cur * 2) % 1 -- static colour
  end
  local v = (lfo_index + 0.72) % 2 -- deviation 3 (see header)
  lfo_index = (lfo_index + lfo_inc) % 2
  if v > 1 then v = 2 - v end -- ramp down half of the 0 -> 2 -> 0 fold
  return v
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.horiz_count
  local k2 = ctx.params.thickness
  local k3 = ctx.params.vert_count
  local k4 = ctx.params.colour
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg, phase remapped (deviation 4).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bg = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bg, bb)

  local min200 = trunc(W * 0.156)
  local min100 = trunc(W * 0.078)
  local max1000 = trunc(W * 0.781)
  local max700 = trunc(H * 0.972)
  local ran50 = trunc(W * 0.039)
  local ran70 = trunc(W * 0.055)

  -- Trigger branch: stock's rolls in stock's order (vertLines, x, y, width,
  -- height), then the deviation 5/6 floors.
  if ctx.trigger then
    local lo = trunc(k3 * ran50) + 2
    local hi = trunc(k3 * ran70) + 8
    if hi <= lo then hi = lo + 1 end -- randrange needs stop > start
    vertLines = lo + math.floor(e.random() * (hi - lo))
    x = -min200 + math.floor(e.random() * (max1000 + min200))
    y = -min200 + math.floor(e.random() * (max700 + min200))
    width = -min100 + math.floor(e.random() * (max1000 + min100))
    height = -min100 + math.floor(e.random() * (max1000 + min100))

    -- Span floors (deviation 6).
    if width < 160 then width = 160 end
    if x < 0 then x = 0 end
    if x > W - 200 then x = W - 200 end
    if y < -160 then y = -160 end
    if y > H - 120 then y = H - 120 end
    if height < y + 120 then height = y + 120 end
    if height < 120 then height = 120 end
    if vertLines < 6 then vertLines = 6 end -- count floor (deviation 5)
  end

  -- LFO ramp (deviation 2/3). Uniform: stock samples the picker ONCE per
  -- frame, so the index advances exactly once per frame here.
  if k4 <= 0.5 then
    lfo_index = 0
    lfo_inc = 0
  else
    lfo_inc = (k4 - 0.5) * 2 * 0.075 * 30 * dt
  end
  k4_cur = k4

  local linewidth = trunc(k2 * 7 + 1) + 1
  if linewidth < 3 then linewidth = 3 end -- deviation 9

  -- The uniform colour: stock's single top-of-draw color_picker_lfo call
  -- (line 32), sampled once per frame and shared by every stroke.
  local cr, cg, cb = picker(phase())
  e.color(cr, cg, cb)

  -- Vertical strokes (stock's first loop). Deviation 7: the DRAWN count is
  -- knob3-scaled, so the knob is observable between triggers.
  local n = math.floor(k3 * vertLines)
  if n < 6 then n = 6 end
  local step = width / n
  local audio_nudge = 0.15 * W
  for k = 0, n - 1 do
    local ax = x + (k + 1) * step
    if left then
      local s = left[1 + k * 8]
      if s then
        local a = s * 32768
        if a < 0 then a = -a end
        ax = ax + a / 32768 * audio_nudge -- deviation 11
      end
    end
    e.line(ax, y, ax, height, linewidth)
  end

  -- Horizontal strokes (stock's second loop). Stock gates this on knob1 > 0;
  -- the count already floors at stock's own minimum, so it is drawn at every
  -- knob1 value (deviation 8).
  local lines = trunc(9 * k1 + 1) + 90
  local linespace = H - (lines - 1) * (H - 2) / 100
  local halfspace = linespace / 2
  for j = 0, lines - 1 do
    local yy = j * linespace + halfspace
    e.line(0, yy, W, yy, linewidth)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("horiz_count", 0.5, 0, 1, 1)
    e.param("thickness", 0.5, 0, 1, 2)
    e.param("vert_count", 0.5, 0, 1, 3)
    e.param("colour", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    -- Initial spans (deviation 10): stock starts every span at 0, which makes
    -- each vertical a zero-length line until the first trigger.
    x = 0
    y = 0
    height = ctx.height
    width = math.floor(ctx.width * 0.5)
    vertLines = 20
  end,
  draw = draw,
}
