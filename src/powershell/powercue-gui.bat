@echo off
rem Lanzador de PowerCue Power Management (PowerShell). Mantener junto a powercue.ps1
rem Reenvia los argumentos: powercue-gui.bat 45 -Accion suspender
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0powercue.ps1" %*
