import QtQuick
import HdmiKiosk

Rectangle {
    id: root

    readonly property bool active: Recordings.copying || Recordings.copyMessage.length > 0
    readonly property bool failed: !Recordings.copying && Recordings.copyError
    readonly property color accent: failed ? Theme.accent : "#4c8dff"

    visible: active
    width: parent ? parent.width : 0
    height: active ? column.implicitHeight + 20 : 0
    color: Theme.overlay
    border.color: active ? accent : "transparent"
    border.width: active ? 2 : 0
    radius: 8

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        Text {
            width: parent.width
            text: Recordings.copyMessage
            color: Theme.text
            font.pixelSize: Theme.fontBody
            font.bold: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            visible: Recordings.copying
            text: qsTr("%1%").arg(Recordings.copyProgress)
            color: accent
            font.pixelSize: Theme.fontSmall
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            width: parent.width
            height: 14
            radius: 7
            color: Theme.surfaceAlt
            visible: Recordings.copying

            Rectangle {
                width: parent.width * Recordings.copyProgress / 100
                height: parent.height
                radius: 7
                color: accent
                Behavior on width {
                    NumberAnimation { duration: 120 }
                }
            }
        }
    }
}
