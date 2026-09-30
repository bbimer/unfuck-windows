<#
.SYNOPSIS
    Syncs customization configs from repo to Windows user profile and reloads services.
#>
param(
    [switch]$NoReload
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

Write-Host "Reloading Komorebi & whkd..." -ForegroundColor Cyan

# Reload Komorebi
try {
    komorebic reload-configuration
    komorebic retile
    Write-Host " [OK] Komorebi reloaded & retiled" -ForegroundColor Green
} catch {
    Write-Warning "Failed to reload Komorebi: $_"
}

# Reload whkd
try {
    Get-Process whkd -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 200
    Start-Process whkd -WindowStyle hidden
    Write-Host " [OK] whkd daemon restarted" -ForegroundColor Green
} catch {
    Write-Warning "Failed to reload whkd: $_"
}

Write-Host "All configs applied successfully!" -ForegroundColor Green
