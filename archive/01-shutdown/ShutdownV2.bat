@echo off
setlocal EnableDelayedExpansion
title Apagado programado

rem ==================================================
rem CONFIGURACION
rem ==================================================

set "CONFIG=%APPDATA%\ApagadoProgramado"
set "PRESETS=%CONFIG%\presets.ini"

if not exist "%CONFIG%" (
    mkdir "%CONFIG%"
)

if not exist "%PRESETS%" (
    (
        echo preset1=
        echo preset2=
        echo preset3=
        echo preset4=
    ) > "%PRESETS%"
)


:MENU

rem ==================================================
rem LEER PRESETS
rem ==================================================

set "preset1="
set "preset2="
set "preset3="
set "preset4="

for /f "usebackq tokens=1,2 delims==" %%A in ("%PRESETS%") do (
    set "%%A=%%B"
)


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
echo.

call :MOSTRAR_PRESET_MENU 1 7
call :MOSTRAR_PRESET_MENU 2 8
call :MOSTRAR_PRESET_MENU 3 9
call :MOSTRAR_PRESET_MENU 4 A

echo.
echo   B. Tiempo personalizado
echo   C. Administrar presets
echo   D. Cancelar apagado de Windows
echo   0. Salir
echo.
echo ========================================
echo.

choice /c 123456789ABCD0 /n /m "Seleccione una opcion: "

if errorlevel 14 goto SALIR
if errorlevel 13 goto CANCELAR
if errorlevel 12 goto ADMINISTRAR
if errorlevel 11 goto PERSONALIZADO
if errorlevel 10 goto PRESET4
if errorlevel 9 goto PRESET3
if errorlevel 8 goto PRESET2
if errorlevel 7 goto PRESET1
if errorlevel 6 set "MINUTOS=480" & goto INICIAR
if errorlevel 5 set "MINUTOS=240" & goto INICIAR
if errorlevel 4 set "MINUTOS=120" & goto INICIAR
if errorlevel 3 set "MINUTOS=60" & goto INICIAR
if errorlevel 2 set "MINUTOS=30" & goto INICIAR
if errorlevel 1 set "MINUTOS=15" & goto INICIAR

goto MENU


rem ==================================================
rem USAR PRESETS
rem ==================================================

:PRESET1
set "MINUTOS=!preset1!"
goto USAR_PRESET

:PRESET2
set "MINUTOS=!preset2!"
goto USAR_PRESET

:PRESET3
set "MINUTOS=!preset3!"
goto USAR_PRESET

:PRESET4
set "MINUTOS=!preset4!"
goto USAR_PRESET


:USAR_PRESET

if not defined MINUTOS (
    echo.
    echo Ese preset no esta configurado.
    pause
    goto MENU
)

goto INICIAR


rem ==================================================
rem TIEMPO PERSONALIZADO
rem ==================================================

:PERSONALIZADO

cls
echo.
echo ========================================
echo          TIEMPO PERSONALIZADO
echo ========================================
echo.
echo Introduzca el tiempo en minutos.
echo.

set "MINUTOS="
set /p "MINUTOS=Minutos: "

if not defined MINUTOS goto MENU

set /a PRUEBA=MINUTOS 2>nul

if !PRUEBA! LEQ 0 (
    echo.
    echo El tiempo debe ser mayor que 0.
    pause
    goto PERSONALIZADO
)

set "MINUTOS=!PRUEBA!"

goto INICIAR


rem ==================================================
rem INICIAR TEMPORIZADOR
rem ==================================================

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

rem ==================================================
rem CALCULAR TIEMPO RESTANTE
rem ==================================================

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
echo          Se apagara a las:
echo.
echo             !APAGADO_HORA!:!APAGADO_MIN!:!APAGADO_SEG!
echo.
echo          Tiempo restante:
echo.
echo             !HORAS!:!MIN!:!SEG!
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


rem ==================================================
rem CANCELAR TEMPORIZADOR
rem ==================================================

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


rem ==================================================
rem APAGAR
rem ==================================================

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


rem ==================================================
rem CANCELAR APAGADO DE WINDOWS
rem ==================================================

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


rem ==================================================
rem MOSTRAR PRESET EN MENU PRINCIPAL
rem ==================================================

:MOSTRAR_PRESET_MENU

set "NUM=%1"
set "TECLA=%2"
set "VALOR=!preset%NUM%!"

if not defined VALOR (
    echo   %TECLA%. No configurado
    exit /b
)

set /a H=VALOR/60
set /a M=VALOR%%60

if !H! GTR 0 (
    if !M! EQU 0 (
        echo   %TECLA%. !H! hora
    ) else (
        echo   %TECLA%. !H! hora !M! minutos
    )
) else (
    echo   %TECLA%. !M! minutos
)

exit /b


rem ==================================================
rem ADMINISTRAR PRESETS
rem ==================================================

:ADMINISTRAR

cls
echo.
echo ========================================
echo          PRESETS PERSONALIZADOS
echo ========================================
echo.

call :MOSTRAR_PRESET_MENU 1 1
call :MOSTRAR_PRESET_MENU 2 2
call :MOSTRAR_PRESET_MENU 3 3
call :MOSTRAR_PRESET_MENU 4 4

echo.
echo   5. Crear / modificar preset
echo   6. Eliminar preset
echo   0. Volver
echo.
echo ========================================
echo.

choice /c 1234560 /n /m "Seleccione una opcion: "

if errorlevel 7 goto MENU
if errorlevel 6 goto ELIMINAR
if errorlevel 5 goto MODIFICAR
if errorlevel 4 set "NUM=4" & goto INTRODUCIR
if errorlevel 3 set "NUM=3" & goto INTRODUCIR
if errorlevel 2 set "NUM=2" & goto INTRODUCIR
if errorlevel 1 set "NUM=1" & goto INTRODUCIR

goto ADMINISTRAR


rem ==================================================
rem CREAR / MODIFICAR PRESET
rem ==================================================

:MODIFICAR

cls
echo.
echo ========================================
echo       CREAR / MODIFICAR PRESET
echo ========================================
echo.
echo   1. Preset 1
echo   2. Preset 2
echo   3. Preset 3
echo   4. Preset 4
echo.
echo   0. Volver
echo.
echo ========================================
echo.

choice /c 12340 /n /m "Seleccione el preset: "

if errorlevel 5 goto ADMINISTRAR
if errorlevel 4 set "NUM=4" & goto INTRODUCIR
if errorlevel 3 set "NUM=3" & goto INTRODUCIR
if errorlevel 2 set "NUM=2" & goto INTRODUCIR
if errorlevel 1 set "NUM=1" & goto INTRODUCIR

goto MODIFICAR


rem ==================================================
rem INTRODUCIR VALOR
rem ==================================================

:INTRODUCIR

cls
echo.
echo ========================================
echo          CONFIGURAR PRESET %NUM%
echo ========================================
echo.
echo Introduzca el tiempo en minutos.
echo.

set "NUEVO="
set /p "NUEVO=Minutos: "

if not defined NUEVO goto ADMINISTRAR

set /a PRUEBA=NUEVO 2>nul

if !PRUEBA! LEQ 0 (
    echo.
    echo El tiempo debe ser mayor que 0.
    pause
    goto INTRODUCIR
)

set "preset%NUM%=!PRUEBA!"

call :GUARDAR

echo.
echo Preset guardado correctamente.
pause
goto ADMINISTRAR


rem ==================================================
rem ELIMINAR PRESET
rem ==================================================

:ELIMINAR

cls
echo.
echo ========================================
echo           ELIMINAR PRESET
echo ========================================
echo.
echo   1. Preset 1
echo   2. Preset 2
echo   3. Preset 3
echo   4. Preset 4
echo.
echo   0. Volver
echo.
echo ========================================
echo.

choice /c 12340 /n /m "Seleccione el preset: "

if errorlevel 5 goto ADMINISTRAR
if errorlevel 4 set "NUM=4" & goto BORRAR
if errorlevel 3 set "NUM=3" & goto BORRAR
if errorlevel 2 set "NUM=2" & goto BORRAR
if errorlevel 1 set "NUM=1" & goto BORRAR

goto ELIMINAR


:BORRAR

set "preset%NUM%="

call :GUARDAR

echo.
echo Preset eliminado.
pause
goto ADMINISTRAR


rem ==================================================
rem GUARDAR PRESETS
rem ==================================================

:GUARDAR

(
    echo preset1=!preset1!
    echo preset2=!preset2!
    echo preset3=!preset3!
    echo preset4=!preset4!
) > "%PRESETS%"

exit /b


rem ==================================================
rem SALIR
rem ==================================================

:SALIR

exit /b