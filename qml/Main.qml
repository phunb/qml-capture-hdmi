import QtQuick
import QtQuick.Controls
import QtQuick.Window
import HdmiKiosk

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    color: Theme.bg
    title: qsTr("HDMI Kiosk")
    visibility: Kiosk.locked ? Window.FullScreen : Window.Windowed
    flags: Kiosk.locked ? (Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint) : Qt.Window

    property string screenName: "live"
    property bool dialogOpen: deleteDialog.opened || exitDialog.opened

    function showLive() {
        if (screenName === "playback")
            playback.stopPlayback()
        Capture.muted = false
        Capture.startPreview()
        screenName = "live"
    }

    function showLibrary() {
        if (Capture.recording)
            return
        if (screenName === "playback")
            playback.stopPlayback()
        Library.goToRoot()
        screenName = "library"
    }

    function showPlayback(url, name) {
        if (Capture.recording)
            return
        Capture.muted = true
        if (!Capture.recording)
            Capture.stopPreview()
        screenName = "playback"
        playback.play(url, name)
    }

    onClosing: function(close) {
        if (Kiosk.locked)
            close.accepted = false
    }

    Component.onCompleted: {
        Kiosk.attachWindow(root)
        Capture.startPreview()
    }

    LiveView {
        anchors.fill: parent
        visible: screenName === "live"
        enabled: visible
        onOpenLibrary: root.showLibrary()
    }

    LibraryView {
        id: libraryView
        anchors.fill: parent
        visible: screenName === "library"
        enabled: visible
        onBackRequested: root.showLive()
        onPlayRequested: function(url, name) { root.showPlayback(url, name) }
        onDeleteRequested: function(index, name) {
            pendingDeleteIndex = index
            deleteDialog.messageText = qsTr("Xóa vĩnh viễn “%1”?").arg(name)
            deleteDialog.open()
        }
    }

    PlaybackView {
        id: playback
        anchors.fill: parent
        visible: screenName === "playback"
        enabled: visible
        onBackRequested: root.showLibrary()
    }

    property int pendingDeleteIndex: -1

    ConfirmDialog {
        id: deleteDialog
        titleText: qsTr("Xóa video")
        confirmText: qsTr("Xóa")
        danger: true
        onConfirmed: {
            if (pendingDeleteIndex >= 0)
                Library.removeAt(pendingDeleteIndex)
            pendingDeleteIndex = -1
        }
        onCancelled: pendingDeleteIndex = -1
    }

    ConfirmDialog {
        id: exitDialog
        titleText: qsTr("Thoát kiosk")
        messageText: qsTr("Thoát ứng dụng và trả lại màn hình hệ điều hành?")
        confirmText: qsTr("Thoát")
        danger: true
        onConfirmed: Kiosk.exitApp()
    }

    Connections {
        target: HidInput

        function onToggleRecord() {
            if (dialogOpen)
                return
            if (screenName !== "live")
                root.showLive()
            Capture.toggleRecording()
        }

        function onOpenLibrary() {
            if (dialogOpen)
                return
            root.showLibrary()
        }

        function onGoLive() {
            if (dialogOpen)
                return
            root.showLive()
        }

        function onGoBack() {
            if (exitDialog.opened) {
                exitDialog.close()
                return
            }
            if (deleteDialog.opened) {
                deleteDialog.close()
                return
            }
            if (screenName === "playback")
                root.showLibrary()
            else if (screenName === "library") {
                if (!Library.atRoot)
                    Library.goUp()
                else
                    root.showLive()
            }
        }

        function onPlayPause() {
            if (dialogOpen)
                return
            if (screenName === "playback")
                playback.togglePlay()
            else if (screenName === "live")
                Capture.toggleRecording()
        }

        function onSelectItem() {
            if (deleteDialog.opened) {
                if (pendingDeleteIndex >= 0)
                    Library.removeAt(pendingDeleteIndex)
                pendingDeleteIndex = -1
                deleteDialog.close()
                return
            }
            if (exitDialog.opened) {
                Kiosk.exitApp()
                return
            }
            if (screenName === "library" && Library.count > 0) {
                if (Library.currentIsFolder)
                    Library.openCurrent()
                else
                    root.showPlayback(Library.currentUrl, Library.currentName)
            }
        }

        function onMoveCurrent(delta) {
            if (dialogOpen)
                return
            if (screenName === "library")
                Library.moveCurrent(delta)
        }

        function onSeekBy(ms) {
            if (dialogOpen)
                return
            if (screenName === "playback")
                playback.seekBy(ms)
            else if (screenName === "library")
                Library.moveCurrent(ms > 0 ? 1 : -1)
        }

        function onDeleteCurrent() {
            if (dialogOpen)
                return
            if (screenName === "library" && Library.count > 0 && !Library.currentIsFolder) {
                pendingDeleteIndex = Library.currentIndex
                deleteDialog.messageText = qsTr("Xóa vĩnh viễn “%1”?").arg(Library.currentName)
                deleteDialog.open()
            }
        }

        function onAdminExit() {
            exitDialog.open()
        }
    }

    Connections {
        target: Kiosk
        function onAdminExitRequested() {
            exitDialog.open()
        }
    }

    Connections {
        target: Capture
        function onRecordingChanged() {
            if (Capture.recording && screenName !== "live")
                root.showLive()
        }
    }
}
