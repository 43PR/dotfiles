// hl.dsp.exec_cmd("qs -d -c volume-osd")
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 120
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? flyout : null
    }

    // -------------------------
    // PipeWire
    // -------------------------

    PwObjectTracker {
        id: audioTracker

        objects: [Pipewire.defaultAudioSink]
    }

    property var sink: Pipewire.defaultAudioSink

    property real volume: {
        if (!sink || !sink.audio)
            return 0

        return sink.audio.volume
    }

    property bool muted: {
        if (!sink || !sink.audio)
            return false

        return sink.audio.muted
    }

    // -------------------------
    // OSD state
    // -------------------------

    property bool showing: false

    function showOsd() {
        showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer

        interval: 1200
        repeat: false

        onTriggered: root.showing = false
    }

    // -------------------------
    // Detect changes
    // -------------------------

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            root.showOsd()
        }

        function onMutedChanged() {
            root.showOsd()
        }
    }

    // -------------------------
    // OSD
    // -------------------------

    Rectangle {
        id: flyout

        width: 320
        height: 35

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30

        radius: 36
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

        Text {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (root.muted)
                    return "󰖁"

                if (root.volume <= 0)
                    return "󰕿"

                if (root.volume < 0.5)
                    return "󰖀"

                return "󰕾"
            }

            font.family: "Symbols Nerd Font"
            font.pixelSize: 20

            color: "white"
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter

            text: root.muted
                ? "Muted"
                : Math.round(root.volume * 100) + "%"

            font.pixelSize: 12
            font.bold: true

            color: "white"
        }

        Rectangle {
            anchors.left: icon.right
            anchors.leftMargin: 15

            anchors.right: parent.right
            anchors.rightMargin: 68

            anchors.verticalCenter: parent.verticalCenter

            height: 5
            radius: 4

            color: "#555555"

            Rectangle {
                width: root.muted
                    ? 0
                    : parent.width * Math.min(root.volume, 1)

                height: parent.height
                radius: 4

                color: "white"

                Behavior on width {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }
    }
}
