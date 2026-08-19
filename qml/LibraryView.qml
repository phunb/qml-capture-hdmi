import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HdmiKiosk

Item {
    id: root

    signal backRequested()
    signal playRequested(url source, string name)
    signal deleteRequested(int index, string name)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            KioskButton {
                text: qsTr("QUAY LẠI")
                onClicked: root.backRequested()
            }

            KioskButton {
                visible: !Library.atRoot
                text: qsTr("THƯ MỤC CHA")
                onClicked: Library.goUp()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: qsTr("Thư viện  (%1)").arg(Library.count)
                    color: Theme.text
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                }
                Text {
                    text: Library.displayPath
                    color: Theme.muted
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            Text {
                text: qsTr("Còn trống: %1").arg(Recordings.freeSpaceText)
                color: Theme.muted
                font.pixelSize: Theme.fontBody
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            model: Library
            currentIndex: Library.currentIndex
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 80

            delegate: Rectangle {
                required property int index
                required property string fileName
                required property string detailText
                required property url url
                required property bool isFolder

                width: ListView.view.width
                height: 96
                radius: Theme.radius
                color: index === Library.currentIndex ? "#2a3546" : Theme.surface
                border.width: index === Library.currentIndex ? 2 : 0
                border.color: "#4c8dff"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    Rectangle {
                        width: 64
                        height: 64
                        radius: 12
                        color: Theme.surfaceAlt
                        Text {
                            anchors.centerIn: parent
                            text: isFolder ? qsTr("📁") : qsTr("▶")
                            color: Theme.text
                            font.pixelSize: 28
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: fileName
                            color: Theme.text
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        Text {
                            text: detailText
                            color: Theme.muted
                            font.pixelSize: Theme.fontSmall
                        }
                    }

                    KioskButton {
                        text: isFolder ? qsTr("MỞ") : qsTr("PHÁT")
                        primary: true
                        implicitWidth: 140
                        implicitHeight: 64
                        onClicked: {
                            Library.currentIndex = index
                            if (isFolder)
                                Library.openAt(index)
                            else
                                root.playRequested(url, fileName)
                        }
                    }

                    KioskButton {
                        visible: !isFolder
                        text: qsTr("XÓA")
                        danger: true
                        implicitWidth: 120
                        implicitHeight: 64
                        onClicked: {
                            Library.currentIndex = index
                            root.deleteRequested(index, fileName)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: Library.currentIndex = index
                    onDoubleClicked: {
                        if (isFolder)
                            Library.openAt(index)
                        else
                            root.playRequested(url, fileName)
                    }
                }
            }

            Text {
                visible: Library.count === 0
                anchors.centerIn: parent
                text: qsTr("Thư mục trống.\nGốc thư viện: %1").arg(Library.rootPath)
                color: Theme.muted
                font.pixelSize: Theme.fontBody
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Text {
            color: Theme.muted
            font.pixelSize: Theme.fontSmall
            text: qsTr("Bàn phím: ↑↓ chọn   Enter mở/phát   Esc thư mục cha   Del xóa")
        }
    }
}
