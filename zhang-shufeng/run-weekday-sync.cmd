@echo off
setlocal EnableExtensions
cd /d "%~dp0.."
if not exist "%~dp0logs" mkdir "%~dp0logs"

set "PS=powershell"
where pwsh >nul 2>nul
if not errorlevel 1 set "PS=pwsh"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0weekday-sync.ps1" >> "%~dp0logs\scheduler.log" 2>&1
exit /b %ERRORLEVEL%
