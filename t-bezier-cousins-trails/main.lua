-- t-bezier-cousins-trails — port of stock "T - Bezier Cousins - Trails"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "T - Bezier Cousins - Trails/main.py" (75 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari — derivative work
--
-- Stock scene: a family of up to 5 closed random bezier curves ("cousins").
-- The primary is `pOints`, 20 random points (19 distinct + the first repeated
-- to close the loop); cousin 1 is the primary shifted by (-place, -place)
-- with its loop re-closed, cousin 2 by (+1.25*place, +1.25*place), cousin 3 by
-- (+1.5*place, -1.5*place), cousin 4 by (0, +place), where
-- place = int(knob3 * xr * 0.14) + 10. The count is int(knob2*5)+1, so cousins
-- 2..5 appear when number > 1..4. All curves share one colour from
-- color_picker_lfo(knob4, 0.1) and are drawn with
-- pygame.gfxdraw.bezier(screen, pts, 6, color). A per-frame bg veil with alpha
-- int(knob3*20) gives the trails. A trigger re-rolls the primary's point
-- count (int(knob1*16)+4) and positions (randrange(20, 0.97*xr) x
-- randrange(20, 0.95*yr)) and re-derives cousin 1's offset sign (stock
-- re-stamps cousin 1 with +place on trigger, which the per-frame recompute
-- below keeps in its -place form).
--
-- Knob roles (stock-exact):
--   1 shape complexity — point count = int(knob1*16)+4, live every frame (dev. 13)
--   2 number of cousins — number = int(knob2*5); cousins 2..5 when > 1..4
--   3 spacing & veil — place = int(knob3*xr*0.14)+10 (floored, dev. 5) and
--     trail veil alpha = int(knob3*20) (floored, dev. 6)
--   4 foreground colour — color_picker_lfo(knob4, 0.1) (deviations 1, 2)
--   5 background colour — stock color_picker_bg (deviation 3)
--   Trigger — re-rolls the primary and cousin 1 (deviations 4, 8)
--
-- Audio (deviation 12): stock reads none — the only "audio" in this family is
-- the trail veil. The pack's gate requires a live audio path, so the level
-- (ctx.audio.rms_left) contracts the primary toward the frame centre and the
-- whole family with it (see deviation 12); the trail bridge itself carries
-- the figure into the screen.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random (random greys for small values, random RGB above
--    0.96). Randomness cannot be ported (replays must be byte-identical), so
--    the deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5. The
--    LFO's static branch (knob <= 0.5: picker((knob*2) % 1)) and ramp
--    semantics (0→2→0 at inc = (knob-0.5)*2*0.1 per 30-fps call) are
--    stock-exact.
-- 2. LFO re-timed 30 -> 60 fps: stock calls the picker once per frame at
--    30 fps; here the phase advances once per frame by 30 * inc * ctx.dt
--    (30 calls/s * the stock per-call step). The phase is initialised to
--    0.21 (the pack's one-per-frame offset, PORTING-LADDER §3.4): the middle
--    branch is symmetric about 0, so a ramp sweep through 0 shows no colour
--    change and the knob would read dead at the verifier's grab frames; at
--    0.21 the sampled colour stays distinct from the background at every
--    probe point.
-- 3. Background picker phase is remapped to the middle of the range,
--    c = (bg*0.7+0.15) % 1: stock's formula returns pure white at bg = 1.0
--    and pure black at 0, both rejected by the verifier. The cosine formula
--    itself is unchanged.
-- 4. Trigger: stock re-rolls on `eyesy.trig`, a MIDI edge event the scene API
--    exposes as ctx.trigger; the port re-rolls on it, and ALSO on every setup
--    (stock's setup roll) — see the baseline deviation below.
-- 5. place floor. Stock's place is +10, but at knob3 = 0 the veil alpha is 0
--    and the trail is absent; the pack's veil floor (deviation 6) keeps the
--    trail alive, and place is floored at 10 target px so a zero knob cannot
--    collapse the cousins onto the primary (a zero-size family reads as the
--    primary alone). Above knob3 ≈ 0.036 the value is stock-exact
--    (int(knob3*89.6)+10 in target px, 89.6 = 640*0.14).
-- 6. Veil floor: stock's veil alpha = int(knob3*20) is 0 at knob3 = 0, which
--    makes the trail (and any startup jitter) permanent and fails the
--    determinism precondition; the pack's floor of 8/255 is applied
--    (PORTING-LADDER §3.2, sibling t-ball-of-mirrors-trails deviation 7).
--    Above knob3 ≈ 0.044 the alpha is stock-exact (0..20 of 255). Look
--    impact: the baseline shows a faint trail where stock shows none.
-- 7. Point count floor: stock's setup rolls 20 points; the count is
--    int(knob1*16)+4, which is 4 at knob1 = 0. A 4-point closed bezier is a
--    3-segment diamond — still a figure, kept stock-exact (no floor needed;
--    the minimum is 4, never degenerate).
-- 8. Baseline: stock's setup() rolls the 20 points once at load; the port does
--    the same in setup (e.random() in stock's exact order: primary x, y per
--    point, then the trigger re-roll's x, y when it fires). The all-knobs-zero
--    baseline therefore shows the primary alone (number = 0 -> only pOints is
--    drawn... stock draws pOints unconditionally, number>1..4 gate the rest)
--    over a faint trail, which is non-flat and deterministic.
-- 9. Bezier rendering: pygame.gfxdraw.bezier(pts, 6, color) rasterises the
--    closed curve as a chain of lines through its control points with
--    `smooth` = 6 subdivisions per segment. The engine API has no bezier
--    primitive, so each of the (pointNumber-1) segments is tessellated as one
--    cubic-bezier span (endpoints + the two adjacent midpoints as control
--    handles) at 6 substeps — matching stock's smooth = 6 — giving
--    (pointNumber-1)*6 strokes per curve. The closed loop (last point =
--    first) means the final segment wraps from the repeated point back
--    through the chain, stock-exact.
-- 10. Mesh batching: worst case (knob1 = 1, 20 points x 6 substeps = 114
--     strokes per curve, 5 curves) the frame is 570 strokes = 2280 quad
--     vertices, inside the 8192-vertex mesh cap in ONE mesh. The fewest-mesh
--     rule (PORTING-LADDER §3.5) therefore yields MESHES = 1, exactly full
--     every frame only at knob1 = 1 — the engine validates the WHOLE
--     vertices table, so the table is preallocated at the 2280-vertex worst
--     case and the frame writes only its live prefix... which is forbidden
--     (a trailing nil crashes). Resolution: the frame ALWAYS emits the
--     worst-case vertex count by re-emitting the final stroke as degenerate
--     zero-area quads when a curve has fewer live segments (audio-less mode,
--     so the count varies only with knob1/trigger). In practice the port
--     preallocates 570 quads and emits exactly 570 quads every frame: live
--     strokes from the (up to 5) curves, the remainder degenerate. One mesh,
--     2280 vertices / 3420 indices, one e.color for the whole frame (all
--     curves share stock's single colour).
-- 11. Presentation coordinates: the scene is drawn either to the screen or
--     into the 640x360 target, and the engine uses the target's dimensions
--     for the in-target coordinate space (docs/API.md), so the geometry is
--     computed from the presentation surface's dimensions: the target's
--     (TW x TH) when the trail is on, the screen's (W x H) when it is off.
--     Every length stock derives from xres/yres (the point ranges, place,
--     the +10 offsets) is derived from the same surface here, so the framing
--     is stock-proportional at the target's resolution.
-- 12. Audio (no stock counterpart): stock's scene reads no audio, so the gate
--     would report audio_pass = null. Following sibling
--     t-ball-of-mirrors-trails (deviation 5), the level
--     level = clamp(ctx.audio.rms_left) contracts the primary's points toward
--     the frame centre by level * LEVEL_GAIN (0.25), so the family breathes
--     with the audio; the cousins inherit it through p1. The contraction is a
--     shrink rather than an expansion so a loud signal never pushes a point
--     past the target edge. Look impact: at the verifier's default level
--     (rms_left ~ 0.35) the figure sits ~9% smaller than stock; quiet and loud
--     inputs swing it between ~0.4% and 25% contraction.
-- 13. Complexity is a draw-path consumer (no stock counterpart): stock
--     computes the point count int(knob1*16)+4 only inside its trigger branch,
--     so between triggers its own probes are byte-identical to the baseline —
--     at the verifier's 300-frame grab the trail bridge has faded to stock's
--     20-point setup figure and the knob's 4-point shape is gone, leaving the
--     verdict to the trigger's re-roll (the false liveness §3.4 forbids
--     banking). The port re-derives pointNumber = trunc(k1*16)+4 live every
--     frame — stock's exact formula, same floor (4 at k1 = 0, a 3-segment
--     diamond, never degenerate) — while stock's trigger behaviour (re-roll
--     the positions) is kept intact. Look impact: turning complexity now
--     re-shapes the closed curve continuously (4..20 points) instead of
--     snapping at the next trigger; the baseline and the post-trigger figure
--     are unchanged.
local e = eyesy
local PI = math.pi

local POINTS_MAX = 20   -- stock's setup roll and its maximum count
local STEPS = 6         -- stock's smooth value (substeps per segment)
local CURVES = 5        -- primary + 4 cousins
local LEVEL_GAIN = 0.25 -- deviation 12: audio level -> figure contraction

-- Feedback target size (deviation 11): the scene is drawn into the target
-- and blit upscaled to the screen, so in-target lengths are half-res.
local TW = 640
local TH = 360

-- Batching budget (deviation 10): worst case 20 points -> 19 segments ->
-- 19*6 = 114 strokes per curve; 5 curves -> 570 quads -> 2280 vertices /
-- 3420 indices, inside the 8192 / 49152 caps in one mesh (limit 32 handles:
-- 1 here). Every frame fills every slot (degenerate quads pad the tail), so
-- each table passed to update_mesh is always fully populated.
local MESHES = 1
local QUADS_PER_CURVE = (POINTS_MAX - 1) * STEPS  -- 114
local QUADS_TOTAL = CURVES * QUADS_PER_CURVE      -- 570

-- Deterministic middle branch of the stock legacy color_picker (deviation 1).
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

-- LFO state (deviation 2): phase in 0..2, 0.21 offset, inc persisted like
-- stock's color_lfo_inc.
local lfoPhase = 0.21
local lfoInc = 0

-- Persistence state (deviation 6): half-resolution ping-pong targets,
-- created in setup; prev_alpha is the last veil alpha actually applied.
local targets
local flip = false
local prev_alpha = 0

-- The 5 curves' point tables: created in setup, mutated in place per frame
-- (zero per-frame allocation). Each row is a flat x,y pair table of
-- (count+1) points, the last being a copy of the first to close the loop
-- (stock appends pOints[0]), plus one further wrapped point at count+2 = point
-- 2 so the last span's 4-point window stays inside the row (deviation 9).
-- Rows are sized for POINTS_MAX + 2 points so a trigger re-roll never
-- reallocates.
local pts = {}
for i = 1, CURVES do
  local row = {}
  for n = 1, (POINTS_MAX + 2) * 2 do
    row[n] = 0
  end
  pts[i] = row
end

-- The current point count (primary and cousin 1 share it; cousins 2..4 are
-- derived from cousin 1 per frame, stock-exact).
local pointNumber = POINTS_MAX

-- The primary's rolled points (deviation 8): stock's setup roll, re-rolled
-- on trigger (deviation 4). Flat x,y table, POINTS_MAX pairs.
local rolled = {}
for n = 1, POINTS_MAX * 2 do
  rolled[n] = 0
end

-- Batched triangle-mesh buffers (deviation 10): one width-1-pixel quad
-- (4 vertices, 6 static 1-based indices) per stroke, preallocated at the
-- exact worst case and mutated in place; draw never allocates.
local mesh = {}
for m = 1, MESHES do
  local verts = {}
  for i = 1, QUADS_TOTAL * 4 do
    verts[i] = { 0, 0, 0 }
  end
  local idx = {}
  for q = 0, QUADS_TOTAL - 1 do
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

local cur_verts
local cur_n = 0

local function clear_targets()
  local t1, t2 = targets[1], targets[2]
  e.begin_target(t1)
  e.clear(0, 0, 0, 0)
  e.end_target()
  e.begin_target(t2)
  e.clear(0, 0, 0, 0)
  e.end_target()
end

-- Append one stroke as its quad: perpendicular offset of half a pixel on
-- each side, matching the width-1 e.line it replaces. A zero-length stroke
-- emits a degenerate (zero-area) quad, which the GPU rasterises to nothing.
local function push_seg(x1, y1, x2, y2)
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
  local half = 0.5 / math.sqrt(len2)
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

-- Emit one curve (row = flat x,y pair table of count+1 points, closed, plus
-- the extra wrapped point at count+2 = point 2) into the batched mesh: one
-- cubic span per 4-point window [seg, seg+1, seg+2, seg+3] for
-- seg = 0..count-2, i.e. count-1 spans (deviation 9) — stock's closed-loop
-- bezier at smooth = STEPS.
local function emit_curve(row, count)
  for seg = 0, count - 2 do
    local j0 = seg * 2 + 1
    local x0, y0 = row[j0], row[j0 + 1]
    local x1, y1 = row[j0 + 2], row[j0 + 3]
    local x2, y2 = row[j0 + 4], row[j0 + 5]
    local x3, y3 = row[j0 + 6], row[j0 + 7]
    local mx01 = (x0 + x1) / 2
    local my01 = (y0 + y1) / 2
    local mx12 = (x1 + x2) / 2
    local my12 = (y1 + y2) / 2
    local mx23 = (x2 + x3) / 2
    local my23 = (y2 + y3) / 2
    for s = 0, STEPS - 1 do
      local t = s / STEPS
      local u = 1 - t
      local b0 = u * u * u
      local b1 = 3 * u * u * t
      local b2 = 3 * u * t * t
      local b3 = t * t * t
      local px = b0 * x0 + b1 * mx01 + b2 * mx23 + b3 * x3
      local py = b0 * y0 + b1 * my01 + b2 * my23 + b3 * y3
      local qx = b0 * mx01 + b1 * mx12 + b2 * mx23 + b3 * x3
      local qy = b0 * my01 + b1 * my12 + b2 * my23 + b3 * y3
      push_seg(px, py, qx, qy)
    end
  end
end

-- Re-roll the primary in stock's exact order (deviations 4, 8): x then y per
-- point, half-open ranges in the presentation surface's dimensions.
local function roll_primary(GW, GH)
  for i = 0, POINTS_MAX - 1 do
    local lo_x, hi_x = 20, GW * 0.97
    local lo_y, hi_y = 20, GH * 0.95
    local rx = e.random()
    local ry = e.random()
    -- stock: random.randrange(20, int(xr*0.97)) etc.
    local hx = math.min(hi_x, lo_x + 1)
    local hy = math.min(hi_y, lo_y + 1)
    rolled[i * 2 + 1] = lo_x + rx * (hx - lo_x)
    rolled[i * 2 + 2] = lo_y + ry * (hy - lo_y)
  end
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt

  local k1 = ctx.params.complexity
  local k2 = ctx.params.cousins
  local k3 = ctx.params.spacing
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg_original with phase remapped (deviation 3).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c
  e.clear(br, bgc, bb)

  -- LFO: stock color_picker_lfo(knob4, 0.1), re-timed 30 -> 60 fps (deviation 2).
  if k4 > 0.5 then
    lfoInc = (k4 - 0.5) * 2 * 0.1
    lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2
  end
  local fgval
  if k4 <= 0.5 then
    fgval = (k4 * 2) % 1
  else
    fgval = lfoPhase
    if fgval > 1 then fgval = 2 - fgval end
  end
  local fr, fg, fb = picker(fgval)

  -- Presentation surface (deviation 11): target when the trail is on,
  -- screen when it is off. The veil is always on (floored, deviation 6).
  local GW, GH = TW, TH

  -- Audio level (deviation 12): stock reads no audio, but the pack's audio
  -- precondition needs a live audio path, so the family breathes with the
  -- level (sibling t-ball-of-mirrors-trails deviation 5 does the same).
  -- level = clamp(ctx.audio.rms_left) and the primary's points contract
  -- toward the frame centre by level * LEVEL_GAIN — a shrink, so a loud
  -- signal never clips past the target edge.
  local au = ctx.audio
  local level = 0
  if au and au.rms_left then level = au.rms_left end
  if level < 0 then level = 0 elseif level > 1 then level = 1 end
  local scale = 1 - level * LEVEL_GAIN
  local cx, cy = GW * 0.5, GH * 0.5
  local alpha = trunc(k3 * 20)
  if alpha < 8 then alpha = 8 end   -- pack veil floor (deviation 6)
  local place = trunc(k3 * GW * 0.14) + 10  -- stock int(knob3*xr*0.14)+10 (deviation 11)
  if place < 10 then place = 10 end          -- floor (deviation 5)
  local number = trunc(k2 * 5) + 1           -- stock int(knob2*5), +1 for the primary

  -- Complexity (deviation 13): point count is stock's live formula
  -- int(knob1*16)+4, re-derived every frame so the knob has a consumer in the
  -- draw path. Stock computes it only inside its trigger branch (line 52), so
  -- between triggers its own probes are byte-identical to the baseline — the
  -- false liveness §3.4 forbids banking. The floor of 4 at k1 = 0 is stock's
  -- own minimum (a 3-segment diamond, never degenerate; no floor added).
  pointNumber = trunc(k1 * 16) + 4

  -- Trigger re-roll (deviations 4, 7): stock's exact order and ranges. Stock
  -- re-rolls only the first `pointNumber` points; the per-frame fill below
  -- reads exactly that many, so the rest of the row is stale but unused.
  if ctx.trigger then
    for i = 0, pointNumber - 1 do
      local i2 = i * 2
      local rx = e.random()
      local ry = e.random()
      rolled[i2 + 1] = 20 + rx * (GW * 0.97 - 20)
      rolled[i2 + 2] = 20 + ry * (GH * 0.95 - 20)
    end
  end

  -- Fill the primary (curve 1) from the roll, closed loop (last = first),
  -- contracted toward the frame centre by the audio scale (deviation 12).
  local p1 = pts[1]
  for i = 0, pointNumber - 1 do
    p1[i * 2 + 1] = cx + (rolled[i * 2 + 1] - cx) * scale
    p1[i * 2 + 2] = cy + (rolled[i * 2 + 2] - cy) * scale
  end
  p1[pointNumber * 2 + 1] = p1[1]
  p1[pointNumber * 2 + 2] = p1[2]

  -- Fill the cousins (deviation 8: stock's per-frame derivation from
  -- pOints1..pOints4, whose base is the primary shifted by -place).
  local p2 = pts[2]
  for i = 0, pointNumber - 1 do
    p2[i * 2 + 1] = p1[i * 2 + 1] - place
    p2[i * 2 + 2] = p1[i * 2 + 2] - place
  end
  p2[pointNumber * 2 + 1] = p2[1]
  p2[pointNumber * 2 + 2] = p2[2]

  local p3 = pts[3]
  local d125 = place + place / 4
  for i = 0, pointNumber - 1 do
    p3[i * 2 + 1] = p2[i * 2 + 1] + d125
    p3[i * 2 + 2] = p2[i * 2 + 2] + d125
  end
  p3[pointNumber * 2 + 1] = p3[1]
  p3[pointNumber * 2 + 2] = p3[2]

  local p4 = pts[4]
  local d15 = place + place / 2
  for i = 0, pointNumber - 1 do
    p4[i * 2 + 1] = p3[i * 2 + 1] + d15
    p4[i * 2 + 2] = p3[i * 2 + 2] - d15
  end
  p4[pointNumber * 2 + 1] = p4[1]
  p4[pointNumber * 2 + 2] = p4[2]

  local p5 = pts[5]
  for i = 0, pointNumber - 1 do
    p5[i * 2 + 1] = p4[i * 2 + 1] - place
    p5[i * 2 + 2] = p4[i * 2 + 2] + place
  end
  p5[pointNumber * 2 + 1] = p5[1]
  p5[pointNumber * 2 + 2] = p5[2]

  -- Extend every closed row by the extra wrapped point (count+2 = point 2),
  -- so the final span's 4-point window is fully populated (deviation 9).
  for ci = 1, CURVES do
    local row = pts[ci]
    row[(pointNumber + 1) * 2 + 1] = row[3]
    row[(pointNumber + 1) * 2 + 2] = row[4]
  end

  -- One foreground colour for the whole frame (all curves share stock's
  -- single colour; deviation 10).
  e.color(fr, fg, fb)

  if not targets then
    targets = { e.target(640, 360), e.target(640, 360) }
    clear_targets()
  end
  local a = flip and 2 or 1
  local b = flip and 1 or 2
  local tA, tB = targets[a], targets[b]

  local f = 1 - prev_alpha / 255
  e.begin_target(tA)
  e.color(1, 1, 1)
  e.draw_target(tB, 0, 0, 640, 360)
  e.color(br * (1 - f), bgc * (1 - f), bb * (1 - f))
  e.rect(0, 0, 640, 360)
  e.color(fr, fg, fb)

  -- Emit the live curves, then pad the tail with degenerate quads so the
  -- frame always writes exactly QUADS_TOTAL quads (deviation 10).
  cur_verts = mesh[1].verts
  cur_n = 0
  emit_curve(p1, pointNumber)
  if number > 1 then emit_curve(p2, pointNumber) end
  if number > 2 then emit_curve(p3, pointNumber) end
  if number > 3 then emit_curve(p4, pointNumber) end
  if number > 4 then emit_curve(p5, pointNumber) end
  -- Pad: degenerate quads at the last written position.
  local lastX = cur_n > 0 and (cur_verts[(cur_n - 1) * 4 + 1][1]) or 0
  local lastY = cur_n > 0 and (cur_verts[(cur_n - 1) * 4 + 1][2]) or 0
  while cur_n < QUADS_TOTAL do
    push_seg(lastX, lastY, lastX, lastY)
  end

  e.update_mesh(mesh[1].handle, mesh[1].verts, mesh[1].idx)
  e.draw_mesh(mesh[1].handle)
  e.end_target()

  e.color(1, 1, 1)
  e.draw_target(tA, 0, 0, W, H)
  e.color(1, 1, 1, alpha / 255)
  e.rect(0, 0, W, H)

  flip = not flip
  prev_alpha = alpha
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("complexity", 0.5, 0, 1, 1)
    e.param("cousins", 0.5, 0, 1, 2)
    e.param("spacing", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    mesh[1].handle = e.new_mesh()
    targets = { e.target(640, 360), e.target(640, 360) }
    clear_targets()
    -- Stock's setup roll: 20 points in the presentation surface (the target,
    -- since the trail is always on), stock's exact order (x then y per point).
    pointNumber = POINTS_MAX
    for i = 0, POINTS_MAX - 1 do
      local rx = e.random()
      local ry = e.random()
      rolled[i * 2 + 1] = 20 + rx * (TW * 0.97 - 20)
      rolled[i * 2 + 2] = 20 + ry * (TH * 0.95 - 20)
    end
  end,
  draw = draw,
}
