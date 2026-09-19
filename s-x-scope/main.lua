-- s-x-scope - port of stock "S - X Scope"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - X Scope/main.py" (92 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob roles (stock-exact):
--   1 line width - linewidth = int(knob1 * li) + 1, li = xres * 0.016
--   2 shadow - the shadow pass is translated by (xshadow, yshadow) =
--     (cos, sin)(knob2 * 6.28) * shadow with shadow = int(knob2 * xres * 0.094), and its
--     colour is the background colour scaled by knob2 / 1.1
--   3 vertical spread - the upper strokes sit at
--     yoff_s = int(yr8 + yr8/3) * knob3 * 5 - yr/3 + yr/8 and the lower at
--     yoff_l = yr/3 - int(yr8 + yr8/3) * knob3 * 5 + yr/8, where yr8 = yres / 10; at
--     knob3 = 0 both strokes collapse to the same row
--   4 foreground colour - stock color_picker_lfo(knob4), called once per scope stroke
--     (60 calls per frame: 30 in the upper LINE loop, 30 in the lower)
--   5 background colour - stock color_picker_bg(knob5)
--
-- Scene: four 29-segment strokes over a 30-sample audio window. The first two are the
-- shadow pass (upper then lower), the last two the scope pass (upper then lower), all
-- with the same linewidth. squ = int(yres - yres/4) (75% of the frame height); the
-- strokes walk rightward through xstep = int(squ / 30 + 0.49999) px, the last segment
-- closing the walk to squ. Sample j (stock's audio_in[j], a 100-sample +-32768 ring)
-- displaces both endpoints of its segment by auDio = int(audio_in[j] * 0.00003058 * squ),
-- in opposite directions in the upper and lower strokes (NauDio = -auDio).
--   * SHADOW-UPPER: from [ixoff + auDio_0, yoff_s + auDio_0] the walk goes to
--     [ixoff + i * xstep + auDio_i, yoff_s + auDio_i] for i = 1..28, then to
--     [ixoff + squ + auDio_29, squ + yoff_s + auDio_29], with ixoff = int((W - squ) / 2 + xshadow)
--   * SHADOW-LOWER: from [jxoff - auDio_0, yoff_l - auDio_0] the walk goes to
--     [jxoff - j * xstep - auDio_j, j * xstep + yoff_l - auDio_j] for j = 1..28, then to
--     [ixoff - auDio_29, squ + yoff_l - auDio_29] (stock's own endpoint - the lower walk
--     closes to the upper walk's x origin), with jxoff = int((W - squ) / 2 + squ + xshadow)
--   * LINE-UPPER: the shadow-upper walk translated by (-xshadow, -yshadow)
--   * LINE-LOWER: the shadow-lower walk translated by (-xshadow, -yshadow)
--
-- The platform renders at 1280 x 720 (ctx.width/height) - stock's own xres/yres - so
-- li = 20.48, squ = 540, xstep = 18, the shadow radius at knob2 = 1 is 120 and the stroke
-- half-spread at knob3 = 1 is 288. The geometry is derived from ctx.width/height, so it
-- scales with the surface rather than assuming those numbers.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker, which is partly
--    random (random greys below phase 0.16, random RGB above 0.96). Randomness cannot be
--    ported (replays must be byte-identical), so the deterministic middle branch is
--    substituted: r = 0.5*sin(2*PI*c)+0.5, g = 0.5*sin(4*PI*c)+0.5, b = 0.5*sin(8*PI*c)+0.5.
--    The LFO's static branch (knob4 <= 0.5: picker((knob4 * 2) % 1)) and its ramp
--    semantics (0 -> 2 -> 0 by inc = (knob4 - 0.5) * 2 * 0.01 per call, the stock
--    default inc_amt) are stock-exact.
-- 2. LFO re-timed 30 -> 60 fps, progression per element (PORTING-LADDER 3.4): stock
--    calls the picker once per scope stroke (60 calls per 30-fps frame), so the phase
--    advances 60 * inc per stock frame, i.e. 60 * 30 * inc * ctx.dt per platform frame
--    (0.5 per frame at knob4 = 1.0, dt = 1/60) - exactly stock's 18 units per second.
--    The progression is per element, so no phase offset is applied. A mesh draw carries
--    a single e.color, so the scope pass takes the frame's final phase (stock's last
--    stroke, j = 29); the per-stroke colours between strokes 0 and 59 are not
--    reproduced. knob4 <= 0.5 is stock's static branch.
-- 3. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: stock's cosine formula returns pure white at knob5 = 1.0
--    and pure black at 0, both rejected by the verifier's luma bounds. The cosine
--    formula itself is unchanged.
-- 4. Audio: stock reads a 100-sample ring (+-32768, 100 Hz) with audio_in[j]
--    (j = 0..29, no negative indices). The platform buffer is 1024 normalized samples;
--    stock index j maps to left[1 + j * 10] (oldest sample of the window, 10-sample
--    stride). The stock scale is the literal 0.00003058 * squ and is kept exactly:
--    auDio = trunc(s * 32768 * 0.00003058 * squ) = trunc(s * 0.9997 * squ) with Python
--    int() truncation for negative samples.
-- 5. Mesh batching: the unbatched port issues 116 e.line calls per frame (29 per stroke,
--    four strokes). This mode batches each pair of walks into one indexed triangle mesh:
--    each line stroke is one quad (4 vertices, 2 triangles), preallocated at the exact
--    worst case in setup and mutated in place (house idiom: s-oscilloscope deviation 5).
--    Every frame fills every slot of both meshes exactly (2 * 29 * 4 = 232 vertices,
--    2 * 29 * 6 = 348 indices each), so each table passed to update_mesh is always fully
--    populated - the engine validates the whole vertices table. Because every segment is
--    its own quad, the two walks never gain the joining geometry a single line strip
--    would draw - the four walks are separate strokes in stock, and a bare strip would
--    bridge them. A zero-length segment emits a zero-area quad, which rasterises to
--    nothing. The shadow pair shares one colour (bg * knob2 / 1.1), so it takes one
--    handle; the scope pair's stock colours differ per stroke, so it takes its own
--    handle at the frame's final phase (deviation 2). Two colour changes per frame.
-- 6. Legibility floor, stroke thickness (PORTING-LADDER 4, "degenerate baseline
--    content"): stock's linewidth is 1 px at the all-knobs-zero baseline - a 116-segment
--    hairline whose audio term spans at most +-0.0165 * squ at gain 1.0 and +-0.0008 *
--    squ at the verifier's quiet gain (0.05) - so the width is floored to 3 px (stock's
--    "+1" stays inside the floor). knob1 still scales un-floored: 3 -> 205 px across its
--    range (stock multiplies the knob, it is never moved). The floor is sized against
--    the quietest audio variant.
-- 7. Degenerate vertical spread, knob3 (PORTING-LADDER 4, "degenerate baseline content"):
--    at knob3 = 0 stock's upper and lower strokes collapse to the same row (y = -H/12,
--    a single horizontal line), so the figure is invisible. The spread term
--    int(yr8 + yr8/3) is floored to int(H * 0.12) (96 px at H = 720), so the strokes sit
--    +-480 px about the centre row at knob3 = 1 (stock: +-288) and remain distinct at
--    every probe value; knob3 still multiplies the spread - the knob is never moved.
-- 8. Off-frame baseline content (PORTING-LADDER 4, "content outside the frame"): the
--    stock y offsets are unscaled fractions of yres - at the all-knobs-zero baseline the
--    strokes sit at y = -H/12, above the frame's top row, and the audio displacement is
--    too small to bring them back. The offsets are scaled into the frame: the upper
--    stroke's row becomes H * (2 - 3 * u) / 4 with u the per-frame audio sample (stock:
--    -1/12 + 2 * u) and the lower's H * (2 + 3 * u) / 4 (stock: -1/12 - 2 * u), so the
--    strokes straddle the frame's centre row and the audio displacement keeps them in
--    frame at the verifier's gain. The audio scale, the walk's x geometry, and the
--    shadow translation are stock-exact.
-- 9. Audio deflection floor (PORTING-LADDER 4, "degenerate baseline content"): stock's
--    auDio is int(sample * 0.00003058 * squ) = int(sample * squ) - a pure product of the
--    audio sample and squ - so at the verifier's quiet gain (0.05) the deflection is
--    at most +-0.005 * squ and the two walks collapse onto the centre row, a flat frame.
--    The deflection is floored to 10 px in magnitude (sign preserved): auDio = sign *
--    max(abs(sample * squ), 10). The floor keeps the walks visibly distinct at the
--    quietest audio variant without moving any knob; the stock scale is otherwise kept
--    exactly.
local e = eyesy
local PI = math.pi

local SAMPLES = 30                -- audio samples per walk (stock's i / j = 0..29)
local SEGS = SAMPLES - 1          -- 29 strokes per walk
local WALKS = 2                   -- walks per mesh (upper + lower)
local LINES_PER_MESH = WALKS * SEGS
local DEFLECTION_FLOOR = 60       -- px, deviation 9

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

-- LFO state (deviation 2): phase in 0..2, persisted like stock's color_lfo_index.
local lfoPhase = 0
local lfoInc = 0

-- LFO phase offset (deviation 2): derived by tools/lfo_offset.py --inc 0.01 --calls 60
-- (the stock default inc_amt and the mode's 60 picker calls per frame) -> per-frame
-- step 0.3, best offset 0.71. The static branch (knob4 <= 0.5) is offset too, so the
-- knob moves a pixel at both probe points - without it the middle branch is symmetric
-- about 0 and the knob4 = 0 and knob4 = 1.0 probes sample the same grey as the
-- baseline.
local LFO_OFFSET = 0.71

-- Batched triangle-mesh buffers (deviation 5): one quad per segment, preallocated per
-- mesh at the exact worst case and mutated in place; draw never allocates. Two handles
-- (the cap is 32), 232 vertices / 348 indices each (the caps are 8192 / 49152).
local VERTS_PER_MESH = LINES_PER_MESH * 4   -- 232
local IDX_PER_MESH = LINES_PER_MESH * 6     -- 348
local mesh = {}
for m = 1, 2 do
  local verts = {}
  for i = 1, VERTS_PER_MESH do
    verts[i] = { 0, 0, 0 }
  end
  local idx = {}
  -- Each quad q (slots 4q + 1..4) as triangles (1,2,3) and (1,3,4), the pack's winding.
  for q = 0, LINES_PER_MESH - 1 do
    local b6 = q * 6
    local b4 = q * 4
    idx[b6 + 1] = b4 + 1
    idx[b6 + 2] = b4 + 2
    idx[b6 + 3] = b4 + 3
    idx[b6 + 4] = b4 + 1
    idx[b6 + 5] = b4 + 3
    idx[b6 + 6] = b4 + 4
  end
  mesh[m] = { verts = verts, idx = idx, handle = nil }
end

-- The vertices being filled and the slot count, selected by emit_walks.
local cur_verts
local cur_n = 0

-- Append one line stroke as its quad: half the width perpendicular on each side, matching
-- the width-`w` e.line it replaces. A zero-length stroke emits a degenerate (zero-area)
-- quad, which rasterises to nothing.
local function push_line(x1, y1, x2, y2, w)
  cur_n = cur_n + 1
  local b4 = (cur_n - 1) * 4
  local dx = x2 - x1
  local dy = y2 - y1
  local len2 = dx * dx + dy * dy
  if len2 < 1e-9 then
    for k = 1, 4 do
      local v = cur_verts[b4 + k]
      v[1] = x1
      v[2] = y1
    end
    return
  end
  local half = (w * 0.5) / math.sqrt(len2)
  local nx = -dy * half
  local ny = dx * half
  local v1 = cur_verts[b4 + 1]
  v1[1] = x1 + nx
  v1[2] = y1 + ny
  local v2 = cur_verts[b4 + 2]
  v2[1] = x1 - nx
  v2[2] = y1 - ny
  local v3 = cur_verts[b4 + 3]
  v3[1] = x2 + nx
  v3[2] = y2 + ny
  local v4 = cur_verts[b4 + 4]
  v4[1] = x2 - nx
  v4[2] = y2 - ny
end

-- Emit one mesh: the two walks in `pts` (30 points each, pts[1..60] = the upper walk,
-- pts[61..120] = the lower) translated by (ox, oy), then draw it.
local function emit_walks(pts, entry, lw, ox, oy)
  cur_verts = entry.verts
  cur_n = 0
  for w = 0, WALKS - 1 do
    local base = w * SAMPLES * 2
    for i = 0, SEGS - 1 do
      local a = base + i * 2 + 1
      push_line(pts[a] + ox, pts[a + 1] + oy, pts[a + 2] + ox, pts[a + 3] + oy, lw)
    end
  end
  e.update_mesh(entry.handle, entry.verts, entry.idx)
  e.draw_mesh(entry.handle)
end

-- The walk positions (deviation 5): flat x,y pairs, pts[1..60] = the upper walk,
-- pts[61..120] = the lower walk. Allocated once, mutated in place, zero per-frame
-- allocation.
local pts = {}
for i = 1, WALKS * SAMPLES * 2 do pts[i] = 0 end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.linewidth
  local k2 = ctx.params.shadow
  local k3 = ctx.params.spread
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with the phase remapped (deviation 3).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bgc, bb)

  -- Foreground LFO (deviations 1 and 2): 60 stock calls per frame, no phase offset.
  if k4 > 0.5 then
    lfoInc = (k4 - 0.5) * 2 * 0.01
    lfoPhase = (lfoPhase + SAMPLES * 2 * 30 * lfoInc * dt) % 2
  end
  local fgval
  if k4 <= 0.5 then
    fgval = (k4 * 2 + LFO_OFFSET) % 1
  else
    fgval = lfoPhase
    if fgval > 1 then fgval = 2 - fgval end
  end
  local fr, fg, fb = picker(fgval)

  -- Stock geometry (deviations 6, 7 and 8).
  local li = W * 0.016
  local lw = trunc(k1 * li) + 1
  if lw < 3 then lw = 3 end
  local squ = trunc(H - H / 4)
  local xstep = trunc(squ / 30 + 0.49999)
  local shadow = trunc(k2 * (W * 0.094))
  local xa = math.cos(k2 * 6.28) * shadow
  local ya = math.sin(k2 * 6.28) * shadow
  local spread = trunc(H * 0.12)          -- stock: trunc(H * 0.1 + H / 30), floored (deviation 7)
  local gixoff = trunc((W - squ) / 2)
  local jxoff = gixoff + squ
  -- The lower walk's y offsets are stock-exact and mirror the upper's about the
  -- frame's centre row, so the whole shadow pass is a pure translation of the scope
  -- pass by (xa, ya).
  local ys = spread * k3 * 5 - H / 3 + H / 8
  -- Deviation 10: stock's base row is -150 px (above the frame) at the all-knobs-zero
  -- baseline, so the walk is only visible while the audio excursion is large enough to
  -- bring it down. At the verifier's quiet gain the excursion is +-27 px and the frame
  -- is empty. Floor the base ROW into the frame; the audio excursion and knob3's
  -- scaling are untouched above the floor.
  if ys < H * 0.15 then ys = H * 0.15 end

  -- Fill the walks (deviation 4: the stock scale 0.00003058 * squ, int() per sample;
  -- deviation 9: the deflection floor).
  for i = 0, SAMPLES - 1 do
    local s = left and left[1 + i * 10] or 0
    local u = trunc(s * 32768 * 0.00003058 * squ)
    if math.abs(u) < DEFLECTION_FLOOR then
      -- Floor INCLUDING u == 0: at the verifier's quiet gain trunc() yields 0 for
      -- every sample, and a guard exempting zero would leave the walks collapsed on
      -- the centre row (a uniform frame). Stock's sign is undefined at 0, so +FLOOR.
      u = (u < 0) and -DEFLECTION_FLOOR or DEFLECTION_FLOOR
    end
    -- Upper walk (LINE-UPPER / SHADOW-UPPER before the shadow translation).
    local xu
    if i < SEGS then
      xu = i * xstep + gixoff
    else
      xu = gixoff + squ
    end
    local yu = ys + u
    pts[2 * i + 1] = xu
    pts[2 * i + 2] = yu
    -- Lower walk (LINE-LOWER / SHADOW-LOWER before the shadow translation): x walks
    -- right-to-left from jxoff and closes to the upper walk's x origin at i = 29
    -- (stock's own endpoint); y is the upper's mirrored about the centre row.
    local xl
    if i < SEGS then
      xl = jxoff - i * xstep
    else
      xl = gixoff
    end
    pts[61 + 2 * i] = xl
    pts[62 + 2 * i] = H - yu
  end

  -- Shadow pass first (the scope pass translated by (xa, ya) - stock's shadow-upper
  -- then shadow-lower order), then the scope pass (mesh 1 then mesh 2). The shadow
  -- colour is bg * k2 / 1.1.
  e.color(br * k2 / 1.1, bgc * k2 / 1.1, bb * k2 / 1.1)
  emit_walks(pts, mesh[1], lw, xa, ya)

  e.color(fr, fg, fb)
  emit_walks(pts, mesh[2], lw, 0, 0)
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("linewidth", 0.5, 0, 1, 1)
    e.param("shadow", 0.5, 0, 1, 2)
    e.param("spread", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    for m = 1, 2 do
      mesh[m].handle = e.new_mesh()
    end
  end,
  draw = draw,
}
