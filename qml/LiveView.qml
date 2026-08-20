import QtQuick
import QtQuick.Controls
import QtMultimedia
import HdmiKiosk

Item {
    id: root

    property bool previewing: false

    readonly property int rightWidth: Math.max(240, Math.min(340, width * 0.26))
    readonly property int latestIndex: {
        const n = Library.count
        for (let i = 0; i < n; ++i) {
            if (!Library.isFolderAt(i))
                return i
        }
        return -1
    }
    readonly property url latestUrl: latestIndex >= 0 ? Library.urlAt(latestIndex) : ""
    readonly property bool latestIsImage: latestIndex >= 0 ? Library.isImageAt(latestIndex) : true

    function activateSelected() {
        openCurrent()
    }

    function moveSelection(delta) {
        Library.moveCurrent(delta)
        list.positionViewAtIndex(Library.currentIndex, ListView.Contain)
    }

    function enterPreview() {
        if (latestIndex < 0)
            return
        previewing = true
        lastClip.crop = false
        lastClip.muted = false
        if (!latestIsImage)
            lastClip.play()
    }

    function exitPreview() {
        previewing = false
        lastClip.crop = true
        lastClip.muted = true
        if (!latestIsImage)
            lastClip.pause()
    }

    function togglePreview() {
        if (previewing)
            exitPreview()
        else
            enterPreview()
    }

    function openCurrent() {
        if (Library.count <= 0)
            return
        if (Library.currentIsFolder) {
            Library.openCurrent()
            return
        }
        enterPreview()
    }

    function togglePlay() {
        if (previewing)
            lastClip.toggle()
        else
            enterPreview()
    }

    function seekBy(ms) {
        if (previewing)
            lastClip.seekBy(ms)
        else
            moveSelection(ms > 0 ? 1 : -1)
    }

    function selectLatest() {
        if (latestIndex >= 0)
            Library.currentIndex = latestIndex
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Item {
        id: mainPane
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: sideColumn.left
        anchors.margins: 16
        anchors.rightMargin: 12

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            border.color: Theme.surfaceAlt
            border.width: 1
            radius: 4
        }

        VideoOutput {
            id: liveOutput
            parent: root.previewing ? pipLiveSlot : liveMainSlot
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            Component.onCompleted: Capture.setPreviewOutput(liveOutput)
        }

        Item {
            id: liveMainSlot
            anchors.fill: parent
            visible: !root.previewing
            clip: true
        }

        Item {
            id: clipMainSlot
            anchors.fill: parent
            visible: root.previewing
            clip: true
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            visible: !root.previewing && !Capture.signalPresent
            z: 1
            NoSignalOverlay {
                anchors.fill: parent
            }
        }

        Rectangle {
            id: snapFlash
            anchors.fill: parent
            color: "#88ffffff"
            opacity: 0
            z: 4
            SequentialAnimation on opacity {
                id: snapAnim
                running: false
                NumberAnimation { to: 0.45; duration: 50 }
                NumberAnimation { to: 0; duration: 160 }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 16
            radius: 8
            color: Theme.overlay
            width: statusLabel.implicitWidth + 24
            height: 40
            visible: Capture.recording || Capture.flashMessage.length > 0
            z: 5

            Text {
                id: statusLabel
                anchors.centerIn: parent
                text: Capture.flashMessage.length > 0
                      ? Capture.flashMessage
                      : qsTr("REC  %1").arg(Capture.recordingDurationText)
                color: Capture.recording && Capture.flashMessage.length === 0 ? Theme.accent : Theme.text
                font.pixelSize: Theme.fontBody
                font.bold: true
            }
        }
    }

    Column {
        id: sideColumn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.leftMargin: 0
        width: root.rightWidth
        spacing: 12

        Rectangle {
            id: pipFrame
            width: parent.width
            height: Math.round(width * 9 / 16)
            color: Theme.surface
            border.color: Theme.surfaceAlt
            border.width: 1
            radius: 4
            clip: true

            Item {
                id: pipLiveSlot
                anchors.fill: parent
                visible: root.previewing
            }

            Item {
                id: clipPipSlot
                anchors.fill: parent
                visible: !root.previewing
            }

            MouseArea {
                anchors.fill: parent
                enabled: !Capture.recording
                onClicked: root.togglePreview()
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - pipFrame.height - parent.spacing
            color: Theme.surface
            border.color: Theme.surfaceAlt
            border.width: 1
            radius: 4
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                spacing: 8
                cacheBuffer: 240
                reuseItems: false
                model: Library
                currentIndex: Library.currentIndex
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 80
                highlightFollowsCurrentItem: true
                ScrollBar.vertical: ScrollBar {
                    policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Rectangle {
                    id: row
                    required property int index
                    required property url url
                    required property bool isFolder
                    required property bool isImage

                    width: ListView.view.width
                    height: Math.round(width * 9 / 16)
                    radius: 4
                    color: Theme.surfaceAlt
                    clip: false

                    Item {
                        anchors.fill: parent
                        anchors.margins: 3
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            visible: row.isFolder
                            text: qsTr("THƯ MỤC")
                            color: Theme.muted
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Image {
                            anchors.fill: parent
                            visible: row.isImage
                            source: row.isImage ? row.url : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 352
                            sourceSize.height: 200
                        }

                        VideoOutput {
                            id: videoThumb
                            anchors.fill: parent
                            visible: !row.isFolder && !row.isImage
                            fillMode: VideoOutput.PreserveAspectCrop
                        }
                    }

                    MediaPlayer {
                        id: thumbPlayer
                        videoOutput: videoThumb
                        audioOutput: AudioOutput { muted: true; volume: 0 }
                        source: (!row.isFolder && !row.isImage) ? row.url : ""
                        autoPlay: false
                        onMediaStatusChanged: {
                            if (row.isFolder || row.isImage)
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
                        visible: !row.isFolder && !row.isImage
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: 22
                        height: 22
                        radius: 11
                        z: 2
                        color: "#99000000"
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: Theme.text
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        z: 3
                        color: "transparent"
                        radius: 4
                        border.width: row.index === Library.currentIndex ? 3 : 1
                        border.color: row.index === Library.currentIndex ? Theme.warning : Theme.bg
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 4
                        onClicked: {
                            Library.currentIndex = row.index
                            list.positionViewAtIndex(row.index, ListView.Contain)
                        }
                        onDoubleClicked: root.openCurrent()
                    }
                }
            }
        }
    }

    ClipPreview {
        id: lastClip
        parent: root.previewing ? clipMainSlot : clipPipSlot
        anchors.fill: parent
        visible: root.latestIndex >= 0
        source: root.latestUrl
        isImage: root.latestIsImage
        crop: !root.previewing
        autoPlay: false
        muted: !root.previewing
    }

    Timer {
        id: selectLatestTimer
        interval: 120
        repeat: false
        onTriggered: root.selectLatest()
    }

    Connections {
        target: Capture
        function onSnapshotCaptured(path) {
            snapAnim.restart()
            selectLatestTimer.restart()
        }
        function onRecordingChanged() {
            if (Capture.recording)
                root.exitPreview()
        }
        function onRecordingFinished(path) {
            selectLatestTimer.restart()
        }
    }
}
