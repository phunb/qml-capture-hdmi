import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HdmiKiosk

Popup {
    id: root

    property string titleText: ""
    property string messageText: ""
    property string confirmText: qsTr("Đồng ý")
    property string cancelText: qsTr("Hủy")
    property bool danger: false
    property bool confirmSelected: false

    signal confirmed()
    signal cancelled()

    modal: true
    dim: true
    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    padding: 28
    width: Math.min(720, Overlay.overlay ? Overlay.overlay.width - 48 : 720)

    background: Rectangle {
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.surfaceAlt
        border.width: 1
    }

    Overlay.modal: Rectangle {
        color: "#99000000"
    }

    contentItem: ColumnLayout {
        spacing: 20

        Text {
            text: root.titleText
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.bold: true
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Text {
            text: root.messageText
            color: Theme.muted
            font.pixelSize: Theme.fontBody
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            KioskButton {
                Layout.fillWidth: true
                text: root.cancelText
                selected: !root.confirmSelected
                onClicked: {
                    root.cancelled()
                    root.close()
                }
            }

            KioskButton {
                Layout.fillWidth: true
                text: root.confirmText
                danger: root.danger
                primary: true
                selected: root.confirmSelected
                onClicked: {
                    root.confirmed()
                    root.close()
                }
            }
        }

        Text {
            text: qsTr("Pedal: Hủy")
            color: Theme.muted
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
