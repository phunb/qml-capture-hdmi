import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import HdmiKiosk

Item {
    id: root

    signal backRequested()
    signal playRequested(url source, string name, bool isImage)
    signal deleteRequested(int index, string name)

    property int footerIndex: 0

    function activateFooter() {
        if (footerIndex === 2) {
            root.backRequested()
            return
        }
        if (Library.count <= 0)
            return
        if (footerIndex === 1) {
            if (Library.currentIsFolder)
                Library.openCurrent()
            else
                root.playRequested(Library.currentUrl, Library.currentName, Library.currentIsImage)
        } else if (footerIndex === 0 && !Library.currentIsFolder) {
            root.deleteRequested(Library.currentIndex, Library.currentName)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

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
                Text {
                    text: AppSettings.storageReady
                          ? qsTr("%1   •   Còn trống: %2")
                            .arg(AppSettings.storageLabel, Recordings.freeSpaceText)
                          : qsTr("Bạn cần cắm USB để lưu file")
                    color: AppSettings.storageReady ? Theme.live : Theme.warning
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            cacheBuffer: 280
            reuseItems: true
            model: Library
            currentIndex: Library.currentIndex
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 80
            highlightFollowsCurrentItem: true

            delegate: Rectangle {
                required property int index
                required property string fileName
                required property string detailText
                required property url url
                required property bool isFolder
                required property bool isImage

                width: ListView.view.width
                height: 124
                radius: Theme.radius
                color: index === Library.currentIndex ? "#2a3546" : Theme.surface
                border.width: index === Library.currentIndex ? 3 : 0
                border.color: "#f5c542"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 176
                        Layout.preferredHeight: 100
                        radius: 12
                        color: Theme.surfaceAlt
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            visible: isFolder
                            text: qsTr("THƯ MỤC")
                            color: Theme.muted
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Image {
                            anchors.fill: parent
                            visible: isImage
                            source: isImage ? url : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 352
                            sourceSize.height: 200
                        }

                        VideoOutput {
                            id: videoThumb
                            anchors.fill: parent
                            visible: !isFolder && !isImage
                            fillMode: VideoOutput.PreserveAspectCrop
                        }

                        MediaPlayer {
                            id: thumbPlayer
                            videoOutput: videoThumb
                            audioOutput: AudioOutput { muted: true; volume: 0 }
                            source: (!isFolder && !isImage) ? url : ""
                            autoPlay: false
                            onMediaStatusChanged: {
                                if (!visible)
                                    return
                                if (mediaStatus === MediaPlayer.LoadedMedia
                                        || mediaStatus === MediaPlayer.BufferedMedia) {
                                    if (position === 0)
                                        play()
                                }
                            }
                            onPlaybackStateChanged: {
                                if (playbackState === MediaPlayer.PlayingState)
                                    pause()
                            }
                            Component.onCompleted: {
                                if (source != "")
                                    play()
                            }
                            Component.onDestruction: stop()
                        }

                        Rectangle {
                            visible: !isFolder && !isImage
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: 28
                            height: 28
                            radius: 14
                            color: "#99000000"
                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                color: Theme.text
                                font.pixelSize: 12
                            }
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
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Library.currentIndex = index
                    onDoubleClicked: {
                        if (isFolder)
                            Library.openAt(index)
                        else
                            root.playRequested(url, fileName, isImage)
                    }
                }
            }

            Text {
                visible: Library.count === 0
                anchors.centerIn: parent
                text: AppSettings.storageReady
                      ? qsTr("Thư mục trống.\n%1").arg(Library.rootPath)
                      : qsTr("Bạn cần cắm USB để lưu file")
                color: AppSettings.storageReady ? Theme.muted : Theme.warning
                font.pixelSize: Theme.fontBody
                horizontalAlignment: Text.AlignHCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            KioskButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 88
                text: qsTr("XÓA")
                danger: true
                selected: root.footerIndex === 0
                enabled: Library.count > 0 && !Library.currentIsFolder
                onClicked: {
                    root.footerIndex = 0
                    root.deleteRequested(Library.currentIndex, Library.currentName)
                }
            }

            KioskButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 88
                text: Library.currentIsFolder ? qsTr("MỞ") : (Library.currentIsImage ? qsTr("XEM") : qsTr("PHÁT"))
                primary: true
                selected: root.footerIndex === 1
                enabled: Library.count > 0
                onClicked: {
                    root.footerIndex = 1
                    root.activateFooter()
                }
            }

            KioskButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 88
                text: qsTr("QUAY LẠI")
                selected: root.footerIndex === 2
                onClicked: {
                    root.footerIndex = 2
                    root.backRequested()
                }
            }
        }

        Text {
            color: Theme.muted
            font.pixelSize: Theme.fontSmall
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("↑↓ chọn file    Enter mở    Esc quay lại    Del xóa")
        }
    }
}
