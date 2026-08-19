# syntax=docker/dockerfile:1
# Build + smoke test HDMI Kiosk trên Ubuntu 24.04 (không cần HDMI thật).

ARG QT_VERSION=6.8.3
ARG QT_ROOT=/opt/Qt

FROM ubuntu:24.04 AS qt
ARG QT_VERSION
ARG QT_ROOT
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl python3 python3-venv \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/aqt \
    && /opt/aqt/bin/pip install --no-cache-dir aqtinstall \
    && /opt/aqt/bin/python -m aqt install-qt \
        -O ${QT_ROOT} linux desktop ${QT_VERSION} gcc_64 \
        -m qtmultimedia qtshadertools qtimageformats \
        --archives qtbase qtdeclarative qtsvg qttools

FROM ubuntu:24.04 AS build
ARG QT_VERSION
ARG QT_ROOT
ENV DEBIAN_FRONTEND=noninteractive
ENV CMAKE_PREFIX_PATH=${QT_ROOT}/${QT_VERSION}/gcc_64
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake ninja-build g++ \
        libgl1 libegl1 libfontconfig1 libfreetype6 \
        libxkbcommon0 libxkbcommon-x11-0 \
        libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
        libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 \
        libxcb-xkb1 libxcb1 libx11-6 libx11-xcb1 \
        libwayland-client0 libwayland-cursor0 libwayland-egl1 \
        libpulse0 libasound2t64 libva2 libdrm2 libgbm1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=qt ${QT_ROOT} ${QT_ROOT}
WORKDIR /src
COPY CMakeLists.txt ./
COPY src ./src
COPY qml ./qml
RUN cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH} \
    && cmake --build build --parallel

FROM ubuntu:24.04 AS test
ARG QT_VERSION
ARG QT_ROOT
ENV DEBIAN_FRONTEND=noninteractive
ENV CMAKE_PREFIX_PATH=${QT_ROOT}/${QT_VERSION}/gcc_64
ENV LD_LIBRARY_PATH=${QT_ROOT}/${QT_VERSION}/gcc_64/lib
ENV QT_PLUGIN_PATH=${QT_ROOT}/${QT_VERSION}/gcc_64/plugins
ENV QML_IMPORT_PATH=${QT_ROOT}/${QT_VERSION}/gcc_64/qml
ENV QT_QPA_PLATFORM=offscreen
ENV HDMI_KIOSK_SMOKE_TEST=1
ENV HDMI_KIOSK_KIOSK_MODE=0
ENV HDMI_KIOSK_OUTPUT_DIR=/tmp/hdmi-output
ENV LIBGL_ALWAYS_SOFTWARE=1
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates cmake \
        libgl1 libegl1 libopengl0 libfontconfig1 libfreetype6 \
        libxkbcommon0 libxkbcommon-x11-0 \
        libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
        libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 \
        libxcb-xkb1 libxcb1 libx11-6 libx11-xcb1 \
        libwayland-client0 libwayland-cursor0 libwayland-egl1 \
        libpulse0 libasound2t64 libva2 libdrm2 libgbm1 \
        libglib2.0-0 libicu74 libpcre2-16-0 libdouble-conversion3 \
        libmd4c0 libharfbuzz0b libpng16-16t64 libjpeg-turbo8 zlib1g \
        libbrotli1 libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=qt ${QT_ROOT} ${QT_ROOT}
COPY --from=build /src/build /src/build
WORKDIR /src/build
CMD ["ctest", "--output-on-failure", "--timeout", "45"]
