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
        scale: 1.0, barScale: 0.9, bgOpacity: 0.35, border: false, radius: 16, calRadius: 15, calScale: 0.9,
        tooltips: true, tooltipHints: false, tooltipBorder: false, tipDelay: 450,
        modPad: 18, wsDot: 16, wsGap: 8, wsScroll: true, wsNumbers: true,
        tasksScale: 0.85, tasksGap: 2, tasksColor: "normal",
        statsPercent: false, statsScale: 0.95, statsBorder: false, statsRadius: 24, statsGap: 1, statsWarn: 85, tempWarn: 85, batLowPct: 15,
        batNumber: false, batPercent: false,
        volStep: 2, volMax: 100, volNumber: false, volPercent: false,
        clock24: true, clockSeconds: false, clockPadHour: true, clockDate: true, clockDay: false, clockCase: "normal", weekMonday: true,
        clockPrimary: "calendar", clockSecondary: "settings", clockTertiary: "quickactions",
        settingsPrimary: "settings", settingsSecondary: "barsettings", settingsTertiary: "none",
        hidden: "wall,settings,ram",
        startMods: "notif,cpu,ram,gpu,cputemp,gputemp",
        midLeftMods: "ws",
        centerMods: "clock",
        midRightMods: "tasks",
        endMods: "media,battery,wall,settings,volume,net,power"
    })

    readonly property var positions: ["top", "right", "bottom", "left"]
    readonly property var styles: ["floating", "joined", "strip"]
    readonly property var clockActions: ["calendar", "quickactions", "settings", "barsettings", "none"]
    readonly property var settingsActions: ["settings", "barsettings", "quickactions", "none"]
    readonly property var actionLabels: ({ quickactions: "QUICK ACTIONS", barsettings: "BAR SETTINGS" })
    readonly property var caseOptions: ["normal", "upper", "lower"]
    readonly property var caseLabels: ({ normal: "NORMAL", upper: "UPPERCASE", lower: "LOWERCASE" })

    // Module order / section placement is changed by dragging modules on the bar itself.
    // This page only turns modules on and off.
    readonly property var moduleDefs: [
        { id: "clock",    l: "CLOCK" },
        { id: "cpu",      l: "CPU" },
        { id: "ram",      l: "RAM" },
        { id: "gpu",      l: "GPU" },
        { id: "cputemp",  l: "CPU TEMP" },
        { id: "gputemp",  l: "GPU TEMP" },
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
            x === "stats" ? out.push("cpu", "ram")
          : x === "temp"  ? out.push("cputemp", "gputemp")
          : out.push(x)
        return out
    }

    function isOn(id) { return csv(val("hidden")).indexOf(id) < 0 }
    function setOn(id, on) {
        const h = csv(val("hidden")).filter(x => x !== id)
        if (!on) h.push(id)
        set("hidden", h.join(","))
    }

    // any of the CPU / RAM / GPU / TEMPS badges is shown
    readonly property bool statsOn: isOn("cpu") || isOn("ram") || isOn("gpu") || isOn("cputemp") || isOn("gputemp")

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
    // Quick jump (section chips at the top of the page)
    // ------------------------------------------------------------------

    NumberAnimation {
        id: jumpAnim
        target: flick
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
    }

    function jumpTo(item) {
        if (!item) return
        jumpAnim.stop()
        jumpAnim.from = flick.contentY
        jumpAnim.to = Math.max(0, Math.min(item.y, flick.contentHeight - flick.height))
        jumpAnim.start()
    }

    // ------------------------------------------------------------------
    // Reusable inline components
    //
    // Controls size themselves from their parent: inside a `Cols` grid they
    // take one cell (parent.cellWidth), anywhere else they take the full width.
    // ------------------------------------------------------------------

    // Grid of N equal columns. Put sliders / toggles / cycle buttons inside.
    component Cols: Grid {
        property int cols: 2
        readonly property real cellWidth: Math.floor((width - (cols - 1) * columnSpacing) / cols)
        width: parent.width
        columns: cols
        columnSpacing: 12
        rowSpacing: 6
    }

    component SectionTitle: Text {
        color: Theme.text
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSection; font.bold: true; font.letterSpacing: 2
    }

    component GroupLabel: Text {
        color: Theme.accent2
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup; font.bold: true; font.letterSpacing: 1
    }

    // small grey explanation under a section title
    component Note: Text {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.textDim
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
    }

    component Divider: Rectangle {
        width: parent.width; height: 1
        color: Theme.border
        opacity: 0.5
    }

    component Card: Rectangle {
        id: card
        default property alias contentData: cardColumn.data
        width: parent.width
        height: cardColumn.implicitHeight + 20
        radius: Theme.radius
        color: "#00000000"; border.width: 1; border.color: Theme.border

        Column {
            id: cardColumn
            x: 10; y: 10
            width: parent.width - 20
            spacing: 8
        }
    }

    component SmallButton: Rectangle {
        id: sb
        property string label: ""
        property bool current: false
        property bool buttonEnabled: true
        signal clicked()
        height: 26; radius: Theme.radius
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

    // Section chip: sized to its text, scrolls the page to `target`.
    component NavChip: SmallButton {
        property Item target: null
        width: Math.ceil(navMetrics.advanceWidth) + 20
        height: 22

        TextMetrics {
            id: navMetrics
            text: label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeBody
            font.bold: true
            font.letterSpacing: 1
        }

        onClicked: page.jumpTo(target)
    }

    // On/off switch as a single button: filled dot + highlight = on.
    component ToggleRow: Item {
        id: tg
        property string label: ""
        property bool checked: false
        property bool locked: false
        signal toggled(bool v)

        width: parent.cellWidth ?? parent.width
        height: 26
        opacity: enabled ? 1.0 : 0.4

        SmallButton {
            width: tg.width; height: tg.height
            label: (tg.checked ? "● " : "○ ") + tg.label
            current: tg.checked
            buttonEnabled: !tg.locked
            onClicked: tg.toggled(!tg.checked)
        }
    }

    // Label + value on one line, drag track right below.
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

        width: parent.cellWidth ?? parent.width
        height: 34
        opacity: enabled ? 1.0 : 0.4

        Text {
            anchors.left: parent.left; anchors.right: valueText.left; anchors.rightMargin: 6
            y: 0
            elide: Text.ElideRight
            text: sl.label
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
        }

        Text {
            id: valueText
            anchors.right: parent.right; y: 0
            text: (sl.value * sl.displayScale).toFixed(sl.decimals) + sl.unit
            color: Theme.accent2
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
        }

        Rectangle {
            id: track
            anchors.left: parent.left; anchors.right: parent.right
            y: 24; height: 4; radius: 2
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
            y: 14; height: 20
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

    // Label on top, one button per option side by side (wraps after `maxCols`).
    // Use for short lists where seeing every option at once helps.
    component BarChoice: Item {
        id: ch
        property string label: ""
        property var options: []
        property string current: ""
        property int maxCols: 4
        property var labels: ({})       // optional id → display text (default: id in upper case)
        signal picked(string v)

        readonly property int cols: Math.max(1, Math.min(options.length, maxCols))

        width: parent.cellWidth ?? parent.width
        height: lbl.implicitHeight + 3 + flow.implicitHeight
        opacity: enabled ? 1.0 : 0.4

        Text {
            id: lbl
            text: ch.label
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
        }

        Flow {
            id: flow
            y: lbl.implicitHeight + 3
            width: parent.width
            spacing: 6

            Repeater {
                model: ch.options
                delegate: SmallButton {
                    required property string modelData
                    width: Math.floor((ch.width - (ch.cols - 1) * 6) / ch.cols)
                    label: ch.labels[modelData] ?? modelData.toUpperCase()
                    current: modelData === ch.current
                    buttonEnabled: ch.enabled
                    onClicked: ch.picked(modelData)
                }
            }
        }
    }

    // Label on top, ONE button below that shows the current option; click = next option.
    // Compact replacement for long option lists.
    component CycleChoice: Item {
        id: cy
        property string label: ""
        property var options: []
        property string current: ""
        property var labels: ({})
        signal picked(string v)

        width: parent.cellWidth ?? parent.width
        height: cyLabel.implicitHeight + 3 + 26
        opacity: enabled ? 1.0 : 0.4

        Text {
            id: cyLabel
            text: cy.label
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
        }

        SmallButton {
            y: cyLabel.implicitHeight + 3
            width: cy.width
            label: (cy.labels[cy.current] ?? cy.current.toUpperCase()) + "  ›"
            buttonEnabled: cy.enabled
            onClicked: {
                const i = cy.options.indexOf(cy.current)
                cy.picked(cy.options[(i + 1) % cy.options.length])
            }
        }
    }

    // ------------------------------------------------------------------
    // UI
    //
    // Sections, most used first:
    //   Bar (layout + look) · Modules · Clock & Calendar · Workspaces & Open apps
    //   System stats · Battery & Volume · Tooltips · Click actions
    // Options that belong to a module are dimmed while that module is off.
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
            spacing: 8

            // ---------------- TITLE + RESET ----------------
            Item {
                width: parent.width; height: 26

                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "BAR"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeTitle; font.letterSpacing: 3
                }

                SmallButton {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 110; height: 22
                    label: "RESET ALL"
                    buttonEnabled: page.modified
                    onClicked: page.resetAll()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------- LAYOUT + APPEARANCE ----------------
            // Where the bar sits, how big it is, and how it looks.
            Column {
                id: secBar
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "LAYOUT & APPEARANCE" }

                Card {
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

                    Divider {}

                    Cols {
                        BarSlider {
                            label: "THICKNESS"
                            from: 16; to: 40; step: 1; unit: " px"
                            value: page.val("thickness")
                            onMoved: v => page.set("thickness", v)
                        }
                        BarSlider {
                            label: "BAR SCALE"
                            from: 0.6; to: 1.5; step: 0.05; unit: "×"; decimals: 2
                            value: page.val("barScale")
                            onMoved: v => page.set("barScale", v)
                        }
                        BarSlider {
                            label: "EDGE MARGIN"
                            enabled: !page.strip
                            from: 0; to: 16; step: 1; unit: " px"
                            value: page.val("margin")
                            onMoved: v => page.set("margin", v)
                        }
                        BarSlider {
                            label: "MODULE PADDING"
                            from: 0; to: 40; step: 2; unit: " px"
                            value: page.val("modPad")
                            onMoved: v => page.set("modPad", v)
                        }
                        BarSlider {
                            label: "BG OPACITY"
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
                            label: "TEXT SCALE"
                            from: 0.8; to: 1.5; step: 0.05; unit: "×"; decimals: 2
                            value: page.val("scale")
                            onMoved: v => page.set("scale", v)
                        }
                    }

                    Divider {}

                    Cols {
                        cols: 3
                        ToggleRow {
                            label: "BORDER"; checked: page.val("border")
                            onToggled: v => page.set("border", v)
                        }
                        ToggleRow {
                            label: "RESERVE SPACE"; checked: page.val("reserveSpace")
                            onToggled: v => page.set("reserveSpace", v)
                        }
                        ToggleRow {
                            label: "ALL MONITORS"; checked: page.val("allScreens")
                            onToggled: v => page.set("allScreens", v)
                        }
                        ToggleRow {
                            label: "DRAG MODULES"; checked: page.val("dragModules")
                            onToggled: v => page.set("dragModules", v)
                        }
                    }
                }
            }

            // --------------- MODULES ----------------
            // One compact on/off button per module, four per row.
            // Highlighted = shown on the bar. Reorder by dragging modules on the bar.
            Column {
                id: secModules
                width: parent.width; spacing: 6
                topPadding: 2

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
            }

            // ---------------- CLOCK, DATE & CALENDAR ----------------
            // The calendar is the popup that opens from the clock.
            Column {
                id: secClock
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "CLOCK & CALENDAR" }

                Note {
                    visible: !page.isOn("clock")
                    text: "Turn on the CLOCK module to use these options."
                }

                Card {
                    enabled: page.isOn("clock")

                    Cols {
                        cols: 3
                        ToggleRow {
                            label: "24-HOUR"; checked: page.val("clock24")
                            onToggled: v => page.set("clock24", v)
                        }
                        ToggleRow {
                            label: "SECONDS"; checked: page.val("clockSeconds")
                            onToggled: v => page.set("clockSeconds", v)
                        }
                        ToggleRow {
                            label: "LEADING 0"; checked: page.val("clockPadHour")
                            onToggled: v => page.set("clockPadHour", v)
                        }
                        ToggleRow {
                            label: "SHOW DATE"; checked: page.val("clockDate")
                            onToggled: v => page.set("clockDate", v)
                        }
                        ToggleRow {
                            label: "WEEKDAY"; checked: page.val("clockDay")
                            enabled: page.val("clockDate")
                            onToggled: v => page.set("clockDay", v)
                        }
                    }

                    Divider {}

                    Cols {
                        CycleChoice {
                            label: "DAY & AM/PM CASE"
                            // only matters while the weekday or the AM/PM suffix is visible
                            enabled: (page.val("clockDate") && page.val("clockDay")) || !page.val("clock24")
                            options: page.caseOptions; labels: page.caseLabels
                            current: page.val("clockCase")
                            onPicked: v => page.set("clockCase", v)
                        }
                        CycleChoice {
                            label: "WEEK STARTS ON"
                            options: ["monday", "sunday"]
                            current: page.val("weekMonday") ? "monday" : "sunday"
                            onPicked: v => page.set("weekMonday", v === "monday")
                        }
                        BarSlider {
                            label: "CALENDAR SCALE"
                            from: 0.6; to: 1.5; step: 0.05; unit: "×"; decimals: 2
                            value: page.val("calScale")
                            onMoved: v => page.set("calScale", v)
                        }
                        BarSlider {
                            label: "CALENDAR RADIUS"
                            from: 0; to: 32; step: 1; unit: " px"
                            value: page.val("calRadius")
                            onMoved: v => page.set("calRadius", v)
                        }
                    }
                }
            }

            // ---------------- WORKSPACES + OPEN APPS ----------------
            Column {
                id: secWorkspaces
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "WORKSPACES & OPEN APPS" }

                Card {
                    Column {
                        width: parent.width; spacing: 6
                        enabled: page.isOn("ws")
                        opacity: enabled ? 1.0 : 0.45

                        GroupLabel { text: page.isOn("ws") ? "WORKSPACES" : "WORKSPACES  (turn the module on in MODULES)" }
                        Cols {
                            BarSlider {
                                label: "DOT SIZE"
                                from: 6; to: 30; step: 1; unit: " px"
                                value: page.val("wsDot")
                                onMoved: v => page.set("wsDot", v)
                            }
                            BarSlider {
                                label: "DOT SPACING"
                                from: 0; to: 20; step: 1; unit: " px"
                                value: page.val("wsGap")
                                onMoved: v => page.set("wsGap", v)
                            }
                            ToggleRow {
                                label: "NUMBERS"; checked: page.val("wsNumbers")
                                onToggled: v => page.set("wsNumbers", v)
                            }
                            /*ToggleRow {
                                label: "SCROLL TO SWITCH"; checked: page.val("wsScroll")
                                onToggled: v => page.set("wsScroll", v)
                            }*/
                        }
                    }

                    Divider {}

                    Column {
                        width: parent.width; spacing: 6
                        enabled: page.isOn("tasks")
                        opacity: enabled ? 1.0 : 0.45

                        GroupLabel { text: page.isOn("tasks") ? "OPEN APPS" : "OPEN APPS  (turn the module on in MODULES)" }
                        Cols {
                            BarSlider {
                                label: "ICON SCALE"
                                from: 0.5; to: 1.5; step: 0.05; unit: "×"; decimals: 2
                                value: page.val("tasksScale")
                                onMoved: v => page.set("tasksScale", v)
                            }
                            BarSlider {
                                label: "ICON SPACING"
                                from: 0; to: 16; step: 1; unit: " px"
                                value: page.val("tasksGap")
                                onMoved: v => page.set("tasksGap", v)
                            }
                            CycleChoice {
                                label: "ICON COLOR"
                                options: ["normal", "accent"]
                                current: page.val("tasksColor")
                                onPicked: v => page.set("tasksColor", v)
                            }
                        }
                    }
                }
            }

            // ---------------- SYSTEM STATS ----------------
            // CPU / RAM / GPU / TEMP badges.
            Column {
                id: secStats
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "SYSTEM STATS" }

                Note {
                    visible: !page.statsOn
                    text: "Turn on CPU, RAM, GPU, CPU TEMP or GPU TEMP in MODULES to use these options."
                }

                Card {
                    enabled: page.statsOn

                    Cols {
                        ToggleRow {
                            label: "% / °C SYMBOLS"; checked: page.val("statsPercent")
                            onToggled: v => page.set("statsPercent", v)
                        }
                        ToggleRow {
                            label: "BADGE BORDER"; checked: page.val("statsBorder")
                            onToggled: v => page.set("statsBorder", v)
                        }
                    }

                    Cols {
                        BarSlider {
                            label: "TEXT SCALE"
                            from: 0.5; to: 2.0; step: 0.05; unit: "×"; decimals: 2
                            value: page.val("statsScale")
                            onMoved: v => page.set("statsScale", v)
                        }
                        BarSlider {
                            label: "CORNER RADIUS"
                            from: 0; to: 24; step: 1; unit: " px"
                            value: page.val("statsRadius")
                            onMoved: v => page.set("statsRadius", v)
                        }
                        BarSlider {
                            label: "SPACING"
                            from: 0; to: 24; step: 1; unit: " px"
                            value: page.val("statsGap")
                            onMoved: v => page.set("statsGap", v)
                        }
                        BarSlider {
                            label: "HIGH LOAD WARNING"
                            from: 50; to: 100; step: 5; unit: "%"
                            value: page.val("statsWarn")
                            onMoved: v => page.set("statsWarn", v)
                        }
                        BarSlider {
                            label: "HIGH TEMP WARNING"
                            from: 50; to: 110; step: 5; unit: " °"
                            value: page.val("tempWarn")
                            onMoved: v => page.set("tempWarn", v)
                        }
                    }
                }
            }

            // ---------------- BATTERY & VOLUME (side by side) ----------------
            Column {
                id: secBattVol
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "BATTERY & VOLUME" }

                Card {
                    Cols {
                        Column {
                            width: parent.cellWidth ?? parent.width
                            spacing: 6

                            GroupLabel { text: "BATTERY" }
                            ToggleRow {
                                label: "NUMBER"; checked: page.val("batNumber")
                                enabled: page.isOn("battery")
                                onToggled: v => page.set("batNumber", v)
                            }
                            ToggleRow {
                                label: "% SYMBOL"; checked: page.val("batPercent")
                                enabled: page.isOn("battery") && page.val("batNumber")
                                onToggled: v => page.set("batPercent", v)
                            }
                            BarSlider {
                                label: "LOW WARNING"
                                enabled: page.isOn("battery")
                                from: 5; to: 50; step: 5; unit: "%"
                                value: page.val("batLowPct")
                                onMoved: v => page.set("batLowPct", v)
                            }
                        }

                        Column {
                            width: parent.cellWidth ?? parent.width
                            spacing: 6

                            GroupLabel { text: "VOLUME" }
                            ToggleRow {
                                label: "NUMBER"; checked: page.val("volNumber")
                                enabled: page.isOn("volume")
                                onToggled: v => page.set("volNumber", v)
                            }
                            ToggleRow {
                                label: "% SYMBOL"; checked: page.val("volPercent")
                                enabled: page.isOn("volume") && page.val("volNumber")
                                onToggled: v => page.set("volPercent", v)
                            }
                            BarSlider {
                                label: "SCROLL STEP"
                                enabled: page.isOn("volume")
                                from: 1; to: 10; step: 1; unit: "%"
                                value: page.val("volStep")
                                onMoved: v => page.set("volStep", v)
                            }
                            BarSlider {
                                label: "MAX VOLUME"
                                enabled: page.isOn("volume")
                                from: 100; to: 150; step: 5; unit: "%"
                                value: page.val("volMax")
                                onMoved: v => page.set("volMax", v)
                            }
                        }
                    }
                }
            }

            // ---------------- TOOLTIPS ----------------
            Column {
                id: secTooltips
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "TOOLTIPS" }

                Card {
                    Cols {
                        cols: 3
                        ToggleRow {
                            label: "SHOW"; checked: page.val("tooltips")
                            onToggled: v => page.set("tooltips", v)
                        }
                        ToggleRow {
                            label: "HINTS"; checked: page.val("tooltipHints")
                            enabled: page.val("tooltips")
                            onToggled: v => page.set("tooltipHints", v)
                        }
                        ToggleRow {
                            label: "BORDER"; checked: page.val("tooltipBorder")
                            enabled: page.val("tooltips")
                            onToggled: v => page.set("tooltipBorder", v)
                        }
                    }

                    Cols {
                        BarSlider {
                            label: "DELAY"
                            enabled: page.val("tooltips")
                            from: 0; to: 1500; step: 50; unit: " ms"
                            value: page.val("tipDelay")
                            onMoved: v => page.set("tipDelay", v)
                        }
                    }
                }
            }

            // ---------------- CLICK ACTIONS ----------------
            // What a click on the clock / settings button does.
            // Click a button to cycle through the available actions.
            Column {
                id: secActions
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "CLICK ACTIONS" }

                Card {
                    GroupLabel { text: "CLOCK" }
                    Cols {
                        cols: 3
                        enabled: page.isOn("clock")
                        CycleChoice {
                            label: "LEFT"
                            options: page.clockActions; labels: page.actionLabels
                            current: page.val("clockPrimary")
                            onPicked: v => page.set("clockPrimary", v)
                        }
                        CycleChoice {
                            label: "RIGHT"
                            options: page.clockActions; labels: page.actionLabels
                            current: page.val("clockSecondary")
                            onPicked: v => page.set("clockSecondary", v)
                        }
                        CycleChoice {
                            label: "MIDDLE"
                            options: page.clockActions; labels: page.actionLabels
                            current: page.val("clockTertiary")
                            onPicked: v => page.set("clockTertiary", v)
                        }
                    }

                    Divider {}

                    GroupLabel { text: "SETTINGS BUTTON" }
                    Cols {
                        cols: 3
                        enabled: page.isOn("settings")
                        CycleChoice {
                            label: "LEFT"
                            options: page.settingsActions; labels: page.actionLabels
                            current: page.val("settingsPrimary")
                            onPicked: v => page.set("settingsPrimary", v)
                        }
                        CycleChoice {
                            label: "RIGHT"
                            options: page.settingsActions; labels: page.actionLabels
                            current: page.val("settingsSecondary")
                            onPicked: v => page.set("settingsSecondary", v)
                        }
                        CycleChoice {
                            label: "MIDDLE"
                            options: page.settingsActions; labels: page.actionLabels
                            current: page.val("settingsTertiary")
                            onPicked: v => page.set("settingsTertiary", v)
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