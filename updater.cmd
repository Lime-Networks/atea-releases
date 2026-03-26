@echo off
powershell.exe -Command "Unblock-File -Path '%~dp0updater.ps1'" 2>nul
powershell.exe -ExecutionPolicy Bypass -File "%~dp0updater.ps1"
