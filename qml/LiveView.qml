import QtQuick
import QtQuick.Layouts
import QtMultimedia
import HdmiKiosk

Item {
    id: root

    property alias selectedAction: bar.selectedIndex

    signal openLibrary()

    function activateSelected() {
        bar.activateSelected()
    }

    function moveSelection(delta) {
        bar.moveSelection(delta)
    }

    VideoOutput {
        id: preview
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: bar.top
        fillMode: VideoOutput.PreserveAspectFit

        Component.onCompleted: Capture.setPreviewOutput(preview)
    }

    Rectangle {
        anchors.fill: preview
        color: Theme.bg
        visible: !Capture.signalPresent
        z: 1

        NoSignalOverlay {
            anchors.fill: parent
            message: {
                if (!Capture.hasDevice)
                    return qsTr("Không tìm thấy HDMI Capture")
                if (Capture.status === "error")
                    return qsTr("Lỗi thiết bị")
                return qsTr("Không có tín hiệu HDMI")
            }
            detail: Capture.statusMessage
        }
    }

    Rectangle {
        id: snapFlash
        anchors.fill: preview
        color: "#88ffffff"
        opacity: 0
        z: 5
        SequentialAnimation on opacity {
            id: snapAnim
            running: false
            NumberAnimation { to: 0.55; duration: 60 }
            NumberAnimation { to: 0; duration: 180 }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 20
        radius: 16
        color: Theme.overlay
        width: statusRow.implicitWidth + 28
        height: 52
        visible: Capture.recording || Capture.signalPresent || Capture.flashMessage.length > 0
        z: 2

        RowLayout {
            id: statusRow
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: Capture.recording ? Theme.accent : Theme.live
                SequentialAnimation on opacity {
                    running: Capture.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }

            Text {
                text: Capture.flashMessage.length > 0
                      ? Capture.flashMessage
                      : (Capture.recording
                         ? qsTr("REC  %1").arg(Capture.recordingDurationText)
                         : qsTr("LIVE"))
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.bold: true
            }
        }
    }

    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 6
        z: 2
        width: Math.min(parent.width * 0.42, 420)

        Text {
            width: parent.width
            color: Theme.muted
            font.pixelSize: Theme.fontSmall
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: Capture.currentDeviceName
            MouseArea {
                anchors.fill: parent
                enabled: Capture.deviceNames.length > 1 && !Capture.recording
                onClicked: {
                    const next = (Capture.currentDeviceIndex + 1) % Capture.deviceNames.length
                    Capture.currentDeviceIndex = next
                }
            }
        }

        Text {
            width: parent.width
            color: AppSettings.usingUsb ? Theme.live : Theme.warning
            font.pixelSize: Theme.fontSmall
            font.bold: true
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: AppSettings.usingUsb
                  ? qsTr("Lưu USB: %1").arg(AppSettings.storageLabel)
                  : qsTr("Lưu: %1").arg(AppSettings.storageLabel)
        }
    }

    ControlBar {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 2
        recording: Capture.recording
        durationText: Capture.recordingDurationText
        statusText: Capture.statusMessage
        canRecord: Capture.hasDevice
        canCapture: Capture.hasDevice && Capture.signalPresent
        onCaptureClicked: Capture.captureSnapshot()
        onRecordClicked: Capture.toggleRecording()
        onLibraryClicked: root.openLibrary()
    }

    Connections {
        target: Capture
        function onSnapshotCaptured(path) {
            snapAnim.restart()
        }
    }
}
