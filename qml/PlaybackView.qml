import QtQuick
import QtQuick.Layouts
import QtMultimedia
import HdmiKiosk

Item {
    id: root

    property url source: ""
    property string titleText: ""
    property bool isImage: false
    property int selectedIndex: 1

    signal backRequested()

    function play(url, name, image) {
        root.source = url
        root.titleText = name
        root.isImage = !!image
        root.selectedIndex = 1
        if (root.isImage) {
            player.stop()
            player.source = ""
            return
        }
        player.source = url
        player.play()
    }

    function stopPlayback() {
        player.stop()
        player.source = ""
        root.source = ""
        root.titleText = ""
        root.isImage = false
    }

    function togglePlay() {
        if (root.isImage)
            return
        if (player.playbackState === MediaPlayer.PlayingState)
            player.pause()
        else
            player.play()
    }

    function seekBy(ms) {
        if (root.isImage)
            return
        player.position = Math.max(0, Math.min(player.duration, player.position + ms))
    }

    function moveSelection(delta) {
        const count = root.isImage ? 1 : 4
        selectedIndex = (selectedIndex + delta % count + count) % count
    }

    function activateSelected() {
        if (selectedIndex === 0 || root.isImage) {
            root.backRequested()
            return
        }
        if (selectedIndex === 1)
            root.togglePlay()
        else if (selectedIndex === 2)
            root.seekBy(-10000)
        else if (selectedIndex === 3)
            root.seekBy(10000)
    }

    MediaPlayer {
        id: player
        videoOutput: playbackOutput
        audioOutput: AudioOutput { volume: 1.0 }
    }

    VideoOutput {
        id: playbackOutput
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: playbackBar.top
        fillMode: VideoOutput.PreserveAspectFit
        visible: !root.isImage
    }

    Image {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: playbackBar.top
        fillMode: Image.PreserveAspectFit
        source: root.isImage ? root.source : ""
        visible: root.isImage
        asynchronous: true
    }

    MouseArea {
        anchors.fill: playbackOutput
        enabled: !root.isImage
        onClicked: root.togglePlay()
    }

    Rectangle {
        id: playbackBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 148
        color: Theme.bg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: root.titleText
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.bold: true
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }

            Rectangle {
                id: seekBar
                Layout.fillWidth: true
                height: 18
                radius: 9
                color: Theme.surfaceAlt
                visible: !root.isImage

                Rectangle {
                    width: player.duration > 0 ? parent.width * player.position / player.duration : 0
                    height: parent.height
                    radius: 9
                    color: "#4c8dff"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: player.duration > 0
                    onClicked: function(mouse) {
                        player.position = player.duration * mouse.x / width
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                KioskButton {
                    text: qsTr("QUAY LẠI")
                    selected: root.selectedIndex === 0
                    onClicked: {
                        root.selectedIndex = 0
                        root.backRequested()
                    }
                }

                KioskButton {
                    visible: !root.isImage
                    text: player.playbackState === MediaPlayer.PlayingState ? qsTr("TẠM DỪNG") : qsTr("PHÁT")
                    primary: true
                    selected: root.selectedIndex === 1
                    onClicked: {
                        root.selectedIndex = 1
                        root.togglePlay()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.muted
                    font.pixelSize: Theme.fontBody
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isImage ? qsTr("Enter / Esc: quay lại")
                                       : (formatMs(player.position) + " / " + formatMs(player.duration))
                }

                KioskButton {
                    visible: !root.isImage
                    text: qsTr("-10s")
                    selected: root.selectedIndex === 2
                    onClicked: {
                        root.selectedIndex = 2
                        root.seekBy(-10000)
                    }
                }

                KioskButton {
                    visible: !root.isImage
                    text: qsTr("+10s")
                    selected: root.selectedIndex === 3
                    onClicked: {
                        root.selectedIndex = 3
                        root.seekBy(10000)
                    }
                }
            }
        }
    }

    function formatMs(ms) {
        const total = Math.floor(ms / 1000)
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = total % 60
        const pad = v => v < 10 ? "0" + v : "" + v
        if (h > 0)
            return pad(h) + ":" + pad(m) + ":" + pad(s)
        return pad(m) + ":" + pad(s)
    }
}
