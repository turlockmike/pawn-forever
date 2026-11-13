-- Teaches Pawn the WoW Forever tooltip lines it scores as 0.
--
-- The patterns are built from the game's own localized tooltip templates (TOOLTIP_ITEM_STAT_*, ITEM_MOD_*),
-- so they work in every client language. Each pattern is only added when Pawn doesn't already understand
-- a sample line built from the same template: once Pawn handles a line itself, that fix switches off.

local _, PF = ...
if type(PawnRegexes) ~= "table" then return end

PF.AddedPatterns = {}

local NUMBER = "(-?[%d%., ]+)"
local EQUIP = ITEM_SPELL_TRIGGER_ONEQUIP -- "Equip:"

local function Normalize(s)
  s = strtrim(s or "")
  for _, entry in pairs(PawnNormalizationRegexes or {}) do
    s = gsub(s, entry[1], entry[2], 1)
  end
  return s
end
PF.Normalize = Normalize

local function PawnUnderstands(line)
  return PawnFindStringInRegexTable(Normalize(line), PawnRegexes) ~= nil
end

-- Escapes a literal piece of a template. ASCII letters match either case ("Mana" / "mana" both appear on Forever).
local function Escape(text)
  text = gsub(text, "[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")
  return (gsub(text, "%a", function(c) return "[" .. strlower(c) .. strupper(c) .. "]" end))
end

-- Template -> pattern, plus a sample line using the number 7.
-- "Equip: Restores %1$d Mana per 5 sec." -> "^[eE]quip: [rR]estores %+?(-?[%d%., ]+) [mM]ana per 5 sec%.$"
local function Build(template, trailingText)
  local pattern, sample, i = "^", "", 1
  while true do
    local s, e = strfind(template, "%%%d?%$?[ds]", i)
    if not s then break end
    local literal = strsub(template, i, s - 1)
    pattern = pattern .. Escape(literal) .. "%+?" .. NUMBER
    sample = sample .. literal .. "7"
    i = e + 1
  end
  local tail = strsub(template, i)
  if trailingText then
    -- Same line followed by more text, e.g. "... by up to 8. This effect is tripled in Forest and Grassland areas."
    -- The extra text must follow the full original sentence, so "...by up to 8 and healing..." never matches.
    pattern = pattern .. Escape(tail) .. " ?.+$"
    sample = sample .. tail .. " Lorem ipsum."
  else
    pattern = pattern .. Escape(tail) .. "$"
    sample = sample .. tail
  end
  return pattern, sample
end

-- stats: list of { stat name, capture index }
local function Add(template, stats, trailingText)
  if type(template) ~= "string" or template == "" then return end
  local variants = { template }
  -- Forever prints some of these as plain green stat lines without "Equip:".
  if EQUIP and strsub(template, 1, strlen(EQUIP) + 1) == EQUIP .. " " then
    tinsert(variants, strsub(template, strlen(EQUIP) + 2))
  end
  for _, t in ipairs(variants) do
    local pattern, sample = Build(t, trailingText)
    if not PawnUnderstands(sample) and strfind(Normalize(sample), pattern) then
      local entry = { pattern }
      if #stats == 1 then
        entry[2] = stats[1][1]
      else
        for _, s in ipairs(stats) do
          tinsert(entry, s[1]); tinsert(entry, s[2]); tinsert(entry, PawnMultipleStatsExtract)
        end
      end
      tinsert(PawnRegexes, entry)
      tinsert(PF.AddedPatterns, { pattern = pattern, sample = sample })
    end
  end
end

local function AddBoth(template, stats)
  Add(template, stats, false)
  Add(template, stats, true)
end

-- Mana per 5: "Restores +4 mana per 5 sec." (914 Forever items) and zone-bonus versions.
AddBoth(ITEM_MOD_MANA_REGENERATION, { { "Mp5", 1 } })
AddBoth(TOOLTIP_ITEM_STAT_MANA_REGEN_INCREASE, { { "Mp5", 1 } })
AddBoth(ITEM_MOD_HEALTH_REGENERATION, { { "Hp5", 1 } })
AddBoth(TOOLTIP_ITEM_STAT_HEALTH_REGEN_INCREASE, { { "Hp5", 1 } })
-- Healing only: "Increases healing done by magical spells and effects by up to 12." (235 items)
AddBoth(TOOLTIP_ITEM_STAT_SPELL_HEALING_INCREASE, { { "Healing", 1 } })
AddBoth(ITEM_MOD_SPELL_HEALING_DONE, { { "Healing", 1 } })
-- Damage and healing / damage only, including "This effect is tripled in ..." zone bonuses (base value only).
AddBoth(TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE, { { "SpellDamage", 1 }, { "Healing", 1 } })
AddBoth(TOOLTIP_ITEM_STAT_SPELL_DAMAGE_INCREASE, { { "SpellDamage", 1 } })
AddBoth(ITEM_MOD_SPELL_DAMAGE_DONE, { { "SpellDamage", 1 } })
AddBoth(TOOLTIP_ITEM_STAT_SPELL_HEALING_INCREASE_DAMAGE_INCREASE, { { "Healing", 1 }, { "SpellDamage", 2 } })
for _, school in ipairs({ "FIRE", "FROST", "ARCANE", "SHADOW", "NATURE", "HOLY" }) do
  local stat = school:sub(1, 1) .. school:sub(2):lower() .. "SpellDamage"
  AddBoth(_G["TOOLTIP_ITEM_STAT_" .. school .. "_DAMAGE_INCREASE"], { { stat, 1 } })
end

-- Zone bonus on any other Equip: stat, e.g. "Equip: +14 Attack Power. This effect is tripled in Forest and Grassland areas."
-- Drops the zone sentence so Pawn's own pattern reads the base value. English only (no game string for it);
-- "Use:" effects are left alone because Pawn doesn't score them.
if GetLocale() == "enUS" or GetLocale() == "enGB" then
  local line = "Equip: +7 Attack Power. This effect is tripled in Forest and Grassland areas."
  if not PawnUnderstands(line) and type(PawnNormalizationRegexes) == "table" then
    local rule = { "^(" .. EQUIP .. " .-%.) This effect is %a+ in [^%.]- areas%.$", "%1" }
    tinsert(PawnNormalizationRegexes, rule)
    if PawnUnderstands(line) then
      tinsert(PF.AddedPatterns, { pattern = rule[1], sample = line })
    else
      tremove(PawnNormalizationRegexes) -- Pawn can't read the base line either, so the rule doesn't help.
    end
  end
end

-- Leg-armor style enchant line. There's no game string for it, so English only.
if GetLocale() == "enUS" or GetLocale() == "enGB" then
  local line = "Stamina +7 and Armor +7"
  if not PawnUnderstands(line) then
    local pattern = "^Stamina %+" .. NUMBER .. " and Armor %+" .. NUMBER .. "$"
    tinsert(PawnRegexes, { pattern, "Stamina", 1, PawnMultipleStatsExtract, "Armor", 2, PawnMultipleStatsExtract })
    tinsert(PF.AddedPatterns, { pattern = pattern, sample = line })
  end
end
