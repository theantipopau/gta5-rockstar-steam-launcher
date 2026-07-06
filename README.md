# GTA V (Rockstar Launcher) Steam Non-Steam-Game Launcher

A small PowerShell script that lets you add **GTA V Enhanced** to Steam as a non-Steam
game and have it launch hands-free — no clicking "Play" in the Rockstar Games Launcher
yourself. Built for couch/controller setups (Steam Big Picture, Steam Link) where
reaching for a mouse to click through Rockstar's launcher isn't practical.

## Why this exists

Rockstar Games Launcher UI is built with Chromium (CEF). Its "PLAY" button is a custom
web-rendered element, not a native Windows control — it doesn't expose itself to
Windows UI Automation / accessibility APIs, and Rockstar exposes no command-line flag
or public API to launch a specific title directly. That means there's no clean,
"proper" way to automate it. `GTA5_Enhanced.exe` also refuses to run standalone —
Rockstar's DRM requires it to be launched *through* the Launcher, which injects
session/auth data at runtime.

This script works around that by:
1. Launching Rockstar Games Launcher directly.
2. Locating its window by title (not `Process.MainWindowHandle`, which is unreliable
   for CEF-based apps — the visible window is often owned by a different internal
   process than the one PowerShell/`Get-Process` sees).
3. Trying UI Automation first (cheap, harmless — usually won't find anything, but
   costs nothing to try in case a future Launcher version changes this).
4. Falling back to an image search for the "PLAY" button's pixels, restricted **only**
   to the live Launcher window's own screen rectangle (never the whole desktop) —
   clicking wherever it's actually found rather than a fixed screen coordinate.
5. Waiting for `GTA5_Enhanced.exe` to actually appear, bringing it to the foreground,
   and minimizing Steam's Big Picture window if it's open (Big Picture won't auto-hide
   for a game it isn't directly tracking, since this whole approach deliberately keeps
   GTA V out of Steam's hooked process tree — that's what avoids a "Steam client
   failed to initialize" crash some users hit with GTA V Enhanced + Steam Overlay).
6. Waiting for the game to exit so Steam's "Playing" status stays accurate for the
   whole session, then cleaning up leftover Epic/Rockstar helper processes.

This works regardless of whether your copy of GTA V Enhanced came from Steam, Epic
Games, or was bought directly through Rockstar — the Launcher app and
`GTA5_Enhanced.exe` process name are the same either way. (If you own it on Steam,
you don't need this at all — just launch GTA V normally.)

## Setup

1. Clone/download this repo somewhere permanent, e.g. `D:\GTAV-AutoLaunch\`.
2. **Capture your own Play button image** — the exact pixels can vary slightly by
   Windows scaling/theme/resolution, so the included `playbutton.png` may not match
   your system:
   - Open Rockstar Games Launcher manually.
   - Press `Win+Shift+S`, tightly crop just the "PLAY" button (a little bit of
     surrounding background is fine).
   - Save it over `playbutton.png` in this folder.
3. In Steam, click **Add a Non-Steam Game**, and browse to:
   ```
   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
   ```
4. Right-click the new shortcut → **Properties**, and set:
   - **Launch Options**:
     ```
     -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\GTAV-AutoLaunch\LaunchGTAV.ps1"
     ```
     (adjust the path to wherever you put this folder)
   - **Start In**: the same folder
5. Rename the shortcut to whatever you like (e.g. "Grand Theft Auto V").
6. Launch it from Steam / Big Picture / Steam Link.

## Steam artwork (optional)

The `steam-artwork/` folder has the official GTA V Enhanced store assets (pulled
directly from Steam's own CDN, since the game is also sold on Steam under app id
`3240220`), so your shortcut doesn't have to look like a blank placeholder tile:

| File | Use for | Size |
|---|---|---|
| `grid_portrait.jpg` | Grid (Portrait) | 600x900 |
| `header.jpg` | Grid (Landscape) | 460x215 |
| `hero.jpg` | Hero | 1920x620 |
| `logo.png` | Logo | 640x360 |

To apply: right-click the shortcut in your Steam Library → **Manage** → **Set custom
artwork**, and drop in the matching file for each slot. For the **Icon**, don't use an
image from here — instead set it directly to your `GTA5_Enhanced.exe` path so Steam
extracts the real embedded icon.

## Troubleshooting

The script writes a timestamped log to `launch_log.txt` in the same folder on every
run — check it first. It records:
- Whether the Launcher window was found, and its handle
- Whether UI Automation found/clicked a button
- The actual screen rectangle it searched for the Play button image, and whether it
  found a match
- Whether `GTA5_Enhanced.exe` was ever detected

If the image match keeps failing, re-capture `playbutton.png` (see step 2) — this is
the single most common thing that needs adjusting per-machine.

## Notes / limitations

- Assumes the default Rockstar Games Launcher install path
  (`C:\Program Files\Rockstar Games\Launcher\Launcher.exe`). Edit `$launcherExe` at
  the top of the script if yours differs.
- The image search only succeeds if "PLAY" is the button actually showing (i.e. GTA V
  Enhanced is the last-viewed/selected title in the Launcher). If you have multiple
  Rockstar titles installed, make sure GTA V is selected the last time you used the
  Launcher manually.
- Not affiliated with Rockstar Games, Take-Two Interactive, Valve, or Epic Games.
  Automates clicking a button in an already-installed, legitimately-owned game's
  official launcher — nothing here bypasses DRM, authentication, or ownership checks.
- Use at your own risk. Rockstar could change their UI layout at any time and break
  the image match (you'd just need to recapture `playbutton.png`).

## License

MIT — see [LICENSE](LICENSE).
