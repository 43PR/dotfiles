import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool recording: false
    property int elapsed: 0

    visible: recording
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "recorder-osd"

    anchors { top: true; right: true }
    margins { top: 12; right: 12 }
    implicitWidth: row.implicitWidth + 24
    implicitHeight: 28

    function fmt(s) {
        const m = Math.floor(s / 60), r = s % 60
        return String(m).padStart(2, "0") + ":" + String(r).padStart(2, "0")
    }

    onRecordingChanged: elapsed = 0

    // Poll the pidfile; recording = file exists AND process is alive
    Process {
        id: check
        command: ["sh", "-c",
            "f=\"${XDG_RUNTIME_DIR:-/tmp}/gsr.pid\"; [ -f \"$f\" ] && kill -0 \"$(cat \"$f\")\" 2>/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.recording = text.trim() === "1"
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            check.running = true
            if (root.recording) root.elapsed++
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 10; height: 10; radius: 5
                color: Theme.danger
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running: root.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: Theme.animSlow }
                    NumberAnimation { to: 1.0; duration: Theme.animSlow }
                }
            }

            Text {
                text: "REC " + root.fmt(root.elapsed)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}