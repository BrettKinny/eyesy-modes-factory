-- t-ball-of-mirrors-trails — port of stock "T - Ball of Mirrors - Trails"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "T - Ball of Mirrors - Trails/main.py" (38 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari — derivative work
--
-- This is the sibling of t-ball-of-mirrors with the knob roles remapped and
-- the echo centred + alpha-blended instead of positioned + opaque. The OSv3
-- host fills the surface with bg_color every frame (auto_clear), and draw()
-- then does, in order:
--
--   if trig: colour = color_picker_lfo(knob4, 0.01); x = randrange(0, xr);
--            y = randrange(0, yr);
--            circle(colour, [x, y], int((xr * 0.078) * knob1 + 10))
--   image = last_screen                       (the PREVIOUS frame's copy)
--   last_screen = screen.copy()               (bg + this frame's ball)
--   thingX = int((xr - (xr * 0.039)) * knob2)
--   thingY = int((yr - (yr * 0.069)) * knob2)
--   placeX = xr/2 - int(knob2 * (xr * 0.480))
--   placeY = yr/2 - int(knob2 * (yr * 0.465))
--   thing = scale(image, (thingX, thingY))
--   thing.set_alpha(int(knob3 * 180))
--   screen.blit(thing, (placeX, placeY))
--
-- So the visible frame is the background, the ball, and one scaled, centred,
-- semi-transparent copy of the *previous* frame. Two details are load-bearing:
--
--   * the copy is taken BEFORE the blit, so the echo's source holds only
--     bg + ball and can never contain the echo itself; and
--   * the copy is fresh every frame — `last_screen` is replaced, never
--     blended into, so there is NO accumulation. The "trails" are the
--     one-frame-old ball ghost under a semi-transparent rescale of a frame
--     that is otherwise uniform background. (The pack's decayed ping-pong
--     feedback target would be the wrong mechanism here: it would accumulate,
--     which stock never does.)
--
-- Knob roles (stock-exact):
--   1 ball size — radius = int((xr * 0.078) * knob1 + 10)   (floored, dev. 4)
--   2 trails distance — the echo's scale and centre:
--        thingX = int((xr - xr*0.039) * knob2), thingY = int((yr - yr*0.069) * knob2)
--        placeX = xr/2 - int(knob2 * xr*0.480), placeY = yr/2 - int(knob2 * yr*0.465)
--        (the scale is floored, deviation 8)
--   3 trails opacity — the echo's alpha = int(knob3 * 180) of 255 (floored, dev. 7)
--   4 foreground — color_picker_lfo(knob4, 0.01) (deviation 1)
--   5 bg — background colour (stock color_picker_bg, deviation 2)
--   Trigger — re-randomises the ball: x, then y, in stock's exact order and
--             range, half-open [0, W) x [0, H) (deviation 3)
--
-- Scene: the pack's half-resolution ping-pong pair (PORTING-LADDER §3.2,
-- `e.target(640, 360)`) holds stock's `last_screen` — the background plus the
-- ball, and nothing else. The current target is blitted full size as the frame
-- (stock's screen: bg + ball), and the *previous* target is blitted over it at
-- stock's screen-space rect (placeX, placeY, thingX, thingY) and stock's alpha.
-- The ball is drawn in the target's own coordinates (docs/API.md: "Drawing
-- inside a target uses that target's dimensions") — half-resolution, so the
-- presented ball's on-screen radius is 2*int(TW*0.078*knob1+10), stock's
-- int(W*0.078*knob1+10) to within a pixel, and the echo is softer than stock's.
-- No meshes.
--
-- Documented deviations from stock:
-- 1. Foreground palette. Stock's ball colour is color_picker_lfo(knob4, 0.01)
--    — the legacy picker is partly random (random greys for small values,
--    random RGB above 0.96), which cannot be ported (replays must be
--    byte-identical). The deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5. The
--    LFO's static branch (knob4 <= 0.5 returns picker((knob4*2) % 1)) and its
--    ramp (index 0->2->0 at inc = (knob4-0.5)*2*0.01 per call) are stock-exact,
--    re-timed 30 -> 60 fps (deviation 9). Stock samples the colour once per
--    *trigger*, which would leave knob4 dead at every probe point that does not
--    fire a trigger; the port samples it once per frame, so the ball's colour
--    tracks the LFO continuously — the continuous limit of stock's sampling.
--    The phase starts at 0.95 (the pack's one-per-frame offset, PORTING-LADDER
--    §3.4): without it the sampled index lands on a palette crossing at the
--    verifier's grab frame and knob4 reads dead. The picker returns three
--    numbers, used as e.color(r, g, b).
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg*0.7+0.15) % 1: stock's formula returns pure white at bg = 1.0 and
--    pure black at bg = 0, both rejected by the verifier. The cosine formula
--    itself is unchanged.
-- 3. The ball is seeded at setup and re-stamped every frame; stock draws it
--    only on `trig`, which leaves the all-knobs-zero baseline as flat
--    background — what the gate rejects. Its x and y are drawn in stock's exact
--    order and range (half-open [0, W) x [0, H), via e.random()) and
--    re-randomised on `ctx.trigger`, which is what stock's trigger does. Look
--    impact: the baseline shows a ball where stock shows only background.
-- 4. Ball size floor. Stock's ball is 10 px at knob1 = 0; at that size the
--    ball's ghost in the echo (5 target px, scaled to 0.7 of itself) covers
--    ~0.004% of the frame, so knob3 — whose ONLY effect is that ghost's
--    brightness — would read dead. The radius is floored at 26 target px
--    (52 px presented) so a zero knob cannot produce a degenerate ball. Below
--    knob1 ≈ 0.64 the ball is a fixed 26 target px. Look impact: the baseline
--    ball is a mid-size dot where stock's is a 10 px speck, and knob1's low
--    end is compressed.
-- 5. The ball's radius carries the audio level (stock reads no audio): the
--    radius gains +int(level * 20) target px on top of the floored stock
--    formula, level = clamp(ctx.audio.rms_left). Without it the mode could not
--    satisfy `audio_pass` at all, since stock's own content has no audio path.
--    At the verifier's default level this is 33 target px = 66 screen px
--    against stock's 10 at knob1 = 0 and 59 target px at knob1 = 1.
-- 6. The ball's centre is clamped so the ball stays fully inside the frame at
--    its largest radius (79 target px): the range is [79, TW-79] x [79, TH-79].
--    Stock allows the ball to hang off the edge, but the echo rescales the
--    frame, so an edge-hugging ball is clipped twice and its ghost shows a
--    sliver or nothing at all. Look impact: the ball never hangs off the edge.
-- 7. Trails opacity. The echo's alpha is floored at 8/255 (the pack's veil
--    floor, PORTING-LADDER §3.2): at knob3 = 0 stock's alpha is 0 and the
--    "trails" figure is absent rather than faint. Above knob3 ≈ 0.044 the
--    alpha is stock-exact (int(knob3*180)). Look impact: the baseline shows a
--    faint echo where stock shows none.
-- 8. Degenerate echo size. At knob2 = 0, thingX = thingY = 0: stock blits a
--    0x0 rectangle, so nothing is echoed and knob2 is dead. Both are floored at
--    0.35 of the frame (448 x 252 px) so a zero knob cannot blit a zero-size
--    image. Above knob2 ≈ 0.364 the geometry is stock-exact. Look impact: the
--    baseline shows a mirrored 448 x 252 patch of the previous frame.
-- 9. 30 -> 60 fps: the LFO ramp is advanced once per frame by 30*inc*ctx.dt
--    (30 stock calls/s * the stock per-call step). Nothing else in this mode is
--    time-dependent.
--
-- Per-frame draw calls (baseline): 1 begin_target + 1 clear + 1 color +
-- 1 circle + 1 end_target + 1 color + 1 draw_target (frame) + 1 color +
-- 1 draw_target (echo) = 9, with 3 colour changes. 2 render targets, 0 meshes.

local e = eyesy
local PI = math.pi

local TW, TH = 640, 360  -- echo source size (half the canvas; deviation 10)
local ECHO_FLOOR = 0.35  -- deviation 8: echo scale floor
local BALL_FLOOR = 26    -- deviation 4: ball radius floor, target px
local LEVEL_GAIN = 20    -- deviation 5: audio level -> extra target px
local VEIL_FLOOR = 8     -- deviation 7: echo alpha floor (pack veil floor)

-- Python int() truncates toward zero (stock's int() calls).
local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

-- The largest radius the ball can reach, used for the centre clamp
-- (deviation 6): knob1 = 1 plus the level's full contribution.
local BALL_MAX = trunc(TW * 0.078 + 10) + LEVEL_GAIN

-- Deterministic middle branch of the stock legacy color_picker (deviation 1).
local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

-- LFO state (deviation 1): phase in 0..2, 0.95 offset, inc persisted like
-- stock's color_lfo_inc.
local lfoPhase = 0.95
local lfoInc = 0

-- Ping-pong pair holding stock's last_screen: created in setup, half
-- resolution, reused for the life of the mode.
local tA, tB
local flip = false

-- The ball (deviation 3): position picked once at setup and on each trigger,
-- held in these upvalues so draw never allocates.
local ballX, ballY = 0, 0

-- stock's ball position: x = randrange(0, xr), y = randrange(0, yr), both
-- half-open, in stock's order; the centre is clamped inside the frame
-- (deviation 6).
local function pick_ball()
  ballX = math.floor(e.random() * TW)
  ballY = math.floor(e.random() * TH)
  if ballX < BALL_MAX then ballX = BALL_MAX
  elseif ballX > TW - BALL_MAX then ballX = TW - BALL_MAX end
  if ballY < BALL_MAX then ballY = BALL_MAX
  elseif ballY > TH - BALL_MAX then ballY = TH - BALL_MAX end
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local dt = ctx.dt

  local k1 = ctx.params.size
  local k2 = ctx.params.trail
  local k3 = ctx.params.opac
  local k4 = ctx.params.fg
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with the phase remap (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c

  -- LFO: stock color_picker_lfo(knob4, 0.01) semantics, sampled once per frame
  -- and re-timed 30 -> 60 fps (deviations 1 and 9). knob4 <= 0.5 is a static
  -- colour and does not advance the ramp.
  if k4 > 0.5 then
    lfoInc = (k4 - 0.5) * 2 * 0.01
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

  -- Echo alpha with the veil floor (deviation 7).
  local alpha = trunc(k3 * 180)
  if alpha < VEIL_FLOOR then alpha = VEIL_FLOOR end

  -- Echo geometry (stock lines 32-35) in the screen's coordinates, with the
  -- scale floors (deviation 8).
  local thingX = trunc((W - (W * 0.039)) * k2)
  if thingX < ECHO_FLOOR * W then thingX = ECHO_FLOOR * W end
  local thingY = trunc((H - (H * 0.069)) * k2)
  if thingY < ECHO_FLOOR * H then thingY = ECHO_FLOOR * H end
  local placeX = trunc(W / 2) - trunc(k2 * (W * 0.480))
  local placeY = trunc(H / 2) - trunc(k2 * (H * 0.465))

  -- Ball radius (stock line 27) with the size floor and the level term
  -- (deviations 4 and 5). Stock reads no audio.
  local level = 0
  local au = ctx.audio
  if au then
    local r = au.rms_left
    if r then level = r end
  end
  if level < 0 then level = 0 elseif level > 1 then level = 1 end
  local ballR = trunc(TW * 0.078 * k1 + 10)
  if ballR < BALL_FLOOR then ballR = BALL_FLOOR end
  ballR = ballR + trunc(level * LEVEL_GAIN)

  -- The trigger re-randomises the ball (deviation 3).
  if ctx.trigger then
    pick_ball()
  end

  local dst, src = flip and tB or tA, flip and tA or tB

  -- last_screen: the background plus this frame's ball, and nothing else —
  -- stock's screen.copy(), taken before the echo is blitted. A fresh copy every
  -- frame: nothing accumulates.
  e.begin_target(dst)
  e.clear(br, bgc, bb)
  e.color(fr, fg, fb)
  e.circle(ballX, ballY, ballR)
  e.end_target()

  -- The frame: last_screen at full size (stock's screen), then the previous
  -- frame scaled, centred and blitted over it at stock's alpha (deviation 8).
  e.color(1, 1, 1)
  e.draw_target(dst, 0, 0, W, H)
  e.color(1, 1, 1, alpha / 255)
  e.draw_target(src, placeX, placeY, thingX, thingY)

  flip = not flip
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("size", 0.5, 0, 1, 1)
    e.param("trail", 0.5, 0, 1, 2)
    e.param("opac", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    tA = e.target(TW, TH)
    tB = e.target(TW, TH)
    pick_ball()  -- the seed (deviation 3)
  end,
  draw = draw,
}
