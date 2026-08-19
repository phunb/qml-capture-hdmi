#!/usr/bin/env bash
set -euo pipefail

rm -f "$HOME/.config/autostart/hdmi-kiosk.desktop"
systemctl --user disable --now hdmi-kiosk.service >/dev/null 2>&1 || true
rm -f "$HOME/.config/systemd/user/hdmi-kiosk.service"
systemctl --user daemon-reload
echo "Đã gỡ autostart HDMI Kiosk."
