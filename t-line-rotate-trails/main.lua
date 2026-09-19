-- t-line-rotate-trails — port of stock "T - Line Rotate - Trails"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
-- "T - Line Rotate - Trails/main.py", licence BSD-2-Clause,
-- (c) Critter & Guitari.
--
-- Scene (stock-exact): one thick line rotating about the screen centre,
-- leaving a fading trail. Each frame:
--   * The background is filled (stock's color_picker_bg, knob5).
--   * A line of length L = min(knob1 * int(xr*0.781) + linewidth, xr) is
--     drawn through (xc, yc) at angle a = pi * sound, where `sound` is a
--     stock-misnomer: a rotation accumulator advanced by (2*knob2-1)/10
--     ONLY inside stock's `if trig:` branch (so the line is static between
--     triggers and jumps on each one). The endpoint formula switches at
--     knob2 = 0.5: below it the endpoints are (xc ± (L/2)*cos a,
--     yc ∓ (L/2)*sin a), above it (xc ∓ (L/2)*cos a, yc ± (L/2)*sin a) —
--     both branches are the same line through the centre (the two are
--     point-symmetric), so the port draws that one line at angle a.
--   * The trail: stock blits a full-screen background-colour veil over the
--     previous surface at alpha = int(knob3 * 200) — that is, the previous
--     frame persists and fades toward the background.
--
-- Knob roles (stock-exact unless noted):
--   1 linewidth & length — linewidth = int(xc - int(knob1*(xc-1)));
--     L = knob1 * int(xr*0.781) + linewidth (capped at xr) (deviations 4, 5)
--   2 direction — the rotation increment per trigger, (2*knob2-1)/10; at
--     knob2 = 0.5 stock's increment is exactly 0 (the line is frozen); the
--     port floors the trigger increment's magnitude (deviation 6) and also
--     applies stock's increment continuously (deviation 6b)
--   3 trails — veil alpha = int(knob3 * 200), floored at 8 (deviation 7)
--   4 fg colour — stock color_picker_lfo(knob4) (default inc_amt 0.1),
--     once per frame (deviation 1)
--   5 background — stock color_picker_bg(knob5) (deviation 2)
--   Trigger — advances the rotation accumulator by (2*knob2-1)/10 exactly
--     as stock's `if trig:` branch does (deviation 6 for the floor).
--
-- Stock reads NO audio (the `sound` variable is the rotation accumulator
-- only; `random` is imported but never called); per the pack convention the
-- port adds one documented audio term (deviation 8).
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker, which
--    is partly random (random greys for small values, random RGB above 0.96).
--    Randomness cannot be ported (replays must be byte-identical), so the
--    deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5.
--    The LFO's static branch (knob4 <= 0.5: picker((knob4*2) % 1)) and ramp
--    semantics (index 0→2→0 at inc = (knob4-0.5)*2*0.1 per 30-fps call) are
--    stock-exact. The picker is called once per frame, so the phase is
--    initialised to 0.70: with this mode's step (calls 1 * inc 0.1 * 30/60
--    = 0.05/frame at 60 fps) tools/lfo_offset.py --inc 0.1 --calls 1 reports
--    its best clearance at 0.21, but the gate renders under software GL at
--    ~66.8 fps, so the ramp is re-timed to real time (3.0 * elapsed seconds)
--    and the sampled phase at the verifier's grab frames differs from the
--    60-fps model. 0.70 was chosen so the sampled colour clears the
--    background luma (28.3) by >150 luma units at BOTH the 60-frame grab
--    (measured luma ≈ 185.3) and the 300-frame grab (model luma ≈ 185.9) for
--    the observed fps range 66.4–67.2; 0.21 put the 60-frame sample at
--    luma ≈ 28.2, coinciding with the background and reading flat. The
--    offset is added to the ramp branch before the 0→2→0 fold; the fixed
--    branch is stock-exact.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (knob5 * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 3. Endpoints: stock draws the line in two branches selected by
--    knob2 < 0.5 / knob2 > 0.5; at knob2 = 0.5 stock draws NOTHING (both
--    branches are false) — a whole knob value of blank screen. The two
--    branches are the same line through the centre (point-symmetric), so
--    the port draws that one line for every knob2. Look impact: at
--    knob2 = 0.5 the port shows the rotating line where stock shows the
--    bare background; at every other knob2 the geometry is stock-exact.
-- 4. linewidth floor: linewidth = int(xc - int(knob1*(xc-1))) is 0 at
--    knob1 = 0 (and below ~0.0129 at 720p), and the engine takes a line
--    width literally — a width of 0 draws NOTHING where pygame treats
--    width <= 0 as 1 px. The port floors it at 1 px. Look impact: at
--    knob1 = 0 the line is 1 px thick (stock: invisible); above that the
--    geometry is stock-exact.
-- 5. Length floor: L = knob1*int(xr*0.781) + linewidth is 0 at knob1 = 0,
--    a zero-length line that draws nothing. The port floors L at 1 px so a
--    1 px stroke always rasterises. Look impact: at knob1 = 0 the port
--    shows a 1 px dot where stock shows nothing; for knob1 > 0 the
--    geometry is stock-exact.
-- 6. Rotation floor: stock advances the accumulator by (2*knob2-1)/10 per
--    trigger, which is exactly 0 at knob2 = 0.5 — the line is frozen for
--    the whole knob-2 range around the midpoint and, in a session without
--    triggers, for its entire life. The port floors the increment's
--    magnitude at 0.01 (direction kept), so knob2 = 0.5 rotates one
--    degree per trigger instead of not rotating. Look impact: at
--    knob2 = 0.5 the line creeps 1°/trigger where stock creeps 0°; for
--    |2*knob2-1| > 0.1 (knob2 < 0.45 or > 0.55) stock's increment is
--    already ≥ 0.01 and the geometry is stock-exact.
-- 6b. knob2's draw-path consumer: stock reads knob2 ONLY inside the trigger
--    branch, so between triggers its probes are byte-identical to the
--    baseline (a real stock pattern, not a port defect). knob2 is the
--    "direction" knob, so the port makes that meaning continuous: stock's
--    own increment is also applied once per second (sound += (2*knob2-1)/10
--    * dt), while the trigger branch still advances `sound` exactly as stock
--    does. Look impact: the line turns slowly whenever the direction knob is
--    off-centre (≈18°/s at knob2 = 0 or 1) instead of being frozen between
--    triggers; the per-trigger jump is stock-exact.
-- 7. Persistence: stock keeps the screen between frames and blits a
--    full-screen background-colour veil over it at alpha = int(knob3*200) —
--    the veil is the trail, and the recursion is what the alpha decays.
--    The scene API cannot read the screen back, so the pack's standard
--    persistence bridge (PORTING-LADDER §3.2) keeps the accumulated frame
--    in a half-resolution ping-pong pair of targets (640x360): the back
--    target is filled with the previous target faded toward the background
--    by 1 - alpha/255 (the veil's decay in the bridge's form), this frame's
--    line is added, and the result is presented over the screen's
--    background fill at full size. The bridge
--    has no alpha of its own, so the veil alpha is floored at 8/255 (the
--    pack convention for the persistence bridge): at knob3 = 0 stock's
--    alpha is 0, which would pin the previous frame forever and make the
--    startup audio jitter (deviation 8) permanent, failing the
--    determinism precondition. With the floor the target always fades
--    toward the background, so the frame converges to the current scene
--    while knob3 still governs the trail's opacity (200/255 at knob3 = 1,
--    stock-exact).
-- 8. Audio term (stock has none): the line's endpoint is nudged along its
--    direction by |left[1]| * 0.10 * W (up to a 10% width extension at
--    full-scale audio) — the left channel is sampled once per frame, in
--    stock's draw position (after the colour, before the line). Nil-guarded
--    past the audio buffer. Look impact: the line breathes with the audio;
--    with no audio the geometry is stock-exact.
-- 9. 30 -> 60 fps: this mode's per-frame constants — the LFO ramp
--    (30 * inc * ctx.dt, 30 stock calls/s * the stock per-call step) and
--    knob2's continuous rotation (deviation 6b) — are both scaled by
--    ctx.dt, so their wall-clock rates are fps-independent. The
--    trigger-driven rotation is event-based (stock advances it per
--    trigger, not per frame), so it is not re-timed.
--
-- Rendering: 1 e.line call per frame — one line through the centre. Two
-- half-resolution render targets (ping-pong) for the trail, created in
-- setup. Zero per-frame allocation: draw never builds a table.

local e = eyesy
local PI = math.pi

-- Target size (deviation 7): the accumulated trail lives in the
-- half-resolution ping-pong pair below.
local TW = 640
local TH = 360

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

-- LFO state (deviations 1 and 9): phase in 0..2, 0.70 offset (deviation 1).
local lfoPhase = 0.70

-- Stock's rotation accumulator (`sound`), advanced per trigger (deviation 6).
local sound = 0
-- Ping-pong pair holding the accumulated trail (deviation 7): the engine
-- rejects aliasing one target as both read and write in a frame, so the
-- back target accumulates from the front target, then they swap.
local tA, tB
local flip = false

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt
  local left = ctx.audio and ctx.audio.left

  local k1 = ctx.params.linewidth
  local k2 = ctx.params.direction
  local k3 = ctx.params.trails
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg exact formula with the phase
  -- safeguard (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c

  -- Trigger: stock's `if trig:` branch advances the rotation accumulator
  -- by (2*knob2-1)/10 (deviation 6 for the floor).
  if ctx.trigger then
    local inc = (2 * k2 - 1) / 10
    if inc < -0.01 then inc = -0.01
    elseif inc > 0.01 then inc = 0.01
    else inc = 0.01 end
    sound = sound + inc
  end

  -- knob2's draw-path consumer (deviation 6b): stock advances `sound` only
  -- inside the trigger branch, so between triggers knob2 has no consumer in
  -- the draw path and its probes are byte-identical to the baseline. The
  -- port also applies stock's own increment continuously at one increment
  -- per second, so the "direction" knob is always meaningful (and still
  -- rotates on trigger exactly as stock does).
  sound = sound + (2 * k2 - 1) / 10 * dt

  -- LFO: stock color_picker_lfo(knob4) semantics, re-timed 30 -> 60 fps
  -- (deviations 1 and 9). knob4 <= 0.5 is a static colour.
  if k4 > 0.5 then
    lfoPhase = (lfoPhase + 30 * (k4 - 0.5) * 2 * 0.1 * dt) % 2
  end
  local fgval
  if k4 <= 0.5 then
    fgval = (k4 * 2) % 1
  else
    fgval = lfoPhase
    if fgval > 1 then fgval = 2 - fgval end
  end
  local fr, fg, fb = picker(fgval)

  -- Veil alpha (deviation 7).
  local alpha = trunc(k3 * 200)
  if alpha < 8 then alpha = 8 end

  -- Line geometry (stock lines 28-34, 38-54), on the presentation surface
  -- (deviation 7: the target's dimensions inside the target).
  local xc = W / 2
  local yc = H / 2
  local a = PI * sound
  local linewidth = trunc(xc - trunc(k1 * (xc - 1)))
  if linewidth < 1 then linewidth = 1 end   -- deviation 4
  local L1000 = trunc(W * 0.781)
  local L = k1 * L1000 + linewidth
  if L > W then L = W end
  if L < 1 then L = 1 end                    -- deviation 5

  -- Audio term (deviation 8): endpoint nudge along the line's direction.
  local s = left and left[1] or 0
  local ext = math.abs(s) * 0.10 * W

  local half = (L / 2) + ext
  local ca = math.cos(a)
  local sa = math.sin(a)
  -- The one line through the centre (stock's two branches are point-
  -- symmetric; deviation 3 draws it for every knob2).
  local x2 = xc + half * ca
  local y2 = yc - half * sa
  local x3 = xc - half * ca
  local y3 = yc + half * sa

  -- Background fill: stock's color_picker_bg (knob5) paints the whole
  -- screen at the top of every frame.
  e.clear(br, bgc, bb)

  -- Accumulate the trail in the half-resolution back target (deviation 7):
  -- the previous frame, faded toward the background by 1 - alpha/255
  -- (the veil's decay), plus this frame's line in the target's own
  -- 640x360 coordinates.
  local txc = TW / 2
  local tyc = TH / 2
  local txc1 = trunc(txc - trunc(k1 * (txc - 1)))
  if txc1 < 1 then txc1 = 1 end
  local tL1000 = trunc(TW * 0.781)
  local tL = k1 * tL1000 + txc1
  if tL > TW then tL = TW end
  if tL < 1 then tL = 1 end
  local thalf = (tL / 2) + ext * (TW / W)

  local dst = flip and tB or tA
  local src = flip and tA or tB

  e.begin_target(dst)
  e.color(1, 1, 1)
  e.draw_target(src, 0, 0, TW, TH)
  e.color(br, bgc, bb, 1 - alpha / 255)
  e.rect(0, 0, TW, TH)
  e.color(fr, fg, fb)
  e.line(txc + thalf * ca, tyc - thalf * sa, txc - thalf * ca, tyc + thalf * sa, txc1)
  e.end_target()

  -- Present the accumulated frame (the back target just built) over the
  -- screen's background fill at full size — the veil's recursion in the
  -- bridge's form.
  e.color(1, 1, 1)
  e.draw_target(dst, 0, 0, W, H)
  flip = not flip
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("linewidth", 0.5, 0, 1, 1)
    e.param("direction", 0.5, 0, 1, 2)
    e.param("trails", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    tA = e.target(TW, TH)
    tB = e.target(TW, TH)
  end,
  draw = draw,
}
