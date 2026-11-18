#!/usr/bin/env python3
"""PowerTimer 5.0 (GUI) - Programador de energia con ventana grafica.

Autor original: Patomoi.
Requiere solo Python 3 con tkinter. Funciona en Windows y Linux
(macOS: soporte basico, sin hibernar).
"""

import math
import os
import platform
import re
import subprocess
import time
import tkinter as tk
import tkinter.font as tkfont
from datetime import datetime, timedelta
from pathlib import Path
from tkinter import messagebox, simpledialog, ttk

VERSION = "5.0"
MAX_MIN = 720          # duracion maxima "dentro de..." en minutos (12 h)
MAX_SEG = 24 * 3600    # limite absoluto del tiempo restante
AVISO = 30             # segundos de aviso final antes de ejecutar la accion
AVISOS = (300, 60)     # avisos previos: a 5 min y a 1 min
RAPIDOS = [(15, "15 min"), (30, "30 min"), (60, "1 hora"),
           (120, "2 horas"), (240, "4 horas"), (480, "8 horas")]

# Paleta
BG, CARD, CARD2 = "#14161b", "#1d2027", "#272b35"
FG, MUTED = "#e8eaf0", "#8b92a3"
ACCENT, WARN, DANGER = "#4f8cff", "#ffb020", "#ff5d5d"

ACCIONES = {
    "apagar":    {"nombre": "Apagar",    "titulo": "APAGADO PROGRAMADO",
                  "futuro": "Se apagará",    "aviso": "El PC se apagará en"},
    "reiniciar": {"nombre": "Reiniciar", "titulo": "REINICIO PROGRAMADO",
                  "futuro": "Se reiniciará", "aviso": "El PC se reiniciará en"},
    "suspender": {"nombre": "Suspender", "titulo": "SUSPENSIÓN PROGRAMADA",
                  "futuro": "Se suspenderá", "aviso": "El PC se suspenderá en"},
    "hibernar":  {"nombre": "Hibernar",  "titulo": "HIBERNACIÓN PROGRAMADA",
                  "futuro": "Hibernará",     "aviso": "El PC hibernará en"},
}


# ---------------------------------------------------------
# Logica (sin interfaz)
# ---------------------------------------------------------

def config_dir() -> Path:
    if os.name == "nt":
        base = os.environ.get("APPDATA") or str(Path.home())
    else:
        base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "PowerTimer"


PRESETS_FILE = config_dir() / "presets.ini"
SETTINGS_FILE = config_dir() / "settings.ini"


def validar(texto):
    """Minutos (1..MAX_MIN) o None si el texto no es valido."""
    t = str(texto).strip()
    if not re.fullmatch(r"[0-9]{1,4}", t):
        return None
    n = int(t)
    return n if 1 <= n <= MAX_MIN else None


def formato(minutos: int) -> str:
    h, r = divmod(int(minutos), 60)
    partes = []
    if h == 1:
        partes.append("1 hora")
    elif h > 1:
        partes.append(f"{h} horas")
    if r > 0:
        partes.append(f"{r} min")
    return " ".join(partes) or "0 min"


def resumen(segundos: float) -> str:
    return formato(max(1, math.ceil(segundos / 60)))


def objetivo_hora(hh: int, mm: int, ahora=None) -> float:
    """Marca de tiempo de la proxima vez que el reloj marque hh:mm."""
    ahora = ahora or datetime.now()
    t = ahora.replace(hour=hh, minute=mm, second=0, microsecond=0)
    if t <= ahora:
        t += timedelta(days=1)
    return t.timestamp()


def _leer_ini(ruta):
    datos = {}
    try:
        for linea in Path(ruta).read_text(encoding="utf-8").splitlines():
            clave, _, valor = linea.partition("=")
            datos[clave.strip()] = valor.strip()
    except OSError:
        pass
    return datos


def _escribir_ini(ruta, pares):
    ruta = Path(ruta)
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text("".join(f"{k}={v}\n" for k, v in pares), encoding="utf-8")


def cargar_presets(ruta=None):
    """Lista de 5 elementos; los indices 1..4 son los presets (None = vacio)."""
    datos = _leer_ini(ruta or PRESETS_FILE)
    presets = [None] * 5
    for n in range(1, 5):
        presets[n] = validar(datos.get(f"preset{n}", ""))
    return presets


def guardar_presets(presets, ruta=None):
    _escribir_ini(ruta or PRESETS_FILE,
                  [(f"preset{n}", presets[n] or "") for n in range(1, 5)])


def cargar_ajustes(ruta=None):
    return _leer_ini(ruta or SETTINGS_FILE)


def guardar_ajustes(ajustes, ruta=None):
    _escribir_ini(ruta or SETTINGS_FILE, sorted(ajustes.items()))


def etiqueta_ultimo(ultimo):
    """Texto del boton 'Repetir' a partir de 'm:45' o 'h:23:30'; None si no hay."""
    if ultimo.startswith("m:") and validar(ultimo[2:]):
        return f"Repetir último: {formato(int(ultimo[2:]))}"
    m = re.fullmatch(r"h:(\d{2}):(\d{2})", ultimo)
    if m and int(m.group(1)) < 24 and int(m.group(2)) < 60:
        return f"Repetir último: a las {m.group(1)}:{m.group(2)}"
    return None


def comando_accion(accion, sistema=None):
    s = sistema or platform.system()
    if s == "Windows":
        t = {"apagar": ["shutdown", "/s", "/t", "0"],
             "reiniciar": ["shutdown", "/r", "/t", "0"],
             "hibernar": ["shutdown", "/h"],
             "suspender": ["rundll32.exe", "powrprof.dll,SetSuspendState", "0,1,0"]}
    elif s == "Darwin":
        t = {"apagar": ["osascript", "-e", 'tell application "System Events" to shut down'],
             "reiniciar": ["osascript", "-e", 'tell application "System Events" to restart'],
             "suspender": ["pmset", "sleepnow"]}
    else:
        t = {"apagar": ["systemctl", "poweroff"],
             "reiniciar": ["systemctl", "reboot"],
             "suspender": ["systemctl", "suspend"],
             "hibernar": ["systemctl", "hibernate"]}
    return t.get(accion)


def ejecutar_accion(accion):
    cmd = comando_accion(accion)
    if not cmd:
        return False
    try:
        ok = subprocess.run(cmd).returncode == 0
    except OSError:
        ok = False
    if not ok and platform.system() not in ("Windows", "Darwin"):
        alt = {"apagar": ["shutdown", "-h", "now"],
               "reiniciar": ["shutdown", "-r", "now"]}.get(accion)
        if alt:
            try:
                ok = subprocess.run(alt).returncode == 0
            except OSError:
                pass
    return ok


# ---------------------------------------------------------
# Interfaz
# ---------------------------------------------------------

RING = 280


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("PowerTimer")
        self.configure(bg=BG)
        self.resizable(False, False)
        self.protocol("WM_DELETE_WINDOW", self.al_cerrar)
        self.bind("<Escape>", lambda e: self.cancelar() if self.fase else None)

        self.fuente = self._elegir_fuente()
        self._estilos()

        self.ajustes = cargar_ajustes()
        self.presets = cargar_presets()
        accion = self.ajustes.get("accion", "apagar")
        if accion not in ACCIONES or comando_accion(accion) is None:
            accion = "apagar"

        self.v_accion = tk.StringVar(value=accion)
        self.v_tipo = tk.StringVar(value="dentro")
        self.debug = tk.BooleanVar(value=False)
        self.banner = tk.StringVar()
        self.v_estado = tk.StringVar()
        self.v_titulo = tk.StringVar()
        self.v_modo = tk.StringVar()
        self.v_sub = tk.StringVar()
        self.v_actual = tk.StringVar()
        self.v_aviso = tk.StringVar()
        self.v_boton = tk.StringVar()
        ahora = datetime.now() + timedelta(minutes=30)
        self.v_hh = tk.StringVar(value=f"{ahora.hour:02d}")
        self.v_mm = tk.StringVar(value=f"{ahora.minute:02d}")
        self.v_hint = tk.StringVar()

        self.fase = None          # None, "cuenta" o "aviso"
        self.accion = accion
        self.inicio = 0.0
        self.objetivo = 0.0
        self.job = None
        self.avisados = set()
        self.aviso_id = 0
        self.estado_id = 0

        self.f_menu = ttk.Frame(self, padding=16)
        self.f_run = ttk.Frame(self, padding=20)
        self._construir_menu()
        self._construir_cuenta()
        self.v_hh.trace_add("write", self._actualizar_hint)
        self.v_mm.trace_add("write", self._actualizar_hint)
        self._actualizar_hint()
        self.mostrar(self.f_menu)
        self._centrar()

    # ---- estilo ----------------------------------------------------

    def _elegir_fuente(self):
        disponibles = set(tkfont.families(self))
        for f in ("Segoe UI", "SF Pro Display", "Inter", "Noto Sans",
                  "Cantarell", "Ubuntu", "DejaVu Sans", "Helvetica"):
            if f in disponibles:
                return f
        return "Helvetica"

    def _estilos(self):
        F = self.fuente
        s = ttk.Style(self)
        s.theme_use("clam")
        s.configure(".", background=BG, foreground=FG, font=(F, 10),
                    bordercolor=BG, lightcolor=BG, darkcolor=BG, focuscolor=BG)
        s.configure("TFrame", background=BG)
        s.configure("Card.TFrame", background=CARD)

        s.configure("TLabel", background=BG, foreground=FG)
        s.configure("Title.TLabel", font=(F, 22, "bold"))
        s.configure("Sub.TLabel", font=(F, 12))
        s.configure("Muted.TLabel", foreground=MUTED)
        s.configure("Sec.TLabel", foreground=MUTED, font=(F, 8, "bold"))
        s.configure("Danger.TLabel", foreground=DANGER, font=(F, 10, "bold"))
        s.configure("Warn.TLabel", foreground=WARN, font=(F, 11, "bold"))
        s.configure("Card.TLabel", background=CARD)
        s.configure("CardMuted.TLabel", background=CARD, foreground=MUTED)
        s.configure("CardSec.TLabel", background=CARD, foreground=MUTED, font=(F, 8, "bold"))

        for nombre, bg, fg, act, pres in (
                ("TButton", CARD2, FG, "#323846", "#3d4455"),
                ("Accent.TButton", ACCENT, "#ffffff", "#6aa0ff", "#3b74e0"),
                ("Danger.TButton", "#3a2328", DANGER, "#4b2c33", "#5a343c")):
            s.configure(nombre, background=bg, foreground=fg, bordercolor=bg,
                        lightcolor=bg, darkcolor=bg, focuscolor=bg,
                        padding=(12, 8), relief="flat", anchor="center")
            s.map(nombre, background=[("pressed", pres), ("active", act)],
                  bordercolor=[("pressed", pres), ("active", act)],
                  lightcolor=[("pressed", pres), ("active", act)],
                  darkcolor=[("pressed", pres), ("active", act)])
        s.configure("Chip.TButton", anchor="w")

        s.configure("Seg.Toolbutton", background=CARD2, foreground=FG,
                    bordercolor=CARD2, lightcolor=CARD2, darkcolor=CARD2,
                    padding=(8, 8), relief="flat", anchor="center")
        s.map("Seg.Toolbutton",
              background=[("selected", ACCENT), ("active", "#323846")],
              foreground=[("selected", "#ffffff"), ("disabled", "#555b6b")],
              bordercolor=[("selected", ACCENT)], lightcolor=[("selected", ACCENT)],
              darkcolor=[("selected", ACCENT)])

        for w in ("TEntry", "TSpinbox"):
            s.configure(w, fieldbackground=CARD2, foreground=FG, insertcolor=FG,
                        bordercolor=CARD2, lightcolor=CARD2, darkcolor=CARD2,
                        padding=6, arrowcolor=FG, background=CARD2)
        s.configure("TCheckbutton", background=BG, foreground=FG)
        s.map("TCheckbutton", background=[("active", BG)],
              indicatorcolor=[("selected", ACCENT), ("!selected", CARD2)])

    def _centrar(self):
        self.update_idletasks()
        w, h = int(self.winfo_reqwidth()), int(self.winfo_reqheight())
        x = (int(self.winfo_screenwidth()) - w) // 2
        y = (int(self.winfo_screenheight()) - h) // 3
        self.geometry(f"+{max(0, x)}+{max(0, y)}")

    # ---- construccion: menu ---------------------------------------

    def _seccion(self, padre, texto):
        ttk.Label(padre, text=texto, style="Sec.TLabel").pack(anchor="w", pady=(12, 4))

    def _construir_menu(self):
        f = self.f_menu
        cab = ttk.Frame(f)
        cab.pack(fill="x")
        ttk.Label(cab, text="PowerTimer", style="Title.TLabel").pack(side="left")
        ttk.Label(cab, text=f"v{VERSION}", style="Muted.TLabel").pack(
            side="left", padx=(8, 0), pady=(10, 0))
        ttk.Label(f, textvariable=self.banner, style="Danger.TLabel").pack(anchor="w")

        # Accion
        self._seccion(f, "ACCIÓN")
        fila = ttk.Frame(f)
        fila.pack(fill="x")
        for clave, datos in ACCIONES.items():
            rb = ttk.Radiobutton(fila, text=datos["nombre"], value=clave,
                                 variable=self.v_accion, style="Seg.Toolbutton",
                                 command=self.al_cambiar_accion, cursor="hand2")
            rb.pack(side="left", fill="x", expand=True, padx=(0, 4))
            if comando_accion(clave) is None:
                rb.state(["disabled"])

        # Cuando
        self._seccion(f, "CUÁNDO")
        modo = ttk.Frame(f)
        modo.pack(fill="x")
        for valor, txt in (("dentro", "Dentro de…"), ("hora", "A una hora exacta")):
            ttk.Radiobutton(modo, text=txt, value=valor, variable=self.v_tipo,
                            style="Seg.Toolbutton", command=self.cambiar_tipo,
                            cursor="hand2").pack(side="left", fill="x", expand=True,
                                                 padx=(0, 4))
        self.cont = ttk.Frame(f, style="Card.TFrame", padding=10)
        self.cont.pack(fill="x", pady=(6, 0))
        self.p_dentro = ttk.Frame(self.cont, style="Card.TFrame")
        self.p_hora = ttk.Frame(self.cont, style="Card.TFrame")
        self._panel_dentro()
        self._panel_hora()
        self.p_dentro.pack(fill="x")

        self.btn_repetir = ttk.Button(f, command=self.repetir_ultimo, cursor="hand2")
        self.btn_repetir.pack(fill="x", pady=(12, 0))
        self.refrescar_repetir()

        ttk.Checkbutton(f, text="Modo DEBUG (simulación: nunca toca el PC)",
                        variable=self.debug, command=self.al_cambiar_debug,
                        cursor="hand2").pack(anchor="w", pady=(10, 2))
        ttk.Label(f, textvariable=self.v_estado, style="Muted.TLabel").pack(anchor="w")

        pie = ttk.Frame(f)
        pie.pack(fill="x", pady=(8, 0))
        ttk.Button(pie, text="Acerca de", command=self.acerca,
                   cursor="hand2").pack(side="left")
        ttk.Button(pie, text="Salir", command=self.al_cerrar,
                   cursor="hand2").pack(side="right")

    def _panel_dentro(self):
        p = self.p_dentro
        rap = ttk.Frame(p, style="Card.TFrame")
        rap.pack(fill="x")
        for i, (m, txt) in enumerate(RAPIDOS):
            ttk.Button(rap, text=txt, cursor="hand2",
                       command=lambda m=m: self.iniciar_minutos(m)
                       ).grid(row=i // 3, column=i % 3, sticky="ew", padx=3, pady=3)
        for c in range(3):
            rap.columnconfigure(c, weight=1, uniform="r")

        ttk.Label(p, text="PRESETS", style="CardSec.TLabel").pack(anchor="w", pady=(10, 2))
        self.b_presets = {}
        for n in range(1, 5):
            fila = ttk.Frame(p, style="Card.TFrame")
            fila.pack(fill="x", pady=2)
            b = ttk.Button(fila, style="Chip.TButton", cursor="hand2",
                           command=lambda n=n: self.usar_preset(n))
            b.pack(side="left", fill="x", expand=True)
            ttk.Button(fila, text="Editar", width=7, cursor="hand2",
                       command=lambda n=n: self.editar_preset(n)).pack(side="left", padx=(6, 0))
            ttk.Button(fila, text="×", width=3, cursor="hand2",
                       command=lambda n=n: self.borrar_preset(n)).pack(side="left", padx=(4, 0))
            self.b_presets[n] = b
        self.refrescar_presets()

        ttk.Label(p, text="PERSONALIZADO", style="CardSec.TLabel").pack(anchor="w", pady=(10, 2))
        fila = ttk.Frame(p, style="Card.TFrame")
        fila.pack(fill="x")
        self.e_min = ttk.Entry(fila, width=8)
        self.e_min.pack(side="left")
        self.e_min.bind("<Return>", lambda e: self.iniciar_personalizado())
        ttk.Label(fila, text=f"minutos (1-{MAX_MIN})", style="CardMuted.TLabel").pack(
            side="left", padx=8)
        ttk.Button(fila, text="Iniciar", style="Accent.TButton", cursor="hand2",
                   command=self.iniciar_personalizado).pack(side="right")

    def _panel_hora(self):
        p = self.p_hora
        ttk.Label(p, text="HORA DE EJECUCIÓN", style="CardSec.TLabel").pack(anchor="w", pady=(0, 6))
        fila = ttk.Frame(p, style="Card.TFrame")
        fila.pack(anchor="w")
        ttk.Spinbox(fila, from_=0, to=23, width=3, wrap=True, format="%02.0f",
                    textvariable=self.v_hh, font=(self.fuente, 20)).pack(side="left")
        ttk.Label(fila, text=":", style="Card.TLabel",
                  font=(self.fuente, 20, "bold")).pack(side="left", padx=4)
        ttk.Spinbox(fila, from_=0, to=59, width=3, wrap=True, format="%02.0f",
                    textvariable=self.v_mm, font=(self.fuente, 20)).pack(side="left")
        ttk.Label(p, textvariable=self.v_hint, style="CardMuted.TLabel",
                  wraplength=380).pack(anchor="w", pady=8)
        ttk.Button(p, text="Programar", style="Accent.TButton", cursor="hand2",
                   command=self.iniciar_hora_manual).pack(fill="x")

    # ---- construccion: cuenta regresiva ---------------------------

    def _construir_cuenta(self):
        f = self.f_run
        F = self.fuente
        ttk.Label(f, textvariable=self.v_titulo, style="Title.TLabel",
                  font=(F, 16, "bold")).pack()
        ttk.Label(f, textvariable=self.v_modo, style="Danger.TLabel").pack()

        self.canvas = tk.Canvas(f, width=RING, height=RING, bg=BG, highlightthickness=0)
        self.canvas.pack(pady=10)
        m = 16
        self.canvas.create_oval(m, m, RING - m, RING - m, outline=CARD2, width=14)
        self.arco = self.canvas.create_arc(m, m, RING - m, RING - m, start=90,
                                           extent=-359.9, style="arc",
                                           outline=ACCENT, width=14)
        self.txt_tiempo = self.canvas.create_text(RING // 2, RING // 2 - 8, text="00:00",
                                                  fill=FG, font=(F, 38, "bold"))
        self.txt_sub = self.canvas.create_text(RING // 2, RING // 2 + 38, text="restante",
                                               fill=MUTED, font=(F, 11))

        ttk.Label(f, textvariable=self.v_sub, style="Sub.TLabel").pack()
        ttk.Label(f, textvariable=self.v_actual, style="Muted.TLabel").pack(pady=(2, 6))
        ttk.Label(f, textvariable=self.v_aviso, style="Warn.TLabel",
                  wraplength=320, justify="center").pack(pady=(0, 6))

        self.zona = ttk.Frame(f)
        self.zona.pack(fill="x")
        self.fila_ajuste = ttk.Frame(self.zona)
        for txt, delta in (("−5 min", -300), ("+5 min", 300), ("+15 min", 900)):
            ttk.Button(self.fila_ajuste, text=txt, cursor="hand2",
                       command=lambda d=delta: self.ajustar(d)
                       ).pack(side="left", fill="x", expand=True, padx=3)
        self.fila_aviso = ttk.Frame(self.zona)
        ttk.Button(self.fila_aviso, text="Posponer 5 min", style="Accent.TButton",
                   cursor="hand2", command=self.posponer).pack(fill="x", padx=3)

        ttk.Button(f, textvariable=self.v_boton, style="Danger.TButton",
                   cursor="hand2", command=self.cancelar).pack(fill="x", pady=(10, 0))

    def mostrar(self, frame):
        for fr in (self.f_menu, self.f_run):
            fr.pack_forget()
        frame.pack(fill="both", expand=True)

    def cambiar_tipo(self):
        self.p_dentro.pack_forget()
        self.p_hora.pack_forget()
        (self.p_dentro if self.v_tipo.get() == "dentro" else self.p_hora).pack(fill="x")

    # ---- presets, ajustes, hora -----------------------------------

    def refrescar_presets(self):
        for n in range(1, 5):
            v = self.presets[n]
            self.b_presets[n].config(
                text=f"  {n}   {formato(v)}" if v else f"  {n}   No configurado")

    def usar_preset(self, n):
        if self.presets[n]:
            self.iniciar_minutos(self.presets[n])
        else:
            self.estado("Ese preset no está configurado. Use «Editar».")

    def editar_preset(self, n):
        s = simpledialog.askstring(f"Preset {n}", f"Minutos (1-{MAX_MIN}):", parent=self)
        if not s:
            return
        v = validar(s)
        if v is None:
            messagebox.showwarning("PowerTimer",
                                   f"Valor inválido. Use solo números entre 1 y {MAX_MIN}.")
            return
        self.presets[n] = v
        guardar_presets(self.presets)
        self.refrescar_presets()

    def borrar_preset(self, n):
        self.presets[n] = None
        guardar_presets(self.presets)
        self.refrescar_presets()

    def al_cambiar_accion(self):
        self.ajustes["accion"] = self.v_accion.get()
        guardar_ajustes(self.ajustes)

    def refrescar_repetir(self):
        txt = etiqueta_ultimo(self.ajustes.get("ultimo", ""))
        if txt:
            self.btn_repetir.config(text=txt)
            self.btn_repetir.state(["!disabled"])
        else:
            self.btn_repetir.config(text="Repetir último: aún no hay ninguno")
            self.btn_repetir.state(["disabled"])

    def repetir_ultimo(self):
        u = self.ajustes.get("ultimo", "")
        if u.startswith("m:") and validar(u[2:]):
            self.iniciar_minutos(int(u[2:]))
        elif re.fullmatch(r"h:\d{2}:\d{2}", u):
            self.iniciar_hora(int(u[2:4]), int(u[5:7]))

    def _leer_hora(self):
        hh, mm = int(self.v_hh.get()), int(self.v_mm.get())
        if not (0 <= hh <= 23 and 0 <= mm <= 59):
            raise ValueError
        return hh, mm

    def _actualizar_hint(self, *_):
        try:
            hh, mm = self._leer_hora()
        except ValueError:
            self.v_hint.set("Hora inválida (0-23 : 0-59).")
            return
        obj = objetivo_hora(hh, mm)
        hoy = datetime.fromtimestamp(obj).date() == datetime.now().date()
        self.v_hint.set(f"Se ejecutará {'hoy' if hoy else 'mañana'} a las "
                        f"{hh:02d}:{mm:02d} (en {resumen(obj - time.time())}).")

    def estado(self, texto):
        self.v_estado.set(texto)
        self.estado_id += 1
        i = self.estado_id
        self.after(5000, lambda: self.v_estado.set("") if self.estado_id == i else None)

    # ---- temporizador ---------------------------------------------

    def iniciar_personalizado(self):
        v = validar(self.e_min.get())
        if v is None:
            messagebox.showwarning("PowerTimer",
                                   f"Valor inválido. Use solo números entre 1 y {MAX_MIN}.")
            return
        self.iniciar_minutos(v)

    def iniciar_minutos(self, m):
        self.iniciar(m * 60, f"m:{m}")

    def iniciar_hora_manual(self):
        try:
            hh, mm = self._leer_hora()
        except ValueError:
            messagebox.showwarning("PowerTimer", "Hora inválida. Use 0-23 : 0-59.")
            return
        self.iniciar_hora(hh, mm)

    def iniciar_hora(self, hh, mm):
        seg = objetivo_hora(hh, mm) - time.time()
        self.iniciar(seg, f"h:{hh:02d}:{mm:02d}")

    def iniciar(self, segundos, ultimo):
        self.accion = self.v_accion.get()
        datos = ACCIONES[self.accion]
        self.inicio = time.time()
        self.objetivo = self.inicio + min(segundos, MAX_SEG)
        self.fase = "cuenta"
        self.avisados = {t for t in AVISOS if segundos <= t}
        self.ajustes["ultimo"] = ultimo
        self.ajustes["accion"] = self.accion
        guardar_ajustes(self.ajustes)
        self.refrescar_repetir()

        self.v_titulo.set(datos["titulo"])
        self.v_modo.set("[ MODO DEBUG ]" if self.debug.get() else "")
        self.v_sub.set(f"{datos['futuro']} a las "
                       f"{time.strftime('%H:%M:%S', time.localtime(self.objetivo))}")
        self.v_aviso.set("")
        self.v_boton.set("Cancelar temporizador")
        self.canvas.itemconfigure(self.txt_sub, text="restante")
        self._botones("cuenta")
        self.mostrar(self.f_run)
        self.tick()

    def _botones(self, fase):
        self.fila_ajuste.pack_forget()
        self.fila_aviso.pack_forget()
        (self.fila_ajuste if fase == "cuenta" else self.fila_aviso).pack(fill="x")

    def tick(self):
        if self.fase is None:
            return
        resta = self.objetivo - time.time()
        if resta <= 0:
            if self.fase == "cuenta":
                self.terminar_cuenta()
            else:
                self.ejecutar()
            return
        if self.fase == "cuenta":
            for t in AVISOS:
                if resta > t:
                    self.avisados.discard(t)
                elif t not in self.avisados:
                    self.avisados.add(t)
                    self._avisar(t)
        self._dibujar(resta)
        self.job = self.after(200, self.tick)

    def _dibujar(self, resta):
        total = max(1.0, self.objetivo - self.inicio)
        frac = max(0.0, min(1.0, resta / total))
        if self.fase == "aviso":
            color = DANGER
        elif resta <= 60:
            color = WARN
        else:
            color = ACCENT
        r = math.ceil(resta)
        if r >= 3600:
            t = f"{r // 3600}:{r % 3600 // 60:02d}:{r % 60:02d}"
        else:
            t = f"{r // 60:02d}:{r % 60:02d}"
        self.canvas.itemconfigure(self.arco, extent=-max(0.1, 359.9 * frac), outline=color)
        self.canvas.itemconfigure(self.txt_tiempo, text=t,
                                  fill=DANGER if self.fase == "aviso" else FG)
        self.v_actual.set(f"Hora actual  {time.strftime('%H:%M:%S')}")

    def _al_frente(self):
        self.deiconify()
        self.lift()
        self.attributes("-topmost", True)

    def _quitar_topmost(self):
        self.attributes("-topmost", False)

    def _avisar(self, umbral):
        nombre = ACCIONES[self.accion]["nombre"].lower()
        txt = "Quedan 5 minutos" if umbral == 300 else "Queda 1 minuto"
        self.v_aviso.set(f"{txt} para {nombre}")
        self.bell()
        self._al_frente()
        self.after(3000, lambda: self._quitar_topmost() if self.fase == "cuenta" else None)
        self.aviso_id += 1
        i = self.aviso_id
        self.after(8000, lambda: self.v_aviso.set("") if self.aviso_id == i else None)

    def ajustar(self, delta):
        if self.fase != "cuenta":
            return
        nuevo = self.objetivo + delta
        resta = nuevo - time.time()
        if delta < 0 and resta < 30:
            self.estado("No se puede restar más: quedaría muy poco tiempo.")
            return
        if resta > MAX_SEG:
            nuevo = time.time() + MAX_SEG
        self.objetivo = nuevo
        self.v_sub.set(f"{ACCIONES[self.accion]['futuro']} a las "
                       f"{time.strftime('%H:%M:%S', time.localtime(self.objetivo))}")

    def terminar_cuenta(self):
        self._al_frente()
        self.bell()
        if self.debug.get():
            self.fase = None
            self._quitar_topmost()
            nombre = ACCIONES[self.accion]["nombre"].lower()
            messagebox.showinfo("PowerTimer",
                                f"Temporizador finalizado.\n\nSIMULACIÓN: se habría "
                                f"ejecutado «{nombre}». El PC no ha sido tocado.")
            self.mostrar(self.f_menu)
            return
        self.fase = "aviso"
        self.inicio = time.time()
        self.objetivo = self.inicio + AVISO
        self.v_titulo.set("TIEMPO TERMINADO")
        self.v_sub.set(ACCIONES[self.accion]["aviso"])
        self.v_aviso.set("")
        self.v_boton.set("Cancelar")
        self.canvas.itemconfigure(self.txt_sub, text="segundos")
        self._botones("aviso")
        self.tick()

    def posponer(self):
        if self.fase != "aviso":
            return
        self.inicio = time.time()
        self.objetivo = self.inicio + 300
        self.fase = "cuenta"
        self.avisados = {300}
        datos = ACCIONES[self.accion]
        self._quitar_topmost()
        self.v_titulo.set(datos["titulo"])
        self.v_sub.set(f"{datos['futuro']} a las "
                       f"{time.strftime('%H:%M:%S', time.localtime(self.objetivo))}")
        self.v_boton.set("Cancelar temporizador")
        self.canvas.itemconfigure(self.txt_sub, text="restante")
        self._botones("cuenta")

    def ejecutar(self):
        self.fase = None
        if not ejecutar_accion(self.accion):
            self._quitar_topmost()
            messagebox.showerror("PowerTimer",
                                 "No se pudo ejecutar la acción.\n"
                                 "Puede que el sistema no la tenga habilitada "
                                 "(por ejemplo, la hibernación).")
            self.mostrar(self.f_menu)
            return
        if self.accion in ("apagar", "reiniciar"):
            self.destroy()
        else:                       # suspender / hibernar: al despertar, vuelve al menu
            self._quitar_topmost()
            self.mostrar(self.f_menu)

    def cancelar(self):
        if self.job:
            self.after_cancel(self.job)
            self.job = None
        self.fase = None
        self._quitar_topmost()
        self.mostrar(self.f_menu)
        self.estado("Temporizador cancelado. El PC no se tocará.")

    # ---- varios ----------------------------------------------------

    def al_cambiar_debug(self):
        if self.debug.get():
            self.banner.set("MODO DEBUG ACTIVADO: no se ejecutará ninguna acción")
        else:
            self.banner.set("")
            self.estado("Modo DEBUG desactivado: las acciones serán reales.")

    def acerca(self):
        messagebox.showinfo(
            "Acerca de PowerTimer",
            f"PowerTimer {VERSION}\nAutor: Patomoi\n\n"
            "Programa apagado, reinicio, suspensión o hibernación mediante una "
            "cuenta regresiva o una hora exacta, con presets, avisos previos y "
            "modo DEBUG para hacer pruebas sin tocar el PC.")

    def al_cerrar(self):
        if self.fase and not messagebox.askyesno(
                "PowerTimer",
                "Hay un temporizador en marcha.\n"
                "Si sale, se cancelará y el PC NO se tocará.\n\n¿Salir?"):
            return
        self.destroy()


if __name__ == "__main__":
    App().mainloop()
