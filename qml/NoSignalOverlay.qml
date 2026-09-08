import QtQuick
import HdmiKiosk

Item {
    id: root

    Column {
        anchors.centerIn: parent
        width: parent.width - 64
        spacing: 12

        Text {
            width: parent.width
            text: {
                if (!Capture.hasDevice)
                    return qsTr("Không có HDMI Capture")
                if (Capture.status === "error")
                    return qsTr("Lỗi thiết bị")
                return qsTr("Không có tín hiệu HDMI")
            }
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.bold: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: qsTr("Cắm cáp HDMI IN rồi đợi")
            color: Theme.muted
            font.pixelSize: Theme.fontBody
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            visible: Kiosk.idlePowerOffRemainingSec > 0 && Kiosk.idlePowerOffRemainingSec <= 120
            text: qsTr("Tự tắt máy sau %1:%2")
                  .arg(Math.floor(Kiosk.idlePowerOffRemainingSec / 60))
                  .arg(("0" + (Kiosk.idlePowerOffRemainingSec % 60)).slice(-2))
            color: Theme.warning
            font.pixelSize: Theme.fontBody
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
