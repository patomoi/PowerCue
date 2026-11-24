# Notas de desarrollo

## Decisiones tomadas

- Python (tkinter) es la versión principal y portable.
- PowerShell + WinForms es la versión gráfica nativa de Windows, sin instalar nada.
- `.bat` y `.sh` son versiones de texto: menú sin argumentos y línea de comandos con argumentos (modo híbrido).
- Tcl/Tk descartada: era prácticamente igual a la de Python.
- El temporizador no sobrevive al cierre de la ventana o terminal (se quiere feedback); en su lugar hay advertencia ante cierre accidental.
- Ventanas más anchas que altas (la versión alta se cortaba en pantalla). PowerShell: 880×500 (menú) y 700×328 (cuenta).
- Número de versión unificado en todas.
- Nombre: «proyect shutdown» → PowerTimer → PowerCue. En las ventanas, «PowerCue» es el título y «Power Management» un subtítulo; el título de la ventana y los diálogos usan «PowerCue Power Management».
- La carpeta de configuración se llama `PowerCue` (mismo casing en las cuatro versiones; en Linux importa). No se migran los presets de la carpeta `PowerTimer`.
- El lanzador de PowerShell es `powercue-gui.bat`, para no chocar con `powercue.bat` (versión de texto).
- Paquete de descarga: el zip de Windows lleva PowerCue.bat en la raíz y powercue.ps1 en lib\; se genera con python tools/empaquetar.py (deja todo en dist/).

## Advertencia al cerrar con un temporizador corriendo

- Python y PowerShell: preguntan antes de cerrar. Python también atiende Ctrl+C.
- `.sh`: Ctrl+C pide confirmación; si se cierra la terminal manda una notificación de escritorio (`notify-send`).
- `.bat`: Ctrl+C muestra la pregunta propia de cmd; la X de la ventana no se puede interceptar.

## Teclas en las versiones de texto

- Menú: `1`–`6` rápidos, `7 8 9 A` presets 1–4, `B` personalizado, `C` hora exacta, `D` administrar presets, `E` cambiar acción, `R` repetir último, `G` DEBUG, `H` acerca de, `0` salir.
- Cuenta: `C` cancelar, `+`/`S` suma 5 min, `-`/`R` resta 5 min, `M` suma 15 min (en `.bat` se usan `S`, `R`, `M`).
- Aviso final: `P` posponer 5 min, `C` cancelar.

## Pendientes

- comprobar todas las versiones con testeos reales exaustivos, al momento los test han pasado OK 
- ver si se pueden juntar las cersiones de powershell, quiza en un exe
- ver si se puede hacer un paquete de la version de python

## Limitaciones conocidas

- `.bat`: usa solo la hora del reloj, así que un cambio de horario de verano durante la cuenta la desplaza una hora; una espera mayor a unas 23 h 50 min se acorta unos minutos; sin tildes.
- Windows: «Suspender» puede hibernar si la hibernación está activada, y «Hibernar» falla si está desactivada (`powercfg /hibernate on`).
- PowerShell no ajusta el escalado en pantallas de alta resolución (puede verse algo borroso).
- macOS: soporte básico en la versión de Python (sin hibernar), sin probar.

## Codificación y finales de línea

`.gitattributes` fuerza CRLF en `.bat` y `.ps1`, y LF en `.sh`, `.py` y `.pyw`.
`powercue.ps1` debe conservar UTF-8 **con BOM**: git no lo quita, pero algunos editores sí al guardar.
Para que el `.sh` quede ejecutable en el repo: `git update-index --chmod=+x src/shell/powercue.sh`.
