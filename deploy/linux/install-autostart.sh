#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="hdmi-kiosk"

resolve_exe() {
  if [[ -n "${1:-}" && -x "$1" ]]; then
    realpath "$1"
    return
  fi
  if command -v "$APP_NAME" >/dev/null 2>&1; then
    command -v "$APP_NAME"
    return
  fi
  for candidate in \
      "$SCRIPT_DIR/../../build/$APP_NAME" \
      "$SCRIPT_DIR/../../build/Release/$APP_NAME" \
      "$HOME/.local/bin/$APP_NAME"; do
    if [[ -x "$candidate" ]]; then
      realpath "$candidate"
      return
    fi
  done
  echo "Không tìm thấy hdmi-kiosk. Truyền đường dẫn: $0 /path/to/hdmi-kiosk" >&2
  exit 1
}

EXE="$(resolve_exe "${1:-}")"
echo "Cài autostart cho: $EXE"

mkdir -p "$HOME/.config/autostart" "$HOME/.config/systemd/user"

sed "s|^Exec=.*|Exec=$EXE|" "$SCRIPT_DIR/hdmi-kiosk.desktop" \
  > "$HOME/.config/autostart/hdmi-kiosk.desktop"
chmod +x "$HOME/.config/autostart/hdmi-kiosk.desktop"

if [[ "${2:-}" == "--systemd" ]]; then
  sed "s|^ExecStart=.*|ExecStart=$EXE|" "$SCRIPT_DIR/hdmi-kiosk.service" \
    > "$HOME/.config/systemd/user/hdmi-kiosk.service"
  systemctl --user daemon-reload
  systemctl --user enable hdmi-kiosk.service
  loginctl enable-linger "$USER" >/dev/null 2>&1 || true
  echo "Đã bật thêm systemd --user (tránh dùng cùng lúc với desktop autostart)."
fi

if [[ -f "$SCRIPT_DIR/99-hdmi-capture.rules" ]]; then
  if command -v sudo >/dev/null 2>&1; then
    sudo cp "$SCRIPT_DIR/99-hdmi-capture.rules" /etc/udev/rules.d/99-hdmi-capture.rules
    sudo udevadm control --reload-rules || true
    sudo usermod -aG video "$USER" || true
  fi
fi

echo
echo "Đã bật tự chạy khi đăng nhập."
echo "Kiosk Wayland gợi ý (cài cage nếu cần):"
echo "  cage -s $EXE"
echo
echo "Nên cấu hình auto-login cho user kiosk của máy."
