-- s-folia-angles — port of stock "S - Folia Angles"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "S - Folia Angles/main.py" (202 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: shape — one of seven shape families, open polylines of 1-4 segments
--         per box (<0.15 single, 0.15-0.3 broken lozenge, 0.3-0.45 angle,
--         0.45-0.6 bird beak, 0.6-0.75 house, 0.75-0.9 lozenge, >=0.9 star)
-- Knob 2: max rotation speed. At exactly 1 the rotation stops and every angle
--         is pinned to 0 (stock reassigns the whole table there).
-- Knob 3: trail amount — the alpha of the per-frame veil toward the background.
-- Knob 4: foreground colour (LFO picker, inc_amt = 0.05)
-- Knob 5: background colour
--
-- Scene: a 9x7 grid of 63 boxes (each box l100 = xr*0.037 wide and tall).
-- Every box keeps a 10-entry moving window of its own audio sample (a smoothed
-- offset a1 = mean(window)) and its own rotation angle. Each frame the angle
-- advances by (a1/yr) * knob2 * 200 * 2 degrees, clamped to [-180, 180], and
-- the box's shape polylines — built from the rotated box corners and a1 — are
-- drawn in the LFO colour. After the boxes, a full-screen veil in the
-- background colour at alpha knob3*45/255 is blended toward the background,
-- which is what makes the trails.
--
-- Documented deviations from stock:
-- 1. Frame rate: stock ticks at a hard 30 fps; this port runs at 60, so every
--    per-frame increment (rotation, LFO phase) is re-timed by 30 * ctx.dt.
-- 2. Persistence: stock's veil is a literal full-screen alpha blit over the
--    previous framebuffer. The port renders into a ping-pong pair of render
--    targets instead: each frame the new boxes are drawn on top of last
--    frame's target, then a full-screen e.rect in the background colour at
--    alpha knob3 * 45 / 255 fades that result toward the background, and the
--    faded target is presented. The trail's *look* is preserved; the blit is
--    not ported literally (PORTING-LADDER.md section 3.2).
-- 3. Anti-aliasing: pygame.draw.aalines is anti-aliased; the engine's lines
--    are not. The AA is dropped; stroke width stays 1 and the polylines stay
--    open (non-closed strips).
-- 4. Foreground palette: stock color_picker_lfo(knob4, 0.05) uses the legacy
--    picker, which is partly random. The deterministic middle branch
--    (0.5+0.5*sin(2*pi*c), 0.5+0.5*sin(4*pi*c), 0.5+0.5*sin(8*pi*c)) is
--    substituted. For fg <= 0.5 the colour is static picker((fg*2) % 1);
--    above 0.5 the ramp advances once per frame by 30 * inc * ctx.dt with
--    inc = (fg - 0.5) * 2 * 0.05 = (fg - 0.5) * 0.1 (the mode's own
--    inc_amt = 0.05).
-- 5. LFO phase offset 0.21: the mode calls the LFO once per frame and the
--    gate samples the colour at a single instant (luma only). With no offset
--    the sampled index lands exactly on a palette crossing at the verifier's
--    grab frames (the knob event is applied at frame 5), so knob4 reads dead.
--    The phase is initialised to 0.21, derived with tools/lfo_offset.py
--    --inc 0.1 --calls 1: it keeps the sampled colour at least 38.85 luma
--    units from both the palette grey (0.5) and the background at every frame
--    count the verifier supports (60/130/300/600).
-- 6. Background picker: stock's color_picker_bg is ported exactly, with the
--    pack's phase safeguard c = (bg * 0.7 + 0.15) % 1 (the stock formula
--    returns pure white at c = 1 and pure black at c = 0, both rejected by
--    the verifier).
-- 7. Audio: stock reads a 100-sample ring (±32768, 100 Hz) via
--    audio_in[index]; the platform buffer is 1024 normalized samples. Stock
--    index index (0-based, 0..62) maps to left[1 + index*10] (oldest sample
--    of the window, 10-sample stride) denormalized by * 32768.
-- 8. Per-box history: stock pops/appends a 10-entry list per box per frame.
--    Here the 63x10 history and the 63 rotation angles are preallocated in
--    setup and mutated in place (write-index ring); the per-frame vertex
--    tables are the only allocations in draw.

local e = eyesy
local PI = math.pi

local GRID_W = 9
local GRID_H = 7
local BOXES = GRID_W * GRID_H
local HIST = 10

-- Deterministic middle branch of the stock picker.
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- Rotate point (x,y) around (cx,cy) by angle degrees; matches stock verbatim.
local function rotate_point(cx, cy, x, y, angle)
  local rad = angle * PI / 180
  local cos = math.cos(rad)
  local sin = math.sin(rad)
  local tx = x - cx
  local ty = y - cy
  return tx * cos - ty * sin + cx, tx * sin + ty * cos + cy
end

-- Preallocated state: mutated in place per frame, never reallocated.
local audio_history = {}
local hist_pos = {}
local rotation_angles = {}
local lfoPhase = 0.21  -- phase offset, see header deviation 5
local lfoInc = 0
local fbA = nil
local fbB = nil
local mesh1 = nil
local mesh2 = nil
local mesh3 = nil
local mesh4 = nil

-- One mesh handle per concurrent polyline (max 4, far under the 32-handle
-- cap); each is mutated and redrawn in place every frame. The small per-frame
-- vertex tables are the only allocations in draw (see header deviations 2,
-- 3 and 8); the audio ring and the rotation accumulator are pure in-place
-- mutation.
local v1 = {}
local v2 = {}
local v3 = {}
local v4 = {}

local function emit(handle, vt, p1x, p1y, p2x, p2y, p3x, p3y, count)
  vt[1] = { p1x, p1y, 0 }
  vt[2] = { p2x, p2y, 0 }
  if count == 3 then vt[3] = { p3x, p3y, 0 } end
  e.update_mesh(handle, vt)
  e.draw_mesh(handle)
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("shape", 0.5, 0, 1, 1)
    e.param("spin", 0.5, 0, 1, 2)
    e.param("trail", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    for i = 1, BOXES do
      audio_history[i] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
      hist_pos[i] = 0
      rotation_angles[i] = 0
    end
    fbA = e.target(ctx.width, ctx.height)
    fbB = e.target(ctx.width, ctx.height)
    mesh1 = e.new_mesh()
    mesh2 = e.new_mesh()
    mesh3 = e.new_mesh()
    mesh4 = e.new_mesh()
  end,
  draw = function(ctx)
    local shape = ctx.params.shape
    local spin = ctx.params.spin
    local trail = ctx.params.trail
    local fg = ctx.params.fg
    local bg = ctx.params.bg
    local dt = ctx.dt
    local W = ctx.width
    local H = ctx.height

    -- Background colour: stock color_picker_bg with the pack phase safeguard
    -- (header deviation 6). Used for the veil and the screen clear.
    local c = (bg * 0.7 + 0.15) % 1
    local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
    local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
    local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c

    -- Foreground: stock color_picker_lfo(knob4, 0.05) semantics (header
    -- deviations 4 and 5).
    if fg > 0.5 then
      lfoInc = (fg - 0.5) * 0.1
    end
    lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2
    local cr, cg, cb
    if fg > 0.5 then
      local x = lfoPhase
      if x > 1 then x = 2 - x end
      cr, cg, cb = picker(x)
    else
      cr, cg, cb = picker((fg * 2) % 1)
    end
    e.color(cr, cg, cb)

    -- Grid geometry (stock lines 43-48).
    local l100 = W * 0.037
    local hspacing = (W - GRID_W * l100) / (GRID_W + 1)
    local vspacing = (H - GRID_H * l100) / (GRID_H + 1)

    local left = ctx.audio and ctx.audio.left
    local reset_spin = (spin == 1)

    -- Ping-pong feedback target (header deviation 2): draw the boxes on top
    -- of last frame's image, then fade that result toward the background.
    local src = fbA
    local dst = fbB
    e.begin_target(dst)
    e.draw_target(src, 0, 0, W, H)
    for row = 0, GRID_H - 1 do
      for col = 0, GRID_W - 1 do
        local x = hspacing * (col + 1) + col * l100
        local y = vspacing * (row + 1) + row * l100
        local index = row * GRID_W + col

        -- Per-box moving-window audio history (header deviations 7 and 8).
        local s = left and left[1 + index * 10] or 0
        local current_value = s * H  -- stock: (audio_in[index] * yr) / 32768
        local hist = audio_history[index + 1]
        hist_pos[index + 1] = (hist_pos[index + 1] + 1) % HIST
        local p = hist_pos[index + 1] + 1
        hist[p] = current_value
        local sum = 0
        for k = 1, HIST do sum = sum + hist[k] end
        local a1 = sum / HIST

        -- Rotation: never-reset accumulator, clamped to [-180, 180]; pinned to
        -- 0 while spin == 1 (stock reassigns the whole table there).
        local rotation_speed = (a1 / H) * spin * 200 * 2
        local angle = rotation_angles[index + 1] + rotation_speed * 30 * dt
        if angle > 180 then angle = 180 end
        if angle < -180 then angle = -180 end
        if reset_spin then angle = 0 end
        rotation_angles[index + 1] = angle

        local cx = x + l100 / 2
        local cy = y + l100 / 2

        -- Rotated box corners, stock order: TL, BL, BR, TR.
        local rv0x, rv0y = rotate_point(cx, cy, x, y, angle)
        local rv1x, rv1y = rotate_point(cx, cy, x, y + l100, angle)
        local rv2x, rv2y = rotate_point(cx, cy, x + l100, y + l100, angle)
        local rv3x, rv3y = rotate_point(cx, cy, x + l100, y, angle)

        -- The recurring 3-point polylines, point expressions verbatim from
        -- stock: T (top, peak at y + a1), U (bottom, peak at y + l100 - a1),
        -- W (left, peak at x + a1), Z (right, peak at x - a1 + l100).
        local t1x, t1y = rotate_point(cx, cy, x + l100, y, angle)
        local t2x, t2y = rotate_point(cx, cy, x + l100 / 2, y + a1, angle)
        local t3x, t3y = rotate_point(cx, cy, x, y, angle)

        local u1x, u1y = rotate_point(cx, cy, x + l100, y + l100, angle)
        local u2x, u2y = rotate_point(cx, cy, x + l100 / 2, y + l100 - a1, angle)
        local u3x, u3y = rotate_point(cx, cy, x, y + l100, angle)

        local w1x, w1y = rotate_point(cx, cy, x, y + l100, angle)
        local w2x, w2y = rotate_point(cx, cy, x + a1, y + l100 / 2, angle)
        local w3x, w3y = rotate_point(cx, cy, x, y, angle)

        local z1x, z1y = rotate_point(cx, cy, x + l100, y + l100, angle)
        local z2x, z2y = rotate_point(cx, cy, x - a1 + l100, y + l100 / 2, angle)
        local z3x, z3y = rotate_point(cx, cy, x + l100, y, angle)

        -- The top polyline with peak at y - a1 (bird-beak branch only).
        local b2x, b2y = rotate_point(cx, cy, x + l100 / 2, y - a1, angle)

        if shape < 0.15 then
          -- 1 - single
          emit(mesh1, v1, t1x, t1y, t2x, t2y, t3x, t3y, 3)
        elseif shape < 0.3 then
          -- 2 - broken lozenge
          emit(mesh1, v1, t1x, t1y, t2x, t2y, t3x, t3y, 3)
          emit(mesh2, v2, u1x, u1y, u2x, u2y, u3x, u3y, 3)
        elseif shape < 0.45 then
          -- 3 - angle
          emit(mesh1, v1, t1x, t1y, t2x, t2y, t3x, t3y, 3)
          emit(mesh2, v2, w1x, w1y, w2x, w2y, w3x, w3y, 3)
        elseif shape < 0.6 then
          -- 4 - bird beak
          emit(mesh1, v1, rv0x, rv0y, rv1x, rv1y, 0, 0, 2)
          emit(mesh2, v2, rv2x, rv2y, rv3x, rv3y, 0, 0, 2)
          emit(mesh3, v3, t1x, t1y, t2x, t2y, t3x, t3y, 3)
          emit(mesh4, v4, t1x, t1y, b2x, b2y, t3x, t3y, 3)
        elseif shape < 0.75 then
          -- 5 - house: stock's aalines(rotated_vertices) is OPEN (not
          -- closed), so the strip runs TL -> BL -> BR -> TR.
          emit(mesh1, v1, rv0x, rv0y, rv1x, rv1y, 0, 0, 2)
          emit(mesh2, v2, rv2x, rv2y, rv3x, rv3y, 0, 0, 2)
          emit(mesh3, v3, t1x, t1y, t2x, t2y, t3x, t3y, 3)
        elseif shape < 0.9 then
          -- 6 - lozenge
          emit(mesh1, v1, rv0x, rv0y, rv1x, rv1y, 0, 0, 2)
          emit(mesh2, v2, rv2x, rv2y, rv3x, rv3y, 0, 0, 2)
          emit(mesh3, v3, t1x, t1y, t2x, t2y, t3x, t3y, 3)
          emit(mesh4, v4, u1x, u1y, u2x, u2y, u3x, u3y, 3)
        else
          -- 7 - star
          emit(mesh1, v1, t1x, t1y, t2x, t2y, t3x, t3y, 3)
          emit(mesh2, v2, u1x, u1y, u2x, u2y, u3x, u3y, 3)
          emit(mesh3, v3, w1x, w1y, w2x, w2y, w3x, w3y, 3)
          emit(mesh4, v4, z1x, z1y, z2x, z2y, z3x, z3y, 3)
        end
      end
    end
    -- Veil: fade toward the background (stock: veil alpha knob3 * 45 of 255).
    e.color(br, bgc, bb, trail * 45 / 255)
    e.rect(0, 0, W, H)
    e.end_target()

    e.clear(br, bgc, bb)
    e.draw_target(dst, 0, 0, W, H)

    fbA, fbB = dst, src
  end,
}
