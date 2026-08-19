#!/usr/bin/env bash
set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then
  echo "Chạy sudo $0" >&2
  exit 1
fi

KIOSK_USER="${KIOSK_USER:-kiosk}"
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rm -f "/home/${KIOSK_USER}/.bash_profile"
rm -f /etc/systemd/logind.conf.d/hdmi-kiosk.conf
rm -f /etc/environment.d/hdmi-kiosk.conf
systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
systemctl daemon-reload
echo "Đã gỡ autologin kiosk. App vẫn còn ở /opt/hdmi-kiosk (xóa tay nếu muốn)."
