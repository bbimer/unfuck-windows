@echo off
title Revive Environment
chcp 65001 >nul
set PS_SCRIPT="%~dp0revive.ps1"
if not exist %PS_SCRIPT% set PS_SCRIPT="%~dp0_customization\scripts\revive.ps1"
if not exist %PS_SCRIPT% set PS_SCRIPT="C:\Users\root\Desktop\_customization\scripts\revive.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %PS_SCRIPT%
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Encountered an issue while reviving the environment.
    pause
) else (
    ping 127.0.0.1 -n 3 >nul
)
