#!/usr/bin/env bash
# Exportación reproducible de Vaelmoor para Linux x86_64.
#
# Variables:
#   GODOT           Editor de Godot 4.7.x (por defecto: godot4/godot del PATH)
#   GODOT_TEMPLATE  Plantilla release propia (opcional). Si no se indica se usan
#                   las plantillas instaladas en ~/.local/share/godot/export_templates/
#   OUT_DIR         Carpeta de salida (por defecto build/linux)
#
# Resultado: $OUT_DIR/vaelmoor.x86_64 + $OUT_DIR/vaelmoor.pck
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-$(command -v godot4 || command -v godot || true)}"
OUT_DIR="${OUT_DIR:-build/linux}"
if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
  echo "ERROR: no se encontró el editor de Godot. Usa GODOT=/ruta/al/editor $0" >&2
  exit 1
fi
GVER="$("$GODOT" --version | head -n1)"
echo ">> Godot: $GVER"
case "$GVER" in
  4.7.*) ;;
  *) echo "AVISO: el proyecto está hecho para Godot 4.7.x (detectado $GVER)." >&2 ;;
esac
# Carpeta de plantillas: "4.7.2.stable" (sin el sufijo de compilación)
TPL_VER="$(echo "$GVER" | cut -d. -f1-4)"
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TPL_VER"
if [ -n "${GODOT_TEMPLATE:-}" ]; then
  mkdir -p "$TPL_DIR"
  install -m 755 "$GODOT_TEMPLATE" "$TPL_DIR/linux_release.x86_64"
  # El exportador exige que exista también la plantilla de depuración.
  [ -f "$TPL_DIR/linux_debug.x86_64" ] || install -m 755 "$GODOT_TEMPLATE" "$TPL_DIR/linux_debug.x86_64"
fi
if [ ! -f "$TPL_DIR/linux_release.x86_64" ]; then
  echo "ERROR: falta la plantilla $TPL_DIR/linux_release.x86_64" >&2
  echo "Instala las plantillas oficiales $TPL_VER o indica GODOT_TEMPLATE=/ruta/plantilla" >&2
  exit 1
fi
mkdir -p "$OUT_DIR"
echo ">> Importando recursos"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo ">> Exportando"
"$GODOT" --headless --path . --export-release "Linux" "$OUT_DIR/vaelmoor.x86_64"
test -f "$OUT_DIR/vaelmoor.x86_64" && test -f "$OUT_DIR/vaelmoor.pck"
chmod +x "$OUT_DIR/vaelmoor.x86_64"
ls -la "$OUT_DIR"
echo ">> Exportación completada en $OUT_DIR"
