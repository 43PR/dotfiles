import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: root
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 140
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Unmap the surface when idle; stay mapped during the fade-out
    visible: showing || flyout.opacity > 0

    mask: Region {
        item: root.showing ? flyout : null
    }

    property bool showing: false
    property bool cancelled: false
    property string imagePath: ""

    // Release the decoded pixmap only after the fade-out has finished
    onVisibleChanged: if (!visible) imagePath = ""

    function showOsd(path) {
        cancelled = false
        imagePath = path
        showing = true
        hideTimer.restart()
    }

    function showCancelled() {
        cancelled = true
        imagePath = ""
        showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 2200
        repeat: false
        onTriggered: root.showing = false
    }

    IpcHandler {
        target: "screenshot"
        function notify(path: string): void {
            root.showOsd(path)
        }
        function cancelled(): void {
            root.showCancelled()
        }
    }

    Rectangle {
        id: flyout
        width: 320
        height: 84
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        radius: 20
        color: Theme.alpha(Theme.bg, 0.8)
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            Rectangle {
                id: thumb
                width: 60
                height: 60
                radius: 10
                color: "#33ffffff"
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: root.imagePath ? "file://" + root.imagePath : ""
                    sourceSize: Qt.size(120, 120)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                Text {
                    anchors.centerIn: parent
                    visible: !root.imagePath
                    text: root.cancelled ? "󰜺" : "󰄀"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 22
                    color: Theme.text
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: parent.width - thumb.width - parent.spacing

                Text {
                    text: root.cancelled ? "Screenshot cancelled" : "Screenshot saved"
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.text
                }
                Text {
                    visible: !root.cancelled
                    text: root.imagePath.split("/").pop()
                    font.pixelSize: 11
                    color: Theme.textDim
                    elide: Text.ElideMiddle
                    width: parent.width
                }
                Text {
                    text: root.cancelled ? "No area selected" : "Copied to clipboard"
                    font.pixelSize: 10
                    color: Theme.textDim
                }
            }
        }
    }
}