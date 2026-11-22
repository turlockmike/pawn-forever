-- Offline test: runs Pawn's real tooltip reader (PawnLookForSingleStat) on real WoW Forever tooltip lines,
-- first with Pawn alone, then with Pawn_Forever/Parsing.lua loaded, and checks the stats each line gives.
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

local function LoadStockPawn()
  PawnRegexes = nil
  PawnNormalizationRegexes = nil
  dofile(P .. "Pawn/VgerCore/VgerCore.lua")
  dofile(P .. "Pawn/Core.lua")
  dofile(P .. "Pawn/Localization.lua")
  dofile(P .. "Pawn/TooltipParsing.lua")
end

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
    local number, source = entry[i + 1] or 1, entry[i + 2]
    local idx = source == PawnMultipleStatsExtract and number or 1
    local value = tonumber((m[idx] or ""):gsub("[^%d%.%-]", ""), 10)
    if source == PawnSingleStatMultiplier then value = value * number end
    stats[entry[i]] = (stats[entry[i]] or 0) + value
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

LoadStockPawn()

local cases = {
  -- Live Forever tooltips (item IDs noted). Expected = what Pawn + Pawn Forever should read (for a hybrid/Druid class).
  { "270275 Cleansed Vilebranch Medallion", "Equip: +14 Attack Power. This effect is tripled in Forest and Grassland areas.", { Ap = 14 } },
  { "270225 Jewel of the Guard Captain", "Equip: Increases damage and healing done by magical spells and effects by up to 8. This effect is tripled in Forest and Grassland areas.", { SpellDamage = 8, Healing = 8 } },
  { "zone Mp5", "Equip: Restores 3 Mana per 5 sec. This effect is tripled in Forest and Grassland areas.", { Mp5 = 3 } },
  { "zone fire", "Equip: Increases damage done by Fire spells and effects by up to 7. This effect is doubled in Volcanic areas.", { FireSpellDamage = 7 } },
  { "zone healing", "Equip: Increases healing done by magical spells and effects by up to 12. This effect is doubled in Swamp areas.", { Healing = 12 } },
  { "284268 Furbolg Shaman's Girdle (Wowhead text)", "Restores +5 mana per 5 sec.", { Mp5 = 5 } },
  { "Equip: mana per 5", "Equip: Restores 5 mana per 5 sec.", { Mp5 = 5 } },
  { "280059 Tuskblade Halberd (expertise)", "Equip: Reduces chance to be Dodged or Parried by 2.0%.", { ExpertiseRating = 2 } },
  { "240128 Forever Haste (Pawn 2.14.3+)", "Equip: Increases your attack speed and casting speed by 1.0%.", { HasteRating = 1 } },
  { "19431 Styleen's Impeding Scarab", "+24 Block Value", { BlockValue = 24 } },
  { "18833 Grand Marshal's Bullseye", "+36 Ranged Attack Power", { Rap = 36 } },
  { "285326 Leafre's Ring of Armor Piercing", "+50 Armor Penetration", { ArmorPenetration = 50 } },
  { "240063 Waywatcher Trousers", "Equip: +4 Weapon Damage.", { MeleeDps = 1.32, RangedDps = 1.32 } },
  { "271904 Volunteer's Lucky Seal", "Equip: Increases all Resistances by 3. Gain an additional 5 to all Resistances in Forest and Grassland areas.",
    { ArcaneResist = 3, FireResist = 3, FrostResist = 3, NatureResist = 3, ShadowResist = 3 } },
  { "21565 Rune of Perfection (zone spell pen)", "Equip: Your spells pierce 3 Magical Resistances. Gain an additional 7 Spell Piercing in Forest and Grassland areas.", { SpellPenetration = 3 } },
  { "18537 Counterattack Lodestone (doubled AP)", "Equip: +30 Attack Power, doubled against Mechanical units.", { Ap = 30 } },
  { "273817 doubled AP vs Undead", "Equip: +12 Attack Power, doubled against Undead targets.", { Ap = 12 } },
  { "18467 Royal Seal of Eldre'Thalas", "Equip: Increases spell damage and healing by up to 18. Grants an additional 18 spell damage against Demons.", { SpellDamage = 18, Healing = 18 } },
  { "17111 Blazefury Medallion", "Equip: Adds 2 fire damage to your melee attacks.", { MeleeDps = 0.66 } },
  { "12632 Storm Gauntlets", "Equip: Adds 3 Lightning damage to your melee attacks.", { MeleeDps = 0.99 } },
  { "12631 Fiery Plate Gauntlets", "Equip: Adds 4 Fire damage to your weapon attack.", { MeleeDps = 1.32 } },
  { "6323 Medallion of Faith (party Hp5)", "Equip: Cause party members within 30 yds to regenerate 4 health every 5 sec.", { Hp5 = 4 } },
  { "22632 Atiesh Druid (party Mp5)", "Equip: Restores 11 mana per 5 seconds to all party members within 30 yards.", { Mp5 = 11 } },
  { "22631 Atiesh Priest (party Healing)", "Equip: Increases healing done by magical spells and effects of all party members within 30 yards by up to 62.", { Healing = 62 } },
  { "22630 Atiesh Warlock (party SP)", "Equip: Increases damage and healing done by magical spells and effects of all party members within 30 yards by up to 33.", { SpellDamage = 33, Healing = 33 } },
  { "22589 Atiesh Mage (party Spell Crit)", "Equip: Increases the spell critical chance of all party members within 30 yards by 2%.", { CritRating = 2 } },
  { "13965 Blackhand's Breadth (as Druid)", "Equip: Improves your chance to get a Critical Strike with Melee and Ranged attacks by 1.0%.", { CritRating = 1 } },
  { "13968 Eye of the Beast (as Druid)", "Equip: Improves your chance to get a Critical Strike with Spells by 1.0%.", { CritRating = 1 } },
  { "leg armor enchant", "Stamina +16 and Armor +100", { Stamina = 16, Armor = 100 } },
  -- Must stay as Pawn reads them.
  { "weapon damage line", "148 - 222 Damage", { MinDamage = 148, MaxDamage = 222 } },
  { "Equip: block value", "Equip: Increases the Block Value of your shield by 15.", { BlockValue = 15 } },
  -- Must stay unread: Pawn doesn't score Use: effects or pure monster-only bonuses.
  { "249470 Molten Heart of the Mountain (Use:)", "Use: Increase Attack Power by 55 for 15 sec. This effect is doubled in Volcanic areas. (5 Min Cooldown)", nil },
  { "23206 Mark of the Champion (Demons only)", "Equip: +150 Attack Power against Demons.", nil },
}

local stock = {}
for i, c in ipairs(cases) do stock[i] = Show(Read(c[2])) end

dofile("tools/fixtures/globals_enUS.lua")
UnitClass = function() return "Druid", "DRUID" end
local PF = {}
assert(loadfile("Pawn_Forever/Parsing.lua"))("Pawn_Forever", PF)

local failed = 0
local function Check(label, line, want, stockStr)
  local got, wantStr = Show(Read(line)), Show(want)
  local ok = got == wantStr
  if not ok then failed = failed + 1 end
  print(("%s  %-46s Pawn alone: %-28s with Pawn Forever: %s%s"):format(
    ok and "ok  " or "FAIL", label, stockStr or "-", got, ok and "" or ("  (want " .. wantStr .. ")")))
end

for i, c in ipairs(cases) do
  Check(c[1], c[2], c[3], stock[i])
end

-- Class-gated checks: verify pure classes only read stats that apply to them.
local classCases = {
  { "HUNTER",  "13255 Trueaim Gauntlets (Hunter)",      "Equip: Improves your chance to hit with ranged weapons by 3.0%.", { HitRating = 3 } },
  { "HUNTER",  "13965 Blackhand's Breadth (Hunter)",    "Equip: Improves your chance to get a Critical Strike with Melee and Ranged attacks by 1.0%.", { CritRating = 1 } },
  { "HUNTER",  "13968 Eye of the Beast (Hunter)",       "Equip: Improves your chance to get a Critical Strike with Spells by 1.0%.", nil },
  { "WARRIOR", "13255 Trueaim Gauntlets (Warrior)",     "Equip: Improves your chance to hit with ranged weapons by 3.0%.", nil },
  { "WARRIOR", "13965 Blackhand's Breadth (Warrior)",   "Equip: Improves your chance to get a Critical Strike with Melee and Ranged attacks by 1.0%.", { CritRating = 1 } },
  { "WARRIOR", "13968 Eye of the Beast (Warrior)",      "Equip: Improves your chance to get a Critical Strike with Spells by 1.0%.", nil },
  { "WARRIOR", "22589 Atiesh Mage (Warrior)",           "Equip: Increases the spell critical chance of all party members within 30 yards by 2%.", nil },
  { "MAGE",    "13965 Blackhand's Breadth (Mage)",      "Equip: Improves your chance to get a Critical Strike with Melee and Ranged attacks by 1.0%.", nil },
  { "MAGE",    "13968 Eye of the Beast (Mage)",         "Equip: Improves your chance to get a Critical Strike with Spells by 1.0%.", { CritRating = 1 } },
  { "MAGE",    "22589 Atiesh Mage (Mage)",              "Equip: Increases the spell critical chance of all party members within 30 yards by 2%.", { CritRating = 2 } },
}
local lastClass
for _, cc in ipairs(classCases) do
  if cc[1] ~= lastClass then
    lastClass = cc[1]
    LoadStockPawn()
    UnitClass = function() return cc[1], cc[1] end
    assert(loadfile("Pawn_Forever/Parsing.lua"))("Pawn_Forever", {})
  end
  Check(cc[2], cc[3], cc[4], "class:" .. cc[1])
end

local total = #cases + #classCases
print(("%d/%d passed"):format(total - failed, total))
os.exit(failed == 0 and 0 or 1)
