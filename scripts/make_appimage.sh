#!/usr/bin/env bash
# Crea un AppImage a partir de la exportación (opcional).
# Requiere appimagetool en el PATH: https://github.com/AppImage/appimagetool
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT_DIR="${OUT_DIR:-build/linux}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
if ! command -v appimagetool >/dev/null 2>&1; then
  echo "ERROR: appimagetool no está instalado. Descárgalo de https://github.com/AppImage/appimagetool/releases" >&2
  exit 1
fi
APPDIR="build/Vaelmoor.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/128x128/apps"
cp "$OUT_DIR/vaelmoor.x86_64" "$OUT_DIR/vaelmoor.pck" "$APPDIR/usr/bin/"
cp packaging/vaelmoor.desktop "$APPDIR/vaelmoor.desktop"
cp packaging/vaelmoor.desktop "$APPDIR/usr/share/applications/"
cp packaging/vaelmoor.png "$APPDIR/vaelmoor.png"
cp packaging/vaelmoor.png "$APPDIR/usr/share/icons/hicolor/128x128/apps/vaelmoor.png"
cat > "$APPDIR/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/vaelmoor.x86_64" "$@"
RUN
chmod +x "$APPDIR/AppRun"
mkdir -p dist
ARCH=x86_64 appimagetool "$APPDIR" "dist/Vaelmoor-$VERSION-x86_64.AppImage"
echo ">> AppImage: dist/Vaelmoor-$VERSION-x86_64.AppImage"
