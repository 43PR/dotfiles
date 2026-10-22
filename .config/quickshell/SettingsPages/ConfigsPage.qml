// .config/quickshell/SettingsPages/ConfigsPage.qml
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
    readonly property string prefsPath: home + "/.config/quickshell/state/prefs.lua"
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

    property string browserBin: "brave"
    property var installed: []
    property bool reloadAfterSave: false

    // Editable binds (saved to state/binds.lua as kb_<id>)
    readonly property var bindDefs: [
        { id: "terminal",      label: "TERMINAL",                    def: "T" },
        { id: "launcher",      label: "LAUNCHER",                    def: "D" },
        { id: "files",         label: "FILE MANAGER",                def: "E" },
        { id: "browser",       label: "BROWSER",                     def: "B" },
        { id: "settings",      label: "SETTINGS",                    def: "I" },
        { id: "wheel",         label: "QUICK ACTIONS",               def: "S" },
        { id: "close",         label: "CLOSE ACTIVE WINDOW",         def: "Q" },
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

    function isNoSuper(id) {
        return bindDefs.find(d => d.id === id)?.noSuper === true
    }

    function chordOf(d) {
        if (d.chord) return d.chord
        if (d.noSuper) return prettyKey(d.id).toUpperCase()
        return "SUPER + " + prettyKey(d.id)
    }

    readonly property var shownBinds: {
        const q = bindQuery.trim().toLowerCase()
        const all = bindDefs.concat(fixedBinds)
        if (!q) return all
        return all.filter(d =>
            d.label.toLowerCase().indexOf(q) >= 0 ||
            chordOf(d).toLowerCase().indexOf(q) >= 0)
    }

    function isBrowser(b) { return browsers.some(x => x.bin === b) }

    function initBindKeys() {
        const o = {}
        for (const d of bindDefs)
            o[d.id] = d.def
        bindKeys = o
    }

    function keyOf(id) {
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
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1)
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
        searchFocusReleased()
    }
    function captureKey(event) {
        if (bindSearch.activeFocus) return
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

    function parsePrefs(text) {
        const b = /^\s*browser\s*=\s*"([^"]+)"/m.exec(text)
        if (b && isBrowser(b[1])) browserBin = b[1]
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

    function savePrefs() {
        prefsFile.setText(
            "-- Generated by Quickshell (Settings > Configs). Do not edit by hand.\n" +
            "browser = \"" + browserBin + "\"\n")
    }

    function saveBinds() {
        let body = "-- Generated by Quickshell (Settings > Configs). Do not edit by hand.\n"
        for (const d of bindDefs)
            body += luaName(d.id) + " = \"" + keyOf(d.id) + "\"\n"
        bindWriter.scriptBody = body
        bindWriter.running = false
        bindWriter.running = true
    }

    function setBrowser(b) {
        if (b.bin === browserBin) return
        browserBin = b.bin
        Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", b.desktop])
        savePrefs()
    }

    function editConfig(path) {
        Quickshell.execDetached([
            "xed",
            path.replace(/^~/, Quickshell.env("HOME"))
        ])
    }

    Component.onCompleted: initBindKeys()

    // Invisible focus target. While a row is selected, the next real key
    // (Super+Enter, Super+Shift+C, …) is written and Hyprland is reloaded.
    Item {
        id: keyGrabber
        focus: page.editingId !== ""
        Keys.onPressed: function(event) { page.captureKey(event) }
    }

    FileView {
        id: prefsFile
        path: page.prefsPath
        printErrors: false
        onLoaded: page.parsePrefs(text())
        onSaveFailed: error => console.warn("ConfigsPage: prefs write failed: " + error)
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
                console.warn("ConfigsPage: bind save/reload failed (" + code + ")")
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

    component GroupLabel: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSizeGroup
        font.bold: true
        font.letterSpacing: 1
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

    component BindRow: Rectangle {
        id: row
        required property string bindId
        required property string label
        // Non-empty for fixed (hardcoded) binds: shown as-is, not editable
        property string fixedChord: ""
        property bool noSuper: false
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
            anchors.rightMargin: 10
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
    }

    component ConfigButton: Rectangle {
        required property string label
        required property string path

        width: parent.width
        height: 42
        radius: Theme.radius
        color: "#00000000"
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeGroup
            font.bold: true
            font.letterSpacing: 2
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: ""
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.textSizeGroup
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "EDIT " + path.split("/").pop().toUpperCase()
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeGroup
                font.bold: true
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                parent.color = Theme.alpha(Theme.accent, 0.08)
                parent.border.color = Theme.accent
            }
            onExited: {
                parent.color = "#00000000"
                parent.border.color = Theme.border
            }
            onClicked: page.editConfig(path)
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
                text: "CONFIGS"
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

                SectionTitle { text: "KEYBINDS" }

                Card {
                    Column {
                        width: parent.width
                        spacing: 8

                        TextField {
                            id: bindSearch
                            width: parent.width
                            height: 34
                            placeholderText: "SEARCH"
                            placeholderTextColor: Theme.textDim
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSizeGroup
                            font.bold: true
                            font.letterSpacing: 1
                            selectByMouse: true
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
                            background: Rectangle {
                                radius: Theme.radius
                                color: "#00000000"
                                border.width: 1
                                border.color: bindSearch.activeFocus ? Theme.accent : Theme.border
                            }
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
                            visible: page.editingId !== ""

                            Rectangle { width: parent.width; height: 1; color: Theme.border }

                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Listening for "
                                      + (page.bindDefs.find(d => d.id === page.editingId)?.label || "")
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

                SectionTitle { text: "HYPRLAND" }

                Card {
                    Column {
                        width: parent.width
                        spacing: page.sectionSpacing

                        GroupLabel { text: "CONFIG FILES" }

                        ConfigButton {
                            label: "PROGRAMS - AUTOSTART - INPUT"
                            path: "~/.config/hypr/hyprland.lua"
                        }
                        ConfigButton {
                            label: "MONITORS - WORKSPACES"
                            path: "~/.config/hypr/monitors.lua"
                        }
                        ConfigButton {
                            label: "LOOK AND FEEL"
                            path: "~/.config/hypr/look.lua"
                        }
                        ConfigButton {
                            label: "KEYBINDS"
                            path: "~/.config/hypr/keybinds.lua"
                        }
                        ConfigButton {
                            label: "RULES"
                            path: "~/.config/hypr/rules.lua"
                        }
                        ConfigButton {
                            label: "LOCK SCREEN"
                            path: "~/.config/hypr/hyprlock.conf"
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10
                topPadding: 6
                bottomPadding: 6

                SectionTitle { text: "ROFI" }

                Card {
                    Column {
                        width: parent.width
                        spacing: page.sectionSpacing

                        GroupLabel { text: "CONFIG FILES" }

                        ConfigButton {
                            label: "CONFIG"
                            path: "~/.config/rofi/config.rasi"
                        }
                    }
                }
            }
        }
    }
}