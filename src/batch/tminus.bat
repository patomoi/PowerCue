@echo off
setlocal EnableExtensions EnableDelayedExpansion
title T-Minus Shutdown

rem ==================================================
rem T-Minus 5.1 (batch) - Autor original: Patomoi
rem Menu de texto + linea de comandos. Ayuda: tminus.bat --ayuda
rem Solo ASCII: sin tildes, para que la consola las muestre bien.
rem ==================================================

set "VERSION=5.1"
set "MAX_MIN=720"
set "MAX_SEG=86000"
set "AVISO=30"
set "CONFIG=%APPDATA%\T-minus"
set "PRESETS=%CONFIG%\presets.ini"
set "SETTINGS=%CONFIG%\settings.ini"

set "DEBUG=0"
set "SEL=apagar"
set "ACCION=apagar"
set "MODO_CLI=0"
set "FIN=0"
set "RC=0"
set "ULTIMO="
set "MSG="
set "MSG_N=0"
set "FASE="
set "PRE1=" & set "PRE2=" & set "PRE3=" & set "PRE4="

if not exist "%CONFIG%" mkdir "%CONFIG%"
call :LEER_AJUSTES

rem ==================================================
rem ARGUMENTOS
rem ==================================================

set "ARG_T=" & set "ARG_A=" & set "ARG_P=" & set "ARG_R=0" & set "ARG_S="

:ARGS
if "%~1"=="" goto ARGS_FIN
set "ARG=%~1"
if /i "!ARG!"=="-h" goto AYUDA
if /i "!ARG!"=="--ayuda" goto AYUDA
if /i "!ARG!"=="--help" goto AYUDA
if /i "!ARG!"=="/?" goto AYUDA
if /i "!ARG!"=="-v" goto VER_VERSION
if /i "!ARG!"=="--version" goto VER_VERSION
if /i "!ARG!"=="-d" goto OPT_DEBUG
if /i "!ARG!"=="--debug" goto OPT_DEBUG
if /i "!ARG!"=="-r" goto OPT_REP
if /i "!ARG!"=="--repetir" goto OPT_REP
if /i "!ARG!"=="-a" goto OPT_A
if /i "!ARG!"=="--accion" goto OPT_A
if /i "!ARG!"=="-p" goto OPT_P
if /i "!ARG!"=="--preset" goto OPT_P
if /i "!ARG!"=="--segundos" goto OPT_S
if "!ARG:~0,1!"=="-" ( call :ERR_ARGS "opcion desconocida: !ARG!" & exit /b 2 )
if defined ARG_T ( call :ERR_ARGS "sobra el argumento: !ARG!" & exit /b 2 )
set "ARG_T=!ARG!"
shift
goto ARGS

:OPT_DEBUG
set "DEBUG=1"
shift
goto ARGS

:OPT_REP
set "ARG_R=1"
shift
goto ARGS

:OPT_A
if "%~2"=="" ( call :ERR_ARGS "falta el valor de !ARG!" & exit /b 2 )
set "ARG_A=%~2"
shift
shift
goto ARGS

:OPT_P
if "%~2"=="" ( call :ERR_ARGS "falta el valor de !ARG!" & exit /b 2 )
set "ARG_P=%~2"
shift
shift
goto ARGS

:OPT_S
if "%~2"=="" ( call :ERR_ARGS "falta el valor de !ARG!" & exit /b 2 )
set "ARG_S=%~2"
shift
shift
goto ARGS

:ARGS_FIN
if defined ARG_A (
    call :ACC_INFO "!ARG_A!"
    if not defined A_NOM ( call :ERR_ARGS "accion invalida: !ARG_A! (use apagar, reiniciar, suspender o hibernar)" & exit /b 2 )
    set "SEL=!A_VER!"
)

set /a NM=0
if defined ARG_T set /a NM+=1
if defined ARG_P set /a NM+=1
if "!ARG_R!"=="1" set /a NM+=1
if defined ARG_S set /a NM+=1
if !NM! GTR 1 ( call :ERR_ARGS "use solo uno entre TIEMPO, --preset, --repetir y --segundos" & exit /b 2 )

if !NM! EQU 0 (
    if defined ARG_A call :GUARDAR_AJUSTES
    goto MENU
)

set "MODO_CLI=1"
call :LEER_PRESETS

if defined ARG_T (
    call :PARSE_TIEMPO "!ARG_T!"
    if errorlevel 1 ( call :ERR_ARGS "tiempo invalido: !ARG_T! (ejemplos: 45, 2h, 1h30, 23:30)" & exit /b 2 )
    if "!T_TIPO!"=="m" ( call :INICIAR_MIN !T_MIN! ) else ( call :INICIAR_HORA !T_HH! !T_MM! )
    goto CLI_FIN
)
if defined ARG_P (
    call :NUM "!ARG_P!" 1
    if errorlevel 1 ( call :ERR_ARGS "preset invalido: !ARG_P! (use 1 a 4)" & exit /b 2 )
    if !NUM_V! LSS 1 ( call :ERR_ARGS "preset invalido: !ARG_P! (use 1 a 4)" & exit /b 2 )
    if !NUM_V! GTR 4 ( call :ERR_ARGS "preset invalido: !ARG_P! (use 1 a 4)" & exit /b 2 )
    set "NP=!NUM_V!"
    set "PV="
    for %%k in (!NP!) do set "PV=!PRE%%k!"
    if not defined PV ( call :ERR_ARGS "el preset !NP! no esta configurado" & exit /b 2 )
    call :INICIAR_MIN !PV!
    goto CLI_FIN
)
if "!ARG_R!"=="1" (
    call :REPETIR
    if "!RC!"=="2" ( call :ERR_ARGS "aun no hay un ultimo tiempo guardado" & exit /b 2 )
    goto CLI_FIN
)
call :NUM "!ARG_S!" 5
if errorlevel 1 ( call :ERR_ARGS "segundos invalidos: !ARG_S!" & exit /b 2 )
if !NUM_V! LSS 1 ( call :ERR_ARGS "segundos invalidos: !ARG_S!" & exit /b 2 )
if !NUM_V! GTR !MAX_SEG! ( call :ERR_ARGS "segundos invalidos: !ARG_S!" & exit /b 2 )
if not "!DEBUG!"=="1" ( call :ERR_ARGS "--segundos solo se puede usar junto con --debug" & exit /b 2 )
call :ARRANCAR !NUM_V! ""

:CLI_FIN
if "!FIN!"=="1" exit /b 0
if "!RC!"=="1" echo Temporizador cancelado. El PC no se toco.
exit /b !RC!

rem ==================================================
rem MENU
rem ==================================================

:MENU
call :LEER_PRESETS
call :ACC_INFO "!SEL!"
call :LABEL_ULTIMO
cls
echo.
echo ========================================
echo             T-MINUS V5
echo ========================================
echo.
if "!DEBUG!"=="1" (
    echo          MODO DEBUG ACTIVADO
    echo     LAS ACCIONES NO SE EJECUTARAN
    echo.
)
echo   Accion: !A_NOM!   [E] cambiar
echo.
echo   RAPIDO
echo   [1] 15 min   [2] 30 min   [3] 1 hora
echo   [4] 2 horas  [5] 4 horas  [6] 8 horas
echo.
echo   PRESETS
call :MOSTRAR_PRESET 1 7
call :MOSTRAR_PRESET 2 8
call :MOSTRAR_PRESET 3 9
call :MOSTRAR_PRESET 4 A
echo.
echo   [B]  Tiempo personalizado
echo   [C]  Hora exacta
echo   [D]  Administrar presets
if defined UL_TXT ( echo   [R]  !UL_TXT! ) else ( echo   [R]  Repetir ultimo: aun no hay ninguno )
if "!DEBUG!"=="1" ( echo   [G]  Modo DEBUG: ACTIVADO ) else ( echo   [G]  Modo DEBUG: DESACTIVADO )
echo   [H]  Acerca de T-Minus
echo   [0]  Salir
echo.
if defined MSG (
    echo   !MSG!
    echo.
    set "MSG="
)
echo ----------------------------------------
echo.

choice /c 123456789ABCDEGHR0 /n /m "Seleccione una opcion: "
set "K=!errorlevel!"

if "!K!"=="18" goto SALIR_OK
if "!K!"=="17" goto DO_REPETIR
if "!K!"=="16" goto ACERCA
if "!K!"=="15" goto TOGGLE_DEBUG
if "!K!"=="14" goto CAMBIAR_ACCION
if "!K!"=="13" goto ADMIN
if "!K!"=="12" goto MENU_HORA
if "!K!"=="11" goto MENU_PERS
if "!K!"=="10" ( set "NP=4" & goto USAR_PRESET )
if "!K!"=="9" ( set "NP=3" & goto USAR_PRESET )
if "!K!"=="8" ( set "NP=2" & goto USAR_PRESET )
if "!K!"=="7" ( set "NP=1" & goto USAR_PRESET )
if "!K!"=="6" ( call :INICIAR_MIN 480 & goto POST )
if "!K!"=="5" ( call :INICIAR_MIN 240 & goto POST )
if "!K!"=="4" ( call :INICIAR_MIN 120 & goto POST )
if "!K!"=="3" ( call :INICIAR_MIN 60 & goto POST )
if "!K!"=="2" ( call :INICIAR_MIN 30 & goto POST )
if "!K!"=="1" ( call :INICIAR_MIN 15 & goto POST )
goto MENU

:DO_REPETIR
call :REPETIR
if "!RC!"=="2" set "MSG=Aun no hay un ultimo tiempo guardado."
goto POST

:TOGGLE_DEBUG
if "!DEBUG!"=="1" ( set "DEBUG=0" ) else ( set "DEBUG=1" )
goto MENU

:POST
if "!FIN!"=="1" goto SALIR_OK
if "!RC!"=="1" set "MSG=Temporizador cancelado. El PC no se toco."
goto MENU

:USAR_PRESET
set "PV=!PRE%NP%!"
if not defined PV (
    set "MSG=Ese preset no esta configurado. Use [D]."
    goto MENU
)
call :INICIAR_MIN !PV!
goto POST

:CAMBIAR_ACCION
if "!SEL!"=="apagar" ( set "SEL=reiniciar" ) else if "!SEL!"=="reiniciar" ( set "SEL=suspender" ) else if "!SEL!"=="suspender" ( set "SEL=hibernar" ) else ( set "SEL=apagar" )
call :GUARDAR_AJUSTES
goto MENU

:MENU_PERS
cls
echo.
echo ========================================
echo          TIEMPO PERSONALIZADO
echo ========================================
echo.
echo Formatos: 45   45m   2h   1h30    1 a !MAX_MIN! minutos
echo Deje vacio para volver.
echo.
set "VAL="
set /p "VAL=Duracion: "
if not defined VAL goto MENU
call :PARSE_TIEMPO "!VAL!"
if errorlevel 1 ( echo Valor invalido. & pause & goto MENU_PERS )
if not "!T_TIPO!"=="m" ( echo Valor invalido. & pause & goto MENU_PERS )
call :INICIAR_MIN !T_MIN!
goto POST

:MENU_HORA
cls
echo.
echo ========================================
echo              HORA EXACTA
echo ========================================
echo.
echo Formato: HH:MM  en 24 horas. Deje vacio para volver.
echo.
set "VAL="
set /p "VAL=Hora: "
if not defined VAL goto MENU
call :PARSE_TIEMPO "!VAL!"
if errorlevel 1 ( echo Valor invalido. & pause & goto MENU_HORA )
if not "!T_TIPO!"=="h" ( echo Valor invalido. & pause & goto MENU_HORA )
call :INICIAR_HORA !T_HH! !T_MM!
goto POST

:ADMIN
call :LEER_PRESETS
cls
echo.
echo ========================================
echo         PRESETS PERSONALIZADOS
echo ========================================
echo.
call :MOSTRAR_PRESET 1 1
call :MOSTRAR_PRESET 2 2
call :MOSTRAR_PRESET 3 3
call :MOSTRAR_PRESET 4 4
echo.
echo   [1-4]  Crear / modificar ese preset
echo   [E]    Eliminar preset
echo.
echo   [0]    Volver
echo.
echo ----------------------------------------
echo.
choice /c 1234E0 /n /m "Seleccione una opcion: "
set "K=!errorlevel!"
if "!K!"=="6" goto MENU
if "!K!"=="5" goto ADMIN_BORRAR
set "NP=!K!"

:ADMIN_EDITAR
cls
echo.
echo CONFIGURAR PRESET !NP!
echo.
echo Formatos: 45   2h   1h30    1 a !MAX_MIN! minutos
echo Deje vacio para volver.
echo.
set "VAL="
set /p "VAL=Duracion: "
if not defined VAL goto ADMIN
call :PARSE_TIEMPO "!VAL!"
if errorlevel 1 ( echo Valor invalido. & pause & goto ADMIN_EDITAR )
if not "!T_TIPO!"=="m" ( echo Valor invalido. & pause & goto ADMIN_EDITAR )
set "PRE!NP!=!T_MIN!"
call :GUARDAR_PRESETS
echo.
echo Preset guardado.
pause
goto ADMIN

:ADMIN_BORRAR
echo.
choice /c 12340 /n /m "Numero de preset a eliminar, 0 cancela: "
set "K=!errorlevel!"
if "!K!"=="5" goto ADMIN
set "PRE!K!="
call :GUARDAR_PRESETS
echo.
echo Preset eliminado.
pause
goto ADMIN

:ACERCA
cls
echo.
echo ========================================
echo             T-MINUS
echo ========================================
echo.
echo       PROGRAMADOR DE APAGADO
echo.
echo          Version !VERSION! (batch)
echo          Autor: Patomoi
echo.
echo ----------------------------------------
echo.
echo Programa apagado, reinicio, suspension o
echo hibernacion con una cuenta regresiva o una
echo hora exacta, con presets, avisos previos y
echo modo DEBUG para probar sin tocar el PC.
echo.
echo Ayuda de la linea de comandos: --ayuda
echo.
pause
goto MENU

:SALIR_OK
exit /b 0

rem ==================================================
rem AYUDA Y VERSION
rem ==================================================

:AYUDA
echo T-Minus !VERSION! (batch)
echo.
echo Uso: tminus.bat [TIEMPO] [opciones]
echo   Sin argumentos abre el menu. Con TIEMPO, --preset o --repetir
echo   programa de inmediato y muestra la cuenta regresiva.
echo.
echo TIEMPO
echo   45  45m  2h  1h30  1h30m     duracion (1 minuto a 12 horas)
echo   23:30                        hora exacta (hoy o manana)
echo.
echo Opciones
echo   -a, --accion ACC    apagar (por defecto), reiniciar, suspender, hibernar
echo   -p, --preset N      usa el preset N (1-4)
echo   -r, --repetir       repite el ultimo tiempo usado
echo   -d, --debug         simulacion: nunca toca el PC
echo       --segundos N    duracion en segundos (solo pruebas, requiere --debug)
echo   -h, --ayuda         muestra esta ayuda
echo   -v, --version       muestra la version
echo.
echo Durante la cuenta: [S] +5 min  [R] -5 min  [M] +15 min  [C] cancelar
echo En el aviso final: [P] posponer 5 min  [C] cancelar.
echo Ctrl+C pide confirmacion de cmd. Cerrar la ventana cancela el temporizador.
echo.
echo Codigos de salida: 0 termino, 1 cancelado, 2 argumentos invalidos.
echo.
echo Ejemplos
echo   tminus.bat 45
echo   tminus.bat 1h30 --accion suspender
echo   tminus.bat 23:30 -a apagar
echo   tminus.bat --preset 2 --debug
exit /b 0

:VER_VERSION
echo T-Minus !VERSION! (batch)
exit /b 0

:ERR_ARGS
echo T-Minus: %~1
echo Pruebe: tminus.bat --ayuda
exit /b 2

rem ==================================================
rem TEMPORIZADOR
rem ==================================================

:INICIAR_MIN
set /a DUR=%~1*60
call :ARRANCAR !DUR! "m:%~1"
exit /b

:INICIAR_HORA
call :OBTENER_HORA
set /a DUR=%~1*3600+%~2*60-ACTUAL
if !DUR! LEQ 0 set /a DUR+=86400
set "UH=0%~1"
set "UM=0%~2"
call :ARRANCAR !DUR! "h:!UH:~-2!:!UM:~-2!"
exit /b

rem %1 = duracion en segundos   %2 = texto "ultimo" (vacio = no guardar)
:ARRANCAR
set "ACCION=!SEL!"
call :OBTENER_HORA
set "DUR=%~1"
if !DUR! GTR !MAX_SEG! set "DUR=!MAX_SEG!"
set /a OBJ=(ACTUAL+DUR)%%86400
set "TOTAL=!DUR!"
set "AV300=0"
set "AV60=0"
if !DUR! LEQ 300 set "AV300=1"
if !DUR! LEQ 60 set "AV60=1"
set "MSG_N=0"
set "FASE=cuenta"
if not "%~2"=="" set "ULTIMO=%~2"
call :GUARDAR_AJUSTES
call :CORRER
exit /b !RC!

rem Devuelve RC=0 si termino y RC=1 si se cancelo
:CORRER
call :OBTENER_HORA
set /a SEG=OBJ-ACTUAL
if !SEG! LSS 0 set /a SEG+=86400
rem Si el restante supera el maximo posible, el objetivo ya paso ^(salto de segundo o suspension^)
if !SEG! GTR !TOTAL! set "SEG=0"
if !SEG! LEQ 0 goto CORRER_FIN

if "!FASE!"=="cuenta" call :CHEQUEAR_AVISOS
call :DIBUJAR

choice /c CSRMPX /n /t 1 /d X >nul
set "K=!errorlevel!"
if "!K!"=="1" ( set "FASE=" & set "RC=1" & exit /b 1 )
if "!K!"=="2" if "!FASE!"=="cuenta" call :AJUSTAR 300
if "!K!"=="3" if "!FASE!"=="cuenta" call :AJUSTAR -300
if "!K!"=="4" if "!FASE!"=="cuenta" call :AJUSTAR 900
if "!K!"=="5" if "!FASE!"=="aviso" call :POSPONER
goto CORRER

:CORRER_FIN
if "!FASE!"=="cuenta" (
    if "!DEBUG!"=="1" (
        set "FASE="
        call :FIN_DEBUG
        set "RC=0"
        exit /b 0
    )
    set "FASE=aviso"
    set "TOTAL=!AVISO!"
    set /a OBJ=^(ACTUAL+AVISO^)%%86400
    set "MSG_N=0"
    call :SONIDO
    goto CORRER
)
set "FASE="
call :EJECUTAR
set "RC=0"
exit /b 0

:CHEQUEAR_AVISOS
if !SEG! GTR 300 ( set "AV300=0" ) else if "!AV300!"=="0" ( set "AV300=1" & call :AVISAR 300 )
if !SEG! GTR 60 ( set "AV60=0" ) else if "!AV60!"=="0" ( set "AV60=1" & call :AVISAR 60 )
exit /b

:AVISAR
call :ACC_INFO "!ACCION!"
if "%~1"=="300" ( set "MSG=Quedan 5 minutos para !A_VER!" ) else ( set "MSG=Queda 1 minuto para !A_VER!" )
set "MSG_N=8"
call :SONIDO
exit /b

rem %1 = delta en segundos (usa SEG de la vuelta actual)
:AJUSTAR
set /a NR=SEG+%~1
if %~1 LSS 0 if !NR! LSS 30 (
    set "MSG=No se puede restar mas: quedaria muy poco tiempo."
    set "MSG_N=5"
    exit /b
)
set "D=%~1"
if !NR! GTR !MAX_SEG! set /a D=MAX_SEG-SEG
set /a OBJ=(OBJ+D+86400)%%86400
set /a TOTAL+=D
exit /b

:POSPONER
set "TOTAL=300"
set /a OBJ=(ACTUAL+300)%%86400
set "AV300=1"
set "AV60=0"
set "FASE=cuenta"
set "MSG="
set "MSG_N=0"
exit /b

:DIBUJAR
call :ACC_INFO "!ACCION!"
call :HMS !OBJ!
set "HMS_OBJ=!HMS_OUT!"
call :HMS !ACTUAL!
set "HMS_ACT=!HMS_OUT!"
call :HMS !SEG!
set "HMS_RES=!HMS_OUT!"
set /a LL=SEG*30/TOTAL
if !LL! GTR 30 set "LL=30"
set /a PCT=SEG*100/TOTAL
if !PCT! GTR 100 set "PCT=100"
set "BARRA="
for /l %%i in (1,1,30) do ( if %%i LEQ !LL! ( set "BARRA=!BARRA!#" ) else ( set "BARRA=!BARRA!-" ) )

cls
echo.
echo ========================================
if "!FASE!"=="aviso" ( echo           TIEMPO TERMINADO ) else ( echo        !A_TIT! )
echo ========================================
echo.
if "!DEBUG!"=="1" ( echo            [ MODO DEBUG ] & echo. )
if "!FASE!"=="aviso" ( echo   !A_AVI!: ) else ( echo   !A_FUT! a las !HMS_OBJ! )
echo   Hora actual: !HMS_ACT!
echo.
echo   [!BARRA!] !PCT!%%
echo.
echo        Tiempo restante: !HMS_RES!
echo.
if !MSG_N! GTR 0 ( echo   !MSG! & set /a MSG_N-=1 ) else ( echo. )
echo.
if "!FASE!"=="aviso" (
    echo   [P] Posponer 5 min   [C] Cancelar
) else (
    echo   [S] +5 min  [R] -5 min  [M] +15 min  [C] Cancelar
)
echo.
echo ----------------------------------------
exit /b

:FIN_DEBUG
call :SONIDO
cls
echo.
echo ========================================
echo           TIEMPO TERMINADO
echo ========================================
echo.
echo            [ MODO DEBUG ]
echo.
call :ACC_INFO "!ACCION!"
echo   SIMULACION: se habria ejecutado "!A_VER!".
echo   El PC no ha sido tocado.
echo.
if "!MODO_CLI!"=="0" pause
exit /b

:EJECUTAR
call :ACC_INFO "!ACCION!"
cls
echo.
echo   Ejecutando: !A_NOM!...
set "OK=0"
if "!ACCION!"=="apagar" ( shutdown /s /t 0 >nul 2>&1 & if not errorlevel 1 set "OK=1" )
if "!ACCION!"=="reiniciar" ( shutdown /r /t 0 >nul 2>&1 & if not errorlevel 1 set "OK=1" )
if "!ACCION!"=="hibernar" ( shutdown /h >nul 2>&1 & if not errorlevel 1 set "OK=1" )
if "!ACCION!"=="suspender" ( rundll32.exe powrprof.dll,SetSuspendState 0,1,0 & set "OK=1" )
if "!OK!"=="1" (
    if "!ACCION!"=="apagar" set "FIN=1"
    if "!ACCION!"=="reiniciar" set "FIN=1"
    exit /b
)
echo.
echo   No se pudo ejecutar la accion. Puede que el sistema
echo   no la tenga habilitada, por ejemplo la hibernacion.
if "!MODO_CLI!"=="0" pause
exit /b

:SONIDO
start "" /b powershell.exe -NoProfile -WindowStyle Hidden -Command "[System.Media.SystemSounds]::Exclamation.Play(); Start-Sleep -Milliseconds 900"
exit /b

rem ==================================================
rem HORA Y FORMATOS
rem ==================================================

rem Segundos desde medianoche en ACTUAL
:OBTENER_HORA
for /f "tokens=1-3 delims=:,." %%A in ("%TIME%") do (
    set "HR=%%A"
    set "MR=%%B"
    set "SR=%%C"
)
set "HR=!HR: =0!"
set /a ACTUAL=(1!HR!-100)*3600+(1!MR!-100)*60+(1!SR!-100)
exit /b

rem %1 = segundos -> HMS_OUT con formato HH:MM:SS
:HMS
set /a H_=%~1/3600
set /a M_=(%~1%%3600)/60
set /a S_=%~1%%60
if !H_! LSS 10 set "H_=0!H_!"
if !M_! LSS 10 set "M_=0!M_!"
if !S_! LSS 10 set "S_=0!S_!"
set "HMS_OUT=!H_!:!M_!:!S_!"
exit /b

rem %1 = minutos -> TXT
:FORMATO
set /a FH=%~1/60
set /a FM=%~1%%60
set "TXT="
if !FH! EQU 1 set "TXT=1 hora"
if !FH! GTR 1 set "TXT=!FH! horas"
if !FM! GTR 0 (
    if defined TXT ( set "TXT=!TXT! !FM! min" ) else ( set "TXT=!FM! min" )
)
if not defined TXT set "TXT=0 min"
exit /b

rem %1 = texto, %2 = maximo de digitos -> NUM_V sin ceros a la izquierda; errorlevel 1 si no es valido
:NUM
set "NUM_V="
set "NV=%~1"
if not defined NV exit /b 1
for /f "delims=0123456789" %%X in ("!NV!") do exit /b 1
if not "!NV:~%~2!"=="" exit /b 1
for /f "tokens=* delims=0" %%N in ("!NV!") do set "NUM_V=%%N"
if not defined NUM_V set "NUM_V=0"
exit /b 0

rem %1 = texto -> VM (minutos 1..MAX_MIN); errorlevel 1 si no es valido
:VAL_MIN
set "VM="
call :NUM "%~1" 4
if errorlevel 1 exit /b 1
if !NUM_V! LSS 1 exit /b 1
if !NUM_V! GTR !MAX_MIN! exit /b 1
set "VM=!NUM_V!"
exit /b 0

rem Formatos: 45, 45m, 2h, 1h30, 1h30m (T_TIPO=m, T_MIN) y 23:30 (T_TIPO=h, T_HH, T_MM)
:PARSE_TIEMPO
set "T_TIPO="
set "T_MIN="
set "T_HH="
set "T_MM="
set "PT=%~1"
if not defined PT exit /b 1

if not "!PT::=!"=="!PT!" (
    if "!PT:~0,1!"==":" exit /b 1
    for /f "delims=:" %%a in ("!PT!") do set "PH=%%a"
    set "PM=!PT:*:=!"
    call :NUM "!PH!" 2
    if errorlevel 1 exit /b 1
    set "T_HH=!NUM_V!"
    call :NUM "!PM!" 2
    if errorlevel 1 exit /b 1
    set "T_MM=!NUM_V!"
    if !T_HH! GTR 23 exit /b 1
    if !T_MM! GTR 59 exit /b 1
    set "T_TIPO=h"
    exit /b 0
)

set "PD=!PT!"
if /i "!PD:~-3!"=="min" set "PD=!PD:~0,-3!"
if /i "!PD:~-1!"=="m" set "PD=!PD:~0,-1!"
if not defined PD exit /b 1
set "PX=!PD:h=!"
if "!PX!"=="!PD!" (
    call :NUM "!PD!" 4
    if errorlevel 1 exit /b 1
    set "TM=!NUM_V!"
) else (
    if /i "!PD:~0,1!"=="h" exit /b 1
    for /f "delims=hH" %%a in ("!PD!") do set "HA=%%a"
    set "HB=!PD:*h=!"
    call :NUM "!HA!" 2
    if errorlevel 1 exit /b 1
    set /a TM=NUM_V*60
    if defined HB (
        call :NUM "!HB!" 2
        if errorlevel 1 exit /b 1
        if !NUM_V! GTR 59 exit /b 1
        set /a TM+=NUM_V
    )
)
if !TM! LSS 1 exit /b 1
if !TM! GTR !MAX_MIN! exit /b 1
set "T_TIPO=m"
set "T_MIN=!TM!"
exit /b 0

rem %1 = nombre de accion -> A_NOM, A_TIT, A_FUT, A_AVI, A_VER ^(A_NOM queda vacio si no existe^)
:ACC_INFO
set "A_NOM=" & set "A_TIT=" & set "A_FUT=" & set "A_AVI=" & set "A_VER="
if /i "%~1"=="apagar"    ( set "A_NOM=Apagar"    & set "A_TIT=APAGADO PROGRAMADO"     & set "A_FUT=Se apagara"    & set "A_AVI=El PC se apagara en"    & set "A_VER=apagar" )
if /i "%~1"=="reiniciar" ( set "A_NOM=Reiniciar" & set "A_TIT=REINICIO PROGRAMADO"    & set "A_FUT=Se reiniciara" & set "A_AVI=El PC se reiniciara en" & set "A_VER=reiniciar" )
if /i "%~1"=="suspender" ( set "A_NOM=Suspender" & set "A_TIT=SUSPENSION PROGRAMADA"  & set "A_FUT=Se suspendera" & set "A_AVI=El PC se suspendera en" & set "A_VER=suspender" )
if /i "%~1"=="hibernar"  ( set "A_NOM=Hibernar"  & set "A_TIT=HIBERNACION PROGRAMADA" & set "A_FUT=Hibernara"     & set "A_AVI=El PC hibernara en"     & set "A_VER=hibernar" )
exit /b

rem ==================================================
rem CONFIGURACION
rem ==================================================

:LEER_PRESETS
set "PRE1=" & set "PRE2=" & set "PRE3=" & set "PRE4="
if not exist "%PRESETS%" exit /b
for /f "usebackq tokens=1,2 delims==" %%A in ("%PRESETS%") do set "PRE_%%A=%%B"
for /l %%n in (1,1,4) do (
    set "VV=!PRE_preset%%n!"
    if defined VV (
        call :VAL_MIN "!VV!"
        if not errorlevel 1 set "PRE%%n=!VM!"
    )
    set "PRE_preset%%n="
)
exit /b

:GUARDAR_PRESETS
(
    echo preset1=!PRE1!
    echo preset2=!PRE2!
    echo preset3=!PRE3!
    echo preset4=!PRE4!
) > "%PRESETS%"
exit /b

:LEER_AJUSTES
set "ST_accion=" & set "ST_ultimo="
if not exist "%SETTINGS%" exit /b
for /f "usebackq tokens=1,* delims==" %%A in ("%SETTINGS%") do set "ST_%%A=%%B"
if defined ST_accion (
    call :ACC_INFO "!ST_accion!"
    if defined A_NOM set "SEL=!A_VER!"
)
if defined ST_ultimo set "ULTIMO=!ST_ultimo!"
exit /b

:GUARDAR_AJUSTES
(
    echo accion=!SEL!
    echo ultimo=!ULTIMO!
) > "%SETTINGS%"
exit /b

rem Texto del boton "repetir ultimo" en UL_TXT ^(vacio si no hay^)
:LABEL_ULTIMO
set "UL_TXT="
if not defined ULTIMO exit /b
set "U=!ULTIMO!"
if "!U:~0,2!"=="m:" (
    call :VAL_MIN "!U:~2!"
    if not errorlevel 1 (
        call :FORMATO !VM!
        set "UL_TXT=Repetir ultimo: !TXT!"
    )
    exit /b
)
if "!U:~0,2!"=="h:" (
    call :NUM "!U:~2,2!" 2
    if errorlevel 1 exit /b
    set "LH=!NUM_V!"
    call :NUM "!U:~5,2!" 2
    if errorlevel 1 exit /b
    if !LH! GTR 23 exit /b
    if !NUM_V! GTR 59 exit /b
    set "UL_TXT=Repetir ultimo: a las !U:~2,5!"
)
exit /b

rem Repite el ultimo tiempo. RC=2 si no hay ninguno valido
:REPETIR
set "RC=2"
if not defined ULTIMO exit /b
set "U=!ULTIMO!"
if "!U:~0,2!"=="m:" (
    call :VAL_MIN "!U:~2!"
    if not errorlevel 1 call :INICIAR_MIN !VM!
    exit /b
)
if "!U:~0,2!"=="h:" (
    call :NUM "!U:~2,2!" 2
    if errorlevel 1 exit /b
    set "RH=!NUM_V!"
    call :NUM "!U:~5,2!" 2
    if errorlevel 1 exit /b
    call :INICIAR_HORA !RH! !NUM_V!
)
exit /b

rem %1 = numero de preset, %2 = tecla
:MOSTRAR_PRESET
set "PV=!PRE%~1!"
if not defined PV (
    echo   [%~2]  No configurado
    exit /b
)
call :FORMATO !PV!
echo   [%~2]  !TXT!
exit /b
