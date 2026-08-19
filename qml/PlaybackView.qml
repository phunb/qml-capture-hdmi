import QtQuick
import QtQuick.Layouts
import QtMultimedia
import HdmiKiosk

Item {
    id: root

    property url source: ""
    property string titleText: ""

    signal backRequested()

    function play(url, name) {
        root.source = url
        root.titleText = name
        player.source = url
        player.play()
    }

    function stopPlayback() {
        player.stop()
        player.source = ""
        root.source = ""
        root.titleText = ""
    }

    function togglePlay() {
        if (player.playbackState === MediaPlayer.PlayingState)
            player.pause()
        else
            player.play()
    }

    function seekBy(ms) {
        player.position = Math.max(0, Math.min(player.duration, player.position + ms))
    }

    MediaPlayer {
        id: player
        videoOutput: playbackOutput
        audioOutput: AudioOutput { volume: 1.0 }
    }

    VideoOutput {
        id: playbackOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.togglePlay()
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 148
        color: Theme.overlay

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
                    onClicked: root.backRequested()
                }

                KioskButton {
                    text: player.playbackState === MediaPlayer.PlayingState ? qsTr("TẠM DỪNG") : qsTr("PHÁT")
                    primary: true
                    onClicked: root.togglePlay()
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.muted
                    font.pixelSize: Theme.fontBody
                    horizontalAlignment: Text.AlignHCenter
                    text: formatMs(player.position) + " / " + formatMs(player.duration)
                }

                KioskButton {
                    text: qsTr("-10s")
                    onClicked: root.seekBy(-10000)
                }

                KioskButton {
                    text: qsTr("+10s")
                    onClicked: root.seekBy(10000)
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
