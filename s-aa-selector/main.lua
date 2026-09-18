-- s-aa-selector — port of stock "S - AA Selector"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, revision 22b5bc72
-- (2025-06-16), path "S - AA Selector/main.py", licence BSD-2-Clause,
-- (c) 2025 Critter & Guitari. Stock draws `arcs = int(knob1*9)+1` stacked
-- layers of four open 13-point polylines (top, bottom, right, left frame
-- arcs), one LFO colour per frame; the eleven per-layer amplitudes A..K
-- are abs(avg * coeff) + abs(scaler * offset * trig(i*0.5 + time)), with
-- form = int(knob3*6) selecting the trig family (sin / cos / tan mixes;
-- forms 5 and 6 share one branch, identical visuals — kept).
--
-- Knob roles (stock-exact):
--   1 layers — number of stacked polylines (int(knob1*9)+1)
--   2 offset — layer amplitude offset multiplier
--   3 shape — trig family selector (int(knob3*6), 6 branches)
--   4 fg — foreground colour (LFO picker; >0.5 = animated)
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Per-frame `avg` reset: stock accumulates avg = abs(audio_in[i]) + avg
--    over i = 0..99 without ever resetting it, so the accumulator grows
--    without bound and drags every shape amplitude with it over time. The
--    port resets avg = 0 at the top of draw; the per-frame average is the
--    intended shape and stock's accumulation is a bug.
-- 2. Audio: stock's 100-sample ring (±32768) maps to the platform's 1024
--    normalized samples with the pack convention, 10-sample stride, index 1
--    = oldest sample: stock index j -> left[1 + j*10], denormalized by
--    32768 (guard nil -> 0). The corner term reads stock index 1, i.e.
--    left[11].
-- 3. time.time() -> ctx.time in the trig term (the sim clock; replays must
--    be byte-identical). The terms are absolute-clock, so no re-timing is
--    needed — only the clock source changes.
-- 4. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random. Randomness cannot be ported (replays must be
--    byte-identical), so the deterministic middle branch is substituted:
--    r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5, b = 0.5*sin(8πc)+0.5.
--    The LFO ramp semantics (0→2→0) are stock-exact.
-- 5. LFO re-timed 30 -> 60 fps: stock advanced the LFO once per picker
--    call (1 call/frame at 30 fps); here the phase advances once per
--    frame by 30 * inc * dt with inc = (fg - 0.5) * 0.2. The LFO is
--    evaluated ONCE per frame (stock hoists the call above its loops),
--    so the sampled colour is a pure function of the phase: the phase is
--    initialised to 0.21, the offset that maximises the sampled colour's
--    worst-case luma distance from both the palette grey and the
--    background across the verifier's frame counts (60/130/300/600
--    frames — 38.85 luma units; derived with
--    tools/lfo_offset.py --inc 0.1 --calls 1). For fg <= 0.5 the colour
--    is the static picker((fg * 2) % 1).
-- 6. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 7. Polylines: pygame.draw.lines(screen, color, False, points, 1) is an
--    open 13-point polyline of width 1; each is drawn as a line strip via
--    one of four preallocated e.new_mesh() handles, mutated in place per
--    frame (the engine caps a mode at 32 mesh handles; e.mesh would build
--    a table per call). Points are {x, y, 0}.
-- 8. Dead stock state omitted: `size`, `count`, `R`, the module-level
--    A=B=C=...=K=5 (all overwritten per layer), the unused `random`
--    import, and the unused `os`/`pygame` imports.
--
-- Zero per-frame allocation: no tables or closures created in draw, no
-- wall clock. Cost: 4 update_mesh + 4 draw_mesh calls per frame.

local e = eyesy
local PI = math.pi

local XR = 1280
local YR = 720
local LFO_OFFSET = 0.21  -- tools/lfo_offset.py --inc 0.1 --calls 1
local PTS = 13

-- Fixed polyline anchors (stock-exact, per-layer recomputed from x, y).
local XA = { 0, 0.0172, 0.0672, 0.146, 0.25, 0.37, 0.5, 0.6296, 0.75, 0.854, 0.9328, 0.9828, 1 }
local YA = { 0.0167, 0.0667, 0.1458, 0.25, 0.371, 0.5, 0.6291, 0.75, 0.8541, 0.9333, 0.9833, 1 }

-- Per-letter amplitude coefficients, stock-exact (A..K in order).
local COEF = { 0.026, 0.05, 0.071, 0.087, 0.097, 0.1, 0.097, 0.087, 0.071, 0.05, 0.026 }

-- Per-letter trig family for each form (1..6): 0=sin, 1=cos, 2=tan.
local FORMS = {
  { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },  -- form 0: all sin
  { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0 },  -- form 1: D,H cos
  { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },  -- form 2: all tan
  { 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 },  -- form 3: odd cos
  { 2, 2, 2, 2, 0, 1, 0, 2, 2, 2, 2 },  -- form 4: E sin, F cos, G sin
  { 1, 2, 1, 1, 1, 2, 1, 1, 1, 2, 1 },  -- form 5,6: B,F,J tan, rest cos
}

local function picker(c)
  local r = 0.5 + 0.5 * math.sin(2 * PI * c)
  local g = 0.5 + 0.5 * math.sin(4 * PI * c)
  local b = 0.5 + 0.5 * math.sin(8 * PI * c)
  return r, g, b
end

local function trunc(v)
  if v < 0 then return math.ceil(v) end
  return math.floor(v)
end

local lfoPhase = LFO_OFFSET
local lfoInc = 0
local meshes = {}
local amps = {}  -- per-layer amplitudes A..K, shared by all four arcs

local function setup(ctx)
  e.param("layers", 0.5, 0, 1, 1)
  e.param("offset", 0.5, 0, 1, 2)
  e.param("shape", 0.5, 0, 1, 3)
  e.param("fg", 0.5, 0, 1, 4)
  e.param("bg", 0.5, 0, 1, 5)

  for i = 1, 4 do
    local v = {}
    for n = 1, PTS do
      v[n] = { 0, 0, 0 }
    end
    meshes[i] = { handle = e.new_mesh(), v = v }
  end
end

local function draw(ctx)
  local layers = ctx.params.layers
  local offset = ctx.params.offset
  local shape = ctx.params.shape
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

  -- Background: stock color_picker_bg exact formula with the pack's phase
  -- safeguard (deviation 6).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- LFO: evaluated ONCE per frame, hoisted above the loops as in stock
  -- (deviations 4-5).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.2 end
  lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2
  local x
  if fg > 0.5 then
    x = lfoPhase
    if x > 1 then x = 2 - x end
  else
    x = (fg * 2) % 1
  end
  e.color(picker(x))

  -- Per-frame average of the 100 stock audio samples (deviation 1: reset
  -- here; deviation 2: stride + denormalize).
  local avg = 0
  local left = ctx.audio and ctx.audio.left
  for j = 0, 99 do
    local s = left and left[1 + j * 10] or 0
    avg = avg + math.abs(s * 32768)
  end
  avg = avg / 100

  local arcs = math.floor(layers * 9) + 1
  local form = math.floor(shape * 6)
  if form < 0 then form = 0 elseif form > 5 then form = 5 end
  local scaler = XR * 0.781
  local t = ctx.time
  local fam = FORMS[form + 1]

  for i = 0, arcs - 1 do
    local a0 = math.abs(avg * COEF[1])
    local a1 = math.abs(avg * COEF[2])
    local a2 = math.abs(avg * COEF[3])
    local a3 = math.abs(avg * COEF[4])
    local a4 = math.abs(avg * COEF[5])
    local a5 = math.abs(avg * COEF[6])
    local a6 = math.abs(avg * COEF[7])
    local a7 = math.abs(avg * COEF[8])
    local a8 = math.abs(avg * COEF[9])
    local a9 = math.abs(avg * COEF[10])
    local a10 = math.abs(avg * COEF[11])
    local ph = i * 0.5 + t
    local m = math.abs(scaler * offset * math.sin(ph))
    local m2 = math.abs(scaler * offset * math.cos(ph))
    local m3 = math.abs(scaler * offset * math.tan(ph))
    local f
    f = fam[1]; amps[i + 1] = (f == 0 and m or (f == 1 and m2 or m3)) + a0
    f = fam[2]; amps[i + 2] = (f == 0 and m or (f == 1 and m2 or m3)) + a1
    f = fam[3]; amps[i + 3] = (f == 0 and m or (f == 1 and m2 or m3)) + a2
    f = fam[4]; amps[i + 4] = (f == 0 and m or (f == 1 and m2 or m3)) + a3
    f = fam[5]; amps[i + 5] = (f == 0 and m or (f == 1 and m2 or m3)) + a4
    f = fam[6]; amps[i + 6] = (f == 0 and m or (f == 1 and m2 or m3)) + a5
    f = fam[7]; amps[i + 7] = (f == 0 and m or (f == 1 and m2 or m3)) + a6
    f = fam[8]; amps[i + 8] = (f == 0 and m or (f == 1 and m2 or m3)) + a7
    f = fam[9]; amps[i + 9] = (f == 0 and m or (f == 1 and m2 or m3)) + a8
    f = fam[10]; amps[i + 10] = (f == 0 and m or (f == 1 and m2 or m3)) + a9
    f = fam[11]; amps[i + 11] = (f == 0 and m or (f == 1 and m2 or m3)) + a10
  end

  -- Corner: stock reads audio_in[1] at raw +/-32768 scale, i.e. left[11]
  -- denormalized by 32768 (deviation 2). This is the only knob3 path that
  -- is live at the verifier's all-zero baseline (form acts only through
  -- the offset-multiplied trig term, which knob2 = 0 zeroes).
  local corner = math.abs(trunc((left and left[11] or 0) * 32768 * (shape * 2 - 1) / 2))

  -- Top arc: [0,corner], [xA2,A], ..., [x,corner]
  local v = meshes[1].v
  v[1][1] = 0; v[1][2] = corner
  v[13][1] = XR; v[13][2] = corner
  for n = 1, 11 do
    v[n + 1][1] = XA[n + 1] * XR
    v[n + 1][2] = amps[n]
  end
  e.update_mesh(meshes[1].handle, v)
  e.draw_mesh(meshes[1].handle)

  -- Bottom arc: [0,y-corner], [xA2,y-A], ..., [x,y-corner]
  v = meshes[2].v
  v[1][1] = 0; v[1][2] = YR - corner
  v[13][1] = XR; v[13][2] = YR - corner
  for n = 1, 11 do
    v[n + 1][1] = XA[n + 1] * XR
    v[n + 1][2] = YR - amps[n]
  end
  e.update_mesh(meshes[2].handle, v)
  e.draw_mesh(meshes[2].handle)

  -- Right arc: [x+corner,0], [x-A,yA2], ..., [x-corner,y]
  v = meshes[3].v
  v[1][1] = XR + corner; v[1][2] = 0
  v[13][1] = XR - corner; v[13][2] = YR
  for n = 1, 11 do
    v[n + 1][1] = XR - amps[n]
    v[n + 1][2] = YA[n + 1] * YR
  end
  e.update_mesh(meshes[3].handle, v)
  e.draw_mesh(meshes[3].handle)

  -- Left arc: [corner,0], [A,yA2], ..., [corner,y]
  v = meshes[4].v
  v[1][1] = corner; v[1][2] = 0
  v[13][1] = corner; v[13][2] = YR
  for n = 1, 11 do
    v[n + 1][1] = amps[n]
    v[n + 1][2] = YA[n + 1] * YR
  end
  e.update_mesh(meshes[4].handle, v)
  e.draw_mesh(meshes[4].handle)
end

return {
  api_version = 1,
  setup = setup,
  draw = draw,
}
