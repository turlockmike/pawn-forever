-- Structural packaging checks for Pawn_Forever (runs anywhere with Lua/LuaJIT, no WoW install needed).
-- Usage: luajit tools/check_packaging.lua [expected_version]
-- Prevents shipping missing/invalid icons, broken .toc references, Lua syntax errors,
-- mismatched versions/changelogs, or stale SavedVariables names.

local FOLDER = "Pawn_Forever"
local TOC_PATH = FOLDER .. "/" .. FOLDER .. ".toc"
local expectedVersion = arg[1]

local function readAll(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function fail(msg)
  io.stderr:write("FAIL: " .. msg .. "\n")
  os.exit(1)
end

local toc = readAll(TOC_PATH)
if not toc then fail("missing " .. TOC_PATH) end

local version, savedVars, iconPath
local luaFiles = {}
for rawLine in (toc .. "\n"):gmatch("(.-)\r?\n") do
  local line = rawLine:match("^%s*(.-)%s*$")
  if line:find("^##%s*") then
    local k, v = line:match("^##%s*([^:]+):%s*(.-)%s*$")
    if k == "Version" then version = v
    elseif k == "SavedVariables" then savedVars = v
    elseif k == "IconTexture" then iconPath = v
    end
  elseif line ~= "" and not line:find("^#") then
    luaFiles[#luaFiles + 1] = line
  end
end

if not version or not version:match("^%d+%.%d+%.%d+$") then
  fail("invalid or missing ## Version in " .. TOC_PATH .. ": " .. tostring(version))
end
if expectedVersion and version ~= expectedVersion then
  fail(("TOC version %s does not match expected %s"):format(version, expectedVersion))
end

-- 1. Every Lua file listed in .toc must exist and compile cleanly.
if #luaFiles == 0 then fail("no Lua files listed in " .. TOC_PATH) end
for _, rel in ipairs(luaFiles) do
  local full = FOLDER .. "/" .. rel
  local fn, err = loadfile(full)
  if not fn then fail("Lua syntax/load error in " .. full .. ": " .. tostring(err)) end
end

-- 2. SavedVariables must be defined, distinct from Direcktive's PawnForeverDB, and referenced in code.
if not savedVars or savedVars == "" then fail("missing ## SavedVariables in " .. TOC_PATH) end
if savedVars == "PawnForeverDB" then fail("SavedVariables must not collide with PawnForeverDB") end
local foundSV = false
for _, rel in ipairs(luaFiles) do
  local src = readAll(FOLDER .. "/" .. rel) or ""
  if src:find("PawnForeverDB", 1, true) then
    fail("stale PawnForeverDB reference in " .. FOLDER .. "/" .. rel)
  end
  if src:find(savedVars, 1, true) then foundSV = true end
end
if not foundSV then fail("SavedVariables " .. savedVars .. " is not referenced in addon Lua files") end

-- 3. IconTexture must exist and be a valid power-of-two 32-bit TGA (prevents red '?' in WoW AddOn list).
if not iconPath then fail("missing ## IconTexture in " .. TOC_PATH) end
local relIcon = iconPath:match("^Interface\\AddOns\\" .. FOLDER .. "\\(.+)$")
if not relIcon then
  fail("IconTexture must point inside Interface\\AddOns\\" .. FOLDER .. "\\ (got: " .. iconPath .. ")")
end
local iconFile = FOLDER .. "/" .. relIcon:gsub("\\", "/")
local tga = readAll(iconFile)
if not tga or #tga < 18 then fail("missing or truncated icon texture: " .. iconFile) end
local imgType = tga:byte(3)
local w = tga:byte(13) + tga:byte(14) * 256
local h = tga:byte(15) + tga:byte(16) * 256
local bpp = tga:byte(17)
local function isPow2(n) return n >= 16 and n <= 512 and (n == 16 or n == 32 or n == 64 or n == 128 or n == 256 or n == 512) end
if imgType ~= 2 and imgType ~= 10 then fail("icon TGA must be true-color (type 2 or 10), got " .. imgType) end
if bpp ~= 24 and bpp ~= 32 then fail("icon TGA must be 24-bit or 32-bit, got " .. bpp) end
if not isPow2(w) or not isPow2(h) then fail(("icon TGA dimensions must be power-of-two (got %dx%d)"):format(w, h)) end

-- 4. CHANGELOG.md must have a section for this version.
local changelog = readAll("CHANGELOG.md")
if not changelog then fail("missing CHANGELOG.md") end
local topVer = changelog:match("##%s+(%d+%.%d+%.%d+)")
if topVer ~= version then
  fail(("top CHANGELOG.md version (%s) does not match .toc version (%s)"):format(tostring(topVer), version))
end

-- 5. Release workflow must use --form-string for CurseForge JSON metadata (curl -F truncates at semicolons).
local workflow = readAll(".github/workflows/release.yml")
if workflow and workflow:find('%-F%s+"metadata=', 1) then
  fail(".github/workflows/release.yml uses -F for metadata (breaks on semicolons); use --form-string")
end

print(("ok: %s v%s (%d lua files, %s %dx%d %dbpp TGA, CHANGELOG & workflow verified)"):format(
  FOLDER, version, #luaFiles, iconFile, w, h, bpp))
