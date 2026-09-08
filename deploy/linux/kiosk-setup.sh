#!/usr/bin/env bash
set -euo pipefail
echo "Đóng gói trên Ubuntu có mạng:"
echo "  ./scripts/package-ubuntu-deb.sh"
echo
echo "Cài máy không mạng (USB):"
echo "  sudo ./dist/hdmi-kiosk-offline_*.run && sudo reboot"
echo
echo "Hoặc cài từ source trên mini-PC:"
echo "  sudo ./deploy/linux/install-ubuntu-kiosk.sh && sudo reboot"
echo
echo "ISO: Ubuntu Server 24.04 LTS (không cần Desktop)."
echo "Video: /home/kiosk/output"
echo "Thoát GUI bảo trì: Ctrl+Alt+Shift+Q"
