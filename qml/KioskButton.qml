import QtQuick
import QtQuick.Controls
import HdmiKiosk

Button {
    id: root

    property color baseColor: Theme.surfaceAlt
    property color textColor: Theme.text
    property bool danger: false
    property bool primary: false

    implicitHeight: Theme.touch
    implicitWidth: 180
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    background: Rectangle {
        radius: Theme.radius
        color: {
            if (root.down)
                return Qt.darker(fillColor(), 1.18)
            if (root.hovered || root.activeFocus)
                return Qt.lighter(fillColor(), 1.12)
            return fillColor()
        }
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.text

        function fillColor() {
            if (root.danger)
                return root.primary ? Theme.accent : Theme.accentDark
            if (root.primary)
                return "#2f6df6"
            return root.baseColor
        }
    }

    contentItem: Text {
        text: root.text
        color: root.textColor
        font.pixelSize: Theme.fontBody
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }
}
