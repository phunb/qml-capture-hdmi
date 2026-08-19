import QtQuick
import HdmiKiosk

Item {
    id: root
    property string message: qsTr("Không có tín hiệu HDMI")
    property string detail: qsTr("Kiểm tra cáp nguồn HDMI và thiết bị đầu vào.")

    Rectangle {
        anchors.fill: parent
        color: Theme.bg

        Column {
            anchors.centerIn: parent
            spacing: 18
            width: Math.min(parent.width - 80, 720)

            Row {
                spacing: 10
                width: parent.width
                Repeater {
                    model: ["#f43f5e", "#f59e0b", "#22c55e", "#3b82f6", "#a855f7", "#111827"]
                    Rectangle {
                        width: parent.width / 6 - 8
                        height: 56
                        radius: 8
                        color: modelData
                    }
                }
            }

            Text {
                width: parent.width
                text: root.message
                color: Theme.text
                font.pixelSize: 36
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: root.detail
                color: Theme.muted
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
