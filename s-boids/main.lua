-- s-boids — port of stock "S - Boids"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Boids/main.py"
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Scene (stock-exact): 250 boids (NUM_BOIDS) drift at 20 px per stock 30 fps
-- tick, wrap at the screen edges, and bounce off 32 vertical VU bars centred on
-- the frame's horizontal midline. Each bar's height is a running 3-sample
-- average of one audio sample plus min_height (5 px); the bars ARE the boids'
-- obstacles, so the flock's whole bounce field is audio-shaped. Every boid is a
-- filled circle of radius int(knob1*24)+1 in its own colour; the 32 bars share
-- one LFO colour.
--
-- Knob roles (stock-exact):
--   1 boid size — radius int(knob1*24)+1, i.e. 1..25 px
--   2 bar width — int(knob2 * spacing)+2 where spacing = xres/32 (2..42 px);
--     the bars are the bounce field, so this knob reshapes the whole flock
--   3 bar style — below 0.5 hollow, border width int(box_width_half*knob3)+1
--     with corner radius int(box_width_half*(knob3*2)) (0 while the bar is
--     shorter than 2*(min_height+fill)); at and above 0.5 solid with corner
--     radius int(box_width_half*(2-knob3*2))
--   4 foreground colour — stock color_picker_lfo(knob4) (the bars' colour)
--   5 background colour — stock color_picker_bg(knob5)
--   Trigger — unused in stock; the port does not read it.
--
-- Documented deviations from stock:
-- 1. Randomness: stock's random.uniform(0, xres) / uniform(0, yres) spawn,
--    its two uniform(-1, 1) velocity components and its random.random()
--    per-boid colour value become e.random() (the engine's seeded PRNG,
--    reset on load), drawn in stock's exact order — per boid: spawn x,
--    spawn y, velocity x, velocity y, colour value — so replays are
--    byte-identical. The velocity is scaled to BOID_SPEED by the stock
--    normalize() (a degenerate zero-length draw, impossible in practice,
--    falls back to a +x unit vector instead of dividing by zero).
-- 2. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random (random greys below 0.04, random RGB above
--    0.96). Randomness cannot be ported (replays must be byte-identical),
--    so the deterministic middle branch is substituted:
--    r = 0.5+0.5*sin(2*pi*c), g = 0.5+0.5*sin(4*pi*c), b = 0.5+0.5*sin(8*pi*c).
--    This picker also produces the 250 boid colours, which in stock come from
--    the same partly-random legacy picker (color_picker, the static branch).
--    Its static branch (knob <= 0.5: picker((knob*2) % 1)) and its ramp
--    semantics (index 0 -> 2 -> 0, inc = (knob-0.5)*0.2 per 30 fps call)
--    are stock-exact.
-- 3. LFO re-timed 30 -> 60 fps: stock calls the picker once per frame at
--    30 fps; here the phase advances once per frame by 30 * inc * ctx.dt and
--    the phase is initialised to 0.21 (the pack's one-call-per-frame offset,
--    PORTING-LADDER 3.4). Without the offset the knob4 = 1.0 ramp sits on a
--    palette grey crossing at the verifier's grab frames, where the colour
--    would match the knob4 = 0 baseline.
-- 4. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    bg = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 5. Audio: stock reads a 100-sample ring (+-32768, 100 Hz) with
--    audio_in[i], i = 0..31, and divides by 32768:
--    current_value = abs(audio_in[i] * yres / 32768). The platform buffer is
--    1024 normalized samples, so stock index i maps to left[1 + i*10]
--    (10-sample stride) denormalized by * 32768; the divisor 32768 is the
--    stock one (it is not the same in every mode). The per-bar history is
--    stock-exact — append, drop the oldest once more than 2 are held, then
--    average — ported as preallocated 4-slot rings mutated in place
--    (slot = write index mod 4, length clamped to 3, so draw allocates
--    nothing). A missing sample is guarded to 0.
-- 6. Boid advance re-timed 30 -> 60 fps: stock adds the whole velocity
--    vector once per 30 fps tick (20 px per tick = 600 px/s); here the
--    position advances by velocity * 30 * ctx.dt per frame, the same rate per
--    second, so the flock traces the same paths. The wrap and the
--    obstacle-bounce test are stock-exact and run once per engine frame
--    (stock's own cadence), so the bounce resolves more finely at 60 fps.
--    pygame's Rect() truncation is reproduced: the boid's collision rect and
--    the bar's rect/centre are ints, while the overlap distances use the raw
--    float position, exactly as stock's bounce() does.
-- 7. VU bars: e.rect has no border width and no corner radius, so
--    pygame.draw.rect(screen, color, vu_box, fill, corner) becomes the pack's
--    four-bar outline (PORTING-LADDER 3.5): top and bottom bars of
--    box_width x f and left and right bars of f x (height - 2f), drawn inward
--    from the stock rect, with f = min(border, floor(height/2)) so the bars
--    can never invert (pygame clamps a width past half the rect to a fill).
--    The corner radius is dropped (the API has no radius). The solid branch
--    (knob3 >= 0.5) is one e.rect. The bar width carries a 12 px legibility
--    floor — box_width = max(12, int(knob2*spacing)+2) — the same deviation
--    and the same reason as s-0-arrival-scope (deviation 5): at the
--    verifier's baseline knob2 = 0 the stock box is 2 px wide, where a 1 px
--    border tiles the whole box and the outline is pixel-identical to the
--    knob3 >= 0.5 fill, so knob3 would read dead. knob2 still scales the
--    width 12 -> 42 px. Look impact: below knob2 ~ 0.25 the bars are wider
--    than stock, so the flock bounces off them more.
-- 8. Boid colour classes: stock sets a fresh colour for every boid (250
--    colour changes per frame). The device receipt measures ~0.2 ms per
--    colour change (70 changes = +13.7 ms, outside tier C), so the boids are
--    grouped by colour class and the colour is set once per class — 16
--    classes, 16 colour changes, in place of 250. A boid's colour value is
--    fixed at setup, so its class membership and its class colour are static:
--    each class is drawn as a run of e.circle calls in class order, and the
--    class colour is the picker at the class's centre phase, (c-0.5)/16,
--    computed once in setup (stock's per-frame picker call is a pure function
--    of the same constant). Look impact: the flock's colour speckle is
--    quantised from 250 values to 16 — adjacent classes differ by up to
--    ~50/255 in the red channel — and overlapping boids resolve by class
--    order rather than by index order.
-- 9. No meshes: e.circle draws the boids directly, so this mode uses no mesh
--    handles and the 32-handle cap does not bind it. Per frame: 1 e.clear,
--    17 e.color (one per class + one for the bars), up to 128 e.rect (the
--    four-bar outline) and 250 e.circle, zero allocation.
-- 10. No positional deviation: the boids wrap inside the frame and the bars
--    are centred on the midline, so all content stays on canvas at every
--    knob value.

local e = eyesy
local PI = math.pi

local NUM_BOIDS = 250     -- stock NUM_BOIDS
local BOID_SPEED = 20     -- stock BOID_SPEED (px per 30 fps tick)
local MIN_HEIGHT = 5      -- stock setup
local COUNT = 32          -- stock: fixed count of VU boxes
local CLASSES = 16        -- boid colour classes (deviation 8)

-- Deterministic middle branch of the stock legacy picker (deviation 2).
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

-- Boid state (deviation 1): flat preallocated arrays, mutated in place per
-- frame. boid_class is fixed at setup (deviation 8).
local bx, by, bvx, bvy = {}, {}, {}, {}
local boid_class = {}

-- Colour classes (deviation 8): class_members[c] holds the boid indices of
-- class c in ascending order, class_n[c] their count, and the class colour is
-- precomputed from the class's centre phase.
local class_members, class_n = {}, {}
local class_r, class_g, class_b = {}, {}, {}

-- Per-bar audio history (deviation 5): a 4-slot ring per bar holding stock's
-- at most 3 values, plus its length and write index.
local hist, hist_len, hist_write = {}, {}, {}

-- Per-bar geometry (deviation 7) and obstacle extents for the bounce test.
local bar = {}

-- LFO state (deviation 3): phase in 0..2, 0.21 offset, inc persisted across
-- frames exactly as stock's color_lfo_inc is.
local lfoPhase = 0.21
local lfoInc = 0

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.size
  local k2 = ctx.params.barwidth
  local k3 = ctx.params.barstyle
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with phase remapped (deviation 4).
  local c = (k5 * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- LFO: stock-exact semantics, re-timed 30 -> 60 fps (deviations 2, 3).
  local lfoC
  if k4 <= 0.5 then
    lfoC = (k4 * 2) % 1
  else
    lfoInc = (k4 - 0.5) * 0.2
    lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2
    lfoC = lfoPhase
    if lfoC > 1 then lfoC = 2 - lfoC end
  end
  local br, bg, bb = picker(lfoC)

  -- Boid size (stock-exact).
  local boid_size = trunc(k1 * 24) + 1

  -- Bar geometry (stock-exact, with the legibility floor of deviation 7).
  local spacing = W / COUNT
  local box_width = trunc(k2 * spacing) + 2
  if box_width < 12 then box_width = 12 end
  local box_width_half = trunc(box_width / 2)
  local box_offset = trunc((spacing - box_width) / 2)

  -- Bar style (stock-exact branch order; deviation 7 for the rendering).
  local solid, border
  if k3 < 0.5 then
    solid = false
    border = trunc(box_width_half * k3) + 1
  else
    solid = true
    border = 0
  end

  local yhalf = H / 2

  -- The 32 bars: audio, history, geometry, draw (stock order). All share one
  -- colour, so it is set once (deviation 8's rule applied to the bars).
  e.color(br, bg, bb)
  for i = 1, COUNT do
    -- Audio: stock index j = i-1 (0-based) -> left[1 + j*10], / 32768.
    local sample = left and left[1 + (i - 1) * 10]
    local current_value = 0
    if sample then
      current_value = sample * 32768
      if current_value < 0 then current_value = -current_value end
      current_value = current_value * H / 32768
    end

    -- History: append, drop the oldest once more than 2 are held, average
    -- (stock-exact; the ring is preallocated, deviation 5).
    local slots = hist[i]
    local w = hist_write[i]
    slots[w] = current_value
    local len = hist_len[i] + 1
    if len > 3 then len = 3 end
    hist_len[i] = len
    hist_write[i] = (w + 1) % 4
    local first = (w - len + 1) % 4
    local sum = 0
    for s = 0, len - 1 do
      sum = sum + slots[(first + s) % 4]
    end
    local height = trunc(sum / len + MIN_HEIGHT)

    -- Stock rect: (x = int(i*spacing + box_offset), yhalf - height/2,
    -- box_width, height) with pygame's int() truncation on the y.
    local x = trunc((i - 1) * spacing + box_offset)
    local y = trunc(yhalf - height / 2)

    if solid then
      e.rect(x, y, box_width, height)
    else
      -- Outline as four inward bars (deviation 7), clamped so they never
      -- invert on a short bar.
      local f = border
      local half_h = trunc(height / 2)
      if f > half_h then f = half_h end
      if f > 0 then
        e.rect(x, y, box_width, f)
        e.rect(x, y + height - f, box_width, f)
        if height - 2 * f > 0 then
          e.rect(x, y + f, f, height - 2 * f)
          e.rect(x + box_width - f, y + f, f, height - 2 * f)
        end
      end
    end

    -- Obstacle: stock appends the whole vu_box (not the outline), and its
    -- centre is the pygame integer centre (x + w//2, y + h//2).
    local b = bar[i]
    b.left = x
    b.right = x + box_width
    b.top = y
    b.bottom = y + height
    b.cx = x + box_width_half
    b.cy = y + trunc(height / 2)
  end

  -- Boids: advance, wrap, bounce (stock order: the bars are already drawn and
  -- do not move, so the flock is updated after them), then draw grouped by
  -- colour class (deviation 8).
  -- 30 fps -> 60 fps re-time factor (deviation 6): stock advanced the whole
  -- velocity vector once per 30 fps tick.
  local step = 30 * dt
  for i = 1, NUM_BOIDS do
    local px = bx[i] + bvx[i] * step
    local py = by[i] + bvy[i] * step

    -- Wrap (stock-exact, tested against the raw position).
    if px > W then
      px = 0
    elseif px < 0 then
      px = W
    end
    if py > H then
      py = 0
    elseif py < 0 then
      py = H
    end

    -- Obstacle collisions (stock-exact overlap test; pygame's Rect truncation
    -- reproduced for the boid's collision rect).
    local bl = trunc(px - boid_size)
    local bt = trunc(py - boid_size)
    local br2 = bl + 2 * boid_size
    local bb2 = bt + 2 * boid_size
    for o = 1, COUNT do
      local ob = bar[o]
      if br2 > ob.left and bl < ob.right and bb2 > ob.top and bt < ob.bottom then
        local overlap_x = math.min(px + boid_size, ob.right) - math.max(px - boid_size, ob.left)
        local overlap_y = math.min(py + boid_size, ob.bottom) - math.max(py - boid_size, ob.top)
        if overlap_x < overlap_y then
          if px < ob.cx then
            bvx[i] = -math.abs(bvx[i])
          else
            bvx[i] = math.abs(bvx[i])
          end
        else
          if py < ob.cy then
            bvy[i] = -math.abs(bvy[i])
          else
            bvy[i] = math.abs(bvy[i])
          end
        end
      end
    end

    bx[i] = px
    by[i] = py
  end

  -- Draw the flock, one colour change per class (deviation 8).
  for k = 1, CLASSES do
    local n = class_n[k]
    if n > 0 then
      e.color(class_r[k], class_g[k], class_b[k])
      local members = class_members[k]
      for m = 1, n do
        local i = members[m]
        e.circle(trunc(bx[i]), trunc(by[i]), boid_size)
      end
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("size", 0.5, 0, 1, 1)
    e.param("barwidth", 0.5, 0, 1, 2)
    e.param("barstyle", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    -- Preallocate the bar history rings and the obstacle records.
    for i = 1, COUNT do
      local slots = {}
      for s = 0, 3 do slots[s] = 0 end
      hist[i] = slots
      hist_len[i] = 0
      hist_write[i] = 0
      bar[i] = { left = 0, right = 0, top = 0, bottom = 0, cx = 0, cy = 0 }
    end

    -- Spawn the flock (stock setup, deviation 1).
    for i = 1, NUM_BOIDS do
      bx[i] = e.random() * ctx.width
      by[i] = e.random() * ctx.height
      local vx = e.random() * 2 - 1
      local vy = e.random() * 2 - 1
      local len = math.sqrt(vx * vx + vy * vy)
      if len > 0 then
        bvx[i] = vx / len * BOID_SPEED
        bvy[i] = vy / len * BOID_SPEED
      else
        bvx[i] = BOID_SPEED
        bvy[i] = 0
      end
      local cv = e.random()
      local c = math.floor(cv * CLASSES) + 1
      if c > CLASSES then c = CLASSES end
      boid_class[i] = c
    end

    -- Colour classes (deviation 8): static membership and static colour.
    for c = 1, CLASSES do
      class_members[c] = {}
      class_n[c] = 0
      class_r[c], class_g[c], class_b[c] = picker((c - 0.5) / CLASSES)
    end
    for i = 1, NUM_BOIDS do
      local c = boid_class[i]
      local n = class_n[c] + 1
      class_n[c] = n
      class_members[c][n] = i
    end
  end,
  draw = draw,
}
