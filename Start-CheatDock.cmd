@echo off
rem Launches Iart Cheat Dock without a console window. Keep this file next to CheatDock.ps1.
start "" "%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0CheatDock.ps1"
