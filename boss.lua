-- ════════════════════════════════════════════════════════════
--  Boss configuration
--  All hardcoded boss values live here; main.lua reads them.
-- ════════════════════════════════════════════════════════════

return {
  maxHp          = 5,
  initialVx      = 50,    -- starting horizontal velocity
  wallMargin     = 20,    -- px from edge before bouncing
  invDuration    = 1.0,   -- seconds of invincibility after a hit
  descentSpeed   = 18,    -- px/s downward drift at final phase (hp == 1)
  descentMaxY    = -280,  -- boss stops at G.H + descentMaxY

  -- Word pool, movement speed, and shoot interval per phase.
  -- Phases are checked in order; first one where hp >= minHp wins.
  phases = {
    { minHp = 4, pool = "medium", speed = 45,  shootInt = 2.5 },
    { minHp = 2, pool = "long",   speed = 75,  shootInt = 2.0 },
    { minHp = 1, pool = "shmup",  speed = 110, shootInt = 1.6 },
  },

  -- HP values that trigger a minion wave on hit.
  -- Key = HP after the hit; value = minion phase number to spawn.
  minionPhaseAt = { [3] = 2, [1] = 3 },

  -- Delay before the FIRST periodic respawn of phase-3 minions.
  -- Subsequent respawns use minionTimerReset.
  minionTimerInit  = 4.5,
  minionTimerReset = 5.0,

  -- Minion spawn configs, keyed by phase number.
  minions = {
    -- Phase 2: slow grunt floaters drifting downward — light pressure.
    [2] = {
      etype       = "grunt",
      pool        = "short",
      vy          = 20,
      spawnYOffset = 30,   -- offset from CFG.formY0
      -- xFrac values are fractions of screen width (840 px reference).
      slots = {
        { xFrac = 50/840,  vx =  28 },
        { xFrac = 400/840, vx = -18 },
        { xFrac = 750/840, vx = -28 },
      },
    },
    -- Phase 3: mid-type divers aimed at bases — serious threat.
    [3] = {
      count        = 2,
      etype        = "mid",
      pool         = "medium",
      spawnYOffset = 20,   -- offset from CFG.formY0
      -- xFrac pairs: left spawn, right spawn.
      spawnXFracs = { 70/840, 770/840 },
    },
  },
}
