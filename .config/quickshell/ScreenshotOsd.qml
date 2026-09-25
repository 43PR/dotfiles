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

    mask: Region {
        item: root.showing ? flyout : null
    }

    // -------------------------
    // OSD state
    // -------------------------

    property bool showing: false
    property string imagePath: ""

    function showOsd(path) {
        imagePath = path
        showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer

        interval: 2200
        repeat: false

        onTriggered: root.showing = false
    }

    // -------------------------
    // IPC entrypoint
    //
    // Called from your shell scripts like:
    //   qs ipc call screenshot notify "$file"
    // -------------------------

    IpcHandler {
        target: "screenshot"

        function notify(path: string): void {
            root.showOsd(path)
        }
    }

    // -------------------------
    // OSD
    // -------------------------

    Rectangle {
        id: flyout

        width: 320
        height: 84

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30

        radius: 20
        color: "#80000000"

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
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.imagePath
                    text: "󰄀"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 22
                    color: "white"
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: parent.width - thumb.width - parent.spacing

                Text {
                    text: "Screenshot saved"
                    font.pixelSize: 13
                    font.bold: true
                    color: "white"
                }

                Text {
                    text: root.imagePath.split("/").pop()
                    font.pixelSize: 11
                    color: "#cccccc"
                    elide: Text.ElideMiddle
                    width: parent.width
                }

                Text {
                    text: "Copied to clipboard"
                    font.pixelSize: 10
                    color: "#999999"
                }
            }
        }
    }
}