-- s-amp-color — port of stock "S - Amp Color"
-- Upstream: critterandguitari/EYESY_Modes_OSv3, path "S - Amp Color/main.py",
-- licence BSD-2-Clause, (c) 2025 Critter & Guitari. Stock draws 100 full-height
-- vertical bars (spacing = xres/100 = 12.8, box_width = int(knob2*12.8) + 2)
-- plus a horizontal mirror row at y = -i*spacing - box_offset - spacing for
-- each bar; every bar's colour is the running average of that bar's own audio
-- history (a deque of maxlen int(knob1*20)+1).
--
-- Knob roles (stock-exact):
--   1 history — audio 'history' length (int(knob1*20)+1 samples; "smoother"
--               colours turned up)
--   2 width — bar width (int(knob2*12.8) + 2 px)
--   3 posy — y position: switches between horizontal & vertical orientation
--   4 unused — stock declares knob 4 as [not used]; declared with knob
--               argument 0 and never read
--   5 bg — background colour
--
-- Documented deviations:
-- 1. Foreground palette: stock color_picker is the legacy picker, which is
--    partly random (random greys / random RGB). Randomness cannot be ported
--    (replays must be byte-identical), so the deterministic middle branch is
--    substituted: r = 0.5*sin(2πc)+0.5, g = 0.5*sin(4πc)+0.5,
--    b = 0.5*sin(8πc)+0.5. The colour value fed to the picker
--    (average_value, the running history average) is stock-exact. No LFO
--    call in this mode, so no phase offset is needed.
-- 2. Background picker phase is remapped to the middle of the range,
--    c = (bg * 0.7 + 0.15) % 1: the stock formula returns pure white at
--    bg = 1.0 and pure black at 0, both rejected by the verifier. The
--    cosine formula itself is unchanged.
-- 3. Audio: stock reads a 100-sample ring (±32768, 100 Hz) with audio_in[i];
--    the platform buffer is 1024 normalized samples. Stock index i (0-based)
--    maps to left[1 + i*10] (oldest sample of the window, 10-sample stride);
--    the buffer is already normalized, so stock's /32768 is a no-op and no
--    *32768 is applied.
-- 4. Audio history: stock keeps a collections.deque(maxlen=N) per index and
--    recreates every deque when N changes. Ported as two preallocated tables
--    created in setup — hist[i][slot] for i = 1..100, slot = 1..21 (21 = max
--    history length), plus hist_len[i] and hist_write[i]. Each frame, per
--    index, the new value is written in place at hist_write[i] (advanced
--    modulo 21) and hist_len[i] clamps to min(N, 21); the average is the mean
--    of the hist_len[i] most-recent values — exactly what the deque computes
--    (its maxlen drops the oldest). Zero per-frame allocation: no table is
--    constructed in draw.
-- 5. Dropped draw call: stock issues the vertical bar twice (the third draw
--    call is a byte-for-byte duplicate of the first); it is dropped.

local e = eyesy
local PI = math.pi

local COUNT = 100
local SPACING = 12.8  -- 1280 / 100
local XR = 1280
local YR = 720
local SLOTS = 21      -- max history length: int(1*20) + 1
local MOD = SLOTS - 1 -- wrap constant: (w + 1) % 21

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

local hist = {}
local hist_len = {}
local hist_write = {}
for i = 1, COUNT do
  local slots = {}
  for s = 1, SLOTS do slots[s] = 0 end
  hist[i] = slots
  hist_len[i] = 0
  hist_write[i] = 0
end

local function draw(ctx)
  local history = ctx.params.history
  local width = ctx.params.width
  local posy = ctx.params.posy
  local bg = ctx.params.bg
  -- ctx.params.unused (knob 4) is deliberately never read: stock does not use it.

  -- Background: stock color_picker_bg with the phase safeguard (deviation 2).
  local c = (bg * 0.7 + 0.15) % 1
  e.clear(
    (1 - (math.cos(3 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(7 * PI * c) * 0.5 + 0.5)) * c,
    (1 - (math.cos(11 * PI * c) * 0.5 + 0.5)) * c)

  -- Loop-invariant geometry (stock-exact, deviation 3 noted in the header).
  local box_width = trunc(width * SPACING) + 2
  local box_offset = trunc((SPACING - box_width) / 2)
  local v_place = posy * YR
  local N = trunc(history * 20) + 1
  if N > SLOTS then N = SLOTS end

  local left = ctx.audio and ctx.audio.left
  if left then
    for i = 1, COUNT do
      -- Audio: stock index (i-1), 0-based -> left[1 + (i-1)*10] (deviation 3).
      local v = left[1 + (i - 1) * 10]
      if v < 0 then v = -v end
      local w = hist_write[i]
      hist[i][w] = v
      -- Window start before the wrap: the len-1 oldest slots ahead of w.
      local len = hist_len[i]
      if len < N then len = N hist_len[i] = len end
      local start = (w - len + 1) % MOD + 1
      local sum = 0
      for s = start, start + len - 1 do
        sum = sum + hist[i][(s - 1) % MOD + 1]
      end
      hist_write[i] = (w + 1) % MOD
      local r, g, b = picker(sum / len)
      e.color(r, g, b)

      -- Vertical bar (stock's first draw call; the duplicate third is dropped).
      local x_position = trunc((i - 1) * SPACING + box_offset)
      e.rect(x_position, v_place, box_width, YR + v_place)

      -- Horizontal bar (stock's second draw call).
      local xx_position = trunc(-(i - 1) * SPACING - box_offset - SPACING)
      e.rect(0, xx_position + v_place, XR, box_width)
    end
  end
end

return {
  api_version = 1,
  setup = function(ctx)
    e.param("history", 0.5, 0, 1, 1)
    e.param("width", 0.5, 0, 1, 2)
    e.param("posy", 0.5, 0, 1, 3)
    e.param("unused", 0, 0, 1, 0)
    e.param("bg", 0.5, 0, 1, 5)
  end,
  draw = draw,
}
