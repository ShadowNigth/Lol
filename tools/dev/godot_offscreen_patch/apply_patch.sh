#!/usr/bin/env bash
# Aplica el parche opcional "offscreen" a un árbol de fuentes de Godot 4.7.x.
# Solo sirve para pruebas automáticas con capturas de pantalla en máquinas sin
# servidor gráfico (por ejemplo, con SwiftShader). NO es necesario para jugar
# ni para exportar el juego.
set -euo pipefail
GODOT_SRC="${1:?Uso: apply_patch.sh /ruta/a/godot-src}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$HERE/platform/linuxbsd/offscreen" "$GODOT_SRC/platform/linuxbsd/"
cd "$GODOT_SRC"
if ! grep -q "offscreen/SCsub" platform/linuxbsd/SCsub; then
  python3 - <<'PY'
import re
p = "platform/linuxbsd/SCsub"
s = open(p).read()
s = s.replace('if env["speechd"]:', 'common_linuxbsd += SConscript("offscreen/SCsub")\n\nif env["speechd"]:', 1)
open(p, "w").write(s)
p = "platform/linuxbsd/os_linuxbsd.cpp"
s = open(p).read()
if 'offscreen/display_server_offscreen.h' not in s:
    s = s.replace('#include "os_linuxbsd.h"', '#include "os_linuxbsd.h"\n#include "offscreen/display_server_offscreen.h"', 1)
anchor = '\tDisplayServerWayland::register_wayland_driver();\n#endif\n'
assert anchor in s, 'No se encontró el punto de registro de Wayland en os_linuxbsd.cpp'
s = s.replace(anchor, anchor + '\n\tDisplayServerOffscreen::register_offscreen_driver();\n', 1)
open(p, "w").write(s)
PY
fi
# Permitir --path en la plantilla de pruebas (solo para este binario de desarrollo).
for f in main/main.cpp core/config/project_settings.cpp; do
  if ! grep -q "VAELMOOR_DEV_PATH_OVERRIDES" "$f"; then
    sed -i '0,/^#include/s//\/\/ VAELMOOR_DEV_PATH_OVERRIDES: build de pruebas, permite --path.\n#ifndef OVERRIDE_PATH_ENABLED\n#define OVERRIDE_PATH_ENABLED\n#endif\n#include/' "$f"
  fi
done
grep -n "offscreen" platform/linuxbsd/SCsub platform/linuxbsd/os_linuxbsd.cpp
echo "Parche aplicado."
