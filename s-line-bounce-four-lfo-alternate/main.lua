-- s-line-bounce-four-lfo-alternate — port of stock
-- "S - Line Bounce Four - LFO Alternate"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "S - Line Bounce Four - LFO Alternate/main.py"
-- Licence: BSD-2-Clause (c) Critter & Guitari
--
-- Knob roles (stock-exact):
--   1 vertical (x) line width — size1 = int(knob1 * x100) + 1 px, x100 =
--     0.078 * xres, floored at 6 px (deviation 7)
--   2 horizontal (y) line width — size2 = int(knob2 * x100 / 2) + 1 px;
--     also sets how far the two horizontal lines sit from the vertical
--     centre (their LFO start/max fold the width in)
--   3 speed — each LFO's per-frame step is int(knob3 * factor) + floor,
--     factor 0.0125 / 0.0242 / x100/20 / x100/20, floor 5 / 5 / 2 / 2
--   4 foreground colour — four LEGACY color_picker calls per frame at
--     (k4), (k4+0.25) % 1, (k4+0.5) % 1, (k4+0.75) % 1 — static at a given
--     knob value; the mode's "LFO Alternate" name refers to the four
--     bouncing position LFOs, not to colour
--   5 background colour — stock color_picker_bg(knob5)
--   Trigger — unused in stock; the port does not read it.
--
-- Scene: four bouncing lines. Two vertical lines bounce horizontally
-- (b1 over 0..xres, step int(k3*0.0125*xres)+5; b2 over 0..xres, step
-- int(k3*0.0242*xres)+5), the upper one spanning (yres/4 - y) to yres/2,
-- the lower one yres/2 to (yres*0.75) + y. Two horizontal lines bounce
-- vertically (b3 over 0..yres/2-size2/2, step int(k3*x100/20)+2; b4 over
-- yres/2+size2/2..yres, same step), spanning the full width. y =
-- abs(audio_in[50] / 85) stretches the vertical lines' outer ends. When
-- the top x LFO reaches either end of its range, a coin flip (stock
-- random.random() < 0.5) reorders the draw of the x lines against the y
-- lines; the port substitutes a deterministic parity alternation
-- (deviation 4) so replays stay byte-identical.
--
-- Documented deviations from stock:
-- 1. Colour pickers: stock's legacy color_picker is partly random
--    (random greys for small values, random RGB above 0.96). Randomness
--    cannot be ported (replays must be byte-identical), so the
--    deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5,
--    with c folded into 0..1. All four calls are static per knob value
--    (no phase state), so no LFO phase offset is involved.
-- 2. Background picker: the stock color_picker_bg cosine formula is kept
--    exactly, with the phase folded to c = (bg * 0.7 + 0.15) % 1 (the
--    pack's luma safeguard; stock's pure-white bg = 1 and pure-black
--    bg = 0 are both rejected by the verifier).
-- 3. Audio: stock reads a 100-sample ring (±32768, 100 Hz) at
--    audio_in[50] and divides by 85 — the stock divisor is 85 and it is
--    kept exactly. The platform buffer is 1024 normalized samples; stock
--    index 50 maps to left[1 + 50*10] (the 1024-sample window holds
--    102.4 stock slots, so index 50 falls at 5.05 platform samples,
--    floored to sample 5, the oldest of that slot's span) and is
--    denormalized by * 32768 (nil guard -> 0). y = abs(s * 32768 / 85).
-- 4. Draw-order coin flip: stock draws a fresh random.random() < 0.5
--    each time the top x LFO touches an end, picking which line family
--    is painted last (and so wins the two families' crossing pixels).
--    Randomness cannot be ported (replays must be byte-identical), so
--    the flag toggles on every arrival instead: every stock outcome is
--    still reachable, the order still alternates exactly as stock's
--    most likely sequence does, and the two families cross at the same
--    points (the vertical strokes meet the lower horizontal stroke near
--    x = 0 at the baseline), so the visible effect is preserved while
--    replays stay byte-identical.
-- 5. Position LFOs re-timed 30 -> 60 fps: stock steps each LFO by an
--    integer number of pixels once per 30-fps frame, i.e. 30 * step
--    px/s. To match that rate at 60 fps the per-frame advance must be
--    (stock step) * 30 * ctx.dt: at dt = 1/60 that is step/2 px per
--    frame, i.e. 30 * step px/s, exactly stock's rate.
--    The range clamp-and-bounce (clamp to the end, flip direction) is
--    stock-exact; stock's two independent ifs are written as an
--    if/elseif, which differs only when start >= max — unreachable,
--    since size2 <= 50 keeps b3's max = yres/2 - size2/2 above its
--    start = 0 and b4's start below its max = yres.
-- 6. Line widths: pygame.draw.line treats a width <= 0 as 1 px, while
--    e.line takes the width literally; stock's int() + 1 already floors
--    both at 1, so size2 (the horizontal stroke) is stock-exact as
--    written. size1 (the vertical stroke) carries the audio legibility
--    floor of deviation 7.
-- 7. Audio legibility floor, stroke thickness (docs/PORTING-LADDER.md
--    §4, same precedent as s-circle-scope-opposite-colors deviation 7,
--    s-zoom-scope deviation 8 and s-five-lines-spin): the only
--    audio-driven geometry in stock is
--    y = abs(sample/85) extending the two vertical strokes' OUTER ends
--    — the inner ends stay pinned at yres/2 — so at the verifier's
--    all-knobs-zero baseline, where size1 = 1 px, the audio variants
--    differ only in those two 1 px columns: measured 0.00028, far below
--    the 0.001 fraction the metric needs (921 px of the 1280x720
--    frame). size1 is therefore floored to 6 px. The stock divisor, the
--    geometry and the knob scaling are untouched: the base grab's
--    y = 135 px leaves the upper stroke's outer end at row 45 and the
--    lower stroke's at row 675, while the quiet grab's y = 7 px leaves
--    them at rows 174 / 546 — 2 x 129 rows of stroke differ, 258 px at
--    the stock 1 px stroke but 1548 px (0.0017) at 6 px. The loud
--    grab's y = 471 px pushes both ends off-frame; the freq grab's
--    y = 177 px leaves the lower end at row 717.
--    The visible cost is that knob1's bottom stop draws 6 px instead of
--    1 px; its 6..100 px range, the whole size2 range (stock-exact,
--    minimum 1 px) and the 30 fps stock behaviour are unchanged.
-- Render: no targets — the mode is stateless across frames (the bounce
-- LFOs' positions are the only state and they are mutated in place), so
-- the whole frame is drawn on the screen in screen coordinates: 4
-- e.color + 4 e.line per frame, no meshes.
local e = eyesy
local PI = math.pi


-- Bounce LFO state (deviation 5): position in pixels, direction ±1,
-- per-frame stock step. Created once, mutated in place (zero per-frame
-- allocation).
local L = {}
for i = 1, 4 do
  L[i] = { pos = 0, dir = 1, step = 0, start = 0, max = 0 }
end

local x_lines_first = true

-- Deterministic middle branch of the stock legacy color_picker
-- (deviation 1); c folded to 0..1 as stock's float math does.
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

-- Stock LFO.update(): advance, clamp at either end, flip direction.
-- Called at the 60-fps re-timed rate (deviation 5): stock steps once
-- per 30-fps frame (30 * step px/s), so the per-frame advance here is
-- 30 * dt times the stock step.
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
  local k1 = ctx.params.vwidth
  local k2 = ctx.params.hwidth
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

  -- Audio (deviation 3): stock abs(audio_in[50] / 85), divisor stock-exact.
  local s = (left and left[1 + 50 * 10]) or 0
  local y = math.abs(s * 32768 / 85)
  local r1, g1, b1 = picker(k4)
  local r2, g2, b2 = picker(k4 + 0.25)
  local r3, g3, b3 = picker(k4 + 0.50)
  local r4, g4, b4 = picker(k4 + 0.75)

  -- size1 carries the audio legibility floor of deviation 7 (6 px).
  local size1 = trunc(k1 * x100) + 1
  if size1 < 6 then size1 = 6 end
  local size2 = trunc(k2 * (x100 / 2)) + 1

  -- Stock's per-frame range/step updates, in stock order.
  L[3].max = (h / 2) - (size2 / 2)
  L[4].start = (h / 2) + (size2 / 2)
  L[1].step = trunc(k3 * (w * 0.0125)) + 5
  L[2].step = trunc(k3 * (w * 0.0242)) + 5
  L[3].step = trunc(k3 * (x100 / 20)) + 2
  L[4].step = trunc(k3 * (x100 / 20)) + 2

  local posx1 = lfo_update(L[1], dt)
  local posx2 = lfo_update(L[2], dt)
  local posy1 = lfo_update(L[3], dt)
  local posy2 = lfo_update(L[4], dt)

  -- Stock's coin flip on top-x LFO arrival, made deterministic
  -- (deviation 4): toggle on every arrival.
  if posx1 == L[1].start or posx1 == L[1].max then
    x_lines_first = not x_lines_first
  end

  if x_lines_first then
    e.color(r1, g1, b1)
    e.line(posx1, (h / 4) - y, posx1, h / 2, size1)
    e.color(r2, g2, b2)
    e.line(posx2, h / 2, posx2, (h * 0.75) + y, size1)
    e.color(r3, g3, b3)
    e.line(0, posy1, w, posy1, size2)
    e.color(r4, g4, b4)
    e.line(0, posy2, w, posy2, size2)
  else
    e.color(r3, g3, b3)
    e.line(0, posy1, w, posy1, size2)
    e.color(r4, g4, b4)
    e.line(0, posy2, w, posy2, size2)
    e.color(r1, g1, b1)
    e.line(posx1, (h / 4) - y, posx1, h / 2, size1)
    e.color(r2, g2, b2)
    e.line(posx2, h / 2, posx2, (h * 0.75) + y, size1)
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("vwidth", 0.5, 0, 1, 1)
    e.param("hwidth", 0.5, 0, 1, 2)
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
    L[3].max = ctx.height / 2
    L[3].pos = 0
    L[4].start = ctx.height / 2
    L[4].max = ctx.height
    L[4].pos = ctx.height / 2
  end,
  draw = draw,
}
