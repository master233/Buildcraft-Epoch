@echo off
cd /d "%~dp0"
title BuildcraftEpoch
echo Starting game server...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "server.ps1"
echo.
pause
