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

    Component.onCompleted: BluetoothState.init()

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
            } catch (e) { console.warn("quickactions: malformed hub.json:", e) }
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
    property bool nightOn: false           // desired / displayed night light state
    property bool nightWasOn: false        // what was last actually applied
    property int nightRetries: 0           // restart attempts if gammastep isn't running
    property bool dndOn: false
    property real brightness: 0.6          // 0..1, synced from brightnessctl
    readonly property bool btOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    // true while any device is mid-connect (reconnectRemembered(), manual connect, etc.)
    readonly property bool btConnecting: {
        const a = Bluetooth.defaultAdapter
        if (!a || !a.enabled || !a.devices) return false
        const devs = a.devices.values !== undefined ? a.devices.values : a.devices
        for (let i = 0; i < devs.length; i++)
        if (devs[i].state === BluetoothDeviceState.Connecting) return true
        return false
    }

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

    // rows shown in the "Keybinds" section at the end of the settings menu:
    // general keys (one per line) and the per-action keys (shown in a grid)
    readonly property var keybindGeneral: [
        { keys: "Esc / Click outside",    desc: "Close menu / settings" },
        { keys: "↑ ↓ ← → Tab",            desc: "Move selection" },
        { keys: "Enter / Space / LMB",    desc: "Run / toggle selected" },
        { keys: "+ - PgUp PgDn / Scroll", desc: "Adjust brightness / night" },
        { keys: "C / RMB (any button)",   desc: "Open settings" },
        { keys: "Drag handle",            desc: "Move the menu" }
    ]
    readonly property var keybindActionKeys: actions.map(function (a) {
        return { keys: a.key.toUpperCase(), desc: a.label }
    })

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
        case "wifi":   return wifiOn ? "\udb81\udda9" : "\udb81\uddaa"
        case "bt":     return btOn ? "\udb80\udcaf" : "\udb80\udcb2"
        case "night":  return "\uf186"                                    // moon
        case "dnd":    return dndOn ? "\udb80\udc9b" : "\udb80\udc9a"
        case "bright": return "\uf185"                                    // sun
        }
        return ""
    }

    function stateText(a) {
        if (a.adjust) return Math.round(root.brightness * 100) + "%"
        if (a.adjustTemp) return (root.nightOn ? "ON " : "OFF ") + root.nightTemp + "K"
        if (a.toggle) return root.isOn(a.name) ? "ON" : "OFF"
        return ""
    }

    // 0..1 fill of the selection border for brightness / night light rows
    function progressFor(a) {
        if (a.adjust)
            return Math.max(0, Math.min(1, root.brightness))
        if (a.adjustTemp) {
            var s = root.numSpec.nightTemp
            return Math.max(0, Math.min(1, (root.nightTemp - s.min) / (s.max - s.min)))
        }
        return 0
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    // width of one cell when `p` is a multi-column Grid, else the full width
    function cellW(p) {
        if (!p) return 0
        if (p.columns !== undefined && p.columns > 1 && p.columnSpacing !== undefined)
            return Math.floor((p.width - (p.columns - 1) * p.columnSpacing) / p.columns)
        return p.width
    }

    // ---- state readers ----------------------------------------------------
    Process {
        id: wifiCheck
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiOn = text.trim() === "enabled"
        }
    }

    // Ignored while a night-light change is pending or still settling, so a
    // check that races with the apply script can't flip the state back.
    // If night light is supposed to be ON (saved state after a reboot/logout,
    // or gammastep died) but nothing is running, start it again instead of
    // silently switching the toggle off. Gives up after a few attempts.
    Process {
        id: nightCheck
        command: ["pgrep", "-x", "gammastep"]
        onExited: function (code) {
            if (nightApplyTimer.running || nightSettleTimer.running)
                return
            if (code === 0) {
                root.nightOn = true
                root.nightWasOn = true
                root.nightRetries = 0
            } else if (root.nightOn && root.nightRetries < 5) {
                root.nightRetries++
                root.nightWasOn = false
                root.applyNight()
            } else {
                root.nightOn = false
                root.nightWasOn = false
            }
        }
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

    function refreshStates(withNight) {
        wifiCheck.running = true
        dndCheck.running = true
        brightCheck.running = true
        if (withNight && !nightApplyTimer.running && !nightSettleTimer.running)
            nightCheck.running = true
    }

    // re-sync with reality shortly after a toggle (night light is excluded:
    // it is driven by the serialized apply below, not by polling)
    Timer {
        id: recheckTimer
        interval: 700
        onTriggered: root.refreshStates(false)
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

    // ---- night light restore at login ---------------------------------------
    // Right after login the compositor may not be fully ready, and gammastep can
    // be alive without actually having applied anything (so "is it running?"
    // is not good enough). On the first start of a session we therefore force a
    // clean (re)apply twice, a few seconds apart. A marker in XDG_RUNTIME_DIR
    // (wiped on logout/reboot) tells a fresh login from a plain shell reload,
    // where gammastep is left alone.
    Process {
        id: sessionProbe
        command: ["sh", "-c",
            "m=\"${XDG_RUNTIME_DIR:-/tmp}/qa-night-restored\"; "
            + "if [ -e \"$m\" ]; then echo reload; else : > \"$m\"; echo fresh; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "fresh" && root.nightOn) {
                    bootApplyTimer.count = 0
                    bootApplyTimer.start()
                } else {
                    nightCheck.running = true
                }
            }
        }
    }

    Timer {
        id: bootApplyTimer
        interval: 2500
        repeat: true
        property int count: 0
        onTriggered: {
            count++
            if (!root.nightOn || count > 2) {
                stop()
                return
            }
            root.nightWasOn = false
            root.nightRetries = 0
            root.applyNight()
            if (count >= 2)
                stop()
        }
    }

    // ---- night light (gammastep) -------------------------------------------
    // Rapid toggling used to start a new gammastep while the old one was still
    // shutting down; on Wayland only one gamma client may hold the output, so
    // the new one failed silently and the feature looked dead.
    //
    // Now:
    //  1. changes are debounced (nightApplyTimer) so only the final desired
    //     state is applied,
    //  2. the apply script runs under flock so two scripts never overlap,
    //  3. it kills gammastep, WAITS until it is really gone (and releases the
    //     gamma control), and only then starts a fresh one,
    //  4. state polling is suppressed while this is in flight.
    readonly property string nightScript:
        "exec 9>/tmp/qa-gammastep.lock; flock 9; "
        + "pkill -x gammastep; "
        + "i=0; while pgrep -x gammastep >/dev/null && [ $i -lt 40 ]; do sleep 0.05; i=$((i+1)); done; "
        + "pkill -9 -x gammastep 2>/dev/null; "
        + "sleep 0.15; "
        + "[ \"$1\" = off ] && exit 0; "
        + "setsid -f gammastep -O \"$1\" 9>&- >/dev/null 2>&1"

    function applyNight() {
        // nothing to do if it is off and was already off (e.g. only the
        // temperature slider moved)
        if (!root.nightOn && !root.nightWasOn)
            return
        Quickshell.execDetached({
            command: ["sh", "-c", root.nightScript, "sh",
                      root.nightOn ? String(root.nightTemp) : "off"]
        })
        root.nightWasOn = root.nightOn
        nightSettleTimer.restart()
    }

    Timer {
        id: nightApplyTimer
        interval: 150
        onTriggered: {
            root.applyNight()
            root.saveState()
        }
    }

    // keeps nightCheck from overriding the state while the script is running
    Timer {
        id: nightSettleTimer
        interval: 1500
        // verify that gammastep really came up (also covers early boot,
        // when the compositor may not be ready for the first attempt)
        onTriggered: if (root.nightOn) nightCheck.running = true
    }

    function setNightTemp(k) {
        var s = root.numSpec.nightTemp
        root.nightTemp = root.clamp(k, s.min, s.max)
        root.nightRetries = 0
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

    function toggleBluetooth() { BluetoothState.togglePower() }

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
            bootApplyTimer.stop()
            root.nightOn = !root.nightOn
            root.nightRetries = 0
            nightSettleTimer.restart()
            nightApplyTimer.restart()
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
        refreshStates(true)
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
        // the night light temperature slider should apply live while on
        if (key === "nightTemp")
            nightApplyTimer.restart()
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
        nightApplyTimer.restart()
    }

    function saveState() {
        var s = { hidden: root.hiddenNames, night: root.nightOn }
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

                // restore night light after reboot / logout / shell restart
                if (typeof s.night === "boolean") {
                    root.nightOn = s.night
                    root.nightWasOn = false
                    root.nightRetries = 0
                    // fresh login -> forced apply; shell reload -> just verify
                    sessionProbe.running = true
                }
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
                                    // 0..1 fill used by the progress border (brightness / night light)
                                    readonly property real progress: root.progressFor(modelData)
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
                                    // Scrollable rows (brightness / night light) draw their
                                    // border as a progress indicator instead (see below).
                                    border.width: (entry.focused && !entry.scrollable) ? root.borderWidth : 0
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

                                    // Progress border: the normal Rectangle border, revealed
                                    // from the left by a clipping item whose width follows the
                                    // value. 100% = the full normal border, 50% = left half,
                                    // 0% = nothing. Drawn by the same renderer as every other
                                    // border, so it stays perfectly sharp at any scale.
                                    Item {
                                        visible: entry.scrollable && entry.focused
                                            && root.borderWidth > 0 && entry.progress > 0
                                        x: 0
                                        y: 0
                                        width: Math.round(entry.width * entry.progress)
                                        height: entry.height
                                        clip: true

                                        Rectangle {
                                            width: entry.width
                                            height: entry.height
                                            radius: entry.radius
                                            color: "transparent"
                                            border.width: root.borderWidth
                                            border.color: Theme.accent
                                        }
                                    }
                                    // Blinking border while Bluetooth is connecting. Separate from the
                                    // focus border so both can coexist. The animation only runs while needed.
                                    Rectangle {
                                        visible: entry.modelData.name === "bt" && root.btConnecting
                                        anchors.fill: parent
                                        radius: entry.radius
                                        color: "transparent"
                                        border.width: Math.max(1, root.borderWidth)
                                        border.color: Theme.accent
                                        opacity: 1
                                        SequentialAnimation on opacity {
                                            running: parent.visible && root.animMs > 0
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.1; duration: 500; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
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
                                label: "\udb81\udc93"
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

    // ---- settings window ----------------------------------------------------
    // Look matches the wallpaper picker's settings menu: JetBrains Mono, the same text
    // sizes, hub.json radius, and everything scaled by `u` (= root.menuUi).
    // No custom layer namespace is set here (the picker sets none either), so the
    // compositor's layer rules, e.g. blur, apply to this window the same way.
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
                        text: "Quick actions settings"
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
                        QaTip {
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
                    anchors.topMargin: 4 * settingsWin.u
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

                        QaSectionHeader { host: root; text: "General" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            QaToggleRow { host: root; key: "showTooltips"; label: "Tooltips"; checked: root.showTooltips; tip: "Turn off to hide all hover hints" }
                            QaToggleRow { host: root; key: "showFooter"; label: "Settings button"; checked: root.showFooter; tip: "Hides the gear button; C and right-click still work" }
                            QaSliderRow { host: root; key: "menuSize"; label: "Scale"; tip: "Overall size of the menu" }
                            QaSliderRow { host: root; key: "animMs"; label: "Animation"; tip: "Animation duration. 0 disables animations" }
                        }

                        QaSectionHeader { host: root; text: "Layout & content" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            QaToggleRow { host: root; key: "horizontal"; label: "Horizontal"; checked: root.horizontal; tip: "Show actions in a row instead of a list" }
                            QaToggleRow { host: root; key: "showIcons"; label: "Icons"; checked: root.showIcons }
                            QaToggleRow { host: root; key: "showLabels"; label: "Labels"; checked: root.showLabels }
                            QaToggleRow {
                                host: root
                                key: "showState"
                                label: "State text"
                                checked: root.showState
                                enabled: !root.horizontal
                                tip: "ON / OFF status text on each row (vertical layout only)"
                            }
                            QaToggleRow {
                                host: root
                                key: "showKeyHints"
                                label: "Key hints"
                                checked: root.showKeyHints
                                enabled: !root.horizontal
                                tip: "Small key badges (vertical layout only)"
                            }
                            QaSliderRow { host: root; key: "cardWidth"; label: "Width" }
                            QaSliderRow { host: root; key: "itemHeight"; label: "Item height" }
                            QaSliderRow { host: root; key: "itemSpacing"; label: "Item spacing" }
                            QaSliderRow { host: root; key: "panelPadding"; label: "Panel padding" }
                        }

                        QaSectionHeader { host: root; text: "Appearance" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            QaSliderRow { host: root; key: "panelRadius"; label: "Panel roundness" }
                            QaSliderRow { host: root; key: "itemRadius"; label: "Item roundness" }
                            QaSliderRow { host: root; key: "iconSize"; label: "Icon size"; enabled: root.showIcons }
                            QaSliderRow { host: root; key: "labelSize"; label: "Label size"; enabled: root.showLabels }
                            QaSliderRow { host: root; key: "borderWidth"; label: "Selection border"; tip: "Also the thickness of the brightness / night light progress border" }
                            QaSliderRow { host: root; key: "panelOpacity"; label: "Panel opacity"; tip: "Panel background opacity" }
                            QaSliderRow { host: root; key: "itemOpacity"; label: "Item opacity"; tip: "Item background opacity" }
                            QaSliderRow { host: root; key: "hoverBoost"; label: "Hover highlight"; tip: "Extra opacity on hovered / selected items" }
                            QaSliderRow { host: root; key: "dimOpacity"; label: "Screen dim"; tip: "Dim the screen behind the menu" }
                        }

                        QaSectionHeader { host: root; text: "Quick actions" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            QaSliderRow { host: root; key: "brightnessStep"; label: "Brightness step"; tip: "Percent per scroll notch / keypress" }
                            QaSliderRow { host: root; key: "nightTemp"; label: "Night temperature"; tip: "Scroll over the Night light row to change it; applies live while on" }
                            QaSliderRow { host: root; key: "nightStep"; label: "Night step"; tip: "Kelvin per scroll notch / keypress" }
                        }

                        QaSectionHeader { host: root; text: "Behavior" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            QaToggleRow { host: root; key: "wrapNav"; label: "Wrap around"; checked: root.wrapNav; tip: "Wrap around when navigating with the keyboard" }
                            QaToggleRow { host: root; key: "hoverSelect"; label: "Hover selects"; checked: root.hoverSelect; tip: "Hovering an item selects it" }
                            QaToggleRow { host: root; key: "closeOnOutside"; label: "Click outside"; checked: root.closeOnOutside; tip: "Close the menu when clicking outside of it" }
                        }

                        QaSectionHeader { host: root; text: "Visible actions" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            Repeater {
                                model: root.actions
                                delegate: QaToggleRow {
                                    required property var modelData
                                    host: root
                                    label: modelData.label
                                    checked: root.hiddenNames.indexOf(modelData.name) < 0
                                    onToggled: root.toggleAction(modelData.name)
                                }
                            }
                        }

                        QaSectionHeader { host: root; text: "Keybinds" }
                        Repeater {
                            model: root.keybindGeneral
                            delegate: Item {
                                id: kbRow
                                required property var modelData
                                width: contentCol.width
                                height: 22 * settingsWin.u

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: kbChip.left
                                    anchors.rightMargin: 8 * settingsWin.u
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: kbRow.modelData.desc
                                    elide: Text.ElideRight
                                    font.family: root.th.fontFamily
                                    font.pixelSize: root.th.textSizeBody * settingsWin.u
                                    color: Theme.text
                                }

                                Rectangle {
                                    id: kbChip
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: kbChipText.implicitWidth + 14 * settingsWin.u
                                    height: 18 * settingsWin.u
                                    radius: 5 * settingsWin.u
                                    color: Theme.alpha(Theme.text, 0.08)

                                    Text {
                                        id: kbChipText
                                        anchors.centerIn: parent
                                        text: kbRow.modelData.keys
                                        font.family: root.th.fontFamily
                                        font.pixelSize: root.th.textSizeSmall * settingsWin.u
                                        font.bold: true
                                        color: Theme.textDim
                                    }
                                }
                            }
                        }
                        Item { width: 1; height: 4 * settingsWin.u }
                        Grid {
                            width: parent.width; columns: 3; columnSpacing: 18 * settingsWin.u
                            Repeater {
                                model: root.keybindActionKeys
                                delegate: Item {
                                    id: kbRow
                                    required property var modelData
                                    width: root.cellW(parent)
                                    height: 22 * settingsWin.u

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: kbChip.left
                                        anchors.rightMargin: 8 * settingsWin.u
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: kbRow.modelData.desc
                                        elide: Text.ElideRight
                                        font.family: root.th.fontFamily
                                        font.pixelSize: root.th.textSizeBody * settingsWin.u
                                        color: Theme.text
                                    }

                                    Rectangle {
                                        id: kbChip
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: kbChipText.implicitWidth + 14 * settingsWin.u
                                        height: 18 * settingsWin.u
                                        radius: 5 * settingsWin.u
                                        color: Theme.alpha(Theme.text, 0.08)

                                        Text {
                                            id: kbChipText
                                            anchors.centerIn: parent
                                            text: kbRow.modelData.keys
                                            font.family: root.th.fontFamily
                                            font.pixelSize: root.th.textSizeSmall * settingsWin.u
                                            font.bold: true
                                            color: Theme.textDim
                                        }
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

                        QaActionButton {
                            host: root
                            label: "Reset all"
                            enabled: root.modified
                            tipsOn: root.showTooltips
                            tip: "Restore every setting to its default"
                            tipSide: "above"
                            onClicked: root.resetAll()
                        }
                        QaActionButton {
                            host: root
                            label: "Reset position"
                            enabled: root.movedFromDefault
                            tipsOn: root.showTooltips
                            tip: "Move the menu back to its default spot"
                            tipSide: "above"
                            onClicked: root.resetPosition()
                        }
                    }
                    QaActionButton {
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
    component QaTip: Rectangle {
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

    // Settings-window components below take `host` (the root Scope) and read the
    // shared scale / font / sizes from host.menuUi and host.th, like the picker's.
    component QaActionButton: Rectangle {
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

        QaTip {
            id: abTip
            allowed: ab.tipsOn
            hovered: abArea.containsMouse
            side: ab.tipSide
            text: ab.tip
            u: ab.u
            family: ab.th.fontFamily
        }
    }

    component QaSectionHeader: Item {
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

    // Toggle row. With a `key` it flips that boolean setting on the host;
    // without one it just emits `toggled()` (used for the action list).
    component QaToggleRow: Item {
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

        QaTip {
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
    // host and saves on release.
    component QaSliderRow: Item {
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
            elide: Text.ElideRight
            text: sr.label
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

        QaTip {
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