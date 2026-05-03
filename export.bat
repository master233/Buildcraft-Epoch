@echo off
cd /d "%~dp0"
title BuildcraftEpoch - Export Web

set OUT=%~dp0bin

:: Try to find Godot from PATH first
where godot >nul 2>&1
if %errorlevel% == 0 (
    set GODOT=godot
    goto :export
)

:: Try common Steam install locations
set STEAM_PATH1=C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe
set STEAM_PATH2=D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe
set STEAM_PATH3=E:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe

if exist "%STEAM_PATH1%" ( set GODOT="%STEAM_PATH1%" & goto :export )
if exist "%STEAM_PATH2%" ( set GODOT="%STEAM_PATH2%" & goto :export )
if exist "%STEAM_PATH3%" ( set GODOT="%STEAM_PATH3%" & goto :export )

echo.
echo ERROR: Godot not found.
echo Please add Godot to PATH or install via Steam on C/D/E drive.
echo.
pause
exit /b 1

:export
echo.
echo [1/2] Creating output directory...
if not exist "%OUT%" mkdir "%OUT%"

echo [2/2] Exporting project...
%GODOT% --headless --path "%~dp0" --export-release "Web" "%OUT%\index.html"
if errorlevel 1 (
    echo.
    echo ERROR: Export failed.
    pause
    exit /b 1
)

echo.
echo Done! Output: %OUT%
echo Double-click bin\start.bat to play.
echo.
pause
