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
local ENGLISH = GetLocale() == "enUS" or GetLocale() == "enGB"

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

local function AddRaw(sample, entry)
  if not PawnUnderstands(sample) then
    tinsert(PawnRegexes, entry)
    tinsert(PF.AddedPatterns, { pattern = entry[1], sample = sample })
  end
end

-- Mana per 5: "Restores +4 mana per 5 sec." (944 Forever items) and zone-bonus versions.
AddBoth(ITEM_MOD_MANA_REGENERATION, { { "Mp5", 1 } })
AddBoth(TOOLTIP_ITEM_STAT_MANA_REGEN_INCREASE, { { "Mp5", 1 } })
AddBoth(ITEM_MOD_HEALTH_REGENERATION, { { "Hp5", 1 } })
AddBoth(TOOLTIP_ITEM_STAT_HEALTH_REGEN_INCREASE, { { "Hp5", 1 } })
-- Healing only: "Increases healing done by magical spells and effects by up to 12."
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
if ENGLISH then
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

-- Plain "+15 Block Value", "+36 Ranged Attack Power", and "+50 Armor Penetration" lines.
-- Pawn only reads the "Equip:" wording for Block Value / Ranged AP.
local function AddShort(name, stat)
  if type(name) ~= "string" or name == "" then return end
  local sample = "+7 " .. name
  if PawnUnderstands(sample) then return end
  local pattern = "^%+?" .. NUMBER .. " " .. Escape(name) .. "$"
  tinsert(PawnRegexes, { pattern, stat })
  tinsert(PF.AddedPatterns, { pattern = pattern, sample = sample })
end
AddShort(ITEM_MOD_BLOCK_VALUE_SHORT, "BlockValue")
AddShort(ITEM_MOD_RANGED_ATTACK_POWER_SHORT, "Rap")
if ENGLISH then
  AddShort("Block Value", "BlockValue")
  AddShort("Ranged Attack Power", "Rap")
  AddShort("Armor Penetration", "ArmorPenetration")
end

-- "Equip: +2 Weapon Damage." on armor (Waywatcher set, Edgemaster's Handguards, ...). Pawn files it under
-- MinDamage/MaxDamage, which scales don't value on a non-weapon. Count it as weapon DPS instead: +1 damage per
-- swing is about a third of a DPS at a typical 3.0 weapon speed. Skipped once Pawn stops reading it as MinDamage.
do
  local pattern = PawnLocal and PawnLocal.TooltipParsing and PawnLocal.TooltipParsing.WeaponDamageEquip
  local current
  for _, entry in ipairs(PawnRegexes) do
    if entry[1] == pattern then current = entry break end
  end
  if type(pattern) == "string" and current and current[2] == "MinDamage" and PawnSingleStatMultiplier then
    -- Inserted first so it wins over Pawn's own entry for the same line.
    tinsert(PawnRegexes, 1, { pattern, "MeleeDps", 0.33, PawnSingleStatMultiplier, "RangedDps", 0.33, PawnSingleStatMultiplier })
    tinsert(PF.AddedPatterns, { pattern = pattern, sample = "Equip: +7 Weapon Damage." })
  end
end

if ENGLISH then
  local class = UnitClass and select(2, UnitClass("player"))
  local PHYSICAL_CRIT = { WARRIOR = true, ROGUE = true, HUNTER = true, PALADIN = true, DRUID = true, SHAMAN = true }
  local SPELL_CRIT = { MAGE = true, PRIEST = true, WARLOCK = true, PALADIN = true, DRUID = true, SHAMAN = true }

  -- All resistances with a zone bonus (base value only), e.g. Volunteer's Lucky Seal:
  -- "Equip: Increases all Resistances by 3. Gain an additional 5 to all Resistances in Forest and Grassland areas."
  local line = "Equip: Increases all Resistances by 7. Gain an additional 7 to all Resistances in Forest and Grassland areas."
  local base = PawnFindStringInRegexTable("+7 to All Resistances", PawnRegexes)
  if base and not PawnUnderstands(line) then
    local entry = { "^Equip: Increases all Resistances by " .. NUMBER .. "%. Gain an additional .+$" }
    for i = 2, #base do entry[i] = base[i] end -- the same stats Pawn gives "+7 to All Resistances"
    tinsert(PawnRegexes, entry)
    tinsert(PF.AddedPatterns, { pattern = entry[1], sample = line })
  end

  -- Spell penetration with plural "Magical Resistances" and/or zone bonus (base value only), e.g. Rune of Perfection:
  -- "Equip: Your spells pierce 3 Magical Resistances. Gain an additional 7 Spell Piercing in Forest and Grassland areas."
  AddRaw("Equip: Your spells pierce 7 Magical Resistances.",
    { "^Equip: Your spells pierce " .. NUMBER .. " Magical Resistances%.$", "SpellPenetration" })
  AddRaw("Equip: Your spells pierce 7 Magical Resistances. Gain an additional 7 Spell Piercing in Forest and Grassland areas.",
    { "^Equip: Your spells pierce " .. NUMBER .. " Magical Resistances?%. Gain an additional .+$", "SpellPenetration" })

  -- Base Attack Power with conditional doubling, e.g. Counterattack Lodestone:
  -- "Equip: +30 Attack Power, doubled against Mechanical units." / "... doubled against Undead targets."
  AddRaw("Equip: +7 Attack Power, doubled against Mechanical units.",
    { "^Equip: %+" .. NUMBER .. " Attack Power, doubled against .+%.$", "Ap" })

  -- Base spell damage & healing with conditional bonus, e.g. Royal Seal of Eldre'Thalas:
  -- "Equip: Increases spell damage and healing by up to 18. Grants an additional 18 spell damage against Demons."
  AddRaw("Equip: Increases spell damage and healing by up to 7. Grants an additional 7 spell damage against Demons.",
    { "^Equip: Increases spell damage and healing by up to " .. NUMBER .. "%. Grants an additional .+$",
      "SpellDamage", 1, PawnMultipleStatsExtract, "Healing", 1, PawnMultipleStatsExtract })

  -- Elemental damage added to melee/weapon attacks (Blazefury Medallion, Storm Gauntlets, Fiery Plate Gauntlets, ...).
  -- Same ~0.33 MeleeDps per point approximation as "Equip: +X Weapon Damage." above.
  if PawnSingleStatMultiplier then
    AddRaw("Equip: Adds 7 fire damage to your melee attacks.",
      { "^Equip: Adds " .. NUMBER .. " %a+ damage to your melee attacks%.$", "MeleeDps", 0.33, PawnSingleStatMultiplier })
    AddRaw("Equip: Adds 7 Fire damage to your weapon attack.",
      { "^Equip: Adds " .. NUMBER .. " %a+ damage to your weapon attack%.$", "MeleeDps", 0.33, PawnSingleStatMultiplier })
  end

  -- Party-wide permanent Equip: auras (always active on the wearer: Medallion of Faith, Atiesh).
  AddRaw("Equip: Cause party members within 30 yds to regenerate 7 health every 5 sec.",
    { "^Equip: Cause party members within %d+ yds? to regenerate " .. NUMBER .. " [hH]ealth every 5 sec%.$", "Hp5" })
  AddRaw("Equip: Restores 7 mana per 5 seconds to all party members within 30 yards.",
    { "^Equip: Restores " .. NUMBER .. " [mM]ana per 5 seconds? to all party members within %d+ yards?%.$", "Mp5" })
  AddRaw("Equip: Increases healing done by magical spells and effects of all party members within 30 yards by up to 7.",
    { "^Equip: Increases healing done by magical spells and effects of all party members within %d+ yards? by up to " .. NUMBER .. "%.$", "Healing" })
  AddRaw("Equip: Increases damage and healing done by magical spells and effects of all party members within 30 yards by up to 7.",
    { "^Equip: Increases damage and healing done by magical spells and effects of all party members within %d+ yards? by up to " .. NUMBER .. "%.$",
      "SpellDamage", 1, PawnMultipleStatsExtract, "Healing", 1, PawnMultipleStatsExtract })

  -- Ranged hit ("Equip: Improves your chance to hit with ranged weapons by 1.0%."). Pawn has no ranged-hit stat,
  -- so it counts as hit for hunters and stays unread for everyone else.
  if class == "HUNTER" then
    AddRaw("Equip: Improves your chance to hit with ranged weapons by 7.0%.",
      { "^Equip: Improves your chance to hit with ranged weapons by " .. NUMBER .. "%%%.$", "HitRating" })
  end

  -- Forever split-crit items (Blackhand's Breadth, Eye of the Beast, Atiesh Mage). Pawn on Forever uses a single
  -- CritRating stat across all scales, so each line is only enabled for classes that benefit from it.
  if PHYSICAL_CRIT[class] then
    AddRaw("Equip: Improves your chance to get a Critical Strike with Melee and Ranged attacks by 7.0%.",
      { "^Equip: Improves your chance to get a [cC]ritical [sS]trike with [mM]elee and [rR]anged attacks by " .. NUMBER .. "%%%.$", "CritRating" })
  end
  if SPELL_CRIT[class] then
    AddRaw("Equip: Improves your chance to get a Critical Strike with Spells by 7.0%.",
      { "^Equip: Improves your chance to get a Critical Strike with Spells by " .. NUMBER .. "%%%.$", "CritRating" })
    AddRaw("Equip: Increases the spell critical chance of all party members within 30 yards by 7%.",
      { "^Equip: Increases the spell critical chance of all party members within %d+ yards? by " .. NUMBER .. "%%%.$", "CritRating" })
  end

  -- Leg-armor style enchant line. There's no game string for it, so English only.
  AddRaw("Stamina +7 and Armor +7",
    { "^Stamina %+" .. NUMBER .. " and Armor %+" .. NUMBER .. "$", "Stamina", 1, PawnMultipleStatsExtract, "Armor", 2, PawnMultipleStatsExtract })
end
