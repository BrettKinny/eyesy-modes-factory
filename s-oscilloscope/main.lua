-- s-oscilloscope - port of stock "S - Oscilloscope"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Oscilloscope/main.py" (82 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob roles (stock-exact):
--   1 line thickness - linewidth = int(knob1 * x110) + 1, x110 = int(xres * 0.234)
--   2 y position - every point's y is int(knob2 * yres + audio_in[i*2] * yres / 32768)
--   3 shadow distance & opacity - the trace is re-drawn behind itself, offset
--     (-shadow * knob3, +shadow * knob3) with shadow = int(xres * 0.078), in the
--     background colour scaled by knob3
--   4 foreground colour - stock color_picker_lfo(knob4, 0.01), called once per
--     stroke (50 calls per frame)
--   5 background colour - stock color_picker_bg(knob5)
--
-- Scene: a 50-point audio scope on the walk  anchor(-x110, yres/2) -> P_0 -> ... -> P_49,
-- with P_i = (i * x15, int(knob2 * yres + A_i * yres / 32768)), x15 = int(xres/50) + 1,
-- A_i = audio_in[i * 2] (i = 0..49, even samples of the 100-sample ring). The walk has
-- 51 positions and is stroked twice per frame, both times identically:
--   * 50 lines, from position w to w+1, width `linewidth`;
--   * 51 circles, radius linewidth * 0.49, at every one of the 51 positions - stock
--     draws one per stroke at the previous position and adds the 51st at i = 49.
-- Stock's draw() calls bglineseg (shadow) for i = 0..49 first, then lineseg (scope) for
-- i = 0..49, so the shadow pass is under the scope pass; that order is kept.
--
-- The platform renders at 1280 x 720 (ctx.width/height) - stock's own xres/yres - so
-- x15 = int(1280/50) + 1 = 26, x110 = int(1280 * 0.234) = 299 and
-- shadow = int(1280 * 0.078) = 99. The geometry is derived from ctx.width/height, so it
-- scales with the surface rather than assuming those numbers.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker, which is partly
--    random (random greys for small phases, random RGB above 0.96). Randomness cannot be
--    ported (replays must be byte-identical), so the deterministic middle branch is
--    substituted: r = 0.5*sin(2*PI*c)+0.5, g = 0.5*sin(4*PI*c)+0.5, b = 0.5*sin(8*PI*c)+0.5.
--    The LFO's static branch (knob4 <= 0.5: picker((knob4 * 2) % 1)) and its ramp
--    semantics (0 -> 2 -> 0 by inc = (knob4 - 0.5) * 2 * 0.01 per call) are stock-exact.
-- 2. LFO re-timed 30 -> 60 fps, progression per element (PORTING-LADDER 3.4): stock
--    calls the picker once per stroke (50 calls per 30-fps frame), so the phase advances
--    50 * inc per stock frame, i.e. 50 * 30 * inc * ctx.dt per platform frame (0.25 per
--    frame at knob4 = 1.0, dt = 1/60) - exactly stock's 15 units per second. Because the
--    progression is per element and the colour is not a once-per-frame sample, no phase
--    offset is applied. A mesh draw carries a single e.color, so the scope pass takes the
--    frame's final phase (stock's last stroke, i = 49); the per-stroke colours between
--    strokes 0 and 48 are not reproduced. knob4 <= 0.5 is stock's static branch, and
--    knob4 = 0.5 folds to picker(0) - the same (0.5, 0.5, 0.5) grey the all-zero baseline
--    draws, in stock too - so knob4's liveness rests on its max probe, where the grabbed
--    trace is (255, 127, 127), picker(0.25) for the frame's final phase, over 15903 px
--    (changed fraction 0.01726).
-- 3. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: stock's cosine formula returns pure white at knob5 = 1.0
--    and pure black at 0, both rejected by the verifier's luma bounds. The cosine
--    formula itself is unchanged.
-- 4. Audio: stock reads a 100-sample ring (+-32768, 100 Hz) with audio_in[i * 2]
--    (i = 0..49: even indices only, no negative indices). The platform buffer is 1024
--    normalized samples; stock index j maps to left[1 + j * 10] (oldest sample of the
--    window, 10-sample stride), so i * 2 maps to left[1 + i * 20] (indices 1..981).
--    Denormalized by * 32768 - the stock divisor is 32768 and is kept stock-exact as
--    trunc(knob2 * H + A * H / 32768) with Python int() truncation for negative samples.
-- 5. Mesh batching: the unbatched port issues 100 e.line + 102 e.circle calls per frame
--    (50 lines + 51 circles per pass, shadow then scope). This mode batches each pass
--    into one indexed triangle mesh: each line stroke is one quad (4 vertices, 2
--    triangles) and each circle is one 12-gon fan (13 vertices, 12 triangles),
--    preallocated at the exact worst case in setup and mutated in place (house idiom:
--    s-folia-curves deviation 10 / s-bezier-h-scope deviation 8). Every frame fills every
--    slot of both meshes exactly (50 * 4 + 51 * 13 = 863 vertices, 50 * 6 + 51 * 36 = 2136
--    indices each), so each table passed to update_mesh is always fully populated - the
--    engine validates the whole vertices table. Because every stroke and every circle is
--    its own quad/fan, the 50 separate segments and 51 circles never gain the joining
--    geometry a single line strip would draw. A zero-length stroke emits a zero-area
--    quad, which rasterises to nothing. Circles are 12-gons rather than pygame's
--    pixel-exact rasteriser (the mesh API has no arc primitive); the 12 unit-circle
--    offsets are precomputed once, so the per-frame pass does no trigonometry.
-- 6. Legibility floor, stroke thickness (PORTING-LADDER 4, "degenerate baseline
--    content"): stock's linewidth is 1 px at the all-knobs-zero baseline - a 50-segment
--    hairline whose audio term spans +-0.6 * yres at gain 1.0 but only +-0.03 * yres at
--    the verifier's quiet gain (0.05) - so the width is floored to 3 px (stock's "+1"
--    stays inside the floor). knob1 still scales un-floored: 3 -> 300 px across its range
--    (stock multiplies the knob, it is never moved). The floor is sized against the
--    quietest audio variant.
-- 7. In-frame y range (PORTING-LADDER 4, "content outside the frame"): stock's
--    int(knob2 * yres) reaches yres at knob2 = 1.0, putting the whole trace below the
--    last row - the frame then holds nothing but the background and the verifier reports
--    a flat frame. The offset is scaled into the frame: int(knob2 * (H - 1)), so the
--    trace's centre stays on the last row instead of one row past it. knob2 = 0 is
--    stock-exact (y = 0, the trace's top edge on the frame's top row).
-- 8. Shadow opacity at the extremes: stock's shadow colour is bg_color * knob3 and it is
--    drawn under the scope pass, so it is invisible at knob3 = 0 (black, dead offset) and
--    at knob3 = 1.0 (exactly the background colour); it shows only between them, as the
--    darker-than-background strokes knob3 = 0.5 draws. That is stock's own behaviour and
--    is kept - the verifier needs each knob live at >= 1 probe point, and knob3 is live at
--    its mid probe by both terms (the offset is shadow * knob3, the colour bg * knob3):
--    the knob3 mid grab adds (8, 19, 5) = bg * 0.5 over 18451 px (changed fraction
--    0.02002), and its max grab is byte-identical to the baseline (fraction 0.0).
local e = eyesy
local PI = math.pi

local POINTS = 50                 -- audio points P_0..P_49 (stock's i = 0..49)
local WALK = POINTS + 1           -- walk positions: the anchor plus the 50 points
local FAN = 12                    -- triangles per circle fan
local CIRCLES = WALK              -- 51 circles per pass
local LINES = POINTS              -- 50 strokes per pass

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

-- LFO state (deviation 2): phase in 0..2, persisted like stock's color_lfo_inc.
local lfoPhase = 0
local lfoInc = 0

-- Unit-circle offsets for the 12-gon fans (deviation 5), computed once: the per-frame
-- pass then does no trigonometry (2 * 51 * 12 sin/cos per frame otherwise).
local UCOS = {}
local USIN = {}
for k = 1, FAN do
  local a = 2 * PI * k / FAN
  UCOS[k] = math.cos(a)
  USIN[k] = math.sin(a)
end

-- Batched triangle-mesh buffers (deviation 5): one quad per line stroke, one 12-gon fan
-- per circle, preallocated per pass at the exact worst case and mutated in place; draw
-- never allocates. Two handles (the cap is 32), 863 vertices / 2136 indices each (the
-- caps are 8192 / 49152).
local VERTS_PER_MESH = LINES * 4 + CIRCLES * (FAN + 1)   -- 863
local IDX_PER_MESH = LINES * 6 + CIRCLES * 3 * FAN       -- 2136
local mesh = {}
for m = 1, 2 do
  local verts = {}
  for i = 1, VERTS_PER_MESH do
    verts[i] = { 0, 0, 0 }
  end
  local idx = {}
  local n = 0
  -- Lines: quad q (slots 1..200) as triangles (1,2,3) and (1,3,4), the pack's winding.
  for q = 0, LINES - 1 do
    local b6 = q * 6
    local b4 = q * 4
    idx[b6 + 1] = b4 + 1
    idx[b6 + 2] = b4 + 2
    idx[b6 + 3] = b4 + 3
    idx[b6 + 4] = b4 + 1
    idx[b6 + 5] = b4 + 3
    idx[b6 + 6] = b4 + 4
    n = b6 + 6
  end
  -- Circles: fan c (centre vertex 200 + 13c, rim 200 + 13c + 1..12), 12 triangles each
  -- as (centre, rim k, rim k+1) with rim 13 wrapping to rim 1. Same winding sense as the
  -- quads above.
  for c = 0, CIRCLES - 1 do
    local cen = 200 + c * 13
    for k = 1, FAN do
      local k2 = k + 1
      if k2 > FAN then k2 = 1 end
      n = n + 1; idx[n] = cen
      n = n + 1; idx[n] = cen + k
      n = n + 1; idx[n] = cen + k2
    end
  end
  mesh[m] = { verts = verts, idx = idx, handle = nil }
end

-- The vertices being filled and the slot count, selected by emit_pass.
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

-- Append one circle as a 12-gon fan starting at slot 200 (deviation 5).
local function push_circle(cx, cy, r)
  cur_n = cur_n + 1
  local base = 200 + (cur_n - LINES - 1) * (FAN + 1)
  local c0 = cur_verts[base]
  c0[1] = cx
  c0[2] = cy
  for k = 1, FAN do
    local v = cur_verts[base + k]
    v[1] = cx + r * UCOS[k]
    v[2] = cy + r * USIN[k]
  end
end

-- Emit one whole pass - the 50 lines (slots 1..200) then the 51 circles (slots 201..863)
-- of the walk in `pts` - into `entry`, translated by (ox, oy), and draw it. The shadow
-- pass is the scope pass translated by (-shadow * knob3, +shadow * knob3), so no point is
-- ever mutated between passes.
local function emit_pass(pts, entry, lw, cr, ox, oy)
  cur_verts = entry.verts
  cur_n = 0
  for i = 0, LINES - 1 do
    local a = i * 2 + 1
    push_line(pts[a] + ox, pts[a + 1] + oy, pts[a + 2] + ox, pts[a + 3] + oy, lw)
  end
  for k = 0, CIRCLES - 1 do
    local p = k * 2 + 1
    push_circle(pts[p] + ox, pts[p + 1] + oy, cr)
  end
  e.update_mesh(entry.handle, entry.verts, entry.idx)
  e.draw_mesh(entry.handle)
end

-- The walk positions (deviation 5): flat x,y pairs, pts[1..2] = the anchor, pts[2w+1..]
-- = the w-th point, w = 1..50. Allocated once, mutated in place, zero per-frame allocation.
local pts = {}
for i = 1, WALK * 2 do pts[i] = 0 end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.thickness
  local k2 = ctx.params.ypos
  local k3 = ctx.params.shadow
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with the phase remapped (deviation 3).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bgc, bb)

  -- Foreground LFO (deviations 1 and 2): 50 stock calls per frame, no phase offset.
  if k4 > 0.5 then
    lfoInc = (k4 - 0.5) * 2 * 0.01
    lfoPhase = (lfoPhase + POINTS * 30 * lfoInc * dt) % 2
  end
  local fgval
  if k4 <= 0.5 then
    fgval = (k4 * 2) % 1
  else
    fgval = lfoPhase
    if fgval > 1 then fgval = 2 - fgval end
  end
  local fr, fg, fb = picker(fgval)

  -- Stock geometry (deviations 6 and 7).
  local x15 = trunc(W / 50) + 1
  local x110 = trunc(W * 0.234)
  local shadow = trunc(W * 0.078)
  local lw = trunc(k1 * x110) + 1
  if lw < 3 then lw = 3 end
  local ybase = trunc(k2 * (H - 1))
  local cr = lw * 0.49

  -- Fill the walk once (deviation 4: the stock divisor 32768, int() over the whole sum).
  pts[1] = -x110
  pts[2] = H / 2
  for i = 0, POINTS - 1 do
    local s = left and left[1 + i * 20] or 0
    local A = s * 32768
    local p = i * 2 + 3
    pts[p] = i * x15
    pts[p + 1] = trunc(ybase + A * H / 32768)
  end

  -- Shadow pass first, then the scope pass - stock's draw order (mesh 1 then mesh 2).
  local sh = shadow * k3
  e.color(br * k3, bgc * k3, bb * k3)
  emit_pass(pts, mesh[1], lw, cr, -sh, sh)

  e.color(fr, fg, fb)
  emit_pass(pts, mesh[2], lw, cr, 0, 0)
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("thickness", 0.5, 0, 1, 1)
    e.param("ypos", 0.5, 0, 1, 2)
    e.param("shadow", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    for m = 1, 2 do
      mesh[m].handle = e.new_mesh()
    end
  end,
  draw = draw,
}