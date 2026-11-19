@echo off
setlocal EnableExtensions
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0icreat-usage.ps1" -ReportOnly >> "%~dp0logs\usage-report-console.log" 2>&1
exit /b %ERRORLEVEL%
