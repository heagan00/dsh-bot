@echo off
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "logs" mkdir "logs"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Minimized -File "%~dp0wang-dali.ps1" >> "%~dp0logs\wang-dali-console.log" 2>&1
exit /b %ERRORLEVEL%
