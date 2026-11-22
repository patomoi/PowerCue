# T-Minus Shutdown

Programador de apagado y otras acciones de energía (apagar, reiniciar, suspender, hibernar).
Empezó con el nombre «proyect shutdown». Autor original: Patomoi.

Versión actual: **5.1**. Desarrollo principal en Windows; también se usa en Linux.

## Versiones

| Carpeta | Archivo | Qué es | Requisitos |
|---|---|---|---|
| `src/python/` | `tminus.pyw` | GUI en Python, versión principal y portable | Python 3 con tkinter (Windows y Linux; macOS básico, sin hibernar) |
| `src/powershell/` | `tminus.ps1` | GUI nativa de Windows (WinForms) | PowerShell 5.1. Guardar como UTF-8 con BOM y CRLF |
| `src/powershell/` | `tminus.bat` | Lanzador del `.ps1`; reenvía los argumentos | Debe estar junto a `tminus.ps1` |
| `src/batch/` | `tminus.bat` | Versión de texto para Windows (ASCII, sin tildes) | Windows |
| `src/shell/` | `tminus.sh` | Versión de texto para Linux | bash 4+ y `date` de GNU |

Las cuatro comparten sintaxis de línea de comandos y archivos de configuración.

## Funciones comunes

- Acción a elegir: apagar, reiniciar, suspender, hibernar (se recuerda la última).
- «Dentro de…»: 6 botones rápidos (15 min, 30 min, 1 h, 2 h, 4 h, 8 h), 4 presets y tiempo personalizado (hasta 720 min).
- «A una hora exacta» (hoy o mañana) y «Repetir último».
- Cuenta regresiva con progreso, ajustes −5 / +5 / +15 min y avisos a los 5 y 1 minuto.
- Aviso final de 30 s con «Posponer 5 min» y «Cancelar».
- Modo DEBUG: simula, nunca toca el PC. Siempre arranca desactivado.
- Advertencia ante un cierre accidental con un temporizador corriendo.

## Línea de comandos

Sin argumentos abre el menú o la ventana. Con TIEMPO, preset o repetir, programa de inmediato.

```
TIEMPO        45, 45m, 2h, 1h30, 1h30m (duración, 1 min a 12 h) o 23:30 (hora exacta)
--accion ACC  (-a)  apagar (por defecto), reiniciar, suspender, hibernar
--preset N    (-p)  usa el preset N (1-4)
--repetir     (-r)  repite el último tiempo
--debug       (-d)  simulación
--segundos N        duración en segundos, solo pruebas, requiere --debug
--ayuda (-h), --version (-v)
```

En PowerShell los nombres son `-Accion`, `-Preset`, `-Repetir`, `-ModoDebug`, `-Segundos`, `-Ayuda`, `-Version`.
Solo se admite uno entre TIEMPO, preset, repetir y segundos.
Códigos de salida (versiones de texto): `0` terminó, `1` cancelado, `2` argumentos inválidos.

Ejemplos:

```
./tminus.sh 1h30 --accion suspender
tminus.bat 23:30
tminus.bat -Preset 2 -ModoDebug
```

## Configuración

- Windows: `%APPDATA%\T-Minus\`
- Linux: `~/.config/T-Minus/`

`presets.ini` (`preset1=45` … `preset4=`, en minutos; vacío = sin configurar) y `settings.ini` (`accion=apagar`, `ultimo=m:45` o `ultimo=h:23:30`).



## Limitaciones conocidas

Ver [`docs/NOTAS-DE-DESARROLLO.md`](docs/NOTAS-DE-DESARROLLO.md).

## Historial

Las versiones anteriores están en [`archive/`](archive/README.md).
