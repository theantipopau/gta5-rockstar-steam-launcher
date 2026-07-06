<p align="center">
  <img src="steam-artwork/hero.jpg" alt="GTA V Enhanced" width="100%">
</p>

<h1 align="center">GTA V Enhanced — Hands-Free Steam Launch</h1>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows-0078D6?logo=windows&logoColor=white">
  <a href="https://matthurley.dev"><img alt="Created by Matt Hurley" src="https://img.shields.io/badge/created%20by-Matt%20Hurley-informational"></a>
</p>

<p align="center">
  Add <b>GTA V Enhanced</b> to Steam as a non-Steam game and launch it with a single
  click — no reaching for a mouse to click "Play" in Rockstar Games Launcher every
  time. Built for couch play: Steam Big Picture, Steam Link, and Xbox/PlayStation
  controllers over Steam Input.
</p>

---

No coding or GitHub experience needed — just follow the steps below in order.
Everything here is free and uses only things already built into Windows and Steam.

## Setup

### 1. Download this project

- Click the green **Code** button near the top of this page → **Download ZIP**.
  *(If you'd rather grab a fixed, tested version instead of the latest code, use the
  [Releases page](../../releases) on the right side of this repo instead and download
  the zip attached to the newest release.)*
- Once downloaded, right-click the zip → **Extract All...** and pick a permanent
  location you won't move or delete later, e.g. `D:\GTAV-AutoLaunch\`. (Anywhere
  works — just remember the folder, you'll need its path in step 3.)
- **If Windows shows a blue "Windows protected your PC" SmartScreen warning** when
  opening the zip or the folder: this is normal for any script downloaded from the
  internet that isn't digitally signed by a paid certificate (most free/hobby GitHub
  tools show this). Click **More info** → **Run anyway**, or just ignore it — nothing
  in this folder needs to be "run" directly; Steam will run the script for you later.

### 2. Capture your own "PLAY" button image

The included `playbutton.png` was captured on one specific Windows setup — button
pixels can shift slightly with different display scaling, themes, or resolutions, so
it's best to replace it with your own:

1. Open Rockstar Games Launcher normally (double-click it like you always would).
2. Once it's fully loaded and showing GTA V's PLAY button, press `Win+Shift+S` on
   your keyboard (Windows' built-in snipping tool — a small toolbar appears at the
   top of your screen).
3. Click and drag a tight box around just the **PLAY** button (a little bit of
   background around it is fine, but avoid capturing anything else like the
   promotional tiles next to it).
4. This copies the snip to your clipboard. Open **Paint** (search for it in the
   Start menu), press `Ctrl+V` to paste it in, then **File → Save As** → save it as
   `playbutton.png` directly into the folder from step 1, replacing the existing file
   (choose "Yes" to overwrite when asked).

### 3. Add it to Steam

1. Open Steam, go to the **Library** tab.
2. Bottom-left corner, click **+ Add a Game** → **Add a Non-Steam Game...**
   (on some Steam versions this is under the **Games** menu at the top instead).
3. In the file browser that opens, paste this into the filename box and press Enter:
   ```
   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
   ```
4. Tick the checkbox next to it in the list, then click **Add Selected Programs**.
5. Find the new "powershell" entry in your Library, right-click it → **Properties**.
6. In the **General** tab of the Properties window, find the **LAUNCH OPTIONS** box
   near the bottom and paste this in — **but first edit the folder path** to match
   wherever you actually extracted this project in step 1:
   ```
   -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\GTAV-AutoLaunch\LaunchGTAV.ps1"
   ```
7. Also find the **Target** and **Start In** fields near the top of the same tab —
   set **Start In** to your project folder path as well (e.g. `D:\GTAV-AutoLaunch\`,
   no quotes needed there).
8. At the very top of the Properties window, rename the shortcut from "powershell"
   to something sensible like `Grand Theft Auto V`.
9. Close the Properties window. You're done — launch it from your Steam Library, Big
   Picture Mode, or Steam Link like any other game.

## Make it look like a real Steam game

<p align="center">
  <img src="steam-artwork/grid_portrait.jpg" alt="Portrait grid" height="220">
  &nbsp;&nbsp;
  <img src="steam-artwork/logo.png" alt="Logo" height="120">
</p>

The `steam-artwork/` folder has the official GTA V Enhanced store assets, pulled
straight from Steam's own CDN (the game is also sold on Steam under app id
`3240220`), so your shortcut doesn't have to sit there as a blank tile.

| File | Steam slot | Size |
|---|---|---|
| `steam-artwork/grid_portrait.jpg` | Grid (Portrait) | 600×900 |
| `steam-artwork/header.jpg` | Grid (Landscape) | 460×215 |
| `steam-artwork/hero.jpg` | Hero | 1920×620 |
| `steam-artwork/logo.png` | Logo | 640×360 |

**To apply them:**

1. Add the shortcut to Steam first (see Setup above) and restart Steam if it was
   already open.
2. In your Steam **Library**, find the new shortcut and right-click it.
3. Choose **Manage** → **Set Custom Artwork** (older Steam clients: **Manage** →
   **Edit Steam Grid Image**).
4. A picker opens with tabs/slots for **Grid**, **Hero**, and **Logo** — for each
   one, click it and browse to the matching file from the table above.
5. For the **Icon** (shown in your taskbar/desktop, not part of the picker above):
   right-click the shortcut → **Properties**, and set the icon path directly to your
   `GTA5_Enhanced.exe` — Steam will pull the real embedded icon rather than needing an
   image file.
6. Back out to your Library view — the tile now looks like any other Steam game.

## How it works (technical details)

<details>
<summary>Click to expand — not needed to use the tool, just for the curious</summary>

Rockstar Games Launcher's UI is built with Chromium (CEF). Its "PLAY" button is a
custom web-rendered element, not a native Windows control, so it doesn't expose
itself to Windows accessibility APIs — and Rockstar has no command-line flag or public
API to launch a specific title directly. `GTA5_Enhanced.exe` also refuses to run
standalone; Rockstar's DRM requires it to be launched *through* the Launcher, which
injects session/auth data at runtime.

So there's no "clean" way to automate this. The script does the next best thing:

1. Launches Rockstar Games Launcher directly.
2. Finds its window by title text (not `Process.MainWindowHandle`, which is
   unreliable for CEF apps — the visible window is often owned by a different
   internal process than the one PowerShell sees).
3. Tries UI Automation first (cheap, harmless, occasionally works on future
   Launcher versions).
4. Falls back to an image search for the "PLAY" button's actual pixels — restricted
   **only** to the live Launcher window's own screen rectangle, never the whole
   desktop — and clicks wherever it's actually found.
5. Waits for `GTA5_Enhanced.exe` to appear, brings it to the foreground, and
   minimizes Steam's Big Picture window if it's open (Big Picture won't auto-hide for
   a game it isn't directly tracking — this approach deliberately keeps GTA V outside
   Steam's hooked process tree, which is also what avoids a **"Steam client failed to
   initialize, please reinstall the game"** crash some setups hit otherwise).
6. Waits for the game to exit so Steam's "Playing" status stays accurate for the
   whole session, then cleans up leftover helper processes.

Works no matter which storefront your copy came from — Epic, Rockstar directly, or
Steam — since the Launcher app and `GTA5_Enhanced.exe` process name are identical
either way. (Already own it on Steam? You don't need any of this — just launch it
normally.)

</details>

## Troubleshooting

The script writes a timestamped log to `launch_log.txt` in the same folder on every
run — check it first. It records:
- Whether the Launcher window was found, and its handle
- Whether UI Automation found/clicked a button
- The actual screen rectangle it searched for the Play button image, and whether it
  found a match
- Whether `GTA5_Enhanced.exe` was ever detected

If the image match keeps failing, re-capture `playbutton.png` (see Setup step 2) —
that's the single most common thing that needs adjusting per-machine.

## Notes / limitations

- Assumes the default Rockstar Games Launcher install path
  (`C:\Program Files\Rockstar Games\Launcher\Launcher.exe`). Edit `$launcherExe` at
  the top of the script if yours differs.
- The image search only succeeds if "PLAY" is the button actually showing — i.e. GTA V
  Enhanced needs to be the last-viewed/selected title in the Launcher. If you have
  multiple Rockstar titles installed, make sure GTA V is selected the last time you
  used the Launcher manually.
- Not affiliated with Rockstar Games, Take-Two Interactive, Valve, or Epic Games.
  Automates clicking a button in an already-installed, legitimately-owned game's
  official launcher — nothing here bypasses DRM, authentication, or ownership checks.
- Use at your own risk. Rockstar could change their UI layout at any time and break
  the image match — you'd just need to recapture `playbutton.png`.

## Contributing

Issues and PRs welcome — especially if you've adapted this for other Rockstar
titles (RDR2 etc.) or found a more reliable way to locate the Play button.

## Author

Created by [Matt Hurley](https://matthurley.dev).

## License

MIT — see [LICENSE](LICENSE).
