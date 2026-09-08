#!/usr/bin/env bash
# Chạy binary với Qt đóng gói trong /opt/hdmi-kiosk/qt
set -euo pipefail
ROOT="${HDMI_KIOSK_ROOT:-/opt/hdmi-kiosk}"
BIN="${ROOT}/libexec/hdmi-kiosk"
if [[ -d "${ROOT}/qt/lib" ]]; then
  QT_ROOT="${HDMI_KIOSK_QT:-${ROOT}/qt}"
else
  QT_ROOT="${HDMI_KIOSK_QT:-/opt/Qt/6.8.3/gcc_64}"
fi
export PATH="${QT_ROOT}/bin:${ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${QT_ROOT}/lib:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="${QT_ROOT}/plugins"
export QML_IMPORT_PATH="${QT_ROOT}/qml"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export QT_MEDIA_BACKEND="${QT_MEDIA_BACKEND:-ffmpeg}"
if [[ ! -x "$BIN" ]]; then
  echo "Không tìm thấy $BIN" >&2
  exit 1
fi
exec "$BIN" "$@"
