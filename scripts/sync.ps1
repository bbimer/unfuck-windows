<#
.SYNOPSIS
    Syncs customization configs from repo to Windows user profile and reloads services.
#>
param(
    [switch]$NoReload,
    [switch]$Restart
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Write-Host "Syncing from repository: $repoRoot" -ForegroundColor Cyan

# 1. Komorebi
$komorebiDst = "$env:USERPROFILE\komorebi.json"
Copy-Item "$repoRoot\komorebi\komorebi.json" -Destination $komorebiDst -Force
Write-Host " [OK] Komorebi config synced -> $komorebiDst" -ForegroundColor Green

# 2. whkd
$whkdDst = "$env:USERPROFILE\.config\whkdrc"
if (-not (Test-Path "$env:USERPROFILE\.config")) {
    New-Item -ItemType Directory -Path "$env:USERPROFILE\.config" -Force | Out-Null
}
Copy-Item "$repoRoot\whkd\whkdrc" -Destination $whkdDst -Force
Write-Host " [OK] whkd config synced -> $whkdDst" -ForegroundColor Green

# 3. YASB
$yasbDstDir = "$env:USERPROFILE\.config\yasb"
if (-not (Test-Path $yasbDstDir)) {
    New-Item -ItemType Directory -Path $yasbDstDir -Force | Out-Null
}
Copy-Item "$repoRoot\yasb\config.yaml" -Destination "$yasbDstDir\config.yaml" -Force
Copy-Item "$repoRoot\yasb\styles.css" -Destination "$yasbDstDir\styles.css" -Force
Write-Host " [OK] YASB config & styles synced -> $yasbDstDir" -ForegroundColor Green

# 4. Windows Terminal
$wtDst = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path (Split-Path $wtDst)) {
    Copy-Item "$repoRoot\terminal\settings.json" -Destination $wtDst -Force
    Write-Host " [OK] Windows Terminal settings synced -> $wtDst" -ForegroundColor Green
}

# 5. PowerShell Profile
$psProfileDir = "$env:USERPROFILE\Documents\PowerShell"
if (-not (Test-Path $psProfileDir)) {
    New-Item -ItemType Directory -Path $psProfileDir -Force | Out-Null
}
Copy-Item "$repoRoot\powershell\Microsoft.PowerShell_profile.ps1" -Destination "$psProfileDir\Microsoft.PowerShell_profile.ps1" -Force
Write-Host " [OK] PowerShell profile synced -> $psProfileDir" -ForegroundColor Green

# 6. Fastfetch
$fastfetchDir = "$env:USERPROFILE\.config\fastfetch"
if (-not (Test-Path $fastfetchDir)) {
    New-Item -ItemType Directory -Path $fastfetchDir -Force | Out-Null
}
Copy-Item "$repoRoot\fastfetch\config.jsonc" -Destination "$fastfetchDir\config.jsonc" -Force
Copy-Item "$repoRoot\fastfetch\ascii.txt" -Destination "$fastfetchDir\ascii.txt" -Force
Copy-Item "$repoRoot\fastfetch\logo.jpg" -Destination "$fastfetchDir\logo.jpg" -Force -ErrorAction SilentlyContinue
Write-Host " [OK] Fastfetch config, ascii art & logo synced -> $fastfetchDir" -ForegroundColor Green

# 7. VS Code (Lunar Pink theme + Bunker icons)
$vscodeUserDir = "$env:APPDATA\Code\User"
if (-not (Test-Path $vscodeUserDir)) {
    New-Item -ItemType Directory -Path $vscodeUserDir -Force | Out-Null
}
$vscodeSettingsDst = "$vscodeUserDir\settings.json"
if (Test-Path $vscodeSettingsDst) {
    try {
        $currentJson = Get-Content $vscodeSettingsDst -Raw | ConvertFrom-Json
        $newJson = Get-Content "$repoRoot\vscode\settings.json" -Raw | ConvertFrom-Json
        foreach ($prop in $newJson.PSObject.Properties) {
            $currentJson | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
        }
        $currentJson | ConvertTo-Json -Depth 10 | Set-Content $vscodeSettingsDst -Encoding utf8
    } catch {
        Copy-Item "$repoRoot\vscode\settings.json" -Destination $vscodeSettingsDst -Force
    }
} else {
    Copy-Item "$repoRoot\vscode\settings.json" -Destination $vscodeSettingsDst -Force
}
Write-Host " [OK] VS Code settings & theme synced -> $vscodeSettingsDst" -ForegroundColor Green

# Install VS Code theme extensions if 'code' command is available
if (Get-Command code -ErrorAction SilentlyContinue) {
    $extensionsFile = "$repoRoot\vscode\extensions.txt"
    if (Test-Path $extensionsFile) {
        $extensions = Get-Content $extensionsFile | Where-Object { $_ -match '\S' }
        $origEA = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        foreach ($ext in $extensions) {
            code --install-extension $ext --force 2>$null | Out-Null
        }
        $ErrorActionPreference = $origEA
        Write-Host " [OK] VS Code theme extensions ensured (Lunar Pink & Bunker icons)" -ForegroundColor Green
    }
}

# 8. YouTube Music (Themes)
$ytmThemesDir = "$env:USERPROFILE\.config\youtube-music\themes"
if (-not (Test-Path $ytmThemesDir)) {
    New-Item -ItemType Directory -Path $ytmThemesDir -Force | Out-Null
}
Copy-Item "$repoRoot\youtube-music\themes\*" -Destination $ytmThemesDir -Force -ErrorAction SilentlyContinue
Write-Host " [OK] YouTube Music themes synced -> $ytmThemesDir" -ForegroundColor Green

$ytmAppDir = "$env:APPDATA\YouTube Music"
if (Test-Path "$repoRoot\youtube-music\config.json") {
    if (-not (Test-Path $ytmAppDir)) {
        New-Item -ItemType Directory -Path $ytmAppDir -Force | Out-Null
    }
    Copy-Item "$repoRoot\youtube-music\config.json" -Destination "$ytmAppDir\config.json" -Force
    Write-Host " [OK] YouTube Music config synced -> $ytmAppDir\config.json" -ForegroundColor Green
}

# 10. Desktop revive shortcut/batch file
$desktopDir = [Environment]::GetFolderPath("Desktop")
if (Test-Path "$repoRoot\scripts\revive.bat") {
    Copy-Item "$repoRoot\scripts\revive.bat" -Destination "$desktopDir\revive.bat" -Force
    Write-Host " [OK] Desktop revive.bat synced -> $desktopDir\revive.bat" -ForegroundColor Green
}

if ($NoReload) {
    Write-Host "Skipping reload as requested." -ForegroundColor Yellow
    exit 0
}

Write-Host "Applying Komorebi & whkd configuration..." -ForegroundColor Cyan

function Start-DetachedProcess {
    param([string]$CommandLine)
    $startup = New-CimInstance -ClassName Win32_ProcessStartup -Property @{ShowWindow = [uint16]0} -ClientOnly
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = $CommandLine; ProcessStartupInformation = $startup} | Out-Null
}

if ($Restart) {
    Write-Host "Performing full Komorebi & whkd restart..." -ForegroundColor Yellow
    komorebic stop --whkd
    Start-Sleep -Milliseconds 500
    $noConsole = "C:\Program Files\komorebi\bin\komorebic-no-console.exe"
    if (Test-Path $noConsole) {
        Start-DetachedProcess "`"$noConsole`" start --config `"$komorebiDst`" --whkd"
    } else {
        Start-DetachedProcess "komorebic.exe start --config `"$komorebiDst`" --whkd"
    }
    Start-Sleep -Milliseconds 800
    komorebic enforce-workspace-rules
    komorebic retile
    Write-Host " [OK] Komorebi & whkd full restart completed (headless & detached)" -ForegroundColor Green
} else {
    try {
        komorebic replace-configuration "$komorebiDst"
        Start-Sleep -Milliseconds 200
        komorebic enforce-workspace-rules
        komorebic retile
        Write-Host " [OK] Komorebi configuration replaced & workspace rules enforced" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to replace Komorebi configuration: $_"
    }

    try {
        Get-Process whkd -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Milliseconds 200
        $whkdPath = "C:\Program Files\whkd\bin\whkd.exe"
        if (Test-Path $whkdPath) {
            Start-DetachedProcess "`"$whkdPath`""
        } else {
            Start-DetachedProcess "whkd.exe"
        }
        Write-Host " [OK] whkd daemon restarted (detached & hidden)" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to restart whkd: $_"
    }
}

try {
    $komoState = komorebic state | ConvertFrom-Json
    if ($komoState.is_paused) {
        komorebic toggle-pause
        komorebic retile
        Write-Host " [OK] Komorebi unpaused & retiled" -ForegroundColor Green
    }
} catch {
    # Non-fatal if state query fails
}

# Reload or start YASB status bar
try {
    if (Get-Process yasb -ErrorAction SilentlyContinue) {
        Stop-Process -Name yasb -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
    }
    $yasbExe = "C:\Program Files\YASB\yasb.exe"
    if (Test-Path $yasbExe) {
        Start-DetachedProcess "`"$yasbExe`""
        Write-Host " [OK] YASB status bar restarted (detached)" -ForegroundColor Green
    }
} catch {
    Write-Warning "YASB restart failed: $_"
}

Write-Host "All configs applied successfully!" -ForegroundColor Green
