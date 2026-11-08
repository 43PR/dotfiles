import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 10
    property real marginTop: 0
    property real marginBottom: 0
    property real labelWidth: 200   // kept for compatibility with callers; no longer used internally

    // ---- Hub slider ranges ----
    readonly property real opacityMin: 0
    readonly property real opacityMax: 1.0
    readonly property real tiltMin: 0
    readonly property real tiltMax: 15
    readonly property real scaleMin: 0.6
    readonly property real scaleMax: 1.2
    readonly property real radiusMin: 0
    readonly property real radiusMax: 35
    // Border opacity stops at 10% so borders can't vanish completely by accident
    readonly property real borderOpacityMin: 0.1
    readonly property real borderOpacityMax: 1.0
    readonly property real blurAlphaCap: Math.max(0, round2(Theme.bgAlpha - 0.05))
    readonly property real effectiveBlurAlpha: Math.min(look.blurLayerAlpha, blurAlphaCap)

    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    function round2(v) { return Math.round(v * 100) / 100 }

    // ---- Performance state ----
    property string animationMode: "auto"     // "auto" | "on" | "off"
    property int lowBatteryPercent: 20
    property string effectsLevel: "moderate"   // "off" | "moderate" | "high"
    // When false, opacity.sh leaves the Quickshell components alone (read by the script)
    property bool qsOpacityFollow: true
    property string lastLua: ""

    // Battery + power profile come from UPower / power-profiles-daemon over D-Bus (event-driven).
    readonly property bool hasBattery: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
    // UPowerDevice.percentage is documented as energy / energyCapacity, i.e. 0..1.
    readonly property int batteryPercent: hasBattery ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property string batteryStatus: hasBattery ? UPowerDeviceState.toString(UPower.displayDevice.state) : ""

    function profileId(p) {
        if (p === PowerProfile.PowerSaver) return "power-saver"
        if (p === PowerProfile.Performance) return "performance"
        return "balanced"
    }

    readonly property string currentProfile: profileId(PowerProfiles.profile)
    readonly property var availableProfiles: PowerProfiles.hasPerformanceProfile
        ? ["power-saver", "balanced", "performance"]
        : ["power-saver", "balanced"]

    // ---- Persistence guards ----
    // Nothing is applied or written until the saved settings have been read,
    // so defaults can never overwrite what is on disk.
    property bool settingsReady: false
    property string lastSavedJson: ""
    property string lastSavedLua: ""

    // ---- Look & feel state (mirrors look.lua) ----
    readonly property var lookDefaults: ({
        expandUndersized: false,
        gapsIn: 4,
        gapsTop: 5,
        gapsRight: 8,
        gapsBottom: 8,
        gapsLeft: 8,
        borderSize: 0,
        resizeOnBorder: true,
        allowTearing: false,
        layout: "dwindle",
        rounding: 8,
        blurSize: 5,
        blurPasses: 1,
        blurVibrancy: 0.2,
        blurLayers: true,
        blurLayerAlpha: 0.1,
        shadowRange: 4,
        shadowPower: 3,
        speedWindows: 5,
        speedBorder: 5,
        speedFade: 4,
        speedWorkspaces: 6,
        workspaceStyle: "slidefadevert"
    })
    property var look: Object.assign({}, lookDefaults)

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"
    readonly property bool lowPower: currentProfile === "power-saver"
        || (hasBattery && batteryStatus === "Discharging" && batteryPercent <= lowBatteryPercent)
    readonly property bool animationsEnabled: animationMode === "on" || (animationMode === "auto" && !lowPower)

    // Option lists (ids) + display labels, used by BarChoice
    readonly property var animationOptions: ["off", "auto", "on"]
    readonly property var effectsOptions: ["off", "moderate", "high"]
    readonly property var profileOptions: ["power-saver", "balanced", "performance"]
    readonly property var layoutOptions: ["dwindle", "scrolling", "master"]
    readonly property var borderStyleOptions: ["full", "corner"]
    readonly property var workspaceStyleOptions: ["slide", "slidefade", "slidevert", "slidefadevert"]

    readonly property var profileLabels: ({ "power-saver": "POWER SAVER", balanced: "BALANCED", performance: "PERFORMANCE" })
    readonly property var workspaceStyleLabels: ({ slide: "SLIDE", slidefade: "FADE", slidevert: "VERT", slidefadevert: "VERT FADE" })

    // Profiles the system can't provide are shown dimmed instead of hidden
    readonly property var unavailableProfiles: profileOptions.filter(p => availableProfiles.indexOf(p) < 0)

    // ------------------------------------------------------------------
    // Lua generation
    // ------------------------------------------------------------------

    function luaString(value) { return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") }

    function luaKey(key) {
        return /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? key : "[\"" + luaString(key) + "\"]"
    }

    function luaValue(value, depth) {
        if (typeof value === "boolean") return value ? "true" : "false"
        if (typeof value === "number") return String(Number(value.toFixed(3)))
        if (Array.isArray(value)) {
            const items = []
            for (let i = 0; i < value.length; i++) items.push(luaValue(value[i], depth + 1))
            return "{ " + items.join(", ") + " }"
        }
        if (typeof value === "object" && value !== null) return luaTable(value, depth)
        return "\"" + luaString(value) + "\""
    }

    function luaTable(obj, depth) {
        const pad = "    ".repeat(depth + 1)
        const end = "    ".repeat(depth)
        const keys = Object.keys(obj)
        const parts = []
        for (let i = 0; i < keys.length; i++)
            parts.push(pad + luaKey(keys[i]) + " = " + luaValue(obj[keys[i]], depth + 1) + ",")
        return "{\n" + parts.join("\n") + "\n" + end + "}"
    }

    function animLine(leaf, speed, bezier, style) {
        let s = "hl.animation({ leaf = \"" + leaf + "\", enabled = true, speed = " + speed
            + ", bezier = \"" + bezier + "\""
        if (style) s += ", style = \"" + style + "\""
        return s + " })"
    }

    function lookStatements() {
        const l = look
        const fxOn = effectsLevel !== "off"
        const high = effectsLevel === "high"

        const cfg = {
            general: {
                gaps_in: l.gapsIn,
                gaps_out: { top: l.gapsTop, right: l.gapsRight, bottom: l.gapsBottom, left: l.gapsLeft },
                border_size: l.borderSize,
                resize_on_border: l.resizeOnBorder,
                allow_tearing: l.allowTearing,
                layout: l.layout
            },
            decoration: {
                rounding: l.rounding,
                blur: fxOn
                    ? { enabled: true, size: high ? l.blurSize + 4 : l.blurSize, passes: high ? l.blurPasses + 1 : l.blurPasses, vibrancy: l.blurVibrancy }
                    : { enabled: false },
                shadow: fxOn
                    ? { enabled: true, range: high ? l.shadowRange + 12 : l.shadowRange, render_power: l.shadowPower }
                    : { enabled: false }
            },
            animations: { enabled: animationsEnabled }
        }

        const stmts = []
        stmts.push("hl.config({ render = { expand_undersized_textures = " + (l.expandUndersized ? "true" : "false") + " } })")
        stmts.push("hl.config(" + luaTable(cfg, 0) + ")")
        stmts.push("hl.curve(\"easeOut\", { type = \"bezier\", points = { {0.05, 0.9}, {0.1, 1.0} } })")
        stmts.push(animLine("windows",    l.speedWindows,    "easeOut"))
        stmts.push(animLine("windowsOut", l.speedWindows,    "easeOut"))
        stmts.push(animLine("border",     l.speedBorder,     "default"))
        stmts.push(animLine("fade",       l.speedFade,       "default"))
        stmts.push(animLine("workspaces", l.speedWorkspaces, "default", l.workspaceStyle))
        const layerBlur = fxOn && l.blurLayers
        stmts.push("hl.layer_rule({ name = \"qs\", match = { namespace = \"^(quickshell|settings|notifications|powermenu|powermenu-settings|mediaosd|mediaosd-settings|recorder-osd|todo|wheel|colorpicker|colorpicker-editor)$\" }, blur = "
        + (layerBlur ? "true" : "false")
        + ", blur_popups = " + (layerBlur ? "true" : "false")
        + ", ignore_alpha = " + round2(effectiveBlurAlpha) + " })")
        return stmts
    }

    // Full file text for state/look.lua (pretty-printed, with header).
    // hyprland.lua loads this file at startup / reload so the look survives reboots.
    function lookLua() {
        const s = lookStatements()
        return "-- ---- LOOK AND FEEL ----\n\n" + s[0] + "\n" + s[1] + "\n\n" + s[2] + "\n\n" + s.slice(3).join("\n")
    }

    // One single-line statement per hyprctl call, same pattern as DisplayPage.
    // Never start an argument with "-" (hyprctl would read it as a flag), so no comments here.
    function evalCommand() {
        const cmds = lookStatements().map(s =>
            "hyprctl eval '" + s.replace(/\s*\n\s*/g, " ").replace(/'/g, "") + "'")
        return cmds.join("; ")
    }

    // ------------------------------------------------------------------
    // Power profile (D-Bus via PowerProfiles, no processes)
    // ------------------------------------------------------------------

    function setProfile(id) {
        if (id === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver
        else if (id === "balanced") PowerProfiles.profile = PowerProfile.Balanced
        else if (id === "performance" && PowerProfiles.hasPerformanceProfile)
            PowerProfiles.profile = PowerProfile.Performance
    }

    // Effective animation state depends on power state, so re-apply and re-persist
    // when it flips (e.g. battery drops below the threshold).
    onAnimationsEnabledChanged: {
        applyTimer.restart()
        saveTimer.restart()
    }

    // Background opacity affects the blur threshold cap.
    Connections {
        target: Theme
        function onBgAlphaChanged() {
            applyTimer.restart()
            saveTimer.restart()
        }
    }

    // ------------------------------------------------------------------
    // Apply / persist
    // ------------------------------------------------------------------

    FileView {
        id: settingsFile
        path: page.stateDir + "/performance.json"
        // Non-blocking: settings are applied from onLoaded / onLoadFailed.
        onLoaded: {
            if (!page.settingsReady) {
                page.loadSettings()
                page.markReady()
            }
        }
        // Missing file on first run is normal: start from defaults.
        onLoadFailed: error => page.markReady()
        onSaveFailed: error => page.lastSavedJson = ""
    }

    FileView {
        id: lookFile
        path: page.stateDir + "/look.lua"
        preload: false   // write-only
        onSaveFailed: error => page.lastSavedLua = ""
    }

    // Also needed by Theme.setHub(), which persists to state/hub.json.
    Process {
        id: stateDirProcess
        command: ["mkdir", "-p", page.stateDir]
    }

    Process {
        id: hyprApply
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t.length > 0 && t.split("\n").some(l => l.trim() !== "" && l.trim() !== "ok"))
                    console.log("[look] hyprctl:", t)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) console.warn("[look] hyprctl error:", text.trim())
        }
    }

    // ---- Background picture: file chooser (zenity or kdialog, whichever is installed) ----
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
                if (p !== "") {
                    Theme.setHub("bgImagePath", p)
                    Theme.setHub("bgImageEnabled", true)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) console.warn("[hub] picture chooser:", text.trim())
        }
    }

    function pickImage() {
        if (!pickProc.running) pickProc.running = true
    }

    // Accepts a typed/pasted path: trims whitespace and surrounding quotes,
    // turns file:// URLs into plain paths, expands a leading ~.
    function cleanPath(raw) {
        let p = String(raw).trim().replace(/^["']|["']$/g, "")
        if (p.indexOf("file://") === 0) p = decodeURIComponent(p.substring(7))
        if (p === "~" || p.indexOf("~/") === 0) p = Quickshell.env("HOME") + p.substring(1)
        return p
    }

    function markReady() {
        if (settingsReady) return
        settingsReady = true
        applyTimer.restart()
    }

    function applyLook() {
        if (!settingsReady) return
        if (hyprApply.running) { applyTimer.restart(); return }
        const cmd = evalCommand()
        if (cmd === lastLua) return
        lastLua = cmd
        hyprApply.command = ["sh", "-c", cmd]
        hyprApply.running = true
    }

    function loadSettings() {
        try {
            const saved = JSON.parse(settingsFile.text())
            if (["auto", "on", "off"].indexOf(saved.animations) !== -1) animationMode = saved.animations
            if (["off", "moderate", "high"].indexOf(saved.effects) !== -1) effectsLevel = saved.effects
            if (typeof saved.qsOpacityFollow === "boolean") qsOpacityFollow = saved.qsOpacityFollow

            if (saved.look && typeof saved.look === "object") {
                const n = Object.assign({}, lookDefaults)
                const keys = Object.keys(n)
                for (let i = 0; i < keys.length; i++) {
                    const k = keys[i]
                    if (saved.look[k] !== undefined && typeof saved.look[k] === typeof n[k])
                        n[k] = saved.look[k]
                }
                if (["dwindle", "scrolling", "master"].indexOf(n.layout) === -1) n.layout = lookDefaults.layout
                if (["slide", "slidefade", "slidevert", "slidefadevert"].indexOf(n.workspaceStyle) === -1)
                    n.workspaceStyle = lookDefaults.workspaceStyle
                look = n
            }
        } catch (error) {
            console.warn("[look] could not parse performance.json, using defaults:", error)
        }
    }

    function setAnimationMode(mode) {
        animationMode = mode
        saveTimer.restart()
        applyTimer.restart()
    }

    function setEffectsLevel(level) {
        effectsLevel = level
        saveTimer.restart()
        applyTimer.restart()
    }

    function setQsOpacityFollow(v) {
        qsOpacityFollow = v
        saveTimer.restart()
    }

    function setLook(key, value) {
        if (look[key] === value) return
        const n = Object.assign({}, look)
        n[key] = value
        look = n
        saveTimer.restart()
        applyTimer.restart()
    }

    function resetLook() {
        look = Object.assign({}, lookDefaults)
        saveTimer.restart()
        applyTimer.restart()
    }

    // Writes performance.json (UI state) and look.lua (read by Hyprland at boot/reload).
    // Skips writes whose content has not changed.
    function persist() {
        if (!settingsReady) return

        const json = JSON.stringify({
            animations: animationMode,
            effects: effectsLevel,
            qsOpacityFollow: qsOpacityFollow,
            look: look
        }, null, 2)
        if (json !== lastSavedJson) {
            lastSavedJson = json
            settingsFile.setText(json)
        }

        const lua = lookLua() + "\n"
        if (lua !== lastSavedLua) {
            lastSavedLua = lua
            lookFile.setText(lua)
        }
    }

    Timer { id: applyTimer; interval: 250; onTriggered: page.applyLook() }
    Timer { id: saveTimer; interval: 300; onTriggered: page.persist() }

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
    // Reusable inline components (same pattern as BarPage)
    //
    // Controls size themselves from their parent: inside a `Cols` grid they
    // take one cell (parent.cellWidth), anywhere else they take the full width.
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
        signal toggled(bool v)

        width: parent.cellWidth ?? parent.width
        height: 26
        opacity: enabled ? 1.0 : 0.4

        SmallButton {
            width: tg.width; height: tg.height
            label: (tg.checked ? "● " : "○ ") + tg.label
            current: tg.checked
            buttonEnabled: tg.enabled
            onClicked: tg.toggled(!tg.checked)
        }
    }

    // Label + value on one line, drag track right below.
    //   moved     = live value while dragging (only emitted when the value actually changes)
    //   committed = emitted once on release, with the final value (use to persist)
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
        property bool dragging: false
        signal moved(real v)
        signal committed(real v)

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
                const raw = sl.from + r * (sl.to - sl.from)
                const v = sl.step > 0 ? +(Math.round(raw / sl.step) * sl.step).toFixed(4) : raw
                if (v !== sl.value) sl.moved(v)
            }
            onPressed: m => { sl.dragging = true; apply(m.x) }
            onPositionChanged: m => { if (pressed) apply(m.x) }
            onReleased: { if (sl.dragging) { sl.dragging = false; sl.committed(sl.value) } }
            onCanceled: sl.dragging = false
        }
    }

    // Label on top, one button per option side by side (wraps after `maxCols`).
    component BarChoice: Item {
        id: ch
        property string label: ""
        property var options: []
        property string current: ""
        property int maxCols: 4
        property var labels: ({})          // optional id → display text (default: id in upper case)
        property var disabledOptions: []   // ids shown dimmed and not clickable
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
                    buttonEnabled: ch.enabled && ch.disabledOptions.indexOf(modelData) < 0
                    onClicked: ch.picked(modelData)
                }
            }
        }
    }

    // Header row of a section: title on the left, optional action button on the right.
    component SectionHeader: Item {
        id: sh
        property string title: ""
        property string actionLabel: ""
        signal action()
        width: parent.width
        height: 22

        SectionTitle {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: sh.title
        }
        SmallButton {
            visible: sh.actionLabel !== ""
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 80; height: 22
            label: sh.actionLabel
            onClicked: sh.action()
        }
    }

    // ------------------------------------------------------------------
    // UI
    //
    // Sections:
    //   Performance · Windows & gaps · Blur & shadows · Animations · Hub · Background image
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

            // ---------------- TITLE + QUICK JUMP ----------------
            Item {
                width: parent.width; height: 26

                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "APPEARANCE"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeTitle; font.letterSpacing: 3
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------- PERFORMANCE ----------------
            Column {
                id: secPerf
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "PERFORMANCE" }

                Card {
                    Cols {
                        BarChoice {
                            label: "ANIMATIONS"
                            options: page.animationOptions
                            current: page.animationMode
                            onPicked: v => page.setAnimationMode(v)
                        }
                        BarChoice {
                            label: "BLUR & SHADOWS"
                            options: page.effectsOptions
                            current: page.effectsLevel
                            onPicked: v => page.setEffectsLevel(v)
                        }
                    }

                    BarChoice {
                        label: "POWER PROFILE"
                        options: page.profileOptions
                        labels: page.profileLabels
                        disabledOptions: page.unavailableProfiles
                        current: page.currentProfile
                        onPicked: v => page.setProfile(v)
                    }
                }
            }

            // ---------------- WINDOWS & GAPS ----------------
            Column {
                id: secWindows
                width: parent.width; spacing: 6
                topPadding: 2

                SectionHeader {
                    title: "WINDOWS & GAPS"
                    actionLabel: "RESET"
                    onAction: page.resetLook()
                }

                Card {
                    GroupLabel { text: "GAPS" }
                    Cols {
                        BarSlider {
                            label: "INNER"
                            from: 0; to: 40; step: 1; unit: " px"
                            value: page.look.gapsIn
                            onMoved: v => page.setLook("gapsIn", v)
                        }
                        BarSlider {
                            label: "OUTER TOP"
                            from: 0; to: 60; step: 1; unit: " px"
                            value: page.look.gapsTop
                            onMoved: v => page.setLook("gapsTop", v)
                        }
                        BarSlider {
                            label: "OUTER RIGHT"
                            from: 0; to: 60; step: 1; unit: " px"
                            value: page.look.gapsRight
                            onMoved: v => page.setLook("gapsRight", v)
                        }
                        BarSlider {
                            label: "OUTER BOTTOM"
                            from: 0; to: 60; step: 1; unit: " px"
                            value: page.look.gapsBottom
                            onMoved: v => page.setLook("gapsBottom", v)
                        }
                        BarSlider {
                            label: "OUTER LEFT"
                            from: 0; to: 60; step: 1; unit: " px"
                            value: page.look.gapsLeft
                            onMoved: v => page.setLook("gapsLeft", v)
                        }
                    }

                    Divider {}

                    GroupLabel { text: "WINDOWS" }
                    Cols {
                        BarSlider {
                            label: "BORDER SIZE"
                            from: 0; to: 8; step: 1; unit: " px"
                            value: page.look.borderSize
                            onMoved: v => page.setLook("borderSize", v)
                        }
                        BarSlider {
                            label: "ROUNDING"
                            from: 0; to: 30; step: 1; unit: " px"
                            value: page.look.rounding
                            onMoved: v => page.setLook("rounding", v)
                        }
                        BarSlider {
                            label: "ACCENT COLOR OPACITY"
                            from: page.borderOpacityMin; to: page.borderOpacityMax; step: 0.05
                            unit: "%"; displayScale: 100
                            value: Theme.borderOpacity
                            onMoved: v => Theme.borderOpacity = v
                            onCommitted: v => Theme.setHub("borderOpacity", page.round2(v))
                        }
                        BarChoice {
                            label: "BORDER STYLE"
                            enabled: page.look.borderSize > 0
                            options: page.borderStyleOptions
                            current: Theme.hyprBorderStyle
                            onPicked: v => Theme.setHub("hyprBorderStyle", v)
                        }
                    }
                    Note {
                        visible: page.look.borderSize === 0
                        text: "Set BORDER SIZE above 0 to see the border style and accent opacity."
                    }

                    Cols {
                        cols: 3
                        ToggleRow {
                            label: "RESIZE ON BORDER"; checked: page.look.resizeOnBorder
                            onToggled: v => page.setLook("resizeOnBorder", v)
                        }
                        ToggleRow {
                            label: "ALLOW TEARING"; checked: page.look.allowTearing
                            onToggled: v => page.setLook("allowTearing", v)
                        }
                        ToggleRow {
                            label: "EXPAND TEXTURES"; checked: page.look.expandUndersized
                            onToggled: v => page.setLook("expandUndersized", v)
                        }
                    }

                    BarChoice {
                        label: "LAYOUT"
                        options: page.layoutOptions
                        current: page.look.layout
                        onPicked: v => page.setLook("layout", v)
                    }
                }
            }

            // ---------------- BLUR & SHADOWS ----------------
            Column {
                id: secBlur
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "BLUR & SHADOWS" }

                Note {
                    visible: page.effectsLevel === "off"
                    text: "Blur and shadows are switched off in PERFORMANCE; these options apply once they are on."
                }

                Card {
                    Cols {
                        enabled: page.effectsLevel !== "off"

                        BarSlider {
                            label: "BLUR SIZE"
                            from: 1; to: 20; step: 1
                            value: page.look.blurSize
                            onMoved: v => page.setLook("blurSize", v)
                        }
                        BarSlider {
                            label: "BLUR PASSES"
                            from: 1; to: 6; step: 1
                            value: page.look.blurPasses
                            onMoved: v => page.setLook("blurPasses", v)
                        }
                        BarSlider {
                            label: "VIBRANCY"
                            from: 0; to: 1; step: 0.05; decimals: 2
                            value: page.look.blurVibrancy
                            onMoved: v => page.setLook("blurVibrancy", v)
                        }
                        BarSlider {
                            label: "SHADOW RANGE"
                            from: 0; to: 50; step: 1
                            value: page.look.shadowRange
                            onMoved: v => page.setLook("shadowRange", v)
                        }
                        BarSlider {
                            label: "SHADOW POWER"
                            from: 1; to: 4; step: 1
                            value: page.look.shadowPower
                            onMoved: v => page.setLook("shadowPower", v)
                        }
                    }

                    Divider {}

                    Cols {
                        enabled: page.effectsLevel !== "off"

                        ToggleRow {
                            label: "BLUR PANELS"; checked: page.look.blurLayers
                            onToggled: v => page.setLook("blurLayers", v)
                        }
                        BarSlider {
                            label: "PANEL BLUR THRESHOLD"
                            enabled: page.look.blurLayers
                            from: 0; to: page.blurAlphaCap; step: 0.05; decimals: 2
                            value: page.effectiveBlurAlpha
                            onMoved: v => page.setLook("blurLayerAlpha", v)
                        }
                    }
                }
            }

            // ---------------- ANIMATIONS ----------------
            Column {
                id: secAnim
                width: parent.width; spacing: 6
                topPadding: 2

                SectionTitle { text: "ANIMATIONS & SPEED" }

                Card {
                    Cols {
                        BarSlider {
                            label: "WINDOWS"
                            from: 1; to: 20; step: 1
                            value: page.look.speedWindows
                            onMoved: v => page.setLook("speedWindows", v)
                        }
                        BarSlider {
                            label: "BORDER"
                            from: 1; to: 20; step: 1
                            value: page.look.speedBorder
                            onMoved: v => page.setLook("speedBorder", v)
                        }
                        BarSlider {
                            label: "FADE"
                            from: 1; to: 20; step: 1
                            value: page.look.speedFade
                            onMoved: v => page.setLook("speedFade", v)
                        }
                        BarSlider {
                            label: "WORKSPACES"
                            from: 1; to: 20; step: 1
                            value: page.look.speedWorkspaces
                            onMoved: v => page.setLook("speedWorkspaces", v)
                        }
                    }

                    BarChoice {
                        label: "WORKSPACE STYLE"
                        options: page.workspaceStyleOptions
                        labels: page.workspaceStyleLabels
                        current: page.look.workspaceStyle
                        onPicked: v => page.setLook("workspaceStyle", v)
                    }
                }
            }

            // ---------------- HUB ----------------
            Column {
                id: secHub
                width: parent.width; spacing: 6
                topPadding: 2

                SectionHeader {
                    title: "HUB"
                    actionLabel: "RESET"
                    onAction: Theme.resetHub()
                }

                Card {
                    Cols {
                        BarSlider {
                            label: "BACKGROUND OPACITY"
                            from: page.opacityMin; to: page.opacityMax; step: 0.01
                            unit: "%"; displayScale: 100
                            value: Theme.bgAlpha
                            onMoved: v => Theme.bgAlpha = v
                            onCommitted: v => Theme.setHub("bgAlpha", page.round2(v))
                        }
                        BarSlider {
                            label: "CORNER RADIUS"
                            from: page.radiusMin; to: page.radiusMax; step: 1; unit: " px"
                            value: Theme.radius
                            onMoved: v => Theme.radius = Math.round(v)
                            onCommitted: v => Theme.setHub("radius", Math.round(v))
                        }
                        BarSlider {
                            label: "TILT STRENGTH"
                            from: page.tiltMin; to: page.tiltMax; step: 0.1; decimals: 1
                            value: Theme.tiltStrength
                            onMoved: v => Theme.tiltStrength = v
                            onCommitted: v => Theme.setHub("tiltStrength", page.round2(v))
                        }
                        BarSlider {
                            label: "WINDOW SCALE"
                            from: page.scaleMin; to: page.scaleMax; step: 0.05
                            unit: "%"; displayScale: 100
                            value: Theme.settingsScale
                            onMoved: v => Theme.settingsScale = page.round2(v)
                            onCommitted: v => Theme.setHub("settingsScale", page.round2(v))
                        }
                    }

                    ToggleRow {
                        label: "SYNC OPACITY SCRIPT"; checked: page.qsOpacityFollow
                        onToggled: v => page.setQsOpacityFollow(v)
                    }
                }
            }

            // ---------------- BACKGROUND IMAGE ----------------
            Column {
                id: secImage
                width: parent.width; spacing: 6
                topPadding: 2
                bottomPadding: 6

                SectionTitle { text: "BACKGROUND IMAGE" }

                Note {
                    visible: Theme.bgAlpha > 0.9
                    text: "Lower BACKGROUND OPACITY in HUB to see the picture."
                }

                Card {
                    Row {
                        width: parent.width; spacing: 6

                        SmallButton {
                            id: useBtn
                            width: 110
                            label: (Theme.bgImageEnabled ? "● " : "○ ") + "USE PICTURE"
                            current: Theme.bgImageEnabled
                            onClicked: Theme.setHub("bgImageEnabled", !Theme.bgImageEnabled)
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
                                text: Theme.bgImagePath
                                color: Theme.text
                                selectionColor: Theme.accent
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                                onEditingFinished: Theme.setHub("bgImagePath", page.cleanPath(text))
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
                        enabled: Theme.bgImageEnabled

                        BarSlider {
                            label: "IMAGE OPACITY"
                            from: 0; to: 1; step: 0.01; unit: "%"; displayScale: 100
                            value: Theme.bgImageOpacity
                            onMoved: v => Theme.bgImageOpacity = v
                            onCommitted: v => Theme.setHub("bgImageOpacity", page.round2(v))
                        }
                        BarSlider {
                            label: "IMAGE BLUR"
                            from: 0; to: 1; step: 0.01; unit: "%"; displayScale: 100
                            value: Theme.bgImageBlur
                            onMoved: v => Theme.bgImageBlur = v
                            onCommitted: v => Theme.setHub("bgImageBlur", page.round2(v))
                        }
                        BarSlider {
                            label: "FADE: TOP OPACITY"
                            from: 0; to: 1; step: 0.01; unit: "%"; displayScale: 100
                            value: Theme.bgImageFadeTop
                            onMoved: v => Theme.bgImageFadeTop = v
                            onCommitted: v => Theme.setHub("bgImageFadeTop", page.round2(v))
                        }
                        BarSlider {
                            label: "FADE: BOTTOM OPACITY"
                            from: 0; to: 1; step: 0.01; unit: "%"; displayScale: 100
                            value: Theme.bgImageFadeBottom
                            onMoved: v => Theme.bgImageFadeBottom = v
                            onCommitted: v => Theme.setHub("bgImageFadeBottom", page.round2(v))
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: stateDirProcess.running = true
}