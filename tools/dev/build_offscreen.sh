#!/usr/bin/env bash
# Compila el binario de PRUEBAS "offscreen" (Vulkan sin servidor gráfico) que
# usa tools/dev/run_capture.sh para hacer capturas de pantalla automáticas con
# SwiftShader en máquinas sin GPU. NO hace falta para jugar ni para exportar.
#
# Usa una copia aparte del código fuente (el parche no debe tocar el árbol con
# el que se compilan el editor y la plantilla release del juego).
#
# Uso: JOBS=2 tools/dev/build_offscreen.sh [dir_trabajo]
#   dir_trabajo: el mismo de tools/build_godot_from_source.sh (contiene el
#   .tar.gz de Godot y el venv con scons). Resultado:
#   <dir>/godot-offscreen/bin/godot.linuxbsd.template_debug.x86_64
set -euo pipefail
WORK="${1:-$HOME/.cache/vaelmoor-godot}"
TAG="4.7.2-stable"
JOBS="${JOBS:-$(nproc)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$WORK"
[ -f "godot-$TAG.tar.gz" ] || curl -L -o "godot-$TAG.tar.gz" "https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/$TAG"
if [ ! -d godot-offscreen ]; then
  mkdir godot-offscreen
  tar xzf "godot-$TAG.tar.gz" -C godot-offscreen --strip-components=1
  bash "$HERE/godot_offscreen_patch/apply_patch.sh" "$WORK/godot-offscreen"
fi
[ -x venv/bin/scons ] || { python3 -m venv venv; venv/bin/pip install --quiet scons; }
export PATH="$WORK/venv/bin:$WORK/bin:$PATH"
cd godot-offscreen
scons -j"$JOBS" target=template_debug platform=linuxbsd arch=x86_64 vulkan=yes opengl3=no d3d12=no accesskit=no \
  wayland=no sdl=no scu_build=yes debug_symbols=no \
  module_mono_enabled=no module_openxr_enabled=no module_webxr_enabled=no module_mobile_vr_enabled=no \
  module_webrtc_enabled=no module_websocket_enabled=no module_multiplayer_enabled=no module_enet_enabled=no \
  module_upnp_enabled=no module_lightmapper_rd_enabled=no module_glslang_enabled=yes \
  module_basis_universal_enabled=no module_cvtt_enabled=no module_etcpak_enabled=no module_betsy_enabled=no \
  module_astcenc_enabled=no module_theora_enabled=no module_fbx_enabled=no module_camera_enabled=no \
  module_objectdb_profiler_enabled=no module_raycast_enabled=no module_xatlas_unwrap_enabled=no \
  module_vhacd_enabled=no module_text_server_adv_enabled=no module_text_server_fb_enabled=yes \
  module_msdfgen_enabled=no module_csg_enabled=no module_gridmap_enabled=no module_visual_shader_enabled=no \
  module_navigation_2d_enabled=no module_ktx_enabled=no
ls -la bin/
