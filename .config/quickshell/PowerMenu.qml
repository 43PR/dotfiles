pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    // ---- lifecycle -------------------------------------------------------
    property bool showing: false      // logical "menu is open"
    property bool mounted: false      // window exists
    property var targetScreen: Quickshell.screens[0]
    property real winW: 0             // reported by the window while mounted
    property real winH: 0

    // ---- per-icon size tweaks ----------------------------------------------
    // Multiplier applied on top of the "Icon size" setting, one per action.
    // 1.0 = the Icon size slider value; 0.9 = 10% smaller; 1.15 = 15% bigger.
    property real shutdownIconScale: 1.1
    property real rebootIconScale: 1.1
    property real suspendIconScale: 0.8
    property real logoutIconScale: 1.0
    property real hibernateIconScale: 1.1

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

    // ---- settings window look (same properties as the wallpaper picker) ----
    // Font, text sizes, radius and the menu scale are the same values the wallpaper
    // picker's settings menu uses; scale / radius come from the same hub.json.
    // Colours still come from the Theme singleton, as before.
    //   ui     : resolution scale (1.0 at 1080p height)
    //   menuUi : ui * hub "settingsScale"; multiply every settings-window size by it
    readonly property QtObject th: QtObject {
        property real settingsScale: 1.0
        property int radius: 10

        readonly property string fontFamily: "JetBrains Mono"
        readonly property int animFast: 120
        readonly property int animMed: 220
        readonly property int textSizeSection: 15
        readonly property int textSizeGroup: 12
        readonly property int textSizeBody: 11
        readonly property int textSizeSmall: 10
    }
    readonly property real ui: (targetScreen?.height ?? 1080) / 1080
    readonly property real menuUi: ui * th.settingsScale

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/state/hub.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const h = JSON.parse(text())
                if (typeof h.settingsScale === "number") root.th.settingsScale = Math.max(0.6, Math.min(1.2, h.settingsScale))
                if (typeof h.radius === "number") root.th.radius = Math.round(Math.max(0, Math.min(50, h.radius)))
            } catch (e) { console.warn("powermenu: malformed hub.json:", e) }
        }
    }

    // ---- settings specs (numbers) ----------------------------------------
    readonly property var numSpec: ({
        menuSize:     { min: 70,  max: 260, def: 100, step: 10, unit: "%" },
        animMs:       { min: 0,   max: 500, def: 200, step: 20, unit: " ms" },

        cardWidth:    { min: 60, max: 700, def: 284, step: 5, unit: "px" },
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
        dimOpacity:   { min: 0,   max: 100,  def: 0,   step: 5,  unit: "%" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showTooltips: true,
        horizontal: false,
        showIcons: true,
        showLabels: true,
        showKeyHints: true,
        showFooter: true,
        confirmDangerous: false,
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

    property bool showTooltips: boolDefaults.showTooltips
    property bool horizontal: boolDefaults.horizontal
    property bool showIcons: boolDefaults.showIcons
    property bool showLabels: boolDefaults.showLabels
    property bool showKeyHints: boolDefaults.showKeyHints
    property bool showFooter: boolDefaults.showFooter
    property bool confirmDangerous: boolDefaults.confirmDangerous
    property bool wrapNav: boolDefaults.wrapNav
    property bool hoverSelect: boolDefaults.hoverSelect
    property bool closeOnOutside: boolDefaults.closeOnOutside

    property bool settingsOpen: false
    property bool dragging: false
    property int currentIndex: 0
    property string confirmName: ""
    property var hiddenNames: []

    readonly property int edgeGap: 0
    // how much of the panel must stay on screen when dragged past borders
    readonly property int keepVisible: 40

    // box around the icon glyph = icon size + 12px
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

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/powermenu-state.json"

    onCurrentIndexChanged: confirmName = ""

    // ---- actions ----------------------------------------------------------
    // `glyph` is a Nerd Font icon drawn in the Theme.text colour.
    //   shutdown  nf-md-power          U+F0425
    //   reboot                         U+F0450
    //   suspend   nf-fa-moon_o         U+F186
    //   logout    nf-md-logout         U+F0343
    //   hibernate nf-md-sleep          U+F04B2
    readonly property var actions: [
        { name: "shutdown",  label: "Shut down", glyph: "\udb81\udc25", key: "s", danger: true,  cmd: ["systemctl", "poweroff"] },
        { name: "reboot",    label: "Reboot",    glyph: "\uead2", key: "r", danger: true,  cmd: ["systemctl", "reboot"] },
        { name: "suspend",   label: "Suspend",   glyph: "\uf186",       key: "z", danger: false, cmd: ["systemctl", "suspend"] },
        { name: "logout",    label: "Log out",   glyph: "\udb80\udf43", key: "e", danger: true,  dispatch: "hl.dsp.exit()" },
        { name: "hibernate", label: "Hibernate", glyph: "\udb82\udd01", key: "h", danger: false, cmd: ["systemctl", "hibernate"] }
    ]

    readonly property var visibleActions: actions.filter(function (a) {
        return root.hiddenNames.indexOf(a.name) < 0
    })

    // rows shown in the "Keybinds" section at the end of the settings menu:
    // general keys (one per line) and the per-action keys (shown in a grid)
    readonly property var keybindGeneral: [
        { keys: "Super + Grave",          desc: "Power menu" },
        { keys: "Esc / Click outside",    desc: "Close menu / settings" },
        { keys: "↑ ↓ ← → Tab",            desc: "Move selection" },
        { keys: "Enter / Space / LMB",    desc: "Run selected action" },
        { keys: "C / RMB (any button)",   desc: "Open settings" },
        { keys: "Drag handle",            desc: "Move the menu" }
    ]
    readonly property var keybindActionKeys: actions.map(function (a) {
        return { keys: a.key.toUpperCase(), desc: a.label }
    })

    // per-icon multiplier, looked up from the *IconScale properties at the top
    function iconScaleOf(name) {
        var v = root[name + "IconScale"]
        return (typeof v === "number" && v > 0) ? v : 1.0
    }

    // width of one cell when `p` is a Grid with several columns, else the full width
    function cellW(p) {
        if (!p) return 0
        if (p.columns !== undefined && p.columns > 1 && p.columnSpacing !== undefined)
            return Math.floor((p.width - (p.columns - 1) * p.columnSpacing) / p.columns)
        return p.width
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    function runAction(a) {
        // the menu stays visible while settings are open for live preview,
        // so never fire real actions from it
        if (root.settingsOpen)
            return
        if (root.confirmDangerous && a.danger && root.confirmName !== a.name) {
            root.confirmName = a.name
            return
        }
        if (a.dispatch)
            Hyprland.dispatch(a.dispatch)
        else if (a.cmd)
            Quickshell.execDetached({ command: a.cmd })
        root.closeMenu()
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
        confirmName = ""
        settingsOpen = false
        dragging = false
        showing = true   // onShowingChanged mounts the window
    }

    function closeMenu() {
        showing = false
        settingsOpen = false
        dragging = false
        confirmName = ""
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
    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
        function settings(): void { root.openSettings() }
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
                console.warn("powermenu: could not read saved state:", e)
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
            WlrLayershell.namespace: "powermenu"
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

                            Tip {
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
                                    readonly property bool pending: root.confirmName === modelData.name
                                    readonly property int count: root.visibleActions.length

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
                                    border.color: entry.pending ? Theme.text : Theme.accent
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

                                        // Font icon, coloured by the theme text colour
                                        Text {
                                            anchors.centerIn: parent
                                            text: entry.modelData.glyph
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: Math.round(root.iconSize * root.iconScaleOf(entry.modelData.name))
                                            color: entry.pending ? Theme.accent : Theme.text
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }

                                    Text {
                                        id: eLabel
                                        visible: root.showLabels
                                        text: entry.pending ? entry.modelData.label + "?" : entry.modelData.label
                                        font.pixelSize: root.labelSize
                                        font.bold: true
                                        color: entry.pending ? Theme.accent : Theme.text
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
                                            : Math.max(0, entry.width - x - ((root.showKeyHints) ? 40 : 12))
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
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.openSettings()
                                                return
                                            }
                                            root.currentIndex = entry.index
                                            root.runAction(entry.modelData)
                                        }
                                    }

                                    Tip {
                                        id: entryTip
                                        allowed: root.showTooltips
                                        hovered: entryArea.containsMouse
                                        side: root.horizontal ? "below" : "left"
                                        text: entry.modelData.label
                                            + " (" + entry.modelData.key.toUpperCase() + ")"
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

                            FooterButton {
                                id: footBtn
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                label: "\udb81\udc93"
                                fontSize: 12
                                active: root.settingsOpen
                                opacity: (hovered || root.settingsOpen) ? 1 : 0.1
                                onClicked: root.toggleSettings()
                                onRightClicked: root.openSettings()
                            }

                            Tip {
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

    // ---- settings window ----------------------------------------------------
    // Look matches the wallpaper picker's settings menu: JetBrains Mono, the same text
    // sizes, hub.json radius, and everything scaled by `u` (= root.menuUi).
    // No custom layer namespace is set here (the picker sets none either), so the
    // compositor's layer rules, e.g. blur, apply to this window the same way.
    //
    // Compact layout: sliders and toggles sit in plain `Grid`s (2 columns, 3 for
    // the key list), so the whole page needs far less scrolling.
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin
            screen: root.targetScreen

            readonly property real u: root.menuUi

            color: "transparent"
            implicitWidth: Math.round(440 * u)
            implicitHeight: Math.round(Math.min(640 * u, (screen?.height ?? 800) * 0.88))
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Rectangle {
                anchors.fill: parent
                radius: root.th.radius * settingsWin.u
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
                    height: 52 * settingsWin.u

                    Text {
                        x: 20 * settingsWin.u; y: 8 * settingsWin.u
                        text: "Power menu settings"
                        font.family: root.th.fontFamily
                        font.pixelSize: root.th.textSizeSection * settingsWin.u
                        font.bold: true
                        color: Theme.text
                    }
                    Text {
                        x: 20 * settingsWin.u; y: 30 * settingsWin.u
                        text: "Drag the handle to move."
                        font.family: root.th.fontFamily
                        font.pixelSize: root.th.textSizeSmall * settingsWin.u
                        color: Theme.textDim
                    }
                    Text {
                        id: closeX
                        anchors.right: parent.right
                        anchors.rightMargin: 16 * settingsWin.u
                        y: 8 * settingsWin.u
                        width: 26 * settingsWin.u; height: 26 * settingsWin.u
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "×"
                        font.family: root.th.fontFamily
                        font.pixelSize: 22 * settingsWin.u
                        color: closeArea.containsMouse ? Theme.text : Theme.textDim
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.closeSettings()
                        }
                        Tip {
                            allowed: root.showTooltips
                            hovered: closeArea.containsMouse
                            side: "belowEnd"
                            text: "Close (Esc)"
                            u: settingsWin.u
                            family: root.th.fontFamily
                        }
                    }
                }

                // Everything below the header scrolls (mouse wheel, drag,
                // or the scrollbar on the right edge).
                Flickable {
                    id: flick
                    anchors.top: head.bottom
                    anchors.topMargin: 2 * settingsWin.u
                    anchors.bottom: foot.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    contentWidth: width
                    contentHeight: contentCol.height + 12 * settingsWin.u
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: contentCol
                        x: 20 * settingsWin.u
                        width: flick.width - 48 * settingsWin.u

                        // ---------------- GENERAL ----------------
                        SectionHeader { host: root; text: "General" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            ToggleRow {
                                host: root
                                key: "showTooltips"
                                label: "Tooltips"
                                checked: root.showTooltips
                                tip: "Turn off to hide all hover hints"
                            }
                            ToggleRow {
                                host: root
                                key: "showFooter"
                                label: "Settings button"
                                checked: root.showFooter
                                tip: "Hides the gear button; C and right-click still work"
                            }
                            SliderRow { host: root; key: "menuSize"; label: "Scale"; tip: "Overall size of the power menu" }
                            SliderRow { host: root; key: "animMs"; label: "Animation"; tip: "Animation duration. 0 disables animations" }
                        }

                        // ---------------- LAYOUT & CONTENT ----------------
                        SectionHeader { host: root; text: "Layout & content" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            ToggleRow { host: root; key: "horizontal"; label: "Horizontal"; checked: root.horizontal; tip: "Show actions in a row instead of a list" }
                            ToggleRow { host: root; key: "showIcons"; label: "Icons"; checked: root.showIcons }
                            ToggleRow { host: root; key: "showLabels"; label: "Labels"; checked: root.showLabels }
                            ToggleRow {
                                host: root
                                key: "showKeyHints"
                                label: "Key hints"
                                checked: root.showKeyHints
                                enabled: !root.horizontal
                                tip: "Small key badges (vertical layout only)"
                            }
                            SliderRow { host: root; key: "cardWidth"; label: "Width" }
                            SliderRow { host: root; key: "itemHeight"; label: "Item height" }
                            SliderRow { host: root; key: "itemSpacing"; label: "Item spacing" }
                            SliderRow { host: root; key: "panelPadding"; label: "Panel padding" }
                        }

                        // ---------------- APPEARANCE ----------------
                        SectionHeader { host: root; text: "Appearance" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            SliderRow { host: root; key: "panelRadius"; label: "Panel roundness" }
                            SliderRow { host: root; key: "itemRadius"; label: "Item roundness" }
                            SliderRow { host: root; key: "iconSize"; label: "Icon size"; enabled: root.showIcons }
                            SliderRow { host: root; key: "labelSize"; label: "Label size"; enabled: root.showLabels }
                            SliderRow { host: root; key: "borderWidth"; label: "Selection border" }
                            SliderRow { host: root; key: "panelOpacity"; label: "Panel opacity"; tip: "Panel background opacity" }
                            SliderRow { host: root; key: "itemOpacity"; label: "Item opacity"; tip: "Item background opacity" }
                            SliderRow { host: root; key: "hoverBoost"; label: "Hover highlight"; tip: "Extra opacity on hovered / selected items" }
                            SliderRow { host: root; key: "dimOpacity"; label: "Screen dim"; tip: "Dim the screen behind the menu" }
                        }

                        // ---------------- BEHAVIOR ----------------
                        SectionHeader { host: root; text: "Behavior" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            ToggleRow { host: root; key: "confirmDangerous"; label: "Confirm danger"; checked: root.confirmDangerous; tip: "Shutdown / reboot / logout need a second press to confirm" }
                            ToggleRow { host: root; key: "wrapNav"; label: "Wrap around"; checked: root.wrapNav; tip: "Wrap around when navigating with the keyboard" }
                            ToggleRow { host: root; key: "hoverSelect"; label: "Hover selects"; checked: root.hoverSelect; tip: "Hovering an item selects it" }
                            ToggleRow { host: root; key: "closeOnOutside"; label: "Click outside"; checked: root.closeOnOutside; tip: "Close the menu when clicking outside of it" }
                        }

                        // ---------------- VISIBLE ACTIONS ----------------
                        SectionHeader { host: root; text: "Visible actions" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            Repeater {
                                model: root.actions
                                delegate: ToggleRow {
                                    required property var modelData
                                    host: root
                                    label: modelData.label + " (" + modelData.key.toUpperCase() + ")"
                                    checked: root.hiddenNames.indexOf(modelData.name) < 0
                                    onToggled: root.toggleAction(modelData.name)
                                }
                            }
                        }

                        // ---------------- KEYBINDS ----------------
                        SectionHeader { host: root; text: "Keybinds" }
                        Repeater {
                            model: root.keybindGeneral
                            delegate: KeyRow {
                                required property var modelData
                                host: root
                                keys: modelData.keys
                                desc: modelData.desc
                            }
                        }
                        Item { width: 1; height: 4 * settingsWin.u }
                        Grid {
                            width: parent.width; columns: 3; columnSpacing: 18 * settingsWin.u
                            Repeater {
                                model: root.keybindActionKeys
                                delegate: KeyRow {
                                    required property var modelData
                                    host: root
                                    keys: modelData.keys
                                    desc: modelData.desc
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
                    x: flick.x + flick.width - 14 * settingsWin.u
                    y: flick.y
                    width: 4 * settingsWin.u
                    height: flick.height
                    radius: width / 2
                    color: Theme.alpha(Theme.text, 0.08)
                }

                Rectangle {
                    id: sbHandle
                    visible: flick.contentHeight > flick.height
                    x: flick.x + flick.width - 14 * settingsWin.u
                    width: 4 * settingsWin.u
                    radius: width / 2
                    height: Math.max(24 * settingsWin.u, flick.height * flick.visibleArea.heightRatio)
                    y: flick.y + flick.visibleArea.yPosition * flick.height
                    color: Theme.text
                    opacity: (sbArea.containsMouse || sbArea.pressed || flick.moving) ? 0.7 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea {
                        id: sbArea
                        anchors.fill: parent
                        anchors.margins: -5 * settingsWin.u
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
                    height: 50 * settingsWin.u

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.alpha(Theme.text, 0.08)
                    }

                    Row {
                        x: 20 * settingsWin.u
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * settingsWin.u

                        ActionButton {
                            host: root
                            label: "Reset all"
                            enabled: root.modified
                            tipsOn: root.showTooltips
                            tip: "Restore every setting to its default"
                            tipSide: "above"
                            onClicked: root.resetAll()
                        }
                        ActionButton {
                            host: root
                            label: "Reset position"
                            enabled: root.movedFromDefault
                            tipsOn: root.showTooltips
                            tip: "Move the menu back to its default spot"
                            tipSide: "above"
                            onClicked: root.resetPosition()
                        }
                    }

                    ActionButton {
                        host: root
                        anchors.right: parent.right
                        anchors.rightMargin: 20 * settingsWin.u
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
    // by siblings. `u` / `family` let the settings window scale it and use the
    // shared font; the main menu keeps the defaults.
    component Tip: Rectangle {
        id: tp
        property string text: ""
        property bool allowed: false
        property bool hovered: false
        property real u: 1
        property string family: Qt.application.font.family
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
        width: tipText.implicitWidth + 16 * u
        height: tipText.implicitHeight + 10 * u
        radius: 6 * u
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 1)
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.15)
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        x: side === "left" ? -width - 8 * u
         : side === "below" ? (parent.width - width) / 2
         : side === "belowEnd" ? parent.width - width
         : 0
        y: side === "left" ? (parent.height - height) / 2
         : side === "above" ? -height - 4 * u
         : parent.height + 4 * u

        Text {
            id: tipText
            anchors.centerIn: parent
            text: tp.text
            font.family: tp.family
            font.pixelSize: 10 * tp.u
            color: Theme.text
        }
    }

    component FooterButton: Rectangle {
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

    // Settings-window components below take `host` (the root Scope) and read the
    // shared scale / font / sizes from host.menuUi and host.th, like the picker's.
    //
    // Sliders, toggles and key rows size themselves from their parent: inside a
    // multi-column `Grid` they take one cell (see cellW() on the root), anywhere else the full width.

    component ActionButton: Rectangle {
        id: ab
        property var host
        property string label: ""
        property bool primary: false
        property string tip: ""
        property bool tipsOn: false
        property string tipSide: "belowStart"
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        signal clicked()

        implicitWidth: abText.implicitWidth + 28 * u
        width: implicitWidth
        height: 28 * u
        radius: Math.min(height / 2, ab.th.radius * u)
        z: abTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4
        color: primary
            ? Theme.accent
            : Theme.alpha(Theme.text, abArea.containsMouse && enabled ? 0.18 : 0.1)
        Behavior on color { ColorAnimation { duration: ab.th.animFast } }

        Text {
            id: abText
            anchors.centerIn: parent
            text: ab.label
            font.family: ab.th.fontFamily
            font.pixelSize: ab.th.textSizeBody * ab.u
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

        Tip {
            id: abTip
            allowed: ab.tipsOn
            hovered: abArea.containsMouse
            side: ab.tipSide
            text: ab.tip
            u: ab.u
            family: ab.th.fontFamily
        }
    }

    component SectionHeader: Item {
        id: sh
        property var host
        property string text: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        width: parent?.width ?? 0
        height: 26 * u

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3 * sh.u
            text: sh.text
            font.family: sh.th.fontFamily
            font.pixelSize: sh.th.textSizeSmall * sh.u
            font.bold: true
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
            color: Theme.textDim
        }
    }

    // One line of the keybind cheat-sheet: description left, key chip right.
    component KeyRow: Item {
        id: kr
        property var host
        property string keys: ""
        property string desc: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th

        width: host.cellW(parent)
        height: 22 * u

        Text {
            anchors.left: parent.left
            anchors.right: chip.left
            anchors.rightMargin: 8 * kr.u
            anchors.verticalCenter: parent.verticalCenter
            text: kr.desc
            elide: Text.ElideRight
            font.family: kr.th.fontFamily
            font.pixelSize: kr.th.textSizeBody * kr.u
            color: Theme.text
        }

        Rectangle {
            id: chip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + 14 * kr.u
            height: 18 * kr.u
            radius: 5 * kr.u
            color: Theme.alpha(Theme.text, 0.08)

            Text {
                id: chipText
                anchors.centerIn: parent
                text: kr.keys
                font.family: kr.th.fontFamily
                font.pixelSize: kr.th.textSizeSmall * kr.u
                font.bold: true
                color: Theme.textDim
            }
        }
    }

    // Toggle row. With a `key` it flips that boolean setting on the host;
    // without one it just emits `toggled()` (used for the action list).
    component ToggleRow: Item {
        id: tr
        property var host
        property string key: ""
        property string label: ""
        property string tip: ""
        property bool checked: false
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        signal toggled()

        width: host.cellW(parent)
        height: 28 * u
        z: trTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6 * tr.u
            anchors.rightMargin: -6 * tr.u
            radius: Math.min(8 * tr.u, tr.th.radius * tr.u)
            color: trArea.containsMouse && tr.enabled ? Theme.alpha(Theme.text, 0.06) : "transparent"
        }

        Text {
            anchors.left: parent.left
            anchors.right: sw.left
            anchors.rightMargin: 8 * tr.u
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            elide: Text.ElideRight
            font.family: tr.th.fontFamily
            font.pixelSize: tr.th.textSizeGroup * tr.u
            font.bold: true
            color: Theme.text
        }

        Rectangle {
            id: sw
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * tr.u; height: 18 * tr.u; radius: height / 2
            color: tr.checked ? Theme.accent : "transparent"
            border.width: 1
            border.color: tr.checked ? Theme.accent : Theme.alpha(Theme.text, 0.3)
            Behavior on color { ColorAnimation { duration: tr.th.animMed } }

            Rectangle {
                width: 12 * tr.u; height: 12 * tr.u; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: tr.checked ? parent.width - width - 3 * tr.u : 3 * tr.u
                color: tr.checked ? Theme.bg : Theme.text
                Behavior on x { NumberAnimation { duration: tr.th.animMed; easing.type: Easing.OutCubic } }
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

        Tip {
            id: trTip
            allowed: tr.host ? tr.host.showTooltips : false
            hovered: trArea.containsMouse
            side: "belowStart"
            text: tr.tip
            u: tr.u
            family: tr.th.fontFamily
        }
    }

    // Self-contained minimal slider. Reads/writes a numSpec entry on the
    // host and saves on release. Label and value share the top line.
    component SliderRow: Item {
        id: sr
        property var host
        property string key: ""
        property string label: ""
        property string tip: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th

        readonly property var spec: host.numSpec[key]
        readonly property real ratio: Math.max(0, Math.min(1,
            (host[key] - spec.min) / (spec.max - spec.min)))

        width: host.cellW(parent)
        height: 38 * u
        z: srTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4

        Text {
            anchors.left: parent.left
            anchors.right: srValue.left
            anchors.rightMargin: 6 * sr.u
            y: 4 * sr.u
            text: sr.label
            elide: Text.ElideRight
            font.family: sr.th.fontFamily
            font.pixelSize: sr.th.textSizeGroup * sr.u
            font.bold: true
            color: Theme.text
        }

        Text {
            id: srValue
            anchors.right: parent.right
            y: 5 * sr.u
            text: sr.host.fmtValue(sr.key, sr.host[sr.key])
            font.family: sr.th.fontFamily
            font.pixelSize: sr.th.textSizeBody * sr.u
            color: Theme.textDim
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            y: 27 * sr.u
            height: 4 * sr.u
            radius: height / 2
            color: Theme.alpha(Theme.text, 0.15)

            Rectangle {
                width: knob.x + knob.width / 2
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }

            Rectangle {
                id: knob
                width: 14 * sr.u
                height: 14 * sr.u
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: sr.ratio * (track.width - width)
                color: Theme.text
            }
        }

        MouseArea {
            id: sliderArea
            anchors.fill: parent
            anchors.topMargin: 18 * sr.u
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

        Tip {
            id: srTip
            allowed: sr.host ? sr.host.showTooltips : false
            hovered: sliderArea.containsMouse && !sliderArea.pressed
            side: "belowStart"
            text: sr.tip
            u: sr.u
            family: sr.th.fontFamily
        }
    }
}