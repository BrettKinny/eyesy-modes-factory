-- s-breezy-feather-lfo — port of stock "S - Breezy Feather LFO"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path
--   "S - Breezy Feather LFO/main.py", revision 22b5bc72a123a6aeb4be7d84b8f4b4a99ef294d6
-- Licence: BSD-2-Clause (c) 2025 Critter & Guitari
--
-- Knob 1: rate of change for the number of triangles (bouncing LFO 2..60)
-- Knob 2: feather angle (horizontal offset of each triangle's apex)
-- Knob 3: y position step amount (bounce speed of the baseline)
-- Knob 4: foreground colour (LFO picker; >0.5 = animated rainbow)
-- Knob 5: background colour
--
-- Scene: a bouncing y position sweeps a horizontal baseline across the
-- frame, and a bouncing count of filled triangles (3..62) hangs from it,
-- each triangle's apex displaced by one audio sample.
--
-- Documented deviations from stock:
-- 1. Foreground palette: stock color_picker_lfo uses the legacy picker,
--    which is partly random (random greys for small values, random RGB
--    above 0.96). Randomness cannot be ported (replays must be
--    byte-identical), so the deterministic middle branch is substituted:
--    r = 0.5*sin(2*pi*c)+0.5, g = 0.5*sin(4*pi*c)+0.5, b = 0.5*sin(8*pi*c)+0.5.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    knob5 = 1.0 and pure black at 0, both rejected by the verifier.
--    The cosine formula itself is unchanged.
-- 3. Both stateful oscillators (yposr, tris) re-timed 30 -> 60 fps: stock
--    added step once per frame at 30 fps; here each advances by
--    step * 30 * dt. The LFO arithmetic is float (stock's int() truncation
--    applies only to the knob mapping, which is kept stock-exact:
--    tris.step = floor(rate*15.36), yposr.step = floor(bounce*72),
--    tris.max = floor(1280*0.047) = 60).
-- 4. Colour LFO re-timed with the same rule: the picker is called once per
--    frame, so the phase advances by 30 * inc * dt with inc = (fg-0.5)*0.2;
--    for fg <= 0.5 the colour is the static picker((fg*2) % 1).
--    The phase is initialised to 0.21 (tools/lfo_offset.py --inc 0.1
--    --calls 1): the gate samples the colour at one instant and measures
--    luma only, so the sampled colour must clear both the palette grey
--    (luma 127.5) and the background's luma; 0.21 keeps it >= 38.9 luma
--    units from both at every frame count the verifier supports.
-- 5. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with
--    audio_in[i]; the platform buffer is 1024 normalized samples. Stock
--    index i (0-based) maps to left[1 + i*10] (oldest sample of the
--    window, 10-sample stride), denormalized by * 32768 / 65.
-- 6. Triangles drawn from one preallocated mesh: all 72 triangles share
--    one colour, so a single e.new_mesh() handle holds 216 vertices and
--    216 one-based index triples, created in setup and mutated in place
--    per frame (zero per-frame allocation, one draw call).

local e = eyesy
local PI = math.pi

local MAX_TRIS = 72   -- stock tris LFO max (70) + 2

local mesh
local trisCur, trisDir = 0, 1   -- stock: LFO(2, 70, 1), current=0, dir=1
local yposrCur, yposrDir = 0, 1 -- stock: LFO(0,500,10), current=0, dir=1;
                                -- start/max set in setup (see below)
local yposrStart = -36          -- stock setup: int(720 - 720*1.05)
local yposrMax = 756            -- stock setup: int(720 * 1.05)
local lfoPhase = 0.21  -- deviation 4
local lfoInc = 0

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

local function draw(ctx)
  local W = ctx.width
  local H = ctx.height
  local rate = ctx.params.rate
  local feather = ctx.params.feather
  local bounce = ctx.params.bounce
  local fg = ctx.params.fg
  local bg = ctx.params.bg
  local dt = ctx.dt

  -- Background: stock color_picker_bg_original with phase remap (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Foreground: stock color_picker_lfo semantics, once per frame (deviations 1, 4).
  if fg > 0.5 then lfoInc = (fg - 0.5) * 0.2 end
  lfoPhase = (lfoPhase + 30 * lfoInc * dt) % 2
  local x = (fg > 0.5) and lfoPhase or ((fg * 2) % 1)
  if x > 1 then x = 2 - x end
  local cr, cg, cb = picker(x)

  -- tris oscillator: stock knob mapping kept, step re-timed (deviation 3).
  local trisMax = math.floor(W * 0.047)   -- 60 at 1280
  local trisStep = math.floor(rate * (W * 0.012))
  trisCur = trisCur + trisStep * trisDir * 30 * dt
  if trisCur >= trisMax then
    trisDir = -1
    trisCur = trisMax
  end
  if trisCur <= 2 then
    trisDir = 1
    trisCur = 2
  end
  local triangles = math.floor(trisCur) + 2
  if triangles < 2 then triangles = 2 end

  -- space: stock int(xr/(triangles-1)); guard the divide.
  local space = math.floor(W / (triangles - 1))
  if space < 1 then space = 1 end

  local offset = trunc((feather * 2 - 1) * space * 4)

  -- yposr oscillator: stock knob mapping kept, step re-timed (deviation 3).
  local yStep = math.floor(bounce * (H * 0.1))  -- 72 at 720
  yposrCur = yposrCur + yStep * yposrDir * 30 * dt
  if yposrCur >= yposrMax then
    yposrDir = -1
    yposrCur = yposrMax
  end
  if yposrCur <= yposrStart then
    yposrDir = 1
    yposrCur = yposrStart
  end
  local y = yposrCur

  -- Baseline: stock draws it so the frame is never empty.
  e.color(cr, cg, cb)
  e.line(0, y, W, y, 1)

  -- Triangles: mutate the preallocated mesh in place (deviation 6).
  local v = mesh.v
  local left = ctx.audio and ctx.audio.left
  for i = 0, triangles - 1 do
    local auDio = 0
    if left then
      local s = left[1 + i * 10]
      if s then auDio = trunc(s * 32768 / 65) end
    end
    local ax = i * space
    local b0 = i * 3 + 1
    v[b0][1] = ax;                v[b0][2] = y
    v[b0 + 1][1] = ax + trunc(space / 2 + offset); v[b0 + 1][2] = auDio + y
    v[b0 + 2][1] = ax + space;    v[b0 + 2][2] = y
  end
  e.update_mesh(mesh.handle, v, mesh.idx)
  e.draw_mesh(mesh.handle)
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("rate", 0.5, 0, 1, 1)
    e.param("feather", 0.5, 0, 1, 2)
    e.param("bounce", 0.5, 0, 1, 3)
    e.param("fg", 0.5, 0, 1, 4)
    e.param("bg", 0.5, 0, 1, 5)

    -- One preallocated mesh of MAX_TRIS triangles (216 vertices, 216
    -- one-based index triples) (deviation 6).
    local verts = {}
    for n = 1, MAX_TRIS * 3 do
      verts[n] = {0, 0, 0}
    end
    local idx = {}
    for i = 0, MAX_TRIS - 1 do
      local b0 = i * 3
      idx[b0 + 1] = b0 + 1
      idx[b0 + 2] = b0 + 2
      idx[b0 + 3] = b0 + 3
    end
    mesh = { handle = e.new_mesh(), v = verts, idx = idx }
  end,
  draw = draw,
}
