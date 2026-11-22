# PowerCue Power Management 5.1 (PowerShell + WinForms) - Autor original: Patomoi
# Solo Windows. Usa Windows PowerShell 5.1 (incluido en Windows 10/11), sin instalar nada.
# Lanzar con powercue.bat, o:  powershell -STA -ExecutionPolicy Bypass -File powercue.ps1 [opciones]
# Opciones:  powercue.ps1 -Ayuda

param(
    [Parameter(Position = 0)][string]$Tiempo = '',
    [string]$Accion = '',
    [int]$Preset = 0,
    [switch]$Repetir,
    [switch]$ModoDebug,
    [int]$Segundos = 0,
    [switch]$Ayuda,
    [switch]$Version
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

# ----------------------------------------------------------------
# Configuracion
# ----------------------------------------------------------------

$AppVersion = '5.1'
$MaxMin     = 720      # duracion maxima "dentro de..." en minutos (12 h)
$MaxSeg     = 86400    # limite absoluto del tiempo restante
$AvisoSeg   = 30       # segundos de aviso final antes de ejecutar la accion

$CfgDir       = Join-Path $env:APPDATA 'Powercue'
$PresetsFile  = Join-Path $CfgDir 'presets.ini'
$SettingsFile = Join-Path $CfgDir 'settings.ini'

$Acc = [ordered]@{
    apagar    = @{ Nombre = 'Apagar';    Titulo = 'APAGADO PROGRAMADO';     Futuro = 'Se apagará';    Aviso = 'El PC se apagará en' }
    reiniciar = @{ Nombre = 'Reiniciar'; Titulo = 'REINICIO PROGRAMADO';    Futuro = 'Se reiniciará'; Aviso = 'El PC se reiniciará en' }
    suspender = @{ Nombre = 'Suspender'; Titulo = 'SUSPENSIÓN PROGRAMADA';  Futuro = 'Se suspenderá'; Aviso = 'El PC se suspenderá en' }
    hibernar  = @{ Nombre = 'Hibernar';  Titulo = 'HIBERNACIÓN PROGRAMADA'; Futuro = 'Hibernará';     Aviso = 'El PC hibernará en' }
}

# ----------------------------------------------------------------
# Linea de comandos: 45, 45m, 2h, 1h30, 1h30m (duracion) y 23:30 (hora exacta)
# ----------------------------------------------------------------

function Parse-Tiempo([string]$t) {
    $s = $t.Trim().ToLower()
    if ($s -match '^([0-9]{1,2}):([0-9]{2})$') {
        $h = [int]$Matches[1]; $m = [int]$Matches[2]
        if ($h -le 23 -and $m -le 59) { return @{ Tipo = 'h'; HH = $h; MM = $m } }
        return $null
    }
    $min = $null
    if ($s -match '^([0-9]{1,4})(m|min)?$') { $min = [int]$Matches[1] }
    elseif ($s -match '^([0-9]{1,2})h$') { $min = [int]$Matches[1] * 60 }
    elseif ($s -match '^([0-9]{1,2})h([0-5]?[0-9])(m|min)?$') { $min = [int]$Matches[1] * 60 + [int]$Matches[2] }
    if ($null -ne $min -and $min -ge 1 -and $min -le $MaxMin) { return @{ Tipo = 'm'; Min = $min } }
    return $null
}

$TextoAyuda = @'
PowerCue Power Management 5.1 (PowerShell)

Uso:  powercue.ps1 [TIEMPO] [opciones]
  Sin argumentos abre la ventana. Con TIEMPO, -Preset o -Repetir
  la abre ya programada.

TIEMPO
  45  45m  2h  1h30  1h30m   duración (1 minuto a 12 horas)
  23:30                      hora exacta (hoy o mañana)

Opciones
  -Accion ACC    apagar (por defecto), reiniciar, suspender, hibernar
  -Preset N      usa el preset N (1-4)
  -Repetir       repite el último tiempo usado
  -ModoDebug     simulación: nunca toca el PC
  -Segundos N    duración en segundos (solo pruebas, requiere -ModoDebug)
  -Ayuda         muestra esta ayuda
  -Version       muestra la versión

Ejemplos
  powercue.bat 45
  powercue.bat 1h30 -Accion suspender
  powercue.bat 23:30
  powercue.bat -Preset 2 -ModoDebug
'@

function Salir-Con([string]$texto, [int]$codigo, [string]$icono = 'Information') {
    Write-Host $texto
    [void][System.Windows.Forms.MessageBox]::Show($texto, 'PowerCue Power Management', 'OK', $icono)
    exit $codigo
}

if ($Ayuda)   { Salir-Con $TextoAyuda 0 }
if ($Version) { Salir-Con "Powercue Power Management $AppVersion (PowerShell)" 0 }

$errArg = ''
$nModos = 0
if ($Tiempo) {
    $nModos++
    if (-not (Parse-Tiempo $Tiempo)) { $errArg = "Tiempo inválido: $Tiempo (ejemplos: 45, 2h, 1h30, 23:30)." }
}
if ($PSBoundParameters.ContainsKey('Preset')) {
    $nModos++
    if ($Preset -lt 1 -or $Preset -gt 4) { $errArg = "Preset inválido: $Preset (use 1 a 4)." }
}
if ($Repetir) { $nModos++ }
if ($PSBoundParameters.ContainsKey('Segundos')) {
    $nModos++
    if ($Segundos -lt 1 -or $Segundos -gt $MaxSeg) { $errArg = "Segundos inválidos: $Segundos (1 a $MaxSeg)." }
    elseif (-not $ModoDebug) { $errArg = '-Segundos solo se puede usar junto con -ModoDebug.' }
}
if ($Accion -and -not $Acc.Contains($Accion.ToLower())) {
    $errArg = "Acción inválida: $Accion (use apagar, reiniciar, suspender o hibernar)."
}
if (-not $errArg -and $nModos -gt 1) { $errArg = 'Use solo uno entre TIEMPO, -Preset, -Repetir y -Segundos.' }
if ($errArg) { Salir-Con ($errArg + "`nUse -Ayuda para ver las opciones.") 2 'Warning' }

# WinForms necesita STA: se relanza en una ventana oculta, conservando los argumentos
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $lista = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $PSCommandPath))
    foreach ($k in $PSBoundParameters.Keys) {
        $v = $PSBoundParameters[$k]
        if ($v -is [System.Management.Automation.SwitchParameter]) { if ($v.IsPresent) { $lista += "-$k" } }
        else { $lista += "-$k"; $lista += ('"{0}"' -f $v) }
    }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $lista
    exit
}

function Mk-Color([string]$hex) { return [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Mk-Font([double]$size, [string]$style = 'Regular') {
    return New-Object System.Drawing.Font -ArgumentList 'Segoe UI', ([single]$size), ([System.Drawing.FontStyle]$style)
}

$cBg     = Mk-Color '#14161b'
$cCard   = Mk-Color '#1d2027'
$cCard2  = Mk-Color '#272b35'
$cFg     = Mk-Color '#e8eaf0'
$cMuted  = Mk-Color '#8b92a3'
$cAccent = Mk-Color '#4f8cff'
$cWarn   = Mk-Color '#ffb020'
$cDanger = Mk-Color '#ff5d5d'

$fBase  = Mk-Font 10
$fBold  = Mk-Font 10 'Bold'
$fSec   = Mk-Font 8 'Bold'
$fTitle = Mk-Font 20 'Bold'
$fRun   = Mk-Font 14 'Bold'
$fSub   = Mk-Font 11
$fBig   = Mk-Font 16
$fReloj = Mk-Font 34 'Bold'
$fWarn  = Mk-Font 11 'Bold'

# Estado
$script:Fase        = ''          # '', 'cuenta' o 'aviso'
$script:Sel         = 'apagar'    # accion elegida en el menu
$script:Accion      = 'apagar'    # accion del temporizador en marcha
$script:ModoDebug   = $false
$script:Inicio      = [DateTime]::UtcNow
$script:Objetivo    = [DateTime]::UtcNow
$script:Avisados    = New-Object 'System.Collections.Generic.HashSet[int]'
$script:Presets     = @($null, $null, $null, $null, $null)
$script:Ultimo      = ''
$script:EstadoHasta = $null
$script:AvisoHasta  = $null
$script:TopHasta    = $null
$script:HintRef     = [DateTime]::UtcNow
$script:RingFrac    = 1.0
$script:RingColor   = $cAccent
$script:RingText    = '00:00'
$script:RingSub     = 'restante'
$script:RingTextCol = $cFg

# ----------------------------------------------------------------
# Logica
# ----------------------------------------------------------------

function Validar([string]$t) {
    $t = $t.Trim()
    if ($t -notmatch '^[0-9]{1,4}$') { return $null }
    $n = [int]$t
    if ($n -ge 1 -and $n -le $MaxMin) { return $n }
    return $null
}

function Formato([int]$m) {
    $h = [math]::Floor($m / 60)
    $r = $m % 60
    $p = @()
    if ($h -eq 1) { $p += '1 hora' } elseif ($h -gt 1) { $p += "$h horas" }
    if ($r -gt 0) { $p += "$r min" }
    if ($p.Count -eq 0) { return '0 min' }
    return ($p -join ' ')
}

function Resumen([double]$seg) {
    return (Formato ([int][math]::Max(1, [math]::Ceiling($seg / 60))))
}

# Proxima vez que el reloj marque h:m, como hora UTC
function Objetivo-Hora([int]$h, [int]$m) {
    $ahora = Get-Date
    $t = $ahora.Date.AddHours($h).AddMinutes($m)
    if ($t -le $ahora) { $t = $t.AddDays(1) }
    return $t.ToUniversalTime()
}

function Leer-Ini([string]$ruta) {
    $d = @{}
    if (Test-Path -LiteralPath $ruta) {
        foreach ($l in (Get-Content -LiteralPath $ruta -Encoding UTF8)) {
            $i = $l.IndexOf('=')
            if ($i -gt 0) { $d[$l.Substring(0, $i).Trim()] = $l.Substring($i + 1).Trim() }
        }
    }
    return $d
}

function Escribir-Ini([string]$ruta, $lineas) {
    try {
        $dir = Split-Path -Parent $ruta
        if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir) }
        Set-Content -LiteralPath $ruta -Value $lineas -Encoding ASCII
    } catch { }
}

function Cargar-Presets {
    $d = Leer-Ini $PresetsFile
    for ($n = 1; $n -le 4; $n++) {
        $v = $null
        if ($d.ContainsKey("preset$n")) { $v = Validar $d["preset$n"] }
        $script:Presets[$n] = $v
    }
}

function Guardar-Presets {
    $lineas = @()
    for ($n = 1; $n -le 4; $n++) {
        $v = $script:Presets[$n]
        if ($null -eq $v) { $v = '' }
        $lineas += "preset$n=$v"
    }
    Escribir-Ini $PresetsFile $lineas
}

function Cargar-Ajustes {
    $d = Leer-Ini $SettingsFile
    $script:Sel = 'apagar'
    if ($d.ContainsKey('accion') -and $Acc.Contains($d['accion'])) { $script:Sel = $d['accion'] }
    if ($d.ContainsKey('ultimo')) { $script:Ultimo = $d['ultimo'] }
}

function Guardar-Ajustes {
    Escribir-Ini $SettingsFile @(('accion=' + $script:Sel), ('ultimo=' + $script:Ultimo))
}

function Etiqueta-Ultimo([string]$u) {
    if ($u -match '^m:([0-9]+)$') {
        $m1 = $Matches[1]
        $v = Validar $m1
        if ($null -ne $v) { return ('Repetir último: ' + (Formato $v)) }
    }
    if ($u -match '^h:([0-9]{2}):([0-9]{2})$') {
        $h1 = [int]$Matches[1]; $m2 = [int]$Matches[2]
        if ($h1 -lt 24 -and $m2 -lt 60) { return ('Repetir último: a las {0:00}:{1:00}' -f $h1, $m2) }
    }
    return ''
}

function Ejecutar-Accion([string]$a) {
    try {
        switch ($a) {
            'apagar'    { & shutdown.exe /s /t 0 | Out-Null; return ($LASTEXITCODE -eq 0) }
            'reiniciar' { & shutdown.exe /r /t 0 | Out-Null; return ($LASTEXITCODE -eq 0) }
            'suspender' { return [bool][System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Suspend, $false, $false) }
            'hibernar'  { return [bool][System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Hibernate, $false, $false) }
        }
    } catch { return $false }
    return $false
}

# ----------------------------------------------------------------
# Utilidades de interfaz
# ----------------------------------------------------------------

function Mostrar-Mensaje([string]$texto, [string]$icono = 'Information') {
    [void][System.Windows.Forms.MessageBox]::Show($form, $texto, 'PowerCue Power Management', 'OK', $icono)
}

function Preguntar([string]$texto) {
    return ([System.Windows.Forms.MessageBox]::Show($form, $texto, 'PowerCue Power Management', 'YesNo', 'Question') -eq 'Yes')
}

function New-Lbl([string]$text, [int]$x, [int]$y, [int]$w, [int]$h, $font, $color, [string]$align = 'MiddleLeft') {
    $l = New-Object System.Windows.Forms.Label
    $l.AutoSize = $false
    $l.SetBounds($x, $y, $w, $h)
    $l.Text = $text
    $l.Font = $font
    $l.ForeColor = $color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.TextAlign = $align
    return $l
}

function New-Btn([string]$text, [int]$x, [int]$y, [int]$w, [int]$h, [string]$kind = 'normal') {
    $b = New-Object System.Windows.Forms.Button
    $b.SetBounds($x, $y, $w, $h)
    $b.Text = $text
    $b.Font = $fBase
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.UseVisualStyleBackColor = $false
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    switch ($kind) {
        'accent' {
            $b.BackColor = $cAccent; $b.ForeColor = [System.Drawing.Color]::White
            $b.FlatAppearance.MouseOverBackColor = (Mk-Color '#6aa0ff')
            $b.FlatAppearance.MouseDownBackColor = (Mk-Color '#3b74e0')
        }
        'danger' {
            $b.BackColor = (Mk-Color '#3a2328'); $b.ForeColor = $cDanger
            $b.FlatAppearance.MouseOverBackColor = (Mk-Color '#4b2c33')
            $b.FlatAppearance.MouseDownBackColor = (Mk-Color '#5a343c')
        }
        default {
            $b.BackColor = $cCard2; $b.ForeColor = $cFg
            $b.FlatAppearance.MouseOverBackColor = (Mk-Color '#323846')
            $b.FlatAppearance.MouseDownBackColor = (Mk-Color '#3d4455')
        }
    }
    return $b
}

function New-Seg([string]$text, [int]$x, [int]$y, [int]$w, [int]$h, $tag) {
    $r = New-Object System.Windows.Forms.RadioButton
    $r.Appearance = 'Button'
    $r.FlatStyle = 'Flat'
    $r.TextAlign = 'MiddleCenter'
    $r.SetBounds($x, $y, $w, $h)
    $r.Text = $text
    $r.Tag = $tag
    $r.Font = $fBase
    $r.BackColor = $cCard2
    $r.ForeColor = $cFg
    $r.UseVisualStyleBackColor = $false
    $r.FlatAppearance.BorderSize = 0
    $r.FlatAppearance.CheckedBackColor = $cAccent
    $r.FlatAppearance.MouseOverBackColor = (Mk-Color '#323846')
    $r.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $r
}

function New-Panel([int]$x, [int]$y, [int]$w, [int]$h, $color) {
    $p = New-Object System.Windows.Forms.Panel
    $p.SetBounds($x, $y, $w, $h)
    $p.BackColor = $color
    return $p
}

function Estado([string]$txt) {
    $lblEstado.Text = $txt
    $script:EstadoHasta = [DateTime]::UtcNow.AddSeconds(5)
}

# ----------------------------------------------------------------
# Construccion de la ventana
# ----------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = 'PowerCue Power Management'
$form.BackColor = $cBg
$form.ForeColor = $cFg
$form.Font = $fBase
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.KeyPreview = $true

# ---- Pagina: menu (diseno ancho: 880 x 500) ----
$pMenu = New-Panel 0 0 880 500 $cBg
$pMenu.Controls.Add((New-Lbl 'PowerCue Power Management' 16 10 190 40 $fTitle $cFg))
$pMenu.Controls.Add((New-Lbl ('v' + $AppVersion) 200 24 60 20 $fBase $cMuted))
$lblBanner = New-Lbl '' 400 20 464 20 $fBold $cDanger 'MiddleRight'
$pMenu.Controls.Add($lblBanner)

$pMenu.Controls.Add((New-Lbl 'ACCIÓN' 16 60 200 16 $fSec $cMuted))
$gAcc = New-Panel 16 78 848 36 $cBg
$pMenu.Controls.Add($gAcc)
$radAcc = @{}
$i = 0
foreach ($k in $Acc.Keys) {
    $nombreAcc = $Acc[$k].Nombre
    $r = New-Seg $nombreAcc ($i * 213) 0 209 36 $k
    $r.Add_CheckedChanged({ param($s, $e) if ($s.Checked) { $script:Sel = [string]$s.Tag; Guardar-Ajustes } })
    $gAcc.Controls.Add($r)
    $radAcc[$k] = $r
    $i++
}

# Dos tarjetas lado a lado
$pnlIzq = New-Panel 16 128 528 300 $cCard
$pnlDer = New-Panel 560 128 304 300 $cCard
$pMenu.Controls.Add($pnlIzq)
$pMenu.Controls.Add($pnlDer)

# -- tarjeta izquierda: "dentro de" --
$pDentro = New-Panel 12 12 504 276 $cCard
$pnlIzq.Controls.Add($pDentro)
$pDentro.Controls.Add((New-Lbl 'DENTRO DE…' 0 0 300 16 $fSec $cMuted))
$quick = @(@(15, '15 min'), @(30, '30 min'), @(60, '1 hora'), @(120, '2 horas'), @(240, '4 horas'), @(480, '8 horas'))
for ($i = 0; $i -lt 6; $i++) {
    $mins = $quick[$i][0]; $txt = $quick[$i][1]
    $qx = ($i % 3) * 170
    $qy = 22 + [int]([math]::Floor($i / 3)) * 40
    $b = New-Btn $txt $qx $qy 164 34
    $b.Tag = $mins
    $b.Add_Click({ param($s, $e) Iniciar-Minutos ([int]$s.Tag) })
    $pDentro.Controls.Add($b)
}
$pDentro.Controls.Add((New-Lbl 'PRESETS' 0 108 200 16 $fSec $cMuted))
$chips = New-Object 'object[]' 5
for ($n = 1; $n -le 4; $n++) {
    $cx = (($n - 1) % 2) * 258
    $cy = 128 + [int]([math]::Floor(($n - 1) / 2)) * 40
    $chip = New-Btn '' $cx $cy 142 32
    $chip.TextAlign = 'MiddleLeft'
    $chip.Padding = New-Object System.Windows.Forms.Padding -ArgumentList 8, 0, 0, 0
    $chip.Tag = $n
    $chip.Add_Click({ param($s, $e) Usar-Preset ([int]$s.Tag) })
    $pDentro.Controls.Add($chip)
    $chips[$n] = $chip

    $be = New-Btn 'Editar' ($cx + 146) $cy 56 32
    $be.Tag = $n
    $be.Add_Click({ param($s, $e) Editar-Preset ([int]$s.Tag) })
    $pDentro.Controls.Add($be)

    $bx = New-Btn '×' ($cx + 206) $cy 40 32
    $bx.Tag = $n
    $bx.Add_Click({ param($s, $e) Borrar-Preset ([int]$s.Tag) })
    $pDentro.Controls.Add($bx)
}
$pDentro.Controls.Add((New-Lbl 'PERSONALIZADO' 0 214 200 16 $fSec $cMuted))
$tbMin = New-Object System.Windows.Forms.TextBox
$tbMin.SetBounds(0, 236, 80, 28)
$tbMin.Font = (Mk-Font 12)
$tbMin.BackColor = $cCard2
$tbMin.ForeColor = $cFg
$tbMin.BorderStyle = 'FixedSingle'
$tbMin.MaxLength = 4
$tbMin.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Return') { $e.SuppressKeyPress = $true; Iniciar-Personalizado } })
$pDentro.Controls.Add($tbMin)
$pDentro.Controls.Add((New-Lbl ('minutos (1-{0})' -f $MaxMin) 90 236 200 28 $fBase $cMuted))
$btnIni = New-Btn 'Iniciar' 404 234 100 34 'accent'
$btnIni.Add_Click({ Iniciar-Personalizado })
$pDentro.Controls.Add($btnIni)

# -- tarjeta derecha: hora exacta y repetir --
$pHora = New-Panel 12 12 280 276 $cCard
$pnlDer.Controls.Add($pHora)
$pHora.Controls.Add((New-Lbl 'A UNA HORA EXACTA' 0 0 280 16 $fSec $cMuted))
$lblHint = New-Lbl '' 0 74 280 44 $fBase $cMuted 'TopLeft'
$cbH = New-Object System.Windows.Forms.ComboBox
$cbM = New-Object System.Windows.Forms.ComboBox
foreach ($cb in @($cbH, $cbM)) {
    $cb.DropDownStyle = 'DropDownList'
    $cb.FlatStyle = 'Flat'
    $cb.BackColor = $cCard2
    $cb.ForeColor = $cFg
    $cb.Font = $fBig
    $cb.Width = 80
    $cb.DropDownHeight = 220
}
$cbH.Location = New-Object System.Drawing.Point -ArgumentList 0, 26
$cbM.Location = New-Object System.Drawing.Point -ArgumentList 104, 26
for ($i = 0; $i -lt 24; $i++) { [void]$cbH.Items.Add(('{0:00}' -f $i)) }
for ($i = 0; $i -lt 60; $i++) { [void]$cbM.Items.Add(('{0:00}' -f $i)) }
$t30 = (Get-Date).AddMinutes(30)
$cbH.SelectedIndex = $t30.Hour
$cbM.SelectedIndex = $t30.Minute
$pHora.Controls.Add($cbH)
$pHora.Controls.Add((New-Lbl ':' 84 26 18 32 $fBig $cFg 'MiddleCenter'))
$pHora.Controls.Add($cbM)
$pHora.Controls.Add($lblHint)
$btnProg = New-Btn 'Programar' 0 124 280 38 'accent'
$btnProg.Add_Click({ Iniciar-Hora-Manual })
$pHora.Controls.Add($btnProg)
$pHora.Controls.Add((New-Lbl 'REPETIR' 0 184 200 16 $fSec $cMuted))
$btnRep = New-Btn '' 0 206 280 38
$btnRep.Add_Click({ Repetir-Ultimo })
$pHora.Controls.Add($btnRep)
$cbH.Add_SelectedIndexChanged({ Actualizar-Hint })
$cbM.Add_SelectedIndexChanged({ Actualizar-Hint })

# -- pie del menu --
$chkDebug = New-Object System.Windows.Forms.CheckBox
$chkDebug.SetBounds(16, 440, 520, 24)
$chkDebug.Text = 'Modo DEBUG (simulación: nunca toca el PC)'
$chkDebug.ForeColor = $cFg
$chkDebug.BackColor = $cBg
$chkDebug.Cursor = [System.Windows.Forms.Cursors]::Hand
$chkDebug.Add_CheckedChanged({
    $script:ModoDebug = $chkDebug.Checked
    if ($script:ModoDebug) { $lblBanner.Text = 'MODO DEBUG ACTIVADO: no se ejecutará ninguna acción' }
    else { $lblBanner.Text = ''; Estado 'Modo DEBUG desactivado: las acciones serán reales.' }
})
$pMenu.Controls.Add($chkDebug)
$lblEstado = New-Lbl '' 16 468 640 20 $fBase $cMuted
$pMenu.Controls.Add($lblEstado)
$btnAcerca = New-Btn 'Acerca de' 664 436 96 32
$btnAcerca.Add_Click({
    Mostrar-Mensaje ("PowerCue Power Management $AppVersion (PowerShell)`nAutor: Patomoi`n`nPrograma apagado, reinicio, suspensión o hibernación mediante una cuenta regresiva o una hora exacta, con presets, avisos previos y modo DEBUG para hacer pruebas sin tocar el PC.")
})
$pMenu.Controls.Add($btnAcerca)
$btnSalir = New-Btn 'Salir' 768 436 96 32
$btnSalir.Add_Click({ $form.Close() })
$pMenu.Controls.Add($btnSalir)

# ---- Pagina: cuenta regresiva (diseno ancho: 700 x 328) ----
$pRun = New-Panel 0 0 700 328 $cBg
$pRun.Visible = $false
$ring = New-Object System.Windows.Forms.Panel
$ring.SetBounds(24, 24, 280, 280)
$ring.BackColor = $cBg
$ring.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic').SetValue($ring, $true, $null)

$lblTitulo = New-Lbl '' 330 24 346 30 $fRun $cFg 'MiddleLeft'
$lblModo   = New-Lbl '' 330 56 346 20 $fBold $cDanger 'MiddleLeft'
$lblSub    = New-Lbl '' 330 92 346 26 $fSub $cFg 'MiddleLeft'
$lblActual = New-Lbl '' 330 120 346 20 $fBase $cMuted 'MiddleLeft'
$lblAviso  = New-Lbl '' 330 150 346 44 $fWarn $cWarn 'TopLeft'

$ajBtns = @()
$ajDefs = @(@('−5 min', -300), @('+5 min', 300), @('+15 min', 900))
for ($i = 0; $i -lt 3; $i++) {
    $ajTxt = $ajDefs[$i][0]; $ajDelta = $ajDefs[$i][1]
    $b = New-Btn $ajTxt (330 + $i * 118) 204 110 36
    $b.Tag = $ajDelta
    $b.Add_Click({ param($s, $e) Ajustar ([int]$s.Tag) })
    $ajBtns += $b
}
$btnPosponer = New-Btn 'Posponer 5 min' 330 204 346 36 'accent'
$btnPosponer.Visible = $false
$btnPosponer.Add_Click({ Posponer })
$btnCancel = New-Btn 'Cancelar temporizador' 330 254 346 44 'danger'
$btnCancel.Add_Click({ Cancelar })

foreach ($c in @($lblTitulo, $lblModo, $ring, $lblSub, $lblActual, $lblAviso, $btnPosponer, $btnCancel)) { $pRun.Controls.Add($c) }
foreach ($c in $ajBtns) { $pRun.Controls.Add($c) }

$ring.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $rect = New-Object System.Drawing.Rectangle -ArgumentList 16, 16, 248, 248
    $pen = New-Object System.Drawing.Pen -ArgumentList $cCard2, ([single]14)
    $g.DrawEllipse($pen, $rect)
    $pen.Color = $script:RingColor
    if ($script:RingFrac -ge 0.999) { $g.DrawEllipse($pen, $rect) }
    elseif ($script:RingFrac -gt 0) { $g.DrawArc($pen, $rect, [single](-90), [single](360 * $script:RingFrac)) }
    $pen.Dispose()
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $b1 = New-Object System.Drawing.SolidBrush -ArgumentList $script:RingTextCol
    $b2 = New-Object System.Drawing.SolidBrush -ArgumentList $cMuted
    $g.DrawString($script:RingText, $fReloj, $b1, (New-Object System.Drawing.RectangleF -ArgumentList 0, 98, 280, 60), $sf)
    $g.DrawString($script:RingSub, $fSub, $b2, (New-Object System.Drawing.RectangleF -ArgumentList 0, 152, 280, 30), $sf)
    $b1.Dispose(); $b2.Dispose(); $sf.Dispose()
})

$form.Controls.Add($pMenu)
$form.Controls.Add($pRun)

# ----------------------------------------------------------------
# Comportamiento
# ----------------------------------------------------------------

function Refrescar-Presets {
    for ($n = 1; $n -le 4; $n++) {
        $v = $script:Presets[$n]
        if ($null -ne $v) { $chips[$n].Text = ('{0}    {1}' -f $n, (Formato $v)) }
        else { $chips[$n].Text = ('{0}    No configurado' -f $n) }
    }
}

function Refrescar-Repetir {
    $txt = Etiqueta-Ultimo $script:Ultimo
    if ($txt) { $btnRep.Text = $txt; $btnRep.Enabled = $true }
    else { $btnRep.Text = 'Repetir último: aún no hay ninguno'; $btnRep.Enabled = $false }
}

function Usar-Preset([int]$n) {
    $v = $script:Presets[$n]
    if ($null -ne $v) { Iniciar-Minutos $v } else { Estado 'Ese preset no está configurado. Use «Editar».' }
}

function Editar-Preset([int]$n) {
    $s = [Microsoft.VisualBasic.Interaction]::InputBox(('Minutos (1-{0}):' -f $MaxMin), "Preset $n", '')
    if ([string]::IsNullOrWhiteSpace($s)) { return }
    $v = Validar $s
    if ($null -eq $v) { Mostrar-Mensaje ('Valor inválido. Use solo números entre 1 y {0}.' -f $MaxMin) 'Warning'; return }
    $script:Presets[$n] = $v
    Guardar-Presets
    Refrescar-Presets
}

function Borrar-Preset([int]$n) {
    $script:Presets[$n] = $null
    Guardar-Presets
    Refrescar-Presets
}

function Repetir-Ultimo {
    $u = $script:Ultimo
    if ($u -match '^m:([0-9]+)$') {
        $m1 = $Matches[1]
        $v = Validar $m1
        if ($null -ne $v) { Iniciar-Minutos $v }
    }
    elseif ($u -match '^h:([0-9]{2}):([0-9]{2})$') {
        $h1 = [int]$Matches[1]; $m2 = [int]$Matches[2]
        Iniciar-Hora $h1 $m2
    }
}

function Actualizar-Hint {
    if ($cbH.SelectedIndex -lt 0 -or $cbM.SelectedIndex -lt 0) { return }
    $h = $cbH.SelectedIndex
    $m = $cbM.SelectedIndex
    $obj = Objetivo-Hora $h $m
    $dia = 'mañana'
    if ($obj.ToLocalTime().Date -eq (Get-Date).Date) { $dia = 'hoy' }
    $dentro = Resumen (($obj - [DateTime]::UtcNow).TotalSeconds)
    $lblHint.Text = ('Se ejecutará {0} a las {1:00}:{2:00} (en {3}).' -f $dia, $h, $m, $dentro)
}

function Mostrar([string]$pagina) {
    if ($pagina -eq 'menu') {
        $pRun.Visible = $false
        $pMenu.Visible = $true
        $form.ClientSize = New-Object System.Drawing.Size -ArgumentList 880, 500
        Actualizar-Hint
    } else {
        $pMenu.Visible = $false
        $pRun.Visible = $true
        $form.ClientSize = New-Object System.Drawing.Size -ArgumentList 700, 328
    }
}

function Botones([string]$fase) {
    $esCuenta = ($fase -eq 'cuenta')
    foreach ($b in $ajBtns) { $b.Visible = $esCuenta }
    $btnPosponer.Visible = (-not $esCuenta)
}

function Poner-Sub {
    $d = $Acc[$script:Accion]
    $hora = $script:Objetivo.ToLocalTime().ToString('HH:mm:ss')
    $lblSub.Text = ('{0} a las {1}' -f $d.Futuro, $hora)
}

function Iniciar-Personalizado {
    $v = Validar $tbMin.Text
    if ($null -eq $v) { Mostrar-Mensaje ('Valor inválido. Use solo números entre 1 y {0}.' -f $MaxMin) 'Warning'; return }
    Iniciar-Minutos $v
}

function Iniciar-Minutos([int]$m) {
    Iniciar ($m * 60) ('m:' + $m)
}

function Iniciar-Hora([int]$h, [int]$m) {
    $obj = Objetivo-Hora $h $m
    $seg = ($obj - [DateTime]::UtcNow).TotalSeconds
    Iniciar $seg ('h:{0:00}:{1:00}' -f $h, $m)
}

function Iniciar-Hora-Manual {
    Iniciar-Hora ([int]$cbH.SelectedIndex) ([int]$cbM.SelectedIndex)
}

function Iniciar([double]$seg, [string]$ultimo) {
    $script:Accion = $script:Sel
    $d = $Acc[$script:Accion]
    $script:Inicio = [DateTime]::UtcNow
    $script:Objetivo = $script:Inicio.AddSeconds([math]::Min($seg, $MaxSeg))
    $script:Fase = 'cuenta'
    $script:Avisados.Clear()
    foreach ($t in @(300, 60)) { if ($seg -le $t) { [void]$script:Avisados.Add([int]$t) } }
    if ($ultimo) { $script:Ultimo = $ultimo }
    Guardar-Ajustes
    Refrescar-Repetir

    $lblTitulo.Text = $d.Titulo
    if ($script:ModoDebug) { $lblModo.Text = '[ MODO DEBUG ]' } else { $lblModo.Text = '' }
    Poner-Sub
    $lblAviso.Text = ''
    $btnCancel.Text = 'Cancelar temporizador'
    $script:RingSub = 'restante'
    Botones 'cuenta'
    Mostrar 'run'
    Tick
}

function Al-Frente {
    $form.WindowState = 'Normal'
    $form.TopMost = $true
    $form.Activate()
}

function Avisar([int]$t) {
    $nom = $Acc[$script:Accion].Nombre.ToLower()
    if ($t -eq 300) { $txt = 'Quedan 5 minutos' } else { $txt = 'Queda 1 minuto' }
    $lblAviso.Text = ('{0} para {1}' -f $txt, $nom)
    [System.Media.SystemSounds]::Exclamation.Play()
    Al-Frente
    $script:TopHasta = [DateTime]::UtcNow.AddSeconds(3)
    $script:AvisoHasta = [DateTime]::UtcNow.AddSeconds(8)
}

function Dibujar([double]$resta) {
    $total = [math]::Max(1.0, ($script:Objetivo - $script:Inicio).TotalSeconds)
    $script:RingFrac = [math]::Max(0.0, [math]::Min(1.0, $resta / $total))
    $script:RingTextCol = $cFg
    if ($script:Fase -eq 'aviso') { $script:RingColor = $cDanger; $script:RingTextCol = $cDanger }
    elseif ($resta -le 60) { $script:RingColor = $cWarn }
    else { $script:RingColor = $cAccent }
    $r = [int][math]::Ceiling($resta)
    if ($r -ge 3600) {
        $script:RingText = ('{0}:{1:00}:{2:00}' -f ([math]::Floor($r / 3600)), ([math]::Floor(($r % 3600) / 60)), ($r % 60))
    } else {
        $script:RingText = ('{0:00}:{1:00}' -f ([math]::Floor($r / 60)), ($r % 60))
    }
    $lblActual.Text = 'Hora actual  ' + (Get-Date).ToString('HH:mm:ss')
    $ring.Invalidate()
}

function Tick {
    $ahora = [DateTime]::UtcNow
    if ($script:EstadoHasta -and $ahora -gt $script:EstadoHasta) { $lblEstado.Text = ''; $script:EstadoHasta = $null }
    if ($script:AvisoHasta -and $ahora -gt $script:AvisoHasta) { $lblAviso.Text = ''; $script:AvisoHasta = $null }
    if ($script:TopHasta -and $ahora -gt $script:TopHasta) {
        if ($script:Fase -eq 'cuenta') { $form.TopMost = $false }
        $script:TopHasta = $null
    }
    if ($pMenu.Visible -and $ahora -gt $script:HintRef) { Actualizar-Hint; $script:HintRef = $ahora.AddSeconds(15) }
    if (-not $script:Fase) { return }

    $resta = ($script:Objetivo - $ahora).TotalSeconds
    if ($resta -le 0) {
        if ($script:Fase -eq 'cuenta') { Terminar-Cuenta } else { Ejecutar }
        return
    }
    if ($script:Fase -eq 'cuenta') {
        foreach ($t in @(300, 60)) {
            if ($resta -gt $t) { [void]$script:Avisados.Remove([int]$t) }
            elseif (-not $script:Avisados.Contains([int]$t)) {
                [void]$script:Avisados.Add([int]$t)
                Avisar $t
            }
        }
    }
    Dibujar $resta
}

function Ajustar([int]$delta) {
    if ($script:Fase -ne 'cuenta') { return }
    $nuevo = $script:Objetivo.AddSeconds($delta)
    $resta = ($nuevo - [DateTime]::UtcNow).TotalSeconds
    if ($delta -lt 0 -and $resta -lt 30) { Estado 'No se puede restar más: quedaría muy poco tiempo.'; return }
    if ($resta -gt $MaxSeg) { $nuevo = [DateTime]::UtcNow.AddSeconds($MaxSeg) }
    $script:Objetivo = $nuevo
    Poner-Sub
}

function Terminar-Cuenta {
    Al-Frente
    [System.Media.SystemSounds]::Exclamation.Play()
    if ($script:ModoDebug) {
        $script:Fase = ''
        $form.TopMost = $false
        $nom = $Acc[$script:Accion].Nombre.ToLower()
        Mostrar-Mensaje ("Temporizador finalizado.`n`nSIMULACIÓN: se habría ejecutado «$nom». El PC no ha sido tocado.")
        Mostrar 'menu'
        return
    }
    $script:Fase = 'aviso'
    $script:Inicio = [DateTime]::UtcNow
    $script:Objetivo = $script:Inicio.AddSeconds($AvisoSeg)
    $lblTitulo.Text = 'TIEMPO TERMINADO'
    $lblSub.Text = $Acc[$script:Accion].Aviso
    $lblAviso.Text = ''
    $btnCancel.Text = 'Cancelar'
    $script:RingSub = 'segundos'
    Botones 'aviso'
    Tick
}

function Posponer {
    if ($script:Fase -ne 'aviso') { return }
    $script:Inicio = [DateTime]::UtcNow
    $script:Objetivo = $script:Inicio.AddSeconds(300)
    $script:Fase = 'cuenta'
    $script:Avisados.Clear()
    [void]$script:Avisados.Add(300)
    $form.TopMost = $false
    $lblTitulo.Text = $Acc[$script:Accion].Titulo
    Poner-Sub
    $btnCancel.Text = 'Cancelar temporizador'
    $script:RingSub = 'restante'
    Botones 'cuenta'
}

function Ejecutar {
    $script:Fase = ''
    $ok = Ejecutar-Accion $script:Accion
    if (-not $ok) {
        $form.TopMost = $false
        Mostrar-Mensaje ("No se pudo ejecutar la acción.`nPuede que el sistema no la tenga habilitada (por ejemplo, la hibernación).") 'Error'
        Mostrar 'menu'
        return
    }
    if ($script:Accion -eq 'apagar' -or $script:Accion -eq 'reiniciar') { $form.Close() }
    else { $form.TopMost = $false; Mostrar 'menu' }
}

function Cancelar {
    if (-not $script:Fase) { return }
    $script:Fase = ''
    $form.TopMost = $false
    Mostrar 'menu'
    Estado 'Temporizador cancelado. El PC no se tocará.'
}

function Arranque-Args {
    if ($Segundos -gt 0) { Iniciar $Segundos ''; return }
    if ($Preset -ge 1 -and $Preset -le 4) {
        $v = $script:Presets[$Preset]
        if ($null -ne $v) { Iniciar-Minutos $v }
        else { Mostrar-Mensaje ("El preset {0} no está configurado." -f $Preset) 'Warning' }
        return
    }
    if ($Repetir) {
        if (Etiqueta-Ultimo $script:Ultimo) { Repetir-Ultimo }
        else { Mostrar-Mensaje 'Aún no hay un último tiempo guardado.' }
        return
    }
    if ($Tiempo) {
        $t = Parse-Tiempo $Tiempo
        if ($t.Tipo -eq 'm') { Iniciar-Minutos $t.Min } else { Iniciar-Hora $t.HH $t.MM }
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    try { Tick }
    catch { $lblEstado.Text = 'Error: ' + $_.Exception.Message }
})

$form.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape' -and $script:Fase) { Cancelar } })
$form.Add_FormClosing({
    param($s, $e)
    if ($script:Fase) {
        if (-not (Preguntar "Hay un temporizador en marcha.`nSi sale, se cancelará y el PC NO se tocará.`n`n¿Salir?")) { $e.Cancel = $true }
    }
})

# ----------------------------------------------------------------
# Arranque
# ----------------------------------------------------------------

Cargar-Presets
Cargar-Ajustes
Refrescar-Presets
Refrescar-Repetir
if ($Accion) { $script:Sel = $Accion.ToLower() }
$radAcc[$script:Sel].Checked = $true
if ($ModoDebug) { $chkDebug.Checked = $true }
Mostrar 'menu'
$form.Add_Shown({ Arranque-Args })
$timer.Start()
[void][System.Windows.Forms.Application]::Run($form)
