# Changelog

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
