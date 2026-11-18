@echo off
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "logs" mkdir "logs"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0zhou-ge.ps1" >> "%~dp0logs\zhou-ge-console.log" 2>&1
exit /b %ERRORLEVEL%
