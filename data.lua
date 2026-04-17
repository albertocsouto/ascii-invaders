-- ════════════════════════════════════════════════════════════
--  Static game data (constants, tables, config defaults)
--  Acts as the single gateway: requires levels, bonus, boss
--  and re-exports everything main.lua needs.
-- ════════════════════════════════════════════════════════════

local Levels = require "levels"   -- LEVELS, DIFFICULTY
local Bonus  = require "bonus"    -- WAVE_TEMPLATES, STAGES
local Boss   = require "boss"     -- BOSS config

local WORDS = {
  alpha = {  -- single letters (level 1)
    "a","b","c","d","e","f","g","h","i","j","k","l","m",
    "n","o","p","q","r","s","t","u","v","w","x","y","z",
  },
  digram = {  -- 2-letter words (level 2 bullets)
    "ab","ad","am","an","as","at","be","by","do","go",
    "he","hi","if","in","is","it","me","my","no","of",
    "oh","ok","on","or","so","to","up","us","we","yo",
  },
  tri = {  -- 3-letter words (level 2 enemies / level 3 bullets)
    "ace","act","age","aim","arc","art","axe","bay","bit","bow",
    "bug","can","cap","car","cat","cog","cup","cut","dot","dry",
    "ear","egg","end","eve","eye","fan","fee","fix","fly","fog",
    "fun","gap","gem","gun","hat","hit","hub","hug","ice","ion",
    "jam","jar","jet","joy","key","kit","law","leg","let","lid",
    "log","lot","map","mud","net","nod","nut","oak","orb","ore",
    "owl","pad","pan","peg","pen","pig","pin","pod","pop","pot",
    "ray","red","rib","rip","rod","row","run","rut","rye","sad",
    "saw","say","sea","set","shy","sip","sky","sly","spy","sun",
    "tag","tan","tap","tar","tea","tip","top","toy","tug","web",
    "win","wit","woe","yam","zip",
  },
  short = {  -- 3-4 letter words (level 3 bullets / level 4+)
    "aim","arc","axe","bit","bolt","boom","cast","chip","cog",
    "cut","dart","dot","fly","fog","gap","gem","gun","hex","hub",
    "ion","jet","lag","map","net","orb","pod","pop","ray","rim",
    "rod","run","saw","sky","sun","tip","top","wax","web","zap","zip",
  },
  medium = {  -- 4-6 letter words
    "alien","blast","blaze","boost","comet","craft","crush","cyber",
    "delta","dodge","drone","ember","focus","forge","frost","ghost",
    "glare","glide","globe","laser","light","lunar","merge","metal",
    "micro","night","nova","orbit","phase","pilot","pixel","pivot",
    "plane","polar","power","probe","pulse","radar","radio","relay",
    "repel","robot","scope","scout","shift","sigma","slash","smoke",
    "solar","sonic","spark","speed","spike","squad","stars","storm",
    "surge","sweep","swift","synth","trace","track","trail","turbo",
    "twist","ultra","vault","vortex","warp","watch","wave","xenon",
  },
  long = {  -- 7+ letter words
    "android","arsenal","barrier","blaster","booster","capture",
    "carrier","cluster","command","control","cryptic","crystal",
    "defense","destroy","digital","disable","eclipse","evasion",
    "exhaust","faction","fighter","firewall","fractal","freedom",
    "gateway","gravity","hostile","impulse","invasion","kinetic",
    "lockdown","machine","magnetic","maximum","missile","mission",
    "monitor","network","nuclear","override","phantom","platoon",
    "quantum","reactor","recharge","reflect","retreat","reverse",
    "scanner","section","shatter","shelter","shimmer","silicon",
    "soldier","station","stellar","striker","tactics","torpedo",
    "tracker","trigger","turbine","upgrade","venture","victory",
    "voltage","warrior","weapons","zenith",
  },
  shmup = {  -- funny old-school shmup phrases (boss final phase)
    "insertcoin","playerone","noquarter","extendship",
    "firepower","selectship","finalstage","lastboss",
    "galaxyfighter","roundclear","allclear","newrecord",
    "continueplay","shootemup","blastoff","defenseless",
    "creditsonly","loopthegame","secretbonus","grandmaster",
    "scoreboard","congraturation","allbasesbelong",
    "pleasecontinue","youaredead","gameclear",
  },
}


local SPR = {
  -- base sprites per HP level (all 7 chars wide)
  base = {
    [3] = { " ##### ", "/#####\\", "#######" },
    [2] = { "  ###  ", "/## ##\\", "##   ##" },
    [1] = { "       ", "/  #  \\", "#     #" },
  },
  boss    = {
    "  /-------\\  ",
    " /##@###@##\\ ",
    "(#####@#####)",
    " \\##@###@##/ ",
    "  |/     \\|  ",
  },
  mid     = { " -@-@- ", "  @@@  ", "  -|-  " },
  grunt   = { "  o o  ", "  @@@  " },
  ebullet = { " : " },
  exp1    = { " \\|/ ", " -X- ", " /|\\ " },
  exp2    = { "  * * ", " *   *", "  * * " },
}

local PTS = { boss = 300, mid = 150, grunt = 80, bonus_enemy = 100 }

local COL = {
  bg          = {0.00, 0.00, 0.08},
  base_full   = {0.20, 1.00, 0.40},
  base_mid    = {1.00, 0.85, 0.00},
  base_low    = {1.00, 0.30, 0.30},
  boss        = {1.00, 0.80, 0.10},
  mid         = {0.40, 0.80, 1.00},
  grunt       = {0.40, 1.00, 0.50},
  ebullet     = {1.00, 0.30, 0.30},
  hud         = {1.00, 1.00, 1.00},
  dim         = {0.40, 0.40, 0.52},
  sep         = {0.18, 0.18, 0.38},
  good        = {0.20, 1.00, 0.40},
  warn        = {1.00, 0.30, 0.30},
  wordDim     = {0.70, 0.70, 0.85},
  wordTyped   = {1.00, 1.00, 0.25},
  wordPending = {1.00, 0.55, 0.10},
  laser       = {1.00, 1.00, 0.50},
  mistype     = {1.00, 0.10, 0.10},
}

local CFG = {
  formY0      = 72,
  formSpd     = 38,
  dvSpeed     = 155,
  diveInt     = 4.2,
  maxDivers   = 2,
  dmgBullet   = 1,
  dmgDiver    = 2,
  -- set per level:
  ebSpeed     = 90,
  eShootInt   = 2.0,
  cols        = 8,
}

return {
  WORDS          = WORDS,
  LEVELS         = Levels.LEVELS,
  DIFFICULTY     = Levels.DIFFICULTY,
  WAVE_TEMPLATES = Bonus.WAVE_TEMPLATES,
  BOSS           = Boss,
  SPR            = SPR,
  PTS            = PTS,
  COL            = COL,
  CFG            = CFG,
  BASE_MAX_HP    = 3,
  NUM_BASES      = 5,
  MAX_LB         = 10,
  DISPLAY_LB     = 5,
}
