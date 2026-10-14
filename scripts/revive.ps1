# Revive desktop environment script (Komorebi, whkd, YASB)
$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "   REVIVING CUSTOMIZATION ENVIRONMENT   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Magenta

function Start-DetachedHiddenProcess {
    param([string]$CommandLine)
    $startup = New-CimInstance -ClassName Win32_ProcessStartup -Property @{ShowWindow = [uint16]0} -ClientOnly
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = $CommandLine; ProcessStartupInformation = $startup} | Out-Null
}

$repoRoot = "C:\Users\root\Desktop\_customization"
$komorebiDst = "C:\Users\root\komorebi.json"

# 1. Sync komorebi config if present in repo
if (Test-Path "$repoRoot\komorebi\komorebi.json") {
    Copy-Item "$repoRoot\komorebi\komorebi.json" -Destination $komorebiDst -Force
}

# 2. Check / Restart Komorebi
$komoProc = Get-Process komorebi -ErrorAction SilentlyContinue
if (-not $komoProc) {
    Write-Host "Starting Komorebi..." -ForegroundColor Yellow
    $noConsole = "C:\Program Files\komorebi\bin\komorebic-no-console.exe"
    if (Test-Path $noConsole) {
        Start-DetachedHiddenProcess "`"$noConsole`" start --config `"$komorebiDst`" --whkd"
    } else {
        Start-DetachedHiddenProcess "komorebic.exe start --config `"$komorebiDst`" --whkd"
    }
    Start-Sleep -Milliseconds 600
    Write-Host " [OK] Komorebi started" -ForegroundColor Green
} else {
    try {
        $stateJson = komorebic state | ConvertFrom-Json
        if ($stateJson.is_paused) {
            komorebic toggle-pause
            Write-Host " [OK] Komorebi unpaused" -ForegroundColor Green
        }
    } catch {
        # ignore parse errors
    }
    komorebic replace-configuration "$komorebiDst"
    komorebic enforce-workspace-rules
    komorebic retile
    Write-Host " [OK] Komorebi reconfigured & retiled" -ForegroundColor Green
}

# 3. Restart whkd (strictly hidden, no console window)
try {
    Get-Process whkd -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 200
    $whkdPath = "C:\Program Files\whkd\bin\whkd.exe"
    if (Test-Path $whkdPath) {
        Start-DetachedHiddenProcess "`"$whkdPath`""
    } else {
        Start-DetachedHiddenProcess "whkd.exe"
    }
    Write-Host " [OK] whkd restarted (hidden)" -ForegroundColor Green
} catch {
    Write-Warning "whkd restart failed: $_"
}

# 4. Restart YASB (cleanly reinitializes WASAPI audio visualizer and status bar)
try {
    Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 300
    $yasbExe = "C:\Program Files\YASB\yasb.exe"
    if (Test-Path $yasbExe) {
        Start-DetachedHiddenProcess "`"$yasbExe`""
        Write-Host " [OK] YASB status bar restarted" -ForegroundColor Green
    }
} catch {
    Write-Warning "YASB restart failed: $_"
}

# 5. Final retile to seat all windows
Start-Sleep -Milliseconds 300
komorebic retile
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " Environment successfully restored!    " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta
