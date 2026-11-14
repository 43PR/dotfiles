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
    // Side panel config (shared with SidePanel through state/sidepanel-state.json)
    // SidePanel watches that file, so every change here applies instantly.
    // Keep `defaults` / ranges in sync with SidePanel.qml.
    // Runtime values owned by SidePanel (dnd, night, nightTemp, collapsed)
    // are preserved when this page saves.
    // ------------------------------------------------------------------

    readonly property var numSpec: ({
        uiScale:        { min: 70,   max: 160,  def: 100,  step: 5,   unit: "%" },
        textSize:       { min: 70,   max: 160,  def: 100,  step: 5,   unit: "%" },
        panelWidth:     { min: 280,  max: 520,  def: 340,  step: 10,  unit: "px" },
        panelHeight:    { min: 30,   max: 100,  def: 100,  step: 5,   unit: "%" },
        notifsHeight:   { min: 0,    max: 800,  def: 0,    step: 20,  unit: "px" },
        cornerRadius:   { min: 0,    max: 40,   def: 16,   step: 2,   unit: "px" },
        bgOpacity:      { min: 0,    max: 100,  def: 70,   step: 5,   unit: "%" },
        borderOpacity: { min: 0, max: 100, def: 100, step: 5, unit: "%" },
        animMs:         { min: 0,    max: 500,  def: 200,  step: 20,  unit: " ms" },
        groupLimit:     { min: 2,    max: 8,    def: 3,    step: 1,   unit: "" },
        notifBgOpacity: { min: 0,    max: 100,  def: 30,   step: 5,   unit: "%" },
        brightnessStep: { min: 1,    max: 20,   def: 5,    step: 1,   unit: "%" },
        nightStep:      { min: 50,   max: 500,  def: 100,  step: 50,  unit: " K" },
        tiltStrength:   { min: 0, max: 15, def: 1, step: 1, unit: "" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showCalendar: true,
        showQuick: true,
        border: false,
        weekMonday: true,
        clock24: true,
        clockSeconds: false,
        toasts: true,
        soundEnabled: true,
        notifBgEnabled: false
        })
    readonly property var boolKeys: Object.keys(boolDefaults)

    readonly property var accentChoices: [
        { id: "accent",  label: "ACCENT" },
        { id: "accent2", label: "ACCENT 2" },
        { id: "text",    label: "TEXT" }
    ]
    readonly property var accentIds: accentChoices.map(c => c.id)
    readonly property var accentLabels: ({
        accent: "ACCENT", accent2: "ACCENT 2", text: "TEXT"
    })

    // quick-action tiles that can be shown / hidden (matches SidePanel.allActions)
    readonly property var allActions: [
        { name: "wifi",   label: "WI-FI" },
        { name: "bt",     label: "BLUETOOTH" },
        { name: "dnd",    label: "DO NOT DISTURB" },
        { name: "night",  label: "NIGHT LIGHT" },
        { name: "bright", label: "BRIGHTNESS" }
    ]

    // body section order (matches SidePanel.sectionIds)
    readonly property var sectionIds: ["calendar", "quick", "notifs"]
    readonly property var sectionLabels: ({
        calendar: "CALENDAR",
        quick: "QUICK ACTIONS",
        notifs: "NOTIFICATIONS"
    })
    readonly property var sectionBoolKey: ({
        calendar: "showCalendar",
        quick: "showQuick",
    })

    readonly property var defaults: {
        const o = {
            accentSource: "accent",
            panelSide: "left",
            notifBgPath: "",
            hidden: [],                 // array of action names
            sectionOrder: sectionIds.slice()
        }
        for (const k of numKeys) o[k] = numSpec[k].def
        for (const k of boolKeys) o[k] = boolDefaults[k]
        return o
    }

    // values changed from their defaults (reassigned on every change so bindings update)
    property var s: ({})
    property bool selfWrite: false
    // runtime fields from SidePanel that we must not clobber on save
    property var runtime: ({})

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

    readonly property bool modified: Object.keys(defaults).some(k => {
        const a = val(k), b = defaults[k]
        if (Array.isArray(a) && Array.isArray(b))
            return a.length !== b.length || a.some((x, i) => x !== b[i])
        return a !== b
    })

    function isActionOn(name) {
        const h = val("hidden")
        return !Array.isArray(h) || h.indexOf(name) < 0
    }
    function setActionOn(name, on) {
        let h = Array.isArray(val("hidden")) ? val("hidden").slice() : []
        const i = h.indexOf(name)
        if (on && i >= 0) h.splice(i, 1)
        else if (!on && i < 0) h.push(name)
        set("hidden", h)
    }

    function sectionOrder() {
        const o = val("sectionOrder")
        if (!Array.isArray(o) || o.length === 0) return sectionIds.slice()
        const next = o.filter(id => sectionIds.indexOf(id) >= 0)
        for (let i = 0; i < sectionIds.length; i++)
            if (next.indexOf(sectionIds[i]) < 0) next.push(sectionIds[i])
        return next
    }
    function moveSection(id, dir) {
        const o = sectionOrder().slice()
        const i = o.indexOf(id)
        const j = i + dir
        if (i < 0 || j < 0 || j >= o.length) return
        const tmp = o[i]; o[i] = o[j]; o[j] = tmp
        set("sectionOrder", o)
    }

    function fmtValue(key, v) { return v + numSpec[key].unit }

    // Accepts a typed/pasted path: trims whitespace and surrounding quotes,
    // turns file:// URLs into plain paths, expands a leading ~.
    function cleanPath(raw) {
        let p = String(raw).trim().replace(/^["']|["']$/g, "")
        if (p.indexOf("file://") === 0) p = decodeURIComponent(p.substring(7))
        if (p === "~" || p.indexOf("~/") === 0) p = Quickshell.env("HOME") + p.substring(1)
        return p
    }
    function pickImage() { if (!pickProc.running) pickProc.running = true }

    // ------------------------------------------------------------------
    // Persistence — merge with SidePanel runtime fields
    // ------------------------------------------------------------------

    FileView {
        id: settingsFile
        path: page.stateDir + "/sidepanel-state.json"
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

    // ---- Notification background picture: file chooser (zenity or kdialog, whichever is installed) ----
    Process {
        id: pickProc
        command: ["sh", "-c",
            "if command -v zenity >/dev/null 2>&1; then "
            + "zenity --file-selection --title='Choose background picture' "
            + "--file-filter='Images | *.png *.jpg *.jpeg *.webp *.bmp *.gif' 2>/dev/null; "
            + "elif command -v kdialog >/dev/null 2>&1; then "
            + "kdialog --getopenfilename \"$HOME\" 'image/*' 2>/dev/null; "
            + "else echo 'no file chooser found (install zenity or kdialog), or type the path' >&2; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = page.cleanPath(text)
                if (p !== "") page.setMany({ notifBgPath: p, notifBgEnabled: true })
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) console.warn("[sidepanel] picture chooser:", text.trim())
        }
    }

    function loadSettings() {
        try {
            const j = JSON.parse(settingsFile.text())
            const o = {}
            for (const k of numKeys)
                if (typeof j[k] === "number") o[k] = j[k]
            for (const k of boolKeys)
                if (typeof j[k] === "boolean") o[k] = j[k]
            if (typeof j.accentSource === "string" && accentIds.indexOf(j.accentSource) >= 0)
                o.accentSource = j.accentSource
            if (j.panelSide === "left" || j.panelSide === "right")
                o.panelSide = j.panelSide
            if (typeof j.notifBgPath === "string") o.notifBgPath = j.notifBgPath
            if (Array.isArray(j.hidden))
                o.hidden = j.hidden.filter(n => allActions.some(a => a.name === n))
            if (Array.isArray(j.sectionOrder)) {
                const next = j.sectionOrder.filter(id => sectionIds.indexOf(id) >= 0)
                for (let i = 0; i < sectionIds.length; i++)
                    if (next.indexOf(sectionIds[i]) < 0) next.push(sectionIds[i])
                o.sectionOrder = next
            }
            s = o
            // keep runtime-only fields so we can write them back unchanged
            const rt = {}
            if (typeof j.dnd === "boolean") rt.dnd = j.dnd
            if (typeof j.night === "boolean") rt.night = j.night
            if (typeof j.nightTemp === "number") rt.nightTemp = j.nightTemp
            if (Array.isArray(j.collapsed)) rt.collapsed = j.collapsed
            runtime = rt
        } catch (error) {}
    }

    Timer {
        id: saveTimer
        interval: 150
        onTriggered: {
            page.selfWrite = true
            selfTimer.restart()
            try {
                const out = Object.assign({}, page.runtime, page.defaults, page.s)
                // SidePanel expects "hidden" as an array of action name strings
                if (!Array.isArray(out.hidden)) out.hidden = []
                settingsFile.setText(JSON.stringify(out, null, 2))
            } catch (error) {}
        }
    }

    // ignore the file-change echo of our own write
    Timer { id: selfTimer; interval: 600; onTriggered: page.selfWrite = false }

    // ------------------------------------------------------------------
    // Reusable inline components (same pattern as BarPage)
    // ------------------------------------------------------------------

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
        // shown instead of the number when value is 0 (e.g. "AUTO")
        property string zeroText: ""
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
            text: (sl.zeroText !== "" && sl.value === 0)
                  ? sl.zeroText
                  : (sl.value * sl.displayScale).toFixed(sl.decimals) + sl.unit
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
            preventStealing: true
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

    component BarChoice: Item {
        id: ch
        property string label: ""
        property var options: []
        property string current: ""
        property int maxCols: 4
        property var labels: ({})
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
            background: Rectangle { color: "transparent"; radius: width / 2 }
            contentItem: Rectangle { color: "transparent"; radius: width / 2 }
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
                    text: "SIDE PANEL"; color: Theme.text
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
            // ---------------- APPEARANCE ----------------
            Column {
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "APPEARANCE" }

                Card {
                    Cols {
                        BarSlider {
                            label: "SCALE"
                            from: page.numSpec.uiScale.min; to: page.numSpec.uiScale.max
                            step: page.numSpec.uiScale.step; unit: page.numSpec.uiScale.unit
                            value: page.val("uiScale")
                            onMoved: v => page.set("uiScale", v)
                        }
                        BarSlider {
                            label: "TEXT SIZE"
                            from: page.numSpec.textSize.min; to: page.numSpec.textSize.max
                            step: page.numSpec.textSize.step; unit: page.numSpec.textSize.unit
                            value: page.val("textSize")
                            onMoved: v => page.set("textSize", v)
                        }
                        BarSlider {
                            label: "WIDTH"
                            from: page.numSpec.panelWidth.min; to: page.numSpec.panelWidth.max
                            step: page.numSpec.panelWidth.step; unit: " " + page.numSpec.panelWidth.unit
                            value: page.val("panelWidth")
                            onMoved: v => page.set("panelWidth", v)
                        }
                        BarSlider {
                            label: "HEIGHT"
                            from: page.numSpec.panelHeight.min; to: page.numSpec.panelHeight.max
                            step: page.numSpec.panelHeight.step; unit: page.numSpec.panelHeight.unit
                            value: page.val("panelHeight")
                            onMoved: v => page.set("panelHeight", v)
                        }
                        BarSlider {
                            label: "ROUNDNESS"
                            from: page.numSpec.cornerRadius.min; to: page.numSpec.cornerRadius.max
                            step: page.numSpec.cornerRadius.step; unit: " " + page.numSpec.cornerRadius.unit
                            value: page.val("cornerRadius")
                            onMoved: v => page.set("cornerRadius", v)
                        }
                        BarSlider {
                            label: "BG OPACITY"
                            from: page.numSpec.bgOpacity.min; to: page.numSpec.bgOpacity.max
                            step: page.numSpec.bgOpacity.step; unit: page.numSpec.bgOpacity.unit
                            value: page.val("bgOpacity")
                            onMoved: v => page.set("bgOpacity", v)
                        }
                        BarSlider {
                            label: "BORDER OPACITY"
                            from: page.numSpec.borderOpacity.min
                            to: page.numSpec.borderOpacity.max
                            step: page.numSpec.borderOpacity.step
                            unit: page.numSpec.borderOpacity.unit
                            value: page.val("borderOpacity")
                            onMoved: v => page.set("borderOpacity", v)
                        }
                        BarSlider {
                            label: "TILT STRENGTH"
                            from: page.numSpec.tiltStrength.min; to: page.numSpec.tiltStrength.max
                            step: page.numSpec.tiltStrength.step; unit: page.numSpec.tiltStrength.unit
                            value: page.val("tiltStrength")
                            onMoved: v => page.set("tiltStrength", v)
                        }
                        BarSlider {
                            label: "ANIMATION"
                            from: page.numSpec.animMs.min; to: page.numSpec.animMs.max
                            step: page.numSpec.animMs.step; unit: page.numSpec.animMs.unit
                            value: page.val("animMs")
                            onMoved: v => page.set("animMs", v)
                        }
                    }

                    Divider {}

                    Cols {
                        ToggleRow {
                            label: "BORDER"; checked: page.val("border")
                            onToggled: v => page.set("border", v)
                        }
                        CycleChoice {
                            label: "HIGHLIGHT COLOR"
                            options: page.accentIds
                            labels: page.accentLabels
                            current: page.val("accentSource")
                            onPicked: v => page.set("accentSource", v)
                        }
                        BarChoice {
                            label: "PANEL SIDE (TOP / BOTTOM BAR)"
                            options: ["left", "right"]
                            maxCols: 2
                            current: page.val("panelSide")
                            onPicked: v => page.set("panelSide", v)
                        }
                    }
                }
            }

            // ---------------- CALENDAR ----------------
            Column {
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "CALENDAR" }

                Note {
                    visible: !page.val("showCalendar")
                    text: "Turn on CALENDAR under Sections to use these options."
                }

                Card {
                    enabled: page.val("showCalendar")
                    Cols {
                        cols: 3
                        ToggleRow {
                            label: "WEEK STARTS MONDAY"; checked: page.val("weekMonday")
                            onToggled: v => page.set("weekMonday", v)
                        }
                        ToggleRow {
                            label: "24-HOUR CLOCK"; checked: page.val("clock24")
                            onToggled: v => page.set("clock24", v)
                        }
                        ToggleRow {
                            label: "SHOW SECONDS"; checked: page.val("clockSeconds")
                            onToggled: v => page.set("clockSeconds", v)
                        }
                    }
                }
            }

            // ---------------- NOTIFICATIONS ----------------
            Column {
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "NOTIFICATIONS" }

                Note {
                    visible: !page.val("showNotifs")
                    text: "Turn on NOTIFICATIONS under Sections to use these options."
                }

                Card {
                    enabled: page.val("showNotifs")
                    Cols {
                        ToggleRow {
                            label: "POPUPS (TOASTS)"; checked: page.val("toasts")
                            onToggled: v => page.set("toasts", v)
                        }
                        ToggleRow {
                            label: "SOUND"; checked: page.val("soundEnabled")
                            onToggled: v => page.set("soundEnabled", v)
                        }
                        BarSlider {
                            label: "ENTRIES PER GROUP"
                            from: page.numSpec.groupLimit.min; to: page.numSpec.groupLimit.max
                            step: page.numSpec.groupLimit.step; unit: page.numSpec.groupLimit.unit
                            value: page.val("groupLimit")
                            onMoved: v => page.set("groupLimit", v)
                        }
                        BarSlider {
                            label: "LIST HEIGHT"
                            from: page.numSpec.notifsHeight.min; to: page.numSpec.notifsHeight.max
                            step: page.numSpec.notifsHeight.step; unit: " " + page.numSpec.notifsHeight.unit
                            zeroText: "AUTO"
                            value: page.val("notifsHeight")
                            onMoved: v => page.set("notifsHeight", v)
                        }
                    }

                    Divider {}

                    GroupLabel { text: "BACKGROUND IMAGE" }

                    Row {
                        width: parent.width; spacing: 6

                        SmallButton {
                            id: useBtn
                            width: 110
                            label: (page.val("notifBgEnabled") ? "● " : "○ ") + "USE PICTURE"
                            current: page.val("notifBgEnabled")
                            onClicked: page.set("notifBgEnabled", !page.val("notifBgEnabled"))
                        }

                        Rectangle {
                            width: parent.width - parent.spacing * 2 - useBtn.width - browseBtn.width
                            height: 26; radius: Theme.radius
                            color: "#00000000"; clip: true
                            border.width: 1
                            border.color: pathInput.activeFocus ? Theme.accent : Theme.border

                            TextInput {
                                id: pathInput
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true; selectByMouse: true
                                text: page.val("notifBgPath")
                                color: Theme.text
                                selectionColor: Theme.accent
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                                onEditingFinished: page.set("notifBgPath", page.cleanPath(text))
                            }

                            Text {
                                anchors.fill: parent; anchors.leftMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                visible: pathInput.text === "" && !pathInput.activeFocus
                                text: "/path/to/picture.jpg"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                            }
                        }

                        SmallButton {
                            id: browseBtn
                            width: 80
                            label: "BROWSE"
                            onClicked: page.pickImage()
                        }
                    }

                    Cols {
                        enabled: page.val("notifBgEnabled")
                        BarSlider {
                            label: "IMAGE OPACITY"
                            from: page.numSpec.notifBgOpacity.min; to: page.numSpec.notifBgOpacity.max
                            step: page.numSpec.notifBgOpacity.step; unit: page.numSpec.notifBgOpacity.unit
                            value: page.val("notifBgOpacity")
                            onMoved: v => page.set("notifBgOpacity", v)
                        }
                    }
                }
            }

            // ---------------- QUICK ACTIONS ----------------
            Column {
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "QUICK ACTIONS" }

                Note {
                    visible: !page.val("showQuick")
                    text: "Turn on QUICK ACTIONS under Sections to use these options."
                }

                Card {
                    enabled: page.val("showQuick")

                    Cols {
                        BarSlider {
                            label: "BRIGHTNESS STEP"
                            from: page.numSpec.brightnessStep.min; to: page.numSpec.brightnessStep.max
                            step: page.numSpec.brightnessStep.step; unit: page.numSpec.brightnessStep.unit
                            value: page.val("brightnessStep")
                            onMoved: v => page.set("brightnessStep", v)
                        }
                        BarSlider {
                            label: "NIGHT LIGHT STEP"
                            from: page.numSpec.nightStep.min; to: page.numSpec.nightStep.max
                            step: page.numSpec.nightStep.step; unit: page.numSpec.nightStep.unit
                            value: page.val("nightStep")
                            onMoved: v => page.set("nightStep", v)
                        }
                    }

                    Divider {}

                    GroupLabel { text: "VISIBLE TILES" }
                    Grid {
                        id: actGrid
                        width: parent.width
                        columns: 3
                        spacing: 6

                        Repeater {
                            model: page.allActions
                            delegate: SmallButton {
                                required property var modelData
                                width: Math.floor((actGrid.width - actGrid.spacing * 2) / 3)
                                label: modelData.label
                                current: page.isActionOn(modelData.name)
                                onClicked: page.setActionOn(modelData.name, !page.isActionOn(modelData.name))
                            }
                        }
                    }
                }
            }
            // ---------------- SECTIONS ----------------
            Column {
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "SECTIONS" }
                Note { text: "Toggle visibility and reorder with the arrows (top to bottom in the panel)." }

                Card {
                    Column {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: page.sectionOrder()
                            delegate: Row {
                                required property string modelData
                                required property int index
                                width: parent.width
                                spacing: 6
                                height: 26

                                // up / down
                                SmallButton {
                                    width: 28; height: 26
                                    label: "▲"
                                    buttonEnabled: index > 0
                                    onClicked: page.moveSection(modelData, -1)
                                }
                                SmallButton {
                                    width: 28; height: 26
                                    label: "▼"
                                    buttonEnabled: index < page.sectionOrder().length - 1
                                    onClicked: page.moveSection(modelData, 1)
                                }

                                // visibility toggle fills the rest
                                ToggleRow {
                                    width: parent.width - 28 * 2 - 6 * 2
                                    label: page.sectionLabels[modelData] ?? modelData.toUpperCase()
                                    checked: page.val(page.sectionBoolKey[modelData])
                                    onToggled: v => page.set(page.sectionBoolKey[modelData], v)
                                }
                            }
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