-- On classic-era clients Pawn sets PawnItemCacheCanAssumeComplete = false, so every PawnGetItemData call
-- (even a cache hit) re-renders the item in a hidden tooltip to compare line counts. PawnIsItemAnUpgrade
-- calls it for each equipped slot x each scale on every tooltip refresh: ~1 ms each, dozens per second.
--
-- Pawn itself proves an item complete by returning the *same cached object* on a later call (the line
-- counts matched). Only then do we remember it, and we drop it whenever Pawn clears or uncaches items.

-- Temporary: remove once Pawn ships its own fix (reported to Vger, 2026-11-08).
if VgerCore and VgerCore.IsDraenorOrLater then return end -- retail Pawn trusts its cache already

local orig = PawnGetItemData
if type(orig) ~= "function" then return end

local seen = {}      -- link -> item object Pawn returned last time
local verified = {}  -- link -> item object Pawn returned twice (validated)

PawnGetItemData = function(ItemLink)
  if ItemLink then
    local item = verified[ItemLink]
    if item then
      if item.Values then return item end
      verified[ItemLink] = nil -- values were cleared; let Pawn recalculate
    end
  end
  local item = orig(ItemLink)
  if ItemLink and item and item.Values then
    if seen[ItemLink] == item then
      verified[ItemLink] = item
    else
      seen[ItemLink] = item
    end
  end
  return item
end

local function reset() wipe(seen); wipe(verified) end
for _, fname in ipairs({ "PawnClearCache", "PawnClearCacheValuesOnly", "PawnUncacheItem", "PawnInvalidateBestItems", "PawnResetTooltips" }) do
  if type(_G[fname]) == "function" then hooksecurefunc(fname, reset) end
end
