import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Root is a lightweight Scope: state, persistence and the pidfile poller live here.
// The fullscreen overlay window only exists while a recording is running
// (or while the settings window is open, so there is a preview to tweak).
Scope {
    id: root

    property bool recording: false
    property bool paused: false
    property bool stopping: false
    property int elapsed: 0
    property bool ready: false        // true once the saved state has been loaded

    readonly property string pidFile: "${XDG_RUNTIME_DIR:-/tmp}/gsr.pid"
    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"
    readonly property string statePath: stateDir + "/recorder-osd.json"

    // ---- position (margins from the top-right corner) ----
    readonly property int defaultTop: 12
    readonly property int defaultRight: 12

    // position the user WANTS (persisted, never clamped destructively).
    // The window derives the displayed (clamped) position from these.
    property int wantTop: defaultTop
    property int wantRight: defaultRight
    readonly property var posKeys: ["wantTop", "wantRight"]

    // ---- settings (right-click the pill, or `qs ipc call recorder settings`) ----
    readonly property var numSpec: ({
        uiScale:    { min: 60, max: 200, def: 100, step: 5,  unit: " %" },
        opacityPct: { min: 20, max: 100, def: 100, step: 5,  unit: " %" },
        bgOpacity:  { min: 0,  max: 100, def: 100, step: 5,  unit: " %" },
        radiusPct:  { min: 0,  max: 300, def: 100, step: 10, unit: " %" },   // % of Theme.radius
        textSize:   { min: 9,  max: 24,  def: 13,  step: 1,  unit: " px" },
        animMs:     { min: 0,  max: 600, def: 260, step: 20, unit: " ms" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        vertical: false,
        showBorder: true,
        showControls: true,
        pulseDot: true,
        hidden: false        // remembered between recordings/launches, not listed in the settings UI
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    property int uiScale: numSpec.uiScale.def
    property int opacityPct: numSpec.opacityPct.def
    property bool vertical: boolDefaults.vertical
    property int bgOpacity: numSpec.bgOpacity.def
    property int radiusPct: numSpec.radiusPct.def
    property int textSize: numSpec.textSize.def
    property int animMs: numSpec.animMs.def
    property bool showBorder: boolDefaults.showBorder
    property bool showControls: boolDefaults.showControls
    property bool pulseDot: boolDefaults.pulseDot
    property bool hidden: boolDefaults.hidden

    readonly property real k: uiScale / 100
    readonly property real osdOpacity: opacityPct / 100

    property bool settingsOpen: false

    readonly property bool moved: wantTop !== defaultTop || wantRight !== defaultRight
    readonly property bool modified: moved
        || numKeys.some(n => root[n] !== numSpec[n].def)
        || boolKeys.some(n => root[n] !== boolDefaults[n])

    // ---- host interface required by CustomizationSettings.qml ----
    readonly property real menuUi: 1          // UI scale factor of the settings window
    readonly property color cAccent: Theme.accent
    readonly property QtObject th: QtObject {
        readonly property int radius: 10
        readonly property string fontFamily: "JetBrains Mono"
        readonly property int animFast: 120
        readonly property int animMed: 220
        readonly property int textSizeGroup: 12   // row labels
        readonly property int textSizeBody: 11    // values, button text
        readonly property int textSizeSmall: 10   // section headers
    }

    // the settings Flickable registers itself here so ensureVisible() can scroll it
    property var settingsFlick: null

    // rows of the settings window: header / slider / toggle
    readonly property var settingRows: [
        { type: "header", label: "Size" },
        { type: "slider", key: "uiScale",    label: "Scale" },

        { type: "slider", key: "textSize",   label: "Text size" },

        { type: "header", label: "Appearance" },
        { type: "slider", key: "opacityPct", label: "Overall opacity" },
        { type: "slider", key: "bgOpacity",  label: "Background opacity" },
        { type: "slider", key: "radiusPct",  label: "Corner radius" },
        { type: "toggle", key: "showBorder", label: "Border" },

        { type: "header", label: "Layout" },
        { type: "toggle", key: "vertical",     label: "Vertical layout" },
        { type: "toggle", key: "showControls", label: "Pause / stop buttons" },

        { type: "header", label: "Behavior" },
        { type: "slider", key: "animMs",   label: "Hide animation" },
        { type: "toggle", key: "pulseDot", label: "Pulsing dot" }
    ]

    function fmt(s) {
        const m = Math.floor(s / 60), r = s % 60
        return String(m).padStart(2, "0") + ":" + String(r).padStart(2, "0")
    }

    function sendSignal(sig) {
        sigProc.command = ["sh", "-c",
            "f=\"" + pidFile + "\"; [ -f \"$f\" ] && kill -" + sig + " \"$(cat \"$f\")\""]
        sigProc.running = true
    }

    function togglePause() {
        sendSignal("USR2")
        paused = !paused
    }

    function stopRecording() {
        stopping = true
        sendSignal("INT")
    }

    // user intent: called on load and while dragging (the window re-clamps)
    function setPosition(top, right) {
        wantTop = top
        wantRight = right
    }

    function resetPosition() {
        setPosition(defaultTop, defaultRight)
        saveState()
    }

    function resetAll() {
        setPosition(defaultTop, defaultRight)
        numKeys.forEach(n => { root[n] = numSpec[n].def })
        boolKeys.forEach(n => { root[n] = boolDefaults[n] })
        saveState()
    }

    function setNumber(key, v) {
        const s = numSpec[key]
        root[key] = Math.max(s.min, Math.min(s.max, Math.round(v)))
    }

    function toggleSetting(key) {
        root[key] = !root[key]
        saveState()
    }

    function fmtValue(key, v) { return v + numSpec[key].unit }
    function cellW(p) { return p ? p.width : 0 }

    // Tab / arrow navigation between rows
    function focusStep(item, forward) {
        const n = item.nextItemInFocusChain(forward)
        if (n && n !== item)
            n.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
    }

    // scroll the settings list so the focused row stays visible
    function ensureVisible(item, margin) {
        const f = settingsFlick
        if (!f || !item) return
        const y = item.mapToItem(f.contentItem, 0, 0).y
        const h = item.height
        if (y - margin < f.contentY)
            f.contentY = Math.max(0, y - margin)
        else if (y + h + margin > f.contentY + f.height)
            f.contentY = Math.max(0, Math.min(f.contentHeight - f.height,
                                              y + h + margin - f.height))
    }

    function openSettings() { settingsOpen = true }

    function closeSettings() {
        settingsOpen = false
        saveState()
    }

    function toggleSettings() { settingsOpen ? closeSettings() : openSettings() }

    // debounced: scrolling / dragging / sliders never write the file on every tick
    function saveState() {
        if (!ready) return
        saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            const s = {}
            root.posKeys.concat(root.numKeys, root.boolKeys).forEach(n => { s[n] = root[n] })
            store.setText(JSON.stringify(s))
        }
    }

    // any persisted setting that changes schedules a save (ignored until the state is loaded)
    onUiScaleChanged: saveState()
    onOpacityPctChanged: saveState()
    onVerticalChanged: saveState()
    onShowBorderChanged: saveState()
    onBgOpacityChanged: saveState()
    onRadiusPctChanged: saveState()
    onTextSizeChanged: saveState()
    onAnimMsChanged: saveState()
    onShowControlsChanged: saveState()
    onPulseDotChanged: saveState()
    onHiddenChanged: saveState()

    // `hidden` is intentionally NOT reset when a recording starts:
    // it is restored from disk and remembered between recordings/launches.
    onRecordingChanged: {
        elapsed = 0
        paused = false
    }

    Component.onCompleted: mkState.running = true

    // make sure the state directory exists so saving can't fail silently
    Process {
        id: mkState
        command: ["mkdir", "-p", root.stateDir]
    }

    // test / open without right-clicking: qs ipc call recorder settings
    IpcHandler {
        target: "recorder"
        function settings(): void { root.toggleSettings() }
    }

    // ---- persistence ----
    FileView {
        id: store
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                const s = JSON.parse(store.text())
                root.posKeys.forEach(n => { if (typeof s[n] === "number") root[n] = s[n] })
                root.numKeys.forEach(n => { if (typeof s[n] === "number") root.setNumber(n, s[n]) })
                root.boolKeys.forEach(n => { if (typeof s[n] === "boolean") root[n] = s[n] })

                // migrate the older file format (top / right / opacity as 0..1)
                if (typeof s.wantTop !== "number" && typeof s.top === "number")
                    root.wantTop = s.top
                if (typeof s.wantRight !== "number" && typeof s.right === "number")
                    root.wantRight = s.right
                if (typeof s.opacityPct !== "number" && typeof s.opacity === "number")
                    root.setNumber("opacityPct", s.opacity * 100)
            } catch (e) {
                console.warn("recorder-osd: could not read saved state:", e)
            }
            root.ready = true
        }
        onLoadFailed: root.ready = true
        onSaveFailed: function (error) {
            console.warn("recorder-osd: could not save state:", error)
        }
    }

    // Fires signals at the recorder process
    Process { id: sigProc }

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

    // ---- the window: exists while recording (or while the settings are open, as a preview) ----
    LazyLoader {
        active: (root.recording && !root.stopping) || root.settingsOpen

        PanelWindow {
            id: win

            // position actually DISPLAYED (derived from root.want* and clamped to the window)
            property int posTop: root.defaultTop
            property int posRight: root.defaultRight

            property bool dragging: false
            property bool animatePos: false   // only true briefly during reset

            // 0 = shown, 1 = hidden (animated)
            property real shift: root.hidden ? 1 : 0
            Behavior on shift {
                // no slide animation while the saved state is being restored at startup
                enabled: root.ready
                NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
            }

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

            onWidthChanged: clampPosition()
            onHeightChanged: clampPosition()
            Component.onCompleted: clampPosition()

            // derive the displayed position from the wanted one, keeping pill + chevron on screen.
            // Re-clamping always starts from want*, so a temporarily tiny window
            // (e.g. 100x100 before the layer surface is configured) can't destroy the saved value.
            function clampPosition() {
                if (width <= 0 || height <= 0) {
                    posTop = root.wantTop
                    posRight = root.wantRight
                    return
                }
                const maxTop = Math.max(0, height - pill.height - toggle.height - 2)
                const maxRight = Math.max(0, width - pill.width)
                posTop = Math.round(Math.max(0, Math.min(maxTop, root.wantTop)))
                posRight = Math.round(Math.max(0, Math.min(maxRight, root.wantRight)))
            }

            function resetPos() {
                animatePos = true
                animOff.restart()
                root.resetPosition()
                clampPosition()
            }

            Connections {
                target: root
                function onWantTopChanged()   { win.clampPosition() }
                function onWantRightChanged() { win.clampPosition() }
            }

            Timer {
                id: animOff
                interval: 260
                onTriggered: win.animatePos = false
            }

            // fixed reference frame for drag coordinates
            Item {
                id: area
                anchors.fill: parent
                opacity: root.osdOpacity

                Rectangle {
                    id: pill
                    width: (root.vertical ? 28 : row.implicitWidth + 24) * root.k
                    height: (root.vertical ? row.implicitWidth + 24 : 28) * root.k
                    radius: Theme.radius * root.k * root.radiusPct / 100
                    color: root.bgOpacity >= 100 ? Theme.bg : Theme.alpha(Theme.bg, root.bgOpacity / 100)
                    border.width: root.showBorder ? 1 : 0
                    border.color: Theme.border

                    // slides up and fades out as `shift` goes 0 -> 1
                    opacity: 1 - win.shift
                    visible: win.shift < 1

                    anchors.top: parent.top
                    anchors.topMargin: win.posTop - win.shift * height
                    anchors.right: parent.right
                    anchors.rightMargin: win.posRight

                    // animate only for reset, never while dragging
                    Behavior on anchors.topMargin {
                        enabled: win.animatePos && !win.dragging
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on anchors.rightMargin {
                        enabled: win.animatePos && !win.dragging
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    // re-clamp when the size changes (REC <-> PAUSED, layout, scale)
                    onWidthChanged: win.clampPosition()
                    onHeightChanged: win.clampPosition()

                    // Drag handle: sits under the buttons so they keep their own clicks.
                    // Left-drag moves, double-click resets, right-click opens the settings,
                    // wheel = opacity, Shift + wheel = scale.
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: win.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        property real pressX: 0
                        property real pressY: 0
                        property real startTop: 0
                        property real startRight: 0
                        property real wheelAcc: 0    // collects small touchpad deltas

                        onWheel: function (wheel) {
                            // with Shift held, some setups report the wheel on the x axis
                            const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                            wheelAcc += d
                            const notches = Math.trunc(wheelAcc / 120)
                            if (notches === 0) return
                            wheelAcc -= notches * 120
                            if (wheel.modifiers & Qt.ShiftModifier)
                                root.setNumber("uiScale", root.uiScale + notches * root.numSpec.uiScale.step)
                            else
                                root.setNumber("opacityPct", root.opacityPct + notches * root.numSpec.opacityPct.step)
                        }

                        onPressed: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                root.toggleSettings()
                                return
                            }
                            const p = dragArea.mapToItem(area, mouse.x, mouse.y)
                            pressX = p.x
                            pressY = p.y
                            startTop = win.posTop
                            startRight = win.posRight
                            win.dragging = true
                        }

                        onPositionChanged: function (mouse) {
                            if (!win.dragging) return
                            const p = dragArea.mapToItem(area, mouse.x, mouse.y)
                            root.setPosition(startTop + (p.y - pressY),
                                             startRight - (p.x - pressX))
                        }

                        onReleased: {
                            if (!win.dragging) return
                            win.dragging = false
                            root.saveState()
                        }

                        onCanceled: {
                            if (!win.dragging) return
                            win.dragging = false
                            root.saveState()
                        }

                        onDoubleClicked: function (mouse) {
                            if (mouse.button === Qt.LeftButton) win.resetPos()
                        }
                    }

                    Row {
                        id: row
                        anchors.centerIn: parent
                        spacing: 8
                        rotation: root.vertical ? -90 : 0
                        scale: root.k

                        // Recording indicator
                        Rectangle {
                            id: dot
                            width: 10; height: 10; radius: 5
                            color: Theme.danger
                            opacity: root.paused ? 0.4 : 1.0
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on opacity {
                                running: root.recording && !root.paused && root.pulseDot
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
                            font.pixelSize: root.textSize
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Pause / resume button
                        Item {
                            visible: root.showControls
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
                            visible: root.showControls
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
                    readonly property bool blinking: root.hidden && win.shift >= 1 && !toggleArea.containsMouse

                    opacity: toggleArea.containsMouse ? 1.0
                           : root.hidden ? (win.shift >= 1 ? pulse : 0.7)
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
                        rotation: win.shift * 180
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
    }

    // ---- settings window: only exists while open ----
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin

            color: "transparent"
            implicitWidth: 380
            implicitHeight: Math.min(600, (screen?.height ?? 800) * 0.85)
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.bg
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.12)
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.closeSettings()

                Item {
                    id: head
                    anchors.top: parent.top
                    width: parent.width
                    height: 54

                    Text {
                        x: 20; y: 10
                        text: "Recorder OSD settings"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.text
                    }
                    Text {
                        x: 20; y: 31
                        text: "Drag | Scroll"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        color: Theme.textDim
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        y: 8
                        width: 26; height: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "×"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 22
                        color: closeArea.containsMouse ? Theme.text : Theme.textDim
                        MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.closeSettings() }
                    }
                }

                // everything between header and footer scrolls (mouse wheel / drag)
                Flickable {
                    id: flick
                    anchors.top: head.bottom
                    anchors.bottom: foot.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    contentWidth: width
                    contentHeight: rowsCol.height + 12
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    Component.onCompleted: root.settingsFlick = flick
                    Component.onDestruction: if (root.settingsFlick === flick) root.settingsFlick = null

                    Column {
                        id: rowsCol
                        x: 20
                        width: flick.width - 40

                        Repeater {
                            model: root.settingRows

                            delegate: Loader {
                                id: rowLoader
                                required property var modelData

                                width: rowsCol.width
                                height: item ? item.height : 0
                                sourceComponent: modelData.type === "header" ? headerC
                                               : modelData.type === "slider" ? sliderC
                                               : toggleC

                                Component {
                                    id: headerC
                                    CustomizationSettings.SectionHeader {
                                        host: root
                                        text: rowLoader.modelData.label
                                    }
                                }
                                Component {
                                    id: sliderC
                                    CustomizationSettings.SliderRow {
                                        host: root
                                        key: rowLoader.modelData.key
                                        label: rowLoader.modelData.label
                                    }
                                }
                                Component {
                                    id: toggleC
                                    CustomizationSettings.ToggleRow {
                                        host: root
                                        key: rowLoader.modelData.key
                                        label: rowLoader.modelData.label
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: foot
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 56

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.alpha(Theme.text, 0.08)
                    }

                    CustomizationSettings.ActionButton {
                        id: resetAllBtn
                        host: root
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Reset all"
                        enabled: root.modified
                        onClicked: root.resetAll()
                    }

                    CustomizationSettings.ActionButton {
                        host: root
                        x: resetAllBtn.x + resetAllBtn.width + 8
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Reset position"
                        enabled: root.moved
                        onClicked: root.resetPosition()
                    }

                    CustomizationSettings.ActionButton {
                        host: root
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Done"
                        primary: true
                        onClicked: root.closeSettings()
                    }
                }
            }
        }
    }
}