import QtQuick
import QtMultimedia
import HdmiKiosk

Item {
    id: root

    property url source: ""
    property bool isImage: false
    property bool autoPlay: false
    property bool crop: true
    property bool muted: true
    property real zoom: 1.0
    property bool finished: false

    property bool playIconVisible: false

    readonly property bool hasSource: String(source).length > 0
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property bool atEnd: player.mediaStatus === MediaPlayer.EndOfMedia
            || (player.duration > 0 && player.position >= player.duration - 80)
    readonly property bool showTransport: !root.isImage && !root.crop && root.hasSource

    function bumpPlayIcon() {
        if (!root.showTransport)
            return
        root.playIconVisible = true
        playIconHide.restart()
    }

    function play() {
        if (root.isImage || !root.hasSource)
            return
        if (root.finished || root.atEnd) {
            root.finished = false
            player.position = 0
        }
        player.play()
        bumpPlayIcon()
    }

    function pause() {
        player.pause()
        bumpPlayIcon()
    }

    function stop() {
        player.stop()
        player.source = ""
    }

    function toggle() {
        if (root.isImage)
            return
        if (playing)
            pause()
        else
            play()
    }

    function seekBy(ms) {
        if (root.isImage)
            return
        const dur = player.duration
        const pos = player.position
        if (dur > 0)
            player.position = Math.max(0, Math.min(dur, pos + ms))
        else
            player.position = Math.max(0, pos + ms)
    }

    function zoomBy(delta) {
        if (!root.isImage || root.crop)
            return
        root.zoom = Math.max(1.0, Math.min(3.0, Math.round((root.zoom + delta) * 100) / 100))
    }

    function resetZoom() {
        root.zoom = 1.0
    }

    function formatMs(ms) {
        const total = Math.max(0, Math.floor(ms / 1000))
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = total % 60
        const pad = v => v < 10 ? "0" + v : "" + v
        if (h > 0)
            return pad(h) + ":" + pad(m) + ":" + pad(s)
        return pad(m) + ":" + pad(s)
    }

    onSourceChanged: {
        root.zoom = 1.0
        root.finished = false
        if (root.showTransport)
            bumpPlayIcon()
        else
            root.playIconVisible = false
    }
    onIsImageChanged: root.zoom = 1.0
    onShowTransportChanged: {
        if (root.showTransport)
            bumpPlayIcon()
        else
            root.playIconVisible = false
    }

    Item {
        id: imageViewport
        anchors.fill: parent
        clip: true
        visible: root.isImage && root.hasSource

        Image {
            id: previewImage
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: root.isImage && root.hasSource ? root.source : ""
            fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: true
            sourceSize.width: root.crop ? 352 : 0
            sourceSize.height: root.crop ? 200 : 0
            scale: root.crop ? 1 : root.zoom
            transformOrigin: Item.Center
        }
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        anchors.bottomMargin: root.showTransport ? 52 : 0
        visible: !root.isImage && root.hasSource
        fillMode: root.crop ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
    }

    MediaPlayer {
        id: player
        videoOutput: videoOut
        audioOutput: AudioOutput {
            muted: root.muted
            volume: root.muted ? 0 : 1
        }
        source: (!root.isImage && root.hasSource) ? root.source : ""
        autoPlay: false
        loops: 1
        onMediaStatusChanged: {
            if (!root.hasSource || root.isImage)
                return
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                root.finished = true
                player.pause()
                bumpPlayIcon()
                return
            }
            if (root.finished)
                return
            if (mediaStatus === MediaPlayer.LoadedMedia
                    || mediaStatus === MediaPlayer.BufferedMedia) {
                player.play()
            }
        }
        onSourceChanged: {
            root.finished = false
        }
        Component.onDestruction: stop()
    }

    Connections {
        target: videoOut.videoSink
        function onVideoFrameChanged() {
            if (root.autoPlay || root.finished || root.isImage)
                return
            if (player.playbackState === MediaPlayer.PlayingState)
                player.pause()
        }
    }

    Timer {
        id: playIconHide
        interval: 2000
        repeat: false
        onTriggered: root.playIconVisible = false
    }

    Item {
        anchors.fill: videoOut
        visible: root.showTransport
        z: 2

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggle()
        }

        Rectangle {
            width: Math.max(64, Math.min(112, parent.width * 0.147))
            height: width
            radius: width / 2
            anchors.centerIn: parent
            opacity: root.playIconVisible ? 1 : 0
            color: root.playing ? "#33000000" : "#59000000"
            border.width: 3
            border.color: "#99f4f7fb"
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            Text {
                anchors.centerIn: parent
                text: root.playing ? "II" : "▶"
                color: "#f4f7fb"
                font.pixelSize: Math.round(parent.width * 0.42)
                font.bold: true
            }
        }
    }

    Rectangle {
        visible: root.showTransport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 52
        color: Theme.overlay

        Text {
            id: playGlyph
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            color: Theme.text
            font.pixelSize: Theme.fontBody
            font.bold: true
            text: root.playing ? "II" : "▶"
        }

        Text {
            id: posLabel
            anchors.left: playGlyph.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            color: Theme.text
            font.pixelSize: Theme.fontSmall
            text: root.formatMs(player.position)
        }

        Text {
            id: durLabel
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            color: Theme.muted
            font.pixelSize: Theme.fontSmall
            horizontalAlignment: Text.AlignRight
            text: root.formatMs(player.duration)
        }

        Rectangle {
            id: seekBar
            anchors.left: posLabel.right
            anchors.right: durLabel.left
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 10
            radius: 5
            color: Theme.surfaceAlt

            Rectangle {
                width: player.duration > 0 ? parent.width * player.position / player.duration : 0
                height: parent.height
                radius: 5
                color: "#4c8dff"
            }

            MouseArea {
                anchors.fill: parent
                enabled: player.duration > 0
                onClicked: function(mouse) {
                    player.position = player.duration * mouse.x / Math.max(1, width)
                }
            }
        }
    }
}
