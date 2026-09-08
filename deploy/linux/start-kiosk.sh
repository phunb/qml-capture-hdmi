#!/usr/bin/env bash
# Vào lại HDMI Kiosk từ màn bảo trì (TTY).
set -euo pipefail
rm -f "${HOME}/.hdmi-kiosk-maintenance"
exec "${HDMI_KIOSK_ROOT:-/opt/hdmi-kiosk}/bin/hdmi-kiosk-session"
