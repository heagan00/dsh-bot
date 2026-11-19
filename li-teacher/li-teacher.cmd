@echo off
setlocal EnableExtensions
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0li-teacher.ps1" >> "%~dp0logs\li-teacher-console.log" 2>&1
exit /b %ERRORLEVEL%
