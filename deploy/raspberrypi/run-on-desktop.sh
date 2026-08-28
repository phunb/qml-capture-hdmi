#!/usr/bin/env bash
# Chạy HDMI Kiosk trên Raspberry Pi OS Desktop.
# Nên mở Terminal ngay trên màn Pi. Nếu SSH, script gắn vào session đồ họa đang login.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP="${HDMI_KIOSK_APP:-$SRC_DIR/build-pi/hdmi-kiosk}"

if [[ ! -x "$APP" ]]; then
  echo "Chưa có binary: $APP" >&2
  echo "Chạy trước: $SCRIPT_DIR/build-on-pi.sh" >&2
  exit 1
fi

if ! id -nG | grep -qw video; then
  echo "User chưa thuộc group video. Chạy:" >&2
  echo "  sudo usermod -aG video,render,input,plugdev,audio \$USER && reboot" >&2
  exit 1
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

attach_graphical_session() {
  if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
    return 0
  fi
  for w in wayland-0 wayland-1 wayland-2; do
    if [[ -S "${XDG_RUNTIME_DIR}/${w}" ]]; then
      export WAYLAND_DISPLAY="$w"
      export QT_QPA_PLATFORM=wayland
      echo "Gắn Wayland ($WAYLAND_DISPLAY) — đang SSH? App sẽ hiện trên màn Pi."
      return 0
    fi
  done
  if [[ -S /tmp/.X11-unix/X0 ]]; then
    export DISPLAY=:0
    export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
    export QT_QPA_PLATFORM=xcb
    echo "Gắn X11 DISPLAY=:0"
    return 0
  fi
  return 1
}

if ! attach_graphical_session; then
  echo "Không thấy màn hình Desktop." >&2
  echo "Mở Terminal trên PIXEL (không dùng SSH), hoặc login Desktop rồi SSH lại." >&2
  echo "Gói thiếu (chạy một lần):" >&2
  echo "  sudo apt-get install -y libxcb-cursor0 qt6-wayland" >&2
  exit 1
fi

echo "Mở $APP (platform=${QT_QPA_PLATFORM:-auto})"
exec "$APP"
