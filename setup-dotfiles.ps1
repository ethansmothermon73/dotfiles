#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 Dotfiles Setup Script - Christian Lempa style
    Inspired by: https://github.com/ChristianLempa/hackbox

.DESCRIPTION
    Sets up a complete Windows 11 developer environment including:
    - Dark mode system-wide
    - Mr. Robot wallpaper
    - PowerShell 7, Winget packages
    - Windows Terminal with xcad_tdl color scheme
    - Starship prompt
    - Nerd Fonts
    - WSL2 tools
    - PowerShell profile with aliases and functions

.NOTES
    Run from an elevated PowerShell session:
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\setup-dotfiles.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ╭──────────────────────────────────────────╮" -ForegroundColor DarkMagenta
    Write-Host "  │  $Title" -ForegroundColor Magenta
    Write-Host "  ╰──────────────────────────────────────────╯" -ForegroundColor DarkMagenta
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "  ➜  $Message" -ForegroundColor Cyan
}

function Write-Done {
    param([string]$Message)
    Write-Host "  ✔  $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  ⚠  $Message" -ForegroundColor Yellow
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )
    Write-Step "Installing $DisplayName..."
    winget install --id $PackageId --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
    Write-Done "$DisplayName installed (or already present)"
}

# ─────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────

Clear-Host
Write-Host @"

  ██╗  ██╗ █████╗  ██████╗██╗  ██╗██████╗  ██████╗ ██╗  ██╗
  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝
  ███████║███████║██║     █████╔╝ ██████╔╝██║   ██║ ╚███╔╝
  ██╔══██║██╔══██║██║     ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗
  ██║  ██║██║  ██║╚██████╗██║  ██╗██████╔╝╚██████╔╝██╔╝ ██╗
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝

   Windows 11 Dotfiles  |  Christian Lempa style
   github.com/ChristianLempa/hackbox

"@ -ForegroundColor Magenta

# ─────────────────────────────────────────────
#  STEP 1 — DARK MODE
# ─────────────────────────────────────────────

Write-Header "1/8  Dark Mode"

Write-Step "Enabling Windows dark mode (apps + system)..."
$personalizePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-ItemProperty -Path $personalizePath -Name "AppsUseLightTheme"   -Value 0 -Type DWord
Set-ItemProperty -Path $personalizePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord
Write-Done "Dark mode enabled"

Write-Step "Disabling transparency effects..."
Set-ItemProperty -Path $personalizePath -Name "EnableTransparency" -Value 0 -Type DWord
Write-Done "Transparency disabled"

Write-Step "Setting accent color to purple (matching xcad_tdl theme)..."
$dwmPath = "HKCU:\SOFTWARE\Microsoft\Windows\DWM"
Set-ItemProperty -Path $dwmPath -Name "AccentColor"             -Value 0xFF2B4FFF -Type DWord
Set-ItemProperty -Path $dwmPath -Name "ColorizationColor"       -Value 0xC42B4FFF -Type DWord
Set-ItemProperty -Path $dwmPath -Name "ColorPrevalence"         -Value 1          -Type DWord
Set-ItemProperty -Path $dwmPath -Name "EnableWindowColorization" -Value 1         -Type DWord
Write-Done "Accent color set"

# ─────────────────────────────────────────────
#  STEP 2 — MR. ROBOT WALLPAPER
# ─────────────────────────────────────────────

Write-Header "2/8  Mr. Robot Wallpaper"

$wallpaperDir  = "$HOME\Pictures\Wallpapers"
$wallpaperPath = "$wallpaperDir\mr-robot-wallpaper.png"
$wallpaperUrl  = "https://raw.githubusercontent.com/ChristianLempa/hackbox/main/src/assets/mr-robot-wallpaper.png"

if (-not (Test-Path $wallpaperDir)) {
    New-Item -ItemType Directory -Path $wallpaperDir -Force | Out-Null
}

Write-Step "Downloading Mr. Robot wallpaper..."
try {
    Invoke-WebRequest -Uri $wallpaperUrl -OutFile $wallpaperPath -UseBasicParsing
    Write-Done "Wallpaper downloaded to $wallpaperPath"
} catch {
    Write-Warn "Could not download wallpaper automatically. Please place it manually at:"
    Write-Warn "  $wallpaperPath"
    Write-Warn "  URL: $wallpaperUrl"
}

Write-Step "Applying wallpaper..."
if (Test-Path $wallpaperPath) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public static void Set(string path) {
        SystemParametersInfo(0x0014, 0, path, 0x01 | 0x02);
    }
}
"@
    [Wallpaper]::Set($wallpaperPath)
    Write-Done "Wallpaper applied"
} else {
    Write-Warn "Wallpaper file not found — skipping apply step"
}

# ─────────────────────────────────────────────
#  STEP 3 — WINGET PACKAGES
# ─────────────────────────────────────────────

Write-Header "3/8  Core Packages (winget)"

if (-not (Test-CommandExists "winget")) {
    Write-Warn "winget not found. Install App Installer from the Microsoft Store and re-run."
} else {
    # Developer tools
    Install-WingetPackage "Microsoft.PowerShell"        "PowerShell 7"
    Install-WingetPackage "Microsoft.WindowsTerminal"   "Windows Terminal"
    Install-WingetPackage "Microsoft.VisualStudioCode"  "VS Code"
    Install-WingetPackage "Git.Git"                     "Git"
    Install-WingetPackage "GitHub.cli"                  "GitHub CLI"
    Install-WingetPackage "Starship.Starship"           "Starship Prompt"
    Install-WingetPackage "sharkdp.bat"                 "bat (cat with syntax highlight)"
    Install-WingetPackage "sharkdp.fd"                  "fd (fast find)"
    Install-WingetPackage "BurntSushi.ripgrep.MSVC"     "ripgrep"
    Install-WingetPackage "junegunn.fzf"                "fzf"
    Install-WingetPackage "ajeetdsouza.zoxide"          "zoxide (smart cd)"
    Install-WingetPackage "eza-community.eza"           "eza (modern ls)"
    Install-WingetPackage "Neovim.Neovim"               "Neovim"
    Install-WingetPackage "OpenJS.NodeJS.LTS"           "Node.js LTS"
    Install-WingetPackage "Python.Python.3.12"          "Python 3.12"
    Install-WingetPackage "Docker.DockerDesktop"        "Docker Desktop"
    Install-WingetPackage "Kubernetes.kubectl"          "kubectl"
    Install-WingetPackage "Helm.Helm"                   "Helm"

    # Terminals / Shells
    Install-WingetPackage "Canonical.Ubuntu.2204"       "Ubuntu 22.04 (WSL)"

    # Apps
    Install-WingetPackage "Mozilla.Firefox"             "Firefox"
    Install-WingetPackage "Obsidian.Obsidian"           "Obsidian"
    Install-WingetPackage "Spotify.Spotify"             "Spotify"
}

# ─────────────────────────────────────────────
#  STEP 4 — NERD FONTS
# ─────────────────────────────────────────────

Write-Header "4/8  Nerd Fonts (Hack + AnonymicePro)"

function Install-NerdFont {
    param([string]$FontName, [string]$FileName)
    Write-Step "Downloading $FontName Nerd Font..."
    $fontUrl  = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$FileName"
    $tempDir  = "$env:TEMP\NerdFonts\$FontName"
    $zipPath  = "$tempDir\$FileName"

    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $fontUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

        $fontsFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
        Get-ChildItem -Path $tempDir -Include "*.ttf","*.otf" -Recurse | ForEach-Object {
            if (-not (Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                $fontsFolder.CopyHere($_.FullName, 0x10)
            }
        }
        Write-Done "$FontName installed"
    } catch {
        Write-Warn "Could not auto-install $FontName — download manually from: https://www.nerdfonts.com/font-downloads"
    }
}

Install-NerdFont "Hack"         "Hack.zip"
Install-NerdFont "AnonymicePro" "AnonymicePro.zip"

# ─────────────────────────────────────────────
#  STEP 5 — STARSHIP CONFIG
# ─────────────────────────────────────────────

Write-Header "5/8  Starship Prompt Config"

$starshipDir    = "$HOME\.starship"
$starshipConfig = "$starshipDir\starship.toml"

New-Item -ItemType Directory -Path $starshipDir -Force | Out-Null

Write-Step "Writing starship.toml (xcad / TheDigitalLife style)..."
@'
# ~/.starship/starship.toml
# Christian Lempa / TheDigitalLife style

add_newline = true

format = """\
[╭╴](238)$env_var\
$all[╰─](238)$character"""

[character]
success_symbol = "[](238)"
error_symbol   = "[](238)"

[env_var.STARSHIP_DISTRO]
format   = '[$env_value](bold white)'
variable = "STARSHIP_DISTRO"
disabled = false

[username]
style_user   = "white bold"
style_root   = "black bold"
format       = "[$user]($style) "
disabled     = true
show_always  = false

[directory]
truncation_length  = 3
truncation_symbol  = "…/"
home_symbol        = " ~"
read_only_style    = "197"
read_only          = "  "
format             = "at [$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol             = " "
format             = "on [$symbol$branch]($style) "
truncation_length  = 4
truncation_symbol  = "…/"
style              = "bold green"

[git_status]
format      = '[\($all_status$ahead_behind\)]($style) '
style       = "bold green"
conflicted  = "🏳"
up_to_date  = " "
untracked   = " "
ahead       = "⇡${count}"
diverged    = "⇕⇡${ahead_count}⇣${behind_count}"
behind      = "⇣${count}"
stashed     = " "
modified    = " "
staged      = '[++\($count\)](green)'
renamed     = "襁 "
deleted     = " "

[terraform]
format = "via [ terraform $version]($style) 壟 [$workspace]($style) "

[vagrant]
format = "via [ vagrant $version]($style) "

[docker_context]
format = "via [ $context](bold blue) "

[helm]
format = "via [ $version](bold purple) "

[python]
symbol        = " "
python_binary = "python3"

[nodejs]
format   = "via [ $version](bold green) "
disabled = true

[ruby]
format = "via [ $version]($style) "

[kubernetes]
format   = 'on [ $context\($namespace\)](bold purple) '
disabled = false

[kubernetes.context_aliases]
"clcreative-k8s-staging"    = "cl-k8s-staging"
"clcreative-k8s-production" = "cl-k8s-prod"
'@ | Set-Content -Path $starshipConfig -Encoding UTF8

Write-Done "Starship config written to $starshipConfig"

# ─────────────────────────────────────────────
#  STEP 6 — POWERSHELL PROFILE
# ─────────────────────────────────────────────

Write-Header "6/8  PowerShell 7 Profile"

$pwshProfileDir = Split-Path $PROFILE -Parent
$pwshProfile    = $PROFILE

# Ensure the directory exists (works even if PowerShell 7 isn't default yet)
$pwsh7ProfileDir = "$HOME\Documents\PowerShell"
$pwsh7Profile    = "$pwsh7ProfileDir\Microsoft.PowerShell_profile.ps1"

New-Item -ItemType Directory -Path $pwsh7ProfileDir -Force | Out-Null

Write-Step "Writing PowerShell profile..."
@'
# ─────────────────────────────────────────────────────────
#  PowerShell Profile  |  Christian Lempa / TheDigitalLife
# ─────────────────────────────────────────────────────────

# Environment
$ENV:STARSHIP_CONFIG  = "$HOME\.starship\starship.toml"
$ENV:STARSHIP_DISTRO  = "者  $env:USERNAME"

# Aliases
New-Alias -Name k    -Value kubectl           -Force -ErrorAction SilentlyContinue
New-Alias -Name g    -Value goto              -Force -ErrorAction SilentlyContinue
New-Alias -Name vi   -Value nvim              -Force -ErrorAction SilentlyContinue
New-Alias -Name cat  -Value bat               -Force -ErrorAction SilentlyContinue
New-Alias -Name ls   -Value eza               -Force -ErrorAction SilentlyContinue
New-Alias -Name grep -Value rg                -Force -ErrorAction SilentlyContinue
New-Alias -Name find -Value fd                -Force -ErrorAction SilentlyContinue

try { Remove-Alias -Name h -ErrorAction Stop } catch {}
New-Alias -Name h    -Value helm              -Force -ErrorAction SilentlyContinue

# ── goto: quick directory navigation ─────────────────────
function goto {
    param([string]$location)
    switch ($location) {
        "pr"  { Set-Location "$HOME\projects" }
        "bp"  { Set-Location "$HOME\projects\boilerplates" }
        "cs"  { Set-Location "$HOME\projects\cheat-sheets" }
        "dl"  { Set-Location "$HOME\Downloads" }
        "dt"  { Set-Location "$HOME\Desktop" }
        "dot" { Set-Location "$HOME\.dotfiles" }
        default { Write-Warning "Unknown location '$location'. Available: pr, bp, cs, dl, dt, dot" }
    }
}

# ── kn: kubectl namespace switcher ───────────────────────
function kn {
    param([string]$namespace)
    if ($namespace -in "default", "d") {
        kubectl config set-context --current --namespace=default
    } else {
        kubectl config set-context --current --namespace=$namespace
    }
}

# ── mkcd: mkdir + cd ─────────────────────────────────────
function mkcd {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

# ── which: locate an executable ──────────────────────────
function which {
    param([string]$Command)
    Get-Command $Command | Select-Object -ExpandProperty Source
}

# ── reload: re-source the profile ────────────────────────
function reload {
    . $PROFILE
    Write-Host "Profile reloaded." -ForegroundColor Green
}

# ── uptime: system uptime ────────────────────────────────
function uptime {
    $os = Get-WmiObject Win32_OperatingSystem
    $uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
    Write-Host "Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Cyan
}

# ── psef: grep running processes ─────────────────────────
function psef {
    param([string]$Name)
    Get-Process | Where-Object { $_.Name -like "*$Name*" } | Select-Object Id, Name, CPU, WorkingSet
}

# ── Docker helpers ────────────────────────────────────────
function dps  { docker ps $args }
function dpsa { docker ps -a $args }
function dimg { docker images $args }
function dexec {
    param([string]$Container, [string]$Shell = "sh")
    docker exec -it $Container $Shell
}
function dlogs {
    param([string]$Container)
    docker logs -f $Container
}

# ── Git helpers ───────────────────────────────────────────
function gs   { git status }
function ga   { git add $args }
function gc   { git commit -m $args }
function gp   { git push $args }
function gpl  { git pull $args }
function glog { git log --oneline --graph --decorate --all }
function gco  { git checkout $args }
function gcob { git checkout -b $args }

# ── eza: enhanced ls variants ────────────────────────────
function ll  { eza -la --icons $args }
function la  { eza -a  --icons $args }
function lt  { eza --tree --level=2 --icons $args }

# ── zoxide init ──────────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ── fzf keybindings ──────────────────────────────────────
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $ENV:FZF_DEFAULT_OPTS = "--color=fg:#f8f8f2,bg:#1a1a1a,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#2b2b2b,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
}

# ── neofetch on start (optional, comment out if slow) ────
# if (Get-Command neofetch -ErrorAction SilentlyContinue) { neofetch }

# ── Starship init ─────────────────────────────────────────
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
'@ | Set-Content -Path $pwsh7Profile -Encoding UTF8

Write-Done "PowerShell profile written to $pwsh7Profile"

# ─────────────────────────────────────────────
#  STEP 7 — WINDOWS TERMINAL CONFIG
# ─────────────────────────────────────────────

Write-Header "7/8  Windows Terminal Settings"

$wtSettingsDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"

if (Test-Path $wtSettingsDir) {
    $wtSettings = "$wtSettingsDir\settings.json"
    Write-Step "Writing Windows Terminal settings..."

    @'
{
    "$help": "https://aka.ms/terminal-documentation",
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "actions": [],
    "alwaysShowNotificationIcon": false,
    "defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
    "firstWindowPreference": "defaultProfile",
    "profiles": {
        "defaults": {
            "colorScheme": "xcad_tdl",
            "font": {
                "face": "Hack Nerd Font",
                "size": 14
            },
            "historySize": 12000,
            "opacity": 92,
            "scrollbarState": "visible",
            "useAcrylic": false,
            "backgroundImage": "%USERPROFILE%\\Pictures\\Wallpapers\\mr-robot-wallpaper.png",
            "backgroundImageOpacity": 0.08,
            "backgroundImageStretchMode": "uniformToFill",
            "cursorShape": "bar"
        },
        "list": [
            {
                "commandline": "C:\\Program Files\\PowerShell\\7\\pwsh.exe --NoLogo",
                "guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
                "hidden": false,
                "icon": "%userprofile%\\WindowsTerminalIcons\\ps.png",
                "name": "PowerShell 7",
                "source": "Windows.Terminal.PowershellCore",
                "startingDirectory": "%USERPROFILE%"
            },
            {
                "guid": "{07b52e3e-de2c-5db4-bd2d-ba144ed6c273}",
                "hidden": false,
                "name": "Ubuntu Linux",
                "source": "Windows.Terminal.Wsl",
                "startingDirectory": "~"
            },
            {
                "commandline": "cmd.exe",
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "name": "Command Prompt"
            }
        ]
    },
    "schemes": [
        {
            "background": "#1A1A1A",
            "black": "#121212",
            "blue": "#2B4FFF",
            "brightBlack": "#2F2F2F",
            "brightBlue": "#5C78FF",
            "brightCyan": "#5AC8FF",
            "brightGreen": "#905AFF",
            "brightPurple": "#5EA2FF",
            "brightRed": "#BA5AFF",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#685AFF",
            "cursorColor": "#FFFFFF",
            "cyan": "#28B9FF",
            "foreground": "#F1F1F1",
            "green": "#7129FF",
            "name": "xcad_tdl",
            "purple": "#2883FF",
            "red": "#A52AFF",
            "selectionBackground": "#FFFFFF",
            "white": "#F1F1F1",
            "yellow": "#3D2AFF"
        },
        {
            "background": "#111927",
            "black": "#000000",
            "blue": "#004CFF",
            "brightBlack": "#666666",
            "brightBlue": "#5CB2FF",
            "brightCyan": "#5CECC6",
            "brightGreen": "#C5F467",
            "brightPurple": "#AE81FF",
            "brightRed": "#FF8484",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#FFCC5C",
            "cursorColor": "#FFFFFF",
            "cyan": "#2EE7B6",
            "foreground": "#D4D4D4",
            "green": "#9FEF00",
            "name": "xcad_hackthebox",
            "purple": "#BC3FBC",
            "red": "#FF3E3E",
            "selectionBackground": "#FFFFFF",
            "white": "#FFFFFF",
            "yellow": "#FFAF00"
        },
        {
            "background": "#0F0F0F",
            "black": "#000000",
            "blue": "#2878FF",
            "brightBlack": "#2F2F2F",
            "brightBlue": "#5E99FF",
            "brightCyan": "#5AD6FF",
            "brightGreen": "#FFB15A",
            "brightPurple": "#935CFF",
            "brightRed": "#FF755A",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#FFD25A",
            "cursorColor": "#FFFFFF",
            "cyan": "#28C8FF",
            "foreground": "#F1F1F1",
            "green": "#FF9A28",
            "name": "xcad_tdl_colorful",
            "purple": "#732BFF",
            "red": "#FF4C27",
            "selectionBackground": "#FFFFFF",
            "white": "#F1F1F1",
            "yellow": "#FFC72A"
        }
    ],
    "showTabsInTitlebar": true,
    "tabSwitcherMode": "inOrder",
    "useAcrylicInTabRow": true
}
'@ | Set-Content -Path $wtSettings -Encoding UTF8

    Write-Done "Windows Terminal settings written"
} else {
    Write-Warn "Windows Terminal not found at expected path. Install it first, then re-run step 7."
}

# ─────────────────────────────────────────────
#  STEP 8 — WINDOWS 11 TWEAKS
# ─────────────────────────────────────────────

Write-Header "8/8  Windows 11 Tweaks"

Write-Step "Showing file extensions in Explorer..."
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "HideFileExt" -Value 0 -Type DWord
Write-Done "File extensions visible"

Write-Step "Showing hidden files..."
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Hidden" -Value 1 -Type DWord
Write-Done "Hidden files visible"

Write-Step "Disabling Bing search in Start Menu..."
$searchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
if (-not (Test-Path $searchPath)) { New-Item -Path $searchPath -Force | Out-Null }
Set-ItemProperty -Path $searchPath -Name "BingSearchEnabled" -Value 0 -Type DWord
Write-Done "Bing search disabled"

Write-Step "Setting taskbar to left alignment..."
$taskbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $taskbarPath -Name "TaskbarAl" -Value 0 -Type DWord
Write-Done "Taskbar aligned left"

Write-Step "Disabling taskbar widgets..."
$widgetsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $widgetsPath -Name "TaskbarDa" -Value 0 -Type DWord
Write-Done "Widgets disabled"

Write-Step "Disabling Cortana..."
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force | Out-Null }
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord
Write-Done "Cortana disabled"

Write-Step "Enabling WSL2..."
try {
    wsl --set-default-version 2 2>&1 | Out-Null
    Write-Done "WSL2 set as default"
} catch {
    Write-Warn "WSL2 could not be configured. Enable it manually: wsl --set-default-version 2"
}

Write-Step "Restarting Explorer to apply taskbar changes..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# ─────────────────────────────────────────────
#  DONE
# ─────────────────────────────────────────────

Write-Host ""
Write-Host "  ╭───────────────────────────────────────────────────╮" -ForegroundColor DarkGreen
Write-Host "  │                                                   │" -ForegroundColor DarkGreen
Write-Host "  │   ✔  Setup complete! A few things to do next:    │" -ForegroundColor Green
Write-Host "  │                                                   │" -ForegroundColor DarkGreen
Write-Host "  │   1. Open Windows Terminal → PowerShell 7        │" -ForegroundColor Cyan
Write-Host "  │   2. Verify: starship, eza, zoxide, fzf, bat     │" -ForegroundColor Cyan
Write-Host "  │   3. Reboot recommended to apply all tweaks      │" -ForegroundColor Cyan
Write-Host "  │   4. Set Hack Nerd Font in Windows Terminal       │" -ForegroundColor Cyan
Write-Host "  │   5. Run: wsl --install -d Ubuntu-22.04          │" -ForegroundColor Cyan
Write-Host "  │                                                   │" -ForegroundColor DarkGreen
Write-Host "  ╰───────────────────────────────────────────────────╯" -ForegroundColor DarkGreen
Write-Host ""
