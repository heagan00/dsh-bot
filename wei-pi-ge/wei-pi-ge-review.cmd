@echo off
setlocal EnableExtensions
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0wei-pi-ge.ps1" -Mode review >> "%~dp0logs\wei-pi-ge-console.log" 2>&1
exit /b %ERRORLEVEL%
