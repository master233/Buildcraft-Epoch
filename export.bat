@echo off
cd /d "%~dp0"
title BuildcraftEpoch - Export Web

set GODOT="C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
set OUT=%~dp0bin

echo.
echo [1/3] Creating output directory...
if not exist "%OUT%" mkdir "%OUT%"

echo [2/3] Exporting project...
%GODOT% --headless --path "%~dp0" --export-release "Web" "%OUT%\index.html"
if errorlevel 1 (
    echo.
    echo ERROR: Export failed.
    pause
    exit /b 1
)

echo [3/3] Copying launcher files...
copy /y "%~dp0tools\web\start.bat" "%OUT%\start.bat" >nul
copy /y "%~dp0tools\web\server.ps1" "%OUT%\server.ps1" >nul

echo.
echo Done! Output: %OUT%
echo Double-click start.bat to play.
echo.
pause
