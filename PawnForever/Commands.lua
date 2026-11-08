-- /pff (or /pawnforever) commands.

local _, PF = ...

-- Which tooltip lines of your equipped and bag gear does Pawn still not understand?
local function ScanTooltip(data, link, out)
  if not data or not data.lines then return end
  local rec = { link = link, unparsed = {}, values = {} }
  for i = 2, #data.lines do
    local text = data.lines[i].leftText
    if text and text ~= "" then
      local n = PF.Normalize(text)
      if n ~= "" and not PawnFindStringInRegexTable(n, PawnRegexes) then tinsert(rec.unparsed, n) end
    end
  end
  local item = link and PawnGetItemData(link)
  if item and item.Values then
    for _, v in ipairs(item.Values) do
      if PawnCommon.Scales[v[1]] and PawnIsScaleVisible(v[1]) then rec.values[v[1]] = v[2] end
    end
  end
  if item and item.Stats then
    rec.stats = {}
    for k, v in pairs(item.Stats) do rec.stats[k] = v end
  end
  tinsert(out, rec)
end

local function Diag()
  local out = {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link then ScanTooltip(C_TooltipInfo.GetInventoryItem("player", slot), link, out) end
  end
  for bag = 0, 4 do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local link = C_Container.GetContainerItemLink(bag, slot)
      if link then
        local _, _, _, _, _, classID = GetItemInfoInstant(link)
        if classID == 2 or classID == 4 then ScanTooltip(C_TooltipInfo.GetBagItem(bag, slot), link, out) end
      end
    end
  end
  PawnForeverDB.diag = { time = date("%Y-%m-%d %H:%M:%S"), player = UnitName("player"), level = UnitLevel("player"), locale = GetLocale(), items = out }
  local n = 0
  for _, r in ipairs(out) do
    for _, u in ipairs(r.unparsed) do
      n = n + 1
      if n <= 10 then print("  " .. r.link .. ": " .. u) end
    end
  end
  print(("|cffff7c0aPawn Forever:|r scanned %d items, %d lines Pawn doesn't read (full list saved to PawnForeverDB.diag on /reload)."):format(#out, n))
end

local function Patterns()
  print(("|cffff7c0aPawn Forever:|r %d extra tooltip patterns active (%s client):"):format(#PF.AddedPatterns, GetLocale()))
  for _, p in ipairs(PF.AddedPatterns) do print("  " .. p.sample) end
  PawnForeverDB.patterns = PF.AddedPatterns
end

SLASH_PAWNFOREVER1 = "/pawnforever"
SLASH_PAWNFOREVER2 = "/pff"
SlashCmdList.PAWNFOREVER = function(msg)
  msg = strlower(strtrim(msg or ""))
  if msg == "diag" then Diag()
  elseif msg == "cleardiag" then PawnForeverDB.diag = nil; print("Pawn Forever: diag cleared")
  elseif msg == "patterns" then Patterns()
  elseif msg == "forever" or msg == "show" then PF.UseScales(true); print("Pawn Forever: showing Pawn Forever scales for your class.")
  elseif msg == "stock" then PF.UseScales(false); print("Pawn Forever: showing Pawn's stock scales for your class.")
  else
    print("|cffff7c0aPawn Forever|r (weights: " .. (PF.CurrentBand == "max" and "level 60" or "leveling") .. ")")
    print("  /pff forever - use Pawn Forever scales for your class")
    print("  /pff stock - go back to Pawn's stock scales")
    print("  /pff diag - list tooltip lines Pawn can't read on your gear")
    print("  /pff patterns - list the extra tooltip patterns this client uses")
  end
end
