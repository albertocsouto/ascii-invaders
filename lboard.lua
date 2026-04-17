-- ════════════════════════════════════════════════════════════
--  Leaderboard module
-- ════════════════════════════════════════════════════════════

local LB = {}
LB.data = { score={}, time_game={} }

local MAX_LB

-- True if `score` would place in the top-MAX_LB list.
function LB.qualifies(score)
  local list = LB.data.score
  return #list < MAX_LB or score > (list[#list] and list[#list].score or -1)
end

-- True if `time` would place in the top-MAX_LB time list.
function LB.qualifiesTime(time)
  local list = LB.data.time_game
  return #list < MAX_LB or time < (list[#list] and list[#list].time or math.huge)
end

-- Insert entry at the correct rank. Returns rank (1..MAX_LB) or nil.
function LB.insert(list, entry, isBetter)
  local pos = #list + 1
  for i, e in ipairs(list) do
    if isBetter(entry, e) then pos = i; break end
  end
  if pos > MAX_LB then return nil end
  table.insert(list, pos, entry)
  if #list > MAX_LB then table.remove(list) end
  return pos
end

local function lbSerialize()
  local t = {"return {\n  score={\n"}
  for _, e in ipairs(LB.data.score) do
    t[#t+1] = string.format("    {score=%d,level=%d,initials=%q},\n",
      e.score, e.level, e.initials or "---")
  end
  t[#t+1] = "  },\n  time_game={\n"
  for _, e in ipairs(LB.data.time_game) do
    t[#t+1] = string.format("    {time=%.4f,initials=%q},\n", e.time, e.initials or "---")
  end
  t[#t+1] = "  },\n}"
  return table.concat(t)
end

function LB.save()
  love.filesystem.write("scores.lua", lbSerialize())
end

function LB.load(maxLb)
  MAX_LB   = maxLb
  LB.data  = {score={}, time_game={}}
  local ok, chunk = pcall(love.filesystem.load, "scores.lua")
  if ok and chunk then
    local ok2, data = pcall(chunk)
    if ok2 and type(data) == "table" then
      if type(data.score)     == "table" then LB.data.score     = data.score     end
      if type(data.time_game) == "table" then LB.data.time_game = data.time_game end
    end
  end
end

return LB
