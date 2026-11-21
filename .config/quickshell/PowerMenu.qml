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
    property real panelH: 0           // unscaled panel height, reported by the panel

    // ---- per-icon size tweaks ----------------------------------------------
    // Multiplier applied on top of the "Icon size" setting, one per action.
    // 1.0 = the Icon size slider value; 0.9 = 10% smaller; 1.15 = 15% bigger.
    property real shutdownIconScale: 1.1
    property real rebootIconScale: 1.1
    property real suspendIconScale: 0.8
    property real logoutIconScale: 1.0
    property real hibernateIconScale: 1.1

    property real iconOffsetX: 1

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
    readonly property real menuUi: ui * th.settingsScale * settingsZoom

    // ---- settings window: position + zoom -----------------------------------
    // The settings window is drawn inside a full-screen transparent layer
    // surface (input is masked to the card itself), so it can be dragged freely
    // without fighting the compositor. Position and zoom are saved in the state
    // file. Drag the title bar to move, Shift + scroll to zoom, double-click the
    // title bar to re-centre and reset the zoom.
    //
    // Layer namespace of that surface. Blur / layer rules for the settings window
    // must target this name (use `ignorealpha`, because the surface is full-screen).
    readonly property string settingsNamespace: "powermenu-settings"

    readonly property real zoomMin: 0.6
    readonly property real zoomMax: 2.0
    readonly property real zoomStep: 0.05      // per wheel notch

    property real settingsZoom: 1.0
    property bool settingsPosSet: false         // false = centred on the screen
    property real settingsX: 0                  // top-left of the card, screen px
    property real settingsY: 0
    property bool settingsDragging: false

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
    readonly property var numSpec: ({
        menuSize:     { min: 70,  max: 260, def: 185, step: 5, unit: "%" },
        animMs:       { min: 0,   max: 500, def: 200, step: 10, unit: " ms" },
        cardWidth:    { min: 60,  max: 700, def: 275, step: 5, unit: "px" },
        itemHeight:   { min: 40,  max: 120, def: 52,  step: 4,  unit: "px" },
        itemSpacing:  { min: 0,   max: 24,  def: 24,  step: 2,  unit: "px" },
        panelPadding: { min: 0,   max: 24,  def: 0,   step: 2,  unit: "px" },
        topGap:       { min: 0,   max: 120, def: 12,  step: 4,  unit: "px" },
        sideGap:      { min: 0,   max: 120, def: 24,  step: 4,  unit: "px" },
        panelRadius:  { min: 0,   max: 40,  def: 20,  step: 2,  unit: "px" },
        itemRadius:   { min: 0,   max: 40,  def: 36,  step: 2,  unit: "px" },
        iconSize:     { min: 12,  max: 56,  def: 18,  step: 2,  unit: "px" },
        labelSize:    { min: 9,   max: 22,  def: 11,  step: 1,  unit: "px" },
        borderWidth:  { min: 0,   max: 4,   def: 1,   step: 1,  unit: "px" },
        inactiveBorderWidth: { min: 0, max: 4, def: 1, step: 1, unit: "px" },

        panelOpacity: { min: 0,   max: 100, def: 0,   step: 5,  unit: "%" },
        itemOpacity:  { min: 0,   max: 100, def: 10,  step: 5,  unit: "%" },
        hoverBoost:   { min: 0,   max: 40,  def: 32,  step: 2,  unit: "%" },
        dimOpacity:   { min: 0,   max: 100, def: 40,  step: 5,  unit: "%" },

        labelOpacity:          { min: 0, max: 100, def: 100, step: 5, unit: "%" },
        labelActiveOpacity:    { min: 0, max: 100, def: 100, step: 5, unit: "%" },
        iconOpacity:           { min: 0, max: 100, def: 50,  step: 5, unit: "%" },
        iconActiveOpacity:     { min: 0, max: 100, def: 100, step: 5, unit: "%" },
        borderOpacity:         { min: 0, max: 100, def: 100, step: 5, unit: "%" },
        inactiveBorderOpacity: { min: 0, max: 100, def: 15,  step: 5, unit: "%" },
        keyHintOpacity:        { min: 0, max: 100, def: 100, step: 5, unit: "%" },
        keyHintBgOpacity:      { min: 0, max: 100, def: 8,   step: 2, unit: "%" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showTooltips: true,
        horizontal: true,
        showIcons: true,
        showLabels: false,
        showKeyHints: false,
        confirmDangerous: false,
        wrapNav: true,
        hoverSelect: true,
        closeOnOutside: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    readonly property var posKeys: ["offsetX", "offsetY"]

    // which Theme colour is used as the highlight colour: accent | accent2 | text
    readonly property var accentChoices: [
        { id: "accent",  label: "Accent" },
        { id: "accent2", label: "Accent 2" },
        { id: "text",    label: "Text" }
    ]

    // ---- per-element colour sources ------------------------------------------
    // Every element can use any of these. "highlight" follows the Highlight color
    // chosen in settings > Colors (accentSource).
    readonly property var colorChoices: [
        { id: "highlight", label: "Highlight" },
        { id: "text",      label: "Text" },
        { id: "textDim",   label: "Dim text" },
        { id: "accent",    label: "Accent" },
        { id: "accent2",   label: "Accent 2" },
        { id: "bg",        label: "Background" },
        { id: "black",     label: "Black" },
        { id: "white",     label: "White" }
    ]

    readonly property var colorDefaults: ({
        panelBgColor:        "accent",
        itemBgColor:         "bg",
        itemBgActiveColor:   "bg",
        borderColor:         "highlight",
        inactiveBorderColor: "accent2",
        labelColor:          "text",
        labelActiveColor:    "text",
        iconColor:           "accent2",
        iconActiveColor:     "accent2",
        keyHintColor:        "textDim",
        keyHintBgColor:      "text",
        pendingColor:        "highlight",
        pendingBorderColor:  "text"
    })
    readonly property var colorKeys: Object.keys(colorDefaults)
    readonly property var posDefaults: ({ offsetX: -1280.0273437500005, offsetY: 448.54296875 })
    readonly property var hiddenDefaults: ["hibernate"]
    property real offsetX: posDefaults.offsetX
    property real offsetY: posDefaults.offsetY

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
    property int inactiveBorderWidth: numSpec.inactiveBorderWidth.def
    property int panelOpacity: numSpec.panelOpacity.def
    property int itemOpacity: numSpec.itemOpacity.def
    property int hoverBoost: numSpec.hoverBoost.def
    property int dimOpacity: numSpec.dimOpacity.def

    property int labelOpacity: numSpec.labelOpacity.def
    property int labelActiveOpacity: numSpec.labelActiveOpacity.def
    property int iconOpacity: numSpec.iconOpacity.def
    property int iconActiveOpacity: numSpec.iconActiveOpacity.def
    property int borderOpacity: numSpec.borderOpacity.def
    property int inactiveBorderOpacity: numSpec.inactiveBorderOpacity.def
    property int keyHintOpacity: numSpec.keyHintOpacity.def
    property int keyHintBgOpacity: numSpec.keyHintBgOpacity.def

    property bool showTooltips: boolDefaults.showTooltips
    property bool horizontal: boolDefaults.horizontal
    property bool showIcons: boolDefaults.showIcons
    property bool showLabels: boolDefaults.showLabels
    property bool showKeyHints: boolDefaults.showKeyHints
    property bool confirmDangerous: boolDefaults.confirmDangerous
    property bool wrapNav: boolDefaults.wrapNav
    property bool hoverSelect: boolDefaults.hoverSelect
    property bool closeOnOutside: boolDefaults.closeOnOutside

    property string accentSource: "accent"

    property string panelBgColor: colorDefaults.panelBgColor
    property string itemBgColor: colorDefaults.itemBgColor
    property string itemBgActiveColor: colorDefaults.itemBgActiveColor
    property string borderColor: colorDefaults.borderColor
    property string inactiveBorderColor: colorDefaults.inactiveBorderColor
    property string labelColor: colorDefaults.labelColor
    property string labelActiveColor: colorDefaults.labelActiveColor
    property string iconColor: colorDefaults.iconColor
    property string iconActiveColor: colorDefaults.iconActiveColor
    property string keyHintColor: colorDefaults.keyHintColor
    property string keyHintBgColor: colorDefaults.keyHintBgColor
    property string pendingColor: colorDefaults.pendingColor
    property string pendingBorderColor: colorDefaults.pendingBorderColor

    property bool settingsOpen: false
    property bool dragging: false
    property int currentIndex: 0
    property string confirmName: ""
    property var hiddenNames: hiddenDefaults.slice()

    // ---- highlight colour ---------------------------------------------------
    // cAccent is the "Highlight" colour: toggles, sliders, focus rings, and
    // (by default) the selection border and the confirm prompt. It is one of
    // the three Theme colours, picked in settings > Colors.
    readonly property color themeAccent: Theme.accent
    readonly property color themeAccent2: Theme.accent2 !== undefined ? Theme.accent2 : Theme.accent
    readonly property color themeText: Theme.text

    function accentColorOf(id) {
        switch (id) {
        case "accent2": return themeAccent2
        case "text":    return themeText
        }
        return themeAccent
    }

    readonly property color cAccent: accentColorOf(accentSource)

    function cycleAccent(dir) {
        var n = accentChoices.length
        var i = accentChoices.findIndex(function (c) { return c.id === accentSource })
        if (i < 0) i = 0
        accentSource = accentChoices[((i + dir) % n + n) % n].id
        saveState()
    }

    // ---- per-element colour helpers ------------------------------------------
    // themeColor: resolves a colour-choice id to an actual colour.
    function themeColor(id) {
        switch (id) {
        case "highlight": return cAccent
        case "accent":    return themeAccent
        case "accent2":   return themeAccent2
        case "text":      return themeText
        case "textDim":   return Theme.textDim
        case "bg":        return Theme.bg
        case "black":     return Qt.rgba(0, 0, 0, 1)
        case "white":     return Qt.rgba(1, 1, 1, 1)
        }
        return themeText
    }

    function colorLabel(id) {
        var c = colorChoices.find(function (x) { return x.id === id })
        return c ? c.label : id
    }

    function cycleColor(key, dir) {
        var n = colorChoices.length
        var i = colorChoices.findIndex(function (c) { return c.id === root[key] })
        if (i < 0) i = 0
        root[key] = colorChoices[((i + dir) % n + n) % n].id
        saveState()
    }

    // solid: backgrounds, alpha = pct (ignores the source colour's own alpha)
    function solid(c, pct) {
        return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, pct / 100)))
    }
    // fade: foreground, source alpha scaled by pct
    function fade(c, pct) {
        return Qt.rgba(c.r, c.g, c.b, c.a * Math.max(0, Math.min(1, pct / 100)))
    }

    readonly property int edgeGap: 0
    // how much of the panel must stay on screen when dragged past borders
    readonly property int keepVisible: 40

    // box around the icon glyph = icon size + 12px
    readonly property int iconBox: showIcons ? iconSize + 12 : 0

    // colours derived from the theme + colour/opacity settings
    readonly property color panelColor: solid(themeColor(panelBgColor), panelOpacity)
    readonly property color itemColor: solid(themeColor(itemBgColor), itemOpacity)
    readonly property color itemHoverColor: solid(themeColor(itemBgActiveColor),
                                                  Math.min(100, itemOpacity + hoverBoost))

    // Offsets that put the (scaled) panel in the middle of the screen.
    // The panel is anchored top/right and scaled from its top-right corner,
    // so: right edge = winW - sideGap + offsetX, top edge = topGap + offsetY.
    readonly property real panelScale: menuSize / 100
    readonly property real centerOffsetX: winW > 0
        ? sideGap - winW / 2 + cardWidth * panelScale / 2
        : posDefaults.offsetX
    readonly property real centerOffsetY: (winH > 0 && panelH > 0)
        ? winH / 2 - panelH * panelScale / 2 - topGap
        : posDefaults.offsetY

    readonly property bool movedFromDefault:
        Math.abs(offsetX - centerOffsetX) > 0.5
        || Math.abs(offsetY - centerOffsetY) > 0.5
    readonly property bool modified:
    movedFromDefault
    || numKeys.some(k => root[k] !== numSpec[k].def)
    || boolKeys.some(k => root[k] !== boolDefaults[k])
    || colorKeys.some(k => root[k] !== colorDefaults[k])
    || accentSource !== "accent"
    || JSON.stringify(hiddenNames) !== JSON.stringify(hiddenDefaults)

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/powermenu-state.json"

    onCurrentIndexChanged: confirmName = ""

    // ---- actions ----------------------------------------------------------
    // `glyph` is a Nerd Font icon drawn in the chosen icon colour.
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
        { keys: "Shift + Tab",            desc: "Move selection back" },
        { keys: "Home / End",             desc: "First / last action" },
        { keys: "Enter / Space / LMB",    desc: "Run selected action" },
        { keys: "C / RMB (any button)",   desc: "Open settings" },
        { keys: "Tab / Shift + Tab",      desc: "Settings: next / previous control" },
        { keys: "← → / PgUp PgDn",        desc: "Settings: adjust slider" },
        { keys: "← → / Space",            desc: "Settings: cycle color" },
        { keys: "Space / Enter",          desc: "Settings: toggle / press" },
        { keys: "Drag handle",            desc: "Move the menu" },
        { keys: "Drag title bar",         desc: "Move the settings window" },
        { keys: "Shift + Scroll",         desc: "Zoom the settings window" },
        { keys: "Double-click title",     desc: "Reset settings window" }
    ]
    readonly property var keybindActionKeys: actions.map(function (a) {
        return { keys: a.key.toUpperCase(), desc: a.label }
    })

    // per-icon multiplier, looked up from the *IconScale properties at the top
    function iconScaleOf(name) {
        var v = root[name + "IconScale"]
        return (typeof v === "number" && v > 0) ? v : 1.0
    }
    function iconOffsetOf(name) {
        var v = root[name + "IconOffsetX"]
        return (typeof v === "number") ? v : root.iconOffsetX
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

    // ---- keyboard focus helpers (settings window) ---------------------------
    // Move keyboard focus to the next / previous Tab-focusable item. Wrapping
    // onto the window's content item (not focusable) is ignored.
    function focusStep(item, forward) {
        var n = item.nextItemInFocusChain(forward)
        if (n && n.activeFocusOnTab)
            n.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
    }

    // Scroll the enclosing Flickable (if any) so `item` is fully visible,
    // with `margin` px of breathing room (shows the section header above it).
    function ensureVisible(item, margin) {
        var f = item.parent
        while (f && !(f.contentY !== undefined && f.contentHeight !== undefined))
            f = f.parent
        if (!f)
            return
        var p = item.mapToItem(f.contentItem, 0, 0)
        var top = p.y - margin
        var bottom = p.y + item.height + margin / 2
        var maxY = Math.max(0, f.contentHeight - f.height)
        if (top < f.contentY)
            f.contentY = Math.max(0, top)
        else if (bottom > f.contentY + f.height)
            f.contentY = Math.min(maxY, bottom - f.height)
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
        settingsDragging = false
        showing = true   // onShowingChanged mounts the window
    }

    function closeMenu() {
        showing = false
        settingsOpen = false
        dragging = false
        settingsDragging = false
        confirmName = ""
    }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    function openSettings() {
        if (!showing) openMenu()
        dragging = false
        settingsDragging = false
        settingsOpen = true
    }
    function closeSettings() {
        settingsOpen = false
        dragging = false
        settingsDragging = false
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
        root.setPosition(root.centerOffsetX, root.centerOffsetY)
        root.saveState()
    }

    function resetAll() {
        root.hiddenNames = hiddenDefaults.slice()
        numKeys.forEach(function (k) { root[k] = numSpec[k].def })
        boolKeys.forEach(function (k) { root[k] = boolDefaults[k] })
        colorKeys.forEach(function (k) { root[k] = colorDefaults[k] })
        root.accentSource = "accent"
        root.currentIndex = 0
        reclamp()
        saveState()
    }

    function saveState() {
        var s = { hidden: root.hiddenNames, accentSource: root.accentSource }
        posKeys.forEach(function (k) { s[k] = root[k] })
        numKeys.forEach(function (k) { s[k] = root[k] })
        boolKeys.forEach(function (k) { s[k] = root[k] })
        colorKeys.forEach(function (k) { s[k] = root[k] })
        s.settingsZoom = root.settingsZoom
        if (root.settingsPosSet) {
            s.settingsX = root.settingsX
            s.settingsY = root.settingsY
        }
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

    // ---- settings window geometry -------------------------------------------
    // Size of the settings card in screen px (follows the zoom).
    readonly property real settingsWinW: Math.round(Math.min(440 * menuUi, (targetScreen?.width ?? 1920) * 0.95))
    readonly property real settingsWinH: Math.round(Math.min(640 * menuUi, (targetScreen?.height ?? 1080) * 0.88))

    // Keep at least `keepVisible` px of the card on screen; the title bar
    // (top edge) never leaves the screen so it can always be grabbed again.
    function clampSX(x) {
        var sw = targetScreen?.width ?? 1920
        return Math.round(Math.max(keepVisible - settingsWinW, Math.min(sw - keepVisible, x)))
    }
    function clampSY(y) {
        var sh = targetScreen?.height ?? 1080
        return Math.round(Math.max(0, Math.min(sh - keepVisible, y)))
    }

    // Where the card is actually drawn: the saved position (clamped to the
    // current screen), or centred when it was never moved.
    readonly property real settingsEffX: settingsPosSet
        ? clampSX(settingsX)
        : Math.round(((targetScreen?.width ?? 1920) - settingsWinW) / 2)
    readonly property real settingsEffY: settingsPosSet
        ? clampSY(settingsY)
        : Math.round(((targetScreen?.height ?? 1080) - settingsWinH) / 2)

    function setSettingsPos(x, y) {
        root.settingsX = clampSX(x)
        root.settingsY = clampSY(y)
        root.settingsPosSet = true
    }

    // Zoom the settings window. If it has been moved, it zooms around its centre;
    // if it is still auto-centred it simply stays centred.
    function setSettingsZoom(z) {
        var nz = Math.max(zoomMin, Math.min(zoomMax, Math.round(z * 100) / 100))
        if (nz === root.settingsZoom)
            return
        if (root.settingsPosSet) {
            var cx = root.settingsEffX + root.settingsWinW / 2
            var cy = root.settingsEffY + root.settingsWinH / 2
            root.settingsZoom = nz                      // settingsWinW / H update here
            root.settingsX = clampSX(cx - root.settingsWinW / 2)
            root.settingsY = clampSY(cy - root.settingsWinH / 2)
        } else {
            root.settingsZoom = nz
        }
        zoomSaveTimer.restart()
    }

    function resetSettingsWindow() {
        root.settingsPosSet = false
        root.settingsZoom = 1.0
        root.saveState()
    }

    // wheel notches fire many times a second: save once it settles
    Timer {
        id: zoomSaveTimer
        interval: 400
        onTriggered: root.saveState()
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
                root.colorKeys.forEach(function (k) {
                    if (typeof s[k] === "string"
                            && root.colorChoices.some(function (c) { return c.id === s[k] }))
                        root[k] = s[k]
                })
                if (typeof s.accentSource === "string"
                        && root.accentChoices.some(function (c) { return c.id === s.accentSource }))
                    root.accentSource = s.accentSource

                // settings window zoom + position
                if (typeof s.settingsZoom === "number")
                    root.settingsZoom = Math.max(root.zoomMin, Math.min(root.zoomMax, s.settingsZoom))
                if (typeof s.settingsX === "number" && typeof s.settingsY === "number") {
                    root.settingsX = s.settingsX
                    root.settingsY = s.settingsY
                    root.settingsPosSet = true
                }
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
                    var shift = (event.modifiers & Qt.ShiftModifier) !== 0

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

                    // Shift+Tab: some platforms send Key_Tab + Shift, others Key_Backtab.
                    // Checked before plain Tab so it is never read as "forward".
                    if (event.key === Qt.Key_Backtab
                            || (event.key === Qt.Key_Tab && shift)
                            || event.key === Qt.Key_Up
                            || event.key === Qt.Key_Left) {
                        root.moveSelection(-1)
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Tab
                            || event.key === Qt.Key_Down
                            || event.key === Qt.Key_Right) {
                        root.moveSelection(1)
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Home) {
                        root.currentIndex = 0
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_End) {
                        root.currentIndex = Math.max(0, root.visibleActions.length - 1)
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
                    onHeightChanged: {
                        root.panelH = height
                        if (root.showing) root.setPosition(root.offsetX, root.offsetY)
                    }
                    Component.onCompleted: root.panelH = height

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

                                    // "active" = selected, hovered or pressed; everything else is "inactive"
                                    readonly property bool active: entryArea.pressed || entryArea.containsMouse || entry.focused

                                    readonly property color labelCol: entry.pending
                                        ? root.themeColor(root.pendingColor)
                                        : (entry.active
                                            ? root.fade(root.themeColor(root.labelActiveColor), root.labelActiveOpacity)
                                            : root.fade(root.themeColor(root.labelColor), root.labelOpacity))
                                    readonly property color iconCol: entry.pending
                                        ? root.themeColor(root.pendingColor)
                                        : (entry.active
                                            ? root.fade(root.themeColor(root.iconActiveColor), root.iconActiveOpacity)
                                            : root.fade(root.themeColor(root.iconColor), root.iconOpacity))

                                    z: entryTip.shown ? 100 : 0
                                    width: root.horizontal
                                        ? Math.max(0, (actionGrid.width - root.itemSpacing * (count - 1)) / count)
                                        : actionGrid.width
                                    height: root.itemHeight
                                    radius: root.itemRadius
                                    color: entry.active
                                        ? root.itemHoverColor
                                        : root.itemColor
                                    border.width: entry.focused ? root.borderWidth : root.inactiveBorderWidth
                                    border.color: entry.pending
                                        ? root.themeColor(root.pendingBorderColor)
                                        : (entry.focused
                                            ? root.fade(root.themeColor(root.borderColor), root.borderOpacity)
                                            : root.fade(root.themeColor(root.inactiveBorderColor), root.inactiveBorderOpacity))
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

                                        // Font icon, coloured by the icon colour settings
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.horizontalCenterOffset: root.horizontal ? 0 : root.iconOffsetOf(entry.modelData.name)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: entry.modelData.glyph
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: Math.round(root.iconSize * root.iconScaleOf(entry.modelData.name))
                                            color: entry.iconCol
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }

                                    Text {
                                        id: eLabel
                                        visible: root.showLabels
                                        text: entry.pending ? entry.modelData.label + "?" : entry.modelData.label
                                        font.pixelSize: root.labelSize
                                        font.bold: true
                                        color: entry.labelCol
                                        Behavior on color { ColorAnimation { duration: 120 } }
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
                                        color: root.fade(root.themeColor(root.keyHintBgColor), root.keyHintBgOpacity)

                                        Text {
                                            anchors.centerIn: parent
                                            text: entry.modelData.key.toUpperCase()
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: root.fade(root.themeColor(root.keyHintColor), root.keyHintOpacity)
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
                    }
                }
            }
        }
    }

    // ---- settings window ----------------------------------------------------
    // Look matches the wallpaper picker's settings menu: JetBrains Mono, the same text
    // sizes, hub.json radius, and everything scaled by `u` (= root.menuUi, which
    // includes the Shift+scroll zoom).
    //
    // The layer surface is full-screen and transparent; only `card` receives
    // input (mask), and `card` is what gets positioned. That makes dragging
    // jitter-free: the surface never moves, the card does. Position and zoom are
    // persisted in the state file.
    //
    // The surface uses its own layer namespace (root.settingsNamespace). Because it
    // is full-screen, a blur layer rule for it should use `ignorealpha`, otherwise
    // the whole screen would be blurred.
    //
    // Compact layout: sliders, colour pickers and toggles sit in plain `Grid`s
    // (2 columns, 3 for the key list), so the whole page needs far less scrolling.
    //
    // Keyboard: every toggle, slider, colour picker and footer button is
    // Tab-focusable (Qt's normal focus chain, in visual order). Tab / Shift+Tab or
    // Up / Down move between controls, Left / Right (PgUp / PgDn for bigger
    // steps, Home / End for min / max) adjust a focused slider or cycle a colour,
    // Space / Enter flips a toggle or presses a button, and the page auto-scrolls
    // to keep the focused control in view. Esc or C closes the window.
    //
    // Mouse: drag the title bar to move, Shift + scroll to zoom, double-click the
    // title bar to re-centre and reset the zoom.
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin
            screen: root.targetScreen

            readonly property real u: root.menuUi

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: root.settingsNamespace
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // only the card takes input; everything else falls through to the menu
            mask: Region { item: card }

            Item {
                id: card
                x: root.settingsEffX
                y: root.settingsEffY
                width: root.settingsWinW
                height: root.settingsWinH

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

                    // Fallback keys, only reached when the focused control did not
                    // handle the key (or nothing is focused yet): scrolling and C.
                    // Tab / Shift+Tab are deliberately NOT handled here so Qt's focus
                    // chain moves between controls.
                    Keys.onPressed: function (event) {
                        var maxY = Math.max(0, flick.contentHeight - flick.height)
                        var step = 48 * settingsWin.u
                        var page = flick.height * 0.9
                        var dy = 0

                        switch (event.key) {
                        case Qt.Key_Down:     dy = step;  break
                        case Qt.Key_Up:       dy = -step; break
                        case Qt.Key_PageDown: dy = page;  break
                        case Qt.Key_PageUp:   dy = -page; break
                        case Qt.Key_Home:     flick.contentY = 0;    event.accepted = true; return
                        case Qt.Key_End:      flick.contentY = maxY; event.accepted = true; return
                        case Qt.Key_C:        root.closeSettings();  event.accepted = true; return
                        default: return   // Tab, Escape etc. are handled elsewhere
                        }
                        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + dy))
                        event.accepted = true
                    }

                    // header (also the drag handle for the whole window)
                    Item {
                        id: head
                        anchors.top: parent.top
                        width: parent.width
                        height: 52 * settingsWin.u

                        // Drag area. Coordinates are taken in the (static) window
                        // frame, so moving the card does not feed back into the drag.
                        MouseArea {
                            id: headDrag
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property real pressX: 0
                            property real pressY: 0
                            property real startX: 0
                            property real startY: 0

                            onPressed: mouse => {
                                var p = headDrag.mapToItem(null, mouse.x, mouse.y)
                                pressX = p.x
                                pressY = p.y
                                startX = root.settingsEffX
                                startY = root.settingsEffY
                                root.settingsDragging = true
                            }
                            onPositionChanged: mouse => {
                                if (!root.settingsDragging) return
                                var p = headDrag.mapToItem(null, mouse.x, mouse.y)
                                root.setSettingsPos(startX + (p.x - pressX), startY + (p.y - pressY))
                            }
                            onReleased: {
                                if (!root.settingsDragging) return
                                root.settingsDragging = false
                                root.saveState()
                            }
                            onCanceled: {
                                if (!root.settingsDragging) return
                                root.settingsDragging = false
                                root.saveState()
                            }
                            onDoubleClicked: root.resetSettingsWindow()
                        }

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
                            text: "Drag · Tab · Shift+scroll"
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
                            CustomizationSettings.SectionHeader { host: root; text: "General" }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                CustomizationSettings.ToggleRow {
                                    host: root
                                    key: "showTooltips"
                                    label: "Tooltips"
                                    checked: root.showTooltips
                                }
                                CustomizationSettings.SliderRow { host: root; key: "menuSize"; label: "Scale" }
                                CustomizationSettings.SliderRow { host: root; key: "animMs"; label: "Animation" }
                            }

                            // ---------------- LAYOUT & CONTENT ----------------
                            CustomizationSettings.SectionHeader { host: root; text: "Layout & content" }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                CustomizationSettings.ToggleRow { host: root; key: "horizontal"; label: "Horizontal"; checked: root.horizontal }
                                CustomizationSettings.ToggleRow { host: root; key: "showIcons"; label: "Icons"; checked: root.showIcons }
                                CustomizationSettings.ToggleRow { host: root; key: "showLabels"; label: "Labels"; checked: root.showLabels }
                                CustomizationSettings.ToggleRow {
                                    host: root
                                    key: "showKeyHints"
                                    label: "Key hints"
                                    checked: root.showKeyHints
                                    enabled: !root.horizontal
                                }
                                CustomizationSettings.SliderRow { host: root; key: "cardWidth"; label: "Width" }
                                CustomizationSettings.SliderRow { host: root; key: "itemHeight"; label: "Item height" }
                                CustomizationSettings.SliderRow { host: root; key: "itemSpacing"; label: "Item spacing" }
                                CustomizationSettings.SliderRow { host: root; key: "panelPadding"; label: "Panel padding" }
                            }

                            // ---------------- APPEARANCE ----------------
                            CustomizationSettings.SectionHeader { host: root; text: "Appearance" }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                CustomizationSettings.SliderRow { host: root; key: "panelRadius"; label: "Panel roundness" }
                                CustomizationSettings.SliderRow { host: root; key: "itemRadius"; label: "Item roundness" }
                                CustomizationSettings.SliderRow { host: root; key: "iconSize"; label: "Icon size"; enabled: root.showIcons }
                                CustomizationSettings.SliderRow { host: root; key: "labelSize"; label: "Label size"; enabled: root.showLabels }
                                CustomizationSettings.SliderRow { host: root; key: "borderWidth"; label: "Active border" }
                                CustomizationSettings.SliderRow { host: root; key: "inactiveBorderWidth"; label: "Inactive border" }
                                CustomizationSettings.SliderRow { host: root; key: "panelOpacity"; label: "Panel opacity" }
                                CustomizationSettings.SliderRow { host: root; key: "dimOpacity"; label: "Screen dim" }
                            }

                            // ---------------- COLORS ----------------
                            CustomizationSettings.SectionHeader { host: root; text: "Colors" }
                            Item {
                                id: acRow
                                width: contentCol.width
                                height: 50 * settingsWin.u
                                activeFocusOnTab: true

                                onActiveFocusChanged: if (activeFocus) root.ensureVisible(acRow, 32 * settingsWin.u)

                                Keys.onPressed: function (event) {
                                    if (event.key === Qt.Key_Left) {
                                        root.cycleAccent(-1)
                                    } else if (event.key === Qt.Key_Right
                                            || event.key === Qt.Key_Space
                                            || event.key === Qt.Key_Return
                                            || event.key === Qt.Key_Enter) {
                                        root.cycleAccent(1)
                                    } else if (event.key === Qt.Key_Down) {
                                        root.focusStep(acRow, true)
                                    } else if (event.key === Qt.Key_Up) {
                                        root.focusStep(acRow, false)
                                    } else {
                                        return
                                    }
                                    event.accepted = true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3 * settingsWin.u
                                    radius: Math.min(8 * settingsWin.u, root.th.radius * settingsWin.u)
                                    color: "transparent"
                                    visible: acRow.activeFocus
                                    border.width: Math.max(1, Math.round(settingsWin.u))
                                    border.color: root.cAccent
                                }

                                Text {
                                    y: 4 * settingsWin.u
                                    text: "Highlight color"
                                    font.family: root.th.fontFamily
                                    font.pixelSize: root.th.textSizeGroup * settingsWin.u
                                    font.bold: true
                                    color: Theme.text
                                }

                                Row {
                                    id: acSegs
                                    y: 22 * settingsWin.u
                                    width: parent.width
                                    spacing: 6 * settingsWin.u

                                    Repeater {
                                        model: root.accentChoices
                                        delegate: Rectangle {
                                            id: seg
                                            required property var modelData
                                            readonly property bool picked: root.accentSource === modelData.id
                                            width: (acSegs.width - 2 * acSegs.spacing) / 3
                                            height: 24 * settingsWin.u
                                            radius: Math.min(8 * settingsWin.u, root.th.radius * settingsWin.u)
                                            color: seg.picked
                                                ? Theme.alpha(root.accentColorOf(modelData.id), 0.18)
                                                : (segArea.containsMouse ? Theme.alpha(Theme.text, 0.08) : "transparent")
                                            border.width: 1
                                            border.color: seg.picked
                                                ? root.accentColorOf(modelData.id)
                                                : Theme.alpha(Theme.text, 0.2)

                                            // swatch of the Theme colour this choice maps to
                                            Rectangle {
                                                id: dot
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8 * settingsWin.u
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 10 * settingsWin.u
                                                height: 10 * settingsWin.u
                                                radius: width / 2
                                                color: root.accentColorOf(seg.modelData.id)
                                            }
                                            Text {
                                                anchors.left: dot.right
                                                anchors.leftMargin: 6 * settingsWin.u
                                                anchors.right: parent.right
                                                anchors.rightMargin: 4 * settingsWin.u
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                                text: seg.modelData.label
                                                font.family: root.th.fontFamily
                                                font.pixelSize: root.th.textSizeBody * settingsWin.u
                                                font.bold: seg.picked
                                                color: seg.picked ? Theme.text : Theme.textDim
                                            }
                                            MouseArea {
                                                id: segArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    acRow.forceActiveFocus()
                                                    root.accentSource = seg.modelData.id
                                                    root.saveState()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                CustomizationSettings.ToggleRow { host: root; colorKey: "panelBgColor"; label: "Panel background" }
                            }

                            // ---------------- INACTIVE ITEMS ----------------
                            CustomizationSettings.SectionHeader { host: root; text: "Inactive items" }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                CustomizationSettings.ToggleRow { host: root; colorKey: "itemBgColor"; label: "Background" }
                                CustomizationSettings.SliderRow { host: root; key: "itemOpacity"; label: "Background opacity" }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "labelColor"; label: "Label color"; enabled: root.showLabels }
                                CustomizationSettings.SliderRow { host: root; key: "labelOpacity"; label: "Label opacity"; enabled: root.showLabels }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "iconColor"; label: "Icon color"; enabled: root.showIcons }
                                CustomizationSettings.SliderRow { host: root; key: "iconOpacity"; label: "Icon opacity"; enabled: root.showIcons }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "inactiveBorderColor"; label: "Border color" }
                                CustomizationSettings.SliderRow { host: root; key: "inactiveBorderOpacity"; label: "Border opacity" }
                            }

                            // ---------------- ACTIVE ITEMS ----------------
                            CustomizationSettings.SectionHeader { host: root; text: "Active items" }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                CustomizationSettings.ToggleRow { host: root; colorKey: "itemBgActiveColor"; label: "Background" }
                                CustomizationSettings.SliderRow { host: root; key: "hoverBoost"; label: "Background boost" }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "labelActiveColor"; label: "Label color"; enabled: root.showLabels }
                                CustomizationSettings.SliderRow { host: root; key: "labelActiveOpacity"; label: "Label opacity"; enabled: root.showLabels }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "iconActiveColor"; label: "Icon color"; enabled: root.showIcons }
                                CustomizationSettings.SliderRow { host: root; key: "iconActiveOpacity"; label: "Icon opacity"; enabled: root.showIcons }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "borderColor"; label: "Border color" }
                                CustomizationSettings.SliderRow { host: root; key: "borderOpacity"; label: "Border opacity" }
                            }

                            // ---------------- KEY HINTS & CONFIRM ----------------
                            CustomizationSettings.SectionHeader { host: root; text: "Key hints & confirm" }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                CustomizationSettings.ToggleRow { host: root; colorKey: "keyHintColor"; label: "Hint text color"; enabled: !root.horizontal && root.showKeyHints }
                                CustomizationSettings.SliderRow { host: root; key: "keyHintOpacity"; label: "Hint text opacity"; enabled: !root.horizontal && root.showKeyHints }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "keyHintBgColor"; label: "Hint badge color"; enabled: !root.horizontal && root.showKeyHints }
                                CustomizationSettings.SliderRow { host: root; key: "keyHintBgOpacity"; label: "Hint badge opacity"; enabled: !root.horizontal && root.showKeyHints }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "pendingColor"; label: "Confirm text / icon" }
                                CustomizationSettings.ToggleRow { host: root; colorKey: "pendingBorderColor"; label: "Confirm border" }
                            }

                            // ---------------- BEHAVIOR ----------------
                            CustomizationSettings.SectionHeader { host: root; text: "Behavior" }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                CustomizationSettings.ToggleRow { host: root; key: "confirmDangerous"; label: "Confirm danger"; checked: root.confirmDangerous }
                                CustomizationSettings.ToggleRow { host: root; key: "wrapNav"; label: "Wrap around"; checked: root.wrapNav }
                                CustomizationSettings.ToggleRow { host: root; key: "hoverSelect"; label: "Hover selects"; checked: root.hoverSelect }
                                CustomizationSettings.ToggleRow { host: root; key: "closeOnOutside"; label: "Click outside"; checked: root.closeOnOutside }
                            }

                            // ---------------- VISIBLE ACTIONS ----------------
                            CustomizationSettings.SectionHeader { host: root; text: "Visible actions" }
                            Grid {
                                width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                Repeater {
                                    model: root.actions
                                    delegate: CustomizationSettings.ToggleRow {
                                        required property var modelData
                                        host: root
                                        label: modelData.label + " (" + modelData.key.toUpperCase() + ")"
                                        checked: root.hiddenNames.indexOf(modelData.name) < 0
                                        onToggled: root.toggleAction(modelData.name)
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

                            CustomizationSettings.ActionButton {
                                host: root
                                label: "Reset all"
                                enabled: root.modified
                                onClicked: root.resetAll()
                            }
                            CustomizationSettings.ActionButton {
                                host: root
                                label: "Reset position"
                                enabled: root.movedFromDefault
                                onClicked: root.resetPosition()
                            }
                        }

                        CustomizationSettings.ActionButton {
                            host: root
                            anchors.right: parent.right
                            anchors.rightMargin: 20 * settingsWin.u
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Done"
                            primary: true
                            onClicked: root.closeSettings()
                        }
                    }
                }

                // Shift + scroll = zoom the whole settings window. Sits above
                // everything else in the card and only takes wheel events that
                // carry Shift; plain scrolling is passed on to the Flickable,
                // and clicks are never touched (no buttons accepted).
                MouseArea {
                    id: zoomArea
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        if (!(wheel.modifiers & Qt.ShiftModifier)) {
                            wheel.accepted = false
                            return
                        }
                        // some stacks turn Shift+wheel into a horizontal scroll
                        var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                        if (d !== 0)
                            root.setSettingsZoom(root.settingsZoom + (d / 120) * root.zoomStep)
                        wheel.accepted = true
                    }
                }
            }
        }
    }

    // ---- menu-only component -----------------------------------------------
    // Lightweight hover hint drawn inside the host's own window (no extra
    // popup surface). Appears after a short delay, only if `allowed`.
    // The host should raise its own z while `shown` so the hint isn't covered
    // by siblings. Used by the main menu only; always renders at 12px on screen.
    // (Stays here because it depends on the menu's own scale, root.menuSize.)
    component Tip: Rectangle {
        id: tp
        property string text: ""
        property bool allowed: false
        property bool hovered: false
        // Default cancels the panel's scale (menuSize / 100) so the tooltip
        // always renders at 12px.
        property real u: 100 / root.menuSize
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
            font.pixelSize: 12 * tp.u
            color: Theme.text
        }
    }
}