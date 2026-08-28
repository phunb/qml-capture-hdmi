#!/usr/bin/env bash
# Chạy HDMI Kiosk fullscreen trên Raspberry Pi OS Lite (không desktop).
set -euo pipefail

APP="${HDMI_KIOSK_APP:-/opt/hdmi-kiosk/bin/hdmi-kiosk}"

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" || true

export QT_MEDIA_BACKEND="${QT_MEDIA_BACKEND:-ffmpeg}"
export QT_QPA_EGLFS_INTEGRATION="${QT_QPA_EGLFS_INTEGRATION:-eglfs_kms}"
export QT_QPA_EGLFS_ALWAYS_SET_MODE=1

if [[ ! -x "$APP" ]]; then
  echo "Không tìm thấy $APP" >&2
  sleep 10
  exit 1
fi

if [[ -z "${QT_QPA_PLATFORM:-}" ]]; then
  if [[ -e /dev/dri/card0 || -e /dev/dri/card1 ]]; then
    export QT_QPA_PLATFORM=eglfs
  elif command -v cage >/dev/null 2>&1; then
    export QT_QPA_PLATFORM=wayland
  fi
fi

if [[ "${QT_QPA_PLATFORM}" == "wayland" ]] && command -v cage >/dev/null 2>&1; then
  exec dbus-run-session -- cage -- "$APP"
fi

exec "$APP"
