-- WowBridge: run a Lua job from disk without typing in chat (development tool, not part of the release).
--
-- tools/wowrun.ps1 writes the job into Job.lua and clicks the "Bridge" button at the top of the screen.
-- That reloads the UI, the new job runs once and puts its result in WowBridgeDB. A second click reloads
-- again, which writes WowBridgeDB to disk for the script to read. (A ReloadUI called from a timer
-- did not fire on Forever, so the script clicks twice.)

local job = WowBridgeJob

local btn = CreateFrame("Button", "WowBridgeButton", UIParent, "UIPanelButtonTemplate")
btn:SetSize(70, 20)
btn:SetPoint("TOP", UIParent, "TOP", 0, -30)
btn:SetText("Bridge")
btn:SetScript("OnClick", ReloadUI)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  WowBridgeDB = WowBridgeDB or {}
  if type(job) ~= "table" or WowBridgeDB.id == job.id then return end -- each job runs once

  local db = { id = job.id, done = false }
  WowBridgeDB = db
  local finished = false
  local function done(result)
    if finished then return end
    finished = true
    db.result, db.done = result, true
    btn:SetText("Done")
  end
  C_Timer.After(job.delay or 2, function()
    local ok, res = pcall(job.run, done)
    if not ok then db.error = tostring(res); done(nil)
    elseif res ~= nil then done(res) end
  end)
  C_Timer.After(job.timeout or 20, function()
    if not finished then db.error = "timeout: the job never called done()"; done(nil) end
  end)
end)
