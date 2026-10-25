import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool recording: false
    property bool paused: false
    property bool stopping: false
    property bool hidden: false
    property int elapsed: 0

    readonly property string pidFile: "${XDG_RUNTIME_DIR:-/tmp}/gsr.pid"
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/recorder-osd.json"

    // ---- position (margins from the top-right corner) ----
    readonly property int defaultTop: 12
    readonly property int defaultRight: 12
    property int posTop: defaultTop
    property int posRight: defaultRight
    property bool dragging: false
    property bool animatePos: false   // only true briefly during reset
    property bool ready: false

    // 0 = shown, 1 = hidden (animated)
    property real shift: hidden ? 1 : 0
    Behavior on shift {
        NumberAnimation { duration: 260; easing.type: Easing.InOutCubic }
    }

    visible: recording && !stopping
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "recorder-osd"

    // fullscreen transparent window; only the pill and the chevron receive input
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {
        item: pill
        Region { item: toggle }
    }

    onWidthChanged: setPosition(posTop, posRight)
    onHeightChanged: setPosition(posTop, posRight)

    function fmt(s) {
        const m = Math.floor(s / 60), r = s % 60
        return String(m).padStart(2, "0") + ":" + String(r).padStart(2, "0")
    }

    function sendSignal(sig) {
        signal.command = ["sh", "-c",
            "f=\"" + pidFile + "\"; [ -f \"$f\" ] && kill -" + sig + " \"$(cat \"$f\")\""]
        signal.running = true
    }

    function togglePause() {
        sendSignal("USR2")
        paused = !paused
    }

    function stopRecording() {
        stopping = true
        sendSignal("INT")
    }

    // keep the pill + chevron fully on screen
    function setPosition(top, right) {
        if (width <= 0 || height <= 0) {
            posTop = top
            posRight = right
            return
        }
        const maxTop = Math.max(0, height - pill.height - toggle.height - 2)
        const maxRight = Math.max(0, width - pill.width)
        posTop = Math.round(Math.max(0, Math.min(maxTop, top)))
        posRight = Math.round(Math.max(0, Math.min(maxRight, right)))
    }

    function savePos() {
        if (!ready) return
        store.setText(JSON.stringify({ top: posTop, right: posRight }))
    }

    function resetPos() {
        animatePos = true
        animOff.restart()
        posTop = defaultTop
        posRight = defaultRight
        savePos()
    }

    Timer {
        id: animOff
        interval: 260
        onTriggered: root.animatePos = false
    }

    onRecordingChanged: {
        elapsed = 0
        paused = false
        hidden = false
    }

    // ---- persistence ----
    FileView {
        id: store
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                const d = JSON.parse(store.text())
                if (typeof d.top === "number" && typeof d.right === "number")
                    root.setPosition(d.top, d.right)
            } catch (e) {
                console.warn("recorder-osd: could not read saved position:", e)
            }
            root.ready = true
        }
        onLoadFailed: root.ready = true
    }

    // Fires signals at the recorder process
    Process { id: signal }

    // Poll the pidfile; recording = file exists AND process is alive
    Process {
        id: check
        command: ["sh", "-c",
            "f=\"${XDG_RUNTIME_DIR:-/tmp}/gsr.pid\"; [ -f \"$f\" ] && kill -0 \"$(cat \"$f\")\" 2>/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const alive = text.trim() === "1"
                if (root.stopping) {
                    if (!alive) {
                        root.stopping = false
                        root.recording = false
                    }
                } else {
                    root.recording = alive
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            check.running = true
            if (root.recording && !root.paused) root.elapsed++
        }
    }

    // fixed reference frame for drag coordinates
    Item {
        id: area
        anchors.fill: parent

        Rectangle {
            id: pill
            width: row.implicitWidth + 24
            height: 28
            radius: Theme.radius
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            // slides up and fades out as `shift` goes 0 -> 1
            opacity: 1 - root.shift
            visible: root.shift < 1

            anchors.top: parent.top
            anchors.topMargin: root.posTop - root.shift * height
            anchors.right: parent.right
            anchors.rightMargin: root.posRight

            // animate only for reset, never while dragging
            Behavior on anchors.topMargin {
                enabled: root.animatePos && !root.dragging
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on anchors.rightMargin {
                enabled: root.animatePos && !root.dragging
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            // re-clamp when the label changes width (REC <-> PAUSED)
            onWidthChanged: root.setPosition(root.posTop, root.posRight)

            // Drag handle: sits under the buttons so they keep their own clicks
            MouseArea {
                id: dragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0
                property real startTop: 0
                property real startRight: 0

                onPressed: function (mouse) {
                    const p = dragArea.mapToItem(area, mouse.x, mouse.y)
                    pressX = p.x
                    pressY = p.y
                    startTop = root.posTop
                    startRight = root.posRight
                    root.dragging = true
                }

                onPositionChanged: function (mouse) {
                    if (!root.dragging) return
                    const p = dragArea.mapToItem(area, mouse.x, mouse.y)
                    root.setPosition(startTop + (p.y - pressY),
                                     startRight - (p.x - pressX))
                }

                onReleased: {
                    if (!root.dragging) return
                    root.dragging = false
                    root.savePos()
                }

                onCanceled: {
                    if (!root.dragging) return
                    root.dragging = false
                    root.savePos()
                }

                onDoubleClicked: root.resetPos()
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8

                // Recording indicator
                Rectangle {
                    id: dot
                    width: 10; height: 10; radius: 5
                    color: Theme.danger
                    opacity: root.paused ? 0.4 : 1.0
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: root.recording && !root.paused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: Theme.animSlow }
                        NumberAnimation { to: 1.0; duration: Theme.animSlow }
                        onRunningChanged: if (!running) dot.opacity = root.paused ? 0.4 : 1.0
                    }
                }

                Text {
                    text: (root.paused ? "PAUSED " : "REC ") + root.fmt(root.elapsed)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Pause / resume button
                Item {
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: pauseArea.containsMouse ? 1.0 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        visible: !root.paused
                        Rectangle { width: 3; height: 10; radius: 1; color: Theme.text }
                        Rectangle { width: 3; height: 10; radius: 1; color: Theme.text }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.paused
                        text: "▶"
                        color: Theme.text
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: pauseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePause()
                    }
                }

                // Stop button
                Item {
                    width: 18; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: stopArea.containsMouse ? 1.0 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 10; height: 10; radius: 2
                        color: stopArea.containsMouse ? Theme.danger : Theme.text
                    }

                    MouseArea {
                        id: stopArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopRecording()
                    }
                }
            }
        }

        // Hide / show chevron: centered below the pill, rides up into its place when hidden
        Item {
            id: toggle
            width: 36
            height: 14
            x: pill.x + pill.width / 2 - width / 2
            y: pill.y + pill.height + 2

            // 0..1 pulse driven by the blink animation below
            property real pulse: 1.0

            // Blink only once the pill has fully slid away, and not while hovered.
            // Resting (shown) state stays dim, hovered state stays fully bright.
            readonly property bool blinking: root.hidden && root.shift >= 1 && !toggleArea.containsMouse

            opacity: toggleArea.containsMouse ? 1.0
                   : root.hidden ? (root.shift >= 1 ? pulse : 0.7)
                   : 0.35
            Behavior on opacity {
                enabled: !toggle.blinking
                NumberAnimation { duration: 150 }
            }

            SequentialAnimation {
                id: blinkAnim
                running: toggle.blinking
                loops: Animation.Infinite
                NumberAnimation { target: toggle; property: "pulse"; from: 1.0; to: 0.25; duration: Theme.animSlow; easing.type: Easing.InOutSine }
                NumberAnimation { target: toggle; property: "pulse"; from: 0.25; to: 1.0; duration: Theme.animSlow; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) toggle.pulse = 1.0
            }

            Text {
                id: chevron
                anchors.centerIn: parent
                text: "⌃"
                color: root.hidden ? Theme.danger : Theme.text
                Behavior on color { ColorAnimation { duration: 200 } }
                font.pixelSize: 14
                font.bold: true
                rotation: root.shift * 180
            }

            MouseArea {
                id: toggleArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.hidden = !root.hidden
            }
        }
    }
}