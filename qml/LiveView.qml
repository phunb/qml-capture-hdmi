import QtQuick
import QtQuick.Controls
import QtMultimedia
import HdmiKiosk

Item {
    id: root

    property bool previewing: false
    property bool liveMoving: false

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
        if (!root.previewing || Library.count <= 0)
            return
        let idx = Library.currentIndex + delta
        while (idx >= 0 && idx < Library.count && Library.isFolderAt(idx))
            idx += delta
        if (idx < 0 || idx >= Library.count)
            return
        Library.currentIndex = idx
        list.positionViewAtIndex(idx, ListView.Contain)
        playCurrentIfVideo()
    }

    function playCurrentIfVideo() {
        if (!root.previewing || Library.count <= 0 || Library.currentIsFolder)
            return
        lastClip.crop = false
        lastClip.muted = false
        lastClip.resetZoom()
        lastClip.autoPlay = !Library.currentIsImage
        if (Library.currentIsImage)
            lastClip.pause()
        else
            lastClip.play()
    }

    function enterPreview() {
        if (latestIndex < 0)
            return
        lastClip.parent = clipMainSlot
        focusLatest()
        previewing = true
        playCurrentIfVideo()
    }

    function exitPreview() {
        const wasPreviewing = previewing
        previewing = false
        lastClip.parent = clipPipSlot
        lastClip.crop = true
        lastClip.muted = true
        if (!latestIsImage)
            lastClip.pause()
        if (wasPreviewing)
            focusLatest()
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
        lastClip.parent = clipMainSlot
        previewing = true
        list.positionViewAtIndex(Library.currentIndex, ListView.Contain)
        playCurrentIfVideo()
    }

    function togglePlay() {
        if (previewing)
            lastClip.toggle()
        else
            enterPreview()
    }

    function seekBy(ms) {
        if (!root.previewing)
            return
        if (Library.currentIsImage)
            lastClip.zoomBy(ms > 0 ? 0.15 : -0.15)
        else
            lastClip.seekBy(ms)
    }

    function selectLatest() {
        if (latestIndex >= 0)
            Library.currentIndex = latestIndex
    }

    function focusLatest() {
        selectLatest()
        list.positionViewAtBeginning()
        Qt.callLater(function() {
            if (latestIndex >= 0)
                list.positionViewAtIndex(latestIndex, ListView.Beginning)
        })
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

        Item {
            id: liveMainSlot
            anchors.fill: parent
            z: root.liveMoving ? 10 : 0
            clip: !root.liveMoving
        }

        Item {
            id: clipMainSlot
            anchors.fill: parent
            clip: true
        }

        Item {
            id: liveHost
            parent: liveMainSlot
            x: 0
            y: 0
            width: parent ? parent.width : 0
            height: parent ? parent.height : 0

            VideoOutput {
                id: liveOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 4
                border.width: root.previewing || root.liveMoving ? 3 : 0
                border.color: Theme.accent
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            visible: !root.previewing && !root.liveMoving && !Capture.signalPresent
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
            visible: true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 16
            radius: 8
            color: Theme.overlay
            width: modeRow.implicitWidth + 28
            height: 44
            z: 20

            Row {
                id: modeRow
                anchors.centerIn: parent
                spacing: 10

                Rectangle {
                    visible: !root.previewing && Capture.videoPresent
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.live
                    anchors.verticalCenter: parent.verticalCenter
                    border.width: 2
                    border.color: "#ffc4c8"
                }

                Text {
                    text: root.previewing ? qsTr("Preview") : qsTr("Live")
                    color: Theme.text
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
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
            visible: root.previewing || root.liveMoving
            width: parent.width
            height: visible ? Math.round(width * 9 / 16) : 0
            color: Theme.surface
            border.color: Theme.accent
            border.width: 3
            radius: 4
            clip: true

            Item {
                id: pipLiveSlot
                anchors.fill: parent
            }

            Item {
                id: clipPipSlot
                anchors.fill: parent
            }

            MouseArea {
                anchors.fill: parent
                enabled: !Capture.recording
                onClicked: root.togglePreview()
            }
        }

        Rectangle {
            width: parent.width
            height: pipFrame.visible ? parent.height - pipFrame.height - parent.spacing : parent.height
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
                currentIndex: root.previewing ? Library.currentIndex : -1
                keyNavigationEnabled: false
                focus: false
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 80
                highlightFollowsCurrentItem: false
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
                        loops: 1
                        onMediaStatusChanged: {
                            if (row.isFolder || row.isImage)
                                return
                            if (mediaStatus === MediaPlayer.LoadedMedia
                                    || mediaStatus === MediaPlayer.BufferedMedia)
                                play()
                        }
                        Component.onCompleted: {
                            if (source != "")
                                play()
                        }
                        Component.onDestruction: stop()
                    }

                    Connections {
                        target: videoThumb.videoSink
                        function onVideoFrameChanged() {
                            if (row.isFolder || row.isImage)
                                return
                            if (thumbPlayer.playbackState === MediaPlayer.PlayingState)
                                thumbPlayer.pause()
                        }
                    }

                    Rectangle {
                        visible: !row.isFolder && !row.isImage
                        width: Math.round(parent.width * 0.25)
                        height: width
                        radius: width / 2
                        anchors.centerIn: parent
                        z: 2
                        color: "#59000000"
                        border.width: 2
                        border.color: "#99f4f7fb"
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: Theme.text
                            font.pixelSize: Math.round(parent.width * 0.42)
                            font.bold: true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        z: 3
                        color: "transparent"
                        radius: 4
                        border.width: root.previewing && row.index === Library.currentIndex ? 3 : 1
                        border.color: root.previewing && row.index === Library.currentIndex ? Theme.warning : Theme.bg
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 4
                        onClicked: {
                            if (!root.previewing)
                                return
                            Library.currentIndex = row.index
                            list.positionViewAtIndex(row.index, ListView.Contain)
                            root.playCurrentIfVideo()
                        }
                        onDoubleClicked: root.openCurrent()
                    }
                }
            }
        }
    }

    ClipPreview {
        id: lastClip
        parent: clipPipSlot
        anchors.fill: parent
        visible: (root.previewing || (root.liveMoving && parent === clipMainSlot))
                 && Library.count > 0 && !Library.currentIsFolder
        source: {
            if ((root.previewing || root.liveMoving) && Library.count > 0 && !Library.currentIsFolder)
                return Library.currentUrl
            return root.latestUrl
        }
        isImage: {
            if ((root.previewing || root.liveMoving) && Library.count > 0 && !Library.currentIsFolder)
                return Library.currentIsImage
            return root.latestIsImage
        }
        crop: !root.previewing
        autoPlay: root.previewing && Library.count > 0 && !Library.currentIsFolder && !Library.currentIsImage
        muted: !root.previewing
    }

    states: State {
        name: "previewLive"
        when: root.previewing
        ParentChange {
            target: liveHost
            parent: pipLiveSlot
            x: 0
            y: 0
            width: pipLiveSlot.width
            height: pipLiveSlot.height
        }
    }

    transitions: Transition {
        to: "previewLive"
        SequentialAnimation {
            PropertyAction { target: root; property: "liveMoving"; value: true }
            ParentAnimation {
                NumberAnimation {
                    properties: "x,y,width,height"
                    duration: 260
                    easing.type: Easing.InOutCubic
                }
            }
            PropertyAction { target: root; property: "liveMoving"; value: false }
        }
    }

    onLiveMovingChanged: {
        if (liveMoving || root.previewing)
            return
        lastClip.parent = clipPipSlot
    }

    Component.onCompleted: {
        lastClip.parent = clipPipSlot
        Capture.setPreviewOutput(liveOutput)
        Capture.startPreview()
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
