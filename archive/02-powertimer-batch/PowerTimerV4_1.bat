@echo off
setlocal EnableDelayedExpansion
title PowerTimer

rem ==================================================
rem CONFIGURACION
rem ==================================================

set "CONFIG=%APPDATA%\PowerTimer"
set "PRESETS=%CONFIG%\presets.ini"

rem Limite maximo de duracion en minutos (12 horas).
rem No subir de 1439: la hora objetivo se calcula modulo 24 h.
set "MAX_MIN=720"

rem Segundos de aviso antes del apagado real.
set "AVISO=30"

rem --------------------------------------------------
rem MODO DEBUG
rem 0 = apagado real habilitado
rem 1 = simulacion, nunca apaga el PC
rem --------------------------------------------------

set "DEBUG=0"

if not exist "%CONFIG%" mkdir "%CONFIG%"

if not exist "%PRESETS%" (
    (
        echo preset1=
        echo preset2=
        echo preset3=
        echo preset4=
    ) > "%PRESETS%"
)


:MENU

call :CARGAR

cls
echo.
echo ========================================
echo              POWERTIMER
echo       PROGRAMADOR DE APAGADO
echo ========================================
echo.

if "!DEBUG!"=="1" (
    echo          MODO DEBUG ACTIVADO
    echo       LOS APAGADOS ESTAN DESHABILITADOS
    echo.
)

echo   APAGADO RAPIDO
echo.
echo   [1]  15 minutos
echo   [2]  30 minutos
echo   [3]  1 hora
echo   [4]  2 horas
echo   [5]  4 horas
echo   [6]  8 horas
echo.
echo   PRESETS
echo.
call :MOSTRAR_PRESET_MENU 1 7
call :MOSTRAR_PRESET_MENU 2 8
call :MOSTRAR_PRESET_MENU 3 9
call :MOSTRAR_PRESET_MENU 4 A
echo.
echo   [B]  Tiempo personalizado
echo   [C]  Administrar presets
echo   [D]  Cancelar apagado de Windows

if "!DEBUG!"=="0" (
    echo   [E]  Modo DEBUG: DESACTIVADO
) else (
    echo   [E]  Modo DEBUG: ACTIVADO
)

echo   [F]  Acerca de PowerTimer
echo.
echo   [0]  Salir
echo.
echo ----------------------------------------
echo.

choice /c 123456789ABCDEF0 /n /m "Seleccione una opcion: "

if errorlevel 16 goto SALIR
if errorlevel 15 goto ACERCA
if errorlevel 14 goto TOGGLE_DEBUG
if errorlevel 13 goto CANCELAR
if errorlevel 12 goto ADMINISTRAR
if errorlevel 11 goto PERSONALIZADO
if errorlevel 10 set "MINUTOS=!preset4!" & goto USAR_PRESET
if errorlevel 9 set "MINUTOS=!preset3!" & goto USAR_PRESET
if errorlevel 8 set "MINUTOS=!preset2!" & goto USAR_PRESET
if errorlevel 7 set "MINUTOS=!preset1!" & goto USAR_PRESET
if errorlevel 6 set "MINUTOS=480" & goto INICIAR
if errorlevel 5 set "MINUTOS=240" & goto INICIAR
if errorlevel 4 set "MINUTOS=120" & goto INICIAR
if errorlevel 3 set "MINUTOS=60" & goto INICIAR
if errorlevel 2 set "MINUTOS=30" & goto INICIAR
if errorlevel 1 set "MINUTOS=15" & goto INICIAR

goto MENU


rem ==================================================
rem CAMBIAR MODO DEBUG
rem ==================================================

:TOGGLE_DEBUG

if "!DEBUG!"=="0" (
    set "DEBUG=1"
    shutdown.exe /a >nul 2>&1

    cls
    echo.
    echo ========================================
    echo          MODO DEBUG ACTIVADO
    echo ========================================
    echo.
    echo Los apagados reales estan deshabilitados.
    echo.
    echo PowerTimer funcionara en modo simulacion.
    echo.
    echo El PC NO se apagara.
    echo.
    echo ----------------------------------------
    echo.
    pause
) else (
    set "DEBUG=0"

    cls
    echo.
    echo ========================================
    echo         MODO DEBUG DESACTIVADO
    echo ========================================
    echo.
    echo Los apagados reales estan habilitados.
    echo.
    echo ----------------------------------------
    echo.
    pause
)

goto MENU


rem ==================================================
rem USAR PRESET
rem ==================================================

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
echo Maximo: !MAX_MIN! minutos.
echo.
echo Deje vacio para volver.
echo.

set "VAL="
set /p "VAL=Minutos: "

if not defined VAL goto MENU

call :VALIDAR

if not defined VAL_OK (
    echo.
    echo Valor invalido. Use solo numeros entre 1 y !MAX_MIN!.
    pause
    goto PERSONALIZADO
)

set "MINUTOS=!VAL_NUM!"
goto INICIAR


rem ==================================================
rem INICIAR TEMPORIZADOR
rem ==================================================

:INICIAR

set /a DURACION=MINUTOS*60

call :OBTENER_HORA

set /a OBJETIVO=(ACTUAL_TOTAL+DURACION)%%86400

set /a APAGADO_HORA=OBJETIVO/3600
set /a APAGADO_MIN=(OBJETIVO%%3600)/60
set /a APAGADO_SEG=OBJETIVO%%60

if !APAGADO_HORA! LSS 10 set "APAGADO_HORA=0!APAGADO_HORA!"
if !APAGADO_MIN! LSS 10 set "APAGADO_MIN=0!APAGADO_MIN!"
if !APAGADO_SEG! LSS 10 set "APAGADO_SEG=0!APAGADO_SEG!"


rem ==================================================
rem CUENTA REGRESIVA EN TIEMPO REAL
rem ==================================================

:CUENTA

call :OBTENER_HORA

set /a SEGUNDOS=OBJETIVO-ACTUAL_TOTAL

rem Ajuste si cruza medianoche
if !SEGUNDOS! LSS 0 set /a SEGUNDOS+=86400

rem El restante nunca puede superar la duracion original:
rem si ocurre, el objetivo ya paso ^(salto de segundo o suspension^)
if !SEGUNDOS! GTR !DURACION! goto APAGAR

if !SEGUNDOS! LEQ 0 goto APAGAR

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

if "!DEBUG!"=="1" (
    echo             [ MODO DEBUG ]
    echo.
)

echo          Se apagara a las:
echo.
echo             !APAGADO_HORA!:!APAGADO_MIN!:!APAGADO_SEG!
echo.
echo          Hora actual:
echo.
echo             !HORA_FORMAT!:!MIN_FORMAT!:!SEG_FORMAT!
echo.
echo          Tiempo restante:
echo.
echo             !HORAS!:!MIN!:!SEG!
echo.
echo       [C] Cancelar temporizador
echo.
echo ----------------------------------------
echo.

choice /c CX /n /t 1 /d X >nul

if errorlevel 2 goto CUENTA
if errorlevel 1 goto CANCELAR_TEMP


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

if "!DEBUG!"=="1" goto DEBUG_APAGAR

rem Limpiar cualquier apagado pendiente y programar el real con aviso
shutdown.exe /a >nul 2>&1
shutdown.exe /s /t !AVISO! /c "PowerTimer: el equipo se apagara en !AVISO! segundos."

if errorlevel 1 (
    echo No se pudo programar el apagado.
    echo.
    pause
    goto MENU
)

echo El PC se apagara en !AVISO! segundos.
echo.
echo       [C] Cancelar apagado
echo.
echo ----------------------------------------
echo.

set /a ESPERA=AVISO-3
choice /c CX /n /t !ESPERA! /d X >nul

if errorlevel 2 exit /b

shutdown.exe /a >nul 2>&1

cls
echo.
echo ========================================
echo          APAGADO CANCELADO
echo ========================================
echo.
echo El PC NO se apagara.
echo.
pause
goto MENU


rem ==================================================
rem SIMULACION DE APAGADO
rem ==================================================

:DEBUG_APAGAR

echo             [ MODO DEBUG ]
echo.
echo El temporizador ha terminado.
echo.
echo SIMULACION: el PC NO se apagara.
echo.
echo El apagado real ha sido bloqueado.
echo.
echo ----------------------------------------
echo.

call :NOTIFICACION_DEBUG

pause
goto MENU


rem ==================================================
rem NOTIFICACION DEBUG ^(no bloquea el script^)
rem ==================================================

:NOTIFICACION_DEBUG

start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $n = New-Object System.Windows.Forms.NotifyIcon; $n.Icon = [System.Drawing.SystemIcons]::Information; $n.Visible = $true; $n.BalloonTipTitle = 'PowerTimer'; $n.BalloonTipText = 'Temporizador finalizado. El apagado ha sido simulado. El PC no se apagara.'; $n.ShowBalloonTip(5000); Start-Sleep -Seconds 6; $n.Dispose()"

exit /b


rem ==================================================
rem OBTENER HORA ACTUAL
rem ==================================================

:OBTENER_HORA

for /f "tokens=1-3 delims=:,." %%A in ("%TIME%") do (
    set "HORA_RAW=%%A"
    set "MIN_RAW=%%B"
    set "SEG_RAW=%%C"
)

set "HORA_RAW=!HORA_RAW: =0!"

set /a HORA=1!HORA_RAW!-100
set /a MIN_ACTUAL=1!MIN_RAW!-100
set /a SEG_ACTUAL=1!SEG_RAW!-100

set /a ACTUAL_TOTAL=HORA*3600+MIN_ACTUAL*60+SEG_ACTUAL

set "HORA_FORMAT=!HORA!"
set "MIN_FORMAT=!MIN_ACTUAL!"
set "SEG_FORMAT=!SEG_ACTUAL!"

if !HORA! LSS 10 set "HORA_FORMAT=0!HORA!"
if !MIN_ACTUAL! LSS 10 set "MIN_FORMAT=0!MIN_ACTUAL!"
if !SEG_ACTUAL! LSS 10 set "SEG_FORMAT=0!SEG_ACTUAL!"

exit /b


rem ==================================================
rem VALIDAR NUMERO
rem Entrada: VAL   Salida: VAL_OK=1 y VAL_NUM si es valido
rem Solo digitos, sin ceros a la izquierda, 1..MAX_MIN
rem ==================================================

:VALIDAR

set "VAL_OK="
set "VAL_NUM="

if not defined VAL exit /b

for /f "delims=0123456789" %%X in ("!VAL!") do exit /b
for /f "tokens=* delims=0" %%N in ("!VAL!") do set "VAL_NUM=%%N"

if not defined VAL_NUM exit /b
if not "!VAL_NUM:~4!"=="" (
    set "VAL_NUM="
    exit /b
)
if !VAL_NUM! GTR !MAX_MIN! (
    set "VAL_NUM="
    exit /b
)

set "VAL_OK=1"
exit /b


rem ==================================================
rem FORMATO DE DURACION
rem Entrada: %1 = minutos   Salida: TXT
rem ==================================================

:FORMATO

set /a FH=%~1/60
set /a FM=%~1%%60
set "TXT="

if !FH! EQU 1 set "TXT=1 hora"
if !FH! GTR 1 set "TXT=!FH! horas"

if !FM! GTR 0 (
    if defined TXT (
        set "TXT=!TXT! !FM! min"
    ) else (
        set "TXT=!FM! min"
    )
)

exit /b


rem ==================================================
rem CARGAR PRESETS ^(descarta valores invalidos^)
rem ==================================================

:CARGAR

set "preset1="
set "preset2="
set "preset3="
set "preset4="

for /f "usebackq tokens=1,2 delims==" %%A in ("%PRESETS%") do (
    set "%%A=%%B"
)

for /l %%N in (1,1,4) do (
    set "VAL=!preset%%N!"
    call :VALIDAR
    if defined VAL_OK (
        set "preset%%N=!VAL_NUM!"
    ) else (
        set "preset%%N="
    )
)

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
if errorlevel 1 (
    echo No habia ningun apagado pendiente.
) else (
    echo El apagado de Windows ha sido cancelado.
)
echo.
pause
goto MENU


rem ==================================================
rem MOSTRAR PRESET EN MENU
rem %1 = numero de preset   %2 = tecla
rem ==================================================

:MOSTRAR_PRESET_MENU

set "PN=%1"
set "VALOR=!preset%PN%!"

if not defined VALOR (
    echo   [%2]  No configurado
    exit /b
)

call :FORMATO !VALOR!
echo   [%2]  !TXT!

exit /b


rem ==================================================
rem ADMINISTRAR PRESETS
rem ==================================================

:ADMINISTRAR

cls
echo.
echo ========================================
echo         PRESETS PERSONALIZADOS
echo ========================================
echo.
echo   PRESETS ACTUALES
echo.
call :MOSTRAR_PRESET_MENU 1 1
call :MOSTRAR_PRESET_MENU 2 2
call :MOSTRAR_PRESET_MENU 3 3
call :MOSTRAR_PRESET_MENU 4 4
echo.
echo   [5]  Crear / modificar preset
echo   [6]  Eliminar preset
echo.
echo   [0]  Volver
echo.
echo ----------------------------------------
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
rem CREAR / MODIFICAR
rem ==================================================

:MODIFICAR

cls
echo.
echo ========================================
echo       CREAR / MODIFICAR PRESET
echo ========================================
echo.
echo   [1]  Preset 1
echo   [2]  Preset 2
echo   [3]  Preset 3
echo   [4]  Preset 4
echo.
echo   [0]  Volver
echo.
echo ----------------------------------------
echo.

choice /c 12340 /n /m "Seleccione el preset: "

if errorlevel 5 goto ADMINISTRAR
if errorlevel 4 set "NUM=4" & goto INTRODUCIR
if errorlevel 3 set "NUM=3" & goto INTRODUCIR
if errorlevel 2 set "NUM=2" & goto INTRODUCIR
if errorlevel 1 set "NUM=1" & goto INTRODUCIR

goto MODIFICAR


rem ==================================================
rem INTRODUCIR PRESET
rem ==================================================

:INTRODUCIR

cls
echo.
echo ========================================
echo          CONFIGURAR PRESET %NUM%
echo ========================================
echo.
echo Valor actual:
echo.

set "ACTUAL=!preset%NUM%!"

if defined ACTUAL (
    call :FORMATO !ACTUAL!
    echo   !TXT!
) else (
    echo   No configurado
)

echo.
echo Introduzca el nuevo tiempo en minutos.
echo Maximo: !MAX_MIN! minutos.
echo Deje vacio para volver.
echo.

set "VAL="
set /p "VAL=Minutos: "

if not defined VAL goto ADMINISTRAR

call :VALIDAR

if not defined VAL_OK (
    echo.
    echo Valor invalido. Use solo numeros entre 1 y !MAX_MIN!.
    pause
    goto INTRODUCIR
)

set "preset%NUM%=!VAL_NUM!"

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
echo   [1]  Preset 1
echo   [2]  Preset 2
echo   [3]  Preset 3
echo   [4]  Preset 4
echo.
echo   [0]  Volver
echo.
echo ----------------------------------------
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
rem ACERCA DE POWERTIMER
rem ==================================================

:ACERCA

cls
echo.
echo ========================================
echo             POWERTIMER
echo ========================================
echo.
echo       PROGRAMADOR DE APAGADO
echo.
echo              Version 4.0
echo.
echo          Autor: Patomoi
echo.
echo ----------------------------------------
echo.
echo PowerTimer permite programar el apagado
echo automatico de Windows mediante una
echo cuenta regresiva.
echo.
echo Incluye presets personalizados, tiempo
echo personalizado y modo DEBUG para realizar
echo pruebas sin apagar el PC.
echo.
echo ----------------------------------------
echo.
echo Presione una tecla para volver.
echo.

pause >nul
goto MENU


rem ==================================================
rem SALIR
rem ==================================================

:SALIR

exit /b
