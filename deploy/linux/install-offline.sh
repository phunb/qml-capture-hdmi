#!/usr/bin/env bash
# Cài HDMI Kiosk trên Ubuntu KHÔNG CẦN MẠNG.
# Chạy trong thư mục bộ cài (USB):
#   sudo ./install.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Chạy: sudo $0" >&2
  exit 1
fi

BUNDLE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$BUNDLE/repo"
if [[ ! -d "$REPO" ]] || [[ -z "$(ls -A "$REPO"/*.deb 2>/dev/null)" ]]; then
  echo "Không thấy $REPO/*.deb. Giải nén đủ bộ cài offline." >&2
  exit 1
fi

if [[ ! -f "$REPO/Packages" && ! -f "$REPO/Packages.gz" ]]; then
  if command -v dpkg-scanpackages >/dev/null 2>&1; then
    (cd "$REPO" && dpkg-scanpackages . /dev/null > Packages)
  fi
fi

LIST="$BUNDLE/offline.sources.list"
echo "deb [trusted=yes] file:${REPO} ./" >"$LIST"

export DEBIAN_FRONTEND=noninteractive
echo "==> Cài từ USB/local, không dùng internet"
set +e
apt-get update \
  -o Dir::Etc::sourcelist="$LIST" \
  -o Dir::Etc::sourceparts=/dev/null \
  -o APT::Get::List-Cleanup=0
APT_OK=$?
if [[ "$APT_OK" -eq 0 ]]; then
  apt-get install -y --no-install-recommends \
    -o Dir::Etc::sourcelist="$LIST" \
    -o Dir::Etc::sourceparts=/dev/null \
    -o APT::Get::List-Cleanup=0 \
    hdmi-kiosk
  APT_OK=$?
fi
set -e

if [[ "$APT_OK" -ne 0 ]]; then
  echo "==> apt local thất bại, thử dpkg -i toàn bộ .deb"
  dpkg -i "$REPO"/*.deb || true
  dpkg --configure -a
fi

if ! dpkg -s hdmi-kiosk >/dev/null 2>&1; then
  echo "Cài hdmi-kiosk thất bại." >&2
  exit 1
fi

echo
echo "Cài xong. Khởi động lại mini-PC:"
echo "  sudo reboot"
echo "Máy sẽ tự vào HDMI Kiosk (toàn màn hình)."
