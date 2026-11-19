@echo off
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "logs" mkdir "logs"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0pieter-huang.ps1" >> "%~dp0logs\pieter-huang-console.log" 2>&1
exit /b %ERRORLEVEL%
