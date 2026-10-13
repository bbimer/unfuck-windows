<#
.SYNOPSIS
    Cleans up today's trial-and-error git commits, prepares clean unified history, and syncs configs.
#>
param(
    [switch]$Push
)

$ErrorActionPreference = "Stop"

# 1. Reset broken console delegation registry keys
try {
    Remove-Item -Path "HKCU:\Console\%%Startup" -Recurse -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Console" -Name "DelegationConsole" -Value "{00000000-0000-0000-0000-000000000000}" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Console" -Name "DelegationTerminal" -Value "{00000000-0000-0000-0000-000000000000}" -ErrorAction SilentlyContinue
    Write-Host " [OK] Console delegation keys reset to default" -ForegroundColor Green
} catch {}

# 2. Navigate to repo root
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Cleaning git history..." -ForegroundColor Cyan

# 3. Soft reset to the stable base before today's test commits
$baseCommit = "39f08e809ed2bd1426d62173bf9f85680f0b70a2"
git reset --soft $baseCommit

# 4. Stage all configs
git add -A

# 5. Commit with clean message
$commitMsg = @"
feat: complete Windows 11 customization stack

- Terminal: Windows Terminal with One Half Dark, CaskaydiaMono Nerd Font, and acrylic tab row
- Shell: PowerShell 7 profile with UTF-8 encoding and Oh My Posh wholespace theme
- Fetch: Fastfetch with custom quad ASCII art logo and balanced layout
- VS Code: Lunar Pink theme and Bunker file icons automated configuration
- Komorebi: dynamic tiling, workspaces, floating rules for Windows Terminal and OneCommander
- YASB: minimalist top status bar with dark blur effect and language indicator
- whkd: instant hotkeys for workspace navigation, window focus/swap, and app launching
- Automation: sync.ps1 for one-click deployment across user profile
"@

git commit -m "$commitMsg"

Write-Host " [OK] All commits squashed and staged cleanly!" -ForegroundColor Green

git log -n 3 --oneline

if ($Push) {
    Write-Host "Pushing clean history to origin/main..." -ForegroundColor Cyan
    git push origin main --force
    Write-Host " [OK] Pushed to GitHub successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "To push this clean history to GitHub, run:" -ForegroundColor Yellow
    Write-Host "  git push origin main --force" -ForegroundColor White
}

