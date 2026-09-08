#!/usr/bin/env bash
# Build gói cài Ubuntu (.deb) trên máy Linux x86_64.
# Không chạy được từ Windows.
#
#   ./scripts/package-ubuntu-deb.sh
#   # -> dist/hdmi-kiosk_1.0.0_amd64.deb
#
# Ra thêm bộ cài offline (USB, máy không mạng):
#   dist/hdmi-kiosk-offline_1.0.0_amd64.run
#   dist/hdmi-kiosk-offline_1.0.0_amd64.tar.gz
#
# Mini-PC offline:
#   sudo ./hdmi-kiosk-offline_1.0.0_amd64.run
#   sudo reboot
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Phải chạy script này trên Ubuntu 24.04 (amd64). Không đóng gói từ Windows." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINUX_DIR="$ROOT/deploy/linux"
VERSION="${HDMI_KIOSK_VERSION:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n 's/^project(HdmiKiosk VERSION \([^ ]*\).*/\1/p' "$ROOT/CMakeLists.txt")"
fi
VERSION="${VERSION:-1.0.0}"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
QT_VERSION="${HDMI_KIOSK_QT_VERSION:-6.8.3}"
QT_ROOT="${HDMI_KIOSK_QT_ROOT:-/opt/Qt}"
QT_PREFIX="${HDMI_KIOSK_QT:-$QT_ROOT/$QT_VERSION/gcc_64}"

DIST="$ROOT/dist"
PKG_NAME="hdmi-kiosk_${VERSION}_${ARCH}"
STAGE="$DIST/$PKG_NAME"
DEB="$DIST/${PKG_NAME}.deb"

echo "==> Version $VERSION  arch $ARCH"
echo "==> Stage  $STAGE"

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake ninja-build curl ca-certificates rsync dpkg-dev \
  python3 python3-pip python3-venv \
  libgl1 libegl1 libgles2 libdrm2 libgbm1 \
  libfontconfig1 libfreetype6 libxkbcommon0 libxkbcommon-x11-0 \
  libxcb-cursor0 libwayland-client0 libpulse0 ffmpeg

if [[ ! -x "$QT_PREFIX/bin/qmake" && ! -x "$QT_PREFIX/bin/qt-cmake" ]]; then
  echo "==> Cài Qt $QT_VERSION (aqtinstall) vào $QT_ROOT"
  VENV="$ROOT/.qt-venv"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --upgrade pip aqtinstall
  sudo mkdir -p "$QT_ROOT"
  "$VENV/bin/python" -m aqt install-qt \
    -O "$QT_ROOT" linux desktop "$QT_VERSION" gcc_64 \
    -m qtmultimedia qtshadertools qtimageformats
fi

# Qt official 6.8 cần ICU 73. Không apt-install libicu73 trên 24.04
# (PPA đè file của libicu74). Chỉ giải nén *.so.73 vào lib Qt.
export LD_LIBRARY_PATH="${QT_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
icu73_ready() {
  [[ -e "$QT_PREFIX/lib/libicui18n.so.73" ]]
}
copy_icu73_from_tree() {
  local tree="$1"
  install -d -m 0755 "$QT_PREFIX/lib"
  local found=0
  while IFS= read -r -d '' so; do
    cp -a "$so" "$QT_PREFIX/lib/" || sudo cp -a "$so" "$QT_PREFIX/lib/"
    found=1
  done < <(find "$tree" -name 'libicu*.so.73*' -print0)
  [[ "$found" -eq 1 ]]
}
if ! icu73_ready; then
  echo "==> Lấy libicu*.so.73 (không cài đè hệ thống)"
  ICU_TMP="$(mktemp -d)"
  if sudo apt-get install -y software-properties-common \
      && sudo add-apt-repository -y ppa:reviczky/icu-backports \
      && sudo apt-get update \
      && (cd "$ICU_TMP" && apt-get download libicu73) \
      && dpkg-deb -x "$ICU_TMP"/libicu73_*.deb "$ICU_TMP/root" \
      && copy_icu73_from_tree "$ICU_TMP/root"; then
    echo "Đã copy ICU 73 từ PPA .deb"
  else
    echo "==> Thử Debian snapshot"
    ICU_OK=0
    for url in \
        "https://snapshot.debian.org/archive/debian/20230620T151739Z/pool/main/i/icu/libicu73_73.2-1_amd64.deb" \
        "https://snapshot.debian.org/archive/debian/20230715T025103Z/pool/main/i/icu/libicu73_73.2-1_amd64.deb"
    do
      if curl -fsSL -o "$ICU_TMP/libicu73.deb" "$url" \
          && dpkg-deb -x "$ICU_TMP/libicu73.deb" "$ICU_TMP/debroot" \
          && copy_icu73_from_tree "$ICU_TMP/debroot"; then
        ICU_OK=1
        break
      fi
    done
    if [[ "$ICU_OK" -ne 1 ]]; then
      echo "Không lấy được ICU 73" >&2
      rm -rf "$ICU_TMP"
      exit 1
    fi
  fi
  rm -rf "$ICU_TMP"
fi
if ! icu73_ready; then
  echo "Vẫn thiếu $QT_PREFIX/lib/libicui18n.so.73" >&2
  ls -l "$QT_PREFIX/lib"/libicu* 2>/dev/null || true
  exit 1
fi

BUILD_DIR="${HDMI_KIOSK_BUILD_DIR:-$ROOT/build-deb}"
echo "==> CMake $BUILD_DIR"
cmake -S "$ROOT" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
  -DCMAKE_CXX_COMPILER=g++
cmake --build "$BUILD_DIR" --parallel

BIN="$BUILD_DIR/hdmi-kiosk"
if [[ ! -x "$BIN" ]]; then
  echo "Không thấy binary $BIN" >&2
  exit 1
fi

rm -rf "$STAGE"
install -d -m 0755 \
  "$STAGE/DEBIAN" \
  "$STAGE/opt/hdmi-kiosk/bin" \
  "$STAGE/opt/hdmi-kiosk/libexec" \
  "$STAGE/opt/hdmi-kiosk/qt" \
  "$STAGE/opt/hdmi-kiosk/share"

install -m 0755 "$BIN" "$STAGE/opt/hdmi-kiosk/libexec/hdmi-kiosk"
install -m 0755 "$LINUX_DIR/hdmi-kiosk-wrapper.sh" "$STAGE/opt/hdmi-kiosk/bin/hdmi-kiosk"
install -m 0755 "$LINUX_DIR/hdmi-kiosk-session.sh" "$STAGE/opt/hdmi-kiosk/bin/hdmi-kiosk-session"
install -m 0755 "$LINUX_DIR/hdmi-kiosk-session.sh" "$STAGE/opt/hdmi-kiosk/share/hdmi-kiosk-session.sh"
install -m 0755 "$LINUX_DIR/setup-kiosk-mode.sh" "$STAGE/opt/hdmi-kiosk/share/setup-kiosk-mode.sh"
install -m 0644 "$LINUX_DIR/99-hdmi-capture.rules" "$STAGE/opt/hdmi-kiosk/share/99-hdmi-capture.rules"
install -m 0644 "$LINUX_DIR/50-hdmi-kiosk-poweroff.rules" "$STAGE/opt/hdmi-kiosk/share/50-hdmi-kiosk-poweroff.rules"
install -m 0644 "$LINUX_DIR/hdmi-kiosk-poweroff.sudoers" "$STAGE/opt/hdmi-kiosk/share/hdmi-kiosk-poweroff.sudoers"
install -m 0644 "$LINUX_DIR/hdmi-kiosk.desktop" "$STAGE/opt/hdmi-kiosk/share/hdmi-kiosk.desktop"

echo "==> Đóng gói Qt runtime từ $QT_PREFIX"
copy_qt() {
  local src="$1" dest="$2"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude cmake --exclude pkgconfig --exclude '*.prl' --exclude '*.la' \
      "$src/" "$dest/"
  else
    cp -a "$src/." "$dest/"
  fi
}
copy_qt "$QT_PREFIX/lib" "$STAGE/opt/hdmi-kiosk/qt/lib"
copy_qt "$QT_PREFIX/plugins" "$STAGE/opt/hdmi-kiosk/qt/plugins"
copy_qt "$QT_PREFIX/qml" "$STAGE/opt/hdmi-kiosk/qt/qml"
if [[ -d "$QT_PREFIX/libexec" ]]; then
  copy_qt "$QT_PREFIX/libexec" "$STAGE/opt/hdmi-kiosk/qt/libexec"
fi
if [[ -d "$QT_PREFIX/translations" ]]; then
  copy_qt "$QT_PREFIX/translations" "$STAGE/opt/hdmi-kiosk/qt/translations"
fi

SIZE_KB="$(du -sk "$STAGE" | awk '{print $1}')"
cat >"$STAGE/DEBIAN/control" <<EOF
Package: hdmi-kiosk
Version: ${VERSION}
Section: video
Priority: optional
Architecture: ${ARCH}
Installed-Size: ${SIZE_KB}
Maintainer: HDMI Kiosk <hdmi-kiosk.local>
Depends: cage | weston, seatd, dbus-user-session, adduser, passwd, udev, policykit-1, ffmpeg, v4l-utils, gstreamer1.0-plugins-good, gstreamer1.0-plugins-base, gstreamer1.0-libav, libgl1, libgl1-mesa-dri, libegl1, libgles2, libdrm2, libgbm1, libfontconfig1, libfreetype6, fonts-dejavu-core, libxkbcommon0, libxkbcommon-x11-0, libxcb-cursor0, libxcb-icccm4, libxcb-image0, libxcb-keysyms1, libxcb-randr0, libxcb-render-util0, libxcb-shape0, libxcb-xinerama0, libxcb-xkb1, libxcb1, libx11-6, libx11-xcb1, libwayland-client0, libwayland-cursor0, libwayland-egl1, libwayland-server0, libpulse0, libasound2t64 | libasound2, libva2
Recommends: openssh-server
Description: HDMI capture kiosk (live, snapshot, record)
 Mini-PC kiosk: nhận HDMI Capture, chụp/ghi, xem lại.
 Sau khi cài, máy tự login user kiosk và chạy app toàn màn hình (cage).
EOF

install -m 0755 "$LINUX_DIR/debian/postinst" "$STAGE/DEBIAN/postinst"
install -m 0755 "$LINUX_DIR/debian/prerm" "$STAGE/DEBIAN/prerm"
install -m 0755 "$LINUX_DIR/debian/postrm" "$STAGE/DEBIAN/postrm"

echo "==> dpkg-deb $DEB"
rm -f "$DEB"
dpkg-deb --root-owner-group --build "$STAGE" "$DEB"
ls -lh "$DEB"

OFFLINE_NAME="hdmi-kiosk-offline_${VERSION}_${ARCH}"
OFFLINE_DIR="$DIST/$OFFLINE_NAME"
OFFLINE_TAR="$DIST/${OFFLINE_NAME}.tar.gz"
OFFLINE_RUN="$DIST/${OFFLINE_NAME}.run"
echo "==> Bộ cài offline $OFFLINE_DIR"
rm -rf "$OFFLINE_DIR"
install -d -m 0755 "$OFFLINE_DIR/repo"
python3 "$SCRIPT_DIR/collect-ubuntu-offline-debs.py" "$DEB" "$OFFLINE_DIR/repo" \
  --extra weston --extra openssh-server --extra libgl1-mesa-dri --extra fonts-dejavu-core
(cd "$OFFLINE_DIR/repo" && dpkg-scanpackages . /dev/null > Packages && gzip -kf Packages)
install -m 0755 "$LINUX_DIR/install-offline.sh" "$OFFLINE_DIR/install.sh"
cat >"$OFFLINE_DIR/README.txt" <<EOF
HDMI Kiosk — bộ cài Ubuntu offline (không cần mạng)

Máy đích: Ubuntu 24.04 LTS ${ARCH} (cùng bản với máy đóng gói).

Cách 1 — một file:
  sudo ./$(basename "$OFFLINE_RUN")
  sudo reboot

Cách 2 — thư mục/USB:
  sudo ./install.sh
  sudo reboot

Máy tự login user kiosk và chạy app toàn màn hình.
EOF

tar -C "$DIST" -czf "$OFFLINE_TAR" "$OFFLINE_NAME"
rm -f "$OFFLINE_RUN"
cat "$LINUX_DIR/offline-run-stub.sh" "$OFFLINE_TAR" >"$OFFLINE_RUN"
chmod +x "$OFFLINE_RUN"

echo
echo "==== BỘ CÀI ===="
ls -lh "$DEB" "$OFFLINE_TAR" "$OFFLINE_RUN"
echo
echo "Máy CÓ mạng:     sudo apt install -y ./$(basename "$DEB") && sudo reboot"
echo "Máy KHÔNG mạng:  copy $(basename "$OFFLINE_RUN") (USB) rồi:"
echo "                 sudo ./$(basename "$OFFLINE_RUN") && sudo reboot"
