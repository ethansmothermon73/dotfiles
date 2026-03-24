#Requires -Version 7
<#
.SYNOPSIS
    Installs christianlempa/dotfiles-win on your Windows PC.

.DESCRIPTION
    This script automates the full setup of christianlempa's Windows dotfiles:
      - Installs Scoop (package manager)
      - Installs Starship prompt, PowerShell 7, and Windows Terminal via Scoop/winget
      - Installs Hack Nerd Font
      - Copies the PowerShell profile (with kubectl, helm, starship, datree completions)
      - Copies starship.toml
      - Copies Windows Terminal settings.json + xcad color theme
      - Downloads terminal tab icons from github.com/ethansmothermon73/win-terminal-icons
      - Downloads the Mr. Robot wallpaper from github.com/ChristianLempa/hackbox
      - Sets the wallpaper as your Windows desktop background
      - Enables Windows 11 dark mode (apps + system UI)

.NOTES
    Run from the root of the dotfiles-win repository:
        cd dotfiles-win-main
        .\Install-Dotfiles.ps1

    Flags:
        -ConfigOnly   Skip all tool installs; only copy/download config files
        -Force        Overwrite existing files without prompting
        -DotfilesRoot "C:\other\path"   Use a different source folder
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DotfilesRoot = $PSScriptRoot,
    [switch]$ConfigOnly,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Helpers ─────────────────────────────────────────────────────────────────

function Write-Step ([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}
function Write-OK ([string]$Message) {
    Write-Host "    [OK] $Message" -ForegroundColor Green
}
function Write-Warn ([string]$Message) {
    Write-Host "    [!!] $Message" -ForegroundColor Yellow
}
function Write-Fail ([string]$Message) {
    Write-Host "    [XX] $Message" -ForegroundColor Red
}

function Confirm-Overwrite ([string]$Path) {
    if (-not (Test-Path $Path)) { return $true }
    if ($Force) { return $true }
    $answer = Read-Host "    '$Path' already exists. Overwrite? [y/N]"
    return ($answer -match '^[yY]$')
}

function Install-WithScoop ([string]$Package) {
    if (Get-Command $Package -ErrorAction SilentlyContinue) {
        Write-OK "$Package already installed – skipping."
        return
    }
    Write-Host "    Installing $Package via Scoop..." -ForegroundColor Gray
    scoop install $Package
}

function Safe-Copy ([string]$Source, [string]$Destination) {
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Confirm-Overwrite $Destination) {
        Copy-Item -Path $Source -Destination $Destination -Force
        Write-OK "Copied  $Source  ->  $Destination"
    } else {
        Write-Warn "Skipped $Destination"
    }
}

function Download-File ([string]$Url, [string]$Destination) {
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Confirm-Overwrite $Destination) {
        Write-Host "    Downloading $(Split-Path $Destination -Leaf) ..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        Write-OK "Saved -> $Destination"
    } else {
        Write-Warn "Skipped $Destination"
    }
}

# ─── Validate source tree ────────────────────────────────────────────────────

Write-Step "Validating dotfiles source at: $DotfilesRoot"

$requiredFiles = @(
    ".pwsh\Microsoft.PowerShell_profile.ps1",
    ".starship\starship.toml",
    "windows-terminal-settings.json",
    "files-theme-xcad.xaml"
)

foreach ($rel in $requiredFiles) {
    $full = Join-Path $DotfilesRoot $rel
    if (-not (Test-Path $full)) {
        Write-Fail "Missing expected file: $full"
        Write-Host "    Make sure you run this script from inside the dotfiles-win-main folder." -ForegroundColor Red
        exit 1
    }
}

Write-OK "All source files found."

# ─── 1. Package manager & tools ──────────────────────────────────────────────

if (-not $ConfigOnly) {

    Write-Step "Step 1 - Installing Scoop (package manager)"
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-OK "Scoop is already installed."
    } else {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        Write-OK "Scoop installed."
    }

    Write-Step "Step 2 - Adding Scoop buckets"
    foreach ($bucket in @('extras', 'nerd-fonts')) {
        $existing = scoop bucket list 2>$null | Select-String $bucket
        if ($existing) {
            Write-OK "Bucket '$bucket' already added."
        } else {
            scoop bucket add $bucket
            Write-OK "Added bucket: $bucket"
        }
    }

    Write-Step "Step 3 - Installing core tools via Scoop"
    foreach ($pkg in @('starship', 'git')) {
        Install-WithScoop $pkg
    }

    Write-Step "Step 4 - Installing Hack Nerd Font"
    $fontCheck = (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue).PSObject.Properties |
                 Where-Object { $_.Value -match 'Hack' }
    if ($fontCheck) {
        Write-OK "Hack Nerd Font appears to already be installed."
    } else {
        scoop install Hack-NF
        Write-OK "Hack Nerd Font installed."
    }

    Write-Step "Step 5 - Installing PowerShell 7 (pwsh) via winget"
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-OK "PowerShell 7 is already installed."
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        Write-OK "PowerShell 7 installed."
    } else {
        Write-Warn "winget not found. Install PS7 from: https://github.com/PowerShell/PowerShell/releases"
    }

    Write-Step "Step 6 - Installing Windows Terminal via winget"
    if (Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue) {
        Write-OK "Windows Terminal is already installed."
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Microsoft.WindowsTerminal --source winget --silent --accept-package-agreements --accept-source-agreements
        Write-OK "Windows Terminal installed."
    } else {
        Write-Warn "winget not found. Install Windows Terminal from the Microsoft Store."
    }

    Write-Step "Step 7 - Installing kubectl and helm (used in PS profile aliases)"
    Install-WithScoop 'kubectl'
    Install-WithScoop 'helm'

} else {
    Write-Warn "-ConfigOnly set: skipping all tool installations."
}

# ─── 2. PowerShell profile ───────────────────────────────────────────────────

Write-Step "Step 8 - Installing PowerShell profile"
Safe-Copy `
    (Join-Path $DotfilesRoot ".pwsh\Microsoft.PowerShell_profile.ps1") `
    $PROFILE.CurrentUserCurrentHost

# ─── 3. Starship config ──────────────────────────────────────────────────────

Write-Step "Step 9 - Installing Starship config (starship.toml)"
$starshipDest = Join-Path $HOME ".starship\starship.toml"
Safe-Copy (Join-Path $DotfilesRoot ".starship\starship.toml") $starshipDest
$ENV:STARSHIP_CONFIG = $starshipDest
Write-OK "STARSHIP_CONFIG set to $starshipDest (current session)"

# ─── 4. Windows Terminal settings ────────────────────────────────────────────

Write-Step "Step 10 - Installing Windows Terminal settings.json"

$wtLocalPath   = Join-Path $ENV:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$wtPreviewPath = Join-Path $ENV:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"
$wtSettingsSrc = Join-Path $DotfilesRoot "windows-terminal-settings.json"

$installedWT = $false
foreach ($wtPath in @($wtLocalPath, $wtPreviewPath)) {
    if (Test-Path $wtPath) {
        Safe-Copy $wtSettingsSrc (Join-Path $wtPath "settings.json")
        $installedWT = $true
    }
}
if (-not $installedWT) {
    Write-Warn "Windows Terminal LocalState folder not found. Install Windows Terminal first, then re-run."
}

# ─── 5. xcad color theme ─────────────────────────────────────────────────────

Write-Step "Step 11 - Copying xcad Windows Terminal theme (files-theme-xcad.xaml)"
$xamlSrc = Join-Path $DotfilesRoot "files-theme-xcad.xaml"
if ($installedWT) {
    foreach ($wtPath in @($wtLocalPath, $wtPreviewPath)) {
        if (Test-Path $wtPath) {
            Safe-Copy $xamlSrc (Join-Path $wtPath "files-theme-xcad.xaml")
        }
    }
} else {
    Write-Warn "Skipped XAML copy - Windows Terminal folder not found."
}

# ─── 6. Terminal tab icons ───────────────────────────────────────────────────

Write-Step "Step 12 - Downloading Windows Terminal tab icons"
<#
  Source repo: https://github.com/ethansmothermon73/win-terminal-icons
  The repo filenames are mapped to the short names expected by settings.json:

    icons8-powershell-32.png           -> ps.png
    icons8-ubuntu-32 (1).png           -> ubuntu.png
    icons8-fsociety-mask-32 (1).png    -> kali.png   (used for the Kali Linux profile)
    icons8-cmd-32.png                  -> cmd.png
    icons8-azure-32.png                -> azure.png
#>

$iconsDir  = Join-Path $HOME "WindowsTerminalIcons"
$iconsBase = "https://raw.githubusercontent.com/ethansmothermon73/win-terminal-icons/main"

$iconMap = @(
    @{ Url = "$iconsBase/icons8-powershell-32.png";            Dest = "ps.png"     },
    @{ Url = "$iconsBase/icons8-ubuntu-32%20(1).png";          Dest = "ubuntu.png" },
    @{ Url = "$iconsBase/icons8-fsociety-mask-32%20(1).png";   Dest = "kali.png"   },
    @{ Url = "$iconsBase/icons8-cmd-32.png";                   Dest = "cmd.png"    },
    @{ Url = "$iconsBase/icons8-azure-32.png";                 Dest = "azure.png"  }
)

foreach ($icon in $iconMap) {
    $destPath = Join-Path $iconsDir $icon.Dest
    try {
        Download-File $icon.Url $destPath
    } catch {
        Write-Warn "Failed to download $($icon.Dest): $_"
        Write-Warn "Place it manually at: $destPath"
    }
}

Write-OK "Terminal icons saved to: $iconsDir"

# ─── 7. Mr. Robot wallpaper – download ───────────────────────────────────────

Write-Step "Step 13 - Downloading Mr. Robot wallpaper"
<#
  Source: https://github.com/ChristianLempa/hackbox (src/assets/mr-robot-wallpaper.png)
#>

$wallpaperDir  = Join-Path $HOME "Pictures\Wallpapers"
$wallpaperPath = Join-Path $wallpaperDir "mr-robot-wallpaper.png"
$wallpaperUrl  = "https://raw.githubusercontent.com/ChristianLempa/hackbox/main/src/assets/mr-robot-wallpaper.png"

try {
    Download-File $wallpaperUrl $wallpaperPath
} catch {
    Write-Warn "Could not download wallpaper: $_"
    Write-Warn "Download it manually from:"
    Write-Warn "  $wallpaperUrl"
    Write-Warn "Then right-click the file and choose 'Set as desktop background'."
}

# ─── 8. Apply wallpaper via Windows API ──────────────────────────────────────

Write-Step "Step 14 - Setting Mr. Robot wallpaper as desktop background"

if (Test-Path $wallpaperPath) {
    try {
        # Persist wallpaper path in registry so it survives reboots
        $regDesktop = 'HKCU:\Control Panel\Desktop'
        Set-ItemProperty -Path $regDesktop -Name Wallpaper      -Value $wallpaperPath
        Set-ItemProperty -Path $regDesktop -Name WallpaperStyle -Value '10'  # 10 = Fill
        Set-ItemProperty -Path $regDesktop -Name TileWallpaper  -Value '0'

        # Call user32 SystemParametersInfo to apply without a reboot
        # SPI_SETDESKWALLPAPER = 0x0014
        $apiSig = @'
[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
'@
        $apiType = Add-Type -MemberDefinition $apiSig -Name WinAPI -Namespace SetWallpaper -PassThru
        # SPIF_UPDATEINIFILE (0x01) | SPIF_SENDCHANGE (0x02) = 0x03
        $apiType::SystemParametersInfo(0x0014, 0, $wallpaperPath, 0x03) | Out-Null

        Write-OK "Wallpaper set: $wallpaperPath"
    } catch {
        Write-Warn "Could not apply wallpaper programmatically: $_"
        Write-Warn "Right-click $wallpaperPath and choose 'Set as desktop background'."
    }
} else {
    Write-Warn "Wallpaper file not found at $wallpaperPath – skipping apply step."
}

# ─── 9. Enable Windows 11 dark mode ──────────────────────────────────────────

Write-Step "Step 15 - Enabling Windows 11 dark mode"
<#
  Registry values under HKCU\...\Themes\Personalize:
    AppsUseLightTheme    = 0  ->  dark theme for all apps
    SystemUsesLightTheme = 0  ->  dark theme for taskbar, Start, action centre
#>

try {
    $personalizeKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme    -Value 0 -Type DWord
    Set-ItemProperty -Path $personalizeKey -Name SystemUsesLightTheme -Value 0 -Type DWord
    Write-OK "Registry updated: dark mode enabled."

    # Broadcast WM_SETTINGCHANGE so Explorer/shell picks up the change immediately
    # without requiring a sign-out
    $broadcastSig = @'
[DllImport("user32.dll", SetLastError = true)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam,
    string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    $broadcastType = Add-Type -MemberDefinition $broadcastSig `
                               -Name Shell32Broadcast -Namespace DarkMode -PassThru
    $result = [UIntPtr]::Zero
    # HWND_BROADCAST=0xFFFF, WM_SETTINGCHANGE=0x001A, SMTO_ABORTIFHUNG=0x0002
    $broadcastType::SendMessageTimeout(
        [IntPtr]0xFFFF, 0x001A, [UIntPtr]::Zero,
        "ImmersiveColorSet", 0x0002, 5000, [ref]$result
    ) | Out-Null

    Write-OK "Shell notified – dark mode should apply immediately."
} catch {
    Write-Warn "Could not apply dark mode automatically: $_"
    Write-Warn "Enable manually: Settings -> Personalization -> Colors -> Mode -> Dark"
}

# ─── 10. WSL starting directory reminder ─────────────────────────────────────

Write-Step "Step 16 - WSL profile note"
Write-Warn "The Windows Terminal settings.json has WSL profiles pointing to:"
Write-Warn "  Ubuntu:  \\wsl`$\Ubuntu-20.04\home\xcad"
Write-Warn "  Kali:    \\wsl.localhost\kali-linux\home\xcad"
Write-Warn "Edit settings.json to match your actual WSL distro name / username if different."

# ─── Done ────────────────────────────────────────────────────────────────────

$iconsDir = Join-Path $HOME "WindowsTerminalIcons"   # ensure var is in scope for summary

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  christianlempa/dotfiles-win installation complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  What was installed:" -ForegroundColor White
Write-Host "   [+] PowerShell profile" -ForegroundColor Gray
Write-Host "   [+] Starship config (starship.toml)" -ForegroundColor Gray
Write-Host "   [+] Windows Terminal settings.json + xcad theme" -ForegroundColor Gray
Write-Host "   [+] Tab icons -> $iconsDir" -ForegroundColor Gray
Write-Host "   [+] Mr. Robot wallpaper -> $wallpaperPath" -ForegroundColor Gray
Write-Host "   [+] Windows 11 dark mode enabled" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "   1. Restart PowerShell 7 (pwsh) to load the new profile." -ForegroundColor Gray
Write-Host "   2. Open Windows Terminal – xcad theme + tab icons should be active." -ForegroundColor Gray
Write-Host "   3. Adjust WSL starting directories in settings.json if needed." -ForegroundColor Gray
Write-Host "   4. If kubectl/helm are missing from PATH, reopen your shell." -ForegroundColor Gray
Write-Host ""
