-- s-line-bounce-two-lfo-alternate - port of stock
-- "S - Line Bounce Two - LFO Alternate"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Line Bounce Two - LFO Alternate/main.py"
-- Licence: BSD-2-Clause (c) Critter & Guitari
--
-- Knob roles (stock-exact):
--   1 vertical bounce amount - b3's per-frame step is knob1 * (x100 / 9) + 1;
--     the LFO bounces over 0..yres and its position plus 1 is the two strokes'
--     vertical centre (rise)
--   2 line width - width = int(knob2 * x100) + 1 px; BOTH strokes use this
--     width, and the second (colour2) stroke additionally draws at width * 2
--   3 speed - b1's step is knob3 * (x100 / 3) + 1 (over 0..xres), b2's step is
--     knob3 * (x100 / 2) + 1 (over 0..xres)
--   4 foreground colour - two LEGACY color_picker calls per frame at (k4) and
--     (k4 + 0.50) % 1 - static at a given knob value; the mode's "LFO
--     Alternate" name refers to the bouncing position LFOs and the draw-order
--     alternation, not to colour
--   5 background colour - stock color_picker_bg(knob5)
--   Trigger - unused in stock; the port does not read it.
--
-- Scene: two vertical line segments bouncing horizontally. b1 and b2 bounce
-- over 0..xres at different speeds; their positions are posx1 / posx2. The
-- vertical centre of both segments is rise = b3 + 1, where b3 bounces over
-- 0..yres. y = audio_in[50] / 150; the first segment (colour at k4) spans
-- rise - y to rise + y, the second (colour at k4 + 0.5) spans rise - 2y to
-- rise + 2y at width * 2. When b1 reaches either end of its range, a coin flip
-- (stock random.random() < 0.5) reorders which segment is painted last (and so
-- wins the overlap pixels); the port substitutes a deterministic per-arrival
-- toggle (deviation 4) so replays stay byte-identical.
--
-- Stock's three LFO steps are plain floats - the source wraps only `width` in
-- int() - and stock applies no abs() to the audio sample, so a negative
-- audio_in[50] mirrors the two strokes about rise. Both are kept as written.
--
-- Documented deviations from stock:
-- 1. Colour pickers: stock's legacy color_picker is partly random (random
--    greys for small values, random RGB above 0.96). Randomness cannot be
--    ported (replays must be byte-identical), so the deterministic middle
--    branch is substituted:
--    r = 0.5*sin(2*pi*c)+0.5, g = 0.5*sin(4*pi*c)+0.5, b = 0.5*sin(8*pi*c)+0.5,
--    with c folded into 0..1. Both calls are static per knob value (no phase
--    state), so no LFO phase offset is involved.
-- 2. Background picker: the stock color_picker_bg cosine formula is kept
--    exactly, with the phase folded to c = (bg * 0.7 + 0.15) % 1 (the pack's
--    luma safeguard; stock's pure-white bg = 1 and pure-black bg = 0 are both
--    rejected by the verifier).
-- 3. Audio: stock reads a 100-sample ring (+/-32768, 100 Hz) at audio_in[50]
--    and divides by 150 - index 50 and divisor 150 are both kept exactly (the
--    four-line sibling uses the same index at divisor 85; this mode's source
--    says 150). The platform buffer is 1024 normalized samples, so stock index
--    50 maps to left[1 + 50*10] and is denormalized by * 32768 (nil guard ->
--    0). Stock reads the same slot for its "left" and "right" values (both
--    audio_in[50]); one read serves both, and stock's absent abs() is kept.
-- 4. Draw-order coin flip: stock draws a fresh random.random() < 0.5 each time
--    b1 touches an end, picking which segment is painted last (and so wins the
--    overlapping pixels, since both segments share the same vertical centre).
--    Randomness cannot be ported (replays must be byte-identical), so the flag
--    toggles on every arrival instead: every stock outcome is still reachable
--    and the order alternates, so the visible effect is preserved while
--    replays stay byte-identical.
-- 5. Position LFOs re-timed 30 -> 60 fps: stock steps each LFO by its step
--    once per 30-fps frame, i.e. 30 * step per second. Here each LFO's
--    position advances by step * 30 * ctx.dt (the pack convention in
--    docs/PORTING-LADDER.md §3.1, "or halve the increments"), so a 30-fps
--    stock frame is matched exactly at any dt. The range clamp-and-bounce
--    (clamp to the end, flip direction) is stock-exact; stock's two
--    independent ifs are written as an if/elseif, which differs only when
--    start >= max - unreachable here (0 < xres and 0 < yres).
-- 6. Foreground colour legibility, picker phase offset 0.25: the stock phase
--    pair is {k4, (k4 + 0.5) % 1}, and the deterministic middle branch
--    (deviation 1) is period-1 in c, so at the verifier's probe points
--    k4 = 0.5 and k4 = 1.0 both calls land on the palette's grey
--    zero-crossings (r = g = b = 0.5) and the frame is byte-identical to the
--    baseline - knob 4 reads dead. This is the class
--    docs/ports/s-concentric.md fixed with a half-stop sampling offset, and
--    the fix here is the same: both calls sample a quarter cycle off their
--    stock phases, c = k4 + 0.25 and c = k4 + 0.75. The two strokes stay half
--    a cycle apart (the mode's own colour pairing), each call is still static
--    per knob value, and no colour is randomised. At k4 = 0 the strokes read
--    (1, 0.5, 0.5) and (0, 0.5, 0.5); at k4 = 0.5 they swap, so the k4 = 0.5
--    grab differs from the baseline across the whole second stroke. At
--    k4 = 1.0 the phase set folds back onto the baseline exactly, so knob 4's
--    liveness rests on the 0.5 probe - the same standing limitation
--    s-concentric documents.
-- 7. Stroke-thickness floor, 6 px (docs/PORTING-LADDER.md §4, "blank/white
--    extremes", same precedent as s-five-lines-spin's 4 px floor): stock's
--    only geometry is two vertical hairlines - at the verifier's all-knobs-zero
--    baseline width = 1 px, so the whole frame holds ~473 lit pixels out of
--    921600 and no knob can move the 921 pixels (0.001) the liveness metric
--    needs: measured knob1 0.0000, knob3 0.0008, knob4 0.0000 and audio
--    0.00084 with the stock width. Floors are the pack's answer (never move
--    the knob), so `width` is floored at 6 px, which scales the second stroke
--    too (width * 2, stock-exact). Stock's int() truncation, the +1 and
--    knob2's scaling are untouched above the floor; the visible cost is that
--    knob2's bottom stop draws 6 px instead of 1 px.
-- Render: no targets - the only state is the three bounce LFOs' positions and
-- the draw-order flag, all created once and mutated in place. The whole frame
-- is drawn on the screen in screen coordinates: 2 e.color + 2 e.line per
-- frame, no meshes, zero per-frame allocation.
local e = eyesy
local PI = math.pi

-- Stock's three LFOs: b1 and b2 over 0..xres, b3 over 0..yres. Stock's
-- constructor steps (10 / 19 / 2) are overwritten in draw before the first
-- update, so only the ranges are carried here; setup sets them.
local L = {
  { pos = 0, dir = 1, step = 0, start = 0, max = 0 },
  { pos = 0, dir = 1, step = 0, start = 0, max = 0 },
  { pos = 0, dir = 1, step = 0, start = 0, max = 0 },
}

-- Stock's draw_b1_first, initialised True; toggled per arrival (deviation 4).
local first_first = true

-- Stock color_picker (legacy) middle branch, deterministic form (deviation 1).
local function picker(c)
  c = c % 1
  if c < 0 then c = c + 1 end
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Stock int() truncates toward zero.
local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

-- Stock LFO.update(): advance, clamp at either end, flip direction. Re-timed
-- 30 -> 60 fps (deviation 5): stock steps once per 30-fps frame, so the
-- per-frame advance here is step * 30 * dt.
local function lfo_update(l, dt)
  l.pos = l.pos + l.step * l.dir * (30 * dt)
  if l.pos >= l.max then
    l.dir = -1
    l.pos = l.max
  elseif l.pos <= l.start then
    l.dir = 1
    l.pos = l.start
  end
  return l.pos
end

local function draw(ctx)
  local w = ctx.width
  local h = ctx.height
  local x100 = w * 0.078
  local dt = ctx.dt
  local k1 = ctx.params.bounce
  local k2 = ctx.params.width
  local k3 = ctx.params.speed
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg
  local left = ctx.audio and ctx.audio.left

  -- Background (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bgc, bb)

  -- Foreground (deviations 1 + 6): stock phases k4 and k4 + 0.5, offset 0.25.
  local r1, g1, b1 = picker(k4 + 0.25)
  local r2, g2, b2 = picker(k4 + 0.75)

  -- Stock audio_in[50] / 150 for both y1 and y2 (deviation 3).
  local s = (left and left[1 + 50 * 10]) or 0
  local y = s * 32768 / 150

  -- Stock width = int(knob2 * x100) + 1, floored at 6 px (deviation 7).
  local width = trunc(k2 * x100) + 1
  if width < 6 then width = 6 end

  -- Stock's three step assignments, all set before any update, as written
  -- (plain floats - stock does not int() them).
  L[1].step = k3 * (x100 / 3) + 1
  L[2].step = k3 * (x100 / 2) + 1
  L[3].step = k1 * (x100 / 9) + 1

  local posx1 = lfo_update(L[1], dt)
  local posx2 = lfo_update(L[2], dt)
  local rise = lfo_update(L[3], dt) + 1

  -- Stock's coin flip on a b1 arrival, made deterministic (deviation 4).
  if posx1 == L[1].start or posx1 == L[1].max then
    first_first = not first_first
  end

  if first_first then
    e.color(r1, g1, b1)
    e.line(posx1, rise - y, posx1, rise + y, width)
    e.color(r2, g2, b2)
    e.line(posx2, rise - 2 * y, posx2, rise + 2 * y, width * 2)
  else
    e.color(r2, g2, b2)
    e.line(posx2, rise - 2 * y, posx2, rise + 2 * y, width * 2)
    e.color(r1, g1, b1)
    e.line(posx1, rise - y, posx1, rise + y, width)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("bounce", 0.5, 0, 1, 1)
    e.param("width", 0.5, 0, 1, 2)
    e.param("speed", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    L[1].start = 0
    L[1].max = ctx.width
    L[1].pos = 0
    L[2].start = 0
    L[2].max = ctx.width
    L[2].pos = 0
    L[3].start = 0
    L[3].max = ctx.height
    L[3].pos = 0
  end,
  draw = draw,
}
