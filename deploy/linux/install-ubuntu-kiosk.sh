#!/usr/bin/env bash
# Cài Ubuntu kiosk cho HDMI Kiosk trên mini-PC.
# Chạy TRÊN Ubuntu (sau khi cài Ubuntu Server 24.04 LTS):
#   sudo ./deploy/linux/install-ubuntu-kiosk.sh
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
  build-essential cmake ninja-build git curl ca-certificates \
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
  build-essential cmake ninja-build git curl ca-certificates \
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

# User kiosk: không sudo, có quyền camera/DRM/input
if ! id "$KIOSK_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "HDMI Kiosk" "$KIOSK_USER"
  echo "Đặt mật khẩu user $KIOSK_USER (dùng khi SSH bảo trì):"
  passwd "$KIOSK_USER" || true
fi
usermod -aG video,render,input,plugdev,audio "$KIOSK_USER"

install -d -m 0755 "$INSTALL_ROOT/bin" "$QT_ROOT"

if [[ -f "$SCRIPT_DIR/99-hdmi-capture.rules" ]]; then
  install -m 0644 "$SCRIPT_DIR/99-hdmi-capture.rules" /etc/udev/rules.d/99-hdmi-capture.rules
  udevadm control --reload-rules || true
fi

# Qt 6.8 (Ubuntu 24.04 repo chỉ có ~6.4, app cần >= 6.5)
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
install -m 0755 "$BUILD_DIR/hdmi-kiosk" "$INSTALL_ROOT/bin/hdmi-kiosk"
install -m 0755 "$SCRIPT_DIR/hdmi-kiosk-session.sh" "$INSTALL_ROOT/bin/hdmi-kiosk-session"

# Autologin TTY1 → cage + app (không GNOME)
install -d /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
Type=idle
EOF

BASH_PROFILE="/home/${KIOSK_USER}/.bash_profile"
cat >"$BASH_PROFILE" <<EOF
# HDMI Kiosk autostart
if [ "\$(tty)" = "/dev/tty1" ]; then
  exec /opt/hdmi-kiosk/bin/hdmi-kiosk-session
fi
EOF
chown "${KIOSK_USER}:${KIOSK_USER}" "$BASH_PROFILE"

# Tắt desktop manager nếu có, không cho máy ngủ
systemctl disable --now gdm3 gdm lightdm sddm 2>/dev/null || true
systemctl set-default multi-user.target
systemctl enable getty@tty1.service
systemctl enable ssh
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Không khóa màn / blank (logind)
install -d /etc/systemd/logind.conf.d
cat >/etc/systemd/logind.conf.d/hdmi-kiosk.conf <<EOF
[Login]
IdleAction=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandlePowerKey=ignore
EOF

cat >/etc/environment.d/hdmi-kiosk.conf <<EOF
HDMI_KIOSK_QT=${QT_PREFIX}
EOF

echo
echo "==== ĐÃ CÀI UBUNTU KIOSK ===="
echo "User:     $KIOSK_USER"
echo "App:      $INSTALL_ROOT/bin/hdmi-kiosk"
echo "Video:    USB (thư mục recorder/output trên USB)"
echo "Bảo trì:  SSH vào máy (user $KIOSK_USER hoặc user admin có sudo)"
echo "Thoát GUI: Ctrl+Alt+Shift+Q (rồi login TTY)"
echo
echo "Khởi động lại mini-PC:  sudo reboot"
echo "Máy sẽ tự login và chạy app toàn màn hình."
