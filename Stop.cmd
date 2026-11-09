@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-ATrust.ps1" -Action Stop
pause
