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
    property real labelWidth: 200

    // ---- Hub slider ranges (opacity stops at 20% so the window can't become invisible) ----
    readonly property real opacityMin: 0.2
    readonly property real opacityMax: 1.0
    readonly property real tiltMin: 0
    readonly property real tiltMax: 15
    readonly property real radiusMin: 0
    readonly property real radiusMax: 35
    // Border opacity stops at 10% so borders can't vanish completely by accident
    readonly property real borderOpacityMin: 0.1
    readonly property real borderOpacityMax: 1.0
    // Quickshell component corner-arm length range (px)
    readonly property real blurAlphaCap: Math.max(0, round2(Theme.bgAlpha - 0.05))
    readonly property real effectiveBlurAlpha: Math.min(look.blurLayerAlpha, blurAlphaCap)

    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    function round2(v) { return Math.round(v * 100) / 100 }

    // ---- Performance state ----
    property string animationMode: "auto"     // "auto" | "on" | "off"
    property int lowBatteryPercent: 20
    property string effectsLevel: "moderate"   // "off" | "moderate" | "high"
    property string lastLua: ""

    // Battery + power profile come from UPower / power-profiles-daemon over D-Bus
    // (event-driven). This replaces the old 5 s `sh -c cat ...` poll and the
    // powerprofilesctl get/list/set processes.
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

    readonly property var animationOptions: [
        { id: "off",  label: "OFF" },
        { id: "auto", label: "AUTO" },
        { id: "on",   label: "ON" }
    ]

    readonly property var profiles: [
        { id: "power-saver", label: "POWER SAVER" },
        { id: "balanced",    label: "BALANCED" },
        { id: "performance", label: "PERFORMANCE" }
    ]

    function profileLabel(id) {
        for (let i = 0; i < profiles.length; i++)
            if (profiles[i].id === id) return profiles[i].label
        return id.toUpperCase()
    }
    readonly property var effectsOptions: [
        { id: "off",      label: "OFF" },
        { id: "moderate", label: "MODERATE" },
        { id: "high",     label: "HIGH" }
    ]

    readonly property var layoutOptions: [
        { id: "dwindle", label: "DWINDLE" },
        { id: "scrolling", label: "SCROLLING" },
        { id: "master",  label: "MASTER" }
    ]

    readonly property var borderStyleOptions: [
        { id: "full",   label: "FULL" },
        { id: "corner", label: "CORNER" }
    ]

    readonly property var workspaceStyleOptions: [
        { id: "slide",         label: "SLIDE" },
        { id: "slidefade",     label: "FADE" },
        { id: "slidevert",     label: "VERT" },
        { id: "slidefadevert", label: "VERT FADE" }
    ]

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

    // Background opacity affects the blur threshold cap; border opacity and the
    // palette colours feed directly into the Hyprland border colours.
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
            onStreamFinished: if (text.trim().length > 0 && text.trim() !== "ok") console.log("[look] hyprctl:", text.trim())
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) console.warn("[look] hyprctl error:", text.trim())
        }
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

            if (saved.look && typeof saved.look === "object") {
                const n = Object.assign({}, lookDefaults)
                const keys = Object.keys(n)
                for (let i = 0; i < keys.length; i++) {
                    const k = keys[i]
                    if (saved.look[k] !== undefined && typeof saved.look[k] === typeof n[k])
                        n[k] = saved.look[k]
                }
                // (the old two-value layout check that reset "scrolling" to dwindle was removed)
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

    function setLook(key, value) {
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
            text: sb.label
            color: sb.current ? Theme.accentSolid : Theme.text
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

    component OptionRow: Row {
        id: optRow
        property var options: []
        property string currentId: ""
        signal picked(string id)
        width: parent.width; spacing: 8

        Repeater {
            model: optRow.options

            delegate: SmallButton {
                required property var modelData
                width: (optRow.width - optRow.spacing * (optRow.options.length - 1)) / optRow.options.length
                label: modelData.label
                current: optRow.currentId === modelData.id
                onClicked: optRow.picked(modelData.id)
            }
        }
    }

    component Stepper: Item {
        id: st
        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 100
        property real step: 1
        property int decimals: 0
        property string suffix: ""
        signal moved(real v)

        width: parent.width; height: 28

        function nudge(delta) {
            const v = Math.max(from, Math.min(to, value + delta))
            moved(Number(v.toFixed(Math.max(decimals, 2))))
        }

        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: st.label
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
        }

        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            SmallButton {
                width: 28; label: "−"
                buttonEnabled: st.value > st.from
                onClicked: st.nudge(-st.step)
            }

            Text {
                width: 54
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: st.value.toFixed(st.decimals) + st.suffix
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup
            }

            SmallButton {
                width: 28; label: "+"
                buttonEnabled: st.value < st.to
                onClicked: st.nudge(st.step)
            }
        }
    }

    component ToggleRow: Item {
        id: tg
        property string label: ""
        property bool checked: false
        signal toggled(bool v)

        width: parent.width; height: 28

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
            onClicked: tg.toggled(!tg.checked)
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
                text: "APPEARANCE"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeTitle; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------- PERFORMANCE ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                SectionTitle { text: "PERFORMANCE" }

                Card {
                    Column {
                        width: parent.width; spacing: 8

                        Row {
                            spacing: 10
                            GroupLabel { text: "ANIMATIONS" }
                        }

                        OptionRow {
                            options: page.animationOptions
                            currentId: page.animationMode
                            onPicked: id => page.setAnimationMode(id)
                        }
                    }
                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "BLUR & SHADOWS" }

                        OptionRow {
                            options: page.effectsOptions
                            currentId: page.effectsLevel
                            onPicked: id => page.setEffectsLevel(id)
                        }
                    }
                    Column {
                        width: parent.width; spacing: 8

                        Row {
                            spacing: 10
                            GroupLabel { text: "POWER PROFILE" }
                        }

                        Row {
                            id: profRow
                            width: parent.width; spacing: 8

                            Repeater {
                                model: page.profiles

                                delegate: SmallButton {
                                    required property var modelData
                                    width: (profRow.width - profRow.spacing * (page.profiles.length - 1)) / page.profiles.length
                                    label: modelData.label
                                    current: page.currentProfile === modelData.id
                                    buttonEnabled: page.availableProfiles.indexOf(modelData.id) !== -1
                                    onClicked: page.setProfile(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
            // ---------------- LOOK & FEEL ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6
                bottomPadding: 6

                Item {
                    width: parent.width; height: 24

                    SectionTitle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "LOOK & FEEL"
                    }

                    SmallButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 90; height: 24
                        label: "RESET"
                        onClicked: page.resetLook()
                    }
                }

                // ---- Gaps ----
                Card {
                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "GAPS" }

                        Stepper {
                            label: "INNER"; value: page.look.gapsIn; from: 0; to: 40
                            onMoved: v => page.setLook("gapsIn", v)
                        }
                        Stepper {
                            label: "OUTER TOP"; value: page.look.gapsTop; from: 0; to: 60
                            onMoved: v => page.setLook("gapsTop", v)
                        }
                        Stepper {
                            label: "OUTER RIGHT"; value: page.look.gapsRight; from: 0; to: 60
                            onMoved: v => page.setLook("gapsRight", v)
                        }
                        Stepper {
                            label: "OUTER BOTTOM"; value: page.look.gapsBottom; from: 0; to: 60
                            onMoved: v => page.setLook("gapsBottom", v)
                        }
                        Stepper {
                            label: "OUTER LEFT"; value: page.look.gapsLeft; from: 0; to: 60
                            onMoved: v => page.setLook("gapsLeft", v)
                        }
                    }
                }

                // ---- Windows ----
                Card {
                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "WINDOWS" }

                        Stepper {
                            label: "BORDER SIZE"; value: page.look.borderSize; from: 0; to: 8
                            onMoved: v => page.setLook("borderSize", v)
                        }
                        Stepper {
                            label: "ROUNDING"; value: page.look.rounding; from: 0; to: 30
                            onMoved: v => page.setLook("rounding", v)
                        }
                        ToggleRow {
                            label: "RESIZE ON BORDER"; checked: page.look.resizeOnBorder
                            onToggled: v => page.setLook("resizeOnBorder", v)
                        }
                        ToggleRow {
                            label: "ALLOW TEARING"; checked: page.look.allowTearing
                            onToggled: v => page.setLook("allowTearing", v)
                        }
                        ToggleRow {
                            label: "EXPAND UNDERSIZED TEXTURES"; checked: page.look.expandUndersized
                            onToggled: v => page.setLook("expandUndersized", v)
                        }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "LAYOUT" }

                        OptionRow {
                            options: page.layoutOptions
                            currentId: page.look.layout
                            onPicked: id => page.setLook("layout", id)
                        }
                    }
                }

                // ---- Borders (style + global opacity) ----
                Card {
                    Column {
                        width: parent.width; spacing: 8

                        Row {
                            spacing: 10
                            GroupLabel { text: "BORDER STYLE" }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: page.look.borderSize === 0
                                text: "SET BORDER SIZE > 0 TO SEE IT"
                                color: Theme.textDim
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
                            }
                        }

                        OptionRow {
                            options: page.borderStyleOptions
                            currentId: Theme.hyprBorderStyle
                            onPicked: id => Theme.setHub("hyprBorderStyle", id)
                        }
                    }

                    // ---- global border opacity (Hyprland borders + Theme.accent) ----
                    Row {
                        width: parent.width; spacing: 8

                        Text {
                            width: page.labelWidth
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ACCENT COLOR OPACITY"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                        }

                        Slider {
                            width: parent.width - page.labelWidth - 52 - 16
                            anchors.verticalCenter: parent.verticalCenter
                            label: ""; icon: ""
                            value: page.clamp01((Theme.borderOpacity - page.borderOpacityMin) / (page.borderOpacityMax - page.borderOpacityMin))
                            onMoved: value => Theme.borderOpacity = page.borderOpacityMin + page.clamp01(value) * (page.borderOpacityMax - page.borderOpacityMin)
                            onCommitted: value => Theme.setHub("borderOpacity", page.round2(page.borderOpacityMin + page.clamp01(value) * (page.borderOpacityMax - page.borderOpacityMin)))
                        }

                        Text {
                            width: 52
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(Theme.borderOpacity * 100) + "%"
                            color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                        }
                    }
                }
            // ---------------- HUB ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                Item {
                    width: parent.width;
                    height: 24
                    y: -6
                    SectionTitle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "HUB"
                    }

                    SmallButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 90; height: 24
                        label: "RESET"
                        onClicked: Theme.resetHub()
                    }
                }

                Card {
                    Column {
                        width: parent.width; spacing: 6
                        ToggleRow {
                            label: "BLUR PANELS"; checked: page.look.blurLayers
                            onToggled: v => page.setLook("blurLayers", v)
                        }
                        Stepper {
                            label: "PANEL BLUR THRESHOLD"; value: page.effectiveBlurAlpha
                            from: 0; to: page.blurAlphaCap; step: 0.05; decimals: 2
                            onMoved: v => page.setLook("blurLayerAlpha", v)
                        }
                        // ---- background opacity ----
                        Row {
                            width: parent.width; spacing: 8

                            Text {
                                width: page.labelWidth
                                anchors.verticalCenter: parent.verticalCenter
                                text: "BACKGROUND OPACITY"; color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                            }

                            Slider {
                                width: parent.width - page.labelWidth - 52 - 16
                                anchors.verticalCenter: parent.verticalCenter
                                label: ""; icon: ""
                                value: page.clamp01((Theme.bgAlpha - page.opacityMin) / (page.opacityMax - page.opacityMin))
                                onMoved: value => Theme.bgAlpha = page.opacityMin + page.clamp01(value) * (page.opacityMax - page.opacityMin)
                                onCommitted: value => Theme.setHub("bgAlpha", page.round2(page.opacityMin + page.clamp01(value) * (page.opacityMax - page.opacityMin)))
                            }

                            Text {
                                width: 52
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(Theme.bgAlpha * 100) + "%"
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                            }
                        }

                        // ---- corner radius ----
                        Row {
                            width: parent.width; spacing: 8

                            Text {
                                width: page.labelWidth
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CORNER RADIUS"; color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                            }

                            Slider {
                                width: parent.width - page.labelWidth - 52 - 16
                                anchors.verticalCenter: parent.verticalCenter
                                label: ""; icon: ""
                                value: page.clamp01((Theme.radius - page.radiusMin) / (page.radiusMax - page.radiusMin))
                                onMoved: value => Theme.radius = Math.round(page.radiusMin + page.clamp01(value) * (page.radiusMax - page.radiusMin))
                                onCommitted: value => Theme.setHub("radius", Math.round(page.radiusMin + page.clamp01(value) * (page.radiusMax - page.radiusMin)))
                            }

                            Text {
                                width: 52
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(Theme.radius) + "px"
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                            }
                        }

                        // ---- tilt strength ----
                        Row {
                            width: parent.width; spacing: 8

                            Text {
                                width: page.labelWidth
                                anchors.verticalCenter: parent.verticalCenter
                                text: "TILT STRENGTH"; color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                            }

                            Slider {
                                width: parent.width - page.labelWidth - 52 - 16
                                anchors.verticalCenter: parent.verticalCenter
                                label: ""; icon: ""
                                value: page.clamp01((Theme.tiltStrength - page.tiltMin) / (page.tiltMax - page.tiltMin))
                                onMoved: value => Theme.tiltStrength = page.tiltMin + page.clamp01(value) * (page.tiltMax - page.tiltMin)
                                onCommitted: value => Theme.setHub("tiltStrength", page.round2(page.tiltMin + page.clamp01(value) * (page.tiltMax - page.tiltMin)))
                            }

                            Text {
                                width: 52
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: Theme.tiltStrength.toFixed(1)
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                            }
                        }

                        // ---- click outside closes ----
                        Row {
                            width: parent.width
                            spacing: 16
                            // Close on outside click
                            Row {
                                height: 28
                                spacing: 8

                                Text {
                                    width: 176
                                    height: 28
                                    verticalAlignment: Text.AlignVCenter
                                    text: "CLOSE ON OUTSIDE CLICK"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.textSizeBody
                                }

                                Rectangle {
                                    width: 64
                                    height: 28
                                    radius: Theme.radius

                                    color: Theme.clickOutsideClose
                                        ? Theme.alpha(Theme.accent, 0.10)
                                        : (outsideMouse.containsMouse
                                           ? Theme.alpha(Theme.accent, 0.08)
                                           : "#00000000")

                                    border.width: 1
                                    border.color: Theme.clickOutsideClose
                                        || outsideMouse.containsMouse
                                        ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.clickOutsideClose ? "ON" : "OFF"
                                        color: Theme.clickOutsideClose
                                            ? Theme.accentSolid : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.textSizeBody
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }

                                    MouseArea {
                                        id: outsideMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Theme.setHub(
                                            "clickOutsideClose",
                                            !Theme.clickOutsideClose
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
                // ---- Blur & Shadow ----
                Card {
                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "BLUR" }

                        Stepper {
                            label: "SIZE"; value: page.look.blurSize; from: 1; to: 20
                            onMoved: v => page.setLook("blurSize", v)
                        }
                        Stepper {
                            label: "PASSES"; value: page.look.blurPasses; from: 1; to: 6
                            onMoved: v => page.setLook("blurPasses", v)
                        }
                        Stepper {
                            label: "VIBRANCY"; value: page.look.blurVibrancy; from: 0; to: 1
                            step: 0.05; decimals: 2
                            onMoved: v => page.setLook("blurVibrancy", v)
                        }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "SHADOW" }

                        Stepper {
                            label: "RANGE"; value: page.look.shadowRange; from: 0; to: 50
                            onMoved: v => page.setLook("shadowRange", v)
                        }
                        Stepper {
                            label: "RENDER POWER"; value: page.look.shadowPower; from: 1; to: 4
                            onMoved: v => page.setLook("shadowPower", v)
                        }
                    }
                }

                // ---- Animations ----
                Card {
                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "ANIMATION SPEED" }

                        Stepper {
                            label: "WINDOWS"; value: page.look.speedWindows; from: 1; to: 20
                            onMoved: v => page.setLook("speedWindows", v)
                        }
                        Stepper {
                            label: "BORDER"; value: page.look.speedBorder; from: 1; to: 20
                            onMoved: v => page.setLook("speedBorder", v)
                        }
                        Stepper {
                            label: "FADE"; value: page.look.speedFade; from: 1; to: 20
                            onMoved: v => page.setLook("speedFade", v)
                        }
                        Stepper {
                            label: "WORKSPACES"; value: page.look.speedWorkspaces; from: 1; to: 20
                            onMoved: v => page.setLook("speedWorkspaces", v)
                        }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "WORKSPACE STYLE" }

                        OptionRow {
                            options: page.workspaceStyleOptions
                            currentId: page.look.workspaceStyle
                            onPicked: id => page.setLook("workspaceStyle", id)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: stateDirProcess.running = true
}