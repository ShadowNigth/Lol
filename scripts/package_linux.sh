#!/usr/bin/env bash
# Empaqueta la exportación en un .tar.xz listo para copiar y ejecutar.
# Requiere haber ejecutado antes scripts/export_linux.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT_DIR="${OUT_DIR:-build/linux}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
NAME="vaelmoor-$VERSION-linux-x86_64"
STAGE="build/$NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE/licenses" dist
cp "$OUT_DIR/vaelmoor.x86_64" "$OUT_DIR/vaelmoor.pck" "$STAGE/"
cp packaging/vaelmoor.sh packaging/install.sh packaging/vaelmoor.desktop packaging/vaelmoor.png "$STAGE/"
chmod +x "$STAGE/vaelmoor.sh" "$STAGE/install.sh" "$STAGE/vaelmoor.x86_64"
cp README.md ATTRIBUTIONS.md "$STAGE/"
cp licenses/* "$STAGE/licenses/"
tar -C build -cJf "dist/$NAME.tar.xz" "$NAME"
sha256sum "dist/$NAME.tar.xz" > "dist/$NAME.tar.xz.sha256"
ls -la dist/
echo ">> Paquete: dist/$NAME.tar.xz"
