#!/usr/bin/env bash
# Compila desde el código fuente oficial el editor y la plantilla de
# exportación de Godot 4.7.2 que usa Vaelmoor (Linux x86_64).
#
# Úsalo solo si no puedes descargar los binarios oficiales de
# https://godotengine.org/download/linux/ . El juego funciona con el editor
# oficial 4.7.x y sus plantillas oficiales.
#
# Requisitos (Debian/Ubuntu): build-essential python3 python3-venv git
#   (Arch: base-devel python git). No hace falta pkg-config ni librerías
#   de desarrollo de X11: Godot carga X11/OpenGL/ALSA/PulseAudio en tiempo
#   de ejecución.
#
# Uso: tools/build_godot_from_source.sh [directorio_de_trabajo]
# Resultado: <dir>/godot-4.7.2-stable/bin/godot.linuxbsd.{editor,template_release}.x86_64
set -euo pipefail

WORK="${1:-$HOME/.cache/vaelmoor-godot}"
TAG="4.7.2-stable"
JOBS="${JOBS:-$(nproc)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$WORK"
cd "$WORK"

if [ ! -d "godot-$TAG" ]; then
  echo ">> Descargando código fuente de Godot $TAG"
  curl -L -o "godot-$TAG.tar.gz" "https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/$TAG"
  tar xzf "godot-$TAG.tar.gz"
fi

if [ ! -x venv/bin/scons ]; then
  python3 -m venv venv
  venv/bin/pip install --quiet scons
fi
export PATH="$WORK/venv/bin:$PATH"

# pkg-config no es necesario: si no existe, se usa un sustituto que solo informa la versión.
if ! command -v pkg-config >/dev/null 2>&1; then
  mkdir -p "$WORK/bin"
  printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo 0.29.2; exit 0; fi\nexit 1\n' > "$WORK/bin/pkg-config"
  chmod +x "$WORK/bin/pkg-config"
  export PATH="$WORK/bin:$PATH"
fi

cd "godot-$TAG"

# Compatibilidad con glibc 2.35 (Ubuntu 22.04 / Mint 21): ver tools/glibc_compat.c
cp "$HERE/glibc_compat.c" platform/linuxbsd/glibc_compat.c
grep -q "glibc_compat.c" platform/linuxbsd/SCsub || sed -i 's/^common_linuxbsd = \[/common_linuxbsd = [\n    "glibc_compat.c",/' platform/linuxbsd/SCsub

# Módulos que el juego no usa (reduce tamaño y tiempo de compilación).
COMMON="platform=linuxbsd arch=x86_64 vulkan=no opengl3=yes d3d12=no accesskit=no wayland=no
 scu_build=yes debug_symbols=no
 module_mono_enabled=no module_openxr_enabled=no module_webxr_enabled=no module_mobile_vr_enabled=no
 module_webrtc_enabled=no module_websocket_enabled=no module_multiplayer_enabled=no module_enet_enabled=no
 module_upnp_enabled=no module_lightmapper_rd_enabled=no module_glslang_enabled=no
 module_basis_universal_enabled=no module_cvtt_enabled=no module_etcpak_enabled=no module_betsy_enabled=no
 module_astcenc_enabled=no module_theora_enabled=no module_fbx_enabled=no module_camera_enabled=no
 module_objectdb_profiler_enabled=no module_raycast_enabled=no module_xatlas_unwrap_enabled=no
 module_vhacd_enabled=no module_text_server_adv_enabled=no module_text_server_fb_enabled=yes
 module_msdfgen_enabled=no module_csg_enabled=no module_gridmap_enabled=no module_visual_shader_enabled=no
 module_navigation_2d_enabled=no module_ktx_enabled=no"
if command -v ld.gold >/dev/null 2>&1; then COMMON="$COMMON linker=gold"; fi

echo ">> Compilando el editor (puede tardar 20-60 min)"
scons -j"$JOBS" target=editor sdl=no $COMMON
echo ">> Compilando la plantilla de exportación (release, con soporte de mandos SDL3)"
scons -j"$JOBS" target=template_release sdl=yes $COMMON

ls -la bin/
echo ">> Listo. Exporta con:"
echo "   GODOT=$PWD/bin/godot.linuxbsd.editor.x86_64 GODOT_TEMPLATE=$PWD/bin/godot.linuxbsd.template_release.x86_64 scripts/export_linux.sh"
