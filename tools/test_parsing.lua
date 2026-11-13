-- Offline test: runs Pawn's real tooltip reader (PawnLookForSingleStat) on real WoW Forever tooltip lines,
-- first with Pawn alone, then with PawnForever/Parsing.lua loaded, and checks the stats each line gives.
--
--   luajit tools/test_parsing.lua
-- Set ADDONS to your Interface/AddOns folder if Pawn isn't in the default Forever install.

local P = (os.getenv("ADDONS") or "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns") .. "/"

GetBuildInfo = function() return "1.60.1", "70790", "", 16001 end
WOW_PROJECT_ID = 99; WOW_PROJECT_CLASSIC = 2; WOW_PROJECT_MAINLINE = 1
strlen = string.len; strsub = string.sub; strlower = string.lower; strupper = string.upper; strmatch = string.match
gmatch = string.gmatch; tremove = table.remove; floor = math.floor; gsub = string.gsub; strfind = string.find
tinsert = table.insert; format = string.format; unpack = unpack or table.unpack
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
GetLocale = function() return "enUS" end
LARGE_NUMBER_SEPERATOR = ","
PawnMultipleStatsExtract = "_MultipleExtract"
setmetatable(_G, { __index = function(_, k)
  if type(k) == "string" and k:match("^[A-Z][A-Z0-9_]+$") then return "ZZUNSET_" .. k end
end })
dofile(P .. "Pawn/VgerCore/VgerCore.lua")
dofile(P .. "Pawn/Core.lua")
dofile(P .. "Pawn/Localization.lua")
dofile(P .. "Pawn/TooltipParsing.lua")

function PawnFindStringInRegexTable(s, t)
  for _, r in ipairs(t) do
    if r[1] then
      local m = { s:find(r[1]) }
      if m[1] then return r, { select(3, unpack(m)) } end
    end
  end
end

-- The stats one tooltip line gives, the way Pawn reads it: normalize, find the pattern, take the numbers.
local function Read(line)
  local s = strtrim(line)
  for _, e in pairs(PawnNormalizationRegexes) do s = gsub(s, e[1], e[2], 1) end
  local entry, m = PawnFindStringInRegexTable(s, PawnRegexes)
  if not entry then return nil end
  local stats = {}
  local i = 2
  while entry[i] do
    local idx = entry[i + 1] or 1
    stats[entry[i]] = (stats[entry[i]] or 0) + tonumber((m[idx] or ""):gsub("[^%d%.%-]", ""), 10)
    i = i + 3
  end
  return stats
end

local function Show(t)
  if not t then return "unread" end
  local k = {}
  for n, v in pairs(t) do k[#k + 1] = n .. "=" .. v end
  table.sort(k)
  return "{" .. table.concat(k, ", ") .. "}"
end

local cases = {
  -- Live Forever tooltips (item IDs noted). Expected = what Pawn + Pawn Forever should read.
  { "270275 Cleansed Vilebranch Medallion", "Equip: +14 Attack Power. This effect is tripled in Forest and Grassland areas.", { Ap = 14 } },
  { "270225 Jewel of the Guard Captain", "Equip: Increases damage and healing done by magical spells and effects by up to 8. This effect is tripled in Forest and Grassland areas.", { SpellDamage = 8, Healing = 8 } },
  { "zone Mp5", "Equip: Restores 3 Mana per 5 sec. This effect is tripled in Forest and Grassland areas.", { Mp5 = 3 } },
  { "zone fire", "Equip: Increases damage done by Fire spells and effects by up to 7. This effect is doubled in Volcanic areas.", { FireSpellDamage = 7 } },
  { "zone healing", "Equip: Increases healing done by magical spells and effects by up to 12. This effect is doubled in Swamp areas.", { Healing = 12 } },
  { "284268 Furbolg Shaman's Girdle (Wowhead text)", "Restores +5 mana per 5 sec.", { Mp5 = 5 } },
  { "Equip: mana per 5", "Equip: Restores 5 mana per 5 sec.", { Mp5 = 5 } },
  -- Must stay unread: Pawn doesn't score Use: effects.
  { "249470 Molten Heart of the Mountain (Use:)", "Use: Increase Attack Power by 55 for 15 sec. This effect is doubled in Volcanic areas. (5 Min Cooldown)", nil },
}

local stock = {}
for i, c in ipairs(cases) do stock[i] = Show(Read(c[2])) end

dofile("tools/fixtures/globals_enUS.lua")
local PF = {}
assert(loadfile("PawnForever/Parsing.lua"))("PawnForever", PF)

local failed = 0
for i, c in ipairs(cases) do
  local got, want = Show(Read(c[2])), Show(c[3])
  local ok = got == want
  if not ok then failed = failed + 1 end
  print(("%s  %-46s Pawn alone: %-28s with Pawn Forever: %s%s"):format(ok and "ok  " or "FAIL", c[1], stock[i], got, ok and "" or ("  (want " .. want .. ")")))
end
print(("%d/%d passed"):format(#cases - failed, #cases))
os.exit(failed == 0 and 0 or 1)
