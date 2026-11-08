-- "Pawn Forever" scale provider: one scale per spec for every class (weights in Weights.lua).
-- Below level 60 the leveling values are used; at 60 the scales switch to the endgame values.

local _, PF = ...
if not PawnAddPluginScaleProvider then return end

local PROVIDER = "PawnForever"
local MAX_LEVEL = 60
PF.Provider = PROVIDER

local function InternalName(spec)
  return spec.specID and (spec.class .. spec.specID) or (spec.class .. "_" .. spec.key)
end
function PF.ScaleName(spec) return PawnGetProviderScaleName(PROVIDER, InternalName(spec)) end
function PF.StockScaleName(spec) return spec.specID and PawnGetProviderScaleName("Classic", spec.class .. spec.specID) end

local function Band()
  local level = UnitLevel("player") or 0
  return (level >= MAX_LEVEL) and "max" or "leveling"
end
PF.CurrentBand = nil

local function AddScales()
  local band = Band()
  PF.CurrentBand = band
  for _, spec in ipairs(PF.Weights) do
    local values = {}
    -- Item types this class can never use (from Pawn's own class templates).
    local template = PawnFindScaleTemplate(spec.classID)
    if template then
      for stat, v in pairs(PawnGetStatValuesForTemplate(template, true)) do values[stat] = v end
    end
    for stat, v in pairs(spec[band]) do values[stat] = v end

    local className, classFile = PawnGetClassInfo(spec.classID)
    local specName, role, _ = spec.label, nil
    if spec.specID then
      local _, localized, _, _, r = PawnGetSpecializationInfoForClassID(spec.classID, spec.specID)
      specName, role = specName or localized, r
    end
    local color = RAID_CLASS_COLORS[classFile] and RAID_CLASS_COLORS[classFile].colorStr
    color = color and strsub(color, 3) or "ffffff"

    PawnAddPluginScale(PROVIDER, InternalName(spec), (className or spec.class) .. ": " .. (specName or spec.key), color, values)
    local scale = PawnCommon.Scales[PF.ScaleName(spec)]
    if scale then
      scale.ClassID, scale.SpecID, scale.Role = spec.classID, spec.specID, role
    end
  end
end

-- Show this character's Pawn Forever scales in place of the stock ones it was using.
-- Runs once per character; afterwards the player's own choices in Pawn are left alone.
local function FirstRunVisibility()
  PawnForeverDB.setupDone = PawnForeverDB.setupDone or {}
  local who = PawnPlayerFullName or UnitName("player")
  if PawnForeverDB.setupDone[who] then return end
  PawnForeverDB.setupDone[who] = true

  local _, myClass = UnitClass("player")
  local shown = 0

  -- Version 1 of this addon imported two custom druid scales; replace them.
  local legacy = { ["Forever Balance"] = "DRUID1", ["Forever Resto"] = "DRUID4" }
  for oldName, newInternal in pairs(legacy) do
    local old = PawnCommon.Scales[oldName]
    if old and not old.Provider and old.Color == "ff7c0a" then
      local wasVisible = PawnIsScaleVisible(oldName)
      PawnDeleteScale(oldName)
      if wasVisible and myClass == "DRUID" then
        PawnSetScaleVisible(PawnGetProviderScaleName(PROVIDER, newInternal), true)
        shown = shown + 1
      end
    end
  end

  for _, spec in ipairs(PF.Weights) do
    local stock = PF.StockScaleName(spec)
    if spec.class == myClass and stock and PawnCommon.Scales[stock] and PawnIsScaleVisible(stock) then
      PawnSetScaleVisible(PF.ScaleName(spec), true)
      PawnSetScaleVisible(stock, false)
      shown = shown + 1
    end
  end
  if shown > 0 then
    print("|cffff7c0aPawn Forever:|r now showing " .. shown .. " Pawn Forever scale(s) instead of Pawn's stock ones. /pff stock switches back.")
  end
end

-- Swap every scale of the player's class between Pawn Forever and Pawn's stock set.
function PF.UseScales(ours)
  local _, myClass = UnitClass("player")
  for _, spec in ipairs(PF.Weights) do
    if spec.class == myClass then
      local stock = PF.StockScaleName(spec)
      local stockVisible = stock and PawnCommon.Scales[stock] and PawnIsScaleVisible(stock)
      local mineVisible = PawnIsScaleVisible(PF.ScaleName(spec))
      if ours and stockVisible then
        PawnSetScaleVisible(PF.ScaleName(spec), true); PawnSetScaleVisible(stock, false)
      elseif not ours and mineVisible and stock and PawnCommon.Scales[stock] then
        PawnSetScaleVisible(stock, true); PawnSetScaleVisible(PF.ScaleName(spec), false)
      end
    end
  end
end

local function Refresh()
  AddScales()
  for _, spec in ipairs(PF.Weights) do PawnRecalculateScaleTotal(PF.ScaleName(spec)) end
  if PawnClearCache then PawnClearCache() end
  if PawnResetTooltips then PawnResetTooltips() end
end

PawnAddPluginScaleProvider(PROVIDER, "Pawn Forever", function()
  PawnForeverDB = PawnForeverDB or {} -- providers run at PLAYER_LOGIN, after saved variables load
  AddScales()
  FirstRunVisibility()
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(_, _, newLevel)
  if PF.CurrentBand and ((newLevel or 0) >= MAX_LEVEL and "max" or "leveling") ~= PF.CurrentBand then
    C_Timer.After(1, Refresh)
  end
end)
