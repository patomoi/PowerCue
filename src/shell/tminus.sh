#!/usr/bin/env bash
# T-Minus 5.1 (shell) - Autor original: Patomoi
# Menú de texto + línea de comandos. Requiere bash 4+ y el date de GNU (Linux).
# Uso: ./tminus.sh --ayuda

VERSION="5.1"
MAX_MIN=720      # duración máxima en minutos (12 h)
MAX_SEG=86400    # límite absoluto del tiempo restante
AVISO=30         # segundos de aviso final antes de ejecutar la acción

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/T-Minus"
PRESETS="$CONFIG/presets.ini"
SETTINGS="$CONFIG/settings.ini"

ACC_ORDEN=(apagar reiniciar suspender hibernar)
declare -A ACC_NOMBRE=([apagar]="Apagar" [reiniciar]="Reiniciar" [suspender]="Suspender" [hibernar]="Hibernar")
declare -A ACC_TITULO=([apagar]="APAGADO PROGRAMADO" [reiniciar]="REINICIO PROGRAMADO" [suspender]="SUSPENSIÓN PROGRAMADA" [hibernar]="HIBERNACIÓN PROGRAMADA")
declare -A ACC_FUTURO=([apagar]="Se apagará" [reiniciar]="Se reiniciará" [suspender]="Se suspenderá" [hibernar]="Hibernará")
declare -A ACC_AVISO=([apagar]="El PC se apagará en" [reiniciar]="El PC se reiniciará en" [suspender]="El PC se suspenderá en" [hibernar]="El PC hibernará en")
declare -A AV=()

SEL="apagar"       # acción elegida en el menú
ACCION="apagar"    # acción del temporizador en marcha
DEBUG=0
FASE=""            # "", "cuenta" o "aviso"
INICIO=0; OBJETIVO=0; NOW=0
ULTIMO=""
MSG=""; MSG_HASTA=0
INT_FLAG=0
MODO_CLI=0
preset=("" "" "" "" "")
T_TIPO=""; T_MIN=""; T_HH=""; T_MM=""

if [[ -t 1 ]]; then
    C_R=$'\033[0m'; C_B=$'\033[1m'; C_ROJO=$'\033[31m'; C_AMA=$'\033[33m'; C_AZU=$'\033[36m'; C_GRIS=$'\033[90m'
else
    C_R=""; C_B=""; C_ROJO=""; C_AMA=""; C_AZU=""; C_GRIS=""
fi

# ---------------------------------------------------------
# Utilidades
# ---------------------------------------------------------

now() { printf -v NOW '%(%s)T' -1; }

pant() { if [[ -t 1 ]]; then printf '\033[2J\033[H'; else echo; fi; }

linea() { echo "----------------------------------------"; }

titulo() {
    pant
    echo
    echo "========================================"
    printf '%*s\n' $(( (40 + ${#1}) / 2 )) "$1"
    echo "========================================"
    echo
}

pausa() { echo; read -rsn1 -p "Presione una tecla para continuar..."; echo; }

notificar() {
    command -v notify-send >/dev/null 2>&1 && notify-send "T-Minus" "$1" >/dev/null 2>&1 &
}

hhmmss() { printf '%(%H:%M:%S)T' "$1"; }

formato() {   # minutos -> TXT
    local h=$(( $1 / 60 )) r=$(( $1 % 60 ))
    TXT=""
    (( h == 1 )) && TXT="1 hora"
    (( h > 1 ))  && TXT="$h horas"
    (( r > 0 ))  && TXT="${TXT:+$TXT }$r min"
    [[ -z $TXT ]] && TXT="0 min"
}

# ---------------------------------------------------------
# Tiempos: 45, 45m, 2h, 1h30, 1h30m, 23:30
# Resultado: T_TIPO=m con T_MIN, o T_TIPO=h con T_HH y T_MM
# ---------------------------------------------------------

parse_tiempo() {
    local s=${1,,} h m
    T_TIPO=""; T_MIN=""; T_HH=""; T_MM=""
    if [[ $s =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        h=$((10#${BASH_REMATCH[1]})); m=$((10#${BASH_REMATCH[2]}))
        (( h <= 23 && m <= 59 )) || return 1
        T_TIPO=h; T_HH=$h; T_MM=$m
        return 0
    elif [[ $s =~ ^([0-9]{1,4})(m|min)?$ ]]; then
        m=$((10#${BASH_REMATCH[1]}))
    elif [[ $s =~ ^([0-9]{1,2})h$ ]]; then
        m=$(( 10#${BASH_REMATCH[1]} * 60 ))
    elif [[ $s =~ ^([0-9]{1,2})h([0-5]?[0-9])(m|min)?$ ]]; then
        m=$(( 10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]} ))
    else
        return 1
    fi
    (( m >= 1 && m <= MAX_MIN )) || return 1
    T_TIPO=m; T_MIN=$m
}

objetivo_hora() {   # HH MM -> epoch de la próxima vez que el reloj marque esa hora
    local hm t
    hm=$(printf '%02d:%02d' "$1" "$2")
    t=$(date -d "$hm" +%s) || return 1
    if (( t <= NOW )); then t=$(date -d "tomorrow $hm" +%s) || return 1; fi
    echo "$t"
}

# ---------------------------------------------------------
# Configuración (mismo formato que las demás versiones)
# ---------------------------------------------------------

ini_valor() {   # archivo clave -> imprime el valor
    local k v
    [[ -f $1 ]] || return 1
    while IFS='=' read -r k v; do
        k=${k//[$'\r ']/}; v=${v//[$'\r ']/}
        [[ $k == "$2" ]] && { printf '%s' "$v"; return 0; }
    done < "$1"
    return 1
}

cargar_presets() {
    local n v
    preset=("" "" "" "" "")
    for n in 1 2 3 4; do
        v=$(ini_valor "$PRESETS" "preset$n") || continue
        if parse_tiempo "$v" && [[ $T_TIPO == m ]]; then preset[n]=$T_MIN; fi
    done
}

guardar_presets() {
    mkdir -p "$CONFIG"
    printf 'preset%s=%s\n' 1 "${preset[1]}" 2 "${preset[2]}" 3 "${preset[3]}" 4 "${preset[4]}" > "$PRESETS"
}

cargar_ajustes() {
    local a
    a=$(ini_valor "$SETTINGS" accion) && [[ -n ${ACC_NOMBRE[$a]:-} ]] && SEL=$a
    ULTIMO=$(ini_valor "$SETTINGS" ultimo) || ULTIMO=""
}

guardar_ajustes() {
    mkdir -p "$CONFIG"
    printf 'accion=%s\nultimo=%s\n' "$SEL" "$ULTIMO" > "$SETTINGS"
}

etiqueta_ultimo() {   # imprime el texto del botón "repetir" o nada
    local u=$ULTIMO
    if [[ $u =~ ^m:([0-9]+)$ ]] && parse_tiempo "${BASH_REMATCH[1]}"; then
        formato "$T_MIN"; printf 'Repetir último: %s' "$TXT"
    elif [[ $u =~ ^h:([0-9]{2}):([0-9]{2})$ ]]; then
        printf 'Repetir último: a las %s:%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    fi
}

# ---------------------------------------------------------
# Acciones del sistema
# ---------------------------------------------------------

ejecutar_accion() {
    case $1 in
        apagar)    systemctl poweroff  || shutdown -h now ;;
        reiniciar) systemctl reboot    || shutdown -r now ;;
        suspender) systemctl suspend ;;
        hibernar)  systemctl hibernate ;;
    esac
}

# ---------------------------------------------------------
# Temporizador
# ---------------------------------------------------------

fmt_tiempo() {   # segundos -> RELOJ
    local r=$1
    if (( r >= 3600 )); then printf -v RELOJ '%d:%02d:%02d' $((r/3600)) $((r%3600/60)) $((r%60))
    else printf -v RELOJ '%02d:%02d' $((r/60)) $((r%60)); fi
}

dibujar() {
    local resta=$1 total=$(( OBJETIVO - INICIO )) ancho=32 llenos barra vacia pct color
    (( total < 1 )) && total=1
    llenos=$(( resta * ancho / total )); (( llenos > ancho )) && llenos=$ancho; (( llenos < 0 )) && llenos=0
    pct=$(( resta * 100 / total )); (( pct > 100 )) && pct=100
    printf -v barra '%*s' "$llenos" ''; barra=${barra// /#}
    printf -v vacia '%*s' $(( ancho - llenos )) ''; vacia=${vacia// /-}
    fmt_tiempo $(( resta > 0 ? resta : 0 ))

    if [[ $FASE == aviso ]]; then color=$C_ROJO
    elif (( resta <= 60 )); then color=$C_AMA
    else color=$C_AZU; fi

    if [[ $FASE == aviso ]]; then titulo "TIEMPO TERMINADO"; else titulo "${ACC_TITULO[$ACCION]}"; fi
    (( DEBUG )) && { echo "            [ MODO DEBUG ]"; echo; }

    if [[ $FASE == aviso ]]; then
        echo "  ${ACC_AVISO[$ACCION]}:"
    else
        echo "  ${ACC_FUTURO[$ACCION]} a las $(hhmmss "$OBJETIVO")"
    fi
    echo "  ${C_GRIS}Hora actual: $(hhmmss "$NOW")${C_R}"
    echo
    echo "  ${color}[${barra}${vacia}]${C_R} ${pct}%"
    echo
    echo "  ${color}${C_B}      $RELOJ${C_R}"
    echo
    if [[ -n $MSG ]] && (( NOW < MSG_HASTA )); then echo "  ${C_AMA}${MSG}${C_R}"; else echo; fi
    echo
    if [[ $FASE == aviso ]]; then
        echo "  [P] Posponer 5 min   [C] Cancelar"
    else
        echo "  [+] +5 min  [-] -5 min  [M] +15 min  [C] Cancelar"
    fi
    echo
    linea
}

avisar() {   # umbral (300 o 60)
    local txt="Queda 1 minuto"
    (( $1 == 300 )) && txt="Quedan 5 minutos"
    MSG="$txt para ${ACC_NOMBRE[$ACCION],,}"; MSG_HASTA=$(( NOW + 8 ))
    printf '\a'
    notificar "$MSG"
}

chequear_avisos() {   # segundos restantes
    local t
    for t in 300 60; do
        if (( $1 > t )); then AV[$t]=0
        elif (( ${AV[$t]:-0} == 0 )); then AV[$t]=1; avisar "$t"; fi
    done
}

ajustar() {   # delta en segundos
    local nuevo resta
    nuevo=$(( OBJETIVO + $1 )); resta=$(( nuevo - NOW ))
    if (( $1 < 0 && resta < 30 )); then
        MSG="No se puede restar más: quedaría muy poco tiempo."; MSG_HASTA=$(( NOW + 5 )); return
    fi
    (( resta > MAX_SEG )) && nuevo=$(( NOW + MAX_SEG ))
    OBJETIVO=$nuevo
}

posponer() {
    INICIO=$NOW; OBJETIVO=$(( NOW + 300 )); FASE=cuenta; AV[300]=1; AV[60]=0
    MSG=""
}

confirmar_cancelar() {
    INT_FLAG=0
    printf '\n  ¿Cancelar el temporizador? El PC NO se tocará. [s/N] '
    local r
    read -rsn1 r
    echo
    [[ ${r,,} == s ]]
}

ejecutar() {
    pant; echo; echo "  Ejecutando: ${ACC_NOMBRE[$ACCION]}..."
    if ejecutar_accion "$ACCION"; then
        case $ACCION in apagar|reiniciar) exit 0 ;; esac
        return 0
    fi
    echo; echo "  No se pudo ejecutar la acción. Puede que el sistema no la tenga habilitada."
    (( MODO_CLI )) || pausa
    return 1
}

fin_debug() {
    titulo "TIEMPO TERMINADO"
    echo "            [ MODO DEBUG ]"
    echo
    echo "  SIMULACIÓN: se habría ejecutado «${ACC_NOMBRE[$ACCION],,}»."
    echo "  El PC no ha sido tocado."
    printf '\a'
    notificar "Simulación: se habría ejecutado «${ACC_NOMBRE[$ACCION],,}»."
    (( MODO_CLI )) || pausa
}

# Cuenta regresiva. Devuelve 0 si terminó (ejecutado o simulado) y 1 si se canceló.
cuenta() {
    local resta k rc
    FASE=cuenta
    while true; do
        now
        resta=$(( OBJETIVO - NOW ))
        if (( resta <= 0 )); then
            if [[ $FASE == cuenta ]]; then
                if (( DEBUG )); then FASE=""; fin_debug; return 0; fi
                FASE=aviso; INICIO=$NOW; OBJETIVO=$(( NOW + AVISO )); MSG=""
                printf '\a'; notificar "El PC se ${ACC_NOMBRE[$ACCION],,} en $AVISO segundos."
                continue
            fi
            FASE=""; ejecutar; return 0
        fi
        [[ $FASE == cuenta ]] && chequear_avisos "$resta"
        dibujar "$resta"

        k=""
        read -rsn1 -t 1 k; rc=$?
        (( rc == 1 )) && sleep 1      # sin teclado (EOF): evitar bucle rápido
        if (( INT_FLAG )); then
            if confirmar_cancelar; then FASE=""; return 1; fi
        fi
        case ${k^^} in
            C) FASE=""; return 1 ;;
            +|=|S) [[ $FASE == cuenta ]] && ajustar 300 ;;
            -|_|R) [[ $FASE == cuenta ]] && ajustar -300 ;;
            M)   [[ $FASE == cuenta ]] && ajustar 900 ;;
            P)   [[ $FASE == aviso ]] && posponer ;;
        esac
    done
}

# $1 = segundos, $2 = texto para "repetir último" (vacío = no guardar)
arrancar() {
    local seg=$1
    ACCION=$SEL
    now; INICIO=$NOW
    (( seg > MAX_SEG )) && seg=$MAX_SEG
    OBJETIVO=$(( NOW + seg ))
    MSG=""; AV=()
    (( seg <= 300 )) && AV[300]=1
    (( seg <= 60 ))  && AV[60]=1
    if [[ -n $2 ]]; then ULTIMO=$2; fi
    guardar_ajustes
    cuenta
}

iniciar_minutos() { arrancar $(( $1 * 60 )) "m:$1"; }

iniciar_hora() {   # HH MM
    local obj
    now
    obj=$(objetivo_hora "$1" "$2") || { echo "No se pudo calcular la hora."; return 1; }
    arrancar $(( obj - NOW )) "$(printf 'h:%02d:%02d' "$1" "$2")"
}

repetir_ultimo() {
    if [[ $ULTIMO =~ ^m:([0-9]+)$ ]] && parse_tiempo "${BASH_REMATCH[1]}"; then
        iniciar_minutos "$T_MIN"
    elif [[ $ULTIMO =~ ^h:([0-9]{2}):([0-9]{2})$ ]]; then
        iniciar_hora "$((10#${BASH_REMATCH[1]}))" "$((10#${BASH_REMATCH[2]}))"
    else
        return 1
    fi
}

# ---------------------------------------------------------
# Menú (TUI)
# ---------------------------------------------------------

mostrar_preset() {   # número, tecla
    if [[ -z ${preset[$1]} ]]; then echo "  [$2]  No configurado"
    else formato "${preset[$1]}"; echo "  [$2]  $TXT"; fi
}

siguiente_accion() {
    local i
    for i in "${!ACC_ORDEN[@]}"; do
        if [[ ${ACC_ORDEN[i]} == "$SEL" ]]; then
            SEL=${ACC_ORDEN[(i + 1) % ${#ACC_ORDEN[@]}]}
            break
        fi
    done
    guardar_ajustes
}

# Resultado del temporizador -> mensaje del menú
resultado() { if (( $1 == 1 )); then MSG="Temporizador cancelado. El PC no se tocó."; MSG_HASTA=$(( 0x7fffffff )); fi; }

pedir_minutos() {   # deja el resultado en T_MIN; return 1 si se deja vacío
    local val
    echo "Formatos: 45   45m   2h   1h30      (1-$MAX_MIN minutos)"
    echo "Deje vacío para volver."
    echo
    while true; do
        read -rp "Duración: " val
        [[ -z $val ]] && return 1
        if parse_tiempo "$val" && [[ $T_TIPO == m ]]; then return 0; fi
        echo "Valor inválido."
    done
}

pedir_hora() {   # deja el resultado en T_HH y T_MM
    local val
    echo "Formato: HH:MM (24 horas). Deje vacío para volver."
    echo
    while true; do
        read -rp "Hora: " val
        [[ -z $val ]] && return 1
        if parse_tiempo "$val" && [[ $T_TIPO == h ]]; then return 0; fi
        echo "Valor inválido."
    done
}

administrar() {
    local k n
    while true; do
        cargar_presets
        titulo "PRESETS PERSONALIZADOS"
        mostrar_preset 1 1; mostrar_preset 2 2; mostrar_preset 3 3; mostrar_preset 4 4
        echo
        echo "  [1-4]  Crear / modificar ese preset"
        echo "  [E]    Eliminar preset"
        echo
        echo "  [0]    Volver"
        echo; linea; echo
        read -rsn1 -p "Seleccione una opción: " k; k=${k^^}
        case $k in
            [1-4])
                titulo "CONFIGURAR PRESET $k"
                if pedir_minutos; then preset[k]=$T_MIN; guardar_presets; echo; echo "Preset guardado."; pausa; fi ;;
            E)
                echo; echo
                read -rsn1 -p "Número de preset a eliminar (1-4): " n
                if [[ $n =~ ^[1-4]$ ]]; then preset[n]=""; guardar_presets; echo; echo "Preset eliminado."; pausa; fi ;;
            0) return ;;
        esac
    done
}

acerca() {
    titulo "T-Minus Shutdown"
    echo "       PROGRAMADOR DE APAGADO"
    echo
    echo "              Versión $VERSION (shell)"
    echo "          Autor: Patomoi"
    echo; linea; echo
    echo "Programa apagado, reinicio, suspensión o"
    echo "hibernación con una cuenta regresiva o una"
    echo "hora exacta, con presets, avisos previos y"
    echo "modo DEBUG para probar sin tocar el PC."
    echo
    echo "Ayuda de la línea de comandos: --ayuda"
    pausa
}

menu() {
    local k rep lbl
    while true; do
        cargar_presets
        titulo "T-Minus V5"
        (( DEBUG )) && { echo "        MODO DEBUG ACTIVADO"; echo "   LAS ACCIONES NO SE EJECUTARÁN"; echo; }
        echo "  Acción: ${C_B}${ACC_NOMBRE[$SEL]}${C_R}   [E] cambiar"
        echo
        echo "  RÁPIDO"
        echo "  [1] 15 min   [2] 30 min   [3] 1 hora"
        echo "  [4] 2 horas  [5] 4 horas  [6] 8 horas"
        echo
        echo "  PRESETS"
        mostrar_preset 1 7; mostrar_preset 2 8; mostrar_preset 3 9; mostrar_preset 4 A
        echo
        echo "  [B]  Tiempo personalizado"
        echo "  [C]  Hora exacta"
        echo "  [D]  Administrar presets"
        lbl=$(etiqueta_ultimo)
        if [[ -n $lbl ]]; then echo "  [R]  $lbl"; else echo "  [R]  ${C_GRIS}Repetir último: aún no hay ninguno${C_R}"; fi
        (( DEBUG )) && echo "  [G]  Modo DEBUG: ACTIVADO" || echo "  [G]  Modo DEBUG: DESACTIVADO"
        echo "  [H]  Acerca de T-Minus"
        echo "  [0]  Salir"
        echo
        if [[ -n $MSG ]]; then echo "  ${C_AMA}${MSG}${C_R}"; MSG=""; fi
        linea; echo
        read -rsn1 -p "Seleccione una opción: " k; k=${k^^}

        case $k in
            1) iniciar_minutos 15;  resultado $? ;;
            2) iniciar_minutos 30;  resultado $? ;;
            3) iniciar_minutos 60;  resultado $? ;;
            4) iniciar_minutos 120; resultado $? ;;
            5) iniciar_minutos 240; resultado $? ;;
            6) iniciar_minutos 480; resultado $? ;;
            7|8|9|A)
                case $k in 7) n=1 ;; 8) n=2 ;; 9) n=3 ;; A) n=4 ;; esac
                if [[ -n ${preset[n]} ]]; then iniciar_minutos "${preset[n]}"; resultado $?
                else MSG="Ese preset no está configurado. Use [D]."; fi ;;
            B) titulo "TIEMPO PERSONALIZADO"
               if pedir_minutos; then iniciar_minutos "$T_MIN"; resultado $?; fi ;;
            C) titulo "HORA EXACTA"
               if pedir_hora; then iniciar_hora "$T_HH" "$T_MM"; resultado $?; fi ;;
            D) administrar ;;
            E) siguiente_accion ;;
            R) repetir_ultimo; resultado $? ;;
            G) (( DEBUG )) && DEBUG=0 || DEBUG=1 ;;
            H) acerca ;;
            0) pant; exit 0 ;;
        esac
    done
}

# ---------------------------------------------------------
# Señales: advertencia ante cierre accidental
# ---------------------------------------------------------

on_int() {
    if [[ -n $FASE ]]; then INT_FLAG=1
    else [[ -t 0 ]] && stty echo 2>/dev/null; echo; exit 130; fi
}

# Al cerrar la terminal no se puede preguntar: se avisa con una notificación.
on_hup() {
    if [[ -n $FASE ]]; then notificar "Temporizador cancelado: se cerró T-Minus. El PC NO se tocará."; sleep 0.3; fi
    exit 129
}

# ---------------------------------------------------------
# Línea de comandos
# ---------------------------------------------------------

uso() {
    cat << AYUDA
T-Minus $VERSION (shell)

Uso: $0 [TIEMPO] [opciones]
  Sin argumentos abre el menú. Con TIEMPO (o --preset / --repetir)
  programa de inmediato y muestra la cuenta regresiva.

TIEMPO
  45  45m  2h  1h30  1h30m     duración (1 minuto a 12 horas)
  23:30                        hora exacta (hoy o mañana)

Opciones
  -a, --accion ACC    apagar (por defecto), reiniciar, suspender, hibernar
  -p, --preset N      usa el preset N (1-4)
  -r, --repetir       repite el último tiempo usado
  -d, --debug         simulación: nunca toca el PC
      --segundos N    duración en segundos (solo pruebas, requiere --debug)
  -h, --ayuda         muestra esta ayuda
  -v, --version       muestra la versión

Durante la cuenta: [+] +5 min  [-] -5 min  [M] +15 min  [C] cancelar
En el aviso final: [P] posponer 5 min  [C] cancelar. Ctrl+C pide confirmación.

Códigos de salida: 0 terminó, 1 cancelado, 2 argumentos inválidos.

Ejemplos
  $0 45
  $0 1h30 --accion suspender
  $0 23:30 -a apagar
  $0 --preset 2 --debug
AYUDA
}

error_args() { echo "T-Minus: $1" >&2; echo "Pruebe: $0 --ayuda" >&2; exit 2; }

main() {
    local ARG_T="" ARG_A="" ARG_P="" ARG_R=0 ARG_S="" rc=0
    cargar_presets
    cargar_ajustes

    while (( $# )); do
        case $1 in
            -h|--ayuda|--help) uso; exit 0 ;;
            -v|--version) echo "T-Minus $VERSION (shell)"; exit 0 ;;
            -d|--debug) DEBUG=1 ;;
            -r|--repetir) ARG_R=1 ;;
            -a|--accion)   (( $# >= 2 )) || error_args "falta el valor de $1"; ARG_A=$2; shift ;;
            --accion=*)    ARG_A=${1#*=} ;;
            -p|--preset)   (( $# >= 2 )) || error_args "falta el valor de $1"; ARG_P=$2; shift ;;
            --preset=*)    ARG_P=${1#*=} ;;
            --segundos)    (( $# >= 2 )) || error_args "falta el valor de $1"; ARG_S=$2; shift ;;
            --segundos=*)  ARG_S=${1#*=} ;;
            -*) error_args "opción desconocida: $1" ;;
            *) [[ -z $ARG_T ]] || error_args "sobra el argumento: $1"; ARG_T=$1 ;;
        esac
        shift
    done

    if [[ -n $ARG_A ]]; then
        ARG_A=${ARG_A,,}
        [[ -n ${ACC_NOMBRE[$ARG_A]:-} ]] || error_args "acción inválida: $ARG_A (use apagar, reiniciar, suspender o hibernar)"
        SEL=$ARG_A
    fi

    local n_modos=0
    [[ -n $ARG_T ]] && ((n_modos++)); [[ -n $ARG_P ]] && ((n_modos++)); (( ARG_R )) && ((n_modos++)); [[ -n $ARG_S ]] && ((n_modos++))
    (( n_modos > 1 )) && error_args "use solo uno entre TIEMPO, --preset, --repetir y --segundos"

    trap on_int INT
    trap on_hup HUP TERM

    if (( n_modos == 0 )); then
        [[ -n $ARG_A ]] && guardar_ajustes
        menu
        return
    fi

    MODO_CLI=1
    if [[ -n $ARG_T ]]; then
        parse_tiempo "$ARG_T" || error_args "tiempo inválido: $ARG_T (ejemplos: 45, 2h, 1h30, 23:30)"
        if [[ $T_TIPO == m ]]; then iniciar_minutos "$T_MIN"; rc=$?; else iniciar_hora "$T_HH" "$T_MM"; rc=$?; fi
    elif [[ -n $ARG_P ]]; then
        [[ $ARG_P =~ ^[1-4]$ ]] || error_args "preset inválido: $ARG_P (use 1-4)"
        [[ -n ${preset[ARG_P]} ]] || error_args "el preset $ARG_P no está configurado"
        iniciar_minutos "${preset[ARG_P]}"; rc=$?
    elif (( ARG_R )); then
        repetir_ultimo; rc=$?
        [[ -z $(etiqueta_ultimo) ]] && error_args "aún no hay un último tiempo guardado"
    else
        [[ $ARG_S =~ ^[0-9]+$ ]] && (( ARG_S >= 1 && ARG_S <= MAX_SEG )) || error_args "segundos inválidos: $ARG_S"
        (( DEBUG )) || error_args "--segundos solo se puede usar junto con --debug"
        arrancar "$ARG_S" ""; rc=$?
    fi
    (( rc == 1 )) && echo "Temporizador cancelado. El PC no se tocó."
    exit "$rc"
}

# Permite cargar el archivo con "source" para pruebas sin ejecutar main
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
