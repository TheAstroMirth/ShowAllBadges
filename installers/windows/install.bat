@echo off
rem Double-click to run the ShowAllBadges installer. No administrator rights needed.
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "SAB_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %SAB_EXIT%
