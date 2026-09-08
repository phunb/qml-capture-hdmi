#!/usr/bin/env bash
# Cài từ source trên Ubuntu (Server 24.04 LTS): build + bật kiosk boot.
#   sudo ./deploy/linux/install-ubuntu-kiosk.sh
# Máy đích chỉ cần gói .deb: xem scripts/package-ubuntu-deb.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Chạy bằng sudo: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
KIOSK_USER="${KIOSK_USER:-kiosk}"
INSTALL_ROOT="/opt/hdmi-kiosk"
QT_ROOT="/opt/Qt"
QT_VERSION="6.8.3"
QT_PREFIX="$QT_ROOT/$QT_VERSION/gcc_64"

echo "==> Nguồn project: $SRC_DIR"
echo "==> User kiosk: $KIOSK_USER"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  build-essential cmake ninja-build git curl ca-certificates rsync \
  python3 python3-pip python3-venv \
  cage seatd dbus-user-session weston \
  mesa-utils libgl1 libegl1 libgles2 libdrm2 libgbm1 \
  libfontconfig1 libfreetype6 libxkbcommon0 libxkbcommon-x11-0 \
  libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 \
  libxcb-xkb1 libxcb1 libx11-6 libx11-xcb1 \
  libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0 \
  libpulse0 libasound2t64 libva2 ffmpeg v4l-utils \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-base gstreamer1.0-libav \
  openssh-server udev \
  || apt-get install -y \
  build-essential cmake ninja-build git curl ca-certificates rsync \
  python3 python3-pip python3-venv \
  cage seatd dbus-user-session weston \
  mesa-utils libgl1 libegl1 libgles2 libdrm2 libgbm1 \
  libfontconfig1 libfreetype6 libxkbcommon0 libxkbcommon-x11-0 \
  libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
  libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 \
  libxcb-xkb1 libxcb1 libx11-6 libx11-xcb1 \
  libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0 \
  libpulse0 libasound2 libva2 ffmpeg v4l-utils \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-base gstreamer1.0-libav \
  openssh-server udev

install -d -m 0755 "$INSTALL_ROOT"

if [[ ! -x "$QT_PREFIX/bin/qmake" ]]; then
  echo "==> Cài Qt $QT_VERSION bằng aqtinstall"
  python3 -m venv "$INSTALL_ROOT/venv"
  "$INSTALL_ROOT/venv/bin/pip" install --upgrade pip aqtinstall
  "$INSTALL_ROOT/venv/bin/python" -m aqt install-qt \
    -O "$QT_ROOT" linux desktop "$QT_VERSION" gcc_64 \
    -m qtmultimedia qtshadertools qtimageformats \
    --archives qtbase qtdeclarative qtsvg qttools
fi

echo "==> Build app"
BUILD_DIR="$INSTALL_ROOT/build"
rm -rf "$BUILD_DIR"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
  -DCMAKE_CXX_COMPILER=g++
cmake --build "$BUILD_DIR" --parallel
install -d -m 0755 "$INSTALL_ROOT/bin"
install -m 0755 "$BUILD_DIR/hdmi-kiosk" "$INSTALL_ROOT/bin/hdmi-kiosk"

export KIOSK_USER HDMI_KIOSK_ROOT="$INSTALL_ROOT" HDMI_KIOSK_QT="$QT_PREFIX"
bash "$SCRIPT_DIR/setup-kiosk-mode.sh"
