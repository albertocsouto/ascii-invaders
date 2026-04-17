-- ════════════════════════════════════════════════════════════
--  Draw module
-- ════════════════════════════════════════════════════════════

local Draw = {}

local G, D, Sound, LB
local COL, SPR, LEVELS, CFG, DISPLAY_LB

function Draw.init(g, d, s, lb)
  G = g; D = d; Sound = s; LB = lb
  COL        = D.COL
  SPR        = D.SPR
  LEVELS     = D.LEVELS
  CFG        = D.CFG
  DISPLAY_LB = D.DISPLAY_LB
end

local _savedG = nil
function Draw.pushContext(g) _savedG = G; G = g end
function Draw.popContext()   if _savedG then G = _savedG; _savedG = nil end end

-- ────────────────────────────────────────────────────────────
--  Local helpers
-- ────────────────────────────────────────────────────────────

local function sprW(spr) return #spr[1] * G.CW end
local function sprH(spr) return #spr  * G.CH end

local function setCol(c, a)
  love.graphics.setColor(c[1], c[2], c[3], a or 1)
end

local function centered(font, text, y, c, a)
  setCol(c or COL.hud, a)
  love.graphics.setFont(font)
  love.graphics.print(text, math.floor(G.W/2 - font:getWidth(text)/2), y)
end

local function centeredAt(font, text, cx, y, c, a)
  setCol(c or COL.hud, a)
  love.graphics.setFont(font)
  love.graphics.print(text, math.floor(cx - font:getWidth(text)/2), y)
end

local function drawSpr(spr, x, y, c, a)
  setCol(c or COL.hud, a)
  love.graphics.setFont(G.fnt)
  for i, line in ipairs(spr) do
    love.graphics.print(line, math.floor(x), math.floor(y + (i-1)*G.CH))
  end
end

local function drawWord(word, nTyped, x, y, active)
  love.graphics.setFont(G.wfnt)
  local xi, yi = math.floor(x), math.floor(y)
  if nTyped > 0 then
    local done = word:sub(1, nTyped)
    setCol(COL.wordTyped)
    love.graphics.print(done, xi, yi)
    xi = xi + G.wfnt:getWidth(done)
  end
  setCol(active and COL.wordPending or COL.wordDim)
  love.graphics.print(word:sub(nTyped+1), xi, yi)
  love.graphics.setFont(G.fnt)
end

local function baseSpr(hp)
  return SPR.base[math.max(1, math.min(D.BASE_MAX_HP, hp))]
end

local function baseCol(hp)
  if hp >= 3 then return COL.base_full
  elseif hp >= 2 then return COL.base_mid
  else return COL.base_low end
end

local function fx0()
  return (G.W - LEVELS[G.level].cols * G.cellW) / 2 + G.formOX
end

local function epos(r, c)
  return fx0() + (c-1)*G.cellW, CFG.formY0 + (r-1)*G.cellH
end

local function hasPrefix(word)
  return #G.typed > 0 and word:sub(1, #G.typed) == G.typed
end

local function aliveCount()
  local n = 0
  for r = 1, LEVELS[G.level].rows do
    for c = 1, LEVELS[G.level].cols do
      if G.grid[r] and G.grid[r][c] then n=n+1 end
    end
  end
  for _, dv in ipairs(G.divers) do if dv.alive then n=n+1 end end
  for _, be in ipairs(G.bonusEnemies or {}) do if be.alive then n=n+1 end end
  return n
end

local function hsvToRgb(h, s, v)
  h = h % 360
  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c
  local r, g, b
  if     h < 60  then r,g,b = c,x,0
  elseif h < 120 then r,g,b = x,c,0
  elseif h < 180 then r,g,b = 0,c,x
  elseif h < 240 then r,g,b = 0,x,c
  elseif h < 300 then r,g,b = x,0,c
  else                r,g,b = c,0,x end
  return r+m, g+m, b+m
end

local function fmtTime(t)
  local m  = math.floor(t / 60)
  local s  = math.floor(t % 60)
  local cs = math.floor((t % 1) * 10)
  return string.format("%d:%02d.%d", m, s, cs)
end

local function accuracy(keys, mistypes)
  if keys == 0 then return 100 end
  return math.floor((keys - mistypes) / keys * 100)
end

-- ────────────────────────────────────────────────────────────
--  Public draw functions
-- ────────────────────────────────────────────────────────────

function Draw.stars()
  love.graphics.setFont(G.fnt)
  for _, s in ipairs(G.stars) do
    love.graphics.setColor(s.r, s.g, s.b)
    love.graphics.print(s.ch, s.x, s.y)
  end
end

function Draw.hud()
  local lvl = LEVELS[G.level]
  love.graphics.setFont(G.fnt)
  setCol(COL.hud)
  love.graphics.print("SCORE  "..G.score, 12, 8)
  if G.multiplier > 1 then
    local mx = "x"..G.multiplier
    setCol(COL.wordTyped)
    love.graphics.print(mx, 12 + G.fnt:getWidth("SCORE  "..G.score) + 8, 8)
    setCol(COL.hud)
  end

  local prog
  if lvl.winBy == "deflect" then
    prog = lvl.title.."   deflected "..G.deflectCount.." / "..lvl.winCount
  elseif lvl.winBy == "boss" then
    if G.boss_entity and G.boss_entity.alive then
      local hp = G.boss_entity.hp
      prog = lvl.title.."   BOSS  "..string.rep("|", hp)..string.rep(".", G.boss_entity.maxHp - hp)
    else
      prog = lvl.title.."   BOSS DEFEATED"
    end
  elseif lvl.winBy == "bonus" then
    prog = lvl.title.."   "..G.bonusKilled.." / "..(G.bonusTotal or 0).."  hit"
  else
    prog = lvl.title.."   enemies "..aliveCount().." left"
  end
  love.graphics.print(prog, math.floor(G.W/2-G.fnt:getWidth(prog)/2), 8)

  local hiStr = "HI  "..G.hi
  setCol(G.score >= G.hi and G.hi > 0 and COL.wordTyped or COL.hud)
  love.graphics.print(hiStr, G.W-G.fnt:getWidth(hiStr)-12, 8)

  setCol(COL.sep)
  love.graphics.line(0,30,G.W,30)
  love.graphics.line(0,G.H-54,G.W,G.H-54)
end

function Draw.field()
  -- Laser flashes
  for _, s in ipairs(G.shots) do
    local a=1-s.t/s.dur
    setCol(COL.laser, a)
    love.graphics.setLineWidth(2)
    love.graphics.line(s.x1,s.y1,s.x2,s.y2)
    love.graphics.setLineWidth(1)
  end

  -- Grid enemies
  local lvl = LEVELS[G.level]
  for r=1,lvl.rows do
    for c=1,lvl.cols do
      local e=G.grid[r] and G.grid[r][c]
      if e then
        local ex,ey=epos(r,c)
        local spr=SPR[e.type]
        local active=hasPrefix(e.word)
        drawSpr(spr, ex, ey, COL[e.type])
        local wy=ey-G.WCH-2
        local wx=ex+sprW(spr)/2 - G.wfnt:getWidth(e.word)/2
        drawWord(e.word, active and #G.typed or 0, wx, wy, active)
      end
    end
  end

  -- Divers
  for _, dv in ipairs(G.divers) do
    if dv.alive then
      local active=hasPrefix(dv.word)
      -- Rainbow: during warning and throughout the dive
      love.graphics.setFont(G.fnt)
      local baseHue = (love.timer.getTime() * 200) % 360
      for i, line in ipairs(dv.spr) do
        local r, g, b = hsvToRgb(baseHue + i * 50, 1, 1)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.print(line, math.floor(dv.x), math.floor(dv.y + (i-1)*G.CH))
      end
      local wy=dv.y-G.WCH-2
      local wx=dv.x+sprW(dv.spr)/2 - G.wfnt:getWidth(dv.word)/2
      drawWord(dv.word, active and #G.typed or 0, wx, wy, active)
    end
  end

  -- Boss
  if G.boss_entity and G.boss_entity.alive then
    local spr = SPR.boss
    local flashing = G.boss_entity.invTimer and (math.floor(G.boss_entity.invTimer * 8) % 2 == 0)
    if not flashing then
      -- Core color changes with HP phase
      local coreCol = G.boss_entity.hp >= 4 and COL.boss or (G.boss_entity.hp >= 2 and COL.mid or COL.warn)
      -- Per-row colors: wings→body→core→body→legs
      local rowCols = { COL.mid, COL.boss, coreCol, COL.boss, COL.mid }
      love.graphics.setFont(G.fnt)
      for i, line in ipairs(spr) do
        setCol(rowCols[i] or coreCol)
        love.graphics.print(line, math.floor(G.boss_entity.x), math.floor(G.boss_entity.y + (i-1)*G.CH))
      end

      local wx = G.boss_entity.x + sprW(spr)/2
      local wy = G.boss_entity.y - G.WCH - 2
      if G.boss_entity.word and not G.boss_entity.invTimer then
        local active = hasPrefix(G.boss_entity.word)
        drawWord(G.boss_entity.word, active and #G.typed or 0, wx - G.wfnt:getWidth(G.boss_entity.word)/2, wy, active)
      elseif G.boss_entity.invTimer then
        local msg = "* HIT *"
        love.graphics.setFont(G.wfnt)
        setCol(COL.warn)
        love.graphics.print(msg, math.floor(wx - G.wfnt:getWidth(msg)/2), math.floor(wy))
        love.graphics.setFont(G.fnt)
      end
    end
  end

  -- Bonus enemies
  if LEVELS[G.level].winBy == "bonus" then
    for _, be in ipairs(G.bonusEnemies or {}) do
      if be.alive then
        local active = hasPrefix(be.word)
        drawSpr(be.spr, be.x, be.y, COL[be.eType])
        local wy = be.y - G.WCH - 2
        local wx = be.x + sprW(be.spr)/2 - G.wfnt:getWidth(be.word)/2
        drawWord(be.word, active and #G.typed or 0, wx, wy, active)
      end
    end
  end

  -- Bases
  for _, base in ipairs(G.bases) do
    if base.alive then
      local spr = baseSpr(base.hp)
      drawSpr(spr, base.x, base.y, baseCol(base.hp))
    end
  end

  -- Enemy bullets
  for _, b in ipairs(G.eb) do
    local active=b.word and hasPrefix(b.word)
    drawSpr(SPR.ebullet, b.x, b.y, COL.ebullet)
    if b.word then
      local bx=b.x+sprW(SPR.ebullet)+2
      drawWord(b.word, active and #G.typed or 0, bx, b.y, active)
    end
  end

  -- Explosions
  for _, e in ipairs(G.exps) do
    local frac=e.t/e.dur
    local spr=frac<0.5 and SPR.exp1 or SPR.exp2
    drawSpr(spr, e.x-sprW(spr)/2, e.y-sprH(spr)/2, e.col, 1-frac)
  end

  -- Letter burst particles
  love.graphics.setFont(G.mfnt)
  for _, p in ipairs(G.particles) do
    setCol(p.col, 1 - p.t / p.dur)
    love.graphics.print(p.ch, math.floor(p.x), math.floor(p.y))
  end

  -- Score pop-ups
  for _, p in ipairs(G.pops) do
    local alpha = 1 - p.t / p.dur
    setCol(p.col, alpha)
    love.graphics.print(p.text, math.floor(p.x - G.wfnt:getWidth(p.text)/2), math.floor(p.y))
  end
  love.graphics.setFont(G.fnt)
end

function Draw.inputBar()
  local y = G.H - 42
  love.graphics.setFont(G.fnt)
  if G.mistype then
    setCol(COL.mistype, G.mistype/0.22)
    local msg="[ MISTYPE! ]"
    love.graphics.print(msg, math.floor(G.W/2-G.fnt:getWidth(msg)/2), y)
  else
    setCol(COL.dim); love.graphics.print("> ", 12, y)
    if #G.typed > 0 then
      setCol(COL.wordTyped)
      love.graphics.print(G.typed, 12+G.fnt:getWidth("> "), y)
    else
      setCol(COL.dim)
      love.graphics.print("start typing any word you see...", 12+G.fnt:getWidth("> "), y)
    end
  end
  setCol(COL.dim)
  local hint="BACKSPACE: reset   ESC: quit"
  love.graphics.print(hint, math.floor(G.W/2-G.fnt:getWidth(hint)/2), G.H-20)
end

function Draw.title()
  -- ── ASCII art title ──────────────────────────────────────
  love.graphics.setFont(G.fnt)
  local artAscii = {
    "  ###   #####   #####  #####  ##### ",
    " #   #  #       #        #      #   ",
    " #####   ###    #        #      #   ",
    " #   #       #  #        #      #   ",
    " #   #  #####   #####  #####  ##### ",
  }
  local artInv = {
    " #####  #   #  #   #   ###   ####   #####  ####   ##### ",
    "   #    ##  #  #   #  #   #  #   #  #      #   #  #     ",
    "   #    # # #   # #   #####  #   #  ####   ####    ###  ",
    "   #    #  ##   # #   #   #  #   #  #      # #        # ",
    " #####  #   #    #    #   #  ####   #####  #  ##  ##### ",
  }
  local rowCols = { COL.boss, COL.mid, COL.warn, COL.mid, COL.boss }

  local y1 = math.floor(G.H/2 - 210)
  local x1 = math.floor((G.W - G.fnt:getWidth(artAscii[1])) / 2)
  for i, line in ipairs(artAscii) do
    setCol(rowCols[i])
    love.graphics.print(line, x1, y1 + (i-1)*G.CH)
  end

  local y2 = y1 + 5*G.CH + 20
  local x2 = math.floor((G.W - G.fnt:getWidth(artInv[1])) / 2)
  for i, line in ipairs(artInv) do
    setCol(rowCols[i])
    love.graphics.print(line, x2, y2 + (i-1)*G.CH)
  end

  -- ── Instructions ─────────────────────────────────────────
  love.graphics.setFont(G.fnt)
  local rows={
    {COL.ebullet, SPR.ebullet[1], " type the letter / word on each bullet to deflect it"},
    {COL.mid,     SPR.mid[2],     " type the word on each enemy to shoot it"},
    {COL.good,    " ",            " defend your 5 bases — game over when all are destroyed"},
  }
  local maxIconW, maxTxtW = 0, 0
  for _, row in ipairs(rows) do
    maxIconW = math.max(maxIconW, G.fnt:getWidth(row[2]))
    maxTxtW  = math.max(maxTxtW,  G.fnt:getWidth(row[3]))
  end
  local sep = G.CW
  local bx  = math.floor((G.W - (maxIconW + sep + maxTxtW)) / 2)
  local tx  = bx + maxIconW + sep
  for i, row in ipairs(rows) do
    local y = G.H/2+22+(i-1)*30
    setCol(row[1]); love.graphics.print(row[2], bx, y)
    setCol(COL.hud); love.graphics.print(row[3], tx, y)
  end
  local pulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 2.8)
  centered(G.pfnt, "PRESS  SPACE  OR  ENTER  TO  START", G.H/2+112, COL.warn, pulse)
  if G.debug then
    centered(G.fnt, "debug:  1  2  3  4  5  6  7  to jump to a level", G.H/2+120, COL.dim)
  end

end

function Draw.levelClear()
  love.graphics.setColor(0,0,0,0.70)
  love.graphics.rectangle("fill",0,0,G.W,G.H)

  local lvl  = LEVELS[G.level]
  local next = LEVELS[G.level+1]
  local acc  = accuracy(G.lvlKeys, G.lvlMistypes)

  if lvl.winBy == "bonus" then
    -- ── Bonus clear variant ─────────────────────────────────
    local titleCol = G.bonusPerfect and COL.wordTyped or COL.good
    centered(G.bfnt, lvl.title.."  CLEAR!", G.H/2-120, titleCol)
    centered(G.fnt,  "SCORE  "..G.score, G.H/2-68, COL.hud)
    local killPct = G.bonusTotal > 0 and math.floor(G.bonusKilled / G.bonusTotal * 100) or 0
    local stats = "ACCURACY  "..acc.."%     KILLED  "..killPct.."%     TIME  "..fmtTime(G.lvlTime)
    centered(G.fnt, stats, G.H/2-48, COL.mid)
    setCol(COL.sep)
    love.graphics.rectangle("fill", G.W/2-200, G.H/2-22, 400, 1)

    local lcx = G.W/3
    local hitStr = G.bonusKilled.." / "..(G.bonusTotal or 0).."  enemies destroyed"
    if G.bonusPerfect then
      centeredAt(G.bfnt, "PERFECT!", lcx, G.H/2+4, COL.wordTyped)
      centeredAt(G.fnt, "+3000  BONUS", lcx, G.H/2+44, COL.wordTyped)
    else
      centeredAt(G.fnt, hitStr, lcx, G.H/2+18, COL.hud)
    end
    centered(G.fnt, "next: "..next.title, G.H/2+68, COL.mid)
    centered(G.fnt, "PRESS  SPACE  OR  ENTER  TO  CONTINUE", G.H/2+105, COL.warn)
    return
  end

  -- ── Normal level clear ──────────────────────────────────────
  centered(G.bfnt, lvl.title.."  CLEAR!", G.H/2-120, COL.good)
  centered(G.fnt,  "SCORE  "..G.score, G.H/2-68, COL.hud)
  local stats = "ACCURACY  "..acc.."%     MAX COMBO  x"..G.lvlMaxCombo.."     TIME  "..fmtTime(G.lvlTime)
  centered(G.fnt, stats, G.H/2-48, COL.mid)

  setCol(COL.sep)
  love.graphics.rectangle("fill", G.W/2-200, G.H/2-22, 400, 1)

  centered(G.bfnt, next.title,    G.H/2+4,  COL.mid)
  centered(G.fnt,  next.subtitle, G.H/2+46, COL.hud)
  centered(G.fnt,  next.hint,     G.H/2+68, COL.dim)

  centered(G.fnt, "PRESS  SPACE  OR  ENTER  TO  CONTINUE", G.H/2+105, COL.warn)
end

function Draw.overlay(msg, c, sub)
  love.graphics.setColor(0,0,0,0.65)
  love.graphics.rectangle("fill",0,0,G.W,G.H)
  centered(G.bfnt, msg, G.H/2-115, c)
  if sub then
    centered(G.fnt, sub, G.H/2-65, COL.dim)
  end
  centered(G.fnt, "SCORE  "..G.score, G.H/2-45, COL.hud)
  local acc = accuracy(G.gameKeys, G.gameMistypes)
  local stats = "ACCURACY  "..acc.."%     MAX COMBO  x"..G.gameMaxCombo.."     TIME  "..fmtTime(G.gameTime)
  centered(G.fnt, stats, G.H/2-25, COL.mid)

  setCol(COL.sep)
  love.graphics.rectangle("fill", G.W/2-200, G.H/2, 400, 1)

  -- Best game times (win only)
  if G.gs == "win" then
    local rcx = G.W*2/3
    centeredAt(G.fnt, "BEST  GAME  TIMES", rcx, G.H/2+10, COL.dim)
    if #LB.data.time_game == 0 then
      centeredAt(G.fnt, "no records yet", rcx, G.H/2+28, COL.dim)
    else
      for i, e in ipairs(LB.data.time_game) do
        if i > DISPLAY_LB then break end
        local col = (i == G.lastGameTimeRank) and COL.good or COL.hud
        centeredAt(G.fnt, string.format("%d.  %-3s  %s", i, e.initials or "---", fmtTime(e.time)), rcx, G.H/2+10+i*18, col)
      end
    end
    setCol(COL.sep)
    love.graphics.line(G.W/2, G.H/2+6, G.W/2, G.H/2+100)
  end

  centered(G.fnt, "PRESS SPACE OR ENTER TO PLAY AGAIN", G.H/2+112, COL.warn)
end

function Draw.initials()
  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, G.W, G.H)

  local blink = math.abs(math.sin(love.timer.getTime() * 3.2))

  local isScoreRecord = G.pendingScore ~= nil
  local isTimeRecord  = G.pendingTime ~= nil
  centered(G.bfnt, isScoreRecord and "NEW  HIGH  SCORE!" or "NEW  BEST  TIME!", G.H/2 - 148, COL.wordTyped)
  local infoY = G.H/2 - 98
  if isScoreRecord then
    centered(G.fnt, string.format("SCORE  %d   —   LEVEL %d",
      G.pendingScore.score, G.pendingScore.level), infoY, COL.hud)
    infoY = infoY + 18
  end
  if isTimeRecord then
    centered(G.fnt, string.format("TIME  %s", fmtTime(G.pendingTime.time)), infoY, COL.mid)
  end

  setCol(COL.sep)
  love.graphics.line(G.W/2 - 170, G.H/2 - 70, G.W/2 + 170, G.H/2 - 70)

  centered(G.fnt, "ENTER  YOUR  INITIALS", G.H/2 - 54, COL.dim)

  -- Three character slots
  local slotW   = G.bfnt:getWidth("W") + 18
  local gap     = 14
  local totalW  = slotW * 3 + gap * 2
  local sx      = math.floor(G.W/2 - totalW/2)
  local sy      = G.H/2 - 26

  love.graphics.setFont(G.bfnt)
  for i = 1, 3 do
    local ch  = G.initialsBuffer:sub(i, i)
    local cx  = sx + (i-1) * (slotW + gap) + slotW/2
    local x   = math.floor(cx - G.bfnt:getWidth(ch ~= "" and ch or "_") / 2)
    if ch ~= "" then
      setCol(COL.wordTyped)
      love.graphics.print(ch, x, sy)
    elseif i == #G.initialsBuffer + 1 then
      love.graphics.setColor(COL.warn[1], COL.warn[2], COL.warn[3], 0.4 + 0.6 * blink)
      love.graphics.print("_", x, sy)
    else
      setCol(COL.dim, 0.4)
      love.graphics.print("_", x, sy)
    end
  end

  setCol(COL.sep)
  love.graphics.line(G.W/2 - 170, G.H/2 + 58, G.W/2 + 170, G.H/2 + 58)
  centered(G.fnt, "BACKSPACE  to delete   —   ENTER  to confirm", G.H/2 + 72, COL.dim)
end

function Draw.scores()
  local pulse   = 0.55 + 0.45 * math.sin(love.timer.getTime() * 1.4)
  local y0      = 58       -- top of content area
  local rowH    = 20
  local hasTimes = #LB.data.time_game > 0
  local scx     = hasTimes and math.floor(G.W * 0.38) or math.floor(G.W / 2)
  local tcx     = math.floor(G.W * 0.78)
  local y1      = y0 + 78  -- first data row

  centered(G.bfnt, "HIGH  SCORES", y0, COL.boss, pulse)

  setCol(COL.sep)
  love.graphics.line(60, y0 + 46, G.W - 60, y0 + 46)

  -- Score column
  if #LB.data.score > 0 then
    centeredAt(G.fnt, "TOP  SCORES", scx, y0 + 50, COL.dim)
    for i, e in ipairs(LB.data.score) do
      local c   = i == 1 and COL.wordTyped or COL.hud
      local txt = string.format("%2d  %-3s  %5d  level%d",
        i, e.initials or "---", e.score, e.level)
      centeredAt(G.pfnt, txt, scx, y1 + (i-1)*rowH, c)
    end
  else
    centeredAt(G.fnt, "no records yet", scx, y1, COL.dim)
  end

  -- Times column
  if hasTimes then
    centeredAt(G.fnt, "BEST  TIMES", tcx, y0 + 50, COL.dim)
    for i, e in ipairs(LB.data.time_game) do
      if i > DISPLAY_LB then break end
      local c = i == 1 and COL.good or COL.hud
      centeredAt(G.pfnt, string.format("%-3s  %s", e.initials or "---", fmtTime(e.time)), tcx, y1 + (i-1)*rowH, c)
    end
    setCol(COL.sep)
    local divX = math.floor(G.W * 0.58)
    love.graphics.line(divX, y0 + 48, divX, y1 + #LB.data.score * rowH + 4)
  end

  local yBot = y1 + math.max(#LB.data.score, 1) * rowH + 12
  setCol(COL.sep)
  love.graphics.line(60, yBot, G.W - 60, yBot)
  centered(G.pfnt, "PRESS  SPACE  OR  ENTER  TO  START", yBot + 14, COL.warn, pulse)
end

-- ────────────────────────────────────────────────────────────
--  Exported utility shorthands (used by main.lua game logic)
-- ────────────────────────────────────────────────────────────

Draw.sprW       = sprW
Draw.sprH       = sprH
Draw.fx0        = fx0
Draw.epos       = epos
Draw.hasPrefix  = hasPrefix
Draw.aliveCount = aliveCount

return Draw
