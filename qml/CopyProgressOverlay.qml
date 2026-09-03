import QtQuick
import HdmiKiosk

Rectangle {
    id: root

    readonly property bool active: Recordings.copying || Recordings.copyMessage.length > 0
    readonly property bool failed: !Recordings.copying && Recordings.copyError
    readonly property bool done: !Recordings.copying && !Recordings.copyError && Recordings.copyMessage.length > 0
    readonly property color accent: failed ? Theme.accent : (done ? "#3dd68c" : "#4c8dff")

    visible: active
    anchors.fill: parent
    color: "#e607090c"
    z: 100

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 820)
        height: column.implicitHeight + 56
        radius: 24
        color: Theme.surface
        border.color: root.accent
        border.width: 3

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 36
            anchors.rightMargin: 36
            spacing: 18

            Text {
                width: parent.width
                text: Recordings.copying
                      ? qsTr("CHÉP SANG USB")
                      : (root.failed ? qsTr("LỖI USB") : qsTr("XONG"))
                color: Theme.text
                font.pixelSize: Theme.fontTitle
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                visible: Recordings.copying || root.done
                text: qsTr("%1%").arg(Recordings.copyProgress)
                color: root.accent
                font.pixelSize: Theme.fontHuge
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: parent.width
                height: 28
                radius: 14
                color: Theme.surfaceAlt
                visible: Recordings.copying || root.done

                Rectangle {
                    width: parent.width * Recordings.copyProgress / 100
                    height: parent.height
                    radius: 14
                    color: root.accent
                    Behavior on width {
                        NumberAnimation { duration: 120 }
                    }
                }
            }

            Text {
                width: parent.width
                text: Recordings.copying
                      ? qsTr("Giữ USB — không rút")
                      : Recordings.copyMessage
                color: Theme.text
                font.pixelSize: 28
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: Recordings.copying
                      ? qsTr("Đợi đến khi xong")
                      : (root.failed
                         ? qsTr("Cắm lại USB rồi nhấn 1 2 3 4")
                         : qsTr("Có thể rút USB"))
                color: Theme.muted
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
