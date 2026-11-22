@echo off
rem Lanzador de T-Minus (PowerShell). Mantener junto a tminus.ps1
rem Reenvia los argumentos: tminus.bat 45 -Accion suspender
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0tminus.ps1" %*
