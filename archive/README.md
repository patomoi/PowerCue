# Historial de desarrollo

Versiones anteriores, solo como referencia. No se mantienen.
Los archivos con nombre «PowerTimer» son anteriores al cambio de nombre a PowerCue y usan la carpeta de configuración `PowerTimer`.

| Carpeta | Archivo | Notas |
|---|---|---|
| `01-shutdown/` | `ShutdownV1.bat` | Primer temporizador: menú fijo y cuenta regresiva |
| | `ShutdownV2.bat` | Añade presets (`presets.ini` en `%APPDATA%\ApagadoProgramado`) |
| `02-powertimer-batch/` | `PowerTimerV1.bat` | Igual que `ShutdownV2.bat`, con el título «POWERTIMER» |
| | `PowerTimerV2.bat` | Carpeta de configuración `%APPDATA%\PowerTimer`; menú rediseñado |
| | `PowerTimerV3.bat` | Añade modo DEBUG |
| | `PowerTimerV4.bat` | «Versión 4» |
| | `PowerTimerV4_1.bat` | «Versión 4.0» con `MAX_MIN` y `AVISO` configurables |
| | `PowerTimer_cli.bat` | Versión 5.1 de texto (menú + línea de comandos), con el nombre PowerTimer |
| `03-python/` | `powertimer_gui_v5.0.pyw` | GUI en Python, versión 5.0 (antes del rediseño ancho y de la 5.1) |
| | `powertimer_gui.pyw` | GUI en Python, versión 5.1, con el nombre PowerTimer |
| `04-powershell/` | `PowerTimer.ps1`, `PowerTimer.bat` | GUI de PowerShell 5.1 y su lanzador, con el nombre PowerTimer |
| `05-shell/` | `powertimer.sh` | Versión de shell 5.1, con el nombre PowerTimer |

`PowerTimerV2.bat` y `PowerTimerV3.bat` venían con vallas de código markdown (```` ```bat ````) pegadas
al principio y al final; se quitaron porque impedían ejecutarlos. El resto del contenido está intacto.
