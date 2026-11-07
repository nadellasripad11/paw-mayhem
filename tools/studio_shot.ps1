# takes a screenshot of the roblox studio window (only that window, not the
# whole screen) so it can be looked at while testing.
#   powershell -ExecutionPolicy Bypass -File tools/studio_shot.ps1 [out.png]
param([string]$Out = "$env:TEMP\studio_shot.png")

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[Win]::SetProcessDPIAware() | Out-Null

$p = Get-Process -Name "RobloxStudioBeta" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Output "studio is not open"; exit 1 }
$h = $p.MainWindowHandle
if ([Win]::IsIconic($h)) { Write-Output "studio is minimised - restore it first"; exit 1 }

$r = New-Object Win+RECT
[Win]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.R - $r.L; $ht = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
# PrintWindow with PW_RENDERFULLCONTENT (2) captures the window even when
# other windows cover it, including the 3d viewport
$dc = $g.GetHdc()
$ok = [Win]::PrintWindow($h, $dc, 2)
$g.ReleaseHdc($dc)
if (-not $ok) { $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size) }
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "saved $Out ($w x $ht)"
