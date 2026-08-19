import QtQuick
import QtQuick.Layouts
import QtMultimedia
import HdmiKiosk

Item {
    id: root

    signal openLibrary()

    VideoOutput {
        id: preview
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit

        Component.onCompleted: Capture.setPreviewOutput(preview)
    }

    Rectangle {
        anchors.fill: parent
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
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 20
        radius: 16
        color: Theme.overlay
        width: statusRow.implicitWidth + 28
        height: 52
        visible: Capture.recording || Capture.signalPresent
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
                text: Capture.recording
                      ? qsTr("REC  %1").arg(Capture.recordingDurationText)
                      : qsTr("LIVE")
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.bold: true
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        z: 2
        color: Theme.muted
        font.pixelSize: Theme.fontSmall
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

    ControlBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 2
        recording: Capture.recording
        durationText: Capture.recordingDurationText
        statusText: Capture.statusMessage
        canRecord: Capture.hasDevice
        onRecordClicked: Capture.toggleRecording()
        onLibraryClicked: root.openLibrary()
    }
}
