import QtQuick
import HdmiKiosk

Item {
    id: root

    property string message: ""

    visible: message.length > 0
    z: 90

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, Math.max(label.implicitWidth + 64, 480))
        height: label.implicitHeight + 48
        radius: 20
        color: "#f2151a22"
        border.width: 3
        border.color: Theme.warning

        Text {
            id: label
            anchors.centerIn: parent
            width: Math.min(root.width - 96, 760)
            text: root.message
            color: Theme.text
            font.pixelSize: 32
            font.bold: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
