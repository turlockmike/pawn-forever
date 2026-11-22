# Contributing to Pawn Forever

## Local Testing in WoW Forever
- Copy `Pawn_Forever/` into `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\Pawn_Forever\`.
- **`/reload` reloads everything** (Lua files, `.toc` metadata, and textures/icons like `Icon.tga`) — no need to restart the WoW client after copying updated files.
- To run Lua snippets inside the running client without typing in chat, install `tools/WowBridge` into `Interface\AddOns\WowBridge` and use `tools/wowrun.ps1`.
- Check BugSack after `/reload` and verify `/pff patterns` and `/pff diag`.

## Offline Tests & Audits
Run from the repo root (requires LuaJIT and Pawn / GearQuestForever installed, or `ADDONS` pointing at your `Interface/AddOns` folder):
- `luajit tools/test_parsing.lua` — verifies tooltip parsing against Pawn alone vs. Pawn + Pawn Forever, including class-gated patterns.
- `luajit tools/test_scales.lua` — verifies scale registration, class templates (e.g. Rogue 1H axes, Shaman off-hands), level-60 switching, upgrade migration, and `/pff` commands.
- `luajit tools/check_regexes.lua` (add `--stock` for Pawn alone) — audits patterns across GearQuest Forever's full tooltip dataset.

## Updating Weights
Weights are generated from GearQuest Forever's `ScoringWeights.generated.lua`:

    luajit tools/generate_weights.lua "<AddOns>/GearQuestForever/_generated/ScoringWeights.generated.lua"

Edit `tools/generate_weights.lua` (not `Pawn_Forever/Weights.lua` directly) if changing stat mappings or expertise multipliers.

## Reconciling Upstream Pawn Updates
1. Review Pawn's `Readme.md` changelog and diff `TooltipParsing.lua`, `Localization*.lua`, `ScaleTemplates.lua`, and `Pawn.lua` (especially incompatibility checks and public APIs).
2. Run `test_parsing.lua`, `test_scales.lua`, and `check_regexes.lua` (`--stock` and with Pawn Forever) to see which gaps Pawn closed and whether new Forever tooltip lines appeared.
3. Update `Pawn_Forever/Parsing.lua` (every pattern must guard with `not PawnUnderstands(sample)` so it auto-disables once Pawn handles it) and add regression cases to `tools/test_parsing.lua`.

## Releasing
1. Bump `## Version:` in `Pawn_Forever/Pawn_Forever.toc` and add a matching `## x.y.z (YYYY-MM-DD)` section at the top of `CHANGELOG.md`.
2. Commit, then tag and push: `git tag vx.y.z && git push origin main --tags`.
3. `.github/workflows/release.yml` packages `Pawn_Forever-vx.y.z.zip`, creates the GitHub release, and uploads to CurseForge.
4. Note: CurseForge's upload API does not update the project avatar — if `media/logo.png` changed, upload it manually under CurseForge project settings.
