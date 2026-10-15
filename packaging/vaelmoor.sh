#!/bin/sh
# Lanzador de Vaelmoor (paquete binario).
HERE="$(dirname "$(readlink -f "$0")")"
cd "$HERE" || exit 1
exec ./vaelmoor.x86_64 "$@"
