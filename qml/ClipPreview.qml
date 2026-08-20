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

    readonly property bool hasSource: String(source).length > 0
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState

    function play() {
        if (!root.isImage && root.hasSource)
            player.play()
    }

    function pause() {
        player.pause()
    }

    function stop() {
        player.stop()
        player.source = ""
    }

    function toggle() {
        if (root.isImage)
            return
        if (playing)
            player.pause()
        else
            player.play()
    }

    function seekBy(ms) {
        if (root.isImage || player.duration <= 0)
            return
        player.position = Math.max(0, Math.min(player.duration, player.position + ms))
    }

    Image {
        anchors.fill: parent
        visible: root.isImage && root.hasSource
        source: root.isImage && root.hasSource ? root.source : ""
        fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        asynchronous: true
        cache: true
        sourceSize.width: root.crop ? 352 : 0
        sourceSize.height: root.crop ? 200 : 0
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
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
        onMediaStatusChanged: {
            if (!root.hasSource || root.isImage)
                return
            if (mediaStatus === MediaPlayer.LoadedMedia
                    || mediaStatus === MediaPlayer.BufferedMedia) {
                if (root.autoPlay)
                    play()
                else if (position === 0)
                    play()
            }
        }
        onPlaybackStateChanged: {
            if (!root.autoPlay && playbackState === MediaPlayer.PlayingState)
                pause()
        }
        Component.onCompleted: {
            if (!root.isImage && root.hasSource)
                play()
        }
        Component.onDestruction: stop()
    }
}
