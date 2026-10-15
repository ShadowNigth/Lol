#!/usr/bin/env bash
# Ejecuta la herramienta de capturas con el binario de pruebas "offscreen"
# (Vulkan sobre SwiftShader) en máquinas sin servidor gráfico.
# Variables: GODOT_OFFSCREEN (binario), VK_DIR (dir. con libvulkan.so.1 y el ICD).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="${GODOT_OFFSCREEN:-$HOME/.cache/godot/godot-offscreen/bin/godot.linuxbsd.template_debug.x86_64}"
VK_DIR="${VK_DIR:-$HOME/.cache/webtest/chrome}"
OUT="${1:-/tmp/caps}"
SETS="${2:-views,vm,enemy}"
RES="${RES:-800x450}"
export VK_ICD_FILENAMES="$VK_DIR/vk_swiftshader_icd.json"
export LD_LIBRARY_PATH="$VK_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$BIN" --path "$HERE" --display-driver offscreen --rendering-driver vulkan --rendering-method mobile \
  --resolution "$RES" --audio-driver Dummy res://tools/dev/capture.tscn -- --out="$OUT" --set="$SETS" ${EXTRA:-}
