# Gói build Qt6 trên Raspberry Pi OS Bookworm và Trixie.
# Source từ build-on-pi.sh / install-raspberry-pi-kiosk.sh.

hdmi_kiosk_apt_install() {
  if [[ "${EUID}" -eq 0 ]]; then
    apt-get install -y "$@"
  else
    sudo apt-get install -y "$@"
  fi
}

hdmi_kiosk_install_build_deps() {
  hdmi_kiosk_apt_install \
    build-essential cmake ninja-build pkg-config \
    qt6-base-dev qt6-base-dev-tools qt6-declarative-dev qt6-multimedia-dev \
    qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates qml6-module-qtquick-window \
    qml6-module-qtqml qml6-module-qtqml-workerscript \
    qml6-module-qtmultimedia \
    libqt6multimedia6 \
    libdrm-dev libgbm-dev libxkbcommon-dev \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-libav \
    ffmpeg v4l-utils \
    libxcb-cursor0 libxcb-cursor-dev \
    qt6-wayland

  # Bookworm: libgl1-mesa-dev. Trixie: libgl-dev.
  hdmi_kiosk_apt_install libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev \
    || hdmi_kiosk_apt_install libgl-dev libegl-dev libgles-dev

  # Bookworm có gói này; Trixie gộp vào qml6-module-qtmultimedia.
  hdmi_kiosk_apt_install libqt6multimediaquick6 || true
}
