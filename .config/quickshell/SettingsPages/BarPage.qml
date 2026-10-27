import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 10
    property real marginTop: 0
    property real marginBottom: 0

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"

    // ------------------------------------------------------------------
    // Bar config (shared with the bar through state/bar-state.json)
    // The bar watches that file, so every change here applies instantly.
    // Keep `defaults` in sync with Bar.qml.
    // ------------------------------------------------------------------

    readonly property var defaults: ({
        position: "left", style: "joined", thickness: 20, margin: 4,
        reserveSpace: true, allScreens: true, dragModules: true,
        scale: 1.0, bgOpacity: 0.5, border: false, radius: 16, calRadius: 15,
        tooltips: true, tooltipHints: true, tipDelay: 450,
        modPad: 20, wsDot: 10, wsGap: 8, wsScroll: true,
        statsMode: "compact", statsWarn: 85, tempWarn: 85, batLowPct: 15,
        volStep: 2, volMax: 100,
        clock24: true, clockSeconds: false, weekMonday: true,
        hidden: "cpu,ram,gpu,temp,wall,settings,tasks",
        startMods: "cpu,ram,gpu,temp,ws",
        centerMods: "clock",
        endMods: "media,volume,battery,net,notif,wall,settings,power"
    })

    readonly property var positions: ["top", "right", "bottom", "left"]
    readonly property var styles: ["floating", "joined", "strip"]
    readonly property var statsModes: ["default", "compact"]

    // Module order / section placement is changed by dragging modules on the bar itself.
    // This page only turns modules on and off.
    readonly property var moduleDefs: [
        { id: "cpu",      l: "CPU" },
        { id: "ram",      l: "RAM" },
        { id: "gpu",      l: "GPU" },
        { id: "temp",     l: "TEMPS" },
        { id: "ws",       l: "WORKSPACES" },
        { id: "tasks",    l: "OPEN APPS" },
        { id: "media",    l: "MEDIA" },
        { id: "volume",   l: "VOLUME" },
        { id: "battery",  l: "BATTERY" },
        { id: "net",      l: "NETWORK" },
        { id: "notif",    l: "NOTIFS" },
        { id: "wall",     l: "WALLPAPERS" },
        { id: "settings", l: "SETTINGS" },
        { id: "power",    l: "POWER", fixed: true }
    ]

    // values changed from their defaults (reassigned on every change so bindings update)
    property var s: ({})
    property bool selfWrite: false

    function val(k) { return s[k] !== undefined ? s[k] : defaults[k] }

    function set(k, v) {
        const o = {}
        o[k] = v
        setMany(o)
    }

    function setMany(o) {
        s = Object.assign({}, s, o)
        saveTimer.restart()
    }

    function resetAll() {
        s = ({})
        saveTimer.restart()
    }

    readonly property bool modified: Object.keys(defaults).some(k => val(k) !== defaults[k])
    readonly property bool vertical: val("position") === "left" || val("position") === "right"
    readonly property bool strip: val("style") === "strip"

    // ---- module enable / disable (mirrors the logic in Bar.qml) ----
    // The old combined "stats" module is migrated to "cpu" + "ram".
    function csv(str) {
        if (str === "") return []
        const out = []
        for (const x of str.split(","))
        x === "stats" ? out.push("cpu", "ram") : out.push(x)
        return out
    }

    function isOn(id) { return csv(val("hidden")).indexOf(id) < 0 }
    function setOn(id, on) {
        const h = csv(val("hidden")).filter(x => x !== id)
        if (!on) h.push(id)
        set("hidden", h.join(","))
    }

    // ------------------------------------------------------------------
    // Persistence
    // ------------------------------------------------------------------

    FileView {
        id: settingsFile
        path: page.stateDir + "/bar-state.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: if (!page.selfWrite) page.loadSettings()
    }

    Process {
        id: stateDirProcess
        command: ["mkdir", "-p", page.stateDir]
    }

    function loadSettings() {
        try {
            const j = JSON.parse(settingsFile.text())
            const o = {}
            for (const k in defaults)
                if (j[k] !== undefined && typeof j[k] === typeof defaults[k]) o[k] = j[k]
            s = o
        } catch (error) {}
    }

    Timer {
        id: saveTimer
        interval: 150
        onTriggered: {
            page.selfWrite = true
            selfTimer.restart()
            try {
                settingsFile.setText(JSON.stringify(Object.assign({}, page.defaults, page.s), null, 2))
            } catch (error) {}
        }
    }

    // ignore the file-change echo of our own write
    Timer { id: selfTimer; interval: 600; onTriggered: page.selfWrite = false }

    // ------------------------------------------------------------------
    // Reusable inline components
    // ------------------------------------------------------------------

    component SectionTitle: Text {
        color: Theme.text
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSection; font.bold: true; font.letterSpacing: 2
    }

    component GroupLabel: Text {
        color: Theme.text
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup; font.bold: true; font.letterSpacing: 1
    }

    component Card: Rectangle {
        id: card
        default property alias contentData: cardColumn.data
        width: parent.width
        height: cardColumn.implicitHeight + 28
        radius: Theme.radius
        color: "#00000000"; border.width: 1; border.color: Theme.border

        Column {
            id: cardColumn
            x: 14; y: 14
            width: parent.width - 28
            spacing: 16
        }
    }

    component SmallButton: Rectangle {
        id: sb
        property string label: ""
        property bool current: false
        property bool buttonEnabled: true
        signal clicked()
        height: 28; radius: Theme.radius
        opacity: buttonEnabled ? 1.0 : 0.35
        color: current ? Theme.alpha(Theme.accent, 0.10) : (sbMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
        border.width: 1
        border.color: current || sbMouse.containsMouse ? Theme.accent : Theme.border

        Text {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, sb.width - 8)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: sb.label
            color: sb.current ? Theme.accent : Theme.text
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.bold: true; font.letterSpacing: 1
        }

        MouseArea {
            id: sbMouse
            anchors.fill: parent; hoverEnabled: true
            enabled: sb.buttonEnabled
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.clicked()
        }
    }

    component ToggleRow: Item {
        id: tg
        property string label: ""
        property bool checked: false
        property bool locked: false
        signal toggled(bool v)

        width: parent.width; height: 28
        opacity: enabled ? 1.0 : 0.4

        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: tg.label
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
        }

        SmallButton {
            anchors.right: parent.right
            width: 72
            label: tg.checked ? "ON" : "OFF"
            current: tg.checked
            buttonEnabled: !tg.locked
            onClicked: tg.toggled(!tg.checked)
        }
    }

    // Label + value on top, drag track below.
    component BarSlider: Item {
        id: sl
        property string label: ""
        property real from: 0
        property real to: 1
        property real step: 1
        property real value: 0
        property string unit: ""
        property real displayScale: 1
        property int decimals: 0
        signal moved(real v)

        readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

        width: parent.width; height: 40
        opacity: enabled ? 1.0 : 0.4

        Text {
            anchors.left: parent.left; y: 0
            text: sl.label
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
        }

        Text {
            anchors.right: parent.right; y: 0
            text: (sl.value * sl.displayScale).toFixed(sl.decimals) + sl.unit
            color: Theme.accent2
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
        }

        Rectangle {
            id: track
            anchors.left: parent.left; anchors.right: parent.right
            y: 28; height: 4; radius: 2
            color: Theme.border

            Rectangle {
                width: knob.x + knob.width / 2
                height: parent.height; radius: 2
                color: Theme.accent
            }
            Rectangle {
                id: knob
                width: 12; height: 12; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: sl.ratio * (track.width - width)
                color: Theme.accent
            }
        }

        MouseArea {
            anchors.left: parent.left; anchors.right: parent.right
            y: 18; height: 22
            hoverEnabled: true
            preventStealing: true      // keep the page from scrolling while dragging
            enabled: sl.enabled
            cursorShape: Qt.PointingHandCursor

            function apply(mx) {
                const usable = track.width - knob.width
                if (usable <= 0) return
                const r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable))
                const v = sl.from + r * (sl.to - sl.from)
                sl.moved(sl.step > 0 ? +(Math.round(v / sl.step) * sl.step).toFixed(3) : v)
            }
            onPressed: m => apply(m.x)
            onPositionChanged: m => { if (pressed) apply(m.x) }
        }
    }

    // Label on top, a wrapping row of buttons below.
    component BarChoice: Item {
        id: ch
        property string label: ""
        property var options: []
        property string current: ""
        property int btnWidth: 92
        signal picked(string v)

        width: parent.width
        height: lbl.implicitHeight + 8 + flow.implicitHeight
        opacity: enabled ? 1.0 : 0.4

        Text {
            id: lbl
            text: ch.label
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
        }

        Flow {
            id: flow
            y: lbl.implicitHeight + 8
            width: parent.width
            spacing: 6

            Repeater {
                model: ch.options
                delegate: SmallButton {
                    required property string modelData
                    width: ch.btnWidth
                    label: modelData.toUpperCase()
                    current: modelData === ch.current
                    buttonEnabled: ch.enabled
                    onClicked: ch.picked(modelData)
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft; anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop; anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            background: Rectangle {
                color: "transparent"
                radius: width / 2
            }
            contentItem: Rectangle {
                color: "transparent"
                radius: width / 2
            }
        }

        Column {
            id: content
            width: flick.width
            spacing: 14

            Text {
                text: "BAR"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeTitle; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------- LAYOUT ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                Item {
                    width: parent.width; height: 24

                    SectionTitle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "LAYOUT"
                    }

                    SmallButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 110; height: 24
                        label: "RESET ALL"
                        buttonEnabled: page.modified
                        onClicked: page.resetAll()
                    }
                }

                Card {
                    Column {
                        width: parent.width; spacing: 12

                        BarChoice {
                            label: "POSITION"
                            options: page.positions
                            current: page.val("position")
                            onPicked: v => page.set("position", v)
                        }
                        BarChoice {
                            label: "STYLE"
                            options: page.styles
                            current: page.val("style")
                            onPicked: v => page.set("style", v)
                        }
                        BarSlider {
                            label: "THICKNESS"
                            from: 16; to: 40; step: 1; unit: " px"
                            value: page.val("thickness")
                            onMoved: v => page.set("thickness", v)
                        }
                        BarSlider {
                            label: "EDGE MARGIN"
                            enabled: !page.strip
                            from: 0; to: 16; step: 1; unit: " px"
                            value: page.val("margin")
                            onMoved: v => page.set("margin", v)
                        }
                        ToggleRow {
                            label: "RESERVE SCREEN SPACE"; checked: page.val("reserveSpace")
                            onToggled: v => page.set("reserveSpace", v)
                        }
                        ToggleRow {
                            label: "SHOW ON ALL MONITORS"; checked: page.val("allScreens")
                            onToggled: v => page.set("allScreens", v)
                        }
                        ToggleRow {
                            label: "DRAG MODULES ON BAR"; checked: page.val("dragModules")
                            onToggled: v => page.set("dragModules", v)
                        }
                    }
                }
            }

            // ---------------- APPEARANCE ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                SectionTitle { text: "APPEARANCE" }

                Card {
                    Column {
                        width: parent.width; spacing: 10

                        BarSlider {
                            label: "BACKGROUND OPACITY"
                            from: 0; to: 1; step: 0.05; unit: "%"; displayScale: 100
                            value: page.val("bgOpacity")
                            onMoved: v => page.set("bgOpacity", v)
                        }
                        BarSlider {
                            label: "CORNER RADIUS"
                            enabled: !page.strip
                            from: 0; to: 24; step: 1; unit: " px"
                            value: page.val("radius")
                            onMoved: v => page.set("radius", v)
                        }
                        BarSlider {
                            label: "CALENDAR RADIUS"
                            from: 0; to: 32; step: 1; unit: " px"
                            value: page.val("calRadius")
                            onMoved: v => page.set("calRadius", v)
                        }
                        BarSlider {
                            label: "TEXT SCALE"
                            from: 0.8; to: 1.5; step: 0.05; unit: "×"; decimals: 2
                            value: page.val("scale")
                            onMoved: v => page.set("scale", v)
                        }
                        ToggleRow {
                            label: "BORDER"; checked: page.val("border")
                            onToggled: v => page.set("border", v)
                        }
                    }
                }
            }

            // ---------------- TOOLTIPS ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                SectionTitle { text: "TOOLTIPS" }

                Card {
                    Column {
                        width: parent.width; spacing: 10

                        ToggleRow {
                            label: "SHOW TOOLTIPS"; checked: page.val("tooltips")
                            onToggled: v => page.set("tooltips", v)
                        }
                        ToggleRow {
                            label: "HINTS IN TOOLTIPS"; checked: page.val("tooltipHints")
                            enabled: page.val("tooltips")
                            onToggled: v => page.set("tooltipHints", v)
                        }
                        BarSlider {
                            label: "TOOLTIP DELAY"
                            enabled: page.val("tooltips")
                            from: 0; to: 1500; step: 50; unit: " ms"
                            value: page.val("tipDelay")
                            onMoved: v => page.set("tipDelay", v)
                        }
                    }
                }
            }

            // --------------- MODULES ----------------
            // One compact on/off button per module, four per row.
            // Highlighted = shown on the bar. Reorder by dragging modules on the bar.
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                SectionTitle { text: "MODULES" }

                Card {
                    Grid {
                        id: modGrid
                        width: parent.width
                        columns: 4
                        spacing: 6

                        Repeater {
                            model: page.moduleDefs
                            delegate: SmallButton {
                                required property var modelData
                                width: Math.floor((modGrid.width - modGrid.spacing * 3) / 4)
                                label: modelData.l
                                current: page.isOn(modelData.id) || !!modelData.fixed
                                buttonEnabled: !modelData.fixed
                                onClicked: page.setOn(modelData.id, !page.isOn(modelData.id))
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Drag modules on the bar to reorder them."
                    color: Theme.textDim
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
                }
            }

            // ---------------- CLOCK & CALENDAR ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                SectionTitle { text: "CLOCK & CALENDAR" }

                Card {
                    Column {
                        width: parent.width; spacing: 10

                        ToggleRow {
                            label: "24-HOUR CLOCK"; checked: page.val("clock24")
                            onToggled: v => page.set("clock24", v)
                        }
                        ToggleRow {
                            label: "SHOW SECONDS"; checked: page.val("clockSeconds")
                            onToggled: v => page.set("clockSeconds", v)
                        }
                        BarChoice {
                            label: "WEEK STARTS ON"
                            options: ["monday", "sunday"]
                            current: page.val("weekMonday") ? "monday" : "sunday"
                            onPicked: v => page.set("weekMonday", v === "monday")
                        }
                    }
                }
            }

            // ---------------- MODULE APPEARANCE ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                SectionTitle { text: "MODULE APPEARANCE" }

                Card {
                    Column {
                        width: parent.width; spacing: 10

                        BarSlider {
                            label: "MODULE PADDING"
                            from: 0; to: 40; step: 2; unit: " px"
                            value: page.val("modPad")
                            onMoved: v => page.set("modPad", v)
                        }
                        BarSlider {
                            label: "WORKSPACE DOT SIZE"
                            from: 6; to: 18; step: 1; unit: " px"
                            value: page.val("wsDot")
                            onMoved: v => page.set("wsDot", v)
                        }
                        BarSlider {
                            label: "WORKSPACE DOT SPACING"
                            from: 0; to: 20; step: 1; unit: " px"
                            value: page.val("wsGap")
                            onMoved: v => page.set("wsGap", v)
                        }
                        ToggleRow {
                            label: "SCROLL TO SWITCH WORKSPACE"; checked: page.val("wsScroll")
                            onToggled: v => page.set("wsScroll", v)
                        }
                        BarChoice {
                            label: "CPU / RAM / GPU / TEMP STYLE"
                            options: page.statsModes
                            current: page.val("statsMode")
                            onPicked: v => page.set("statsMode", v)
                        }
                        BarSlider {
                            label: "HIGH CPU / RAM / GPU WARNING"
                            from: 50; to: 100; step: 5; unit: "%"
                            value: page.val("statsWarn")
                            onMoved: v => page.set("statsWarn", v)
                        }
                        BarSlider {
                            label: "HIGH TEMPERATURE WARNING"
                            from: 50; to: 110; step: 5; unit: " °C"
                            value: page.val("tempWarn")
                            onMoved: v => page.set("tempWarn", v)
                        }
                        BarSlider {
                            label: "LOW BATTERY WARNING"
                            from: 5; to: 50; step: 5; unit: "%"
                            value: page.val("batLowPct")
                            onMoved: v => page.set("batLowPct", v)
                        }
                        BarSlider {
                            label: "VOLUME SCROLL STEP"
                            from: 1; to: 10; step: 1; unit: "%"
                            value: page.val("volStep")
                            onMoved: v => page.set("volStep", v)
                        }
                        BarSlider {
                            label: "MAXIMUM VOLUME"
                            from: 100; to: 150; step: 5; unit: "%"
                            value: page.val("volMax")
                            onMoved: v => page.set("volMax", v)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        stateDirProcess.running = true
        loadSettings()
    }
}