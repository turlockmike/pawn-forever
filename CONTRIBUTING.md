# Contributing to Pawn Forever

## Local Testing in WoW Forever
- Copy `Pawn_Forever/` into `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\Pawn_Forever\`.
- **`/reload` reloads everything** (Lua files, `.toc` metadata, and textures/icons like `Icon.tga`) — no need to restart the WoW client after copying updated files.
- To run Lua snippets inside the running client without typing in chat, install `tools/WowBridge` into `Interface\AddOns\WowBridge` and use `tools/wowrun.ps1`.
- Check BugSack after `/reload` and verify `/pff patterns` and `/pff diag`.

## Automated Checks & Offline Tests
Run from the repo root:
- `luajit tools/check_packaging.lua` — standalone check (also run automatically in CI before releasing). Validates `.toc` folder/version/SavedVariables invariants, compiles every Lua file, verifies `Icon.tga` is a valid power-of-two 24/32-bit TGA, checks `CHANGELOG.md` matches the `.toc` version, and ensures `.github/workflows/release.yml` uses `--form-string` (not `-F`) for CurseForge JSON metadata.
- `luajit tools/test_parsing.lua` — verifies tooltip parsing against Pawn alone vs. Pawn + Pawn Forever, including class-gated patterns (needs Pawn installed or `ADDONS` set).
- `luajit tools/test_scales.lua` — verifies scale registration, class templates (Rogue 1H axes, Shaman off-hands), level-60 switching, upgrade migration, and `/pff` commands.
- `luajit tools/check_regexes.lua` (add `--stock` for Pawn alone) — audits patterns across GearQuest Forever's full tooltip dataset.

## Key Invariants
- **Folder vs. Pawn provider name:** The addon folder and saved variables are `Pawn_Forever` / `Pawn_ForeverDB` (distinct from Direcktive's unrelated `PawnForever` addon), while `PROVIDER = "PawnForever"` in `Pawn_Forever/Scales.lua` stays unchanged so existing users keep their Pawn scale visibility inside `PawnCommon.Scales`.
- **Self-disabling patterns:** Every pattern added in `Pawn_Forever/Parsing.lua` must check `not PawnUnderstands(sample)` so it turns off automatically when Pawn adds support upstream.
- **Icon format:** `Pawn_Forever/Icon.tga` must be a power-of-two (`64x64`) 24/32-bit TGA referenced by `## IconTexture:` in `Pawn_Forever/Pawn_Forever.toc` so WoW doesn't display the default red `?`.
- **Changelog format:** Keep `CHANGELOG.md` in reverse-chronological order (newest `## x.y.z (YYYY-MM-DD)` section at the top). CurseForge's Changelog tab only displays the latest file's changelog, so `release.yml` sends the entire versioned `CHANGELOG.md` to CurseForge (stripping `# Changelog`) and only the latest section to GitHub Releases.

## Updating Weights
Weights are generated from GearQuest Forever's `ScoringWeights.generated.lua`:

    luajit tools/generate_weights.lua "<AddOns>/GearQuestForever/_generated/ScoringWeights.generated.lua"

Edit `tools/generate_weights.lua` (not `Pawn_Forever/Weights.lua` directly) if changing stat mappings or expertise multipliers.

## Reconciling Upstream Pawn Updates
1. Review Pawn's `Readme.md` changelog and inspect `TooltipParsing.lua`, `Localization*.lua`, `ScaleTemplates.lua`, and `Pawn.lua` (especially incompatibility checks and public APIs).
2. Run `test_parsing.lua`, `test_scales.lua`, and `check_regexes.lua` (`--stock` and with Pawn Forever) to see which gaps Pawn closed and whether new Forever tooltip lines appeared.
3. Update `Pawn_Forever/Parsing.lua` and add regression cases to `tools/test_parsing.lua`.

## Releasing
1. Bump `## Version:` in `Pawn_Forever/Pawn_Forever.toc` and add a matching `## x.y.z (YYYY-MM-DD)` section at the top of `CHANGELOG.md`.
2. Run `luajit tools/check_packaging.lua`, `luajit tools/test_parsing.lua`, and `luajit tools/test_scales.lua`.
3. Commit, then tag and push: `git tag vx.y.z && git push origin main vx.y.z`.
4. `.github/workflows/release.yml` runs `check_packaging.lua`, pre-validates the CurseForge JSON metadata with `jq` before publishing, packages `Pawn_Forever-vx.y.z.zip`, creates the GitHub release (with this version's notes), and uploads to CurseForge with the full versioned `CHANGELOG.md` (newest on top) using `curl --form-string` (never `-F`, which truncates JSON at semicolons).
5. Never delete or rewrite a pushed release tag if a workflow step fails — fix the workflow and bump a patch version instead.
6. CurseForge's upload API does not update the project avatar — if `media/logo.png` changed, upload it manually under CurseForge project settings.
