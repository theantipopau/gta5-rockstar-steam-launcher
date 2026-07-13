<#
    GTA V (Rockstar Launcher) Steam Non-Steam-Game Launcher
    github.com/theantipopau/gta5-rockstar-steam-launcher
    Created by Matt Hurley - matthurley.dev

    Point Steam's Launch Options at THIS file. It just sets which game to look for and
    hands off to Launch-Core.ps1, which does the actual work.
#>

$GameProcessName = "GTA5_Enhanced"
$TemplateImageName = "playbutton-gtav.png"

. (Join-Path $PSScriptRoot "Launch-Core.ps1")
