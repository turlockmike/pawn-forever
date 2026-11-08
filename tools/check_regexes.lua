-- Offline check: runs Pawn's tooltip regex table (optionally plus PawnForever/Parsing.lua) over ~32k real
-- WoW Forever tooltips taken from GearQuest Forever's audit data, and lists the stat lines nothing matches.
--
--   luajit tools/check_regexes.lua            -- Pawn + Pawn Forever
--   luajit tools/check_regexes.lua --stock    -- Pawn alone
-- Set ADDONS to your Interface/AddOns folder if it isn't the default Forever install.

local P = (os.getenv("ADDONS") or "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns") .. "/"
local stock = arg[1] == "--stock"

GetBuildInfo = function() return "1.60.1", "70790", "", 16001 end
WOW_PROJECT_ID = 99; WOW_PROJECT_CLASSIC = 2; WOW_PROJECT_MAINLINE = 1
strlen = string.len; strsub = string.sub; strlower = string.lower; strupper = string.upper; strmatch = string.match
gmatch = string.gmatch; tremove = table.remove; floor = math.floor; gsub = string.gsub; strfind = string.find
tinsert = table.insert; format = string.format
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
GetLocale = function() return "enUS" end
LARGE_NUMBER_SEPERATOR = ","
setmetatable(_G, { __index = function(_, k)
  if type(k) == "string" and k:match("^[A-Z][A-Z0-9_]+$") then return "ZZUNSET_" .. k end
end })
dofile(P .. "Pawn/VgerCore/VgerCore.lua")
assert(VgerCore.IsForever, "VgerCore doesn't think this is Forever")
dofile(P .. "Pawn/Core.lua")
dofile(P .. "Pawn/Localization.lua")
dofile(P .. "Pawn/TooltipParsing.lua")

function PawnFindStringInRegexTable(s, t)
  for _, r in ipairs(t) do
    if r[1] then
      local m = { s:find(r[1]) }
      if m[1] then return r, select(3, unpack(m)) end
    end
  end
end

local PF = {}
if not stock then
  dofile("tools/fixtures/globals_enUS.lua")
  assert(loadfile("PawnForever/Parsing.lua"))("PawnForever", PF)
  io.stderr:write(("Pawn Forever added %d patterns\n"):format(#PF.AddedPatterns))
end

local function Normalize(s)
  for _, e in pairs(PawnNormalizationRegexes or {}) do s = s:gsub(e[1], e[2], 1) end
  return s
end

local tips = {}
local function grab(file)
  local f = io.open(file, "rb"); if not f then return end
  local s = f:read("*a"); f:close()
  for tip in s:gmatch('tip="(.-[^\\])"') do tips[#tips + 1] = tip end
  for _, tip in s:gmatch('%[(%d+)%]="(Item Level.-[^\\])"') do tips[#tips + 1] = tip end
end
grab(P .. "GearQuestForever/_generated/Data.ForeverAudit.generated.lua")
for _, c in ipairs { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" } do
  grab(P .. "GearQuestForever_" .. c .. "/AuditTips.lua")
end
io.stderr:write("tooltips: " .. #tips .. "\n")

local miss, hit = {}, {}
for _, tip in ipairs(tips) do
  tip = tip:gsub("\\n", "\n"):gsub('\\"', '"')
  for line in (tip .. "\n"):gmatch("(.-)\n") do
    local low = line:lower()
    if (low:find("heal") or low:find("spell") or low:find("damage") or low:find("mana") or low:find("magical") or low:find("armor"))
       and not line:find("^%(%d") and not line:find("Set :") then
      local r, c1, c2 = PawnFindStringInRegexTable(Normalize(line), PawnRegexes)
      local key = line:gsub("%d+%.?%d*", "#")
      local t = r and hit or miss
      t[key] = t[key] or { n = 0, as = r and ((r[2] or "(ignored)") .. (r[5] and ("+" .. r[5]) or "")) .. " " .. tostring(c1) .. (c2 and ("," .. c2) or "") or nil }
      t[key].n = t[key].n + 1
    end
  end
end

local function dump(t, title, limit)
  local arr = {}
  for k, v in pairs(t) do arr[#arr + 1] = { k = k, v = v } end
  table.sort(arr, function(a, b) return a.v.n > b.v.n end)
  local total = 0
  for _, e in ipairs(arr) do total = total + e.v.n end
  print(("==== %s: %d distinct, %d lines"):format(title, #arr, total))
  for i, e in ipairs(arr) do
    if i > limit then break end
    print(e.v.n, e.v.as or "", e.k)
  end
end
dump(miss, "NOT READ", tonumber(os.getenv("LIMIT") or 40))
if os.getenv("SHOWHIT") then dump(hit, "READ", 200) end
