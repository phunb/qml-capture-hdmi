import QtQuick
import HdmiKiosk

Item {
    id: root

    Text {
        anchors.centerIn: parent
        width: parent.width - 48
        text: {
            if (!Capture.hasDevice)
                return qsTr("Không có HDMI Capture")
            if (Capture.status === "error")
                return qsTr("Lỗi thiết bị")
            return qsTr("Không có tín hiệu")
        }
        color: Theme.muted
        font.pixelSize: Theme.fontBody
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
