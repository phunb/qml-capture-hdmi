import QtQuick
import QtQuick.Layouts
import HdmiKiosk

Rectangle {
    id: root

    property bool recording: false
    property string durationText: "00:00"
    property string statusText: ""
    property bool canRecord: true

    signal recordClicked()
    signal libraryClicked()

    height: 112
    color: Theme.overlay

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        KioskButton {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            text: root.recording ? qsTr("DỪNG GHI  %1").arg(root.durationText) : qsTr("GHI HÌNH")
            danger: true
            primary: true
            enabled: root.canRecord || root.recording
            onClicked: root.recordClicked()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                width: parent.width
                text: root.statusText
                color: root.recording ? Theme.accent : Theme.muted
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        KioskButton {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            text: qsTr("THƯ VIỆN")
            enabled: !root.recording
            onClicked: root.libraryClicked()
        }
    }
}
