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

    property bool dialogOpen: deleteDialog.opened || exitDialog.opened
    property int pendingDeleteIndex: -1

    function requestDeleteCurrent() {
        if (Library.count <= 0 || Library.currentIsFolder)
            return
        pendingDeleteIndex = Library.currentIndex
        deleteDialog.messageText = qsTr("Xóa “%1”?").arg(Library.currentName)
        deleteDialog.confirmSelected = false
        deleteDialog.open()
    }

    onClosing: function(close) {
        if (Kiosk.locked)
            close.accepted = false
    }

    Component.onCompleted: {
        Kiosk.attachWindow(root)
        Capture.startPreview()
        Library.goToRoot()
    }

    LiveView {
        id: liveView
        anchors.fill: parent
    }

    ConfirmDialog {
        id: deleteDialog
        titleText: qsTr("Xóa")
        confirmText: qsTr("Xóa")
        danger: true
        onConfirmed: {
            if (pendingDeleteIndex >= 0)
                Library.removeAt(pendingDeleteIndex)
            pendingDeleteIndex = -1
            liveView.exitPreview()
        }
        onCancelled: pendingDeleteIndex = -1
    }

    ConfirmDialog {
        id: exitDialog
        titleText: qsTr("Thoát")
        messageText: qsTr("Thoát ứng dụng?")
        confirmText: qsTr("Thoát")
        danger: true
        onConfirmed: Kiosk.exitApp()
    }

    Connections {
        target: HidInput

        function onToggleRecord() {
            if (dialogOpen)
                return
            if (liveView.previewing) {
                liveView.moveSelection(1)
                return
            }
            Capture.toggleRecording()
        }

        function onCaptureSnapshot() {
            if (dialogOpen)
                return
            if (liveView.previewing) {
                liveView.moveSelection(-1)
                return
            }
            Capture.captureSnapshot()
        }

        function onPedalTap() {
            if (dialogOpen)
                return
            if (liveView.previewing) {
                liveView.exitPreview()
                return
            }
            Capture.captureSnapshot()
        }

        function onGoLive() {
            if (dialogOpen)
                return
            liveView.exitPreview()
        }

        function onTogglePreview() {
            if (dialogOpen || Capture.recording)
                return
            if (liveView.previewing)
                liveView.seekBy(10000)
            else
                liveView.enterPreview()
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
            if (liveView.previewing)
                liveView.exitPreview()
            else if (!Library.atRoot)
                Library.goUp()
        }

        function onPlayPause() {
            if (dialogOpen)
                return
            liveView.togglePlay()
        }

        function onSelectItem() {
            if (deleteDialog.opened) {
                if (deleteDialog.confirmSelected) {
                    if (pendingDeleteIndex >= 0)
                        Library.removeAt(pendingDeleteIndex)
                    pendingDeleteIndex = -1
                    deleteDialog.close()
                    liveView.exitPreview()
                } else {
                    pendingDeleteIndex = -1
                    deleteDialog.close()
                }
                return
            }
            if (exitDialog.opened) {
                if (exitDialog.confirmSelected)
                    Kiosk.exitApp()
                else
                    exitDialog.close()
                return
            }
            if (liveView.previewing)
                liveView.togglePlay()
            else
                liveView.openCurrent()
        }

        function onMoveCurrent(delta) {
            if (deleteDialog.opened) {
                deleteDialog.confirmSelected = !deleteDialog.confirmSelected
                return
            }
            if (exitDialog.opened) {
                exitDialog.confirmSelected = !exitDialog.confirmSelected
                return
            }
            if (!liveView.previewing)
                return
            liveView.seekBy(delta > 0 ? -10000 : 10000)
        }

        function onSeekBy(ms) {
            if (dialogOpen || !liveView.previewing)
                return
            liveView.seekBy(ms)
        }

        function onDeleteCurrent() {
            if (dialogOpen)
                return
            root.requestDeleteCurrent()
        }

        function onAdminExit() {
            exitDialog.confirmSelected = false
            exitDialog.open()
        }
    }

    Connections {
        target: Kiosk
        function onAdminExitRequested() {
            exitDialog.confirmSelected = false
            exitDialog.open()
        }
    }
}
