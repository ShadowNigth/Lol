#!/usr/bin/env bash
# Ejecuta Vaelmoor desde el código fuente con un editor de Godot 4.7.x.
# Uso: ./run.sh [argumentos de Godot]   (variable GODOT = ruta al binario)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
GODOT="${GODOT:-$(command -v godot4 || command -v godot || true)}"
if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
  echo "No se encontró Godot 4.7. Instala el editor (https://godotengine.org/download/linux/)"
  echo "o indica su ruta: GODOT=/ruta/a/godot ./run.sh"
  exit 1
fi
# La primera vez hay que importar los recursos del proyecto.
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  echo "Importando el proyecto (solo la primera vez)..."
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi
exec "$GODOT" --path . "$@"
