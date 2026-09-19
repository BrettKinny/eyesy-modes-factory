-- t-ball-of-mirrors — port of stock "T - Ball of Mirrors"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- (2025-06-16), path "T - Ball of Mirrors/main.py" (37 lines)
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- This is a feedback mode. The OSv3 host fills the surface with bg_color every
-- frame (auto_clear), and draw() then does, in order:
--
--   if trig: one random filled circle, radius int(xr*.04), random centre
--   image = last_screen                       (the previous frame)
--   last_screen = screen.copy()               (bg + this frame's ball)
--   thing = scale(image, int(knob3*xr), int(knob4*yr))
--   thing = flip(thing, 1, 0)                 (horizontal mirror)
--   screen.blit(thing, (int(knob1*xr), int(knob2*yr)))
--
-- So the visible frame is the background, the ball, and one scaled + mirrored
-- copy of the previous frame — a ball of mirrors. Note the copy is taken
-- *before* the blit: the echo's source is the frame without the echo.
--
-- Knob roles (stock-exact):
--   1 x pos   — echo x = int(knob1*xr)
--   2 y pos   — echo y = int(knob2*yr)
--   3 x scale — echo width  = int(knob3*xr)   (floored, deviation 4)
--   4 y scale — echo height = int(knob4*yr)   (floored, deviation 4)
--   5 bg      — background colour (stock color_picker_bg, deviation 2)
--   Trigger   — re-randomises the ball: colour phase, then x, then y, in
--               stock's exact call order and range (deviation 3)
--
-- Scene: the pack's half-resolution ping-pong pair (PORTING-LADDER §3.2,
-- `e.target(640, 360)`) holds stock's `last_screen` — the background plus the
-- ball, and nothing else, exactly as stock's copy is taken before the echo is
-- blitted. Each frame the back target is cleared to the background and the
-- ball is drawn into it; the previous target is then blitted over the screen,
-- scaled to stock's echo rectangle (knob3*xr, knob4*yr), mirrored horizontally
-- and placed at (knob1*xr, knob2*yr). The echo rectangle is therefore in the
-- screen's coordinates, as stock's blit is, and the ball is drawn in the
-- target's own coordinates (docs/API.md: "Drawing inside a target uses that
-- target's dimensions") — half-resolution, so the ball's on-screen radius is
-- 50 px against stock's 51, the one-pixel cost of the half-resolution bridge.
-- No meshes.
--
-- Documented deviations from stock:
-- 1. Foreground palette. Stock's ball colour is color_picker(randrange(0,100)
--    *0.01) — the legacy picker is partly random (random greys for small
--    values, random RGB above 0.96), which cannot be ported (replays must be
--    byte-identical). The deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5. The
--    phase fed to it reproduces stock's value exactly —
--    trunc(e.random()*100)*0.01 is randrange(0,100)*0.01's 100-step grid — and
--    the picker returns three numbers, used as e.color(r, g, b) (the house
--    idiom of s-amp-color-circles; an earlier revision indexed the returned
--    colour as a table, which is the `attempt to index local 'color'` crash).
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg*0.7+0.15) % 1: stock's formula returns pure white at bg = 1.0 and
--    pure black at bg = 0, both rejected by the verifier. The cosine formula
--    itself is unchanged.
-- 3. The ball is seeded, persistent and audio-reactive; stock's is a one-shot
--    trigger flash. Three linked changes, all of them forced:
--    a. Stock draws the ball only on `trig`. That cannot stand here: the echo
--       rescales its source down every frame, so a ball drawn once decays
--       geometrically (radius 25 -> 25*f -> 25*f²...) and is gone within a
--       handful of frames, leaving the all-knobs-zero baseline as flat
--       background — which is what the gate rejects. The ball is therefore
--       seeded at setup and re-stamped every frame (the assignment's
--       "degenerate baseline content" class: floor the degenerate input, never
--       move a knob). Position and colour are chosen in stock's exact call
--       order (colour phase, x, y) and stock's exact range — x ∈ [int(-cscale/
--       2), xr) half-open, i.e. a + floor(random()*(xr - a)) — so replays stay
--       byte-identical; the trigger re-randomises them, which is what stock's
--       trigger does.
--    b. Stock reads no audio at all (`audio_in` is never referenced), but the
--       contract gate asserts audio reactivity whenever a mode references
--       ctx.audio, so the mode must have an audio path. The ball's radius
--       follows the input level:
--       cscale = int(TW*0.04 * (0.55 + 1.3*level)) with level =
--       clamp(ctx.audio.rms_left, 0, 1). At the verifier's default synthetic
--       level (rms 0.35) that is stock's radius, int(TW*0.04) = 25 target px
--       (50 px on screen); a quiet input shrinks the ball to 13 target px and a
--       loud one grows it to 47 (26-94 px on screen).
--       Look impact: the ball pulses with the music instead of being fixed.
--    c. The ball is drawn before the echo, in stock's order, and — as in stock
--       — the echo is composited over it rather than into the stored frame.
--       Drawing the echo into the stored frame instead (an earlier revision)
--       is fatal: the echo's source is then the *composited* frame, so a ball
--       that falls under the echo rectangle is erased from the frame and from
--       the history at once and the mode goes blank, exactly what stock's
--       copy-before-blit ordering prevents.
--    d. Stock's centre range lets the ball sit up to cscale/2 px outside the
--       frame. Because the echo mirrors the previous frame about the echo
--       rectangle's own centre line, an edge-hugging ball is clipped twice
--       over — by the frame, and then out of the echo rectangle — so the echo
--       of a ball parked on the frame edge shows a sliver or nothing at all
--       (measured: a uniform background, stddev 0.0, on the verifier's
--       knob2-mid and knob4-max runs). The centre is clamped to
--       [47, TW-47] x [47, TH-47] (47 = the largest radius the ball can be
--       drawn at, so both the ball and its echo stay fully inside). Look
--       impact: the ball never hangs off the frame edge.
-- 4. Echo scale floors (degenerate baseline). At the verifier's all-knobs-zero
--    baseline int(0*xr) and int(0*yr) are both 0, so stock's blit is a 0x0
--    rectangle: nothing is blitted and knobs 1-4 are all dead. Both scales are
--    floored at 0.35 of the screen — 448 x 252 px. The floor is not cosmetic:
--    the echo's content is the previous frame scaled down, whose only feature
--    is the ball, so the ball appears inside the echo at radius 25*0.35 =
--    8.75 target px = 17.5 screen px. Below f ≈ 0.24 that speck is smaller
--    than the verifier's 0.1 %-of-frame liveness threshold (2*pi*(25f)² < 230
--    target px), and moving the echo (knobs 1 and 2) would be invisible; 0.35
--    leaves ~2x margin. Look impact: below knob3 = knob4 = 0.35 the echo is a
--    fixed 448x252 mirrored patch instead of stock's smaller (or absent) one;
--    above it the geometry is stock-exact (int(knob3*xr), int(knob4*yr)).
--    Knobs 3 and 4 are therefore flat over their bottom 35 % — the same trade
--    the pack's trail bridge makes with its 8/255 veil alpha floor, but a
--    larger one, and it is the price of a legible all-knobs-zero baseline for
--    this mode.
-- 5. Horizontal flip. Stock does flip(thing, 1, 0) — an x mirror of the image
--    at the unchanged blit position. The API's draw_target has no flip
--    argument, so the port mirrors the blit about the rectangle's own vertical
--    centre line (translate(cx,cy) / scale(-1,1) / translate(-cx,-cy) with
--    cx = bx + sw/2), which mirrors the content in place exactly as stock does
--    and leaves the placement untouched.
-- 6. Persistence at half resolution (640x360), the pack's bridge convention
--    (PORTING-LADDER §3.2, whitney-kaleido's target size): the echo is
--    marginally softer than stock's full-resolution copy and the ball is 1 px
--    smaller on screen. Two targets (of the eight allowed), zero per-frame
--    allocation — both targets are created once in setup and reused for the
--    life of the mode, and the back target is cleared each frame, so nothing
--    accumulates across frames.
--
-- Per-frame draw calls: 1 begin_target + 1 clear (bg) + 1 color + 1 circle +
-- 1 end_target + 1 color (white) + 1 draw_target (present) + 1 push + 3 matrix
-- ops + 1 draw_target (echo) + 1 pop = 13, with 3 colour changes. No screen
-- clear is needed: the presentation blit is the full canvas and the target is
-- opaque.

local e = eyesy
local PI = math.pi

local TW = 640  -- echo source width  (half of the 1280 canvas, deviation 6)
local TH = 360  -- echo source height
local ECHO_FLOOR = 0.35  -- deviation 4: echo scale floor, see the header
local BALL_FLOOR = 2     -- target px: never emit a zero-radius circle
-- The ball's largest drawn radius (level 1.0 -> int(TW*0.04*1.85)), and so the
-- margin the ball's centre is kept from the frame edge (deviation 3d).
local BALL_MAX = math.floor(640 * 0.04 * 1.85)

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

-- Ping-pong pair holding stock's last_screen (deviations 3c, 6): created in
-- setup, half resolution, reused for the life of the mode.
local tA, tB
local flip = false

-- The ball (deviation 3): position and colour are picked once, in stock's call
-- order, and re-picked on a trigger. State is held in these upvalues so draw
-- never allocates.
local ballX, ballY, ballR, ballG, ballB = 0, 0, 0, 0, 0

-- stock's ball: colour = color_picker(randrange(0,100)*.01), then
-- x = randrange(int(-cscale/2), xr), then y = randrange(int(-cscale/2), yr) —
-- both half-open, so x ∈ [a, W). Called from setup (the seed) and on trigger,
-- with the ball clamped inside the frame (deviation 3d).
local function pick_ball(W, H)
  local cscale = trunc(W * 0.04)
  local phase = trunc(e.random() * 100) * 0.01
  ballR, ballG, ballB = picker(phase)
  local a = trunc(-(cscale / 2))
  ballX = a + math.floor(e.random() * (W - a))
  ballY = a + math.floor(e.random() * (H - a))
  if ballX < BALL_MAX then ballX = BALL_MAX
  elseif ballX > W - BALL_MAX then ballX = W - BALL_MAX end
  if ballY < BALL_MAX then ballY = BALL_MAX
  elseif ballY > H - BALL_MAX then ballY = H - BALL_MAX end
end

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height

  local k1 = ctx.params.xpos
  local k2 = ctx.params.ypos
  local k3 = ctx.params.xscale
  local k4 = ctx.params.yscale
  local k5 = ctx.params.bg

  -- Background: stock color_picker_bg with phase remapped (deviation 2).
  local c = (k5 * 0.7 + 0.15) % 1
  local br = (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c
  local bgc = (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c
  local bb = (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c

  -- Stock's echo rectangle, in the screen's coordinates, with the scale floors
  -- (deviation 4). The source is the half-resolution target, so the echo's
  -- content is scaled by sw/640 exactly as stock scales its xr-wide copy.
  local sw = k3 * W
  if sw < ECHO_FLOOR * W then sw = ECHO_FLOOR * W end
  local sh = k4 * H
  if sh < ECHO_FLOOR * H then sh = ECHO_FLOOR * H end
  local bx = trunc(k1 * W)
  local by = trunc(k2 * H)

  -- Ball radius from the input level (deviation 3b). Stock reads no audio.
  local level = 0
  local au = ctx.audio
  if au then
    local r = au.rms_left
    if r then level = r end
  end
  if level < 0 then level = 0 elseif level > 1 then level = 1 end
  local cscale = trunc(TW * 0.04 * (0.55 + 1.3 * level))
  if cscale < BALL_FLOOR then cscale = BALL_FLOOR end

  -- The trigger re-randomises the ball, in stock's call order (deviation 3a).
  if ctx.trigger then
    pick_ball(TW, TH)
  end

  local dst, src = flip and tB or tA, flip and tA or tB

  -- last_screen: the background plus this frame's ball, and nothing else —
  -- stock's screen.copy(), taken before the echo is blitted (deviation 3c).
  e.begin_target(dst)
  e.clear(br, bgc, bb)
  e.color(ballR, ballG, ballB)
  e.circle(ballX, ballY, cscale)
  e.end_target()

  -- The frame: last_screen, then the previous frame scaled, mirrored and
  -- blitted over it at stock's (knob1*xr, knob2*yr) (deviations 5, 6).
  e.color(1, 1, 1)
  e.draw_target(dst, 0, 0, W, H)
  e.push()
  local cx = bx + sw / 2
  local cy = by + sh / 2
  e.translate(cx, cy)
  e.scale(-1, 1)
  e.translate(-cx, -cy)
  e.draw_target(src, bx, by, sw, sh)
  e.pop()

  flip = not flip
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("xpos", 0.5, 0, 1, 1)
    e.param("ypos", 0.5, 0, 1, 2)
    e.param("xscale", 0.5, 0, 1, 3)
    e.param("yscale", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)
    tA = e.target(TW, TH)
    tB = e.target(TW, TH)
    pick_ball(TW, TH)  -- the seed (deviation 3a)
  end,
  draw = draw,
}
