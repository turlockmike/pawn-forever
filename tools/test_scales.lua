-- Offline test for Pawn_Forever/Scales.lua, Weights.lua, and Commands.lua against Pawn's real ScaleTemplates.lua.
--
--   luajit tools/test_scales.lua
-- Set ADDONS to your Interface/AddOns folder if Pawn isn't in the default Forever install.

local P = (os.getenv("ADDONS") or "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns") .. "/"

GetBuildInfo = function() return "1.60.1", "70790", "", 16001 end
WOW_PROJECT_ID = 99; WOW_PROJECT_CLASSIC = 2; WOW_PROJECT_MAINLINE = 1
strlen = string.len; strsub = string.sub; strlower = string.lower; strupper = string.upper; strmatch = string.match
gmatch = string.gmatch; tremove = table.remove; floor = math.floor; gsub = string.gsub; strfind = string.find
tinsert = table.insert; format = string.format; unpack = unpack or table.unpack
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
GetLocale = function() return "enUS" end
PawnIgnoreStatValue = -1000000

dofile(P .. "Pawn/VgerCore/VgerCore.lua")
assert(VgerCore.IsForever, "VgerCore doesn't think this is Forever")
dofile(P .. "Pawn/Core.lua")
dofile(P .. "Pawn/Localization.lua")
dofile(P .. "Pawn/ScaleTemplates.lua")

local CLASS_FILES = {
  [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE",
  [5] = "PRIEST", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID",
}
RAID_CLASS_COLORS = {}
for _, f in pairs(CLASS_FILES) do RAID_CLASS_COLORS[f] = { colorStr = "ffff7c0a" } end

PawnCommon = { Scales = {} }
PawnPlayerFullName = "Testchar-Forever"
local visible = {}
local providers = {}
local levelUpHandler
local clearedCache, resetTooltips = 0, 0
local currentClass, currentLevel = "ROGUE", 40

UnitClass = function() return currentClass, currentClass end
UnitLevel = function() return currentLevel end
UnitName = function() return "Testchar" end
CreateFrame = function()
  return {
    RegisterEvent = function() end,
    SetScript = function(_, ev, fn) if ev == "OnEvent" then levelUpHandler = fn end end,
  }
end
C_Timer = { After = function(_, fn) fn() end }
SlashCmdList = {}

function PawnAddPluginScaleProvider(name, _, fn) providers[name] = fn end
function PawnGetProviderScaleName(provider, internal) return '"' .. provider .. '":' .. internal end
function PawnGetClassInfo(classID) return CLASS_FILES[classID], CLASS_FILES[classID] end
function PawnGetSpecializationInfoForClassID(classID, specID)
  local s = PawnLocal.Specs[classID][specID]
  return specID, s.Name, "", s.Icon, s.Role
end
function PawnAddPluginScale(provider, internal, label, color, values)
  local name = PawnGetProviderScaleName(provider, internal)
  PawnCommon.Scales[name] = { Provider = provider, LocalizedName = label, Color = color, Values = values }
end
function PawnIsScaleVisible(name) return visible[name] == true end
function PawnSetScaleVisible(name, v) visible[name] = v and true or false end
function PawnDeleteScale(name) PawnCommon.Scales[name] = nil; visible[name] = nil end
function PawnRecalculateScaleTotal() end
function PawnClearCache() clearedCache = clearedCache + 1 end
function PawnResetTooltips() resetTooltips = resetTooltips + 1 end

local PF = {}
assert(loadfile("Pawn_Forever/Weights.lua"))("Pawn_Forever", PF)
assert(loadfile("Pawn_Forever/Scales.lua"))("Pawn_Forever", PF)
assert(loadfile("Pawn_Forever/Commands.lua"))("Pawn_Forever", PF)

assert(providers["PawnForever"], "provider PawnForever was not registered")

-- Seed stock Rogue scales as visible before first run.
for i = 1, 3 do
  local stock = PawnGetProviderScaleName("Classic", "ROGUE" .. i)
  PawnCommon.Scales[stock] = { Provider = "Classic", Values = {} }
  visible[stock] = true
end

providers["PawnForever"]()

-- 1. All 33 specs loaded in leveling band.
local count = 0
for _, spec in ipairs(PF.Weights) do
  local scale = PawnCommon.Scales[PF.ScaleName(spec)]
  assert(scale, "missing scale " .. spec.label)
  assert(scale.ClassID == spec.classID, "wrong ClassID on " .. spec.label)
  count = count + 1
end
assert(count == 33, "expected 33 scales, got " .. count)
assert(PF.CurrentBand == "leveling", "expected leveling band at level 40")

-- 2. Pawn 2.14.4+: Rogues can use 1H Axes on Forever, while Shamans still cannot dual-wield off-hands.
local combat = PawnCommon.Scales[PawnGetProviderScaleName("PawnForever", "ROGUE2")]
assert(combat.Values.IsAxe == nil, "Rogue Combat should allow 1H Axes on Pawn 2.14.4+")
assert(combat.Values.Is2HAxe == PawnIgnoreStatValue, "Rogue Combat should still disallow 2H Axes")
local enh = PawnCommon.Scales[PawnGetProviderScaleName("PawnForever", "SHAMAN2")]
assert(enh.Values.IsOffHand == PawnIgnoreStatValue, "Shaman should disallow IsOffHand on Forever")
assert(enh.Values.Agility == 0.6, "Enhancement Agility should be 0.6 (GearQuestForever 1.3.1)")
assert(enh.Values.Intellect == 1.5, "Enhancement leveling Intellect should be 1.5")

-- 3. Bear Druid updated weights (GearQuestForever 1.3.1).
local bear = PawnCommon.Scales[PawnGetProviderScaleName("PawnForever", "DRUID3")]
assert(bear.Values.CritRating == 8.12, "Bear CritRating should be 8.12")
assert(bear.Values.HitRating == 8.8, "Bear HitRating should be 8.8")
assert(bear.Values.ExpertiseRating == 13.2, "Bear ExpertiseRating should be 13.2")
assert(bear.Values.Stamina == 2.16, "Bear leveling Stamina should be 2.16")

-- 4. FirstRunVisibility swapped stock Rogue scales to Pawn Forever scales.
for i = 1, 3 do
  assert(visible[PawnGetProviderScaleName("PawnForever", "ROGUE" .. i)], "Rogue PF scale " .. i .. " should be visible")
  assert(not visible[PawnGetProviderScaleName("Classic", "ROGUE" .. i)], "Rogue stock scale " .. i .. " should be hidden")
end
assert(Pawn_ForeverDB and Pawn_ForeverDB.setupDone[PawnPlayerFullName], "Pawn_ForeverDB.setupDone should be set")

-- 5. Seamless migration from PawnForever -> Pawn_Forever: fresh Pawn_ForeverDB with existing visible PF scales
-- must NOT re-swap a user's customized visibility (e.g., if they turned stock back on alongside one PF scale).
Pawn_ForeverDB = nil
visible[PawnGetProviderScaleName("Classic", "ROGUE1")] = true
visible[PawnGetProviderScaleName("PawnForever", "ROGUE2")] = false
providers["PawnForever"]()
assert(visible[PawnGetProviderScaleName("Classic", "ROGUE1")], "upgrade migration must not hide user-enabled stock scale")
assert(not visible[PawnGetProviderScaleName("PawnForever", "ROGUE2")], "upgrade migration must not re-enable user-hidden PF scale")

-- 6. Leveling -> level 60 transition refreshes scales and clears Pawn cache.
currentLevel = 60
levelUpHandler(nil, "PLAYER_LEVEL_UP", 60)
assert(PF.CurrentBand == "max", "expected max band at level 60")
assert(PawnCommon.Scales[PawnGetProviderScaleName("PawnForever", "SHAMAN2")].Values.Intellect == 0.75, "Enhancement max Intellect should be 0.75")
assert(PawnCommon.Scales[PawnGetProviderScaleName("PawnForever", "DRUID3")].Values.Stamina == 0.72, "Bear max Stamina should be 0.72")
assert(clearedCache == 1 and resetTooltips == 1, "level 60 transition should clear cache and reset tooltips")

-- 7. Slash commands: /pff stock & /pff forever.
assert(SLASH_PAWN_FOREVER1 == "/pff" and SLASH_PAWN_FOREVER2 == "/pawn_forever", "slash commands should be /pff and /pawn_forever")
SlashCmdList.PAWN_FOREVER("stock")
assert(visible[PawnGetProviderScaleName("Classic", "ROGUE1")], "/pff stock should show stock scale")
assert(not visible[PawnGetProviderScaleName("PawnForever", "ROGUE1")], "/pff stock should hide PF scale")
SlashCmdList.PAWN_FOREVER("forever")
assert(visible[PawnGetProviderScaleName("PawnForever", "ROGUE1")], "/pff forever should show PF scale")
assert(not visible[PawnGetProviderScaleName("Classic", "ROGUE1")], "/pff forever should hide stock scale")

print("all scale & command checks passed (" .. count .. " specs)")
