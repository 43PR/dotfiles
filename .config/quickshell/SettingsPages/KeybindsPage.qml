// .config/quickshell/SettingsPages/KeybindsPage.qml
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page
    signal closeRequested()
    signal searchFocusReleased()
    property real marginLeft: 0
    property real marginRight: 10
    property real marginTop: 0
    property real marginBottom: 0
    property real sectionSpacing: 6

    readonly property string home: Quickshell.env("HOME")
    readonly property string bindsPath: home + "/.config/quickshell/state/binds.lua"

    // ------------------------------------------------------------------
    // Browser
    // ------------------------------------------------------------------

    readonly property var browsers: [
        { bin: "brave",                label: "BRAVE",     desktop: "brave-browser.desktop" },
        { bin: "firefox",              label: "FIREFOX",   desktop: "firefox.desktop" },
        { bin: "chromium",             label: "CHROMIUM",  desktop: "chromium.desktop" },
        { bin: "google-chrome-stable", label: "CHROME",    desktop: "google-chrome.desktop" },
        { bin: "zen-browser",          label: "ZEN",       desktop: "zen.desktop" },
        { bin: "librewolf",            label: "LIBREWOLF", desktop: "librewolf.desktop" },
        { bin: "vivaldi-stable",       label: "VIVALDI",   desktop: "vivaldi-stable.desktop" }
    ]

    property string browserBin: ""
    property string browserDesktop: ""
    property var installed: []
    property bool reloadAfterSave: false

    // Editable binds (saved to state/binds.lua as kb_<id>)
    readonly property var bindDefs: [
        { id: "terminal",      label: "TERMINAL",                    def: "T" },
        { id: "launcher",      label: "LAUNCHER",                    def: "D" },
        { id: "files",         label: "FILE MANAGER",                def: "E" },
        { id: "close",         label: "CLOSE ACTIVE WINDOW",         def: "Q" },
        { id: "settings",      label: "SETTINGS",                    def: "I" },
        { id: "browser",       label: "BROWSER",                     def: "B" },
        { id: "qa",            label: "QUICK ACTIONS",               def: "S" },
        { id: "fullscreen",    label: "FULLSCREEN",                  def: "F" },
        { id: "float",         label: "FLOATING WINDOW",             def: "Space" },
        { id: "lock",          label: "LOCK SCREEN",                 def: "Tab" },
        { id: "power",         label: "POWER MENU",                  def: "GRAVE" },
        { id: "opacity",       label: "OPACITY",                     def: "O" },
        { id: "clipboard",     label: "CLIPBOARD",                   def: "V" },
        { id: "todo",          label: "NOTES & REMINDERS",           def: "C" },
        { id: "colorpicker",   label: "COLOR PICKER",                def: "SHIFT + C" },
        { id: "wallpapers",    label: "WALLPAPERS PICKER",           def: "W" },
        { id: "record",        label: "TOGGLE SCREEN RECORDING",     def: "R" },
        { id: "notifications", label: "NOTIFICATIONS",               def: "N" },
        { id: "theme",         label: "TOGGLE DARK/LIGHT MODE",      def: "period" },
        { id: "bar",           label: "TOGGLE BAR",                  def: "SHIFT + W" },
        { id: "layout",        label: "KB LAYOUT",                   def: "X" },
        // noSuper: bound as-is in keybinds.lua, SUPER is not prepended
        { id: "shot",          label: "SCREENSHOT (FULL)",           def: "Delete",         noSuper: true },
        { id: "shot_area",     label: "SCREENSHOT (AREA)",           def: "SHIFT + Delete", noSuper: true }
    ]

    // Fixed binds hardcoded in keybinds.lua (display only, not editable)
    readonly property var fixedBinds: [
        { id: "fx_focus",     label: "FOCUS WINDOW",              chord: "SUPER + H / J / K / L" },
        { id: "fx_move",      label: "MOVE WINDOW",               chord: "SUPER + SHIFT + H / J / K / L" },
        { id: "fx_ws",        label: "SWITCH WORKSPACE",          chord: "SUPER + 1 - 0" },
        { id: "fx_ws_move",   label: "MOVE WINDOW TO WORKSPACE",  chord: "SUPER + SHIFT + 1 - 0" }
    ]

    property var bindKeys: ({})
    property string editingId: ""
    property string captureHint: ""
    property string bindQuery: ""

    // Custom (user-created) binds, saved to state/custom_binds.json and
    // state/custom_binds.lua (the Lua file is what Hyprland reads)
    property var customBinds: []
    property bool formOpen: false
    property bool helpOpen: true
    property string formId: ""      // "" = creating, otherwise editing that id
    property string formName: ""
    property string formCmd: ""
    property string formKey: ""
    readonly property string formCaptureId: "__form__"
    readonly property string customPath: home + "/.config/quickshell/state/custom_binds.json"
    readonly property string customLuaPath: home + "/.config/quickshell/state/custom_binds.lua"
    readonly property bool formValid: formName.trim() !== "" && formCmd.trim() !== "" && formKey !== ""

    function isCustom(id) { return customBinds.some(c => c.id === id) }

    // Custom binds and the new-bind form store the full chord (SUPER is only
    // included when it was held), exactly like the screenshot binds.
    function isNoSuper(id) {
        return id === formCaptureId || isCustom(id)
            || bindDefs.find(d => d.id === id)?.noSuper === true
    }

    function labelOf(id) {
        if (id === formCaptureId) return formName.trim() || "NEW KEYBIND"
        return bindDefs.find(d => d.id === id)?.label
            || customBinds.find(c => c.id === id)?.label
            || ""
    }

    function chordOf(d) {
        if (d.chord) return d.chord
        if (d.noSuper) return prettyKey(d.id).toUpperCase()
        return "SUPER + " + prettyKey(d.id)
    }

    readonly property var allBinds: {
        const custom = customBinds.map(c => ({
            id: c.id,
            label: c.label.toUpperCase(),
            cmd: c.cmd,
            noSuper: true,
            custom: true
        }))
        return bindDefs.concat(custom).concat(fixedBinds)
    }

    readonly property var shownBinds: {
        const q = bindQuery.trim().toLowerCase()
        if (!q) return allBinds
        return allBinds.filter(d =>
            d.label.toLowerCase().indexOf(q) >= 0 ||
            (d.cmd || "").toLowerCase().indexOf(q) >= 0 ||
            chordOf(d).toLowerCase().indexOf(q) >= 0)
    }

    // The chord as stored/compared (no prettifying)
    function rawChord(d) {
        if (d.chord) return d.chord
        if (d.noSuper) return keyOf(d.id)
        return "SUPER + " + keyOf(d.id)
    }

    // Label of another bind that already uses the key typed in the form
    readonly property string formConflict: {
        if (!formKey) return ""
        const k = formKey.toLowerCase()
        const hit = allBinds.find(d => d.id !== formId && rawChord(d).toLowerCase() === k)
        return hit ? hit.label : ""
    }

    function isBrowser(b) { return browsers.some(x => x.bin === b) }

    function initBindKeys() {
        const o = {}
        for (const d of bindDefs)
            o[d.id] = d.def
        bindKeys = o
    }

    function keyOf(id) {
        if (id === formCaptureId) return formKey
        const c = customBinds.find(x => x.id === id)
        if (c) return c.key
        return bindKeys[id] || bindDefs.find(d => d.id === id)?.def || "?"
    }

    // keyOf() returns what is written to binds.lua (an xkb keysym name);
    // prettyKey() returns what the UI shows (the symbol on the keycap).
    readonly property var keySymbols: ({
        period: ".", comma: ",", slash: "/", minus: "-", equal: "=",
        semicolon: ";", apostrophe: "'", bracketleft: "[", bracketright: "]",
        backslash: "\\", GRAVE: "`"
    })

    function prettyKey(id) {
        return keyOf(id).split(" + ").map(p => keySymbols[p] || p).join(" + ")
    }

    function luaName(id) { return "kb_" + id }

    function cleanKey(raw, keepSuper) {
        let s = (raw || "").trim()
        // mainMod is prepended in keybinds.lua for normal binds — never store
        // SUPER for those. noSuper binds (screenshots) keep it if it was held.
        if (!keepSuper)
            s = s.replace(/^(SUPER|META|WIN)\s*\+\s*/i, "")
        s = s.replace(/\s*\+\s*/g, " + ")
        s = s.replace(/[^A-Za-z0-9:+_ ]/g, "")
        return s.trim()
    }

    function hyprKeyName(event) {
        const k = event.key
        if (k === Qt.Key_Return || k === Qt.Key_Enter) return "Return"
        if (k === Qt.Key_Space) return "Space"
        if (k === Qt.Key_Tab || k === Qt.Key_Backtab) return "Tab"
        if (k === Qt.Key_Escape) return "Escape"
        if (k === Qt.Key_Backspace) return "BackSpace"
        if (k === Qt.Key_Delete) return "Delete"
        if (k === Qt.Key_Insert) return "Insert"
        if (k === Qt.Key_Home) return "Home"
        if (k === Qt.Key_End) return "End"
        if (k === Qt.Key_PageUp) return "Page_Up"
        if (k === Qt.Key_PageDown) return "Page_Down"
        if (k === Qt.Key_Left) return "Left"
        if (k === Qt.Key_Right) return "Right"
        if (k === Qt.Key_Up) return "Up"
        if (k === Qt.Key_Down) return "Down"
        if (k === Qt.Key_QuoteLeft || k === Qt.Key_AsciiTilde) return "GRAVE"
        if (k === Qt.Key_Print || k === Qt.Key_SysReq) return "Print"
        if (k === Qt.Key_Pause) return "Pause"
        if (k === Qt.Key_ScrollLock) return "Scroll_Lock"
        if (k === Qt.Key_Menu) return "Menu"
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1)
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
        const named = {
            45: "minus", 61: "equal",
            91: "bracketleft", 93: "bracketright", 92: "backslash",
            59: "semicolon", 39: "apostrophe",
            44: "comma", 46: "period", 47: "slash"
        }
        if (named[k]) return named[k]
        if (event.text && event.text.length === 1 && /[a-zA-Z0-9]/.test(event.text))
            return event.text.toUpperCase()
        return ""
    }

    function isModifierOnly(event) {
        return event.key === Qt.Key_Shift
            || event.key === Qt.Key_Control
            || event.key === Qt.Key_Alt
            || event.key === Qt.Key_Meta
            || event.key === Qt.Key_Super_L
            || event.key === Qt.Key_Super_R
            || event.key === Qt.Key_AltGr
    }
    function releaseToWindow() {
        keyGrabber.focus = false
        bindSearch.focus = false
        formNameField.focus = false
        formCmdField.focus = false
        searchFocusReleased()
    }
    function captureKey(event) {
        if (bindSearch.activeFocus || formNameField.activeFocus || formCmdField.activeFocus) return
        if (!editingId || event.isAutoRepeat) return
        if (event.key === Qt.Key_Escape) {
            editingId = ""
            captureHint = ""
            event.accepted = true
            releaseToWindow()
            return
        }
        if (isModifierOnly(event)) {
            captureHint = "Hold the modifier, then press the key"
            return
        }
        const name = hyprKeyName(event)
        if (!name) {
            captureHint = "That key is not mapped. Try another."
            event.accepted = true
            return
        }
        const parts = []
        // noSuper binds only include SUPER when it is actually held
        if (isNoSuper(editingId) && (event.modifiers & Qt.MetaModifier)) parts.push("SUPER")
        if (event.modifiers & Qt.ControlModifier) parts.push("CTRL")
        if (event.modifiers & Qt.AltModifier) parts.push("ALT")
        if (event.modifiers & Qt.ShiftModifier) parts.push("SHIFT")
        // Meta / Super is mainMod and is added in keybinds.lua
        parts.push(name)
        captureHint = ""
        event.accepted = true
        setKey(editingId, parts.join(" + "))
    }

    function setKey(id, raw) {
        const key = cleanKey(raw, isNoSuper(id))
        if (!id || !key) return

        // New-bind form: only remember the key, nothing is saved yet
        if (id === formCaptureId) {
            formKey = key
            editingId = ""
            captureHint = ""
            releaseToWindow()
            return
        }

        // Existing custom bind: rebind and save
        if (isCustom(id)) {
            customBinds = customBinds.map(c => c.id === id ? Object.assign({}, c, { key: key }) : c)
            editingId = ""
            captureHint = ""
            saveCustom()
            releaseToWindow()
            return
        }

        const next = Object.assign({}, bindKeys)
        next[id] = key
        bindKeys = next
        editingId = ""
        captureHint = ""
        saveBinds()
        releaseToWindow()
    }

    function beginEdit(id) {
        editingId = (editingId === id) ? "" : id
        captureHint = ""
        if (editingId !== "")
            keyGrabber.forceActiveFocus()
        else
            releaseToWindow()
    }

    function parseBinds(text) {
        const next = Object.assign({}, bindKeys)
        for (const d of bindDefs) {
            const re = new RegExp("^\\s*" + luaName(d.id) + "\\s*=\\s*\"([^\"]+)\"", "m")
            const m = re.exec(text)
            if (m) next[d.id] = m[1]
        }
        bindKeys = next
    }

    function saveBinds() {
        let body = "-- Generated by Quickshell (Settings > Keybinds). Do not edit by hand.\n"
        for (const d of bindDefs)
            body += luaName(d.id) + " = \"" + keyOf(d.id) + "\"\n"
        bindWriter.scriptBody = body
        bindWriter.running = false
        bindWriter.running = true
    }

    // ---- custom binds -------------------------------------------------

    function luaStr(v) {
        return "\"" + String(v)
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
            .replace(/\r?\n/g, "\\n") + "\""
    }

    function parseCustom(t) {
        if (!t || !t.trim()) return
        try {
            const arr = JSON.parse(t)
            if (!Array.isArray(arr)) return
            customBinds = arr
                .filter(c => c && c.id && c.label && c.cmd && c.key)
                .map(c => ({
                    id: String(c.id),
                    label: String(c.label),
                    cmd: String(c.cmd),
                    key: String(c.key)
                }))
        } catch (e) {
            console.warn("KeybindsPage: bad custom_binds.json: " + e)
        }
    }

    function saveCustom() {
        let lua = "-- Generated by Quickshell (Settings > Keybinds). Do not edit by hand.\n"
        lua += "return {\n"
        for (const c of customBinds)
            lua += "    { key = " + luaStr(c.key)
                 + ", cmd = " + luaStr(c.cmd)
                 + ", label = " + luaStr(c.label) + " },\n"
        lua += "}\n"
        customWriter.jsonBody = JSON.stringify(customBinds, null, 2) + "\n"
        customWriter.luaBody = lua
        customWriter.running = false
        customWriter.running = true
    }

    function openForm(id) {
        const c = id ? customBinds.find(x => x.id === id) : null
        editingId = ""
        captureHint = ""
        formId = c ? c.id : ""
        formKey = c ? c.key : ""
        formNameField.text = c ? c.label : ""
        formCmdField.text = c ? c.cmd : ""
        formOpen = true
        formNameField.forceActiveFocus()
    }

    function closeForm() {
        formOpen = false
        formId = ""
        formKey = ""
        formNameField.text = ""
        formCmdField.text = ""
        if (editingId === formCaptureId) editingId = ""
        captureHint = ""
        releaseToWindow()
    }

    function submitForm() {
        if (!formValid) return
        const entry = {
            id: formId || ("c" + Date.now()),
            label: formName.trim(),
            cmd: formCmd.trim(),
            key: formKey
        }
        const next = customBinds.slice()
        const i = next.findIndex(c => c.id === entry.id)
        if (i >= 0) next[i] = entry
        else next.push(entry)
        customBinds = next
        closeForm()
        saveCustom()
    }

    function deleteCustom(id) {
        if (editingId === id) editingId = ""
        if (formId === id) closeForm()
        customBinds = customBinds.filter(c => c.id !== id)
        saveCustom()
    }

    function refreshBrowser() {
        if (!browserQuery.running) browserQuery.running = true
    }

    function setBrowser(b) {
        if (browserSetter.running || b.desktop === browserDesktop) return
        browserSetter.desktop = b.desktop
        browserSetter.running = true
    }

    Process {
        id: browserQuery
        command: ["xdg-mime", "query", "default", "x-scheme-handler/https"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.browserDesktop = text.trim()
                const selected = page.browsers.find(b => b.desktop === page.browserDesktop)
                page.browserBin = selected ? selected.bin : ""
            }
        }
    }
    Process {
        id: browserSetter
        property string desktop: ""
        command: ["env", "-u", "BROWSER", "xdg-settings", "set", "default-web-browser", desktop]
        onExited: code => {
            if (code !== 0) console.warn("KeybindsPage: XDG browser update failed (" + code + ")")
            page.refreshBrowser()
        }
    }
    onVisibleChanged: if (visible) refreshBrowser()

    Component.onCompleted: { initBindKeys(); refreshBrowser(); }

    // Invisible focus target. While a row is selected, the next real key
    // (Super+Enter, Super+Shift+C, …) is written and Hyprland is reloaded.
    Item {
        id: keyGrabber
        focus: page.editingId !== ""
        Keys.onPressed: function(event) { page.captureKey(event) }
    }

    FileView {
        id: bindsFile
        path: page.bindsPath
        printErrors: false
        onLoaded: page.parseBinds(text())
    }

    // Writes binds.lua, then reloads Hyprland. Args are not expanded by the
    // shell, so the generated Lua cannot break the command.
    Process {
        id: bindWriter
        property string scriptBody: ""
        command: [
            "sh", "-c",
            "mkdir -p -- \"$1\" && printf '%s' \"$2\" > \"$3\" && hyprctl reload",
            "bindwrite",
            page.home + "/.config/quickshell/state",
            scriptBody,
            page.bindsPath
        ]
        onExited: code => {
            if (code !== 0)
                console.warn("KeybindsPage: bind save/reload failed (" + code + ")")
        }
    }

    FileView {
        id: customFile
        path: page.customPath
        printErrors: false
        onLoaded: page.parseCustom(text())
    }

    // Writes custom_binds.json (for this page) and custom_binds.lua (for
    // Hyprland), then reloads Hyprland.
    Process {
        id: customWriter
        property string jsonBody: ""
        property string luaBody: ""
        command: [
            "sh", "-c",
            "mkdir -p -- \"$1\" && printf '%s' \"$2\" > \"$3\" && printf '%s' \"$4\" > \"$5\" && hyprctl reload",
            "customwrite",
            page.home + "/.config/quickshell/state",
            jsonBody,
            page.customPath,
            luaBody,
            page.customLuaPath
        ]
        onExited: code => {
            if (code !== 0)
                console.warn("KeybindsPage: custom bind save/reload failed (" + code + ")")
        }
    }

    Process {
        id: detect
        running: true
        command: ["sh", "-c",
            "for b in " + page.browsers.map(x => x.bin).join(" ") +
            "; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b\"; done"]
        stdout: StdioCollector {
            onStreamFinished: page.installed = text.split("\n").filter(s => s.length > 0)
        }
    }

    // ------------------------------------------------------------------
    // Components
    // ------------------------------------------------------------------

    component SectionTitle: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSizeSection
        font.bold: true
        font.letterSpacing: 2
    }

    component InputField: TextField {
        id: fld
        height: 34
        placeholderTextColor: Theme.textDim
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSizeGroup
        font.bold: true
        font.letterSpacing: 1
        selectByMouse: true
        background: Rectangle {
            radius: Theme.radius
            color: "#00000000"
            border.width: 1
            border.color: fld.activeFocus ? Theme.accent : Theme.border
        }
    }

    component Card: Rectangle {
        id: card
        default property alias contentData: cardColumn.data
        width: parent.width
        height: cardColumn.implicitHeight + 28
        radius: Theme.radius
        color: "#00000000"
        border.width: 1
        border.color: Theme.border

        Column {
            id: cardColumn
            x: 14; y: 14
            width: parent.width - 28
            spacing: 16
        }
    }

    component ChoiceButton: Rectangle {
        id: choice
        property string label: ""
        property bool current: false
        signal clicked()

        height: 34
        radius: Theme.radius
        color: current ? Theme.alpha(Theme.accent, 0.10)
                       : (choiceMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
        border.width: 1
        border.color: current || choiceMouse.containsMouse ? Theme.accent : Theme.border

        Text {
            anchors.centerIn: parent
            text: choice.label
            color: choice.current ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeGroup
            font.bold: true
            font.letterSpacing: 1
        }

        MouseArea {
            id: choiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.clicked()
        }
    }

    component TinyButton: Rectangle {
        id: tiny
        property string label: ""
        signal clicked()

        height: 18
        width: tinyText.implicitWidth + 12
        radius: Theme.radius
        color: tinyMouse.containsMouse ? Theme.alpha(Theme.accent, 0.10) : "#00000000"
        border.width: 1
        border.color: tinyMouse.containsMouse ? Theme.accent : Theme.border

        Text {
            id: tinyText
            anchors.centerIn: parent
            text: tiny.label
            color: tinyMouse.containsMouse ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, Theme.textSizeSmall - 2)
            font.bold: true
            font.letterSpacing: 1
        }

        MouseArea {
            id: tinyMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tiny.clicked()
        }
    }

    component HelpText: Text {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSizeSmall
    }
    component CodeBlock: Rectangle {
        property alias text: codeText.text
        width: parent.width
        height: codeText.implicitHeight + 16
        radius: Theme.radius
        color: Theme.alpha(Theme.accent, 0.06)
        border.width: 1
        border.color: Theme.border
        Text {
            id: codeText
            x: 8; y: 8
            width: parent.width - 16
            wrapMode: Text.WrapAnywhere
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeSmall
        }
    }

    component BindRow: Rectangle {
        id: row
        required property string bindId
        required property string label
        // Non-empty for fixed (hardcoded) binds: shown as-is, not editable
        property string fixedChord: ""
        property bool noSuper: false
        property bool custom: false
        readonly property bool fixed: fixedChord !== ""

        width: parent.width
        height: 46
        radius: Theme.radius

        color: page.editingId === bindId
               ? Theme.alpha(Theme.accent, 0.12)
               : (rowMouse.containsMouse
                  ? Theme.alpha(Theme.accent, 0.06)
                  : "#00000000")

        border.width: 1
        border.color: page.editingId === bindId || rowMouse.containsMouse
                      ? Theme.accent : Theme.border

        Column {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: fixedTag.visible ? fixedTag.width + 20
                                 : (customTools.visible ? customTools.width + 20 : 10)
            anchors.topMargin: 5
            anchors.bottomMargin: 5
            spacing: 2

            Text {
                width: parent.width
                text: row.label
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeGroup
                font.bold: true
                font.letterSpacing: 1
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: row.fixed
                      ? row.fixedChord
                      : (page.editingId === row.bindId
                         ? "PRESS A KEY"
                         : (row.noSuper
                            ? page.prettyKey(row.bindId).toUpperCase()
                            : "SUPER + " + page.prettyKey(row.bindId)))
                color: page.editingId === row.bindId
                       ? Theme.accent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeSmall
                font.bold: true
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: !row.fixed
            cursorShape: row.fixed ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!row.fixed) page.beginEdit(row.bindId)
        }

        // Small tag on binds that cannot be edited
        Rectangle {
            id: fixedTag
            visible: row.fixed
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 18
            width: fixedTagText.implicitWidth + 12
            radius: Theme.radius
            color: "#00000000"
            border.width: 1
            border.color: Theme.border

            Text {
                id: fixedTagText
                anchors.centerIn: parent
                text: "FIXED"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.textSizeSmall - 2)
                font.bold: true
                font.letterSpacing: 1
            }
        }

        // Edit / delete for user-created binds
        Row {
            id: customTools
            visible: row.custom
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            TinyButton { label: "EDIT"; onClicked: page.openForm(row.bindId) }
            TinyButton { label: "DELETE"; onClicked: page.deleteCustom(row.bindId) }
        }
    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom
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
            spacing: 14

            Text {
                text: "KEYBINDS"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeTitle
                font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Column {
                width: parent.width
                spacing: 10
                topPadding: 6

                Card {
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 8

                            InputField {
                                id: bindSearch
                                width: parent.width - newBtn.width - parent.spacing
                                placeholderText: "SEARCH"
                                onTextChanged: page.bindQuery = text
                                Keys.onEscapePressed: function(event) {
                                    if (text !== "") {
                                        page.bindQuery = ""
                                        text = ""
                                        event.accepted = true
                                    } else {
                                        focus = false
                                        page.closeRequested()
                                    }
                                }
                            }

                            ChoiceButton {
                                id: newBtn
                                width: 150
                                label: "+ NEW KEYBIND"
                                current: page.formOpen && page.formId === ""
                                onClicked: (page.formOpen && page.formId === "")
                                           ? page.closeForm() : page.openForm("")
                            }
                        }

                        // New / edit custom keybind form
                        Column {
                            width: parent.width
                            spacing: 8
                            visible: page.formOpen

                            Rectangle { width: parent.width; height: 1; color: Theme.border }

                            Text {
                                text: page.formId !== "" ? "EDIT KEYBIND" : "NEW KEYBIND"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSizeGroup
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            InputField {
                                id: formNameField
                                width: parent.width
                                placeholderText: "NAME (e.g. SCREENSHOT TOOL)"
                                onTextChanged: page.formName = text
                                Keys.onReturnPressed: formCmdField.forceActiveFocus()
                                Keys.onEscapePressed: page.closeForm()
                            }

                            InputField {
                                id: formCmdField
                                width: parent.width
                                placeholderText: "COMMAND (e.g. firefox --private-window)"
                                onTextChanged: page.formCmd = text
                                Keys.onReturnPressed: page.submitForm()
                                Keys.onEscapePressed: page.closeForm()
                            }

                            ChoiceButton {
                                width: parent.width
                                label: page.editingId === page.formCaptureId
                                       ? "PRESS A KEY"
                                       : (page.formKey !== ""
                                          ? "KEY: " + page.prettyKey(page.formCaptureId).toUpperCase()
                                          : "SET KEY")
                                current: page.editingId === page.formCaptureId
                                onClicked: page.beginEdit(page.formCaptureId)
                            }

                            Text {
                                visible: page.editingId === page.formCaptureId
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Press the combo now. SUPER is NOT added automatically; "
                                      + "hold it if you want it. Escape cancels."
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSizeSmall
                                font.bold: true
                            }

                            Text {
                                visible: page.captureHint !== "" && page.editingId === page.formCaptureId
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: page.captureHint
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSizeSmall
                            }

                            Text {
                                visible: page.formConflict !== ""
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "This key is already used by " + page.formConflict + "."
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSizeSmall
                            }

                            Row {
                                width: parent.width
                                spacing: 8

                                ChoiceButton {
                                    width: (parent.width - parent.spacing) / 2
                                    label: page.formId !== "" ? "SAVE" : "ADD KEYBIND"
                                    current: page.formValid
                                    opacity: page.formValid ? 1 : 0.4
                                    onClicked: page.submitForm()
                                }
                                ChoiceButton {
                                    width: (parent.width - parent.spacing) / 2
                                    label: "CANCEL"
                                    onClicked: page.closeForm()
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: Theme.border }
                        }

                        Grid {
                            id: bindGrid
                            width: parent.width
                            columns: 2
                            spacing: 8
                            property real cellWidth: (width - spacing) / 2
                            Repeater {
                                model: page.shownBinds
                                delegate: BindRow {
                                    required property var modelData
                                    width: bindGrid.cellWidth
                                    bindId: modelData.id
                                    label: modelData.label
                                    fixedChord: modelData.chord || ""
                                    noSuper: modelData.noSuper === true
                                    custom: modelData.custom === true
                                }
                            }
                        }

                        Text {
                            visible: page.shownBinds.length === 0
                            width: parent.width
                            text: "NO MATCHES"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSizeGroup
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Column {
                            width: parent.width
                            spacing: 6
                            visible: page.editingId !== "" && page.editingId !== page.formCaptureId

                            Rectangle { width: parent.width; height: 1; color: Theme.border }

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Listening for "
                                      + page.labelOf(page.editingId)
                                      + ". Press the combo now. "
                                      + (page.isNoSuper(page.editingId)
                                         ? "SUPER is NOT added for this bind; hold it if you want it. "
                                         : "SUPER is added automatically. ")
                                      + "Escape cancels. Hyprland reloads as soon as the key is saved."
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSizeSmall
                                font.bold: true
                            }

                            Text {
                                visible: page.captureHint !== ""
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: page.captureHint
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSizeSmall
                            }
                        }
                    }
                }
            }
            Column {
                width: parent.width
                spacing: 10
                topPadding: 6

                SectionTitle { text: "DEFAULT BROWSER" }

                Card {
                    Flow {
                        id: browserFlow
                        width: parent.width
                        spacing: page.sectionSpacing
                        readonly property int cols: 4

                        Repeater {
                            model: page.browsers.filter(b =>
                                page.installed.indexOf(b.bin) >= 0 || b.bin === page.browserBin)

                            delegate: ChoiceButton {
                                required property var modelData
                                width: (browserFlow.width - browserFlow.spacing * (browserFlow.cols - 1)) / browserFlow.cols
                                label: modelData.label
                                current: page.browserBin === modelData.bin
                                onClicked: page.setBrowser(modelData)
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10
                topPadding: 6

                SectionTitle { text: "HELP" }

                Card {
                    Column {
                        width: parent.width
                        spacing: 10

                        Row {
                            width: parent.width
                            Text {
                                width: parent.width - helpToggle.width
                                height: helpToggle.height
                                verticalAlignment: Text.AlignVCenter
                                text: "NEW KEYBINDS"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSizeGroup
                                font.bold: true
                                font.letterSpacing: 1
                            }
                            TinyButton {
                                id: helpToggle
                                label: page.helpOpen ? "HIDE" : "SHOW"
                                onClicked: page.helpOpen = !page.helpOpen
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: page.helpOpen

                            Rectangle { width: parent.width; height: 1; color: Theme.border }

                            HelpText { text: "COMMAND EXAMPLES"; color: Theme.text; font.bold: true }
                            CodeBlock {
                                text: "kitty\n"
                                    + "firefox --private-window\n"
                                    + "sh -c 'grim -g \"$(slurp)\" - | wl-copy'"
                            }
                            HelpText {
                                text: "Wrap commands that use pipes, quotes or $(...) in sh -c '...'."
                            }

                            HelpText { text: "KEY FORMAT"; color: Theme.text; font.bold: true }
                            CodeBlock {
                                text: "SUPER + SHIFT + Return\n"
                                    + "CTRL + ALT + Delete"
                            }

                            HelpText { text: "ADDING KEYBINDS MANUALLY"; color: Theme.text; font.bold: true }
                            HelpText {
                                text: "Built-in binds: edit ~/.config/quickshell/state/binds.lua, one line per bind "
                                      + "(no SUPER, it is prepended by keybinds.lua):"
                            }
                            CodeBlock { text: "kb_terminal = \"T\"\nkb_theme = \"period\"" }
                            HelpText {
                                text: "Custom binds: keep two files in sync in the same folder. "
                                      + "custom_binds.json is read by this page; custom_binds.lua is read by Hyprland."
                            }
                            CodeBlock {
                                text: "// custom_binds.json\n"
                                    + "[{ \"id\": \"c1\", \"label\": \"Private browser\",\n"
                                    + "   \"cmd\": \"firefox --private-window\", \"key\": \"SUPER + P\" }]\n\n"
                                    + "-- custom_binds.lua\n"
                                    + "return {\n"
                                    + "    { key = \"SUPER + P\", cmd = \"firefox --private-window\", label = \"Private browser\" },\n"
                                    + "}"
                            }
                            HelpText {
                                text: "Then run hyprctl reload. Saving from this page regenerates both files, "
                                      + "so manual edits to the Lua files alone will be overwritten."
                            }
                        }
                    }
                }
            }
        }
    }
}