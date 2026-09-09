cmake_minimum_required(VERSION 3.21)

project(HdmiKiosk VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

if(MSVC)
    add_compile_options(/utf-8)
endif()

option(HDMI_KIOSK_CONSOLE "Show a debug console on Windows" OFF)

find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Multimedia
)

qt_standard_project_setup(REQUIRES 6.5)
if(QT_VERSION VERSION_GREATER_EQUAL "6.8.0")
    qt_policy(SET QTP0004 NEW)
endif()

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_executable(hdmi-kiosk
    src/main.cpp
)

qt_add_qml_module(hdmi-kiosk
    URI HdmiKiosk
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/KioskButton.qml
        qml/ConfirmDialog.qml
        qml/LiveView.qml
        qml/NoSignalOverlay.qml
        qml/ClipPreview.qml
        qml/CopyProgressOverlay.qml
        qml/PreviewUsbCopyBar.qml
        qml/KioskToast.qml
    SOURCES
        src/AppSettings.h
        src/AppSettings.cpp
        src/CaptureController.h
        src/CaptureController.cpp
        src/RecordingManager.h
        src/RecordingManager.cpp
        src/VideoLibraryModel.h
        src/VideoLibraryModel.cpp
        src/KioskController.h
        src/KioskController.cpp
        src/HidInputRouter.h
        src/HidInputRouter.cpp
)

target_include_directories(hdmi-kiosk PRIVATE src)

target_link_libraries(hdmi-kiosk PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
)

if(WIN32)
    target_link_libraries(hdmi-kiosk PRIVATE user32 advapi32)
    if(NOT HDMI_KIOSK_CONSOLE)
        set_target_properties(hdmi-kiosk PROPERTIES WIN32_EXECUTABLE TRUE)
    endif()
endif()

target_compile_definitions(hdmi-kiosk PRIVATE
    APP_VERSION="${PROJECT_VERSION}"
)

install(TARGETS hdmi-kiosk
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)

install(DIRECTORY deploy/linux DESTINATION share/hdmi-kiosk)
install(DIRECTORY deploy/windows DESTINATION share/hdmi-kiosk)

enable_testing()
add_test(NAME smoke-load COMMAND hdmi-kiosk)
set_tests_properties(smoke-load PROPERTIES
    ENVIRONMENT "HDMI_KIOSK_SMOKE_TEST=1;HDMI_KIOSK_KIOSK_MODE=0;QT_QPA_PLATFORM=offscreen;HDMI_KIOSK_OUTPUT_DIR=/tmp/hdmi-output;QT_LOGGING_TO_CONSOLE=1"
    TIMEOUT 45
)
