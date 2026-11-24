@echo off
rem Lanzador de PowerCue Power Management (version del .zip de descarga).
rem Mantener junto a la carpeta lib\ (que contiene powercue.ps1).
rem Reenvia los argumentos: PowerCue.bat 45 -Accion suspender
if not exist "%~dp0lib\powercue.ps1" (
    echo No se encontro lib\powercue.ps1.
    echo.
    echo Extraiga TODO el contenido del .zip en una carpeta
    echo ^(clic derecho - Extraer todo^) y abra PowerCue.bat desde ahi.
    echo.
    pause
    exit /b 1
)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0lib\powercue.ps1" %*
