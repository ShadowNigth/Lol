#!/bin/sh
# Instala Vaelmoor para el usuario actual (sin permisos de administrador):
#   ~/.local/share/vaelmoor-game/  (juego)
#   ~/.local/bin/vaelmoor          (lanzador)
#   menú de aplicaciones (.desktop)
# Para desinstalar: ./install.sh --uninstall
set -e
HERE="$(dirname "$(readlink -f "$0")")"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/vaelmoor-game"
BIN="$HOME/.local/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/128x128/apps"
if [ "$1" = "--uninstall" ]; then
  rm -rf "$DEST" "$BIN/vaelmoor" "$APPS/vaelmoor.desktop" "$ICONS/vaelmoor.png"
  echo "Vaelmoor desinstalado (las partidas guardadas siguen en ~/.local/share/vaelmoor)."
  exit 0
fi
for f in vaelmoor.x86_64 vaelmoor.pck vaelmoor.png vaelmoor.desktop; do
  if [ ! -f "$HERE/$f" ]; then
    echo "Error: falta $f junto a install.sh (¿paquete incompleto?)." >&2
    exit 1
  fi
done
mkdir -p "$DEST" "$BIN" "$APPS" "$ICONS"
cp "$HERE/vaelmoor.x86_64" "$HERE/vaelmoor.pck" "$DEST/"
chmod +x "$DEST/vaelmoor.x86_64"
# El ejecutable carga vaelmoor.pck por nombre desde su misma carpeta
# (las plantillas de exportación no admiten --main-pack ni --path).
printf '#!/bin/sh\nexec "%s/vaelmoor.x86_64" "$@"\n' "$DEST" > "$BIN/vaelmoor"
chmod +x "$BIN/vaelmoor"
cp "$HERE/vaelmoor.png" "$ICONS/vaelmoor.png"
sed "s|^Exec=.*|Exec=$BIN/vaelmoor|" "$HERE/vaelmoor.desktop" > "$APPS/vaelmoor.desktop"
echo "Vaelmoor instalado. Ejecuta 'vaelmoor' o búscalo en el menú de aplicaciones."
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "Nota: $BIN no está en tu PATH; usa '$BIN/vaelmoor' o añádelo al PATH." ;;
esac
