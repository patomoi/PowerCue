# Historial de desarrollo

Versiones anteriores, solo como referencia. No se mantienen.

| Carpeta | Archivo | Notas |
|---|---|---|
| `01-shutdown/` | `ShutdownV1.bat` | Primer temporizador: menú fijo y cuenta regresiva |
| | `ShutdownV2.bat` | Añade presets (`presets.ini` en `%APPDATA%\ApagadoProgramado`) |
| `02-powertimer-batch/` | `PowerTimerV1.bat` | Igual que `ShutdownV2.bat`, con el título «POWERTIMER» |
| | `PowerTimerV2.bat` | Carpeta de configuración `%APPDATA%\PowerTimer`; menú rediseñado |
| | `PowerTimerV3.bat` | Añade modo DEBUG |
| | `PowerTimerV4.bat` | «Versión 4» |
| | `PowerTimerV4_1.bat` | «Versión 4.0» con `MAX_MIN` y `AVISO` configurables |
| `03-python/` | `powertimer_gui_v5.0.pyw` | GUI en Python, versión 5.0 (antes del rediseño ancho y de la 5.1) |

`PowerTimerV2.bat` y `PowerTimerV3.bat` venían con vallas de código markdown (```` ```bat ````) pegadas
al principio y al final; se quitaron porque impedían ejecutarlos. El resto del contenido está intacto.
