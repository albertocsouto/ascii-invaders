-- ════════════════════════════════════════════════════════════
--  Demo module — attract-mode AI player
--  Injects simulated keystrokes into the real game engine.
--  No game state of its own; main.lua runs the actual simulation.
-- ════════════════════════════════════════════════════════════

local D      = require("data")
local LEVELS = D.LEVELS

local Demo = {}

local DEMO_DURATION  = 23     -- seconds of gameplay before attract cycle moves on
local AI_INTERVAL    = 0.40   -- seconds between keystrokes
local AI_MISS_CHANCE = 0.10   -- probability of a mistype per keystroke

local pressKey  = nil   -- callback provided by main.lua: pressKey(ch) or pressKey("\b")
local aiTimer   = 0
local demoTimer = 0

-- ────────────────────────────────────────────────────────────
--  Target selection  (operates on the real G)
-- ────────────────────────────────────────────────────────────

local function pickTarget(G)
  for _, d in ipairs(G.divers) do
    if d.alive and d.word then return d.word end
  end
  for _, b in ipairs(G.eb) do
    if b.word then return b.word end
  end
  local lvl = LEVELS[G.level]
  for r = lvl.rows, 1, -1 do
    for c = 1, lvl.cols do
      local e = G.grid[r] and G.grid[r][c]
      if e and e.word then return e.word end
    end
  end
  return nil
end

local function resolveTracked(G)
  local t = G.typed
  if #t == 0 then return nil end
  for _, d in ipairs(G.divers) do
    if d.alive and d.word and d.word:sub(1,#t)==t then return d.word end
  end
  for _, b in ipairs(G.eb) do
    if b.word and b.word:sub(1,#t)==t then return b.word end
  end
  local lvl = LEVELS[G.level]
  for r = lvl.rows, 1, -1 do
    for c = 1, lvl.cols do
      local e = G.grid[r] and G.grid[r][c]
      if e and e.word and e.word:sub(1,#t)==t then return e.word end
    end
  end
  return nil
end

-- ────────────────────────────────────────────────────────────
--  Public interface
-- ────────────────────────────────────────────────────────────

-- injectFn(ch): called with a lowercase letter to type, or "\b" to clear the buffer.
function Demo.init(injectFn)
  pressKey  = injectFn
  aiTimer   = AI_INTERVAL
  demoTimer = 0
end

function Demo.tick(dt, G)
  demoTimer = demoTimer + dt

  aiTimer = aiTimer - dt
  if aiTimer > 0 then return end
  aiTimer = AI_INTERVAL

  if #G.typed > 0 then
    local word = resolveTracked(G)
    if not word then pressKey("\b"); return end

    -- Occasional mistype: bail out and retry
    if math.random() < AI_MISS_CHANCE then
      pressKey("\b"); return
    end

    -- Type the next character of the tracked word
    pressKey(word:sub(#G.typed + 1, #G.typed + 1))
  else
    local target = pickTarget(G)
    if target then pressKey(target:sub(1, 1)) end
  end
end

function Demo.isDone()
  return demoTimer >= DEMO_DURATION
end

return Demo
