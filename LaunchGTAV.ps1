$launcherExe = "C:\Program Files\Rockstar Games\Launcher\Launcher.exe"
$gameProcName = "GTA5_Enhanced"
$scriptDir = $PSScriptRoot
$templatePath = Join-Path $scriptDir "playbutton.png"
$logFile = Join-Path $scriptDir "launch_log.txt"

function Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')  $msg" | Out-File -FilePath $logFile -Append -Encoding utf8
}

Log "=== Script started ==="

Add-Type @"
using System;
using System.Runtime.InteropServices;
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
public class Win32Auto {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
}
"@
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Try-ClickPlayViaUIA($hwnd) {
    try {
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
        if (-not $root) { Log "UIA: could not get root element"; return $false }
        $condition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Button
        )
        $buttons = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
        Log "UIA: found $($buttons.Count) button(s)"
        foreach ($btn in $buttons) {
            if ($btn.Current.Name.Trim() -ieq "PLAY") {
                Log "UIA: exact match on 'PLAY', invoking"
                $pattern = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $pattern.Invoke()
                return $true
            }
        }
        Log "UIA: no exact 'PLAY' button match found"
    } catch {
        Log "UIA: exception - $($_.Exception.Message)"
    }
    return $false
}

# Searches ONLY within the given screen rectangle (never the whole desktop) for a region
# matching the template image, using a handful of sample pixels per candidate position for speed.
function Find-TemplateInRect($templatePath, $rect, $tolerance = 24, $step = 3) {
    if (-not (Test-Path $templatePath)) { Log "Template image not found: $templatePath"; return $null }
    $template = [System.Drawing.Bitmap]::FromFile($templatePath)
    $tw = $template.Width
    $th = $template.Height

    $rectW = $rect.Right - $rect.Left
    $rectH = $rect.Bottom - $rect.Top
    if ($tw -ge $rectW -or $th -ge $rectH) { $template.Dispose(); return $null }

    $capture = New-Object System.Drawing.Bitmap $rectW, $rectH
    $g = [System.Drawing.Graphics]::FromImage($capture)
    $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $capture.Size)
    $g.Dispose()

    # sample a grid of points inside the template rather than every pixel, for speed
    $samplePoints = New-Object System.Collections.Generic.List[int[]]
    for ($sy = 0; $sy -lt $th; $sy += [Math]::Max(1, [int]($th / 6))) {
        for ($sx = 0; $sx -lt $tw; $sx += [Math]::Max(1, [int]($tw / 6))) {
            $samplePoints.Add(@($sx, $sy))
        }
    }
    $templateSamples = $samplePoints | ForEach-Object { $template.GetPixel($_[0], $_[1]) }

    $found = $null
    for ($y = 0; $y -le ($capture.Height - $th) -and -not $found; $y += $step) {
        for ($x = 0; $x -le ($capture.Width - $tw); $x += $step) {
            $match = $true
            for ($i = 0; $i -lt $samplePoints.Count; $i++) {
                $sx = $x + $samplePoints[$i][0]
                $sy = $y + $samplePoints[$i][1]
                $pixel = $capture.GetPixel($sx, $sy)
                $tpix = $templateSamples[$i]
                $diff = [Math]::Abs([int]$pixel.R - [int]$tpix.R) + [Math]::Abs([int]$pixel.G - [int]$tpix.G) + [Math]::Abs([int]$pixel.B - [int]$tpix.B)
                if ($diff -gt $tolerance) { $match = $false; break }
            }
            if ($match) {
                $found = New-Object System.Drawing.Point (($rect.Left + $x + [int]($tw / 2)), ($rect.Top + $y + [int]($th / 2)))
                break
            }
        }
    }

    $template.Dispose()
    $capture.Dispose()
    return $found
}

function Click-At($x, $y) {
    [Win32Auto]::SetCursorPos($x, $y)
    Start-Sleep -Milliseconds 150
    [Win32Auto]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero) # left down
    Start-Sleep -Milliseconds 80
    [Win32Auto]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero) # left up
}

# Finds a visible top-level window by title substring, independent of which process/thread owns
# it -- CEF/Chromium apps like Rockstar Launcher don't reliably expose Process.MainWindowHandle,
# so searching by actual window title is the robust way to locate the live window.
function Find-WindowByTitle($titleSubstring) {
    $script:foundHwnd = [IntPtr]::Zero
    $callback = [Win32Auto+EnumWindowsProc]{
        param($hWnd, $lParam)
        if ([Win32Auto]::IsWindowVisible($hWnd)) {
            $len = [Win32Auto]::GetWindowTextLength($hWnd)
            if ($len -gt 0) {
                $sb = New-Object System.Text.StringBuilder ($len + 1)
                [Win32Auto]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
                if ($sb.ToString() -like "*$titleSubstring*") {
                    $script:foundHwnd = $hWnd
                    return $false
                }
            }
        }
        return $true
    }
    [Win32Auto]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
    return $script:foundHwnd
}

function Minimize-SteamWindows {
    $steamProcs = Get-Process -Name "steam" -ErrorAction SilentlyContinue
    if (-not $steamProcs) { return }
    $script:steamPids = $steamProcs | ForEach-Object { $_.Id }
    $callback = [Win32Auto+EnumWindowsProc]{
        param($hWnd, $lParam)
        $procId = 0
        [Win32Auto]::GetWindowThreadProcessId($hWnd, [ref]$procId) | Out-Null
        if ($script:steamPids -contains $procId -and [Win32Auto]::IsWindowVisible($hWnd)) {
            [Win32Auto]::ShowWindow($hWnd, 6) # SW_MINIMIZE
        }
        return $true
    }
    [Win32Auto]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
}

# 1. Launch Rockstar Games Launcher
Log "Launching Rockstar Games Launcher..."
Start-Process -FilePath $launcherExe

# 2. Wait for its window to appear (by title, not Process.MainWindowHandle -- unreliable for CEF apps)
$deadline = (Get-Date).AddSeconds(60)
$hwnd = [IntPtr]::Zero
while ((Get-Date) -lt $deadline) {
    $hwnd = Find-WindowByTitle "Rockstar Games Launcher"
    if ($hwnd -ne [IntPtr]::Zero) { break }
    Start-Sleep -Milliseconds 500
}

if ($hwnd -ne [IntPtr]::Zero) {
    Log "Launcher window found (HWND $hwnd)"
    Start-Sleep -Seconds 10

    # re-find the window fresh right before interacting -- it may have been replaced by a new
    # window as the CEF UI finished loading during the wait above
    $liveHwnd = Find-WindowByTitle "Rockstar Games Launcher"
    if ($liveHwnd -eq [IntPtr]::Zero) { $liveHwnd = $hwnd }
    Log "Using live HWND: $liveHwnd"

    [Win32Auto]::SetForegroundWindow($liveHwnd)
    Start-Sleep -Milliseconds 500

    $clicked = Try-ClickPlayViaUIA($liveHwnd)

    if (-not $clicked) {
        $rect = New-Object RECT
        $gotRect = [Win32Auto]::GetWindowRect($liveHwnd, [ref]$rect)
        Log "GetWindowRect returned $gotRect -- L=$($rect.Left) T=$($rect.Top) R=$($rect.Right) B=$($rect.Bottom)"
        $point = Find-TemplateInRect $templatePath $rect

        if ($point) {
            Log "Play button image matched at ($($point.X), $($point.Y)), clicking"
            Click-At $point.X $point.Y
            $clicked = $true
        } elseif ($gotRect -and ($rect.Right - $rect.Left) -gt 0) {
            Log "Image match failed, falling back to proportional click"
            $width = $rect.Right - $rect.Left
            $height = $rect.Bottom - $rect.Top
            $clickX = $rect.Left + [int]($width * 0.26)
            $clickY = $rect.Top + [int]($height * 0.63)
            Click-At $clickX $clickY
        } else {
            Log "GetWindowRect invalid too -- skipping click entirely, nothing safe to click"
        }
    }
} else {
    Log "Launcher window never appeared within 60s"
}

# 3. Wait for the real game process to appear (up to 3 minutes)
Log "Waiting for $gameProcName to appear..."
$deadline = (Get-Date).AddSeconds(180)
$gameProc = $null
while ((Get-Date) -lt $deadline) {
    $gameProc = Get-Process -Name $gameProcName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gameProc) { break }
    Start-Sleep -Seconds 1
}
if ($gameProc) {
    Log "$gameProcName detected (PID $($gameProc.Id))"
} else {
    Log "$gameProcName never appeared within 180s"
}

# 4. Bring the game to the front and get Big Picture out of the way (it won't auto-hide since it
#    doesn't recognize this process as "its" game), then wait for exit so Steam's "Playing" status
#    stays accurate for the whole session
if ($gameProc) {
    Start-Sleep -Seconds 3
    $gameProc.Refresh()
    Log "Minimizing Steam windows and foregrounding game (game HWND: $($gameProc.MainWindowHandle))"
    Minimize-SteamWindows
    if ($gameProc.MainWindowHandle -ne 0) {
        [Win32Auto]::SetForegroundWindow($gameProc.MainWindowHandle)
    }
    $gameProc.WaitForExit()
    Log "$gameProcName exited"
}

# 5. Clean up leftover Epic/Rockstar helper processes
Start-Sleep -Seconds 2
taskkill /F /IM EpicWebHelper.exe /T 2>$null
taskkill /F /IM EOSOverlayRenderer-Win64-Shipping.exe 2>$null
taskkill /F /IM EOSOverlayRenderer-Win32-Shipping.exe 2>$null
taskkill /F /IM Launcher.exe 2>$null
Log "=== Script finished ==="
