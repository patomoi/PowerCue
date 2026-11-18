@echo off
rem Lanzador de PowerTimer (PowerShell). Mantener junto a PowerTimer.ps1
rem Reenvia los argumentos: PowerTimer.bat 45 -Accion suspender
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0PowerTimer.ps1" %*
