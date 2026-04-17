-- ════════════════════════════════════════════════════════════
--  Sound module
-- ════════════════════════════════════════════════════════════

local Sound = {}
local sounds = {}
local pools  = {}

-- Pool sizes for frequently played sounds (limits concurrent OpenAL sources)
local POOL_SIZES = {
  shoot      = 3,
  kill       = 5,
  deflect    = 3,
  hit        = 2,
  explode    = 2,
  combo      = 3,
  mistype    = 2,
  ebullet    = 6,
  diver_dive = 1,
}

local function buildPool(name, size)
  local src = sounds[name]
  if not src then return end
  local p = {}
  for i = 1, size do p[i] = src:clone() end
  pools[name] = p
end

local function buildSounds()
  local rate = 44100
  local function gen(dur, fn)
    local n = math.floor(rate * dur)
    local sd = love.sound.newSoundData(n, rate, 16, 1)
    for i = 0, n-1 do
      local t = i / rate
      sd:setSample(i, math.max(-1, math.min(1, fn(t, t/dur))))
    end
    return love.audio.newSource(sd, "static")
  end
  local sq  = function(ph) return math.sin(ph) >= 0 and 1.0 or -1.0 end
  local rnd = function()   return math.random()*2 - 1 end

  -- Laser fired from base: descending square-wave sweep
  sounds.shoot = gen(0.12, function(t, p)
    return sq(2*math.pi*(880 - p*770)*t) * (1-p) * 0.35
  end)

  -- Enemy destroyed: tone + noise burst
  sounds.kill = gen(0.18, function(t, p)
    local tone  = math.sin(2*math.pi*(600 - p*480)*t) * 0.5
    local noise = rnd() * 0.3
    return (tone + noise) * (1-p)*(1-p) * 0.5
  end)

  -- Bullet deflected: ascending sine chirp
  sounds.deflect = gen(0.10, function(t, p)
    local env = p < 0.1 and p/0.1 or (1-p)
    return math.sin(2*math.pi*(330 + p*990)*t) * env * 0.45
  end)

  -- Base hit: low square thud + noise
  sounds.hit = gen(0.20, function(t, p)
    local tone  = sq(2*math.pi*(110 - p*70)*t) * 0.6
    local noise = rnd() * 0.35
    return (tone + noise) * math.exp(-p*9) * 0.5
  end)

  -- Base destroyed: noise explosion + low rumble
  sounds.explode = gen(0.50, function(t, p)
    local noise  = rnd() * 0.7
    local rumble = math.sin(2*math.pi*55*t) * 0.3
    return (noise + rumble) * math.exp(-p*4) * 0.65
  end)

  -- Multiplier blip (pitch scaled per call)
  sounds.combo = gen(0.07, function(t, p)
    return math.sin(2*math.pi*880*t) * (1-p) * 0.30
  end)

  -- Mistype: short low buzz
  sounds.mistype = gen(0.08, function(t, p)
    return sq(2*math.pi*100*t) * (1-p) * 0.25
  end)

  -- Enemy bullet fired: low descending square blip
  sounds.ebullet = gen(0.10, function(t, p)
    return sq(2*math.pi*(200 - p*100)*t) * (1-p) * 0.22
  end)


  -- Diver diving: long descending sine sweep ("piiiiiiu"), 3s
  sounds.diver_dive = gen(3.0, function(t, p)
    local f0, f1 = 580, 80
    local phase = 2*math.pi * (f0*t + (f1-f0)*t*t / (2*3.0))
    return math.sin(phase) * (1 - p*0.4) * 0.36
  end)
end

local function buildMenuMusic()
  local rate = 44100
  local bpm  = 128
  local spb  = rate * 60 / bpm   -- samples per beat

  -- 25% duty-cycle pulse: classic chiptune lead timbre
  local function pulse(ph)
    return (ph % (2*math.pi)) < (math.pi * 0.5) and 0.7 or -0.7
  end
  -- Triangle wave: softer bass channel
  local function tri(ph)
    local p = (ph % (2*math.pi)) / (2*math.pi)
    return p < 0.5 and (p*4 - 1) or (3 - p*4)
  end

  local f = {
    C3=130.81, D3=146.83, E3=164.81, F3=174.61, G3=196.00, A3=220.00,
    C4=261.63, D4=293.66, E4=329.63, F4=349.23, G4=392.00, A4=440.00, B4=493.88,
    C5=523.25, D5=587.33, E5=659.25, F5=698.46, G5=783.99, A5=880.00,
    R=0,
  }

  -- 8-bar melody (4/4 time; 1 = quarter note, 0.5 = eighth)
  local mel = {
    {f.G5,0.5},{f.A5,0.5},{f.G5,1},{f.E5,1},{f.C5,1},    -- bar 1
    {f.G5,1},  {f.E5,1},  {f.C5,2},                       -- bar 2
    {f.F5,0.5},{f.G5,0.5},{f.F5,1},{f.D5,1},{f.A4,1},    -- bar 3
    {f.E5,1},  {f.C5,1},  {f.G4,2},                       -- bar 4
    {f.G5,0.5},{f.A5,0.5},{f.G5,0.5},{f.F5,0.5},{f.E5,1},{f.D5,1}, -- bar 5
    {f.E5,0.5},{f.F5,0.5},{f.G5,1}, {f.A5,2},             -- bar 6
    {f.G5,0.5},{f.F5,0.5},{f.E5,0.5},{f.D5,0.5},{f.E5,1},{f.G5,1}, -- bar 7
    {f.C5,4},                                               -- bar 8
  }

  -- 8-bar bass (half notes with rests for staccato feel)
  local bas = {
    {f.C3,1},{f.R,1},{f.G3,1},{f.R,1},   -- bar 1
    {f.C3,1},{f.R,1},{f.E3,1},{f.R,1},   -- bar 2
    {f.F3,1},{f.R,1},{f.C3,1},{f.R,1},   -- bar 3
    {f.C3,1},{f.R,1},{f.G3,2},            -- bar 4
    {f.C3,1},{f.R,1},{f.G3,1},{f.R,1},   -- bar 5
    {f.F3,1},{f.R,1},{f.G3,2},            -- bar 6
    {f.G3,1},{f.R,1},{f.C3,1},{f.R,1},   -- bar 7
    {f.C3,2},{f.G3,2},                    -- bar 8
  }

  local total = math.floor(32 * spb)
  local sd    = love.sound.newSoundData(total, rate, 16, 1)
  local gap   = math.floor(0.014 * rate)  -- ~14 ms silence between notes

  local function render(seq, wavefn, vol)
    local pos = 0
    for _, note in ipairs(seq) do
      local freq = note[1]
      local dur  = math.floor(note[2] * spb)
      local gate = math.max(0, dur - gap)
      local ph   = 0
      for i = 0, dur - 1 do
        if pos + i < total then
          local s = 0
          if freq > 0 and i < gate then
            ph = ph + 2*math.pi*freq/rate
            s  = wavefn(ph) * vol
          end
          sd:setSample(pos+i, math.max(-1, math.min(1, sd:getSample(pos+i) + s)))
        end
      end
      pos = pos + dur
    end
  end

  render(mel, pulse, 0.28)
  render(bas, tri,   0.22)

  local src = love.audio.newSource(sd, "static")
  src:setLooping(false)
  sounds.menu = src
end

local function buildJingles()
  local rate = 44100

  local function pulse(ph)
    return (ph % (2*math.pi)) < (math.pi * 0.5) and 0.6 or -0.6
  end

  local function buildJingle(seq)
    local total = 0
    for _, n in ipairs(seq) do total = total + math.floor(n[2] * rate) end
    local sd  = love.sound.newSoundData(total, rate, 16, 1)
    local gap = math.floor(0.015 * rate)
    local pos = 0
    for _, note in ipairs(seq) do
      local freq = note[1]
      local dur  = math.floor(note[2] * rate)
      local gate = math.max(0, dur - gap)
      local ph   = 0
      for i = 0, dur - 1 do
        local s = 0
        if freq > 0 and i < gate then
          ph = ph + 2*math.pi*freq/rate
          s  = pulse(ph) * math.max(0, 1 - i/gate*0.4) * 0.35
        end
        sd:setSample(pos + i, s)
      end
      pos = pos + dur
    end
    return love.audio.newSource(sd, "static")
  end

  -- Level clear: quick ascending arpeggio landing on a held high note
  sounds.jingle_clear = buildJingle({
    {261.63, 0.10},   -- C4
    {329.63, 0.10},   -- E4
    {392.00, 0.10},   -- G4
    {523.25, 0.55},   -- C5 (held)
  })

  -- Game over: slow descending phrase, heavy and final
  sounds.jingle_over = buildJingle({
    {392.00, 0.30},   -- G4
    {311.13, 0.30},   -- Eb4
    {261.63, 0.55},   -- C4 (held)
  })
end

function Sound.build()
  buildSounds()
  buildMenuMusic()
  buildJingles()
  for name, size in pairs(POOL_SIZES) do
    buildPool(name, size)
  end
end

function Sound.play(name, pitch)
  local pool = pools[name]
  if pool then
    -- Find a free (finished) slot; fall back to slot 1 if all are busy
    local src = pool[1]
    for _, s in ipairs(pool) do
      if not s:isPlaying() then src = s; break end
    end
    src:stop()
    src:setPitch(pitch or 1)
    src:play()
    return
  end
  -- Non-pooled sounds (diver_dive, jingles): clone once per call
  local s = sounds[name]
  if not s then return end
  local c = s:clone()
  if pitch then c:setPitch(pitch) end
  c:play()
end

-- Like play() but returns the source so the caller can stop it later.
-- Uses the pool slot (pool size must be 1 for exclusive sounds).
function Sound.playRaw(name)
  local pool = pools[name]
  if pool then
    local src = pool[1]
    src:stop()
    src:setPitch(1)
    src:play()
    return src
  end
  local s = sounds[name]
  if not s then return nil end
  local c = s:clone()
  c:play()
  return c
end

function Sound.startMenu()
  sounds.menu:play()
end

function Sound.stopMenu()
  sounds.menu:stop()
end

return Sound
