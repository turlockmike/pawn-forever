# Changelog

## 1.3.0 (2026-11-21)
- **Renamed installation folder to `Pawn_Forever`** (and saved variables to `Pawn_ForeverDB`) to eliminate the CurseForge folder collision with Direcktive's unrelated standalone addon ("PawnForever - Alternative to Pawn"). Existing Pawn users keep their scale visibility settings automatically; if installing manually, delete the old `PawnForever` folder.
- Updated the project logo and added an AddOn list icon (`Icon.tga`) with `Equipment` category metadata so Pawn Forever nests cleanly under Pawn without the default `?` icon.
- Reconciled with **Pawn 2.14.8** (Pawn 2.14.3+ natively reads Forever's combined Haste and non-English bonus armor, and Pawn 2.14.4+ allows 1H Axes for Rogues on Forever, which Pawn Forever inherits automatically).
- Now read (English clients):
  - Forever split-crit items (`Equip: Improves your chance to get a Critical Strike with Melee and Ranged attacks by #%.` such as Blackhand's Breadth, and `... with Spells by #%.` such as Eye of the Beast), enabled only for classes that use that crit type.
  - Zone-bonus Spell Penetration (`Equip: Your spells pierce # Magical Resistances. Gain an additional ...`, e.g. Rune of Perfection) — base value counts.
  - Base Attack Power on doubled-vs-type items (`Equip: +# Attack Power, doubled against Mechanical units.` / `Undead targets.`, e.g. Counterattack Lodestone).
  - Base Spell Damage & Healing on conditional-bonus items (`Equip: Increases spell damage and healing by up to #. Grants an additional ...`, e.g. Royal Seal of Eldre'Thalas).
  - Elemental damage added to melee/weapon attacks (`Equip: Adds # Fire/Frost/Arcane/Lightning damage to your melee attacks.` / `weapon attack.`, e.g. Blazefury Medallion, Storm Gauntlets, Fiery Plate Gauntlets), valued at 0.33 Melee DPS per point.
  - Permanent party-aura `Equip:` stats (Medallion of Faith Hp5 and all four Atiesh party auras).
  - Plain `+# Armor Penetration`.
- Weights regenerated from GearQuest Forever 1.3.1 (Enhancement Shaman Agility 1 → 0.6, Intellect 0.7 → 0.75; Bear Druid Crit 3.5 → 8.12, Hit 4 → 8.8, Expertise 6 → 13.2, Stamina 1 → 0.72).

## 1.2.0 (2026-11-15)
- Expertise (`Equip: Reduces chance to be Dodged or Parried by 1.0%.`) now has a value: the spec's hit value for melee damage specs, 1.5x hit for tanks, 5% of hit for hunters, none for casters and healers. GearQuest has no expertise weight, so this one is set by Pawn Forever.
- Now read: `+24 Block Value` and `+36 Ranged Attack Power` (the plain wording without "Equip:"), and all-resistance lines with a zone bonus (base value, English clients).
- `Equip: +2 Weapon Damage.` on armor now counts as weapon DPS (a third of a DPS per point) instead of nothing.
- Hunters: `Equip: Improves your chance to hit with ranged weapons by 1.0%.` counts as hit (English clients).
- Weights regenerated from the current GearQuest Forever data (Bear weapon DPS 2.52 -> 4.9).

## 1.1.0 (2026-11-12)
- Updated for Pawn 2.14.2, which is now the minimum version.
- Removed the hover-lag workaround: Pawn 2.14.2 fixes the lag itself.
- Zone-bonus lines on any Equip: stat now count their base value, e.g. `Equip: +14 Attack Power. This effect is tripled in Forest and Grassland areas.` counts 14 Attack Power (English clients).
- Every spec now uses GearQuest Forever's weights (1.1.5). Balance and Resto druid were hand-tuned before and now follow GearQuest too. Enhancement shaman changed, and Feral Cat and Bear now value weapon DPS.
- Pawn is now marked as a required dependency on CurseForge, so the CurseForge app installs it automatically.

## 1.0.2 (2026-11-08)
- Scales are named "<spec> Forever" (Balance Forever, Resto Forever, Combat Forever, ...) so they're easy to tell apart from Pawn's stock scales on tooltips.

## 1.0.1 (2026-11-08)
- First CurseForge release (project 1792442). Releases now upload to CurseForge automatically.

## 1.0.0 (2026-11-08)
- Reads Forever's mana per 5, healing-only and zone-bonus tooltip lines, built from the game's localized strings.
- Bundles the hover-lag cache fix (formerly the separate PawnCacheFix add-on).
- "Pawn Forever" scales for every spec, with leveling and level 60 values.
- Replaces the two custom druid scales from the first local version.
