#!/usr/bin/env bash
# Build hdmi-kiosk trên Raspberry Pi 4 (64-bit). Chạy trong thư mục project:
#   chmod +x deploy/raspberrypi/*.sh
#   ./deploy/raspberrypi/build-on-pi.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="${HDMI_KIOSK_BUILD_DIR:-$SRC_DIR/build-pi}"
PREFIX="${HDMI_KIOSK_PREFIX:-/opt/hdmi-kiosk}"

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "Script này build trên Raspberry Pi OS 64-bit (aarch64)." >&2
  echo "Máy hiện tại: $(uname -m)" >&2
  exit 1
fi

echo "==> Cài gói build (cần sudo)"
# Trixie: tắt pdiff để tránh lỗi "Need N compressed bytes, but limit is"
sudo apt-get update -o Acquire::PDiffs=false
# shellcheck source=pi-apt-packages.sh
source "$SCRIPT_DIR/pi-apt-packages.sh"
hdmi_kiosk_install_build_deps

echo "==> CMake + build ($BUILD_DIR)"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DHDMI_KIOSK_PI=ON
cmake --build "$BUILD_DIR" --parallel

echo
echo "Xong: $BUILD_DIR/hdmi-kiosk"
echo "Chạy trên Desktop PIXEL (không eglfs):"
echo "  $SCRIPT_DIR/run-on-desktop.sh"
echo "Chạy fullscreen Lite:"
echo "  QT_QPA_PLATFORM=eglfs $BUILD_DIR/hdmi-kiosk"
echo
echo "Kiosk boot (Lite, tắt desktop): sudo $SCRIPT_DIR/install-raspberry-pi-kiosk.sh"
