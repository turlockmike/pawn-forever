# Changelog

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
