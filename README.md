# PowerCue Power Management

Programador de apagado y otras acciones de energía (apagar, reiniciar, suspender, hibernar).
Historial de nombres: «proyect shutdown» → PowerTimer → PowerCue. Autor original: Patomoi.

Versión actual: **5.1**. Desarrollo principal en Windows; también se usa en Linux.

## ¿Cuál versión uso?

| Si usas… | Descarga | Cómo abrirla |
|---|---|---|
| **Windows**, sin experiencia técnica | `PowerCue-5.1-windows.zip` | Extraer todo el contenido en una carpeta y abrir `PowerCue.bat` con doble clic. Ventana gráfica; no instala nada. |
| **Windows**, si prefieres la consola | `powercue.bat` | Doble clic, o desde cmd: `powercue.bat 45`. Un solo archivo. |
| **Linux** | `powercue.sh` | `chmod +x powercue.sh` y luego `./powercue.sh`. Requiere bash 4+ y el `date` de GNU. |
| **Python** | `powercue.pyw` | Solo si ya tienes Python 3 con tkinter: `python powercue.pyw`. Funciona en Windows y Linux, pero no se recomienda para el público general: instalar Python es un paso extra. |

Los archivos de descarga están en la sección *Releases* del repositorio.
Dentro del `.zip` de Windows, el lanzador se llama `PowerCue.bat` y `powercue.ps1` va en la carpeta `lib\`;
en el repositorio (`src/powershell/`) siguen juntos como `powercue.ps1` y `powercue-gui.bat`.

La primera vez, Windows puede mostrar «Windows protegió su PC», porque los archivos no están firmados.
Pulsa «Más información» y «Ejecutar de todas formas». Cada release incluye `SHA256SUMS.txt` para verificar la descarga.

Para generar los archivos de descarga: `python tools/empaquetar.py` (deja todo en `dist/` y muestra el comando para publicarlos).

## Versiones

| Carpeta | Archivo | Qué es | Requisitos |
|---|---|---|---|
| `src/python/` | `powercue.pyw` | GUI en Python, versión principal y portable | Python 3 con tkinter (Windows y Linux; macOS básico, sin hibernar) |
| `src/powershell/` | `powercue.ps1` | GUI nativa de Windows (WinForms) | PowerShell 5.1. Guardar como UTF-8 con BOM y CRLF |
| `src/powershell/` | `powercue-gui.bat` | Lanzador del `.ps1`; reenvía los argumentos | Debe estar junto a `powercue.ps1` |
| `src/batch/` | `powercue.bat` | Versión de texto para Windows (ASCII, sin tildes) | Windows |
| `src/shell/` | `powercue.sh` | Versión de texto para Linux | bash 4+ y `date` de GNU |

Las cuatro comparten sintaxis de línea de comandos y archivos de configuración.
El lanzador de PowerShell se llama `powercue-gui.bat` para no chocar con `powercue.bat` (versión de texto).

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
./powercue.sh 1h30 --accion suspender
powercue.bat 23:30
powercue-gui.bat -Preset 2 -ModoDebug
```

## Configuración

- Windows: `%APPDATA%\PowerCue\`
- Linux: `~/.config/PowerCue/`

`presets.ini` (`preset1=45` … `preset4=`, en minutos; vacío = sin configurar) y `settings.ini` (`accion=apagar`, `ultimo=m:45` o `ultimo=h:23:30`).

## Limitaciones conocidas

Ver [`docs/NOTAS-DE-DESARROLLO.md`](docs/NOTAS-DE-DESARROLLO.md).

## Historial

Las versiones anteriores están en [`archive/`](archive/README.md).
