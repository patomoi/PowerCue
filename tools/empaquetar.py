#!/usr/bin/env python3
"""Genera los archivos de descarga de PowerCue en dist/ y muestra el comando para publicarlos.

Uso:  python tools/empaquetar.py      (en Windows también: py tools\\empaquetar.py)
Solo usa la biblioteca estándar de Python 3. Se puede ejecutar desde cualquier carpeta.
"""

import hashlib
import re
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PS1 = ROOT / "src" / "powershell" / "powercue.ps1"
BAT = ROOT / "src" / "batch" / "powercue.bat"
SH = ROOT / "src" / "shell" / "powercue.sh"
PYW = ROOT / "src" / "python" / "powercue.pyw"
LANZADOR = ROOT / "release" / "windows" / "PowerCue.bat"
LEEME = ROOT / "release" / "windows" / "LEEME.txt"
DIST = ROOT / "dist"

BOM = b"\xef\xbb\xbf"

# Cómo se declara la versión en cada programa
VERSIONES = [
    (PS1, r"^\$AppVersion\s*=\s*'([^']+)'"),
    (BAT, r'^set "VERSION=([^"]+)"'),
    (SH, r'^VERSION="([^"]+)"'),
    (PYW, r'^VERSION\s*=\s*"([^"]+)"'),
]


def error(texto):
    print(f"Error: {texto}", file=sys.stderr)
    sys.exit(1)


def rel(ruta):
    return ruta.relative_to(ROOT)


def comprobar():
    """Valida lo que las notas de desarrollo dicen que no debe perderse."""
    for f in (PS1, BAT, SH, PYW, LANZADOR, LEEME):
        if not f.is_file():
            error(f"falta {rel(f)}")
    if not PS1.read_bytes().startswith(BOM):
        error(f"{rel(PS1)} perdió el BOM UTF-8.")
    for f in (PS1, BAT, LANZADOR, LEEME):
        if b"\r\n" not in f.read_bytes():
            error(f"{rel(f)} no tiene finales de línea CRLF.")
    for f in (SH, PYW):
        if b"\r" in f.read_bytes():
            error(f"{rel(f)} tiene finales CRLF y no funcionará en Linux (debe ser LF).")


def leer_version():
    """La versión debe ser la misma en las cuatro versiones del programa."""
    encontradas = {}
    for f, patron in VERSIONES:
        m = re.search(patron, f.read_text(encoding="utf-8-sig"), re.M)
        if not m:
            error(f"no se pudo leer la versión de {rel(f)}")
        encontradas[f] = m.group(1)
    if len(set(encontradas.values())) > 1:
        detalle = ", ".join(f"{f.name}={v}" for f, v in encontradas.items())
        error(f"las versiones no coinciden: {detalle}")
    return encontradas[PS1]


def sha256(ruta):
    h = hashlib.sha256()
    with open(ruta, "rb") as f:
        for bloque in iter(lambda: f.read(65536), b""):
            h.update(bloque)
    return h.hexdigest()


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")

    comprobar()
    version = leer_version()

    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir()

    # Paquete de Windows: PowerCue.bat + LEEME.txt + lib/powercue.ps1
    zip_ruta = DIST / f"PowerCue-{version}-windows.zip"
    with zipfile.ZipFile(zip_ruta, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(LANZADOR, "PowerCue.bat")
        z.write(LEEME, "LEEME.txt")
        z.write(PS1, "lib/powercue.ps1")
        z.write(ROOT / "LICENSE", "LICENSE")

    # Versiones de un solo archivo
    for f in (BAT, SH, PYW):
        shutil.copy2(f, DIST / f.name)

    archivos = sorted(p for p in DIST.iterdir() if p.is_file())
    sumas = "".join(f"{sha256(p)}  {p.name}\n" for p in archivos)
    (DIST / "SHA256SUMS.txt").write_text(sumas, encoding="utf-8", newline="\n")

    todos = sorted(p for p in DIST.iterdir() if p.is_file())
    print(f"Versión {version}. Archivos en dist/ (todos van a la Release):")
    for p in todos:
        print(f"  {p.name:32} {p.stat().st_size:>8} bytes")

    lista = " ".join(f'"dist/{p.name}"' for p in todos)
    print("\nPara publicar, primero prueba el zip en Windows. Después, con gh instalado")
    print("y sesión iniciada (gh auth login), este comando crea la Release como borrador:\n")
    print(f'  gh release create v{version} {lista} --draft --title "PowerCue {version}" --generate-notes\n')
    print("Revisa el borrador en GitHub y publícalo desde ahí. O súbelos a mano en la web (Releases).")


if __name__ == "__main__":
    main()
