@echo off
setlocal EnableDelayedExpansion
title Apagado programado

:MENU
cls
echo.
echo ========================================
echo          APAGADO PROGRAMADO
echo ========================================
echo.
echo   1. 15 minutos
echo   2. 30 minutos
echo   3. 1 hora
echo   4. 2 horas
echo   5. 4 horas
echo   6. 8 horas
echo   7. Tiempo personalizado
echo   8. Cancelar apagado de Windows
echo   0. Salir
echo.
choice /c 123456780 /n /m "Seleccione una opcion: "

if errorlevel 9 exit /b
if errorlevel 8 goto CANCELAR
if errorlevel 7 goto PERSONALIZADO
if errorlevel 6 set "MINUTOS=480" & goto INICIAR
if errorlevel 5 set "MINUTOS=240" & goto INICIAR
if errorlevel 4 set "MINUTOS=120" & goto INICIAR
if errorlevel 3 set "MINUTOS=60"  & goto INICIAR
if errorlevel 2 set "MINUTOS=30"  & goto INICIAR
if errorlevel 1 set "MINUTOS=15"  & goto INICIAR

goto MENU


:PERSONALIZADO
cls
echo.
echo ========================================
echo          TIEMPO PERSONALIZADO
echo ========================================
echo.
echo Introduzca el tiempo en minutos.
echo.
set /p "MINUTOS=Minutos: "

if not defined MINUTOS goto MENU

set /a PRUEBA=MINUTOS 2>nul

if !PRUEBA! LEQ 0 (
    echo.
    echo El tiempo debe ser mayor que 0.
    pause
    goto PERSONALIZADO
)

goto INICIAR


:INICIAR

set /a SEGUNDOS=MINUTOS*60

rem ----------------------------------------
rem Obtener hora actual
rem ----------------------------------------

for /f "tokens=1-3 delims=:,." %%A in ("%TIME%") do (
    set /a HORA=1%%A-100
    set /a MIN_ACTUAL=1%%B-100
    set /a SEG_ACTUAL=1%%C-100
)

rem ----------------------------------------
rem Convertir hora actual a segundos
rem ----------------------------------------

set /a ACTUAL_TOTAL=HORA*3600+MIN_ACTUAL*60+SEG_ACTUAL

rem ----------------------------------------
rem Calcular hora de apagado
rem ----------------------------------------

set /a APAGADO_TOTAL=(ACTUAL_TOTAL+SEGUNDOS)%%86400

set /a APAGADO_HORA=APAGADO_TOTAL/3600
set /a APAGADO_MIN=(APAGADO_TOTAL%%3600)/60
set /a APAGADO_SEG=APAGADO_TOTAL%%60

if !APAGADO_HORA! LSS 10 set "APAGADO_HORA=0!APAGADO_HORA!"
if !APAGADO_MIN! LSS 10 set "APAGADO_MIN=0!APAGADO_MIN!"
if !APAGADO_SEG! LSS 10 set "APAGADO_SEG=0!APAGADO_SEG!"


:CUENTA

set /a HORAS=SEGUNDOS/3600
set /a MIN=SEGUNDOS%%3600/60
set /a SEG=SEGUNDOS%%60

if !HORAS! LSS 10 set "HORAS=0!HORAS!"
if !MIN! LSS 10 set "MIN=0!MIN!"
if !SEG! LSS 10 set "SEG=0!SEG!"

cls
echo.
echo ========================================
echo          APAGADO PROGRAMADO
echo ========================================
echo.
echo.
echo          Se apagara a las:
echo.
echo             !APAGADO_HORA!:!APAGADO_MIN!:!APAGADO_SEG!
echo.
echo.
echo          Tiempo restante:
echo.
echo             !HORAS!:!MIN!:!SEG!
echo.
echo.
echo       [C] Cancelar temporizador
echo.
echo ========================================
echo.

choice /c CX /n /t 1 /d X >nul

if errorlevel 2 goto CONTINUAR
if errorlevel 1 goto CANCELAR_TEMP


:CONTINUAR

set /a SEGUNDOS-=1

if !SEGUNDOS! LEQ 0 goto APAGAR

goto CUENTA


:CANCELAR_TEMP

cls
echo.
echo ========================================
echo       TEMPORIZADOR CANCELADO
echo ========================================
echo.
echo El PC NO se apagara.
echo.
pause
goto MENU


:APAGAR

cls
echo.
echo ========================================
echo          TIEMPO TERMINADO
echo ========================================
echo.
echo Apagando el PC...
echo.

shutdown.exe /s /t 0

exit /b


:CANCELAR

shutdown.exe /a >nul 2>&1

cls
echo.
echo ========================================
echo          APAGADO CANCELADO
echo ========================================
echo.
echo El apagado de Windows ha sido cancelado.
echo.
pause
goto MENU