#!/usr/bin/env bash
# Cài HDMI Kiosk kiosk-mode trên Raspberry Pi OS Lite 64-bit.
# Chạy TRÊN Pi, trong thư mục project:
#   sudo ./deploy/raspberrypi/install-raspberry-pi-kiosk.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Chạy bằng sudo: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
KIOSK_USER="${KIOSK_USER:-${SUDO_USER:-pi}}"
INSTALL_ROOT="/opt/hdmi-kiosk"
BUILD_DIR="$INSTALL_ROOT/build"

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "Cần Raspberry Pi OS Lite 64-bit (aarch64). Máy này: $(uname -m)" >&2
  exit 1
fi

if ! id "$KIOSK_USER" >/dev/null 2>&1; then
  echo "Không có user $KIOSK_USER. Đặt KIOSK_USER=tên_user rồi chạy lại." >&2
  exit 1
fi

echo "==> User kiosk: $KIOSK_USER"
echo "==> Nguồn:      $SRC_DIR"

export DEBIAN_FRONTEND=noninteractive
apt-get update -o Acquire::PDiffs=false
# shellcheck source=pi-apt-packages.sh
source "$SCRIPT_DIR/pi-apt-packages.sh"
hdmi_kiosk_install_build_deps
hdmi_kiosk_apt_install dbus-user-session openssh-server udev

# cage là dự phòng nếu eglfs không lên được
apt-get install -y cage weston seatd || true

usermod -aG video,render,input,plugdev,audio "$KIOSK_USER" || true

MEM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
if [[ "${MEM_KB:-0}" -lt 3000000 ]] && command -v dphys-swapfile >/dev/null 2>&1; then
  echo "==> RAM < 3GB: tăng swap 1024MB để build"
  sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile || true
  dphys-swapfile setup || true
  dphys-swapfile swapon || true
fi

install -d -m 0755 "$INSTALL_ROOT/bin"

if [[ -f "$SCRIPT_DIR/../linux/99-hdmi-capture.rules" ]]; then
  install -m 0644 "$SCRIPT_DIR/../linux/99-hdmi-capture.rules" /etc/udev/rules.d/99-hdmi-capture.rules
  udevadm control --reload-rules || true
fi

echo "==> Build app (720p Pi)"
rm -rf "$BUILD_DIR"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DHDMI_KIOSK_PI=ON
cmake --build "$BUILD_DIR" --parallel
install -m 0755 "$BUILD_DIR/hdmi-kiosk" "$INSTALL_ROOT/bin/hdmi-kiosk"
install -m 0755 "$SCRIPT_DIR/hdmi-kiosk-pi-session.sh" "$INSTALL_ROOT/bin/hdmi-kiosk-pi-session"

install -d /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
Type=idle
EOF

BASH_PROFILE="/home/${KIOSK_USER}/.bash_profile"
cat >"$BASH_PROFILE" <<EOF
# HDMI Kiosk autostart (Raspberry Pi)
if [ "\$(tty)" = "/dev/tty1" ]; then
  exec /opt/hdmi-kiosk/bin/hdmi-kiosk-pi-session
fi
EOF
chown "${KIOSK_USER}:${KIOSK_USER}" "$BASH_PROFILE"

# Lite không có GDM; đảm bảo boot console
systemctl set-default multi-user.target
systemctl enable getty@tty1.service
systemctl enable ssh
systemctl disable --now lightdm gdm3 sddm 2>/dev/null || true
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || true

install -d /etc/systemd/logind.conf.d
cat >/etc/systemd/logind.conf.d/hdmi-kiosk.conf <<EOF
[Login]
IdleAction=ignore
HandleLidSwitch=ignore
HandlePowerKey=ignore
EOF

cat >/etc/environment.d/hdmi-kiosk.conf <<EOF
HDMI_KIOSK_APP=${INSTALL_ROOT}/bin/hdmi-kiosk
EOF

echo
echo "==== ĐÃ CÀI RASPBERRY PI KIOSK ===="
echo "User:     $KIOSK_USER"
echo "App:      $INSTALL_ROOT/bin/hdmi-kiosk"
echo "Video:    USB (thư mục recorder/output trên USB)"
echo "Bảo trì:  ssh ${KIOSK_USER}@<IP-Pi>"
echo "Thoát GUI: Ctrl+Alt+Shift+Q"
echo
echo "sudo reboot  → Pi tự login và mở app fullscreen (không desktop)."
