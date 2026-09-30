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

if ($NoReload) {
    Write-Host "Skipping reload as requested." -ForegroundColor Yellow
    exit 0
}

Write-Host "Applying Komorebi & whkd configuration..." -ForegroundColor Cyan

function Start-DetachedProcess {
    param([string]$CommandLine)
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = $CommandLine} | Out-Null
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
        Start-DetachedProcess "whkd.exe"
        Write-Host " [OK] whkd daemon restarted (detached from terminal)" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to restart whkd: $_"
    }
}

Write-Host "All configs applied successfully!" -ForegroundColor Green
