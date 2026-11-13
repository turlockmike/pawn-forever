# Runs Lua inside the running WoW client without typing in chat, and prints what it returned.
# Needs the dev addon tools/WowBridge copied to Interface\AddOns\WowBridge (new folders are only
# detected at character select).
#
#   powershell -File tools\wowrun.ps1 -Code 'return { PawnVersion, UnitName("player") }'
#   powershell -File tools\wowrun.ps1 -File job.lua [-Shot after.png]
#
# The code is a function body. Return a value (tables are fine), or for async work call done(value)
# later, e.g.  C_Timer.After(3, function() done(GetItemInfo(270275)) end)
# It runs 2 s after the UI loads. The script clicks the addon's "Bridge" button (top centre of the
# game window) once to reload and start the job, and again to reload and save the result.
param([string]$Code = "", [string]$File = "", [string]$Shot = "", [int]$TimeoutSec = 90, [int]$Wait = 12,
  [string]$Wow = "C:\Program Files (x86)\World of Warcraft\_forever_", [string]$Account = "MICHAEL1986")
if ($File) { $Code = Get-Content -Raw $File }
if (-not $Code) { throw "pass -Code or -File" }
$addon = Join-Path $Wow "Interface\AddOns\WowBridge"
if (-not (Test-Path $addon)) { throw "WowBridge is not installed at $addon" }
$sv = Join-Path $Wow "WTF\Account\$Account\SavedVariables\WowBridge.lua"
$id = [guid]::NewGuid().ToString("N")
$job = "WowBridgeJob = { id = `"$id`", run = function(done)`n$Code`nend }`n"
[System.IO.File]::WriteAllText((Join-Path $addon "Job.lua"), $job, (New-Object System.Text.UTF8Encoding $false))

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class WB {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
  public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public struct RECT { public int L, T, R, B; }
}
"@
$p = Get-Process Wow -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $p.MainWindowHandle
function Click-Bridge {
  [WB]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [WB]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)  # Alt tap so focus is allowed
  if ([WB]::IsIconic($h)) { [WB]::ShowWindow($h, 9) | Out-Null }  # never restore a maximized window: it ends up larger than the screen
  [WB]::SetForegroundWindow($h) | Out-Null
  Start-Sleep -Milliseconds 400
  $c = New-Object WB+RECT; [WB]::GetClientRect($h, [ref]$c) | Out-Null
  # The button is anchored 30 UI units below the top centre; 47/1440 of the height hits its middle.
  $pt = New-Object WB+POINT; $pt.X = [int]($c.R / 2); $pt.Y = [int]($c.B * 47 / 1440)
  [WB]::ClientToScreen($h, [ref]$pt) | Out-Null
  [WB]::SetCursorPos($pt.X, $pt.Y) | Out-Null
  Start-Sleep -Milliseconds 150
  [WB]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60; [WB]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
}

Click-Bridge                      # reload 1: loads the new Job.lua and runs it
$deadline = (Get-Date).AddSeconds($TimeoutSec); $text = $null
while (-not $text -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds $Wait
  Click-Bridge                    # reload: saves WowBridgeDB
  Start-Sleep -Seconds 4
  if (Test-Path $sv) {
    $t = Get-Content -Raw $sv
    if ($t -and $t.Contains($id) -and $t -match '\["done"\] = true') { $text = $t }
  }
}
if ($Shot) {
  Start-Sleep -Seconds 6
  $r = New-Object WB+RECT; [WB]::GetWindowRect($h, [ref]$r) | Out-Null
  $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  [System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
  $bmp.Save($Shot, [System.Drawing.Imaging.ImageFormat]::Png)
}
if (-not $text) { Write-Error "No result within $TimeoutSec s. Is WowBridge loaded (button 'Bridge' at the top of the screen)? A syntax error in the code also ends up here; check BugSack."; exit 1 }
$text
