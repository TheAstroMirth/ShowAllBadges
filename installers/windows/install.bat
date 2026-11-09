@echo off
rem ShowAllBadges - https://github.com/TheAstroMirth/ShowAllBadges
rem Copyright (c) 2026 TheAstroMirth. SPDX-License-Identifier: GPL-3.0-or-later
rem Double-click to run the ShowAllBadges installer. No administrator rights needed.
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "SAB_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %SAB_EXIT%
