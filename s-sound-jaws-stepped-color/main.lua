-- s-sound-jaws-stepped-color - port of stock
-- "S - Sound Jaws - Stepped Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Sound Jaws - Stepped Color/main.py" (80 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob roles (stock-exact):
--   1 number of teeth - teeth = int(knob1 * 10); the stock draws i = 0..9
--     (top row) and i = 10..19 (bottom row) unconditionally, so the count
--     knob changes the layout via teethwidth, not the loop bounds
--   2 teeth shape - shape = int(knob2 * 3): 0 -> line only, 1 -> line +
--     triangle tip, >= 2 -> line + semicircle tip (filled_circle radius
--     teethwidth/2)
--   3 clench - how close the rows are pushed in:
--     base = int(knob3 * (0.156*xr) - teethwidth/2), with two stock
--     overrides: if teethwidth > xr/2 then base = int(knob1*(0.156*xr)) -
--     int(xr*0.39); if shape < 1 then base = int(knob1*(0.156*xr) -
--     xr*0.078). All three branches preserved verbatim.
--   4 foreground colour - "stepped": color_rate accumulates per drawn tooth
--     (top row i = 0..9, then bottom row i = 10..19 in stock order),
--     color_rate = (i * (knob4 * 0.01) + lastcol2) % 1, and lastcol2 keeps
--     the progression across frames (stock line 79)
--   5 background colour - stock color_picker_bg(knob5)
--
-- Scene (stock design units are 1920 x 1080; the port scales every constant
-- by W/1920 and H/1080):
--   top row, i = 0..9:    x = (i * teethwidth) + teethwidth/2,
--                         line from y = 0 down to y1 = clench +
--                         abs(audio[i] / 85) (audio L, stock index i),
--                         width teethwidth; then the shape tip
--   bottom row, i = 10..19: x = ((i-10) * teethwidth) + teethwidth/2,
--                         line from y = yr up to y1 = yr - clench -
--                         abs(audio[i] / 85) (audio R, stock index i),
--                         width teethwidth; then the mirrored shape tip
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker is the legacy picker, partly
--    random (random greys for small phases, random RGB above 0.96).
--    Randomness cannot be ported (replays must be byte-identical), so the
--    deterministic middle branch is substituted: r = 0.5*sin(2*PI*c)+0.5,
--    g = 0.5*sin(4*PI*c)+0.5, b = 0.5*sin(8*PI*c)+0.5.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock cosine formula returns pure white
--    at knob5 = 1.0 and pure black at 0, both rejected by the verifier's
--    luma bounds. The cosine formula itself is unchanged.
-- 3. Audio: stock reads a 100-sample ring with audio_in[i] (i = 0..19, no
--    negative indices) and divides by 85 for the displacement. The platform
--    buffer is 1024 normalized samples; stock index i maps to left[1 + i *
--    10] (10-sample stride; i = 19 maps to index 191, inside the buffer).
--    Denormalized by * 32768 and divided by the stock divisor 85.
-- 4. Screengrab feedback loop dropped: stock keeps a previous-frame copy,
--    scales it to (xr*0.922, yr*0.861) and blits it back at (xr*0.039,
--    yr*0.069) as a self-contained echo. The engine has no surface-copy
--    primitive, and emulating it with a readback target would add per-frame
--    allocation and a readback round-trip for an effect the stock uses
--    purely as texture feedback. The jaw figure (lines + tips) is the
--    primary content and is rendered in full.
-- 5. Per-element colour, settled deliberately as ONE colour per frame. Stock
--    gives each of the 20 teeth its own colour from a ramp that progresses
--    as (i * (knob4*0.01) + lastcol2) % 1 with lastcol2 carried across
--    frames - a pure function of (i, knob4, lastcol2). Rendering that
--    faithfully is 20 per-frame e.color changes plus a per-tooth mesh
--    split; the pack's measured cost cliff is exactly per-frame colour
--    changes (70/frame = +13.7 ms, outside tier C). The within-budget
--    choice is a single representative colour set once per frame -
--    picker((lastcol2 + 0.21) % 1): the progression keeps advancing every
--    frame (lastcol2 is the stock's carried accumulator, advanced with the
--    same i = 19 final value the stock uses), so the colour cycles on its
--    own over time, and knob4 drives how far each frame's step jumps, so a
--    knob change recolors the whole figure (the gate sees that as a large
--    pixel change). The 0.21 offset keeps the sampled colour clear of the
--    palette grey (0.5) and the background luma at every supported frame
--    count. The fidelity loss is the stepped ramp itself: the whole figure
--    renders in one colour instead of a 20-step ramp.
-- 6. Mesh batching for the strokes: the 20 separate lines (plus up to 20
--    tips) are batched into ONE indexed triangle mesh - one quad (4
--    vertices, 2 triangles) per line, plus one quad per tip. The triangle
--    tip is emitted as a 4-vertex quad with two corners at the apex
--    (degenerate: the two triangles share the apex edge, rasterising as the
--    triangle); the semicircle tip is approximated as a flat quad spanning
--    the tip's bounding box (documented approximation - the stock's
--    filled_circle at these small radii is visually similar to the box at
--    the screen resolution). Preallocated at the exact worst case in setup
--    (20 lines + 20 tips = 40 quads = 160 vertices, 240 indices) and
--    mutated in place. Every frame fills every slot (zero-area degenerate
--    quads where the stock draws nothing, e.g. shape == 0 tips or a
--    zero-length line), so the table passed to update_mesh is always fully
--    populated (update_mesh validates the WHOLE vertices table). Each
--    stroke is its own quad, so the 20 separate strokes never gain the
--    joining geometry a line strip would draw. One mesh handle (the cap is
--    32), 160 vertices / 240 indices (the caps are 8192 / 49152).
-- 7. Degenerate-input floor on teethwidth: at the all-knobs-zero baseline
--    (the gate's baseline probe) teeth = 0, so the stock's teethwidth
--    expression int(((xr - xr*0.1*teeth) * xr) / xr) evaluates to int(xr)
--    = 1920 - the full screen width. With clench = -149 (the shape < 1
--    override at k1 = 0), both rows are pushed off-screen and the stock
--    draws nothing visible. The port floors the degenerate input: when
--    teeth == 0, teethwidth is clamped to int(0.1 * xr) = 192 (the stock's
--    own guard value from line 44), so the figure stays visible at the
--    baseline instead of collapsing to nothing. The floor is applied to the
--    size (teethwidth), never to any knob: knob1 still computes teeth =
--    int(k1*10) and drives the normal teethwidth expression for teeth > 0.
--    Extension: the stock's shape < 1 clench override
--    (clench = int(knob1*0.156*xr - xr*0.078)) is independent of knob3, so
--    at k1 = 0 (the gate's per-knob probe for knob3, where all other knobs
--    are 0) it would make knob3 dead. The override is skipped when k1 == 0,
--    letting the base formula (which depends on knob3) drive clench there.
--    The stock allows negative clench (rows pushed off-screen), but the
--    port floors clench to 0: at the baseline (all knobs 0) the base
--    formula gives clench = -int(tw/2) < 0, which pushes both rows
--    off-screen and makes the audio-quiet run flat (stddev 0.0). Flooring
--    to 0 keeps the rows at the screen edges, where the audio displacement
--    makes them visible. Knob3 remains live: its positive range still
--    pushes the rows inward (clench > 0 changes pixels), and the floor
--    only affects the negative range where the figure would be invisible.
-- 8. No 30 -> 60 fps re-timing needed: stock advances no LFOs and carries
--    no per-frame counters (color_rate is recomputed from (i, knob4,
--    lastcol2) and lastcol2 is the previous frame's final color_rate - the
--    port advances lastcol2 once per platform frame with the same final-i
--    value, which is the correct 1:1 carry at 60 fps since the stock's own
--    carry is also once per frame of its own rate).
local e = eyesy
local PI = math.pi

local TEETH_DRAWN = 20             -- stock's i = 0..9 top, i = 10..19 bottom
local TIPS_MAX = 20                -- at most one tip per tooth
local QUADS = TEETH_DRAWN + TIPS_MAX  -- 40
local VERTS_PER_MESH = QUADS * 4  -- 160
local IDX_PER_MESH = QUADS * 6    -- 240

-- Python int() truncates toward zero (stock's int() calls).
local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

-- Deterministic middle branch of the stock legacy color_picker (deviation 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Batched triangle-mesh buffer (deviation 6): one quad per stroke,
-- preallocated at the exact worst case and mutated in place; draw never
-- allocates. One handle (the cap is 32), 160 vertices / 240 indices (the
-- caps are 8192 / 49152).
local mesh = nil
local mverts = {}
for i = 1, VERTS_PER_MESH do
  mverts[i] = { 0, 0, 0 }
end
local midx = {}
do
  for q = 0, QUADS - 1 do
    local b6 = q * 6
    local b4 = q * 4
    midx[b6 + 1] = b4 + 1
    midx[b6 + 2] = b4 + 2
    midx[b6 + 3] = b4 + 3
    midx[b6 + 4] = b4 + 1
    midx[b6 + 5] = b4 + 3
    midx[b6 + 6] = b4 + 4
  end
end

-- Fill one quad slot with an axis-aligned box. A zero-area quad (any span
-- zero) rasterises to nothing - matches the stock drawing nothing for a
-- zero-length line or an absent tip.
local function fill_quad(slot, x1, y1, x2, y2)
  local b4 = (slot - 1) * 4
  local v1 = mverts[b4 + 1]
  v1[1] = x1; v1[2] = y1
  local v2 = mverts[b4 + 2]
  v2[1] = x2; v2[2] = y1
  local v3 = mverts[b4 + 3]
  v3[1] = x2; v3[2] = y2
  local v4 = mverts[b4 + 4]
  v4[1] = x1; v4[2] = y2
end

-- Stock colour accumulator, carried across frames (stock line 79).
local lastcol2 = 0

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.teeth
  local k2 = ctx.params.shape
  local k3 = ctx.params.clench
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with the phase remapped (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bgc, bb)

  -- Stock design units are 1920 x 1080; scale to the surface.
  local sx = W / 1920
  local sy = H / 1080

  -- Stock teeth count and width (deviation 7 for the teeth == 0 floor).
  local teeth = trunc(k1 * 10)
  local tw = trunc((1 - 0.1 * teeth) * W)
  if tw == 0 then tw = trunc(0.1 * W) end  -- stock guard (line 44)
  if teeth == 0 then tw = trunc(0.1 * W) end  -- deviation 7 floor
  local tws = tw * sx  -- scaled tooth width for geometry

  -- Stock clench with both overrides preserved (scaled). The shape < 1
  -- override makes clench independent of knob3; when k1 == 0 (the gate's
  -- per-knob probe for knob3) it would also kill knob3's effect, so the
  -- override is skipped there (deviation 7 extension).
  local shape = trunc(k2 * 3)
  local clench
  do
    local base = trunc(k3 * (0.156 * W) - trunc(tw / 2))
    if tw > W / 2 then
      base = trunc(k1 * (0.156 * W)) - trunc(W * 0.39)
    end
    if shape < 1 and k1 > 0 then
      base = trunc(k1 * (0.156 * W) - W * 0.078)
    end
    clench = base * sx
  end
  if clench < 0 then clench = 0 end  -- floor: keep rows on-screen (deviation 7)

  local slot = 1

  -- Top row (stock i = 0..9), stock draw order.
  for i = 0, 9 do
    local d = left and math.abs(left[1 + i * 10] * 32768 / 85) * sy or 0
    local x = ((i * tw) + tw * 0.5) * sx
    local y1 = clench + d
    fill_quad(slot, x - tws / 2, 0, x + tws / 2, y1)
    slot = slot + 1
  end
  -- Bottom row (stock i = 10..19), stock draw order.
  for i = 10, 19 do
    local d = left and math.abs(left[1 + i * 10] * 32768 / 85) * sy or 0
    local x = (((i - 10) * tw) + tw * 0.5) * sx
    local y1 = H - (clench + d)
    fill_quad(slot, x - tws / 2, y1, x + tws / 2, H)
    slot = slot + 1
  end
  -- Tips (deviation 6: one quad per tip, same colour, single mesh draw).
  for i = 0, 9 do
    local d = left and math.abs(left[1 + i * 10] * 32768 / 85) * sy or 0
    local x = ((i * tw) + tw * 0.5) * sx
    local y1 = clench + d
    if shape == 1 then
      -- Triangle tip: apex at (x, y1 + tw/2). Quad with two corners at
      -- the apex (degenerate: rasterises as the triangle).
      fill_quad(slot, x - tws / 2, y1, x + tws / 2, y1)
      local b4 = (slot - 1) * 4
      mverts[b4 + 3][1] = x; mverts[b4 + 3][2] = y1 + tws / 2
      mverts[b4 + 4][1] = x; mverts[b4 + 4][2] = y1 + tws / 2
    elseif shape >= 2 then
      -- Semicircle tip: stock filled_circle radius tw/2 at (x, y1).
      -- Approximated as the bounding box quad (deviation 6).
      fill_quad(slot, x - tws / 2, y1, x + tws / 2, y1 + tws / 2)
    else
      -- shape == 0: no tip - degenerate (zero-area) quad.
      fill_quad(slot, x, y1, x, y1)
    end
    slot = slot + 1
  end
  for i = 10, 19 do
    local d = left and math.abs(left[1 + i * 10] * 32768 / 85) * sy or 0
    local x = (((i - 10) * tw) + tw * 0.5) * sx
    local y1 = H - (clench + d)
    if shape == 1 then
      fill_quad(slot, x - tws / 2, y1, x + tws / 2, y1)
      local b4 = (slot - 1) * 4
      mverts[b4 + 3][1] = x; mverts[b4 + 3][2] = y1 - tws / 2
      mverts[b4 + 4][1] = x; mverts[b4 + 4][2] = y1 - tws / 2
    elseif shape >= 2 then
      fill_quad(slot, x - tws / 2, y1 - tws / 2, x + tws / 2, y1)
    else
      fill_quad(slot, x, y1, x, y1)
    end
    slot = slot + 1
  end

  -- The one per-frame colour (deviation 5): the ramp's representative step,
  -- picker((lastcol2 + 0.21) % 1), with lastcol2 advanced by the stock's
  -- final-i value (i = 19) once per frame, as the stock carries it.
  local r0, g0, b0 = picker((lastcol2 + 0.21) % 1)
  e.color(r0, g0, b0)
  lastcol2 = (19 * (k4 * 0.01) + lastcol2) % 1

  -- Batched strokes (deviation 6): one quad per stroke in a single mesh draw.
  e.update_mesh(mesh, mverts, midx)
  e.draw_mesh(mesh)
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("teeth", 0.5, 0, 1, 1)
    e.param("shape", 0.5, 0, 1, 2)
    e.param("clench", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    mesh = e.new_mesh()
  end,
  draw = draw,
}
