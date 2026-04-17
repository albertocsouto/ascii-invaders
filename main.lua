--[[
  ASCII GALAXIAN — TYPING EDITION  (level-based)

  Type the word shown on enemies to shoot them.
  Type the word shown on bullets to deflect them.
  Defend your 5 bases! Game over when all bases are destroyed.
  BACKSPACE resets input. ESC quits.
--]]

local D     = require("data")
local Sound = require("sound")
local LB    = require("lboard")
local Draw  = require("draw")
local Demo  = require("demo")

-- Unpack constants for convenient use in game logic
local WORDS, LEVELS, SPR, PTS, COL, CFG, WAVE_TEMPLATES, BOSS, DIFFICULTY = D.WORDS, D.LEVELS, D.SPR, D.PTS, D.COL, D.CFG, D.WAVE_TEMPLATES, D.BOSS, D.DIFFICULTY
local BASE_MAX_HP, NUM_BASES, MAX_LB = D.BASE_MAX_HP, D.NUM_BASES, D.MAX_LB

-- Debug mode: launch with `love . debug` to enable level-jump keys
local _debug = false
if arg then for _, v in ipairs(arg) do if v == "debug" then _debug = true end end end

-- ALL mutable state in one table passed to draw module
local G = {
  -- window / render
  W=0, H=0, fnt=nil, wfnt=nil, bfnt=nil, pfnt=nil,
  CW=0, CH=0, WCW=0, WCH=0, cellW=0, cellH=0,
  stars={},
  debug=_debug,
  -- game state
  gs="title", score=0, hi=0, level=1,
  deflectCount=0, tBulletSpawn=0, tEShoot=0, tDive=0,
  formOX=0, formVX=0,
  -- entities
  grid={}, eb={}, divers={}, exps={}, shots={}, bases={}, boss_entity=nil,
  pops={}, particles={},
  -- end-screen delay
  endTimer=nil, pendingGs=nil,
  -- attract-mode
  attractTimer=0, isDemo=false,
  -- initials entry
  initialsBuffer="", initialsTargetGs="", pendingScore=nil,
  -- player
  typed="", mistype=nil, shake=nil,
  -- combo/multiplier
  multiplier=1, combo=0,
  -- stats
  lvlKeys=0, lvlMistypes=0, lvlMaxCombo=0,
  gameKeys=0, gameMistypes=0, gameMaxCombo=0,
  lvlTime=0, gameTime=0,
  -- leaderboard ranks
  lastScoreRank=nil, lastLvlTimeRank=nil, lastGameTimeRank=nil,
  -- bonus stage state
  bonusEnemies={}, bonusQueue={}, bonusQIdx=0,
  bonusTotal=0, bonusKilled=0, bonusTime=0, bonusPerfect=false,
  waveKills={}, waveSizes={},
}

-- After love.load initialises G, pull utility shorthands from Draw
local sprW, sprH, fx0, epos, hasPrefix, aliveCount

-- ════════════════════════════════════════════════════════════
--  Utilities
-- ════════════════════════════════════════════════════════════

local function aabb(ax,ay,aw,ah, bx,by,bw,bh)
  return ax < bx+bw and ax+aw > bx and ay < by+bh and ay+ah > by
end

local function pickWord(poolName)
  local pool = WORDS[poolName]
  if not pool then return "?" end
  return pool[math.random(#pool)]
end

local function baseSpr(hp)
  return SPR.base[math.max(1, math.min(BASE_MAX_HP, hp))]
end

local function resetMultiplier()
  G.combo = 0
  G.multiplier = 1
end

-- ════════════════════════════════════════════════════════════
--  Prefix matching
-- ════════════════════════════════════════════════════════════

local function getTrackingTarget()
  if #G.typed == 0 then return nil end
  for _, b in ipairs(G.eb) do
    if b.word and hasPrefix(b.word) then return {type="bullet", ref=b} end
  end
  for _, d in ipairs(G.divers) do
    if d.alive and d.word and hasPrefix(d.word) then return {type="diver", ref=d} end
  end
  if G.boss_entity and G.boss_entity.alive and not G.boss_entity.invTimer
     and G.boss_entity.word and hasPrefix(G.boss_entity.word) then
    return {type="boss"}
  end
  for _, be in ipairs(G.bonusEnemies) do
    if be.alive and be.word and hasPrefix(be.word) then return {type="bonus_enemy", ref=be} end
  end
  local lvl = LEVELS[G.level]
  for r = lvl.rows, 1, -1 do
    for c = 1, lvl.cols do
      local e = G.grid[r] and G.grid[r][c]
      if e and e.word and hasPrefix(e.word) then return {type="grid", r=r, c=c} end
    end
  end
  return nil
end

-- ════════════════════════════════════════════════════════════
--  Kill / complete
-- ════════════════════════════════════════════════════════════

local function spawnExp(cx, cy, c)
  G.exps[#G.exps+1] = {x=cx, y=cy, col=c, t=0, dur=0.50}
end

local function spawnPop(text, x, y, col)
  G.pops[#G.pops+1] = {text=text, x=x, y=y, t=0, dur=0.75, col=col}
end

local function spawnWordBurst(word, x, y, col)
  for i = 1, #word do
    local angle = math.random() * 2 * math.pi
    local speed = math.random(80, 170)
    G.particles[#G.particles+1] = {
      ch  = word:sub(i, i),
      x   = x, y = y,
      vx  = math.cos(angle) * speed,
      vy  = math.sin(angle) * speed - 40,
      t   = 0,
      dur = math.random(45, 70) / 100,
      col = col,
    }
  end
end

local function addShot(x2, y2)
  -- Fire from the alive base closest to x2
  local bestBase = nil
  local bestDist = math.huge
  for _, base in ipairs(G.bases) do
    if base.alive then
      local spr = baseSpr(base.hp)
      local bx = base.x + sprW(spr)/2
      local dist = math.abs(bx - x2)
      if dist < bestDist then
        bestDist = dist
        bestBase = base
      end
    end
  end
  if not bestBase then return end
  local spr = baseSpr(bestBase.hp)
  G.shots[#G.shots+1] = {
    x1 = bestBase.x + sprW(spr)/2,
    y1 = bestBase.y,
    x2 = x2, y2 = y2,
    t = 0, dur = 0.10,
  }
  Sound.play("shoot")
end

local function delayedEnd(gs)
  if G.isDemo then
    G.isDemo = false; G.eb = {}; G.gs = "title"; G.attractTimer = 0; Sound.startMenu(); return
  end
  -- Route through initials entry when score qualifies
  local pendingGs = gs
  if (gs == "gameover" or gs == "win") and LB.qualifies(G.score) then
    G.pendingScore     = {score=G.score, level=G.level}
    G.initialsBuffer   = ""
    G.initialsTargetGs = gs
    pendingGs          = "initials"
  end
  G.gs        = "ending"
  G.pendingGs = pendingGs
  G.endTimer  = 1.0
  for _, b in ipairs(G.eb) do
    spawnExp(b.x + sprW(SPR.ebullet)/2, b.y, COL.ebullet)
  end
  G.eb = {}
  if gs == "gameover" then Sound.play("jingle_over") else Sound.play("jingle_clear") end
end

local function damageBase(i, amount)
  local base = G.bases[i]
  if not base.alive then return end
  base.hp = base.hp - amount
  resetMultiplier()
  G.shake = 0.18
  if base.hp <= 0 then
    base.hp = 0
    base.alive = false
    local spr = baseSpr(1)
    spawnExp(base.x + sprW(spr)/2, base.y + sprH(spr)/2, COL.base_low)
    Sound.play("explode")
    G.shake = 0.45
    -- Check if all bases destroyed
    local anyAlive = false
    for _, b in ipairs(G.bases) do
      if b.alive then anyAlive = true; break end
    end
    if not anyAlive then
      if G.score > G.hi then G.hi = G.score end
      delayedEnd("gameover")
    end
  else
    Sound.play("hit")
  end
end

local function registerBonusKill()
  Sound.play("kill")
end

local function registerKill()
  G.combo = G.combo + 1
  if G.combo > G.lvlMaxCombo  then G.lvlMaxCombo  = G.combo end
  if G.combo > G.gameMaxCombo then G.gameMaxCombo = G.combo end
  G.multiplier = G.combo + 1
  Sound.play("kill")
  if G.multiplier > 1 then Sound.play("combo", 1 + (G.multiplier-2)*0.15) end
end

-- ════════════════════════════════════════════════════════════
--  Boss helpers
-- ════════════════════════════════════════════════════════════

-- Returns the BOSS.phases entry matching the current hp.
local function getBossPhase(hp)
  for _, p in ipairs(BOSS.phases) do
    if hp >= p.minHp then return p end
  end
  return BOSS.phases[#BOSS.phases]
end

local function initBoss()
  local spr   = SPR.boss
  local phase = getBossPhase(BOSS.maxHp)
  G.boss_entity = {
    x           = G.W/2 - sprW(spr)/2,
    y           = CFG.formY0,
    vx          = BOSS.initialVx,
    hp          = BOSS.maxHp,
    maxHp       = BOSS.maxHp,
    word        = pickWord(phase.pool),
    invTimer    = nil,
    alive       = true,
    shootTimer  = phase.shootInt,
    minionTimer = nil,
  }
end

-- Spawn boss minions on phase entry.
-- Phase 2: slow grunt floaters drifting down — easy pressure.
-- Phase 3: mid-type divers aimed at bases — real threat.
local function spawnBossMinions(phase)
  local aliveBases = {}
  for _, b in ipairs(G.bases) do if b.alive then aliveBases[#aliveBases+1] = b end end

  local m = BOSS.minions[phase]
  if not m then return end

  if phase == 2 then
    for _, s in ipairs(m.slots) do
      G.divers[#G.divers+1] = {
        type=m.etype, alive=true, spr=SPR[m.etype],
        x=s.xFrac * G.W, y=CFG.formY0 + m.spawnYOffset,
        vx=s.vx, vy=m.vy,
        word=pickWord(m.pool),
      }
    end

  elseif phase == 3 then
    for i = 1, m.count do
      local sx = m.spawnXFracs[i] * G.W
      local sy = CFG.formY0 + m.spawnYOffset
      local tx = G.W / 2
      if #aliveBases > 0 then
        local target = aliveBases[math.random(#aliveBases)]
        tx = target.x + sprW(baseSpr(target.hp)) / 2
      end
      local dx = tx - sx
      local dy = G.H - sy
      local len = math.sqrt(dx*dx + dy*dy)
      local spd = CFG.dvSpeed
      G.divers[#G.divers+1] = {
        type=m.etype, alive=true, spr=SPR[m.etype],
        x=sx, y=sy,
        vx=(dx/len)*spd*0.65, vy=spd,
        word=pickWord(m.pool),
      }
    end
  end
end

local function completeTarget(tgt)
  if tgt.type == "grid" then
    local e = G.grid[tgt.r][tgt.c]
    if not e then return end
    local spr = SPR[e.type]
    local ex, ey = epos(tgt.r, tgt.c)
    local cx, cy = ex+sprW(spr)/2, ey+sprH(spr)/2
    addShot(cx, cy)
    spawnExp(cx, cy, COL[e.type])
    spawnWordBurst(e.word, cx, cy, COL[e.type])
    local pts = PTS[e.type] * G.multiplier
    G.score = G.score + pts
    spawnPop("+"..pts, cx, ey, COL[e.type])
    registerKill()
    G.grid[tgt.r][tgt.c] = nil

  elseif tgt.type == "diver" then
    local d = tgt.ref
    if not d.alive then return end
    local cx, cy = d.x+sprW(d.spr)/2, d.y+sprH(d.spr)/2
    addShot(cx, cy)
    spawnExp(cx, cy, COL[d.type])
    spawnWordBurst(d.word, cx, cy, COL[d.type])
    local pts = PTS[d.type] * G.multiplier
    G.score = G.score + pts
    local popText = "+"..pts
    if not d.warnTimer then
      G.score = G.score + 200
      popText = popText.."  +200 DIVE!"
    end
    spawnPop(popText, cx, cy, COL[d.type])
    registerKill()
    if d.diveSound then d.diveSound:stop() end
    d.alive = false

  elseif tgt.type == "bullet" then
    local b = tgt.ref
    for i, bx in ipairs(G.eb) do
      if bx == b then
        local cx = b.x+sprW(SPR.ebullet)/2
        addShot(cx, b.y)
        spawnExp(cx, b.y, COL.ebullet)
        spawnPop("+10", cx, b.y, COL.ebullet)
        table.remove(G.eb, i)
        G.score = G.score + 10
        G.deflectCount = G.deflectCount + 1
        Sound.play("deflect")
        break
      end
    end

  elseif tgt.type == "boss" then
    if not G.boss_entity or not G.boss_entity.alive then return end
    local spr = SPR.boss
    local cx = G.boss_entity.x + sprW(spr)/2
    local cy = G.boss_entity.y + sprH(spr)/2
    addShot(cx, cy)
    spawnExp(cx, cy, COL.boss)
    spawnWordBurst(G.boss_entity.word, cx, cy, COL.boss)
    local pts = PTS.boss * G.multiplier
    G.boss_entity.hp = G.boss_entity.hp - 1
    G.score = G.score + pts
    spawnPop("+"..pts, cx, cy, COL.boss)
    registerKill()
    -- Spawn minions on phase entry
    local mPhase = BOSS.minionPhaseAt[G.boss_entity.hp]
    if mPhase then
      spawnBossMinions(mPhase)
      if mPhase == 3 then G.boss_entity.minionTimer = BOSS.minionTimerInit end
    end
    if G.boss_entity.hp <= 0 then
      G.boss_entity.alive = false
      Sound.play("explode")
    else
      G.boss_entity.invTimer = BOSS.invDuration
    end

  elseif tgt.type == "bonus_enemy" then
    local be = tgt.ref
    if not be.alive then return end
    local col = COL[be.eType] or COL.grunt
    local cx = be.x + sprW(be.spr)/2
    local cy = be.y + sprH(be.spr)/2
    addShot(cx, cy)
    spawnExp(cx, cy, col)
    spawnWordBurst(be.word, cx, cy, col)
    G.score = G.score + PTS.bonus_enemy
    spawnPop("+"..PTS.bonus_enemy, cx, cy, col)
    registerBonusKill()
    G.bonusKilled = G.bonusKilled + 1
    -- Wave completion bonus
    local wid = be.waveId
    if wid then
      G.waveKills[wid] = (G.waveKills[wid] or 0) + 1
      if G.waveKills[wid] >= (G.waveSizes[wid] or 0) then
        local bonus = 300
        G.score = G.score + bonus
        spawnPop("WAVE +"..bonus, cx, cy - 24, COL.wordTyped)
      end
    end
    be.alive = false
  end
end

-- ════════════════════════════════════════════════════════════
--  Bonus stage
-- ════════════════════════════════════════════════════════════

-- Evaluate a cubic Bezier at t in [0,1]
local function bezierPt(pts, t)
  local mt = 1 - t
  return
    mt^3*pts[1][1] + 3*mt^2*t*pts[2][1] + 3*mt*t^2*pts[3][1] + t^3*pts[4][1],
    mt^3*pts[1][2] + 3*mt^2*t*pts[2][2] + 3*mt*t^2*pts[3][2] + t^3*pts[4][2]
end

-- Build a flat, time-sorted spawn queue from the level's wave sequence.
-- Each entry: {spawnAt, pts (screen-scaled), dur, eType, word}
local function buildBonusQueue(lvl)
  local q = {}
  for wi, wave in ipairs(lvl.bonusWaveSeq) do
    local tmpl = WAVE_TEMPLATES[wave.tmpl]
    for i = 0, wave.count - 1 do
      local pts = {}
      for _, p in ipairs(tmpl.pts) do
        pts[#pts+1] = {p[1] * G.W, p[2] * G.H}
      end
      q[#q+1] = {
        spawnAt = wave.delay + i * wave.gap,
        pts     = pts,
        dur     = wave.dur,
        eType   = wave.etype,
        word    = pickWord(wave.pool),
        waveId  = wi,
      }
    end
  end
  table.sort(q, function(a, b) return a.spawnAt < b.spawnAt end)
  return q
end

-- ════════════════════════════════════════════════════════════
--  Init
-- ════════════════════════════════════════════════════════════

local function initBases()
  local spacing = G.W / (NUM_BASES + 1)
  local spr = baseSpr(BASE_MAX_HP)
  local bw  = sprW(spr)
  local baseY = G.H - 130
  G.bases = {}
  for i = 1, NUM_BASES do
    G.bases[i] = {
      x     = math.floor(spacing * i - bw/2),
      y     = baseY,
      hp    = BASE_MAX_HP,
      alive = true,
    }
  end
end

-- Merge level entry + difficulty preset + CFG fallbacks into CFG.
-- Resolution order: explicit level field > difficulty preset > existing CFG default.
local function resolveLevel(lvl)
  local diff = DIFFICULTY[lvl.difficulty] or {}
  CFG.ebSpeed   = lvl.ebSpeed   or diff.ebSpeed   or CFG.ebSpeed
  CFG.eShootInt = lvl.eShootInt or diff.eShootInt or CFG.eShootInt
  CFG.formSpd   = lvl.formSpd   or diff.formSpd   or CFG.formSpd
  CFG.dvSpeed   = lvl.dvSpeed   or diff.dvSpeed   or CFG.dvSpeed
  CFG.diveInt   = lvl.diveInt   or diff.diveInt   or CFG.diveInt
  CFG.maxDivers = lvl.maxDivers or diff.maxDivers or CFG.maxDivers
end

local function initLevel(n)
  G.level = n
  local lvl = LEVELS[n]

  resolveLevel(lvl)

  G.deflectCount  = 0
  G.tBulletSpawn  = CFG.eShootInt
  G.tEShoot       = CFG.eShootInt + 1.0
  G.tDive         = CFG.diveInt + 2.0

  initBases()

  if lvl.winBy == "boss" then
    initBoss()
  elseif lvl.winBy == "bonus" then
    G.boss_entity = nil
    G.bonusQueue   = buildBonusQueue(lvl)
    G.bonusTotal   = #G.bonusQueue
    G.bonusQIdx    = 0
    G.bonusTime    = 0
    G.bonusKilled  = 0
    G.bonusPerfect = false
    G.waveKills    = {}
    G.waveSizes    = {}
    for wi, wave in ipairs(lvl.bonusWaveSeq) do
      G.waveKills[wi] = 0
      G.waveSizes[wi] = wave.count
    end
  else
    G.boss_entity = nil
  end

  G.multiplier = 1
  G.combo = 0
  G.lvlKeys = 0; G.lvlMistypes = 0; G.lvlMaxCombo = 0
  G.lvlTime = 0
  G.lastScoreRank = nil; G.lastLvlTimeRank = nil; G.lastGameTimeRank = nil

  G.eb, G.divers, G.exps, G.shots, G.bonusEnemies, G.pops, G.particles = {}, {}, {}, {}, {}, {}, {}
  G.typed   = ""
  G.mistype = nil
  G.shake   = nil

  -- Build grid
  G.grid = {}
  for r = 1, lvl.rows do
    G.grid[r] = {}
    local t = lvl.rowTypes[r] or "grunt"
    for c = 1, lvl.cols do
      G.grid[r][c] = { type=t, word=pickWord(lvl.enemyPool or "tri") }
    end
  end

  G.formOX = 0
  G.formVX = CFG.formSpd

  G.gs = "playing"
end

local function startGame(fromLevel)
  Sound.stopMenu()
  G.attractTimer = 0
  G.isDemo = false
  G.score = 0
  G.gameKeys = 0; G.gameMistypes = 0; G.gameMaxCombo = 0
  G.gameTime = 0
  initLevel(fromLevel or 1)
end

-- ════════════════════════════════════════════════════════════
--  Spawn
-- ════════════════════════════════════════════════════════════

local function spawnEB(cx, cy)
  local pool = LEVELS[G.level].bulletPool
  -- Pick a random alive base to aim at
  local aliveBases = {}
  for _, b in ipairs(G.bases) do if b.alive then aliveBases[#aliveBases+1] = b end end
  local vx = 0
  if #aliveBases > 0 then
    local target = aliveBases[math.random(#aliveBases)]
    local spr = baseSpr(target.hp)
    local tx = target.x + sprW(spr)/2
    local ty = target.y + sprH(spr)/2
    local dx = tx - cx
    local dy = ty - cy
    if dy > 0 then
      vx = (dx / dy) * CFG.ebSpeed
    end
  end
  G.eb[#G.eb+1] = {
    x    = cx - sprW(SPR.ebullet)/2,
    y    = cy,
    vx   = vx,
    vy   = CFG.ebSpeed,
    word = pickWord(pool),
  }
  Sound.play("ebullet")
end

local function spawnDiver()
  if not LEVELS[G.level].divers then return end
  if #G.divers >= CFG.maxDivers then return end
  local lvl = LEVELS[G.level]
  local pool = {}
  for r = 1, lvl.rows do
    for c = 1, lvl.cols do if G.grid[r] and G.grid[r][c] then pool[#pool+1]={r=r,c=c} end end
  end
  if #pool == 0 then return end

  -- Pick a random alive base to target
  local aliveBases = {}
  for _, b in ipairs(G.bases) do if b.alive then aliveBases[#aliveBases+1] = b end end
  local targetBase = #aliveBases > 0 and aliveBases[math.random(#aliveBases)] or nil

  -- Don't spawn while another diver is still in warning phase
  for _, d in ipairs(G.divers) do
    if d.warnTimer then return end
  end
  for _ = 1, 1 do
    if #pool == 0 then break end
    local i = math.random(#pool)
    local p = pool[i]; table.remove(pool, i)
    local e   = G.grid[p.r][p.c]
    local spr = SPR[e.type]
    local ex, ey = epos(p.r, p.c)
    G.grid[p.r][p.c] = nil
    local tx  = targetBase and (targetBase.x + sprW(baseSpr(targetBase.hp))/2) or G.W/2
    local dx  = tx - (ex + sprW(spr)/2)
    local dy  = CFG.dvSpeed
    local len = math.sqrt(dx*dx + dy*dy)
    G.divers[#G.divers+1] = {
      type=e.type, alive=true, spr=spr,
      x=ex, y=ey,
      vx=(dx/len)*CFG.dvSpeed*0.65, vy=CFG.dvSpeed,
      warnTimer=3.0, warnR=p.r, warnC=p.c,
      word=e.word or pickWord(lvl.enemyPool or "tri"),
    }
  end
end

local function bossShoot()
  if not G.boss_entity or not G.boss_entity.alive then return end
  local spr = SPR.boss
  local cx = G.boss_entity.x + sprW(spr)/2
  local cy = G.boss_entity.y + sprH(spr)
  -- Max 2 bullets at any phase — spread only at low HP
  local count = G.boss_entity.hp >= 3 and 1 or 2
  for i = 1, count do
    local ox = (i - (count+1)/2) * 48
    spawnEB(cx + ox, cy)
  end
end

local function updateBoss(dt)
  if not G.boss_entity or not G.boss_entity.alive then return end

  local phase = getBossPhase(G.boss_entity.hp)

  if G.boss_entity.invTimer then
    G.boss_entity.invTimer = G.boss_entity.invTimer - dt
    if G.boss_entity.invTimer <= 0 then
      G.boss_entity.invTimer = nil
      G.boss_entity.word = pickWord(phase.pool)
    end
  end

  -- Move horizontally, bouncing off walls
  G.boss_entity.x = G.boss_entity.x + G.boss_entity.vx * dt
  local bw  = sprW(SPR.boss)
  local spd = phase.speed
  if G.boss_entity.x < BOSS.wallMargin then
    G.boss_entity.x  = BOSS.wallMargin
    G.boss_entity.vx = spd
  elseif G.boss_entity.x + bw > G.W - BOSS.wallMargin then
    G.boss_entity.x  = G.W - BOSS.wallMargin - bw
    G.boss_entity.vx = -spd
  end

  -- At HP 1 descend toward bases
  if G.boss_entity.hp == 1 then
    G.boss_entity.y = math.min(G.boss_entity.y + BOSS.descentSpeed * dt, G.H + BOSS.descentMaxY)
  end

  -- Phase 3: periodic extra diver spawns
  if G.boss_entity.minionTimer then
    G.boss_entity.minionTimer = G.boss_entity.minionTimer - dt
    if G.boss_entity.minionTimer <= 0 then
      spawnBossMinions(3)
      G.boss_entity.minionTimer = BOSS.minionTimerReset
    end
  end

  -- Shoot
  G.boss_entity.shootTimer = G.boss_entity.shootTimer - dt
  if G.boss_entity.shootTimer <= 0 then
    bossShoot()
    G.boss_entity.shootTimer = phase.shootInt
  end
end

local function updateBonus(dt)
  G.bonusTime = G.bonusTime + dt

  -- Spawn all queue entries whose spawnAt time has arrived
  while G.bonusQIdx < G.bonusTotal do
    local entry = G.bonusQueue[G.bonusQIdx + 1]
    if not entry or G.bonusTime < entry.spawnAt then break end
    G.bonusQIdx = G.bonusQIdx + 1
    local x0, y0 = bezierPt(entry.pts, 0)
    G.bonusEnemies[#G.bonusEnemies+1] = {
      eType  = entry.eType,
      spr    = SPR[entry.eType],
      word   = entry.word,
      pts    = entry.pts,
      dur    = entry.dur,
      age    = 0,
      alive  = true,
      x      = x0,
      y      = y0,
      waveId = entry.waveId,
    }
  end

  -- Advance all live enemies along their Bezier path
  for i = #G.bonusEnemies, 1, -1 do
    local e = G.bonusEnemies[i]
    if not e.alive then
      table.remove(G.bonusEnemies, i)
    else
      e.age = e.age + dt
      if e.age >= e.dur then
        table.remove(G.bonusEnemies, i)  -- escaped
      else
        e.x, e.y = bezierPt(e.pts, e.age / e.dur)
      end
    end
  end
end

-- ════════════════════════════════════════════════════════════
--  Text input
-- ════════════════════════════════════════════════════════════

local function handleTextInput(text)
  if G.gs ~= "playing" and G.gs ~= "attract_demo" then return end
  local ch = text:lower()
  if not ch:match("^[a-z]$") then return end

  G.lvlKeys = G.lvlKeys + 1; G.gameKeys = G.gameKeys + 1

  local candidate = G.typed .. ch

  -- Check for exact match (fires immediately)
  local matched = nil
  for _, b in ipairs(G.eb) do
    if b.word == candidate then matched={type="bullet",ref=b}; break end
  end
  if not matched then
    for _, d in ipairs(G.divers) do
      if d.alive and d.word == candidate then matched={type="diver",ref=d}; break end
    end
  end
  if not matched then
    local lvl = LEVELS[G.level]
    for r = lvl.rows, 1, -1 do
      for c = 1, lvl.cols do
        local e = G.grid[r] and G.grid[r][c]
        if e and e.word == candidate then matched={type="grid",r=r,c=c}; break end
      end
      if matched then break end
    end
  end
  if not matched then
    if G.boss_entity and G.boss_entity.alive and not G.boss_entity.invTimer
       and G.boss_entity.word == candidate then
      matched = {type="boss"}
    end
  end
  if not matched then
    for _, be in ipairs(G.bonusEnemies) do
      if be.alive and be.word == candidate then matched={type="bonus_enemy",ref=be}; break end
    end
  end

  if matched then
    completeTarget(matched)
    G.typed = ""
    return
  end

  -- Check if candidate is a valid prefix of anything
  local valid = false
  for _, b in ipairs(G.eb) do
    if b.word and b.word:sub(1,#candidate)==candidate then valid=true; break end
  end
  if not valid then
    for _, d in ipairs(G.divers) do
      if d.alive and d.word and d.word:sub(1,#candidate)==candidate then valid=true; break end
    end
  end
  if not valid then
    local lvl = LEVELS[G.level]
    for r = 1, lvl.rows do
      for c = 1, lvl.cols do
        local e = G.grid[r] and G.grid[r][c]
        if e and e.word and e.word:sub(1,#candidate)==candidate then valid=true; break end
      end
      if valid then break end
    end
  end

  if not valid then
    if G.boss_entity and G.boss_entity.alive and not G.boss_entity.invTimer
       and G.boss_entity.word and G.boss_entity.word:sub(1,#candidate)==candidate then
      valid = true
    end
  end
  if not valid then
    for _, be in ipairs(G.bonusEnemies) do
      if be.alive and be.word and be.word:sub(1,#candidate)==candidate then valid=true; break end
    end
  end

  if valid then
    G.typed = candidate
  else
    G.lvlMistypes = G.lvlMistypes + 1; G.gameMistypes = G.gameMistypes + 1
    G.mistype = 0.22
    G.typed   = ""
    Sound.play("mistype")
  end
end

function love.textinput(text)
  if G.gs == "initials" then
    local ch = text:upper()
    if ch:match("^[A-Z]$") and #G.initialsBuffer < 3 then
      G.initialsBuffer = G.initialsBuffer .. ch
    end
    return
  end
  G.textinputWorks = true
  handleTextInput(text)
end

-- ════════════════════════════════════════════════════════════
--  Update subsystems
-- ════════════════════════════════════════════════════════════

local function updateFormation(dt)
  if LEVELS[G.level].rows == 0 then return end
  G.formOX = G.formOX + G.formVX * dt
  local lvl = LEVELS[G.level]
  local lc, rc
  for c = 1, lvl.cols do
    for r = 1, lvl.rows do
      if G.grid[r] and G.grid[r][c] then if not lc then lc=c end; rc=c; break end
    end
  end
  if not lc then return end
  local mg = 20
  local lx = fx0() + (lc-1)*G.cellW
  local rx = fx0() + rc*G.cellW
  if lx < mg and G.formVX < 0 then
    G.formOX=G.formOX+(mg-lx); G.formVX=math.abs(G.formVX)
  elseif rx > G.W-mg and G.formVX > 0 then
    G.formOX=G.formOX-(rx-(G.W-mg)); G.formVX=-math.abs(G.formVX)
  end
end

local function updateDivers(dt)
  for i = #G.divers, 1, -1 do
    local d = G.divers[i]
    if not d.alive or d.y > G.H+60 then
      if d.diveSound then d.diveSound:stop() end
      table.remove(G.divers, i)
    else
      if d.warnTimer then
        d.warnTimer = d.warnTimer - dt
        if d.warnTimer <= 0 then
          d.warnTimer = nil
          d.diveSound = Sound.playRaw("diver_dive")
        else
          d.x, d.y = epos(d.warnR, d.warnC)
        end
      else
        d.x=d.x+d.vx*dt; d.y=d.y+d.vy*dt
        local dsw=sprW(d.spr)
        if d.x < 0     then d.x=0;       d.vx= math.abs(d.vx) end
        if d.x+dsw > G.W then d.x=G.W-dsw; d.vx=-math.abs(d.vx) end
      end
    end
  end
end

local function updateExps(dt)
  for i = #G.exps, 1, -1 do
    G.exps[i].t=G.exps[i].t+dt
    if G.exps[i].t >= G.exps[i].dur then table.remove(G.exps, i) end
  end
end

local function updatePops(dt)
  for i = #G.pops, 1, -1 do
    local p = G.pops[i]
    p.t = p.t + dt
    p.y = p.y - 40 * dt
    if p.t >= p.dur then table.remove(G.pops, i) end
  end
end

local function updateShots(dt)
  for i = #G.shots, 1, -1 do
    G.shots[i].t=G.shots[i].t+dt
    if G.shots[i].t >= G.shots[i].dur then table.remove(G.shots, i) end
  end
end

local function checkCollisions()
  local ebw = sprW(SPR.ebullet)
  local ebh = sprH(SPR.ebullet)
  local slotW = sprW(SPR.base[3])
  local slotH = sprH(SPR.base[3])
  for bi = #G.eb, 1, -1 do
    local b = G.eb[bi]
    if not b then break end  -- eb was replaced (base destroyed mid-loop)
    local hit = false
    for i, base in ipairs(G.bases) do
      if base.alive then
        local spr = baseSpr(base.hp)
        if aabb(b.x, b.y, ebw, ebh, base.x, base.y, sprW(spr), sprH(spr)) then
          table.remove(G.eb, bi)
          damageBase(i, CFG.dmgBullet)
          hit = true
          break
        end
      end
    end
    if not hit then
      for _, base in ipairs(G.bases) do
        if not base.alive then
          if aabb(b.x, b.y, ebw, ebh, base.x, base.y, slotW, slotH) then
            spawnExp(b.x + ebw/2, b.y + ebh/2, COL.dim)
            table.remove(G.eb, bi)
            resetMultiplier()
            break
          end
        end
      end
    end
  end
  for _, d in ipairs(G.divers) do
    if d.alive then
      local dsw = sprW(d.spr)
      local dsh = sprH(d.spr)
      for i, base in ipairs(G.bases) do
        if base.alive then
          local spr = baseSpr(base.hp)
          local bw = sprW(spr)
          local bh = sprH(spr)
          if aabb(d.x, d.y, dsw, dsh, base.x, base.y, bw, bh) then
            spawnExp(d.x+dsw/2, d.y+dsh/2, COL[d.type])
            d.alive = false
            damageBase(i, CFG.dmgDiver)
            break
          end
        end
      end
    end
  end
end

local function enemyShoot()
  local lvl = LEVELS[G.level]
  local shooters = {}
  for c = 1, lvl.cols do
    for r = lvl.rows, 1, -1 do
      if G.grid[r] and G.grid[r][c] then
        local spr=SPR[G.grid[r][c].type]; local ex,ey=epos(r,c)
        shooters[#shooters+1]={cx=ex+sprW(spr)/2, cy=ey+sprH(spr)}
        break
      end
    end
  end
  for _, dv in ipairs(G.divers) do
    if dv.alive then
      shooters[#shooters+1]={cx=dv.x+sprW(dv.spr)/2, cy=dv.y+sprH(dv.spr)}
    end
  end
  if #shooters > 0 then
    local s=shooters[math.random(#shooters)]
    spawnEB(s.cx, s.cy)
  end
end

local function checkWin()
  local lvl = LEVELS[G.level]
  local won = false
  if lvl.winBy == "deflect" then
    won = G.deflectCount >= lvl.winCount
  elseif lvl.winBy == "boss" then
    won = G.boss_entity ~= nil and not G.boss_entity.alive
  elseif lvl.winBy == "bonus" then
    local anyAlive = false
    for _, be in ipairs(G.bonusEnemies) do
      if be.alive then anyAlive = true; break end
    end
    won = (G.bonusQIdx >= G.bonusTotal) and not anyAlive
    if won and G.bonusKilled >= G.bonusTotal then
      G.bonusPerfect = true
      G.score = G.score + 3000
    end
  else
    won = aliveCount() == 0
  end
  if won then
    if G.level >= #LEVELS then
      if G.score > G.hi then G.hi = G.score end
      G.lastGameTimeRank = LB.insert(LB.data.time_game, {time=G.gameTime}, function(a,b) return a.time < b.time end)
      LB.save()
      delayedEnd("win")
    else
      delayedEnd("levelclear")
    end
  end
end

-- ════════════════════════════════════════════════════════════
--  LÖVE Callbacks
-- ════════════════════════════════════════════════════════════

function love.load()
  math.randomseed(os.time())
  G.W = love.graphics.getWidth()
  G.H = love.graphics.getHeight()

  local function loadMonoFont(size)
    return love.graphics.newFont("assets/fonts/Inconsolata-Regular.ttf", size)
  end
  G.fnt  = loadMonoFont(16)
  G.wfnt = loadMonoFont(16)
  G.mfnt = loadMonoFont(21)
  G.pfnt = loadMonoFont(17)
  G.bfnt = loadMonoFont(33)
  love.graphics.setFont(G.fnt)

  G.CW  = math.ceil(G.fnt:getWidth("X"))
  G.CH  = math.ceil(G.fnt:getHeight())
  G.WCW = math.ceil(G.wfnt:getWidth("X"))
  G.WCH = math.ceil(G.wfnt:getHeight())

  -- cellW/cellH only used for the enemy grid (not the boss, which moves freely)
  local maxC, maxR = 0, 0
  for _, spr in pairs({SPR.mid, SPR.grunt}) do
    maxC=math.max(maxC, #spr[1]); maxR=math.max(maxR, #spr)
  end
  G.cellW = math.ceil(math.max(maxC*G.CW, 9*G.WCW)) + 10
  G.cellH = math.ceil(maxR*G.CH + G.WCH) + 16

  G.stars = {}
  for _ = 1, 80 do
    local layer = math.random(3)
    local br = layer == 1 and math.random()*0.12+0.06
            or layer == 2 and math.random()*0.16+0.18
            or                math.random()*0.18+0.32
    local vy = layer == 1 and math.random(10, 20)
            or layer == 2 and math.random(28, 44)
            or                math.random(55, 75)
    G.stars[#G.stars+1]={
      x  = math.random(0, G.W-G.CW),
      y  = math.random(0, G.H-G.CH),
      ch = layer == 3 and "*" or ".",
      r=br, g=br, b=br+0.12,
      vy = vy,
    }
  end

  love.graphics.setBackgroundColor(COL.bg[1], COL.bg[2], COL.bg[3])
  Sound.build()
  LB.load(MAX_LB)
  G.hi = #LB.data.score > 0 and LB.data.score[1].score or 0
  G.gs="title"
  G.gameKeys=0; G.gameMistypes=0; G.gameMaxCombo=0; G.gameTime=0
  G.lvlTime=0

  Draw.init(G, D, Sound, LB)
  sprW      = Draw.sprW
  sprH      = Draw.sprH
  fx0       = Draw.fx0
  epos      = Draw.epos
  hasPrefix = Draw.hasPrefix
  aliveCount= Draw.aliveCount

  Sound.startMenu()
end

function love.update(dt)
  dt=math.min(dt, 0.05)
  if G.shake   then G.shake=G.shake-dt;     if G.shake<=0   then G.shake=nil   end end
  if G.mistype then G.mistype=G.mistype-dt; if G.mistype<=0 then G.mistype=nil end end
  for _, s in ipairs(G.stars) do
    s.y = s.y + s.vy * dt
    if s.y > G.H then s.y = s.y - G.H - G.CH end
  end
  updatePops(dt)
  for i = #G.particles, 1, -1 do
    local p = G.particles[i]
    p.t  = p.t  + dt
    p.x  = p.x  + p.vx * dt
    p.y  = p.y  + p.vy * dt
    p.vy = p.vy + 160 * dt  -- gravity
    if p.t >= p.dur then table.remove(G.particles, i) end
  end
  if G.endTimer then
    G.endTimer = G.endTimer - dt
    if G.endTimer <= 0 then G.gs = G.pendingGs; G.endTimer = nil; G.pendingGs = nil end
  end
  -- ── Attract-mode cycle: title → scores → demo → title ──────
  if G.gs == "title" then
    G.attractTimer = G.attractTimer + dt
    if G.attractTimer >= 17 then   -- one music-loop (15s) + 2s pause
      G.gs = "attract_scores"
      G.attractTimer = 0
    end
    return
  end
  if G.gs == "attract_scores" then
    G.attractTimer = G.attractTimer + dt
    if G.attractTimer >= 6 then
      G.attractTimer = 0
      startGame(5)                 -- real engine, LEVEL 4 (formation + divers)
      G.isDemo = true
      G.gs     = "attract_demo"
      Demo.init(function(ch)
        if ch == "\b" then G.typed = ""
        else handleTextInput(ch) end
      end)
    end
    return
  end
  -- ────────────────────────────────────────────────────────────

  if G.gs == "gameover" then
    updateFormation(dt)
    updateDivers(dt)
    for i = #G.eb, 1, -1 do
      G.eb[i].x = G.eb[i].x + (G.eb[i].vx or 0) * dt
      G.eb[i].y = G.eb[i].y + G.eb[i].vy * dt
      if G.eb[i].y > G.H + 20 then table.remove(G.eb, i) end
    end
    G.tEShoot = G.tEShoot - dt
    if G.tEShoot <= 0 then enemyShoot(); G.tEShoot = CFG.eShootInt end
    updateExps(dt)
    updateShots(dt)
    return
  end
  if G.gs ~= "playing" and G.gs ~= "ending" and G.gs ~= "attract_demo" then return end

  G.lvlTime  = G.lvlTime  + dt
  G.gameTime = G.gameTime + dt

  updateFormation(dt)
  updateDivers(dt)
  for i=#G.eb,1,-1 do
    G.eb[i].x=G.eb[i].x+(G.eb[i].vx or 0)*dt
    G.eb[i].y=G.eb[i].y+G.eb[i].vy*dt
    if G.eb[i].y>G.H+20 then table.remove(G.eb,i) end
  end
  updateExps(dt)
  updateShots(dt)

  if G.gs == "playing" or G.gs == "attract_demo" then checkCollisions() end

  if G.gs ~= "playing" and G.gs ~= "attract_demo" then return end

  local lvl = LEVELS[G.level]

  if lvl.winBy == "boss" then
    updateBoss(dt)
  elseif lvl.winBy == "bonus" then
    updateBonus(dt)
  elseif lvl.rows == 0 then
    G.tBulletSpawn = G.tBulletSpawn - dt
    if G.tBulletSpawn <= 0 then
      local x = math.random(60, G.W - 60)
      spawnEB(x, CFG.formY0)
      G.tBulletSpawn = lvl.eShootInt
    end
  else
    G.tEShoot = G.tEShoot - dt
    if G.tEShoot <= 0 then enemyShoot(); G.tEShoot = CFG.eShootInt end

    if lvl.divers then
      G.tDive = G.tDive - dt
      if G.tDive <= 0 and #G.divers < CFG.maxDivers then spawnDiver(); G.tDive = CFG.diveInt end
    end
  end

  checkWin()

  -- AI tick for attract demo; also handles timed end
  if G.gs == "attract_demo" then
    Demo.tick(dt, G)
    if Demo.isDone() then
      for _, d in ipairs(G.divers) do if d.diveSound then d.diveSound:stop() end end
      G.isDemo       = false
      G.gs           = "title"
      G.attractTimer = 0
      Sound.startMenu()
    end
  end
end

function love.keypressed(key)
  if key=="escape" then
    if love.system.getOS() == "Web" then
      Sound.stopMenu()
      G.gs = "title"
      G.attractTimer = 0
      Sound.startMenu()
    else
      love.event.quit()
    end
  end
  if G.gs == "initials" then
    if key == "backspace" then
      if #G.initialsBuffer > 0 then G.initialsBuffer = G.initialsBuffer:sub(1,-2) end
    elseif key == "return" or key == "space" then
      local initials = (G.initialsBuffer .. "___"):sub(1, 3)
      G.pendingScore.initials = initials
      G.lastScoreRank = LB.insert(LB.data.score, G.pendingScore, function(a,b) return a.score > b.score end)
      LB.save()
      G.pendingScore = nil
      G.gs = G.initialsTargetGs
    end
    return
  end
  if key=="backspace" and G.gs=="playing" then G.typed="" end
  -- Fallback for environments where love.textinput doesn't fire (e.g. web)
  if not G.textinputWorks and #key == 1 and key:match("^[a-z]$") then handleTextInput(key) end
  if key=="return" or key=="space" then
    if G.gs=="title" or G.gs=="gameover"
       or G.gs=="attract_demo" or G.gs=="attract_scores" then
      G.attractTimer = 0
      startGame()
    elseif G.gs=="levelclear" then
      initLevel(G.level + 1)
    elseif G.gs=="win" then startGame()
    end
  end
  if G.debug and (G.gs=="title" or G.gs=="gameover") then
    for i = 1, #LEVELS do
      if key == tostring(i) then startGame(i) end
    end
  end
end

function love.draw()
  local ox,oy = 0,0
  if G.shake then
    local amp = math.max(1, math.floor(G.shake*10))
    ox = math.random(-amp,amp); oy = math.random(-amp,amp)
  end
  love.graphics.push()
  love.graphics.translate(ox, oy)
  Draw.stars()
  if     G.gs=="title"      then Draw.title()
  elseif G.gs=="playing"
      or G.gs=="ending"     then Draw.hud(); Draw.field(); Draw.inputBar()
  elseif G.gs=="levelclear" then Draw.hud(); Draw.field(); Draw.levelClear()
  elseif G.gs=="gameover"   then Draw.hud(); Draw.field(); Draw.inputBar(); Draw.overlay("GAME  OVER", COL.warn, "ALL YOUR BASE ARE BELONG TO US")
  elseif G.gs=="win"        then Draw.overlay("YOU  WIN!", COL.good)
  elseif G.gs=="initials"   then Draw.initials()
  elseif G.gs=="attract_demo" then
    Draw.hud(); Draw.field()
    -- Pulsing start prompt
    local pulse = 0.55 + 0.45 * math.abs(math.sin(love.timer.getTime() * 2.8))
    love.graphics.setColor(COL.warn[1], COL.warn[2], COL.warn[3], pulse)
    love.graphics.setFont(G.pfnt)
    local msg = "PRESS  SPACE  OR  ENTER  TO  START"
    love.graphics.print(msg, math.floor(G.W/2 - G.pfnt:getWidth(msg)/2), G.H - 42)
    -- Small DEMO label in corner
    local a = 0.45 + 0.55 * math.abs(math.sin(love.timer.getTime() * 2.2))
    love.graphics.setColor(COL.boss[1], COL.boss[2], COL.boss[3], a)
    love.graphics.setFont(G.bfnt)
    love.graphics.print("DEMO", G.W - G.bfnt:getWidth("DEMO") - 14, G.H - 52)
  elseif G.gs=="attract_scores" then Draw.scores()
  end
  love.graphics.pop()
end
