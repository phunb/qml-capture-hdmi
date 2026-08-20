import QtQuick
import QtQuick.Layouts
import HdmiKiosk

Rectangle {
    id: root

    property bool recording: false
    property string durationText: "00:00"
    property string statusText: ""
    property bool canRecord: true
    property bool canCapture: true
    property int selectedIndex: 0

    readonly property int actionCount: 3

    signal captureClicked()
    signal recordClicked()
    signal libraryClicked()

    function activateSelected() {
        if (selectedIndex === 0)
            root.captureClicked()
        else if (selectedIndex === 1)
            root.recordClicked()
        else
            root.libraryClicked()
    }

    function moveSelection(delta) {
        const count = actionCount
        selectedIndex = (selectedIndex + delta % count + count) % count
    }

    height: 168
    color: Theme.bg

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            KioskButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: qsTr("CHỤP")
                primary: true
                selected: root.selectedIndex === 0
                enabled: root.canCapture
                onClicked: {
                    root.selectedIndex = 0
                    root.captureClicked()
                }
            }

            KioskButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.recording ? qsTr("DỪNG GHI\n%1").arg(root.durationText) : qsTr("GHI HÌNH")
                danger: true
                primary: true
                selected: root.selectedIndex === 1
                enabled: root.canRecord || root.recording
                onClicked: {
                    root.selectedIndex = 1
                    root.recordClicked()
                }
            }

            KioskButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: qsTr("THƯ VIỆN")
                selected: root.selectedIndex === 2
                enabled: !root.recording
                onClicked: {
                    root.selectedIndex = 2
                    root.libraryClicked()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.statusText.length > 0
            text: root.statusText
            color: root.recording ? Theme.accent : Theme.muted
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
        }

        Text {
            Layout.fillWidth: true
            color: Theme.muted
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Pedal: nhấn chụp    giữ 2s ghi    ↑↓ chọn    Enter thực hiện")
        }
    }
}
