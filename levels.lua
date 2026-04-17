-- ════════════════════════════════════════════════════════════
--  Level definitions
--  Difficulty presets and the ordered LEVELS array.
-- ════════════════════════════════════════════════════════════

local Bonus = require "bonus"

-- ── Difficulty presets ─────────────────────────────────────
-- Each preset bundles the six speed-related parameters.
-- A level entry can override any field individually; missing
-- fields fall back to the preset, then to CFG defaults.
local DIFFICULTY = {
  easy   = { ebSpeed = 65,  eShootInt = 2.5, formSpd = 30, dvSpeed = 130, diveInt = 5.5, maxDivers = 1 },
  medium = { ebSpeed = 110, eShootInt = 2.0, formSpd = 38, dvSpeed = 155, diveInt = 4.2, maxDivers = 2 },
  hard   = { ebSpeed = 160, eShootInt = 1.4, formSpd = 55, dvSpeed = 190, diveInt = 3.0, maxDivers = 3 },
}

-- ── Level entries ──────────────────────────────────────────
-- Required fields for every entry:
--   title, subtitle, hint
--   rows, cols, rowTypes          — formation shape; rows=0 for boss/bonus
--   bulletPool, enemyPool         — word pools (enemyPool may be nil)
--   winBy                         — "kill" | "deflect" | "boss" | "bonus"
--   winCount                      — deflection target (0 for non-deflect levels)
--   divers                        — boolean
--   difficulty                    — "easy" | "medium" | "hard"
--
-- Optional speed overrides (any omitted field uses the preset value):
--   ebSpeed, eShootInt, formSpd, dvSpeed, diveInt, maxDivers

local LEVELS = {
  -- ── Level 1 ────────────────────────────────────────────────
  {
    title      = "LEVEL  1",
    subtitle   = "shoot the invaders",
    hint       = "type the letter on each enemy to shoot — or on bullets to deflect",
    rows = 1, cols = 7,
    bulletPool = "alpha",
    enemyPool  = "digram",
    winBy      = "kill",  winCount = 0,
    divers     = false,
    rowTypes   = {"grunt"},
    difficulty = "easy",
    -- preserve current formation speed (easy preset uses 30; original was 38)
    formSpd    = 38,
    ebSpeed    = 60,   eShootInt = 2.2,
  },

  -- ── Level 2 ────────────────────────────────────────────────
  {
    title      = "LEVEL  2",
    subtitle   = "shoot the invaders",
    hint       = "type the 3-letter word on each enemy",
    rows = 2, cols = 6,
    bulletPool = "digram",
    enemyPool  = "tri",
    winBy      = "kill",  winCount = 0,
    divers     = false,
    rowTypes   = {"mid","grunt"},
    difficulty = "easy",
    -- preserve current formation speed (easy preset uses 30; original was 38)
    formSpd    = 38,
    ebSpeed    = 95,   eShootInt = 2.2,
  },

  -- ── Bonus Stage 1 ──────────────────────────────────────────
  Bonus.STAGES[1],

  -- ── Level 3 ────────────────────────────────────────────────
  {
    title      = "LEVEL  3",
    subtitle   = "clear the formation",
    hint       = "enemies shoot back — deflect bullets, type enemies to clear",
    rows = 3, cols = 8,
    bulletPool = "tri",
    enemyPool  = "short",
    winBy      = "kill",  winCount = 0,
    divers     = false,
    rowTypes   = {"mid","grunt","grunt"},
    difficulty = "medium",
    ebSpeed    = 120,  eShootInt = 2.0,
  },

  -- ── Level 4 ────────────────────────────────────────────────
  {
    title      = "LEVEL  4",
    subtitle   = "formation + divers",
    hint       = "enemies break ranks and dive-bomb your bases — stay sharp",
    rows = 3, cols = 7,
    bulletPool = "short",
    enemyPool  = "medium",
    winBy      = "kill",  winCount = 0,
    divers     = true,
    rowTypes   = {"mid","grunt","grunt"},
    difficulty = "medium",
    ebSpeed    = 130,  eShootInt = 1.8,
  },

  -- ── Bonus Stage 2 ──────────────────────────────────────────
  Bonus.STAGES[2],

  -- ── Level 5 — Boss ─────────────────────────────────────────
  {
    title      = "LEVEL  5",
    subtitle   = "boss incoming",
    hint       = "type the boss word to hit it — words get harder each phase",
    rows = 0, cols = 0,
    bulletPool = "short",
    enemyPool  = nil,
    winBy      = "boss",  winCount = 0,
    divers     = false,
    rowTypes   = {},
    difficulty = "medium",
    ebSpeed    = 110,  eShootInt = 1.5,
  },
}

return {
  LEVELS     = LEVELS,
  DIFFICULTY = DIFFICULTY,
}
