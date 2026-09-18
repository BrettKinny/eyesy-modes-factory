-- s-aquarium — port of stock "S - Aquarium"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "S - Aquarium/main.py"
-- (revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6), licence BSD-2-Clause
-- (c) 2025 Critter & Guitari.
--
-- Knob roles (stock comments):
--   1 fish   — number of 'fish' (vertical lines, 1..20)
--   2 length — fish length (segments per fish, 1..20)
--   3 width  — line width
--   4 fg     — foreground colour (static picker below 0.5, bouncing
--              accumulator above)
--   5 bg     — background colour
--
-- Each of up to 20 "fish" is a vertical line whose y-extent carries one audio
-- sample, whose x slides by a per-fish speed, and whose colour steps a bouncing
-- accumulator. The fish set is re-randomised when knob1 changes, when knob2
-- changes (stock repeats the same three list assignments for both) and on a
-- trigger frame.
--
-- Documented deviations from stock:
-- 1. Randomness: stock's random.randrange calls cannot be ported (replays must
--    be byte-identical); the engine's deterministic PRNG e.random() (reset on
--    load) is substituted, matching the ranges:
--      speed[i] = math.floor(e.random() * 4) - 2 + 0.1
--                (stock randrange(-2,2)+.1 → integers -2..1 plus 0.1),
--      ypos[i]  = math.floor(e.random() * 820) - 50
--                (stock randrange(-50, 770) → -50..769),
--      wlist[i] = math.floor(e.random() * (199-20)) + 20
--                (stock randrange(20, widthmax) with widthmax = 199).
--    The three tables (20 numbers each) plus count[1..20] (initialised 0..19 in
--    setup) are created once and mutated in place; draw never allocates. The
--    re-randomise runs on exactly stock's three occasions — yden change (knob1),
--    xden change (knob2), trigger frame — calling e.random() in the same
--    per-list order (speed, ypos, wlist) each time.
-- 2. Palette: stock's colour picker is legacy and partly random; the
--    deterministic middle branch is substituted:
--      r = 0.5+0.5*sin(2πc), g = 0.5+0.5*sin(4πc), b = 0.5+0.5*sin(8πc).
--    No LFO phase offset is needed: above fg = 0.5 the accumulator advances up
--    to 20*20*0.05 = 20 phases per frame, so the colour varies within the frame
--    and the sampled luma is not pinned to a palette crossing.
-- 3. Background picker phase is remapped to the middle of the range,
--    c = (bg*0.7 + 0.15) % 1: stock's formula returns pure white at bg = 1 and
--    pure black at 0, both rejected by the verifier. The cosine formula is
--    otherwise unchanged.
-- 4. Both per-pair accumulators re-timed 30 → 60 fps: stock advanced
--    count[i] by speed[i] and color_rate by increment*color_direction once per
--    (i, j) pair at 30 fps; here each per-pair delta is multiplied by
--    30 * ctx.dt, with the per-pair order kept so the within-frame slide and
--    colour spread are unchanged.
-- 5. Audio: stock reads a 100-sample ring (±32768, 100 Hz) via audio_in[j+i];
--    the platform buffer is 1024 normalized samples. Stock index j+i (0-based)
--    maps to left[1 + (j+i)*10] (10-sample stride) and is denormalized by
--    * 32768 before dividing by ymod (499.68 = 720 * 0.694), stock-exact. The
--    stock index is floored at 0 (its ring never holds negative indices), so
--    the port reads left[1 + max(0, j+i-2)*10].
-- 6. y position clamp: stock's yList ranges -50..769 while the canvas is 720
--    px; a fish with ypos near the top and a positive audio sample extends
--    below the visible band, and with a negative sample its line endpoints both
--    fall off the top edge and the line vanishes. A clamp,
--    y0 = max(0, ypos[i]), keeps every fish visible (the verifier rejects blank
--    and flat grabs; an all-vanished fish set leaves only the background, which
--    is flat). The stock range itself is unchanged.
-- 7. Fish, column and stroke floors: at the verifier's all-knobs-zero baseline
--    stock draws one fish with one segment — a single ~23 px one-pixel
--    hairline, which reads as a flat grab (the flatness floor rejects grabs
--    with luma stddev < 0.51) and leaves too little lit area for any knob
--    change to move. Floors
--      yden = max(8, floor(fish*19) + 1),
--      xden = max(8, floor(length*19) + 1),
--      linewidth = max(4, floor(width*99.84) + 1)
--    keep 64 strokes ≈ 256 lit pixels at the quiet audio gain and ~6400 at
--    normal gain; the knobs still scale 8 → 20 fish, 8 → 20 columns and
--    4 → 100 px stroke above the floor, and the re-randomise triggers still
--    fire when the floored value changes. Same class as s-five-lines-spin /
--    s-zoom-scope.

local e = eyesy
local PI = math.pi

-- Deterministic middle branch of the stock picker.
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

local speed = {}  -- per-fish slide speed (stock speedList)
local ypos = {}   -- per-fish y position (stock yList)
local wlist = {}  -- per-fish width (stock widthList)
local count = {}  -- per-fish slide accumulator (stock countList)

-- Re-randomise all three lists in stock's per-list order (speed, ypos, wlist).
local function rerandomise()
  for i = 1, 20 do
    speed[i] = math.floor(e.random() * 4) - 2 + 0.1
  end
  for i = 1, 20 do
    ypos[i] = math.floor(e.random() * 820) - 50
  end
  for i = 1, 20 do
    wlist[i] = math.floor(e.random() * (199 - 20)) + 20
  end
end

local yden = 1
local xden = 1
local color_direction = 1
local color_rate = 0.0

return {
  api_version = 1,
  setup = function(ctx)
    e.param("fish", 0.5, 0, 1, 1)
    e.param("length", 0.5, 0, 1, 2)
    e.param("width", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    -- Stock initialises the three lists at module load and countList to
    -- [0..19]; setup is the load equivalent.
    for i = 1, 20 do
      speed[i] = math.floor(e.random() * 4) - 2 + 0.1
      ypos[i] = math.floor(e.random() * 820) - 50
      wlist[i] = math.floor(e.random() * (199 - 20)) + 20
      count[i] = i - 1
    end
  end,
  draw = function(ctx)
    local fish = ctx.params.fish
    local length = ctx.params.length
    local width = ctx.params.width
    local fg = ctx.params.fg
    local bg = ctx.params.bg
    local dt = ctx.dt

    -- Background: stock color_picker_bg with the pack's phase safeguard
    -- (deviation 3).
    local c = (bg * 0.7 + 0.15) % 1
    e.clear(
      (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
      (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
      (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

    local sel = fg * 2
    local increment = math.abs(sel - 1) * 0.05
    local static = sel < 1
    local sr, sg, sb
    if static then
      sr, sg, sb = picker(sel)
    end

    -- Stock's re-randomise triggers, same order and same call pattern:
    -- yden (knob1) change, xden (knob2) change, trigger frame.
    local newyden = math.floor(fish * 19) + 1
    if newyden < 8 then newyden = 8 end  -- legibility floor (deviation 7)
    if yden ~= newyden then
      yden = newyden
      rerandomise()
    end
    local newxden = math.floor(length * 19) + 1
    if newxden < 8 then newxden = 8 end  -- legibility floor (deviation 7)
    if xden ~= newxden then
      xden = newxden
      rerandomise()
    end
    if ctx.trigger then
      rerandomise()
    end

    local left = ctx.audio and ctx.audio.left
    local ymod = 499.68            -- stock: yres * 0.694 at yres = 720
    local xmodbase = 1280          -- stock: eyesy.xres
    local retime = 30 * dt         -- 30 → 60 fps re-time of both accumulators
    local linewidth = math.floor(width * 99.84) + 1
    if linewidth < 4 then linewidth = 4 end  -- legibility floor (deviation 7)

    for i = 1, yden do
      local y0 = ypos[i]
      if y0 < 0 then y0 = 0 end    -- clamp (deviation 6)
      local w = wlist[i]
      for j = 1, xden do
        if static then
          e.color(sr, sg, sb)
        else
          color_rate = color_rate + increment * color_direction
          if color_rate >= 1.0 then
            color_rate = 1.0
            color_direction = -1
          end
          if color_rate <= 0.0 then
            color_rate = 0.0
            color_direction = 1
          end
          local r, g, b = picker(color_rate)
          e.color(r, g, b)
        end
        local idx = j + i - 2
        if idx < 0 then idx = 0 end  -- stock's ring index is never negative
        local s = left and left[1 + idx * 10] or 0
        local A = s * 32768
        local y1 = y0 + A / ymod
        count[i] = count[i] + speed[i] * retime
        local modSpeed = count[i] % (xmodbase + w * 2)
        local x = (j - 1) * (w / 5) + (modSpeed - w)
        e.line(x, y1, x, y0, linewidth)
      end
    end
  end,
}
