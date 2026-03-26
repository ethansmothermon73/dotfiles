#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs ChristianLempa (xcad) dotfiles on Windows 11, sets wallpaper, and enables dark mode.

.DESCRIPTION
    - Installs Winget packages: Windows Terminal, PowerShell 7, Starship, Nerd Fonts, Neofetch
    - Deploys PowerShell profile, Starship config, and Windows Terminal settings
    - Sets Windows 11 dark mode (system + apps)
    - Downloads and sets the Mr. Robot wallpaper

.NOTES
    Run from an elevated PowerShell 7+ window:
        Set-ExecutionPolicy Bypass -Scope Process -Force
        .\Setup-Dotfiles.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────
function Write-Step  { param([string]$msg) Write-Host "`n━━━  $msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$msg) Write-Host "  ✔  $msg" -ForegroundColor Green }
function Write-Warn  { param([string]$msg) Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Fail  { param([string]$msg) Write-Host "  ✖  $msg" -ForegroundColor Red }

function Install-WingetPackage {
    param([string]$Id, [string]$Label)
    Write-Host "  →  Installing $Label ($Id)…" -NoNewline
    $result = winget install --id $Id --accept-source-agreements --accept-package-agreements --silent 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {   # -1978335189 = already installed
        Write-Ok "$Label installed / already present."
    } else {
        Write-Warn "$Label may not have installed cleanly (exit $LASTEXITCODE). Continuing…"
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# ─────────────────────────────────────────────────────────────
#  0. Pre-flight
# ─────────────────────────────────────────────────────────────
Write-Step "Pre-flight checks"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "winget not found. Install App Installer from the Microsoft Store and re-run."
    exit 1
}
Write-Ok "winget found."

# ─────────────────────────────────────────────────────────────
#  1. Core packages
# ─────────────────────────────────────────────────────────────
Write-Step "Installing packages via winget"

Install-WingetPackage "Microsoft.PowerShell"          "PowerShell 7"
Install-WingetPackage "Microsoft.WindowsTerminal"     "Windows Terminal"
Install-WingetPackage "Starship.Starship"             "Starship Prompt"
Install-WingetPackage "Git.Git"                       "Git"
Install-WingetPackage "junegunn.fzf"                  "fzf"

# Hack Nerd Font  (used in the WT settings)
Install-WingetPackage "DEVCOM.JetBrainsMonoNerdFont"  "JetBrainsMono Nerd Font"   # fallback
# Try the exact Hack Nerd Font if available
$hackId = "Hackgen.HackGenNerd"
Write-Host "  →  Attempting Hack Nerd Font…" -NoNewline
winget install --id $hackId --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
    Write-Ok "Hack Nerd Font installed."
} else {
    Write-Warn "Hack Nerd Font not found in winget; JetBrainsMono Nerd Font installed as fallback. Update the WT settings font face if needed."
}

# Neofetch (via Scoop if winget doesn't carry it)
$neofetchViaWinget = winget install --id "nepnep.neofetch-win" --accept-source-agreements --accept-package-agreements --silent 2>&1
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
    Write-Warn "neofetch not available via winget. Installing Scoop then neofetch…"
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
    }
    scoop install neofetch
}
Write-Ok "neofetch handled."

# ─────────────────────────────────────────────────────────────
#  2. Deploy dotfiles
# ─────────────────────────────────────────────────────────────
Write-Step "Deploying dotfiles"

$dotfilesRepo = "https://github.com/ChristianLempa/dotfiles/archive/refs/heads/main.zip"
$tmpZip       = "$env:TEMP\xcad-dotfiles.zip"
$tmpDir       = "$env:TEMP\xcad-dotfiles"

Write-Host "  →  Downloading dotfiles from GitHub…"
Invoke-WebRequest -Uri $dotfilesRepo -OutFile $tmpZip -UseBasicParsing

if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

# Find the extracted root (handles both "dotfiles-main" and similar names)
$extractedRoot = (Get-ChildItem $tmpDir -Directory | Select-Object -First 1).FullName
$winRoot       = Join-Path $extractedRoot "Windows"

# ── 2a. PowerShell profile ──────────────────────────────────
$psProfileDir = Split-Path $PROFILE -Parent
Ensure-Directory $psProfileDir

$sourceProfile = Join-Path $winRoot ".pwsh\Microsoft.PowerShell_profile.ps1"
if (Test-Path $sourceProfile) {
    Copy-Item $sourceProfile $PROFILE -Force
    Write-Ok "PowerShell profile deployed → $PROFILE"
} else {
    Write-Warn "Source profile not found at $sourceProfile; writing a minimal one."
    @'
# Minimal xcad profile
$ENV:STARSHIP_CONFIG  = "$HOME\.starship\starship.toml"
$ENV:STARSHIP_DISTRO  = "者  $env:username"
Invoke-Expression (&starship init powershell)
'@ | Set-Content $PROFILE -Encoding UTF8
    Write-Ok "Minimal PowerShell profile written."
}

# ── 2b. Starship config ─────────────────────────────────────
$starshipDir    = "$HOME\.starship"
$starshipConfig = Join-Path $starshipDir "starship.toml"
Ensure-Directory $starshipDir

$sourceStarship = Join-Path $winRoot ".starship\starship.toml"
if (Test-Path $sourceStarship) {
    Copy-Item $sourceStarship $starshipConfig -Force
    Write-Ok "Starship config deployed → $starshipConfig"
} else {
    Write-Warn "Starship config not found in repo; writing a sensible default."
    @'
add_newline = true
format = """
[╭╴](238)$env_var$all[╰─](238)$character"""

[character]
success_symbol = "[](238)"
error_symbol   = "[](238)"

[env_var.STARSHIP_DISTRO]
format   = "[$env_value](bold white)"
variable = "STARSHIP_DISTRO"
disabled = false

[directory]
truncation_length  = 3
truncation_symbol  = "…/"
home_symbol        = " ~"
read_only          = "  "
read_only_style    = "197"
format             = "at [$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol = " "
format = "on [$symbol$branch]($style) "

[git_status]
format = '[\($all_status$ahead_behind\)]($style) '
style  = "bold green"
'@ | Set-Content $starshipConfig -Encoding UTF8
    Write-Ok "Default Starship config written."
}

# ── 2c. Windows Terminal settings ───────────────────────────
$wtSettingsDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if (-not (Test-Path $wtSettingsDir)) {
    # Preview / Canary paths
    $wtSettingsDir = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if ($wtSettingsDir) {
    Ensure-Directory $wtSettingsDir
    $sourceWTSettings = Join-Path $winRoot "WindowsTerminal\settings.json"
    if (Test-Path $sourceWTSettings) {
        $destWT = Join-Path $wtSettingsDir "settings.json"
        # Back up existing settings
        if (Test-Path $destWT) {
            Copy-Item $destWT "$destWT.bak" -Force
            Write-Ok "Existing WT settings backed up → settings.json.bak"
        }
        Copy-Item $sourceWTSettings $destWT -Force
        Write-Ok "Windows Terminal settings deployed → $destWT"
    }
} else {
    Write-Warn "Windows Terminal settings directory not found. Open WT once, then re-run."
}

# ── 2d. Neofetch config ──────────────────────────────────────
$neofetchCfgDir = "$HOME\.config\neofetch"
Ensure-Directory $neofetchCfgDir

$sourceNeofetch = Join-Path $extractedRoot ".config\neofetch\config.conf"
if (Test-Path $sourceNeofetch) {
    Copy-Item $sourceNeofetch "$neofetchCfgDir\config.conf" -Force
    $tdlAscii = Join-Path $extractedRoot ".config\neofetch\thedigitallife.txt"
    if (Test-Path $tdlAscii) {
        Copy-Item $tdlAscii "$neofetchCfgDir\thedigitallife.txt" -Force
    }
    Write-Ok "Neofetch config deployed."
}

# ─────────────────────────────────────────────────────────────
#  3. Dark mode (system + apps)
# ─────────────────────────────────────────────────────────────
Write-Step "Enabling Windows 11 dark mode"

$personalizeKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"

Set-ItemProperty -Path $personalizeKey -Name "AppsUseLightTheme"   -Value 0 -Type DWord -Force
Set-ItemProperty -Path $personalizeKey -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force
Write-Ok "Dark mode enabled for apps and system UI."

# ─────────────────────────────────────────────────────────────
#  4. Mr. Robot wallpaper
# ─────────────────────────────────────────────────────────────
Write-Step "Downloading and setting Mr. Robot wallpaper"

$wallpaperDir  = "$HOME\Pictures\Wallpapers"
$wallpaperPath = "$wallpaperDir\mr-robot-wallpaper.png"
Ensure-Directory $wallpaperDir

$wallpaperUrl = "https://raw.githubusercontent.com/ChristianLempa/hackbox/main/src/assets/mr-robot-wallpaper.png"

try {
    Invoke-WebRequest -Uri $wallpaperUrl -OutFile $wallpaperPath -UseBasicParsing
    Write-Ok "Wallpaper downloaded → $wallpaperPath"
} catch {
    Write-Warn "Could not download wallpaper from GitHub. Trying alternate URL…"
    $altUrl = "https://github.com/ChristianLempa/hackbox/raw/main/src/assets/mr-robot-wallpaper.png"
    Invoke-WebRequest -Uri $altUrl -OutFile $wallpaperPath -UseBasicParsing
    Write-Ok "Wallpaper downloaded (alt) → $wallpaperPath"
}

# Apply via SystemParametersInfo (SPI_SETDESKWALLPAPER = 0x0014)
Add-Type @'
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(
        int uAction, int uParam, string lpvParam, int fuWinIni);

    public const int SPI_SETDESKWALLPAPER = 0x0014;
    public const int SPIF_UPDATEINIFILE   = 0x01;
    public const int SPIF_SENDCHANGE      = 0x02;

    public static void Set(string path) {
        SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, path,
            SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
    }
}
'@

[Wallpaper]::Set($wallpaperPath)

# Also write the registry key so it persists after reboots
$desktopKey = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $desktopKey -Name "Wallpaper"      -Value $wallpaperPath -Force
Set-ItemProperty -Path $desktopKey -Name "WallpaperStyle" -Value "10" -Force   # 10 = fill
Set-ItemProperty -Path $desktopKey -Name "TileWallpaper"  -Value "0"  -Force

Write-Ok "Wallpaper applied (fill mode)."

# ─────────────────────────────────────────────────────────────
#  5. Refresh the desktop
# ─────────────────────────────────────────────────────────────
Write-Step "Refreshing desktop / Explorer"
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer

# ─────────────────────────────────────────────────────────────
#  6. Clean up
# ─────────────────────────────────────────────────────────────
Remove-Item $tmpZip  -Force -ErrorAction SilentlyContinue
Remove-Item $tmpDir  -Recurse -Force -ErrorAction SilentlyContinue

# ─────────────────────────────────────────────────────────────
#  Done
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "  ✔  Setup complete!  Restart your terminal to load" -ForegroundColor Green
Write-Host "     the new PowerShell profile and Starship prompt." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1. Open Windows Terminal — your xcad profile is active." -ForegroundColor Gray
Write-Host "  2. If the Hack Nerd Font wasn't found, change the font" -ForegroundColor Gray
Write-Host "     in WT settings to the installed Nerd Font." -ForegroundColor Gray
Write-Host "  3. Sign out / back in to see dark mode fully applied." -ForegroundColor Gray
Write-Host ""
