@echo off
setlocal EnableExtensions
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0prompt-library.ps1" >> "%~dp0logs\prompt-library-console.log" 2>&1
exit /b %ERRORLEVEL%
