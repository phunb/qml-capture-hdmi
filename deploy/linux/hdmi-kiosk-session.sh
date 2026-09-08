#!/usr/bin/env bash
# Phiên kiosk: cage + app, không desktop GNOME.
set -euo pipefail

ROOT="${HDMI_KIOSK_ROOT:-/opt/hdmi-kiosk}"
APP="${HDMI_KIOSK_APP:-${ROOT}/bin/hdmi-kiosk}"
if [[ -d "${ROOT}/qt/lib" ]]; then
  QT_ROOT="${HDMI_KIOSK_QT:-${ROOT}/qt}"
else
  QT_ROOT="${HDMI_KIOSK_QT:-/opt/Qt/6.8.3/gcc_64}"
fi
OUT_DIR="${HDMI_KIOSK_OUTPUT_DIR:-$HOME/output}"

mkdir -p "$OUT_DIR"

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" || true

export HDMI_KIOSK_ROOT="$ROOT"
export HDMI_KIOSK_QT="$QT_ROOT"
export PATH="$QT_ROOT/bin:${ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="$QT_ROOT/lib:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$QT_ROOT/plugins"
export QML_IMPORT_PATH="$QT_ROOT/qml"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export QT_MEDIA_BACKEND="${QT_MEDIA_BACKEND:-ffmpeg}"
export HDMI_KIOSK_OUTPUT_DIR="$OUT_DIR"

command -v xset >/dev/null 2>&1 && xset -dpms s off s noblank || true

if [[ ! -x "$APP" ]]; then
  echo "Không tìm thấy $APP" >&2
  sleep 10
  exit 1
fi

if command -v cage >/dev/null 2>&1; then
  exec dbus-run-session -- cage -- "$APP"
fi

if command -v weston >/dev/null 2>&1; then
  exec dbus-run-session -- weston --shell=kiosk-shell.so -- "$APP"
fi

echo "Thiếu cage/weston. Cài: sudo apt install cage" >&2
sleep 10
exit 1
