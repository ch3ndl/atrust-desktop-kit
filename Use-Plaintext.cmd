@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-ATrust.ps1" -StorageMode Plaintext -PrepareOnly
pause
