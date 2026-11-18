@echo off
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "logs" mkdir "logs"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0li-shen-cleanup.ps1" -Apply >> "%~dp0logs\li-shen-console.log" 2>&1
exit /b %ERRORLEVEL%
