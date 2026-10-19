import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../"

Item {
    id: page

    // Emitted when Esc is pressed inside the layout search box, so the settings
    // window (which owns the page) can close itself.
    signal closeRequested()
    // Emitted whenever the search box gives up keyboard focus, so the settings
    // window can take focus back and keep handling Esc / Tab.
    signal searchFocusReleased()

    property real marginLeft: 0
    property real marginRight: 10
    property real marginTop: 0
    property real marginBottom: 0
    property real labelWidth: 170
    property int maxKbLayouts: 4

    // Keybind shown in the keyboard section header (must match your Hyprland bind).
    property string switchKeybind: "SUPER + X"

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"

    // Every option this page manages. Keys are "section.option" for nested tables.
    readonly property var schema: ({
        "kb_layout": "string",
        "kb_variant": "string",
        "kb_options": "string",
        "sensitivity": "number",
        "accel_profile": "string",
        "natural_scroll": "bool",
        "left_handed": "bool",
        "scroll_factor": "number",
        "touchpad.natural_scroll": "bool",
        "touchpad.scroll_factor": "number",
        "touchpad.disable_while_typing": "bool",
        "touchpad.tap-to-click": "bool",
        "touchpad.tap-and-drag": "bool",
        "touchpad.clickfinger_behavior": "bool",
        "touchpad.middle_button_emulation": "bool"
    })

    // Hyprland defaults, used until the live values are read.
    readonly property var defaults: ({
        "kb_layout": "us",
        "kb_variant": "",
        "kb_options": "",
        "sensitivity": 0,
        "accel_profile": "adaptive",
        "natural_scroll": false,
        "left_handed": false,
        "scroll_factor": 1,
        "touchpad.natural_scroll": false,
        "touchpad.scroll_factor": 1,
        "touchpad.disable_while_typing": true,
        "touchpad.tap-to-click": true,
        "touchpad.tap-and-drag": true,
        "touchpad.clickfinger_behavior": false,
        "touchpad.middle_button_emulation": false
    })

    // settings = what the UI shows. overrides = only the keys changed here; these are the
    // only ones written to devices.lua, so the rest of your Hyprland config stays in charge.
    property var settings: Object.assign({}, page.defaults)
    property var overrides: ({})
    property var pendingApply: ({})

    property var layoutEntries: []
    property var layoutNames: ({})
    property var validPairs: ({})
    property bool layoutsFromRules: false
    property string layoutQuery: ""
    property int activeLayout: 0

    property bool devicesKnown: false
    property var touchpadNames: []
    property var pointerNames: []
    readonly property bool touchpadEnabled: !devicesKnown || touchpadNames.length > 0

    readonly property var kbLayouts: parseKbLayouts(settings["kb_layout"], settings["kb_variant"])

    readonly property var pointerToggles: [
        { key: "natural_scroll", label: "NATURAL SCROLL" },
        { key: "left_handed", label: "LEFT-HANDED" }
    ]

    readonly property var touchpadToggles: [
        { key: "touchpad.natural_scroll", label: "NATURAL SCROLL", touchpad: true },
        { key: "touchpad.tap-to-click", label: "TAP TO CLICK", touchpad: true },
        { key: "touchpad.tap-and-drag", label: "TAP AND DRAG", touchpad: true },
        { key: "touchpad.disable_while_typing", label: "DISABLE WHILE TYPING", touchpad: true },
        { key: "touchpad.clickfinger_behavior", label: "FINGER-COUNT CLICK", touchpad: true },
        { key: "touchpad.middle_button_emulation", label: "MIDDLE-CLICK EMULATION", touchpad: true }
    ]

    // ---------- helpers ----------

    // Drops focus from the search box and tells the settings window to take it back.
    // Without the hand-back nothing in the window has focus, and Esc/Tab go dead.
    function releaseSearchFocus() {
        searchInput.focus = false
        searchFocusReleased()
    }

    function num(key) {
        return typeof settings[key] === "number" ? settings[key] : defaults[key]
    }

    function luaString(value) { return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") }

    function luaValue(value) {
        if (typeof value === "boolean") return value ? "true" : "false"
        if (typeof value === "number") return String(value)
        if (typeof value === "object" && value !== null) return luaTable(value)
        return "\"" + luaString(value) + "\""
    }

    function luaTable(obj) {
        const parts = []
        const keys = Object.keys(obj)
        for (let i = 0; i < keys.length; i++)
            parts.push("[\"" + luaString(keys[i]) + "\"]=" + luaValue(obj[keys[i]]))
        return "{" + parts.join(",") + "}"
    }

    // { "touchpad.natural_scroll": true } -> { touchpad: { natural_scroll: true } }
    function nest(flat) {
        const out = {}
        const keys = Object.keys(flat)
        for (let i = 0; i < keys.length; i++) {
            const parts = keys[i].split(".")
            if (parts.length === 1) {
                out[parts[0]] = flat[keys[i]]
            } else {
                if (typeof out[parts[0]] !== "object") out[parts[0]] = {}
                out[parts[0]][parts[1]] = flat[keys[i]]
            }
        }
        return out
    }

    function inputLua(flat) { return "hl.config({input=" + luaTable(nest(flat)) + "})" }

    function sanitize(raw) {
        const clean = {}
        if (!raw || typeof raw !== "object") return clean
        const keys = Object.keys(raw)
        for (let i = 0; i < keys.length; i++) {
            const type = schema[keys[i]]
            if (type !== undefined && typeof raw[keys[i]] === (type === "bool" ? "boolean" : type))
                clean[keys[i]] = raw[keys[i]]
        }
        return clean
    }

    // ---------- persistence ----------

    Process {
        id: stateDirProcess
        command: ["mkdir", "-p", page.stateDir]
    }

    FileView {
        id: devicesFile
        path: page.stateDir + "/devices.json"
        blockLoading: true
    }

    FileView {
        id: devicesLua
        path: page.stateDir + "/devices.lua"
    }

    function loadState() {
        try {
            const saved = JSON.parse(devicesFile.text())
            if (saved && typeof saved.settings === "object" && saved.settings !== null) {
                overrides = sanitize(saved.settings)
                settings = Object.assign({}, defaults, overrides)
            }
        } catch (error) {}
    }

    function luaFileText() {
        if (Object.keys(overrides).length === 0) return ""
        return inputLua(overrides) + "\n"
    }

    Timer {
        id: stateSaveTimer
        interval: 300
        onTriggered: {
            try {
                devicesFile.setText(JSON.stringify({ settings: page.overrides }, null, 2))
                devicesLua.setText(page.luaFileText())
            } catch (error) {}
        }
    }

    // ---------- applying to Hyprland ----------

    Process {
        id: pInput
        stdout: StdioCollector {
            onStreamFinished: if (text.trim().length > 0 && text.trim() !== "ok") console.log("[devices] hyprctl:", text.trim())
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) console.warn("[devices] hyprctl error:", text.trim())
        }
    }

    // Changes made within 60 ms are merged into a single apply.
    function queueApply(fields) {
        pendingApply = Object.assign({}, pendingApply, fields)
        applyTimer.restart()
    }

    // Hyprland rebuilds the keymap every time kb_layout or kb_variant changes. If both are
    // sent in one table they are applied one after the other, and the half-applied state
    // (new layout list + old variant list) can be invalid, e.g. "us,latam,jp" with variants
    // ",dvorak" means latam(dvorak), which doesn't exist. So keyboard changes are applied in
    // three steps where every intermediate state is valid:
    //   1) clear variants  2) set the new layouts  3) set the new variants
    function flushApply() {
        if (pInput.running) { applyTimer.restart(); return }
        if (Object.keys(pendingApply).length === 0) return

        const fields = Object.assign({}, pendingApply)
        pendingApply = ({})

        const hasKb = fields["kb_layout"] !== undefined || fields["kb_variant"] !== undefined
        if (!hasKb) {
            pInput.command = ["hyprctl", "eval", inputLua(fields)]
            pInput.running = true
            return
        }

        const layout = String(settings["kb_layout"] || defaults["kb_layout"])
        const variant = String(settings["kb_variant"] || "")
        delete fields["kb_layout"]
        delete fields["kb_variant"]

        const steps = []
        if (Object.keys(fields).length > 0) steps.push(inputLua(fields))
        steps.push(inputLua({ "kb_variant": "" }))
        steps.push(inputLua({ "kb_layout": layout }))
        if (variant !== "") steps.push(inputLua({ "kb_variant": variant }))

        pInput.command = ["sh", "-c", "for l in \"$@\"; do hyprctl eval \"$l\"; done", "sh"].concat(steps)
        pInput.running = true
    }

    Timer { id: applyTimer; interval: 60; onTriggered: page.flushApply() }

    function commit(fields) {
        settings = Object.assign({}, settings, fields)
        overrides = Object.assign({}, overrides, fields)
        stateSaveTimer.restart()
        queueApply(fields)
    }

    function setOption(key, value) {
        const fields = {}
        fields[key] = value
        commit(fields)
    }

    // ---------- reading live state ----------

    function liveKeys() {
        return Object.keys(schema).map(k => k.replace(/\./g, ":"))
    }

    // One process prints one `hyprctl getoption -j` JSON object per line.
    Process {
        id: pLive
        stdout: StdioCollector {
            onStreamFinished: page.applyLive(text)
        }
    }

    function applyLive(output) {
        const next = Object.assign({}, settings)
        const lines = output.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line.length === 0) continue
            try {
                const o = JSON.parse(line)
                if (!o || typeof o.option !== "string") continue
                const key = o.option.replace(/^input:/, "").replace(/:/g, ".")
                const type = schema[key]
                if (type === undefined) continue
                if (type === "bool" && o.int !== undefined) next[key] = o.int !== 0
                else if (type === "number" && o.float !== undefined) next[key] = o.float
                else if (type === "number" && o.int !== undefined) next[key] = o.int
                else if (type === "string" && o.str !== undefined) next[key] = o.str
            } catch (error) {}
        }
        if (next["accel_profile"] === "") next["accel_profile"] = "adaptive"
        settings = next
        validateKbSettings()
    }

    Process {
        id: pDevices
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const mice = Array.isArray(data.mice) ? data.mice : []
                    const touchpads = []
                    const pointers = []
                    for (let i = 0; i < mice.length; i++) {
                        const name = String(mice[i].name || "")
                        if (/touchpad|trackpad|synaptics|glidepoint/i.test(name)) touchpads.push(name)
                        else pointers.push(name)
                    }
                    page.touchpadNames = touchpads
                    page.pointerNames = pointers
                    page.devicesKnown = true

                    // Pick up the layout that is actually active (e.g. after the keybind).
                    const kbs = Array.isArray(data.keyboards) ? data.keyboards : []
                    let kb = null
                    for (let i = 0; i < kbs.length; i++) if (kbs[i].main === true) { kb = kbs[i]; break }
                    if (!kb && kbs.length > 0) kb = kbs[0]
                    if (kb) {
                        if (typeof kb.active_layout_index === "number") page.activeLayout = kb.active_layout_index
                        else if (typeof kb.active_keymap === "string") page.syncActiveFromName(kb.active_keymap)
                    }
                } catch (error) {}
            }
        }
    }

    function refresh() {
        pLive.command = [
            "sh", "-c",
            "for o in " + liveKeys().join(" ") + "; do hyprctl getoption \"input:$o\" -j 2>/dev/null | tr -d '\\n'; echo; done"
        ]
        pLive.running = true
        pDevices.running = true
    }

    Timer { id: refreshTimer; interval: 400; onTriggered: page.refresh() }
    Timer { id: lateRefreshTimer; interval: 1500; onTriggered: page.refresh() }

    // ---------- keyboard layouts ----------

    // Both lists are read, the evdev one first, then merged, so no layout is missed.
    Process {
        id: pLayouts
        command: [
            "sh", "-c",
            "cat /usr/share/X11/xkb/rules/evdev.lst /usr/share/X11/xkb/rules/base.lst 2>/dev/null | awk '!seen[$0]++ || /^!/'"
        ]
        stdout: StdioCollector {
            onStreamFinished: page.parseLayoutList(text)
        }
    }

    function fallbackLayouts() {
        const base = [
            ["us", "English (US)"], ["gb", "English (UK)"], ["de", "German"], ["fr", "French"],
            ["es", "Spanish"], ["latam", "Spanish (Latin American)"], ["it", "Italian"],
            ["pt", "Portuguese"], ["br", "Portuguese (Brazil)"],
            ["ru", "Russian"], ["ua", "Ukrainian"], ["pl", "Polish"], ["se", "Swedish"],
            ["no", "Norwegian"], ["dk", "Danish"], ["fi", "Finnish"], ["jp", "Japanese"],
            ["kr", "Korean"], ["cn", "Chinese"], ["il", "Hebrew"], ["tr", "Turkish"]
        ]
        return base.map(b => ({ layout: b[0], variant: "", name: b[1], indent: false }))
    }

    // Reads the "! layout" and "! variant" sections of the xkb rules list.
    function parseLayoutList(raw) {
        const bases = []
        const seenBase = {}
        const variants = {}
        const seenVariant = {}
        let section = ""
        const lines = raw.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            if (line.charAt(0) === "!") { section = line.replace(/^!\s*/, "").trim(); continue }
            if (section === "layout") {
                const m = line.match(/^\s+(\S+)\s+(.*\S)\s*$/)
                if (m && !seenBase[m[1]]) {
                    seenBase[m[1]] = true
                    bases.push({ layout: m[1], variant: "", name: m[2], indent: false })
                }
            } else if (section === "variant") {
                const m = line.match(/^\s+(\S+)\s+(\S+):\s+(.*\S)\s*$/)
                if (m && !seenVariant[m[2] + "|" + m[1]]) {
                    seenVariant[m[2] + "|" + m[1]] = true
                    if (!variants[m[2]]) variants[m[2]] = []
                    variants[m[2]].push({ layout: m[2], variant: m[1], name: m[3], indent: true })
                }
            }
        }

        let entries = []
        const fromRules = bases.length > 0
        if (!fromRules) {
            entries = fallbackLayouts()
        } else {
            bases.sort((a, b) => a.name.localeCompare(b.name))
            for (let i = 0; i < bases.length; i++) {
                entries.push(bases[i])
                const vs = variants[bases[i].layout]
                if (vs) {
                    vs.sort((a, b) => a.name.localeCompare(b.name))
                    for (let j = 0; j < vs.length; j++) entries.push(vs[j])
                }
            }
        }

        const names = {}
        const pairs = {}
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i]
            e.code = e.layout + (e.variant ? "(" + e.variant + ")" : "")
            e.search = (e.name + " " + e.code).toLowerCase()
            names[e.layout + "|" + e.variant] = e.name
            pairs[e.layout + "|" + e.variant] = true
        }
        layoutNames = names
        validPairs = pairs
        layoutsFromRules = fromRules
        layoutEntries = entries
        validateKbSettings()
    }

    function validLayoutPair(layout, variant) {
        return validPairs[layout + "|" + (variant || "")] === true
    }

    // If a saved or live layout/variant combination doesn't exist in the xkb rules (for
    // example left over from an earlier broken write), drop the keyboard override instead
    // of re-applying it on every start.
    function validateKbSettings() {
        if (!layoutsFromRules) return
        const list = kbLayouts
        let bad = false
        for (let i = 0; i < list.length; i++)
            if (!validLayoutPair(list[i].layout, list[i].variant)) { bad = true; break }
        if (!bad) return

        console.warn("[devices] invalid keyboard layout/variant combination, resetting:",
                     settings["kb_layout"], "/", settings["kb_variant"])
        const next = Object.assign({}, overrides)
        delete next["kb_layout"]
        delete next["kb_variant"]
        overrides = next
        activeLayout = 0
        const fields = { "kb_layout": defaults["kb_layout"], "kb_variant": defaults["kb_variant"] }
        settings = Object.assign({}, settings, fields)
        stateSaveTimer.restart()
        queueApply(fields)
    }

    function filteredLayouts() {
        const q = layoutQuery.trim().toLowerCase()
        if (q === "") return layoutEntries
        return layoutEntries.filter(e => e.search.indexOf(q) !== -1)
    }

    function parseKbLayouts(layoutStr, variantStr) {
        const ls = String(layoutStr || "").split(",").map(s => s.trim()).filter(s => s.length > 0)
        const vs = String(variantStr || "").split(",")
        if (ls.length === 0) return [{ layout: "us", variant: "" }]
        return ls.map((l, i) => ({ layout: l, variant: (vs[i] || "").trim() }))
    }

    function kbLabel(item) {
        return item.layout.toUpperCase() + (item.variant ? " (" + item.variant + ")" : "")
    }

    function setKbLayouts(list) {
        activeLayout = 0
        commit({
            "kb_layout": list.map(l => l.layout).join(","),
            "kb_variant": list.some(l => l.variant !== "") ? list.map(l => l.variant).join(",") : ""
        })
    }

    function addKbLayout(entry) {
        if (layoutsFromRules && !validLayoutPair(entry.layout, entry.variant)) return
        const list = kbLayouts.slice()
        if (list.length >= maxKbLayouts) return
        if (list.some(l => l.layout === entry.layout && l.variant === entry.variant)) return
        list.push({ layout: entry.layout, variant: entry.variant })
        setKbLayouts(list)
    }

    function removeKbLayout(index) {
        if (kbLayouts.length <= 1) return
        setKbLayouts(kbLayouts.filter((l, i) => i !== index))
    }

    Process { id: pSwitch }

    function switchKbLayout(index) {
        activeLayout = index
        pSwitch.command = ["hyprctl", "switchxkblayout", "all", String(index)]
        pSwitch.running = true
    }

    // Marks the chip whose xkb description matches the active keymap name.
    function syncActiveFromName(name) {
        const list = kbLayouts
        for (let i = 0; i < list.length; i++) {
            if (layoutNames[list[i].layout + "|" + list[i].variant] === name) {
                activeLayout = i
                return
            }
        }
    }

    // Hyprland sends "activelayout>>keyboardname,layoutname" whenever the layout changes,
    // including from the Super+X bind, so the highlighted chip follows it live.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return
            const data = String(event.data)
            const comma = data.indexOf(",")
            if (comma < 0) return
            page.syncActiveFromName(data.substring(comma + 1))
        }
    }

    function cycleKbLayout() {
        if (kbLayouts.length < 2) return
        switchKbLayout((activeLayout + 1) % kbLayouts.length)
    }

    // ---------- reset ----------

    Process {
        id: pReset
        onExited: exitCode => {
            refreshTimer.restart()
            lateRefreshTimer.restart()
        }
    }

    function resetToConfig() {
        stateSaveTimer.stop()
        applyTimer.stop()
        pendingApply = ({})
        overrides = ({})
        settings = Object.assign({}, defaults)
        activeLayout = 0
        pReset.command = [
            "sh", "-c",
            "rm -f '" + page.stateDir + "/devices.json' '" + page.stateDir + "/devices.lua'; hyprctl reload"
        ]
        pReset.running = true
    }

    // ---------- reusable rows ----------

    Component {
        id: toggleRow

        Row {
            id: tRow
            required property var modelData
            readonly property bool on: page.settings[modelData.key] === true
            readonly property bool usable: modelData.touchpad !== true || page.touchpadEnabled
            width: parent ? parent.width : 0
            height: 28; spacing: 8
            opacity: usable ? 1 : 0.4

            Text {
                width: page.labelWidth; height: 28
                verticalAlignment: Text.AlignVCenter
                text: tRow.modelData.label; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
            }

            Rectangle {
                width: 64; height: 28; radius: Theme.radius
                color: tRow.on ? Theme.alpha(Theme.accent, 0.10) : (tMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                border.width: 1
                border.color: tRow.on || tMouse.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: tRow.on ? "ON" : "OFF"
                    color: tRow.on ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.bold: true; font.letterSpacing: 1
                }

                MouseArea {
                    id: tMouse
                    anchors.fill: parent; hoverEnabled: true
                    enabled: tRow.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.setOption(tRow.modelData.key, !tRow.on)
                }
            }
        }
    }

    Component {
        id: sliderRow

        Row {
            id: sRow
            required property var modelData
            readonly property bool usable: modelData.touchpad !== true || page.touchpadEnabled
            width: parent ? parent.width : 0
            spacing: 8
            opacity: usable ? 1 : 0.4

            Text {
                width: page.labelWidth
                anchors.verticalCenter: parent.verticalCenter
                text: sRow.modelData.label; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
            }

            Slider {
                width: parent.width - page.labelWidth - 52 - 16
                anchors.verticalCenter: parent.verticalCenter
                enabled: sRow.usable
                icon: ""
                value: Math.max(0, Math.min(1, (page.num(sRow.modelData.key) - sRow.modelData.min) / (sRow.modelData.max - sRow.modelData.min)))
                onCommitted: value => {
                    let v = Math.round((sRow.modelData.min + value * (sRow.modelData.max - sRow.modelData.min)) * 100) / 100
                    if (sRow.modelData.min < 0 && Math.abs(v) < 0.03) v = 0
                    page.setOption(sRow.modelData.key, v)
                }
            }

            Text {
                width: 52
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Number(page.num(sRow.modelData.key)).toFixed(2) + sRow.modelData.suffix
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
            }
        }
    }

    // ---------- UI ----------

    // Clicking anywhere outside the search box releases its keyboard focus.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        grabPermissions: PointerHandler.ApprovesTakeOverByAnything
        onTapped: if (searchInput.activeFocus) page.releaseSearchFocus()
    }

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
                text: "INPUT"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeTitle; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------- POINTER ----------------
            Row {
                spacing: 10

                Text {
                    text: "MOUSE"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSection; font.bold: true; font.letterSpacing: 2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.devicesKnown
                    text: page.pointerNames.length === 0 ? "NO MOUSE DETECTED" : page.pointerNames.length + (page.pointerNames.length === 1 ? " DEVICE" : " DEVICES")
                    color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                }
            }

            Rectangle {
                width: parent.width
                height: pointerColumn.implicitHeight + 20
                radius: Theme.radius
                color: "#00000000"; border.width: 1; border.color: Theme.border

                Column {
                    id: pointerColumn
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6

                    Repeater {
                        model: [{ key: "sensitivity", label: "SPEED", min: -1, max: 1, suffix: "" }]
                        delegate: sliderRow
                    }

                    Row {
                        width: parent.width; spacing: 8

                        Text {
                            width: page.labelWidth; height: 28
                            verticalAlignment: Text.AlignVCenter
                            text: "ACCELERATION"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                        }

                        Repeater {
                            model: [
                                { label: "ADAPTIVE", value: "adaptive" },
                                { label: "FLAT", value: "flat" }
                            ]

                            delegate: Rectangle {
                                id: accelButton
                                required property var modelData
                                property bool current: (page.settings["accel_profile"] === "flat") === (modelData.value === "flat")
                                width: 84; height: 28; radius: Theme.radius
                                color: current ? Theme.alpha(Theme.accent, 0.10) : (accelMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                border.width: 1
                                border.color: current || accelMouse.containsMouse ? Theme.accent : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: accelButton.modelData.label
                                    color: accelButton.current ? Theme.accent : Theme.text
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.bold: true
                                }

                                MouseArea {
                                    id: accelMouse
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.setOption("accel_profile", accelButton.modelData.value)
                                }
                            }
                        }
                    }

                    Repeater {
                        model: [{ key: "scroll_factor", label: "SCROLL SPEED", min: 0.1, max: 3, suffix: "x" }]
                        delegate: sliderRow
                    }

                    Row {
                        width: parent.width
                        spacing: 16

                        Repeater {
                            model: page.pointerToggles

                            delegate: Row {
                                id: toggleItem
                                required property var modelData
                                readonly property bool isOn: page.settings[modelData.key] === true

                                height: 28
                                spacing: 8

                                Text {
                                    width: toggleItem.modelData.labelWidth
                                    height: 28
                                    verticalAlignment: Text.AlignVCenter
                                    text: toggleItem.modelData.label
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.textSizeBody
                                }

                                Rectangle {
                                    width: 64
                                    height: 28
                                    radius: Theme.radius

                                    color: toggleItem.isOn
                                        ? Theme.alpha(Theme.accent, 0.10)
                                        : (toggleMouse.containsMouse
                                           ? Theme.alpha(Theme.accent, 0.08)
                                           : "#00000000")

                                    border.width: 1
                                    border.color: toggleItem.isOn || toggleMouse.containsMouse
                                        ? Theme.accent
                                        : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: toggleItem.isOn ? "ON" : "OFF"
                                        color: toggleItem.isOn ? Theme.accent : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.textSizeBody
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }

                                    MouseArea {
                                        id: toggleMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setOption(
                                            toggleItem.modelData.key,
                                            !toggleItem.isOn
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- KEYBOARD ----------------
            Row {
                spacing: 10

                Text {
                    text: "KEYBOARD"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSection; font.bold: true; font.letterSpacing: 2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "UP TO " + page.maxKbLayouts + " LAYOUTS"
                    color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                }

                // Keybind hint. Clicking it also cycles to the next layout.
                Rectangle {
                    id: keybindHint
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.kbLayouts.length > 1
                    width: hintText.implicitWidth + 16; height: 22; radius: Theme.radius
                    color: hintMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                    border.width: 1
                    border.color: hintMouse.containsMouse ? Theme.accent : Theme.border

                    Text {
                        id: hintText
                        anchors.centerIn: parent
                        text: page.switchKeybind + "  SWITCH LAYOUT"
                        color: hintMouse.containsMouse ? Theme.accent : Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.bold: true
                    }

                    MouseArea {
                        id: hintMouse
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.cycleKbLayout()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: kbColumn.implicitHeight + 20
                radius: Theme.radius
                color: "#00000000"; border.width: 1; border.color: Theme.border

                Column {
                    id: kbColumn
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6

                    Row {
                        width: parent.width; spacing: 8

                        Text {
                            width: 36; height: 28
                            verticalAlignment: Text.AlignVCenter
                            text: "LAYOUT"; color: Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                        }

                        Flow {
                            width: parent.width - 36 - 8; spacing: 6

                            Repeater {
                                model: page.kbLayouts

                                delegate: Rectangle {
                                    id: kbChip
                                    required property var modelData
                                    required property int index
                                    property bool current: index === page.activeLayout
                                    height: 28; radius: Theme.radius
                                    width: chipRow.implicitWidth + 16
                                    color: current ? Theme.alpha(Theme.accent, 0.10) : (chipMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                    border.width: 1
                                    border.color: current || chipMouse.containsMouse ? Theme.accent : Theme.border

                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.switchKbLayout(kbChip.index)
                                    }

                                    Row {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: page.kbLabel(kbChip.modelData)
                                            color: kbChip.current ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.bold: true
                                        }

                                        Text {
                                            visible: page.kbLayouts.length > 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "\u00d7"
                                            color: removeMouse.containsMouse ? Theme.accent : Theme.textDim
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSection

                                            MouseArea {
                                                id: removeMouse
                                                anchors.fill: parent; anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: page.removeKbLayout(kbChip.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width; spacing: 8

                        Text {
                            width: 36; height: 28
                            verticalAlignment: Text.AlignVCenter
                            text: "ADD"; color: Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                        }

                        Rectangle {
                            width: parent.width - 36 - 8; height: 28; radius: Theme.radius
                            color: "#00000000"; border.width: 1
                            border.color: searchInput.activeFocus ? Theme.accent : Theme.border

                            TextInput {
                                id: searchInput
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true; selectByMouse: true
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                                onTextChanged: page.layoutQuery = text

                                // Esc leaves the field, hands focus back to the settings
                                // window and asks it to close. The key event can't bubble
                                // up on its own because the page isn't a child of the
                                // window's key handler, so it is signalled explicitly.
                                Keys.onEscapePressed: event => {
                                    event.accepted = true
                                    page.releaseSearchFocus()
                                    page.closeRequested()
                                }
                            }

                            Text {
                                visible: searchInput.text.length === 0
                                anchors.left: parent.left; anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "SEARCH LANGUAGE OR LAYOUT"
                                color: Theme.textDim
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                            }
                        }
                    }

                    Row {
                        width: parent.width; spacing: 8

                        Item { width: 36; height: 1 }

                        Rectangle {
                            width: parent.width - 36 - 8; height: 168; radius: Theme.radius
                            color: "#00000000"; border.width: 1; border.color: Theme.border

                            ListView {
                                id: layoutList
                                anchors.fill: parent; anchors.margins: 1
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: page.filteredLayouts()

                                delegate: Rectangle {
                                    id: layoutRow
                                    required property var modelData
                                    width: layoutList.width; height: 26
                                    color: layoutMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: layoutRow.modelData.indent ? 24 : 8
                                        anchors.right: codeText.left; anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: layoutRow.modelData.name
                                        color: Theme.text
                                        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                                    }

                                    Text {
                                        id: codeText
                                        anchors.right: parent.right; anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: layoutRow.modelData.code
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                                    }

                                    MouseArea {
                                        id: layoutMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            page.releaseSearchFocus()
                                            page.addKbLayout(layoutRow.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- TOUCHPAD ----------------
            Row {
                spacing: 10

                Text {
                    text: "TOUCHPAD"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSection; font.bold: true; font.letterSpacing: 2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.devicesKnown
                    text: page.touchpadNames.length === 0 ? "NO TOUCHPAD DETECTED" : page.touchpadNames[0]
                    color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                }
            }

            Rectangle {
                width: parent.width
                height: touchpadColumn.implicitHeight + 20
                radius: Theme.radius
                color: "#00000000"; border.width: 1; border.color: Theme.border

                Column {
                    id: touchpadColumn
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6

                    Repeater {
                        model: [{ key: "touchpad.scroll_factor", label: "SCROLL SPEED", min: 0.1, max: 3, suffix: "x", touchpad: true }]
                        delegate: sliderRow
                    }

                    Repeater {
                        model: page.touchpadToggles
                        delegate: toggleRow
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 34; radius: Theme.radius
                color: resetMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                border.width: 1
                border.color: resetMouse.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent; text: "RESET TO CONFIG"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup; font.bold: true; font.letterSpacing: 1
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.resetToConfig()
                }
            }
        }
    }

    Component.onCompleted: {
        stateDirProcess.running = true
        loadState()
        pLayouts.running = true
        refresh()
    }
}