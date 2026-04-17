-- ════════════════════════════════════════════════════════════
--  Bonus stage data
--  Wave templates and all bonus stage level entries.
-- ════════════════════════════════════════════════════════════

-- Bezier control points normalized to (0..1) of screen W/H.
-- Values outside [0,1] are off-screen.
-- dur is NOT stored here — each wave entry sets its own dur.
local WAVE_TEMPLATES = {
  -- Enters right edge, arcs up then sweeps to lower-left
  swoop_R2L     = { pts = {{1.12,0.16},{0.78,0.09},{0.28,0.55},{-0.12,0.88}} },
  -- Mirror: enters left edge, sweeps to lower-right
  swoop_L2R     = { pts = {{-0.12,0.16},{0.22,0.09},{0.72,0.55},{1.12,0.88}} },
  -- Lower arc, right-to-left
  swoop_R2L_low = { pts = {{1.12,0.30},{0.82,0.22},{0.24,0.65},{-0.12,0.92}} },
  -- Mirror
  swoop_L2R_low = { pts = {{-0.12,0.30},{0.18,0.22},{0.76,0.65},{1.12,0.92}} },
  -- Dives from top-left, converges toward center — pairs with dive_R for V-shape
  dive_L        = { pts = {{0.12,-0.08},{0.12,0.28},{0.40,0.46},{0.40,1.10}} },
  -- Mirror
  dive_R        = { pts = {{0.88,-0.08},{0.88,0.28},{0.60,0.46},{0.60,1.10}} },
}

-- Each entry is a full LEVELS table entry for a bonus stage.
local STAGES = {
  -- ── Bonus Stage 1 ──────────────────────────────────────────
  {
    title      = "BONUS  STAGE",
    subtitle   = "challenging stage",
    hint       = "type all enemies for a PERFECT BONUS — they never shoot back!",
    rows = 0, cols = 0,
    bulletPool = "alpha", enemyPool = nil,
    ebSpeed = 0, eShootInt = 999,
    divers = false, winBy = "bonus", winCount = 0, rowTypes = {},
    difficulty = "easy",
    -- 6 waves × 5 enemies = 30 total; waves alternate L/R with clear pauses.
    -- gap=0.55s: swoop vert speed ~102 px/s → ~57px separation (sprite+label = 41px, needs >56px)
    -- delay = prev_delay + (count-1)*gap + dur + 0.8s pause
    bonusWaveSeq = {
      {tmpl="swoop_R2L",     count=5, gap=0.55, delay=1.0,  dur=4.5, pool="tri",  etype="grunt"},
      {tmpl="swoop_L2R",     count=5, gap=0.55, delay=8.5,  dur=4.5, pool="tri",  etype="grunt"},
      {tmpl="swoop_R2L_low", count=5, gap=0.55, delay=16.0, dur=4.5, pool="tri",  etype="grunt"},
      {tmpl="swoop_L2R_low", count=5, gap=0.55, delay=23.5, dur=4.5, pool="tri",  etype="grunt"},
      {tmpl="dive_L",        count=5, gap=0.50, delay=31.0, dur=4.0, pool="tri",  etype="mid"},
      {tmpl="dive_R",        count=5, gap=0.50, delay=32.5, dur=4.0, pool="tri",  etype="mid"},
    },
  },

  -- ── Bonus Stage 2 ──────────────────────────────────────────
  {
    title      = "BONUS  STAGE  2",
    subtitle   = "challenging stage",
    hint       = "faster waves, harder words — keep your combo alive!",
    rows = 0, cols = 0,
    bulletPool = "alpha", enemyPool = nil,
    ebSpeed = 0, eShootInt = 999,
    divers = false, winBy = "bonus", winCount = 0, rowTypes = {},
    difficulty = "medium",
    -- 8 waves × 5 enemies = 40 total; alternates mid/grunt for variety.
    -- gap=0.44s: B2 swoop vert speed ~128 px/s → ~56px separation (minimum readable)
    -- dive gap=0.36s: dive vert speed ~236 px/s → ~85px separation (plenty of room)
    bonusWaveSeq = {
      {tmpl="swoop_R2L",     count=5, gap=0.44, delay=0.8,  dur=3.6, pool="short", etype="mid"},
      {tmpl="swoop_L2R",     count=5, gap=0.44, delay=7.0,  dur=3.6, pool="short", etype="mid"},
      {tmpl="swoop_R2L_low", count=5, gap=0.46, delay=13.2, dur=3.8, pool="short", etype="grunt"},
      {tmpl="swoop_L2R_low", count=5, gap=0.46, delay=19.7, dur=3.8, pool="short", etype="grunt"},
      {tmpl="dive_L",        count=5, gap=0.36, delay=26.2, dur=3.2, pool="short", etype="mid"},
      {tmpl="dive_R",        count=5, gap=0.36, delay=27.7, dur=3.2, pool="short", etype="mid"},
      {tmpl="swoop_R2L",     count=5, gap=0.44, delay=33.2, dur=3.5, pool="short", etype="mid"},
      {tmpl="swoop_L2R",     count=5, gap=0.44, delay=34.7, dur=3.5, pool="short", etype="mid"},
    },
  },
}

return {
  WAVE_TEMPLATES = WAVE_TEMPLATES,
  STAGES         = STAGES,
}
