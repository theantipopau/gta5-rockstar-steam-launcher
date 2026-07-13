<#
    Red Dead Redemption 2 (Rockstar Launcher) Steam Non-Steam-Game Launcher
    github.com/theantipopau/gta5-rockstar-steam-launcher
    Created by Matt Hurley - matthurley.dev

    Point Steam's Launch Options at THIS file. It just sets which game to look for and
    hands off to Launch-Core.ps1, which does the actual work.

    NOTE: RDR2.exe is the real long-running process name based on community reports
    (RDR2's launcher stub is PlayRDR2.exe, which hands off to RDR2.exe -- the same
    stub-then-real-process pattern as GTA V). This hasn't been verified against a real
    install the way the GTA V config has. If "RDR2" never appears in launch_log.txt and
    the game doesn't launch, check Task Manager's Details tab while RDR2 is running to
    confirm the actual process name and update $GameProcessName below if it differs.
#>

$GameProcessName = "RDR2"
$TemplateImageName = "playbutton-rdr2.png"

. (Join-Path $PSScriptRoot "Launch-Core.ps1")
