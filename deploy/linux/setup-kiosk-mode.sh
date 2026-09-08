#!/usr/bin/env bash
# Bật chế độ kiosk: máy Ubuntu boot là vào HDMI Kiosk (không desktop).
# Chạy bằng sudo. Dùng chung cho cài từ source và gói .deb.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Chạy bằng sudo: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIOSK_USER="${KIOSK_USER:-kiosk}"
INSTALL_ROOT="${HDMI_KIOSK_ROOT:-/opt/hdmi-kiosk}"
OUTPUT_DIR="${HDMI_KIOSK_OUTPUT_DIR:-/home/${KIOSK_USER}/output}"

if [[ -d "${INSTALL_ROOT}/qt/lib" ]]; then
  QT_PREFIX="${HDMI_KIOSK_QT:-${INSTALL_ROOT}/qt}"
else
  QT_PREFIX="${HDMI_KIOSK_QT:-/opt/Qt/6.8.3/gcc_64}"
fi

SHARE_DIR="$SCRIPT_DIR"
if [[ ! -f "$SHARE_DIR/hdmi-kiosk-session.sh" && -d "${INSTALL_ROOT}/share" ]]; then
  SHARE_DIR="${INSTALL_ROOT}/share"
fi

echo "==> Kiosk user: $KIOSK_USER"
echo "==> App root:   $INSTALL_ROOT"
echo "==> Qt:         $QT_PREFIX"

if ! id "$KIOSK_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "HDMI Kiosk" "$KIOSK_USER"
fi
usermod -aG video,render,input,plugdev,audio "$KIOSK_USER"

install -d -m 0755 "$OUTPUT_DIR"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "$OUTPUT_DIR"

if [[ -f "$SHARE_DIR/99-hdmi-capture.rules" ]]; then
  install -m 0644 "$SHARE_DIR/99-hdmi-capture.rules" /etc/udev/rules.d/99-hdmi-capture.rules
  udevadm control --reload-rules || true
fi

if [[ -x "$SHARE_DIR/hdmi-kiosk-session.sh" ]]; then
  install -m 0755 "$SHARE_DIR/hdmi-kiosk-session.sh" "$INSTALL_ROOT/bin/hdmi-kiosk-session"
fi

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
  exec ${INSTALL_ROOT}/bin/hdmi-kiosk-session
fi
EOF
chown "${KIOSK_USER}:${KIOSK_USER}" "$BASH_PROFILE"

systemctl disable --now gdm3 gdm lightdm sddm 2>/dev/null || true
systemctl set-default multi-user.target
systemctl enable getty@tty1.service
systemctl enable ssh 2>/dev/null || true
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

install -d /etc/systemd/logind.conf.d
cat >/etc/systemd/logind.conf.d/hdmi-kiosk.conf <<EOF
[Login]
IdleAction=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandlePowerKey=ignore
EOF

install -d /etc/environment.d
cat >/etc/environment.d/hdmi-kiosk.conf <<EOF
HDMI_KIOSK_OUTPUT_DIR=${OUTPUT_DIR}
HDMI_KIOSK_QT=${QT_PREFIX}
HDMI_KIOSK_APP=${INSTALL_ROOT}/bin/hdmi-kiosk
EOF

install -d /etc/polkit-1/rules.d
if [[ -f "$SHARE_DIR/50-hdmi-kiosk-poweroff.rules" ]]; then
  sed "s/\"kiosk\"/\"${KIOSK_USER}\"/" "$SHARE_DIR/50-hdmi-kiosk-poweroff.rules" \
    > /etc/polkit-1/rules.d/50-hdmi-kiosk-poweroff.rules
  chmod 0644 /etc/polkit-1/rules.d/50-hdmi-kiosk-poweroff.rules
fi
if [[ -f "$SHARE_DIR/hdmi-kiosk-poweroff.sudoers" ]]; then
  sed "s/^kiosk /${KIOSK_USER} /" "$SHARE_DIR/hdmi-kiosk-poweroff.sudoers" \
    > /etc/sudoers.d/hdmi-kiosk-poweroff
  chmod 0440 /etc/sudoers.d/hdmi-kiosk-poweroff
  visudo -cf /etc/sudoers.d/hdmi-kiosk-poweroff >/dev/null
fi

echo
echo "==== ĐÃ BẬT KIOSK ===="
echo "User:     $KIOSK_USER"
echo "App:      $INSTALL_ROOT/bin/hdmi-kiosk"
echo "Video:    $OUTPUT_DIR"
echo "Bảo trì:  SSH (user admin). Thoát GUI: Ctrl+Alt+Shift+Q"
echo "Khởi động lại: sudo reboot"
echo "Máy sẽ tự login và chạy app toàn màn hình."
