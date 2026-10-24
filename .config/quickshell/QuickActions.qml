pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth

Scope {
    id: root
    // ---- lifecycle -------------------------------------------------------
    property bool showing: false      // logical "menu is open"
    property bool mounted: false      // window exists
    property var targetScreen: Quickshell.screens[0]
    property real winW: 0             // reported by the window while mounted
    property real winH: 0

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            unmountTimer.restart()
        }
    }

    // must be longer than the longest fade-out (panel opacity = animMs)
    Timer {
        id: unmountTimer
        interval: root.animMs + 120
        onTriggered: {
            root.mounted = false
            root.winW = 0
            root.winH = 0
        }
    }

    // ---- settings specs (numbers) ----------------------------------------
    readonly property var numSpec: ({
        menuSize:     { min: 70,  max: 260, def: 100, step: 10, unit: "%" },
        animMs:       { min: 0,   max: 500, def: 200, step: 20, unit: " ms" },

        cardWidth:    { min: 60,  max: 700, def: 284, step: 5,  unit: "px" },
        itemHeight:   { min: 40,  max: 120, def: 56,  step: 4,  unit: "px" },
        itemSpacing:  { min: 0,   max: 24,  def: 8,   step: 2,  unit: "px" },
        panelPadding: { min: 0,   max: 24,  def: 6,   step: 2,  unit: "px" },
        topGap:       { min: 0,   max: 120, def: 12,  step: 4,  unit: "px" },
        sideGap:      { min: 0,   max: 120, def: 24,  step: 4,  unit: "px" },

        panelRadius:  { min: 0,   max: 40,  def: 20,  step: 2,  unit: "px" },
        itemRadius:   { min: 0,   max: 40,  def: 12,  step: 2,  unit: "px" },
        iconSize:     { min: 12,  max: 56,  def: 20,  step: 2,  unit: "px" },
        labelSize:    { min: 9,   max: 22,  def: 11,  step: 1,  unit: "px" },
        borderWidth:  { min: 0,   max: 4,   def: 1,   step: 1,  unit: "px" },

        panelOpacity: { min: 0,   max: 100, def: 0,   step: 5,  unit: "%" },
        itemOpacity:  { min: 0,   max: 100, def: Math.round((Theme.bg.a ?? 1) * 20) * 5, step: 5, unit: "%" },
        hoverBoost:   { min: 0,   max: 40,  def: 12,  step: 2,  unit: "%" },
        dimOpacity:   { min: 0,   max: 100, def: 0,   step: 5,  unit: "%" },

        brightnessStep: { min: 1, max: 20,  def: 5,   step: 1,  unit: "%" },
        nightTemp:      { min: 2500, max: 6500, def: 4500, step: 100, unit: " K" },
        nightStep:      { min: 50,   max: 500,  def: 100,  step: 50,  unit: " K" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showTooltips: true,
        horizontal: false,
        showIcons: true,
        showLabels: true,
        showKeyHints: true,
        showState: true,
        showFooter: true,
        wrapNav: true,
        hoverSelect: true,
        closeOnOutside: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    readonly property var posKeys: ["offsetX", "offsetY"]

    property real offsetX: 0
    property real offsetY: 0

    property int menuSize: numSpec.menuSize.def
    property int animMs: numSpec.animMs.def
    property int cardWidth: numSpec.cardWidth.def
    property int itemHeight: numSpec.itemHeight.def
    property int itemSpacing: numSpec.itemSpacing.def
    property int panelPadding: numSpec.panelPadding.def
    property int topGap: numSpec.topGap.def
    property int sideGap: numSpec.sideGap.def
    property int panelRadius: numSpec.panelRadius.def
    property int itemRadius: numSpec.itemRadius.def
    property int iconSize: numSpec.iconSize.def
    property int labelSize: numSpec.labelSize.def
    property int borderWidth: numSpec.borderWidth.def
    property int panelOpacity: numSpec.panelOpacity.def
    property int itemOpacity: numSpec.itemOpacity.def
    property int hoverBoost: numSpec.hoverBoost.def
    property int dimOpacity: numSpec.dimOpacity.def
    property int brightnessStep: numSpec.brightnessStep.def
    property int nightTemp: numSpec.nightTemp.def
    property int nightStep: numSpec.nightStep.def

    property bool showTooltips: boolDefaults.showTooltips
    property bool horizontal: boolDefaults.horizontal
    property bool showIcons: boolDefaults.showIcons
    property bool showLabels: boolDefaults.showLabels
    property bool showKeyHints: boolDefaults.showKeyHints
    property bool showState: boolDefaults.showState
    property bool showFooter: boolDefaults.showFooter
    property bool wrapNav: boolDefaults.wrapNav
    property bool hoverSelect: boolDefaults.hoverSelect
    property bool closeOnOutside: boolDefaults.closeOnOutside

    property bool settingsOpen: false
    property bool dragging: false
    property int currentIndex: 0
    property var hiddenNames: []

    // ---- quick-action state -----------------------------------------------
    property string iconFont: "Symbols Nerd Font"
    property bool wifiOn: false
    property bool nightOn: false
    property bool dndOn: false
    property real brightness: 0.6          // 0..1, synced from brightnessctl
    readonly property bool btOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false

    readonly property int edgeGap: 0
    // how much of the panel must stay on screen when dragged past borders
    readonly property int keepVisible: 40

    // box around the glyph = icon + 12px
    readonly property int iconBox: showIcons ? iconSize + 12 : 0

    // colours derived from the theme + opacity settings
    readonly property color panelColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, panelOpacity / 100)
    readonly property color itemColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, itemOpacity / 100)
    readonly property color itemHoverColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b,
                                                    Math.min(1, itemOpacity / 100 + hoverBoost / 100))

    readonly property bool movedFromDefault: posKeys.some(k => root[k] !== 0)

    readonly property bool modified:
        posKeys.some(k => root[k] !== 0)
        || numKeys.some(k => root[k] !== numSpec[k].def)
        || boolKeys.some(k => root[k] !== boolDefaults[k])
        || hiddenNames.length > 0

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/quickactions-state.json"

    // ---- actions ----------------------------------------------------------
    readonly property var actions: [
        { name: "area",   label: "Area screenshot", key: "a", toggle: false,
          cmd: ["sh", "-c", "sleep 0.25; exec \"$HOME/.config/hypr/scripts/screenshot-area.sh\""] },
        { name: "wifi",   label: "Wi-Fi",           key: "w", toggle: true },
        { name: "bt",     label: "Bluetooth",       key: "b", toggle: true },
        { name: "dnd",    label: "Do not disturb",  key: "d", toggle: true },
        { name: "night",  label: "Night light",     key: "n", toggle: true, adjustTemp: true },
        { name: "bright", label: "Brightness",      key: "l", toggle: false, adjust: true }
    ]

    readonly property var visibleActions: actions.filter(function (a) {
        return root.hiddenNames.indexOf(a.name) < 0
    })

    // rows shown in the "Keybinds" section at the end of the settings menu
    readonly property var keybindInfo: [
        { keys: "Esc / Click outside",    desc: "Close menu / settings" },
        { keys: "↑ ↓ ← → Tab",            desc: "Move selection" },
        { keys: "Enter / Space / LMB",    desc: "Run / toggle selected" },
        { keys: "+ - PgUp PgDn / Scroll", desc: "Adjust brightness / night light (when selected)" },
        { keys: "C / RMB (any button)",   desc: "Open settings" }
    ].concat(actions.map(function (a) {
        return { keys: a.key.toUpperCase(), desc: a.label }
    })).concat([
        { keys: "Drag handle",            desc: "Move the menu" }
    ])

    function isOn(name) {
        switch (name) {
        case "wifi":  return wifiOn
        case "bt":    return btOn
        case "night": return nightOn
        case "dnd":   return dndOn
        }
        return false
    }

    function iconFor(name) {
        switch (name) {
        case "area":   return "\uf125"
        case "wifi":   return wifiOn ? "\udb81\udda9" : "\udb81\uddaa"   // 󰖩 / 󰖪
        case "bt":     return btOn ? "\udb80\udcaf" : "\udb80\udcb2"      // 󰂯 / 󰂲
        case "night":  return "\uf186"                                    //  moon
        case "dnd":    return dndOn ? "\udb80\udc9b" : "\udb80\udc9a"    // 󰂛 / 󰂚
        case "bright": return "\uf185"                                    //  sun
        }
        return ""
    }

    function stateText(a) {
        if (a.adjust) return Math.round(root.brightness * 100) + "%"
        if (a.adjustTemp) return (root.nightOn ? "ON " : "OFF ") + root.nightTemp + "K"
        if (a.toggle) return root.isOn(a.name) ? "ON" : "OFF"
        return ""
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    // ---- state readers ----------------------------------------------------
    Process {
        id: wifiCheck
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiOn = text.trim() === "enabled"
        }
    }

    Process {
        id: nightCheck
        command: ["pgrep", "-x", "gammastep"]
        onExited: function (code) { root.nightOn = (code === 0) }
    }

    Process {
        id: dndCheck
        command: ["qs", "ipc", "call", "notifications", "isDnd"]
        stdout: StdioCollector {
            onStreamFinished: root.dndOn = text.trim() === "true"
        }
    }

    Process {
        id: brightCheck
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(",")
                if (parts.length >= 4) {
                    var pct = parseInt(parts[3])
                    if (!isNaN(pct)) root.brightness = pct / 100
                }
            }
        }
    }

    function refreshStates() {
        wifiCheck.running = true
        nightCheck.running = true
        dndCheck.running = true
        brightCheck.running = true
    }

    // re-sync with reality shortly after a toggle
    Timer {
        id: recheckTimer
        interval: 700
        onTriggered: root.refreshStates()
    }

    // ---- brightness (throttled so dragging doesn't spawn a process per px)
    Timer {
        id: brightApplyTimer
        interval: 60
        onTriggered: Quickshell.execDetached({
            command: ["brightnessctl", "set", Math.round(root.brightness * 100) + "%"]
        })
    }

    // floor of 1% so you can't scroll the screen fully black
    function setBrightness(pct) {
        root.brightness = Math.max(0.01, Math.min(1, pct / 100))
        brightApplyTimer.restart()
    }

    function adjustBrightness(deltaPct) {
        setBrightness(root.brightness * 100 + deltaPct)
    }

    function selectedIsAdjust() {
        var a = root.visibleActions[root.currentIndex]
        return a !== undefined && a.adjust === true
    }

    function selectedIsTemp() {
        var a = root.visibleActions[root.currentIndex]
        return a !== undefined && a.adjustTemp === true
    }

    // ---- night light temperature (throttled; re-applied live if it's on) --
    Timer {
        id: nightApplyTimer
        interval: 150
        onTriggered: {
            if (root.nightOn)
                Quickshell.execDetached({ command: ["sh", "-c",
                    "pkill -x gammastep; sleep 0.15; exec gammastep -O " + root.nightTemp] })
            root.saveState()
        }
    }

    function setNightTemp(k) {
        var s = root.numSpec.nightTemp
        root.nightTemp = root.clamp(k, s.min, s.max)
        nightApplyTimer.restart()
    }

    function adjustNight(deltaK) {
        setNightTemp(root.nightTemp + deltaK)
    }

    // + / PgUp / scroll up / bar right = warmer-to-cooler (higher K)
    function adjustSelected(dir) {
        if (root.selectedIsAdjust())
            root.adjustBrightness(dir * root.brightnessStep)
        else if (root.selectedIsTemp())
            root.adjustNight(dir * root.nightStep)
    }

    // ---- bluetooth: disconnect devices first, then power off --------------
    Timer {
        id: btOffTimer
        interval: 400
        onTriggered: {
            if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = false
        }
    }

    function toggleBluetooth() {
        var a = Bluetooth.defaultAdapter
        if (!a) return
        if (a.enabled) {
            var devs = a.devices.values
            for (var i = 0; i < devs.length; i++) {
                if (devs[i].connected) devs[i].disconnect()
            }
            btOffTimer.restart()
        } else {
            a.enabled = true
        }
    }

    function toggleItem(name) {
        switch (name) {
        case "wifi":
            Quickshell.execDetached({ command: ["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"] })
            root.wifiOn = !root.wifiOn
            break
        case "bt":
            toggleBluetooth()
            break
        case "night":
            if (root.nightOn)
                Quickshell.execDetached({ command: ["pkill", "-x", "gammastep"] })
            else
                Quickshell.execDetached({ command: ["gammastep", "-O", String(root.nightTemp)] })
            root.nightOn = !root.nightOn
            break
        case "dnd":
            Quickshell.execDetached({ command: ["qs", "ipc", "call", "notifications", "dnd"] })
            root.dndOn = !root.dndOn
            break
        }
        recheckTimer.restart()
    }

    function runAction(a) {
        if (!a) return
        // the menu stays visible while settings are open for live preview,
        // so never fire real actions from it
        if (root.settingsOpen)
            return
        if (a.adjust)
            return
        if (a.toggle) {
            root.toggleItem(a.name)
        } else {
            root.closeMenu()
            Quickshell.execDetached({ command: a.cmd })
        }
    }

    function moveSelection(d) {
        var n = root.visibleActions.length
        if (n <= 0) return
        var i = root.currentIndex + d
        if (root.wrapNav)
            i = (i % n + n) % n
        else
            i = Math.max(0, Math.min(n - 1, i))
        root.currentIndex = i
    }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.targetScreen = scr
        }
        currentIndex = 0
        settingsOpen = false
        dragging = false
        refreshStates()
        showing = true   // onShowingChanged mounts the window
    }

    function closeMenu() {
        showing = false
        settingsOpen = false
        dragging = false
    }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    function openSettings() {
        if (!showing) openMenu()
        dragging = false
        settingsOpen = true
    }
    function closeSettings() {
        settingsOpen = false
        dragging = false
    }
    function toggleSettings() { settingsOpen ? closeSettings() : openSettings() }

    // ---- settings helpers --------------------------------------------------
    function fmtValue(key, v) {
        var s = numSpec[key]
        return v + s.unit
    }

    function reclamp() {
        if (root.showing)
            root.setPosition(root.offsetX, root.offsetY)
    }

    function setNumber(key, v) {
        var s = numSpec[key]
        root[key] = clamp(v, s.min, s.max)
        reclamp()
    }

    function toggleSetting(key) {
        root[key] = !root[key]
        reclamp()
        saveState()
    }

    function toggleAction(name) {
        var h = root.hiddenNames.slice()
        var i = h.indexOf(name)
        if (i >= 0)
            h.splice(i, 1)
        else if (root.visibleActions.length > 1)
            h.push(name)
        root.hiddenNames = h
        if (root.currentIndex >= root.visibleActions.length)
            root.currentIndex = 0
        root.saveState()
    }

    function resetPosition() {
        root.offsetX = 0
        root.offsetY = 0
        root.saveState()
    }

    function resetAll() {
        posKeys.forEach(function (k) { root[k] = 0 })
        numKeys.forEach(function (k) { root[k] = numSpec[k].def })
        boolKeys.forEach(function (k) { root[k] = boolDefaults[k] })
        root.hiddenNames = []
        root.currentIndex = 0
        reclamp()
        saveState()
    }

    function saveState() {
        var s = { hidden: root.hiddenNames }
        posKeys.forEach(function (k) { s[k] = root[k] })
        numKeys.forEach(function (k) { s[k] = root[k] })
        boolKeys.forEach(function (k) { s[k] = root[k] })
        stateFile.setText(JSON.stringify(s))
    }

    // Allows the panel to go past the screen borders (left, right, bottom),
    // keeping at least `keepVisible` px on screen. Top is kept on screen so the
    // drag handle always stays reachable.
    function setPosition(x, y) {
        if (root.winW <= 0 || root.winH <= 0) {
            root.offsetX = x
            root.offsetY = y
            return
        }
        var s = root.menuSize / 100
        var kv = root.keepVisible
        var minX = kv - root.winW + root.sideGap
        var maxX = root.sideGap + root.cardWidth * s - kv
        var minY = root.edgeGap - root.topGap
        var maxY = Math.max(minY, root.winH - kv - root.topGap)
        root.offsetX = Math.max(minX, Math.min(maxX, x))
        root.offsetY = Math.max(minY, Math.min(maxY, y))
    }

    // ---- always-on services (cheap) --------------------------------------
    // target stays "wheel" so existing keybinds (qs ipc call wheel toggle) keep working
    IpcHandler {
        target: "qa"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
        function settings(): void { root.openSettings() }
        function confirm(): void {
            if (!root.showing) return
            var a = root.visibleActions[root.currentIndex]
            if (a) root.runAction(a)
            else root.closeMenu()
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                var valid = root.actions.map(function (a) { return a.name })

                if (Array.isArray(s.hidden)) {
                    var h = s.hidden.filter(function (n) { return valid.indexOf(n) >= 0 })
                    if (h.length < valid.length) root.hiddenNames = h
                }

                root.posKeys.forEach(function (k) {
                    if (typeof s[k] === "number")
                        root[k] = s[k]
                })
                root.numKeys.forEach(function (k) {
                    if (typeof s[k] === "number") {
                        var spec = root.numSpec[k]
                        root[k] = root.clamp(s[k], spec.min, spec.max)
                    }
                })
                root.boolKeys.forEach(function (k) {
                    if (typeof s[k] === "boolean")
                        root[k] = s[k]
                })
            } catch (e) {
                console.warn("quickactions: could not read saved state:", e)
            }
        }
    }

    // ---- the menu window: only exists while mounted -----------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win
            screen: root.targetScreen

            property bool reveal: false

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qa"
            // Released while the settings window is open so that it can
            // take keyboard focus (Escape, etc.).
            WlrLayershell.keyboardFocus: (root.showing && !root.settingsOpen)
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            mask: Region { item: root.showing ? menuRoot : null }

            onWidthChanged: {
                root.winW = width
                if (root.showing) root.setPosition(root.offsetX, root.offsetY)
            }
            onHeightChanged: {
                root.winH = height
                if (root.showing) root.setPosition(root.offsetX, root.offsetY)
            }

            Component.onCompleted: {
                menuRoot.forceActiveFocus()
                root.setPosition(root.offsetX, root.offsetY)
                Qt.callLater(function () {
                    win.reveal = Qt.binding(function () { return root.showing })
                })
            }

            Item {
                id: menuRoot
                anchors.fill: parent
                focus: true
                Keys.onPressed: function (event) {
                    if (!root.showing) return
                    var t = event.text.toLowerCase()

                    if (root.settingsOpen) {
                        if (event.key === Qt.Key_Escape || t === "c")
                            root.closeSettings()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) {
                        root.closeMenu()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Down
                            || event.key === Qt.Key_Right
                            || event.key === Qt.Key_Tab) {
                        root.moveSelection(1)
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Up
                            || event.key === Qt.Key_Left
                            || event.key === Qt.Key_Backtab) {
                        root.moveSelection(-1)
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Space) {
                        root.runAction(root.visibleActions[root.currentIndex])
                        event.accepted = true
                        return
                    }
                    if (root.selectedIsAdjust() || root.selectedIsTemp()) {
                        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal
                                || event.key === Qt.Key_PageUp) {
                            root.adjustSelected(1)
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Minus || event.key === Qt.Key_PageDown) {
                            root.adjustSelected(-1)
                            event.accepted = true
                            return
                        }
                    }
                    if (t === "c") {
                        root.openSettings()
                        event.accepted = true
                        return
                    }
                    for (var i = 0; i < root.visibleActions.length; i++) {
                        if (t === root.visibleActions[i].key) {
                            root.currentIndex = i
                            root.runAction(root.visibleActions[i])
                            event.accepted = true
                            return
                        }
                    }
                    event.accepted = true
                }

                // screen dim
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: win.reveal ? root.dimOpacity / 100 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.animMs } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.settingsOpen)
                            root.closeSettings()
                        else if (root.closeOnOutside)
                            root.closeMenu()
                    }
                }

                Rectangle {
                    id: panel
                    width: root.cardWidth
                    height: panelCol.height + 2 * root.panelPadding
                    radius: root.panelRadius
                    color: root.panelColor
                    transformOrigin: Item.TopRight
                    scale: root.menuSize / 100
                    anchors.top: parent.top
                    anchors.topMargin: root.topGap + root.offsetY
                    anchors.right: parent.right
                    anchors.rightMargin: root.sideGap - root.offsetX
                    opacity: win.reveal ? 1 : 0
                    visible: opacity > 0

                    Behavior on anchors.rightMargin {
                        enabled: !root.dragging && root.showing
                        NumberAnimation { duration: root.animMs * 1.1; easing.type: Easing.OutCubic }
                    }
                    Behavior on anchors.topMargin {
                        enabled: !root.dragging && root.showing
                        NumberAnimation { duration: root.animMs * 1.1; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        enabled: root.showing
                        NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: root.animMs * 0.9; easing.type: Easing.OutCubic }
                    }
                    onHeightChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)

                    // swallow clicks on the panel background (also right clicks)
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                    }

                    Column {
                        id: panelCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: root.panelPadding
                        spacing: 6

                        // ---- drag handle (right click opens settings) ----
                        Item {
                            id: header
                            width: parent.width
                            height: 12
                            z: headerTip.shown ? 100 : 0

                            Rectangle {
                                anchors.centerIn: parent
                                width: 36; height: 4; radius: 2
                                color: Theme.bg
                                opacity: (dragArea.containsMouse || root.dragging) ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property real pressX: 0
                                property real pressY: 0
                                property real startX: 0
                                property real startY: 0
                                onPressed: function (mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        root.openSettings()
                                        return
                                    }
                                    var p = dragArea.mapToItem(menuRoot, mouse.x, mouse.y)
                                    pressX = p.x
                                    pressY = p.y
                                    startX = root.offsetX
                                    startY = root.offsetY
                                    root.dragging = true
                                }
                                onPositionChanged: function (mouse) {
                                    if (!root.dragging) return
                                    var p = dragArea.mapToItem(menuRoot, mouse.x, mouse.y)
                                    root.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
                                }
                                onReleased: {
                                    if (!root.dragging) return
                                    root.dragging = false
                                    root.saveState()
                                }
                                onCanceled: {
                                    if (!root.dragging) return
                                    root.dragging = false
                                    root.saveState()
                                }
                            }

                            QaTip {
                                id: headerTip
                                allowed: root.showTooltips
                                hovered: dragArea.containsMouse && !root.dragging
                                side: "below"
                                text: "Drag to move · right-click: settings"
                            }
                        }

                        // ---- action list (vertical list or horizontal row) ----
                        Grid {
                            id: actionGrid
                            width: parent.width
                            columns: root.horizontal ? Math.max(1, root.visibleActions.length) : 1
                            rowSpacing: root.itemSpacing
                            columnSpacing: root.itemSpacing

                            Repeater {
                                model: root.visibleActions
                                delegate: Rectangle {
                                    id: entry
                                    required property var modelData
                                    required property int index
                                    readonly property bool focused: index === root.currentIndex
                                    readonly property bool isAdjust: modelData.adjust === true
                                    readonly property bool isTemp: modelData.adjustTemp === true
                                    readonly property bool scrollable: isAdjust || isTemp
                                    readonly property bool active: modelData.toggle === true && root.isOn(modelData.name)
                                    readonly property int count: root.visibleActions.length
                                    readonly property bool stateShown: root.showState && !root.horizontal
                                        && (modelData.toggle === true || isAdjust)
                                    // right-hand space reserved for state text + key badge
                                    readonly property real rightReserve: (root.showKeyHints && !root.horizontal ? 36 : 12)
                                        + (stateShown ? (isTemp ? 84 : 44) : 0)

                                    z: entryTip.shown ? 100 : 0
                                    width: root.horizontal
                                        ? Math.max(0, (actionGrid.width - root.itemSpacing * (count - 1)) / count)
                                        : actionGrid.width
                                    height: root.itemHeight
                                    radius: root.itemRadius
                                    color: entryArea.pressed || entryArea.containsMouse || entry.focused
                                        ? root.itemHoverColor
                                        : root.itemColor
                                    border.width: entry.focused ? root.borderWidth : 0
                                    border.color: Theme.accent
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Item {
                                        id: eThumb
                                        visible: root.showIcons
                                        width: root.iconBox
                                        height: root.iconBox
                                        x: root.horizontal ? (entry.width - width) / 2 : 10
                                        y: (root.horizontal && root.showLabels)
                                            ? (entry.height - height - eLabel.implicitHeight - 2) / 2
                                            : (entry.height - height) / 2

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.iconFor(entry.modelData.name)
                                            font.family: root.iconFont
                                            font.pixelSize: root.iconSize
                                            // accent = toggle is ON, normal = off / plain action
                                            color: entry.active || entry.isAdjust
                                                ? Theme.accent
                                                : (entry.focused ? Theme.text : Theme.textDim)
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }

                                    Text {
                                        id: eLabel
                                        visible: root.showLabels
                                        text: entry.modelData.label
                                        font.pixelSize: root.labelSize
                                        font.bold: true
                                        color: Theme.text
                                        elide: Text.ElideRight
                                        horizontalAlignment: root.horizontal ? Text.AlignHCenter : Text.AlignLeft
                                        x: root.horizontal
                                            ? 2
                                            : (root.showIcons ? eThumb.x + eThumb.width + 10 : 14)
                                        y: root.horizontal
                                            ? (root.showIcons
                                                ? eThumb.y + eThumb.height + 2
                                                : (entry.height - implicitHeight) / 2)
                                            : (entry.height - implicitHeight) / 2
                                        width: root.horizontal
                                            ? entry.width - 4
                                            : Math.max(0, entry.width - x - entry.rightReserve)
                                    }

                                    // ON / OFF / brightness %
                                    Text {
                                        visible: entry.stateShown
                                        anchors.right: parent.right
                                        anchors.rightMargin: root.showKeyHints ? 36 : 12
                                        y: (entry.height - implicitHeight) / 2
                                        text: root.stateText(entry.modelData)
                                        font.pixelSize: Math.max(9, root.labelSize - 2)
                                        font.bold: true
                                        color: (entry.active || entry.isAdjust) ? Theme.accent : Theme.textDim
                                    }

                                    Rectangle {
                                        visible: root.showKeyHints && !root.horizontal
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20; height: 20; radius: 6
                                        color: Theme.alpha(Theme.text, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: entry.modelData.key.toUpperCase()
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: Theme.textDim
                                        }
                                    }

                                    MouseArea {
                                        id: entryArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                                        onEntered: if (root.hoverSelect) root.currentIndex = entry.index
                                        onWheel: ev => {
                                            if (entry.scrollable && !root.settingsOpen) {
                                                var dir = ev.angleDelta.y > 0 ? 1 : -1
                                                if (entry.isTemp)
                                                    root.adjustNight(dir * root.nightStep)
                                                else
                                                    root.adjustBrightness(dir * root.brightnessStep)
                                            } else {
                                                ev.accepted = false
                                            }
                                        }
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.openSettings()
                                                return
                                            }
                                            root.currentIndex = entry.index
                                            root.runAction(entry.modelData)
                                        }
                                    }

                                    QaTip {
                                        id: entryTip
                                        allowed: root.showTooltips
                                        hovered: entryArea.containsMouse
                                        side: root.horizontal ? "below" : "left"
                                        text: entry.modelData.label
                                            + (root.stateText(entry.modelData) !== ""
                                                ? ": " + root.stateText(entry.modelData) : "")
                                            + " (" + entry.modelData.key.toUpperCase() + ")"
                                            + (entry.scrollable ? " · scroll to adjust" : "")
                                            + " · right-click: settings"
                                    }
                                }
                            }
                        }

                        // ---- footer: settings button ----
                        Item {
                            visible: root.showFooter
                            width: parent.width
                            height: 16
                            z: footTip.shown ? 100 : 0

                            QaFooterButton {
                                id: footBtn
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                label: "󰒓"
                                fontSize: 12
                                active: root.settingsOpen
                                opacity: (hovered || root.settingsOpen) ? 1 : 0.1
                                onClicked: root.toggleSettings()
                                onRightClicked: root.openSettings()
                            }

                            QaTip {
                                id: footTip
                                allowed: root.showTooltips
                                hovered: footBtn.hovered
                                side: "belowEnd"
                                text: "Settings (C or right-click)"
                            }
                        }
                    }
                }
            }
        }
    }

    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin
            screen: root.targetScreen

            color: "transparent"
            implicitWidth: 420
            implicitHeight: Math.min(640, (screen?.height ?? 800) * 0.85)
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qa-settings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: Theme.bg
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.12)
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.closeSettings()

                // header
                Item {
                    id: head
                    anchors.top: parent.top
                    width: parent.width
                    height: 60

                    Text {
                        x: 20; y: 12
                        text: "Quick actions settings"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.text
                    }
                    Text {
                        x: 20; y: 34
                        text: "Drag the handle to move."
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                    Text {
                        id: closeX
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        y: 10
                        width: 24; height: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "×"
                        font.pixelSize: 22
                        color: closeArea.containsMouse ? Theme.text : Theme.textDim
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.closeSettings()
                        }
                        QaTip {
                            allowed: root.showTooltips
                            hovered: closeArea.containsMouse
                            side: "belowEnd"
                            text: "Close (Esc)"
                        }
                    }
                }

                // Everything below the header scrolls (mouse wheel, drag,
                // or the scrollbar on the right edge).
                Flickable {
                    id: flick
                    anchors.top: head.bottom
                    anchors.topMargin: 4
                    anchors.bottom: foot.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    contentWidth: width
                    contentHeight: contentCol.height + 16
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: contentCol
                        x: 20
                        width: flick.width - 48

                        QaSectionHeader { text: "Hints" }
                        QaToggleRow {
                            host: root
                            key: "showTooltips"
                            label: "Show tooltips / hints"
                            checked: root.showTooltips
                            tip: "Turn off to hide all hover hints"
                        }
                        QaToggleRow {
                            host: root
                            key: "showFooter"
                            label: "Settings button"
                            checked: root.showFooter
                            tip: "Hides the gear button; C and right-click still work"
                        }
                        QaSectionHeader { text: "Global" }
                        QaSliderRow { host: root; key: "menuSize"; label: "Scale"; tip: "Overall size of the menu" }
                        QaSliderRow { host: root; key: "animMs"; label: "Animation duration"; tip: "0 disables animations" }

                        QaSectionHeader { text: "Layout" }
                        QaToggleRow { host: root; key: "horizontal"; label: "Horizontal layout"; checked: root.horizontal; tip: "Show actions in a row instead of a list" }
                        QaSliderRow { host: root; key: "cardWidth"; label: "Width" }
                        QaSliderRow { host: root; key: "itemHeight"; label: "Item height" }
                        QaSliderRow { host: root; key: "itemSpacing"; label: "Item spacing" }
                        QaSliderRow { host: root; key: "panelPadding"; label: "Panel padding" }

                        QaSectionHeader { text: "Content" }
                        QaToggleRow { host: root; key: "showIcons"; label: "Icons"; checked: root.showIcons }
                        QaToggleRow { host: root; key: "showLabels"; label: "Labels"; checked: root.showLabels }
                        QaToggleRow {
                            host: root
                            key: "showState"
                            label: "ON / OFF state text"
                            checked: root.showState
                            enabled: !root.horizontal
                            tip: "Status text on each row (vertical layout only)"
                        }
                        QaToggleRow {
                            host: root
                            key: "showKeyHints"
                            label: "Key hints"
                            checked: root.showKeyHints
                            enabled: !root.horizontal
                            tip: "Small key badges (vertical layout only)"
                        }

                        QaSectionHeader { text: "Appearance" }
                        QaSliderRow { host: root; key: "panelRadius"; label: "Panel roundness" }
                        QaSliderRow { host: root; key: "itemRadius"; label: "Item roundness" }
                        QaSliderRow { host: root; key: "iconSize"; label: "Icon size"; enabled: root.showIcons }
                        QaSliderRow { host: root; key: "labelSize"; label: "Label size"; enabled: root.showLabels }
                        QaSliderRow { host: root; key: "borderWidth"; label: "Selection border" }

                        QaSectionHeader { text: "Opacity" }
                        QaSliderRow { host: root; key: "panelOpacity"; label: "Panel background" }
                        QaSliderRow { host: root; key: "itemOpacity"; label: "Item background" }
                        QaSliderRow { host: root; key: "hoverBoost"; label: "Hover / selected highlight" }
                        QaSliderRow { host: root; key: "dimOpacity"; label: "Dim screen behind menu" }

                        QaSectionHeader { text: "Quick actions" }
                        QaSliderRow { host: root; key: "brightnessStep"; label: "Brightness step"; tip: "Percent per scroll notch / keypress" }
                        QaSliderRow { host: root; key: "nightTemp"; label: "Night light temperature"; tip: "Scroll over the Night light row to change it; applies live while on" }
                        QaSliderRow { host: root; key: "nightStep"; label: "Night light step"; tip: "Kelvin per scroll notch / keypress" }

                        QaSectionHeader { text: "Behavior" }
                        QaToggleRow { host: root; key: "wrapNav"; label: "Wrap around when navigating"; checked: root.wrapNav }
                        QaToggleRow { host: root; key: "hoverSelect"; label: "Hover selects item"; checked: root.hoverSelect }
                        QaToggleRow { host: root; key: "closeOnOutside"; label: "Close on click outside"; checked: root.closeOnOutside }

                        QaSectionHeader { text: "Visible actions" }
                        Repeater {
                            model: root.actions
                            delegate: QaToggleRow {
                                required property var modelData
                                host: root
                                label: modelData.label + "  (" + modelData.key.toUpperCase() + ")"
                                checked: root.hiddenNames.indexOf(modelData.name) < 0
                                onToggled: root.toggleAction(modelData.name)
                            }
                        }

                        QaSectionHeader { text: "Position" }
                        QaActionButton {
                            label: "Reset position"
                            enabled: root.movedFromDefault
                            tipsOn: root.showTooltips
                            tip: "Move the menu back to its default spot"
                            onClicked: root.resetPosition()
                        }

                        QaSectionHeader { text: "Keybinds" }
                        Repeater {
                            model: root.keybindInfo
                            // one line of the keybind cheat-sheet:
                            // description left, key chip right
                            delegate: Item {
                                id: kbRow
                                required property var modelData
                                width: contentCol.width
                                height: 26

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: kbChip.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: kbRow.modelData.desc
                                    elide: Text.ElideRight
                                    font.pixelSize: 11
                                    color: Theme.text
                                }

                                Rectangle {
                                    id: kbChip
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: kbChipText.implicitWidth + 14
                                    height: 18
                                    radius: 5
                                    color: Theme.alpha(Theme.text, 0.08)

                                    Text {
                                        id: kbChipText
                                        anchors.centerIn: parent
                                        text: kbRow.modelData.keys
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: Theme.textDim
                                    }
                                }
                            }
                        }
                    }
                }

                // The scrollbar sits outside the Flickable's content so it
                // doesn't scroll away with it.
                Rectangle {
                    id: sbTrack
                    visible: flick.contentHeight > flick.height
                    x: flick.x + flick.width - 14
                    y: flick.y
                    width: 4
                    height: flick.height
                    radius: 2
                    color: Theme.alpha(Theme.text, 0.08)
                }

                Rectangle {
                    id: sbHandle
                    visible: flick.contentHeight > flick.height
                    x: flick.x + flick.width - 14
                    width: 4
                    radius: 2
                    height: Math.max(24, flick.height * flick.visibleArea.heightRatio)
                    y: flick.y + flick.visibleArea.yPosition * flick.height
                    color: Theme.text
                    opacity: (sbArea.containsMouse || sbArea.pressed || flick.moving) ? 0.7 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea {
                        id: sbArea
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true

                        // Not using drag.target: dragging would overwrite the
                        // handle's y binding and it would stop following the
                        // wheel afterwards. Drive contentY instead.
                        property real grabY: 0

                        onPressed: mouse => {
                            grabY = mapToItem(flick, mouse.x, mouse.y).y
                                - flick.visibleArea.yPosition * flick.height
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return
                            var span = flick.height - sbHandle.height
                            if (span <= 0)
                                return
                            var ny = mapToItem(flick, mouse.x, mouse.y).y - grabY
                            var r = Math.max(0, Math.min(1, ny / span))
                            flick.contentY = r * (flick.contentHeight - flick.height)
                        }
                    }
                }

                // footer
                Item {
                    id: foot
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 58

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.alpha(Theme.text, 0.08)
                    }

                    QaActionButton {
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Reset all"
                        enabled: root.modified
                        tipsOn: root.showTooltips
                        tip: "Restore every setting to its default"
                        tipSide: "above"
                        onClicked: root.resetAll()
                    }
                    QaActionButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Done"
                        primary: true
                        tipsOn: root.showTooltips
                        tip: "Close settings (Esc)"
                        tipSide: "above"
                        onClicked: root.closeSettings()
                    }
                }
            }
        }
    }

    // ---- reusable components -----------------------------------------------

    // Lightweight hover hint drawn inside the host's own window (no extra
    // popup surface). Appears after a short delay, only if `allowed`.
    // The host should raise its own z while `shown` so the hint isn't covered
    // by siblings.
    component QaTip: Rectangle {
        id: tp
        property string text: ""
        property bool allowed: false
        property bool hovered: false
        // left | below | belowStart | belowEnd | above
        property string side: "belowStart"
        property bool shown: false
        readonly property bool wanted: allowed && text !== "" && hovered

        onWantedChanged: {
            if (wanted) {
                tipDelay.restart()
            } else {
                tipDelay.stop()
                shown = false
            }
        }

        Timer {
            id: tipDelay
            interval: 450
            onTriggered: tp.shown = tp.wanted
        }

        z: 1000
        width: tipText.implicitWidth + 16
        height: tipText.implicitHeight + 10
        radius: 6
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 1)
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.15)
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        x: side === "left" ? -width - 8
         : side === "below" ? (parent.width - width) / 2
         : side === "belowEnd" ? parent.width - width
         : 0
        y: side === "left" ? (parent.height - height) / 2
         : side === "above" ? -height - 4
         : parent.height + 4

        Text {
            id: tipText
            anchors.centerIn: parent
            text: tp.text
            font.pixelSize: 10
            color: Theme.text
        }
    }

    component QaFooterButton: Rectangle {
        id: fb
        property string label: ""
        property int fontSize: 11
        property bool active: false
        property color textColor: Theme.textDim
        readonly property bool hovered: fbArea.containsMouse
        signal clicked()
        signal rightClicked()

        width: 16; height: 16; radius: 6
        color: Theme.bg
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: fb.label
            font.family: "Symbols Nerd Font"
            font.pixelSize: fb.fontSize
            font.bold: true
            color: fb.active ? Theme.accent : (fb.hovered ? Theme.text : fb.textColor)
        }

        MouseArea {
            id: fbArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    fb.rightClicked()
                else
                    fb.clicked()
            }
        }
    }

    component QaActionButton: Rectangle {
        id: ab
        property string label: ""
        property bool primary: false
        property string tip: ""
        property bool tipsOn: false
        property string tipSide: "belowStart"
        signal clicked()

        implicitWidth: abText.implicitWidth + 28
        width: implicitWidth
        height: 30
        radius: 15
        z: abTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4
        color: primary
            ? Theme.accent
            : Theme.alpha(Theme.text, abArea.containsMouse ? 0.18 : 0.1)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: abText
            anchors.centerIn: parent
            text: ab.label
            font.pixelSize: 11
            font.bold: true
            color: ab.primary ? Theme.bg : Theme.text
        }

        MouseArea {
            id: abArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: ab.enabled
            onClicked: ab.clicked()
        }

        QaTip {
            id: abTip
            allowed: ab.tipsOn
            hovered: abArea.containsMouse
            side: ab.tipSide
            text: ab.tip
        }
    }

    component QaSectionHeader: Item {
        property string text: ""
        width: parent?.width ?? 0
        height: 32

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: parent.text
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
            color: Theme.textDim
        }
    }

    // Toggle row. With a `key` it flips that boolean setting on the host;
    // without one it just emits `toggled()` (used for the action list).
    component QaToggleRow: Item {
        id: tr
        property var host
        property string key: ""
        property string label: ""
        property string tip: ""
        property bool checked: false
        signal toggled()

        width: parent?.width ?? 0
        height: 34
        z: trTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -8
            anchors.rightMargin: -8
            radius: 8
            color: trArea.containsMouse && tr.enabled ? Theme.alpha(Theme.text, 0.06) : "transparent"
        }

        Text {
            anchors.left: parent.left
            anchors.right: sw.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            elide: Text.ElideRight
            font.pixelSize: 12
            font.bold: true
            color: Theme.text
        }

        Rectangle {
            id: sw
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 20; radius: 10
            color: tr.checked ? Theme.accent : "transparent"
            border.width: 1
            border.color: tr.checked ? Theme.accent : Theme.alpha(Theme.text, 0.3)
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: tr.checked ? parent.width - width - 3 : 3
                color: tr.checked ? Theme.bg : Theme.text
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: trArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: tr.enabled
            onClicked: {
                if (tr.key !== "")
                    tr.host.toggleSetting(tr.key)
                else
                    tr.toggled()
            }
        }

        QaTip {
            id: trTip
            allowed: tr.host ? tr.host.showTooltips : false
            hovered: trArea.containsMouse
            side: "belowStart"
            text: tr.tip
        }
    }

    // Self-contained minimal slider. Reads/writes a numSpec entry on the
    // host and saves on release.
    component QaSliderRow: Item {
        id: sr
        property var host
        property string key: ""
        property string label: ""
        property string tip: ""

        readonly property var spec: host.numSpec[key]
        readonly property real ratio: Math.max(0, Math.min(1,
            (host[key] - spec.min) / (spec.max - spec.min)))

        width: parent?.width ?? 0
        height: 44
        z: srTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4

        Text {
            anchors.left: parent.left
            y: 6
            text: sr.label
            font.pixelSize: 12
            font.bold: true
            color: Theme.text
        }

        Text {
            anchors.right: parent.right
            y: 6
            text: sr.host.fmtValue(sr.key, sr.host[sr.key])
            font.pixelSize: 11
            color: Theme.textDim
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            y: 30
            height: 4
            radius: 2
            color: Theme.alpha(Theme.text, 0.15)

            Rectangle {
                width: knob.x + knob.width / 2
                height: parent.height
                radius: 2
                color: Theme.accent
            }

            Rectangle {
                id: knob
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: sr.ratio * (track.width - width)
                color: Theme.text
            }
        }

        MouseArea {
            id: sliderArea
            anchors.fill: parent
            anchors.topMargin: 20
            hoverEnabled: true
            preventStealing: true
            enabled: sr.enabled

            function apply(mx) {
                var usable = track.width - knob.width
                if (usable <= 0)
                    return
                var r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable))
                var s = sr.spec
                sr.host.setNumber(sr.key,
                    s.min + Math.round(r * (s.max - s.min) / s.step) * s.step)
            }

            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
            onReleased: sr.host.saveState()
        }

        QaTip {
            id: srTip
            allowed: sr.host ? sr.host.showTooltips : false
            hovered: sliderArea.containsMouse && !sliderArea.pressed
            side: "belowStart"
            text: sr.tip
        }
    }
}
