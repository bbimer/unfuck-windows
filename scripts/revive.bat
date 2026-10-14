@echo off
title Revive Environment
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0revive.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Encountered an issue while reviving the environment.
    pause
) else (
    ping 127.0.0.1 -n 3 >nul
)
