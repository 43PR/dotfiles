pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import Quickshell.Services.UPower

Scope {
    id: root
    readonly property string home: Quickshell.env("HOME")
    // ───────────────────────── Settings (the important ones) ─────────────────────────
    readonly property var numSpec: ({
        uiScale:        { min: 70,   max: 160,  def: 95,  step: 5,   unit: "%" },
        textSize:       { min: 70,   max: 160,  def: 80,  step: 5,   unit: "%" },
        panelWidth:     { min: 280,  max: 520,  def: 330,  step: 10,  unit: "px" },
        panelHeight:    { min: 30,   max: 100,  def: 100,  step: 5,   unit: "%" },
        notifsHeight:   { min: 0,    max: 800,  def: 700,    step: 20,  unit: "px" },
        cornerRadius:   { min: 0,    max: 40,   def: 16,   step: 2,   unit: "px" },
        bgOpacity:      { min: 0,    max: 100,  def: 40,   step: 5,   unit: "%" },
        borderOpacity:  { min: 0,    max: 100,  def: 10,  step: 5,   unit: "%" },
        animMs:         { min: 0,    max: 500,  def: 200,  step: 20,  unit: " ms" },
        groupLimit:     { min: 2,    max: 8,    def: 3,    step: 1,   unit: "" },
        notifBgOpacity: { min: 0,    max: 100,  def: 35,   step: 5,   unit: "%" },
        brightnessStep: { min: 1,    max: 20,   def: 5,    step: 1,   unit: "%" },
        nightTemp:      { min: 2500, max: 6500, def: 5600, step: 100, unit: " K" },
        nightStep:      { min: 50,   max: 500,  def: 100,  step: 50,  unit: " K" },
        tiltStrength:   { min: 0,    max: 15,   def: 1,    step: 1,   unit: "" }
    })
    readonly property var numKeys: Object.keys(numSpec)
    readonly property var boolDefaults: ({
        showCalendar: true,
        showQuick: true,
        showNotifs: true,
        border: true,
        weekMonday: true,
        clock24: true,
        clockSeconds: false,
        toasts: true,
        soundEnabled: true,
        notifBgEnabled: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    property int uiScale: numSpec.uiScale.def
    property int textSize: numSpec.textSize.def
    property int panelWidth: numSpec.panelWidth.def
    property int panelHeight: numSpec.panelHeight.def
    property int notifsHeight: numSpec.notifsHeight.def
    property int cornerRadius: numSpec.cornerRadius.def
    property int bgOpacity: numSpec.bgOpacity.def
    property int borderOpacity: numSpec.borderOpacity.def
    property int animMs: numSpec.animMs.def
    property int groupLimit: numSpec.groupLimit.def
    property int notifBgOpacity: numSpec.notifBgOpacity.def
    property int brightnessStep: numSpec.brightnessStep.def
    property int nightTemp: numSpec.nightTemp.def
    property int nightStep: numSpec.nightStep.def
    property int tiltStrength: numSpec.tiltStrength.def

    property bool showCalendar: boolDefaults.showCalendar
    property bool showQuick: boolDefaults.showQuick
    property bool showNotifs: boolDefaults.showNotifs
    property bool border: boolDefaults.border
    property bool weekMonday: boolDefaults.weekMonday
    property bool clock24: boolDefaults.clock24
    property bool clockSeconds: boolDefaults.clockSeconds
    property bool toasts: boolDefaults.toasts
    property bool soundEnabled: boolDefaults.soundEnabled
    property bool notifBgEnabled: boolDefaults.notifBgEnabled
    // background picture shown centered behind the notification list
    readonly property string defaultNotifBg: home + "/Pictures/sigil.png"
    property string notifBgPath: defaultNotifBg
    property bool toastSet: false
    property real toastFx: 0.5
    property real toastY: 0
    // highlight colour: accent | accent2 | text
    property string accentSource: "accent"
    property string panelSide: "left"
    readonly property var accentChoices: [
        { id: "accent",  label: "Accent" },
        { id: "accent2", label: "Accent 2" },
        { id: "text",    label: "Text" }
    ]
    function accentColorOf(id) {
        switch (id) {
        case "accent2": return Theme.accent2 !== undefined ? Theme.accent2 : Theme.accent
        case "text":    return Theme.text
        }
        return Theme.accent
    }
    readonly property color cAccent: accentColorOf(accentSource)
    readonly property color cText: Theme.text
    readonly property color cDim: Theme.textDim

    // quick actions that can be shown / hidden
    readonly property var allActions: [
        { name: "wifi",   label: "Wi-Fi",          short: "Wi-Fi" },
        { name: "bt",     label: "Bluetooth",      short: "Bluetooth" },
        { name: "dnd",    label: "Do not disturb", short: "DND" },
        { name: "night",  label: "Night light",    short: "Night" },
        { name: "bright", label: "Brightness",     short: "Brightness" }
    ]
    property var hiddenNames: []
    readonly property var visibleTiles: allActions.filter(a => hiddenNames.indexOf(a.name) < 0)
    readonly property bool brightVisible: hiddenNames.indexOf("bright") < 0
    readonly property bool nightVisible: hiddenNames.indexOf("night") < 0
    // order of the three body sections
    readonly property var sectionIds: ["calendar", "quick", "notifs"]
    readonly property var defaultSectionOrder: ["notifs", "quick", "calendar"]
    property var sectionOrder: defaultSectionOrder.slice()

    readonly property bool modified:
        numKeys.some(k => root[k] !== numSpec[k].def)
        || boolKeys.some(k => root[k] !== boolDefaults[k])
        || accentSource !== "accent"
        || panelSide !== "left"
        || notifBgPath !== defaultNotifBg
        || toastSet
        || hiddenNames.length > 0
        || sectionOrder.join(",") !== defaultSectionOrder.join(",")
    // ───────────────────────── Scale helpers ─────────────────────────
    readonly property real ui: uiScale / 100
    readonly property real tx: textSize / 100
    function px(n) { return Math.round(n * ui); }              // layout sizes
    function fs(n) { return Math.round(n * ui * tx); }         // font sizes
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Math.round(v))); }
    function fmtValue(key, v) { return v + numSpec[key].unit; }
    // ───────────────────────── Bar geometry (fallback anchor) ─────────────────────────
    property string barPos: "left"
    property string barStyle: "joined"
    property int barThickness: 20
    property int barMargin: 4
    property real barScale: 0.9

    FileView {
        path: root.home + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const b = JSON.parse(text())
                if (typeof b.position === "string") root.barPos = b.position
                if (typeof b.style === "string") root.barStyle = b.style
                if (typeof b.thickness === "number") root.barThickness = b.thickness
                if (typeof b.margin === "number") root.barMargin = b.margin
                if (typeof b.barScale === "number") root.barScale = b.barScale
            } catch (e) {}
        }
    }
    // bar thickness + outer margin = distance from the screen edge to the bar's inner edge
    readonly property int barEdge: {
        const v = barPos === "left" || barPos === "right"
        const thick = Math.round((v ? barThickness + 12 : barThickness) * barScale)
        return thick + (barStyle === "strip" ? 0 : Math.round(barMargin * barScale))
    }

    property bool anchorSet: false
    property string anchorPosition: ""
    property real anchorAlong: -1
    property int anchorEdge: -1
    readonly property string sidePos: anchorSet && anchorPosition !== "" ? anchorPosition : barPos
    readonly property bool vert: sidePos === "left" || sidePos === "right"
    readonly property int edgePx: anchorSet && anchorEdge >= 0 ? anchorEdge : barEdge

    property var targetScreen: Quickshell.screens[0]

    function pickScreen() {
        const mon = Hyprland.focusedMonitor
        if (!mon) return
        const scr = Quickshell.screens.find(s => s.name === mon.name)
        if (scr) targetScreen = scr
    }
    function setAnchor(screenName, pos, along, edge) {
        const scr = Quickshell.screens.find(s => s.name === screenName)
        if (scr) targetScreen = scr
        else pickScreen()
        anchorPosition = pos
        anchorAlong = along
        anchorEdge = edge
        anchorSet = true
    }
    function clearAnchor() {
        anchorSet = false
        anchorAlong = -1
        anchorEdge = -1
        anchorPosition = ""
        pickScreen()
    }
    // ───────────────────────── Lifecycle ─────────────────────────
    property bool panelOpen: false
    property int calMonthOffset: 0

    // window is needed while the panel is open or toasts are showing
    readonly property bool wanted: panelOpen || (toasts && server.trackedNotifications.values.length > 0)

    // mount / keep-alive / "ready to animate" logic lives in PopupLifecycle.qml
    PopupLifecycle {
        id: life
        showing: root.wanted
        keepAliveMs: 20000      // lower this to free the window sooner after closing
    }
    readonly property bool mounted: life.mounted

    function openPanel() {
        if (!anchorSet) pickScreen()
        calMonthOffset = 0
        refreshStates()
        panelOpen = true
    }
    function closePanel() { panelOpen = false }
    function togglePanel() { panelOpen ? closePanel() : openPanel() }
    // Settings live on the SidePanel page of the settings app.
    function openSettings() { Quickshell.execDetached(["qs", "ipc", "call", "settings", "sidepanel"]) }

    // ───────────────────────── Clock / calendar ─────────────────────────
    SystemClock {
        id: clk
        enabled: root.mounted
        precision: root.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
    function pad2(n) { return String(n).padStart(2, "0"); }
    function clockText(d) {
        const h = clock24 ? d.getHours() : (d.getHours() % 12 || 12)
        let t = pad2(h) + ":" + pad2(d.getMinutes())
        if (clockSeconds) t += ":" + pad2(d.getSeconds())
        return clock24 ? t : t + " " + (d.getHours() >= 12 ? "pm" : "am")
    }
    // ───────────────────────── Keyboard-focus helpers ─────────────────────────
    function focusStep(item, forward) {
        const n = item.nextItemInFocusChain(forward)
        if (n && n.activeFocusOnTab)
            n.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
    }
    // scrolls the enclosing Flickable (if any) so `item` is fully visible
    function ensureVisible(item, margin) {
        let f = item.parent
        while (f && !(f.contentY !== undefined && f.contentHeight !== undefined))
            f = f.parent
        if (!f) return
        const p = item.mapToItem(f.contentItem, 0, 0)
        const top = p.y - margin
        const bottom = p.y + item.height + margin / 2
        const maxY = Math.max(0, f.contentHeight - f.height)
        if (top < f.contentY) f.contentY = Math.max(0, top)
        else if (bottom > f.contentY + f.height) f.contentY = Math.min(maxY, bottom - f.height)
    }
    // ───────────────────────── Persisted state ─────────────────────────
    property bool stateReady: false
    property bool dirsReady: false

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.home + "/.config/quickshell/state", root.home + "/.cache/43pr"]
        running: true
        onExited: root.dirsReady = true
    }

    function saveState() { stateTimer.restart() }
    Timer {
        id: stateTimer
        interval: 200
        onTriggered: {
            if (!root.stateReady || !root.dirsReady) { stateTimer.restart(); return }
            const s = {
                hidden: root.hiddenNames,
                dnd: root.dnd,
                night: root.nightOn,
                accentSource: root.accentSource,
                panelSide: root.panelSide,
                notifBgPath: root.notifBgPath,
                sectionOrder: root.sectionOrder,
                toastSet: root.toastSet,
                toastFx: root.toastFx,
                toastY: root.toastY
            }
            root.numKeys.forEach(k => s[k] = root[k])
            root.boolKeys.forEach(k => s[k] = root[k])
            const coll = []
            for (const k in root.collapsedApps) if (root.collapsedApps[k]) coll.push(k)
            s.collapsed = coll
            stateFile.setText(JSON.stringify(s))
        }
    }

    FileView {
        id: stateFile
        path: root.home + "/.config/quickshell/state/sidepanel-state.json"
        printErrors: false
        blockWrites: true
        watchChanges: true
        onFileChanged: reload()
        onSaveFailed: error => console.warn("sidepanel: could not save state: " + error)
        onLoaded: {
            try {
                const s = JSON.parse(stateFile.text())
                const valid = root.allActions.map(a => a.name)
                if (Array.isArray(s.hidden))
                    root.hiddenNames = s.hidden.filter(n => valid.indexOf(n) >= 0)
                root.numKeys.forEach(k => {
                    if (typeof s[k] === "number") root[k] = root.clamp(s[k], root.numSpec[k].min, root.numSpec[k].max)
                })
                root.boolKeys.forEach(k => { if (typeof s[k] === "boolean") root[k] = s[k] })
                if (typeof s.accentSource === "string" && root.accentChoices.some(c => c.id === s.accentSource))
                    root.accentSource = s.accentSource
                if (s.panelSide === "left" || s.panelSide === "right")
                    root.panelSide = s.panelSide
                if (typeof s.notifBgPath === "string") root.notifBgPath = s.notifBgPath
                if (typeof s.toastSet === "boolean") root.toastSet = s.toastSet
                if (typeof s.toastFx === "number") root.toastFx = Math.max(0, Math.min(1, s.toastFx))
                if (typeof s.toastY === "number") root.toastY = s.toastY
                if (Array.isArray(s.sectionOrder)) {
                    const allowed = root.sectionIds
                    const next = s.sectionOrder.filter(id => allowed.indexOf(id) >= 0)
                    // append any missing ids so older state files stay valid
                    for (let i = 0; i < allowed.length; i++)
                        if (next.indexOf(allowed[i]) < 0) next.push(allowed[i])
                    root.sectionOrder = next
                }
                if (typeof s.dnd === "boolean") root.dnd = s.dnd
                if (Array.isArray(s.collapsed)) {
                    const c = {}
                    for (let i = 0; i < s.collapsed.length; i++) c[String(s.collapsed[i])] = true
                    root.collapsedApps = c
                    root.scheduleRebuild()
                }
                // restore night light after reboot / logout / shell restart (first load only)
                if (typeof s.night === "boolean") {
                    root.nightOn = s.night
                    if (!root.stateReady) {
                        root.nightWasOn = false
                        root.nightRetries = 0
                        sessionProbe.running = true
                    }
                }
            } catch (e) { console.warn("sidepanel: could not read saved state:", e) }
            root.stateReady = true
        }
        onLoadFailed: root.stateReady = true
    }

    function setNumber(key, v) {
        const s = numSpec[key]
        root[key] = clamp(v, s.min, s.max)
        if (key === "nightTemp") nightApplyTimer.restart()
        else saveState()
    }
    function toggleSetting(key) { root[key] = !root[key]; saveState() }
    function toggleAction(name) {
        const h = hiddenNames.slice()
        const i = h.indexOf(name)
        if (i >= 0) h.splice(i, 1)
        else h.push(name)
        hiddenNames = h
        saveState()
    }
    function cycleAccent(dir) {
        const n = accentChoices.length
        let i = accentChoices.findIndex(c => c.id === accentSource)
        if (i < 0) i = 0
        accentSource = accentChoices[((i + dir) % n + n) % n].id
        saveState()
    }
    function resetAll() {
        numKeys.forEach(k => root[k] = numSpec[k].def)
        boolKeys.forEach(k => root[k] = boolDefaults[k])
        accentSource = "accent"
        panelSide = "left"
        notifBgPath = defaultNotifBg
        sectionOrder = defaultSectionOrder.slice()
        toastSet = false
        hiddenNames = []
        saveState()
        nightApplyTimer.restart()
    }

    // ═════════════════════════ QUICK ACTIONS ═════════════════════════
    property bool wifiOn: false
    property bool nightOn: false           // desired / displayed night light state
    property bool nightWasOn: false        // what was last actually applied
    property int nightRetries: 0
    property real brightness: 0.6          // 0..1 (brightnessctl)
    property bool dnd: false

    readonly property bool btOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property bool btConnecting: {
        const a = Bluetooth.defaultAdapter
        if (!a || !a.enabled || !a.devices) return false
        const devs = a.devices.values !== undefined ? a.devices.values : a.devices
        for (let i = 0; i < devs.length; i++)
            if (devs[i].state === BluetoothDeviceState.Connecting) return true
        return false
    }
    readonly property bool btConnected: {
        const a = Bluetooth.defaultAdapter
        if (!a || !a.enabled || !a.devices) return false
        const devs = a.devices.values !== undefined ? a.devices.values : a.devices
        for (let i = 0; i < devs.length; i++)
            if (devs[i].state === BluetoothDeviceState.Connected) return true
        return false
    }

    function isOn(name) {
        switch (name) {
        case "wifi":  return wifiOn
        case "bt":    return btOn
        case "night": return nightOn
        case "dnd":   return dnd
        }
        return false
    }
    function iconFor(name) {
        switch (name) {
        case "wifi":  return wifiOn ? "\udb81\udda9" : "\udb81\uddaa"
        case "bt":    return !btOn ? "\udb80\udcb2" : (btConnected ? "\udb80\udcb1" : "\udb80\udcaf")
        case "night": return "\uf186"
        case "dnd":   return dnd ? "\uec08" : "\ueaa2"
        case "bright": return "\uf185"
        }
        return ""
    }
    function subText(name) {
        switch (name) {
        case "wifi":  return wifiOn ? "ON" : "OFF"
        case "bt":    return !btOn ? "OFF" : (btConnecting ? "Connecting…" : (btConnected ? "Connected" : "ON"))
        case "dnd":   return dnd ? "ON" : "OFF"
        case "night":  return nightOn ? nightTemp + " K" : "OFF"
        case "bright": return Math.round(brightness * 100) + "%"
        }
        return ""
    }

    Process {
        id: wifiCheck
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiOn = text.trim() === "enabled" }
    }
    Process {
        id: brightCheck
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",")
                if (parts.length >= 4) {
                    const pct = parseInt(parts[3])
                    if (!isNaN(pct)) root.brightness = pct / 100
                }
            }
        }
    }
    // Ignored while a night-light change is pending or settling, so a check that races with
    // the apply script can't flip the state back. If night light should be ON but nothing is
    // running, it is started again (a few attempts) instead of silently switching off.
    Process {
        id: nightCheck
        command: ["pgrep", "-x", "gammastep"]
        onExited: function (code) {
            if (nightApplyTimer.running || nightSettleTimer.running) return
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
    function refreshStates() {
        wifiCheck.running = true
        brightCheck.running = true
        if (!nightApplyTimer.running && !nightSettleTimer.running) nightCheck.running = true
    }
    Timer { id: recheckTimer; interval: 700; onTriggered: { wifiCheck.running = true; brightCheck.running = true } }

    // brightness (throttled so dragging doesn't spawn a process per pixel; floor 1%)
    Timer {
        id: brightApplyTimer
        interval: 60
        onTriggered: Quickshell.execDetached({ command: ["brightnessctl", "set", Math.round(root.brightness * 100) + "%"] })
    }
    function setBrightness(pct) {
        brightness = Math.max(0.01, Math.min(1, pct / 100))
        brightApplyTimer.restart()
    }
    function adjustBrightness(deltaPct) { setBrightness(brightness * 100 + deltaPct) }

    // Night light restore at login: a marker in XDG_RUNTIME_DIR tells a fresh login from a
    // plain shell reload. On a fresh login the apply is forced twice, a few seconds apart.
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
            if (!root.nightOn || count > 2) { stop(); return }
            root.nightWasOn = false
            root.nightRetries = 0
            root.applyNight()
            if (count >= 2) stop()
        }
    }

    // gammastep: changes are debounced, the apply script runs under flock, kills the old
    // gammastep and WAITS until it is gone before starting a new one.
    readonly property string nightScript:
        "exec 9>/tmp/qa-gammastep.lock; flock 9; "
        + "pkill -x gammastep; "
        + "i=0; while pgrep -x gammastep >/dev/null && [ $i -lt 40 ]; do sleep 0.05; i=$((i+1)); done; "
        + "pkill -9 -x gammastep 2>/dev/null; "
        + "sleep \"${2:-0.15}\"; "
        + "[ \"$1\" = off ] && exit 0; "
        + "setsid -f gammastep -O \"$1\" 9>&- >/dev/null 2>&1"

    function applyNight() {
        if (!nightOn && !nightWasOn) return
        const tempOnly = nightOn && nightWasOn
        Quickshell.execDetached({
            command: ["sh", "-c", root.nightScript, "sh",
                      nightOn ? String(nightTemp) : "off",
                      tempOnly ? "0.03" : "0.15"]
        })
        nightWasOn = nightOn
        nightSettleTimer.restart()
    }
    Timer {
        id: nightApplyTimer
        interval: 150
        onTriggered: { root.applyNight(); root.saveState() }
    }
    // toggling applies quickly; temperature scrolling waits until the scrolling stops
    function queueNight(tempChange) {
        nightApplyTimer.interval = (tempChange && nightOn && nightWasOn) ? 450 : 150
        nightApplyTimer.restart()
    }
    Timer {
        id: nightSettleTimer
        interval: 1500
        onTriggered: if (root.nightOn) nightCheck.running = true
    }
    function setNightTemp(k) {
        const s = numSpec.nightTemp
        nightTemp = clamp(k, s.min, s.max)
        nightRetries = 0
        queueNight(true)
    }
    function adjustNight(deltaK) { setNightTemp(nightTemp + deltaK) }
    function scrollTile(name, dir) {
        if (name === "night") adjustNight(dir * nightStep)
        else if (name === "bright") adjustBrightness(dir * brightnessStep)
    }
    function toggleDnd() { dnd = !dnd; saveState() }
    function toggleSound() { soundEnabled = !soundEnabled; saveState() }

    function toggleItem(name) {
        switch (name) {
        case "wifi":
            Quickshell.execDetached({ command: ["nmcli", "radio", "wifi", wifiOn ? "off" : "on"] })
            wifiOn = !wifiOn
            break
        case "bt":
            BluetoothState.togglePower()
            break
        case "night":
            bootApplyTimer.stop()
            nightOn = !nightOn
            nightRetries = 0
            nightSettleTimer.restart()
            queueNight(false)
            break
        case "bright": {
            const p = Math.round(brightness * 100)
            setBrightness(p < 25 ? 25 : p < 50 ? 50 : p < 75 ? 75 : p < 100 ? 100 : 25)
            break
        }
        case "dnd":
            toggleDnd()
            break
        }
        recheckTimer.restart()
    }
    function runAction(name) { toggleItem(name) }

    // ═════════════════════════ NOTIFICATIONS ═════════════════════════
    property int maxHistory: 100
    property bool historyReady: false

    readonly property int normalTimeout: 3000
    readonly property int criticalTimeout: 6000

    property var collapsedApps: ({})
    property var expandedSet: ({})
    property int groupCount: 0
    property bool allCollapsed: false
    property var groupOffsets: ({})

    // DND lets critical notifications through, except from apps that mark everything
    // critical (lowercase substrings of appName)
    property var dndMuteCritical: ["discord", "vesktop", "webcord", "armcord"]

    readonly property string icDown: "\uDB80\uDD40"
    readonly property string icRight: "\uDB80\uDD42"
    readonly property string icUp: "\uDB80\uDD43"
    readonly property string icLeft: "\uDB80\uDD41"
    readonly property string icCopy: "\uDB80\uDD8F"
    readonly property string icCheck: "\uDB80\uDD2C"

    signal rowsAboutToRebuild()
    signal rowsRebuilt()

    function imgSrc(p) { return !p ? "" : (p.startsWith("/") ? "file://" + p : p); }
    function canExpand(body) { return body.length > 70 || body.indexOf("\n") >= 0; }
    function groupKey(app) { return app && app !== "" ? app : "Other"; }

    function guessKind(app, summary) {
        const s = ((app || "") + " " + (summary || "")).toLowerCase()
        if (/todo|remind/.test(s)) return "reminder"
        if (/usb|disk|drive|device|mount|eject|removed|unplug|storage|udisks|udiskie/.test(s)) return "usb"
        if (/batter/.test(s)) return "battery"
        return ""
    }
    function resolveIcon(image, icon, app, summary) {
        const kind = guessKind(app, summary)
        if (kind === "reminder") return ""
        if (image && image !== "" && !String(image).startsWith("image://icon"))
            return imgSrc(image)
        const cands = []
        if (icon && icon !== "") cands.push(icon)
        if (app && app !== "") { cands.push(app); cands.push(app.toLowerCase()) }
        if (kind === "usb")
            cands.push("drive-removable-media-usb", "drive-removable-media", "media-removable", "usb-creator-gtk", "drive-harddisk-usb")
        else if (kind === "battery")
            cands.push("battery-caution", "battery")
        for (let i = 0; i < cands.length; i++) {
            const c = cands[i]
            if (c.startsWith("/")) return "file://" + c
            if (c.startsWith("image://")) return c
            const p = String(Quickshell.iconPath(c, true) || "")
            if (p !== "" && p.indexOf("missing") === -1) return p
        }
        return ""
    }
    function glyphFor(app, summary) {
        return guessKind(app, summary) === "reminder" ? "󰂞" : "\uDB80\uDC9C";
    }
    function fmtTime(ms) {
        const d = new Date(ms)
        return d.toDateString() === new Date().toDateString()
            ? Qt.formatDateTime(d, "HH:mm")
            : Qt.formatDateTime(d, "dd MMM HH:mm")
    }
    function copyText(s, b) { Quickshell.execDetached(["wl-copy", b !== "" ? s + "\n" + b : s]); }
    function copyRaw(s) { Quickshell.execDetached(["wl-copy", s]); }

    // ---- history ----
    ListModel { id: history }
    ListModel { id: rows }

    function removeHistory(i) {
        if (i < 0 || i >= history.count) return
        history.remove(i)
        saveTimer.restart()
        scheduleRebuild()
    }
    function clearHistory() {
        history.clear()
        saveTimer.restart()
        scheduleRebuild()
    }
    function removeGroup(name) {
        for (let i = history.count - 1; i >= 0; i--)
            if (groupKey(history.get(i).appName) === name) history.remove(i)
        saveTimer.restart()
        scheduleRebuild()
    }
    function toggleCollapse(name) {
        const c = {}
        for (const k in collapsedApps) c[k] = collapsedApps[k]
        if (c[name]) delete c[name]; else c[name] = true
        collapsedApps = c
        saveState()
        scheduleRebuild()
    }
    function toggleCollapseAll() {
        const c = {}
        if (!allCollapsed)
            for (let i = 0; i < history.count; i++) c[groupKey(history.get(i).appName)] = true
        collapsedApps = c
        saveState()
        scheduleRebuild()
    }
    // scrolls a group's visible window by `delta` entries; true if it moved
    function scrollGroup(name, delta) {
        let total = 0
        for (let i = 0; i < history.count; i++)
            if (groupKey(history.get(i).appName) === name) total++
        const maxOff = Math.max(0, total - groupLimit)
        const cur = Math.min(groupOffsets[name] || 0, maxOff)
        const next = Math.max(0, Math.min(maxOff, cur + delta))
        if (next === cur) return false
        const o = {}
        for (const k in groupOffsets) o[k] = groupOffsets[k]
        o[name] = next
        groupOffsets = o
        scheduleRebuild()
        return true
    }
    function toggleExpand(rowIndex, key) {
        const s = {}
        for (const k in expandedSet) s[k] = expandedSet[k]
        if (s[key]) delete s[key]; else s[key] = true
        expandedSet = s
        rows.setProperty(rowIndex, "expanded", s[key] === true)
    }

    Timer { id: rebuildTimer; interval: 20; onTriggered: root.rebuildRows() }
    function scheduleRebuild() { rebuildTimer.restart(); }
    onGroupLimitChanged: scheduleRebuild()

    function rebuildRows() {
        rowsAboutToRebuild()
        rows.clear()

        const order = []
        const groups = {}
        for (let i = 0; i < history.count; i++) {
            const k = groupKey(history.get(i).appName)
            if (!groups[k]) { groups[k] = []; order.push(k) }
            groups[k].push(i)
        }

        let collapsedN = 0
        for (let g = 0; g < order.length; g++) {
            const name = order[g]
            const idxs = groups[name]
            const first = history.get(idxs[0])
            const coll = collapsedApps[name] === true
            if (coll) collapsedN++

            rows.append({
                rowType: "header", groupName: name,
                summary: first.summary, body: "", appName: first.appName,
                appIcon: first.appIcon, image: "", time: first.time,
                hIndex: -1, grpCount: idxs.length, collapsed: coll,
                expanded: false, rowKey: ""
            })
            if (coll) continue

            const total = idxs.length
            const off = Math.max(0, Math.min(groupOffsets[name] || 0, Math.max(0, total - groupLimit)))
            const end = Math.min(total, off + groupLimit)
            for (let j = off; j < end; j++) {
                const e = history.get(idxs[j])
                const key = e.time + "|" + e.summary
                rows.append({
                    rowType: "item", groupName: name,
                    summary: e.summary, body: e.body, appName: e.appName,
                    appIcon: e.appIcon, image: e.image, time: e.time,
                    hIndex: idxs[j], grpCount: total, collapsed: false,
                    expanded: expandedSet[key] === true, rowKey: key
                })
            }
            if (total > groupLimit) {
                rows.append({
                    rowType: "pager", groupName: name,
                    summary: (off + 1) + "–" + end + " of " + total, body: "", appName: "",
                    appIcon: "", image: "", time: 0,
                    hIndex: off, grpCount: total, collapsed: false,
                    expanded: false, rowKey: ""
                })
            }
        }
        groupCount = order.length
        allCollapsed = order.length > 0 && collapsedN === order.length
        rowsRebuilt()
    }

    // history file (the bar reads it for the notification count)
    FileView {
        id: store
        path: root.home + "/.cache/43pr/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                const arr = JSON.parse(text())
                for (let i = 0; i < arr.length; i++) {
                    const e = arr[i]
                    history.append({
                        summary: String(e.summary || ""),
                        body: String(e.body || ""),
                        appName: String(e.appName || ""),
                        appIcon: String(e.appIcon || ""),
                        image: String(e.image || ""),
                        time: Number(e.time) || 0
                    })
                }
            } catch (e) { console.warn("sidepanel: bad history file: " + e) }
            root.historyReady = true
            root.scheduleRebuild()
        }
        onLoadFailed: root.historyReady = true
    }
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            if (!root.historyReady) return
            const out = []
            for (let i = 0; i < history.count; i++) {
                const e = history.get(i)
                out.push({ summary: e.summary, body: e.body, appName: e.appName, appIcon: e.appIcon, image: e.image, time: e.time })
            }
            store.setText(JSON.stringify(out))
        }
    }

    // ---- sound / DND ----
    function playSound(name) {
        if (!soundEnabled) return
        Quickshell.execDetached([
            "sh", "-c",
            'f="/usr/share/sounds/freedesktop/stereo/$1.oga"; '
            + 'if [ -f "$f" ]; then pw-play "$f" 2>/dev/null || paplay "$f" 2>/dev/null; '
            + 'else canberra-gtk-play -i "$1" 2>/dev/null; fi',
            "sh", name
        ])
    }
    function dndBlocks(n) {
        if (!dnd) return false
        const app = (n.appName || "").toLowerCase()
        if (app === "battery") return false
        if (n.urgency !== NotificationUrgency.Critical) return true
        for (let i = 0; i < dndMuteCritical.length; i++)
            if (app.indexOf(dndMuteCritical[i]) >= 0) return true
        return false
    }
    function soundFor(n) {
        if (n.appName === "Todo") return "alarm-clock-elapsed"
        if (n.urgency === NotificationUrgency.Critical) return "dialog-warning"
        return "message-new-instant"
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            if (n.lastGeneration) return
            const blocked = root.dndBlocks(n)
            if (!blocked) root.playSound(root.soundFor(n))
            if (!root.mounted) root.pickScreen()
            n.tracked = !blocked && root.toasts
            if (n.transient) return

            const img = (n.image && !String(n.image).startsWith("image://")) ? String(n.image) : ""
            // show the newest entries of that app again
            const gk = root.groupKey(n.appName)
            if (root.groupOffsets[gk]) {
                const o = {}
                for (const k in root.groupOffsets) o[k] = root.groupOffsets[k]
                delete o[gk]
                root.groupOffsets = o
            }
            history.insert(0, {
                summary: n.summary || "",
                body: n.body || "",
                appName: n.appName || "",
                appIcon: n.appIcon || "",
                image: img,
                time: Date.now()
            })
            if (history.count > root.maxHistory) history.remove(root.maxHistory, history.count - root.maxHistory)
            saveTimer.restart()
            root.scheduleRebuild()
        }
    }

    // ---- battery alerts (event driven) ----
    property real lastBat: -1
    property bool bat20: false
    property bool bat15: false

    function notifyBat(urgency, icon, title, pct) {
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", urgency, "-i", icon, title, "Battery is at " + Math.round(pct) + "%"])
    }
    function checkBattery() {
        if (!UPower.displayDevice.ready) return
        const p = UPower.displayDevice.percentage
        if (!UPower.onBattery) { bat20 = false; bat15 = false; lastBat = p; return }
        if (lastBat < 0) { lastBat = p; return }
        if (p > 20) bat20 = false
        if (p > 15) bat15 = false
        if (!bat20 && lastBat > 20 && p <= 20) { bat20 = true; notifyBat("normal", "battery-caution", "Battery Low", p) }
        if (!bat15 && lastBat > 15 && p <= 15) { bat15 = true; notifyBat("critical", "battery-empty", "Battery Critical", p) }
        lastBat = p
    }
    Connections {
        target: UPower.displayDevice
        function onReadyChanged() { root.checkBattery() }
        function onPercentageChanged() { root.checkBattery() }
        function onStateChanged() { root.checkBattery() }
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() { root.checkBattery() }
    }

    Component.onCompleted: {
        BluetoothState.init()
        checkBattery()
        scheduleRebuild()
    }

    // ═════════════════════════ IPC ═════════════════════════
    IpcHandler {
        target: "sidepanel"
        function toggle(): void { root.clearAnchor(); root.togglePanel() }
        function open(): void { root.clearAnchor(); root.openPanel() }
        function close(): void { root.closePanel() }
        function settings(): void { root.openSettings() }
        // screen name · bar position (top|right|bottom|left) · px along the bar · px from screen edge to bar inner edge
        function toggleAt(screen: string, position: string, along: int, edge: int): void {
            if (root.panelOpen) { root.closePanel(); return }
            root.setAnchor(screen, position, along, edge)
            root.openPanel()
        }
        function openAt(screen: string, position: string, along: int, edge: int): void {
            root.setAnchor(screen, position, along, edge)
            root.openPanel()
        }
    }
    // kept so existing keybinds / bar calls keep working
    IpcHandler {
        target: "notifications"
        function toggle(): void { root.clearAnchor(); root.togglePanel() }
        function open(): void { root.clearAnchor(); root.openPanel() }
        function close(): void { root.closePanel() }
        function clear(): void { root.clearHistory() }
        function dnd(): void { root.toggleDnd() }
        function isDnd(): bool { return root.dnd }
        function sound(): void { root.toggleSound() }
        function collapseAll(): void { root.toggleCollapseAll() }
    }
    IpcHandler {
        target: "qa"
        function toggle(): void { root.clearAnchor(); root.togglePanel() }
        function show(): void { root.clearAnchor(); root.openPanel() }
        function hide(): void { root.closePanel() }
        function settings(): void { root.openSettings() }
        function nightToggle(): void { root.toggleItem("night") }
        function nightAdjust(delta: int): void { root.adjustNight(delta) }
    }

    // ═════════════════════════ WINDOW ═════════════════════════
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win
            screen: root.targetScreen

            // Feed the window's readiness into the lifecycle (restored when the window is destroyed)
            Binding { target: life; property: "sized"; value: win.width > 0 && win.height > 0 }
            Binding { target: life; property: "contentReady"; value: true }
            Binding { target: life; property: "frameWindow"; value: panelClip.Window.window }

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sidepanel"
            // keyboard focus only while the mouse is over the panel
            WlrLayershell.keyboardFocus: (root.panelOpen && panelClip.hovered)
                                         ? WlrKeyboardFocus.Exclusive
                                         : WlrKeyboardFocus.None

            // Only the panel (or toast stack) receives input; clicks outside pass through.
            // The region uses inputRect (an untransformed twin of the panel), NOT the panel
            // itself: while it animates the panel is scaled/tilted, which would shrink the
            // region and leave dead areas. changed() is re-emitted because the region doesn't
            // always follow geometry changes on its own.
            mask: Region {
                id: inputMask
                item: root.panelOpen ? inputRect : stack
            }

            function emitMaskChanged() { inputMask.changed() }
            // Qt.callLater with the same function reference is coalesced into one call
            function refreshMask() { Qt.callLater(win.emitMaskChanged) }

            Connections {
                target: root
                function onPanelOpenChanged() { win.refreshMask() }
            }
            Timer { running: root.panelOpen; interval: 400;  onTriggered: win.refreshMask() }
            Timer { running: root.panelOpen; interval: 1500; onTriggered: win.refreshMask() }

            Component.onCompleted: keys.forceActiveFocus()

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true

                Keys.onPressed: function (event) {
                    if (!root.panelOpen) return
                    switch (event.key) {
                    case Qt.Key_Escape:   root.closePanel(); event.accepted = true; return
                    case Qt.Key_Down:
                    case Qt.Key_Right:    root.focusStep(keys, true); event.accepted = true; return
                    case Qt.Key_Up:
                    case Qt.Key_Left:     root.focusStep(keys, false); event.accepted = true; return
                    case Qt.Key_PageUp:   root.calMonthOffset -= 1; event.accepted = true; return
                    case Qt.Key_PageDown: root.calMonthOffset += 1; event.accepted = true; return
                    case Qt.Key_Home:     root.calMonthOffset = 0; event.accepted = true; return
                    case Qt.Key_Plus:
                    case Qt.Key_Equal:    root.adjustBrightness(root.brightnessStep); event.accepted = true; return
                    case Qt.Key_Minus:    root.adjustBrightness(-root.brightnessStep); event.accepted = true; return
                    }
                }

                Column {
                    id: stack
                    visible: !root.panelOpen
                    width: Math.round(root.panelWidth * root.ui)
                    spacing: root.px(8)

                    // default: top centre (below the bar if it is on top)
                    x: Math.max(0, Math.min(win.width - width, root.toastFx * win.width - width / 2))
                    y: root.toastSet
                       ? Math.max(0, Math.min(Math.max(0, win.height - height), root.toastY))
                       : 12 + (root.barPos === "top" ? root.barEdge : 0)

                    // drag anywhere on a toast to move the whole stack
                    DragHandler {
                        id: stackDrag
                        target: null
                        cursorShape: active ? Qt.ClosedHandCursor : Qt.ArrowCursor
                        property real startX: 0
                        property real startY: 0
                        onActiveChanged: {
                            if (active) {
                                startX = stack.x
                                startY = stack.y
                            } else if (root.toastSet) {
                                root.saveState()
                            }
                        }
                        onTranslationChanged: {
                            if (!active) return
                            const nx = Math.max(0, Math.min(win.width - stack.width, startX + translation.x))
                            const ny = Math.max(0, Math.min(Math.max(0, win.height - stack.height), startY + translation.y))
                            root.toastFx = (nx + stack.width / 2) / win.width
                            root.toastY = ny
                            root.toastSet = true
                        }
                    }

                    Repeater {
                        model: server.trackedNotifications

                        delegate: Item {
                            id: wrapper
                            required property var modelData
                            property bool shown: false
                            property bool leaving: false
                            property bool wasExpired: false
                            property bool notificationClosed: false
                            property bool expanded: false
                            property bool copied: false
                            property real lifeLeft: 1      // invisible countdown = toast lifetime
                            readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                            readonly property bool persistent: modelData.expireTimeout === 0
                            readonly property int lifetime: persistent ? 0 : modelData.expireTimeout > 0
                                ? modelData.expireTimeout : (critical ? root.criticalTimeout : root.normalTimeout)
                            function restartLifetime() {
                                if (persistent) progAnim.stop()
                                else if (!leaving && !notificationClosed) progAnim.restart()
                            }
                            width: root.panelWidth * root.ui
                            height: card.height

                            function close(expired) {
                                if (leaving || notificationClosed) return
                                wasExpired = expired
                                leaving = true
                                shown = false
                                gone.start()
                            }
                            Component.onCompleted: shown = true

                            Timer {
                                id: gone
                                interval: 400
                                onTriggered: {
                                    const n = wrapper.modelData
                                    if (!n || wrapper.notificationClosed || !n.tracked) return
                                    try { if (wrapper.wasExpired) n.expire(); else n.dismiss() } catch (e) { }
                                }
                            }
                            Timer { id: copiedTimer; interval: 900; onTriggered: wrapper.copied = false }

                            NumberAnimation {
                                id: progAnim
                                target: wrapper
                                property: "lifeLeft"
                                from: 1
                                to: 0
                                duration: wrapper.lifetime
                                running: !wrapper.leaving && !wrapper.persistent && !wrapper.notificationClosed
                                paused: hh.hovered || wrapper.expanded
                                onFinished: wrapper.close(true)
                            }
                            Connections {
                                target: wrapper.modelData
                                function onClosed(reason) { wrapper.notificationClosed = true; gone.stop(); progAnim.stop() }
                                function onSummaryChanged() { wrapper.restartLifetime() }
                                function onBodyChanged() { wrapper.restartLifetime() }
                                function onExpireTimeoutChanged() { wrapper.restartLifetime() }
                            }

                            Rectangle {
                                id: card
                                width: parent.width
                                height: Math.max(root.px(64), content.implicitHeight + root.px(24))
                                radius: Math.min(root.cornerRadius, root.px(16))
                                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Math.max(0.5, root.bgOpacity / 100))
                                border.width: wrapper.critical ? 1 : 0
                                border.color: root.cAccent
                                opacity: wrapper.shown ? 1 : 0
                                y: wrapper.shown ? 0 : -(height + 20)
                                Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutQuad } }
                                HoverHandler { id: hh }

                                // left click: dismiss, right click: copy
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: stackDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            root.copyText(wrapper.modelData.summary, wrapper.modelData.body)
                                            wrapper.copied = true
                                            copiedTimer.restart()
                                        } else {
                                            wrapper.close(false)
                                        }
                                    }
                                }

                                Row {
                                    id: content
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: root.px(10) }
                                    spacing: root.px(10)

                                    Thumb {
                                        id: thumb
                                        size: 40
                                        color: "transparent"
                                        src: root.resolveIcon(wrapper.modelData.image, wrapper.modelData.appIcon,
                                                              wrapper.modelData.appName, wrapper.modelData.summary)
                                        glyph: root.glyphFor(wrapper.modelData.appName, wrapper.modelData.summary)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: root.px(3)
                                        width: parent.width - thumb.width - btnCol.width - parent.spacing * 2

                                        Lbl {
                                            sz: 12
                                            font.bold: true
                                            width: parent.width
                                            text: wrapper.modelData.summary
                                            wrapMode: wrapper.expanded ? Text.WordWrap : Text.NoWrap
                                        }
                                        Lbl {
                                            width: parent.width
                                            visible: text !== ""
                                            text: wrapper.modelData.body
                                            color: Theme.textDim
                                            textFormat: Text.PlainText
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: wrapper.expanded ? 200 : 3
                                        }
                                        Lbl { sz: 9; width: parent.width; text: wrapper.modelData.appName; color: Theme.textDim; opacity: 0.7 }

                                        Row {
                                            visible: wrapper.modelData.actions.length > 0
                                            spacing: root.px(6)
                                            Repeater {
                                                model: wrapper.modelData.actions
                                                delegate: Rectangle {
                                                    id: actBtn
                                                    required property var modelData
                                                    height: root.px(20)
                                                    width: actLabel.implicitWidth + root.px(14)
                                                    radius: root.px(7)
                                                    color: Theme.alpha(Theme.text, actArea.containsMouse ? 0.22 : 0.1)
                                                    Lbl { id: actLabel; anchors.centerIn: parent; sz: 9; text: actBtn.modelData.text }
                                                    MouseArea {
                                                        id: actArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: { actBtn.modelData.invoke(); wrapper.close(false) }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        id: btnCol
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: root.px(4)
                                        opacity: hh.hovered ? 1 : 0.45
                                        Behavior on opacity { NumberAnimation { duration: 120 } }

                                        IconBtn {
                                            base: 22
                                            icon: wrapper.copied ? root.icCheck : root.icCopy
                                            tip: "Copy"
                                            onClicked: {
                                                root.copyText(wrapper.modelData.summary, wrapper.modelData.body)
                                                wrapper.copied = true
                                                copiedTimer.restart()
                                            }
                                        }
                                        IconBtn {
                                            base: 22
                                            visible: root.canExpand(wrapper.modelData.body)
                                            icon: wrapper.expanded ? root.icUp : root.icDown
                                            tip: wrapper.expanded ? "Collapse" : "Expand"
                                            onClicked: wrapper.expanded = !wrapper.expanded
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Plain Item tracking the panel's target geometry (see `mask` above)
                Item {
                    id: inputRect
                    x: Math.round(panelClip.x)
                    y: Math.round(panelClip.y)
                    width: Math.round(panelClip.width)
                    height: Math.round(panelClip.height)
                    onXChanged: win.refreshMask()
                    onYChanged: win.refreshMask()
                    onWidthChanged: win.refreshMask()
                    onHeightChanged: win.refreshMask()
                }

                // ───────────── the panel ─────────────
                // Same open/close animation as the settings window (fade + pop + tilt)
                PerspectivePanel {
                    id: panelClip
                    tiltStrength: root.tiltStrength
                    readonly property real along: root.anchorAlong >= 0 ? root.anchorAlong
                                                : (root.vert ? win.height / 2 : win.width / 2)
                    // which screen edge the panel hugs
                    readonly property bool leftSide: root.vert ? root.sidePos === "left"
                                                               : root.panelSide === "left"
                    readonly property real sideGap: root.vert ? root.edgePx + 6 : 8
                    readonly property real maxH: (win.height - (root.vert ? 0 : root.edgePx + 4)) * root.panelHeight / 100
                    readonly property int fullW: Math.round(root.panelWidth * root.ui)
                    readonly property int fullH: root.notifsHeight > 0
                    ? Math.min(panel.implicitHeight, maxH)
                    : maxH

                    width: fullW
                    height: fullH

                    open: life.opened && root.panelOpen
                    prewarm: !life.opened
                    fadeDuration: root.animMs * 1.3
                    popDuration: root.animMs * 1.7
                    tiltDuration: root.animMs * 1.9
                    popEasing: Easing.OutCubic
                    closedScale: 0.7

                    // hugs the left or right screen edge; vertical bars keep their own side
                    x: Math.round(leftSide ? sideGap : win.width - fullW - sideGap)
                    y: Math.round(root.vert
                        ? Math.max(0, Math.min(win.height - fullH, along - fullH / 2))
                        : (root.sidePos === "top" ? root.edgePx + 4
                                                  : win.height - root.edgePx - 4 - fullH))

                    Rectangle {
                        id: panel

                        readonly property int pad: root.px(14)
                        implicitHeight: mainCol.height + 2 * pad
                        anchors.fill: parent

                        radius: root.cornerRadius
                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.bgOpacity / 100)
                        border.width: root.border ? 1 : 0
                        border.color: Theme.alpha(root.cAccent, root.borderOpacity / 100)
                        clip: true

                        // swallow clicks on the panel background
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

                        // ═════════ main view ═════════
                        Column {
                            id: mainCol
                            x: panel.pad
                            y: panel.pad
                            width: panel.width - 2 * panel.pad
                            spacing: root.px(12)

                            // Body sections — order controlled by root.sectionOrder
                            Column {
                                id: sectionsCol
                                width: parent.width
                                spacing: root.px(12)

                                function applyOrder() {
                                    const map = { calendar: calBox, quick: qaBox, notifs: notifsCol }
                                    const ord = root.sectionOrder
                                    for (let i = 0; i < ord.length; i++) {
                                        const item = map[ord[i]]
                                        if (!item) continue
                                        item.parent = null
                                        item.parent = sectionsCol
                                    }
                                }
                                Component.onCompleted: applyOrder()
                                Connections {
                                    target: root
                                    function onSectionOrderChanged() { sectionsCol.applyOrder() }
                                }

                                // ---- calendar ----
                                Column {
                                    id: calBox
                                    visible: root.showCalendar
                                    width: parent.width
                                    spacing: root.px(8)

                                    readonly property int firstDay: root.weekMonday ? 1 : 0
                                    readonly property int cellW: Math.floor(width / 7)
                                    readonly property int cellH: root.px(28)
                                    readonly property date now: clk.date
                                    readonly property date view: new Date(now.getFullYear(), now.getMonth() + root.calMonthOffset, 1)
                                    readonly property var cells: {
                                        const first = (view.getDay() - firstDay + 7) % 7
                                        const y = view.getFullYear(), m = view.getMonth()
                                        const ty = now.getFullYear(), tm = now.getMonth(), td = now.getDate()
                                        return Array.from({ length: 42 }, (_, i) => {
                                            const d = new Date(y, m, i - first + 1)
                                            return {
                                                n: d.getDate(),
                                                inMonth: d.getMonth() === m,
                                                today: d.getFullYear() === ty && d.getMonth() === tm && d.getDate() === td
                                            }
                                        })
                                    }

                                    // no divider needed when the calendar is the first section
                                    Rectangle {
                                        visible: root.sectionOrder[0] !== "calendar"
                                        width: parent.width
                                        height: 1
                                        color: Theme.alpha(Theme.text, 0.12)
                                    }

                                    // ---- clock + date (left-aligned) ----
                                    Column {
                                        id: clockCol
                                        width: parent.width
                                        spacing: root.px(4)

                                        Lbl {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignLeft
                                            sz: 30
                                            font.bold: true
                                            text: root.clockText(clk.date)
                                        }
                                        Lbl {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignLeft
                                            sz: 12
                                            color: Theme.textDim
                                            text: Qt.formatDate(clk.date, "dddd, d MMMM yyyy")
                                        }
                                    }
                                    Item {
                                        width: parent.width
                                        height: root.px(26)

                                        IconBtn {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            base: 24
                                            rest: 0
                                            icon: root.icLeft
                                            tip: "Previous month (PgUp)"
                                            onClicked: root.calMonthOffset -= 1
                                        }
                                        Item {
                                            anchors.centerIn: parent
                                            width: monthTitle.implicitWidth + 16
                                            height: parent.height

                                            Lbl {
                                                id: monthTitle
                                                anchors.centerIn: parent
                                                sz: 13
                                                font.bold: true
                                                color: titleMa.containsMouse ? root.cAccent : Theme.text
                                                text: Qt.formatDate(calBox.view, "MMMM yyyy")
                                            }
                                            MouseArea {
                                                id: titleMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.calMonthOffset = 0
                                            }
                                        }
                                        IconBtn {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            base: 24
                                            rest: 0
                                            icon: root.icRight
                                            tip: "Next month (PgDn)"
                                            onClicked: root.calMonthOffset += 1
                                        }
                                    }
                                    Row {
                                        Repeater {
                                            model: 7
                                            delegate: Lbl {
                                                required property int index
                                                width: calBox.cellW
                                                horizontalAlignment: Text.AlignHCenter
                                                sz: 11
                                                color: Theme.textDim
                                                text: Qt.locale().dayName((index + calBox.firstDay) % 7, Locale.ShortFormat)
                                            }
                                        }
                                    }
                                    Grid {
                                        columns: 7
                                        Repeater {
                                            model: calBox.cells
                                            delegate: Item {
                                                id: dayCell
                                                required property var modelData
                                                width: calBox.cellW
                                                height: calBox.cellH

                                                Rectangle {
                                                    visible: dayCell.modelData.today
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    radius: Theme.radius
                                                    color: Theme.alpha(root.cAccent, 0.2)
                                                    border.width: 1
                                                    border.color: root.cAccent
                                                }
                                                Lbl {
                                                    anchors.centerIn: parent
                                                    sz: 12
                                                    font.bold: dayCell.modelData.today
                                                    color: dayCell.modelData.inMonth ? Theme.text : Theme.textFaint
                                                    text: dayCell.modelData.n
                                                }
                                            }
                                        }
                                    }
                                    // wheel over the calendar = change month
                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onWheel: e => root.calMonthOffset += (e.angleDelta.y > 0 ? -1 : 1)
                                    }
                                }

                                // ---- quick actions ----
                                Column {
                                    id: qaBox
                                    visible: root.showQuick && root.visibleTiles.length > 0
                                    width: parent.width
                                    spacing: root.px(8)

                                    Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.text, 0.12) }

                                    Grid {
                                        id: tileGrid
                                        visible: root.visibleTiles.length > 0
                                        width: parent.width
                                        columns: 5
                                        rowSpacing: root.px(8)
                                        columnSpacing: root.px(8)

                                        Repeater {
                                            model: root.visibleTiles
                                            delegate: SpTile {
                                                id: tile
                                                required property var modelData
                                                width: Math.floor((tileGrid.width - 4 * tileGrid.columnSpacing) / 5)
                                                icon: root.iconFor(modelData.name)
                                                label: modelData.short
                                                sub: root.subText(modelData.name)
                                                on: root.isOn(modelData.name)
                                                blinking: modelData.name === "bt" && root.btConnecting
                                                onClicked: root.runAction(modelData.name)
                                                onScrolled: dir => root.scrollTile(modelData.name, dir)
                                            }
                                        }
                                    }
                                }

                                // ---- notifications ----
                                Column {
                                    id: notifsCol
                                    width: parent.width
                                    spacing: root.px(6)
                                    visible: root.showNotifs

                                    // fixed list area, independent of how many notifications exist
                                    readonly property real listH: {
                                        const gaps = (calBox.visible ? 1 : 0) + (qaBox.visible ? 1 : 0)
                                        const others = 2 * panel.pad
                                            + (calBox.visible ? calBox.height : 0)
                                            + (qaBox.visible ? qaBox.height : 0)
                                            + gaps * sectionsCol.spacing
                                            + nHdr.height + spacing
                                        const avail = Math.max(root.px(90), panelClip.maxH - others)
                                        return root.notifsHeight > 0 ? Math.min(root.px(root.notifsHeight), avail) : avail
                                    }

                                    // header
                                    Item {
                                        id: nHdr
                                        width: parent.width
                                        height: root.px(24)
                                        Lbl {
                                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                            sz: 13
                                            font.bold: true
                                            text: "Notifications" + (history.count > 0 ? "  " + history.count : "")
                                        }
                                        Row {
                                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                            spacing: root.px(4)
                                            IconBtn {
                                                icon: root.soundEnabled ? "󰕾" : "󰖁"
                                                tip: "Sound: " + (root.soundEnabled ? "ON" : "OFF")
                                                rest: root.soundEnabled ? 0.08 : 0.3
                                                onClicked: root.toggleSound()
                                            }
                                            IconBtn {
                                                visible: root.groupCount > 1
                                                icon: root.allCollapsed ? root.icDown : root.icUp
                                                tip: root.allCollapsed ? "Expand all groups" : "Collapse all groups"
                                                onClicked: root.toggleCollapseAll()
                                            }
                                            IconBtn {
                                                visible: history.count > 0
                                                icon: "󰆴"
                                                tip: "Clear all"
                                                tint: root.cAccent
                                                rest: 0.1
                                                hot: 0.25
                                                onClicked: root.clearHistory()
                                            }
                                        }
                                    }

                                    // list area: optional centered background picture,
                                    // the empty-state label and the grouped list share one box
                                    Item {
                                        id: listArea
                                        width: parent.width
                                        height: notifsCol.listH

                                        Image {
                                            id: notifBg
                                            readonly property bool active: root.notifBgEnabled && root.notifBgPath !== ""
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit      // centered, never cropped or stretched
                                            asynchronous: true
                                            cache: false
                                            sourceSize.width: Math.round(width * 2) // cap decode size to the panel
                                            source: active ? root.imgSrc(root.notifBgPath) : ""
                                            opacity: root.notifBgOpacity / 100
                                            visible: active && status === Image.Ready
                                        }

                                        Lbl {
                                            anchors.fill: parent
                                            visible: history.count === 0
                                            sz: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: "No notifications"
                                            color: Theme.textDim
                                        }

                                        // grouped list
                                        ListView {
                                            id: list
                                            visible: history.count > 0
                                            anchors.fill: parent
                                            clip: true
                                            spacing: root.px(6)
                                            model: rows
                                            boundsBehavior: Flickable.StopAtBounds

                                            // keep the scroll position when the grouped model is rebuilt
                                            property real keepY: 0
                                            Connections {
                                                target: root
                                                function onRowsAboutToRebuild() { list.keepY = list.contentY }
                                                function onRowsRebuilt() {
                                                    Qt.callLater(function () {
                                                        list.contentY = Math.max(0, Math.min(list.keepY, list.contentHeight - list.height))
                                                    })
                                                }
                                            }

                                            delegate: Item {
                                                id: rowItem
                                                required property int index
                                                required property string rowType
                                                required property string groupName
                                                required property string summary
                                                required property string body
                                                required property string appName
                                                required property string appIcon
                                                required property string image
                                                required property real time
                                                required property int hIndex
                                                required property int grpCount
                                                required property bool collapsed
                                                required property bool expanded
                                                required property string rowKey

                                                readonly property bool isHeader: rowType === "header"
                                                readonly property bool isPager: rowType === "pager"
                                                property bool copied: false
                                                readonly property real pad: (isHeader && index > 0) ? root.px(6) : 0

                                                width: list.width
                                                height: pad + (isHeader ? headerBox.height : (isPager ? pagerBox.height : itemBox.height))

                                                Timer { id: copiedTimer; interval: 900; onTriggered: rowItem.copied = false }

                                                // ---------- group header ----------
                                                Rectangle {
                                                    id: headerBox
                                                    visible: rowItem.isHeader
                                                    y: rowItem.pad
                                                    width: parent.width
                                                    height: root.px(30)
                                                    radius: root.px(10)
                                                    color: Theme.alpha(Theme.text, hdrArea.containsMouse ? 0.1 : 0.04)

                                                    MouseArea {
                                                        id: hdrArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: root.toggleCollapse(rowItem.groupName)
                                                    }
                                                    Text {
                                                        id: chev
                                                        anchors { left: parent.left; leftMargin: root.px(8); verticalCenter: parent.verticalCenter }
                                                        text: rowItem.collapsed ? root.icRight : root.icDown
                                                        font.family: Theme.iconFont
                                                        font.pixelSize: root.px(13)
                                                        color: Theme.textDim
                                                    }
                                                    Thumb {
                                                        id: hThumb
                                                        size: 18
                                                        color: "transparent"
                                                        src: root.resolveIcon("", rowItem.appIcon, rowItem.appName, rowItem.summary)
                                                        glyph: root.glyphFor(rowItem.appName, rowItem.summary)
                                                        anchors { left: chev.right; leftMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                                    }
                                                    Lbl {
                                                        id: hName
                                                        anchors { left: hThumb.right; leftMargin: root.px(7); verticalCenter: parent.verticalCenter }
                                                        sz: 11
                                                        font.bold: true
                                                        text: rowItem.groupName
                                                    }
                                                    Rectangle {
                                                        id: badge
                                                        anchors { left: hName.right; leftMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                                        width: Math.max(height, badgeTxt.implicitWidth + root.px(10))
                                                        height: root.px(16)
                                                        radius: height / 2
                                                        color: Theme.alpha(Theme.text, 0.12)
                                                        Lbl { id: badgeTxt; anchors.centerIn: parent; sz: 9; text: rowItem.grpCount }
                                                    }
                                                    // latest message as a preview while collapsed
                                                    Lbl {
                                                        visible: rowItem.collapsed
                                                        anchors {
                                                            left: badge.right; leftMargin: root.px(8)
                                                            right: hClear.left; rightMargin: root.px(6)
                                                            verticalCenter: parent.verticalCenter
                                                        }
                                                        sz: 9
                                                        color: Theme.textDim
                                                        text: rowItem.summary
                                                    }
                                                    IconBtn {
                                                        id: hClear
                                                        base: 20
                                                        icon: "󰆴"
                                                        tip: "Clear " + rowItem.groupName
                                                        tint: root.cAccent
                                                        rest: 0.0
                                                        hot: 0.25
                                                        anchors { right: parent.right; rightMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                                        onClicked: root.removeGroup(rowItem.groupName)
                                                    }
                                                }

                                                // ---------- pager ----------
                                                Item {
                                                    id: pagerBox
                                                    visible: rowItem.isPager
                                                    x: root.px(6)
                                                    width: parent.width - root.px(6)
                                                    height: root.px(22)
                                                    Lbl {
                                                        anchors { left: parent.left; leftMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                                        sz: 9
                                                        color: Theme.textDim
                                                        text: rowItem.summary
                                                    }
                                                    Row {
                                                        anchors { right: parent.right; rightMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                                        spacing: root.px(4)
                                                        IconBtn {
                                                            base: 18
                                                            rest: 0.06
                                                            icon: root.icUp
                                                            tip: "Newer"
                                                            opacity: rowItem.hIndex > 0 ? 1 : 0.3
                                                            onClicked: root.scrollGroup(rowItem.groupName, -1)
                                                        }
                                                        IconBtn {
                                                            base: 18
                                                            rest: 0.06
                                                            icon: root.icDown
                                                            tip: "Older"
                                                            opacity: rowItem.hIndex + root.groupLimit < rowItem.grpCount ? 1 : 0.3
                                                            onClicked: root.scrollGroup(rowItem.groupName, 1)
                                                        }
                                                    }
                                                }

                                                // ---------- notification entry ----------
                                                Rectangle {
                                                    id: itemBox
                                                    visible: rowItem.rowType === "item"
                                                    x: root.px(6)
                                                    width: parent.width - root.px(6)
                                                    height: Math.max(root.px(52), textCol.implicitHeight + root.px(20))
                                                    radius: root.px(12)
                                                    color: Theme.alpha(Theme.text, rowItem.copied ? 0.2 : 0.06)
                                                    clip: heightAnim.running
                                                    Behavior on height {
                                                        NumberAnimation { id: heightAnim; duration: 220; easing.type: Easing.OutCubic }
                                                    }

                                                    // wheel scrolls through the group's entries; at either end
                                                    // the event is passed on so the whole list scrolls
                                                    WheelHandler {
                                                        enabled: rowItem.grpCount > root.groupLimit
                                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                                        onWheel: event => {
                                                            const d = event.angleDelta.y
                                                            if (d === 0) { event.accepted = false; return }
                                                            event.accepted = root.scrollGroup(rowItem.groupName, d < 0 ? 1 : -1)
                                                        }
                                                    }

                                                    Thumb {
                                                        id: eThumb
                                                        size: 30
                                                        color: Theme.alpha(Theme.text, 0.1)
                                                        src: root.resolveIcon(rowItem.image, rowItem.appIcon, rowItem.appName, rowItem.summary)
                                                        glyph: root.glyphFor(rowItem.appName, rowItem.summary)
                                                        anchors { left: parent.left; leftMargin: root.px(10); top: parent.top; topMargin: root.px(10) }
                                                    }

                                                    Column {
                                                        id: textCol
                                                        anchors {
                                                            left: eThumb.right; leftMargin: root.px(10)
                                                            right: parent.right; rightMargin: root.px(8)
                                                            top: parent.top; topMargin: root.px(10)
                                                        }
                                                        spacing: root.px(3)

                                                        Item {
                                                            width: parent.width
                                                            height: Math.max(root.px(20), eTitle.implicitHeight)
                                                            Lbl {
                                                                id: eTitle
                                                                anchors { left: parent.left; top: parent.top }
                                                                width: parent.width - eBtns.width - root.px(6)
                                                                sz: 11
                                                                font.bold: true
                                                                text: rowItem.summary
                                                                wrapMode: rowItem.expanded ? Text.WordWrap : Text.NoWrap
                                                            }
                                                            Row {
                                                                id: eBtns
                                                                anchors { right: parent.right; top: parent.top }
                                                                spacing: root.px(2)
                                                                IconBtn {
                                                                    base: 20
                                                                    rest: 0.0
                                                                    visible: root.canExpand(rowItem.body)
                                                                    icon: rowItem.expanded ? root.icUp : root.icDown
                                                                    tip: rowItem.expanded ? "Collapse" : "Expand"
                                                                    onClicked: root.toggleExpand(rowItem.index, rowItem.rowKey)
                                                                }
                                                                IconBtn {
                                                                    base: 20
                                                                    rest: 0.0
                                                                    icon: rowItem.copied ? root.icCheck : root.icCopy
                                                                    tip: "Copy"
                                                                    onClicked: {
                                                                        root.copyText(rowItem.summary, rowItem.body)
                                                                        rowItem.copied = true
                                                                        copiedTimer.restart()
                                                                    }
                                                                }
                                                                IconBtn {
                                                                    base: 20
                                                                    rest: 0.0
                                                                    icon: "󰅖"
                                                                    tip: "Remove"
                                                                    tint: root.cAccent
                                                                    hot: 0.25
                                                                    onClicked: root.removeHistory(rowItem.hIndex)
                                                                }
                                                            }
                                                        }

                                                        // collapsed body (2 lines)
                                                        Lbl {
                                                            width: parent.width
                                                            visible: !rowItem.expanded && text !== ""
                                                            text: rowItem.body
                                                            color: Theme.textDim
                                                            textFormat: Text.PlainText
                                                            wrapMode: Text.WordWrap
                                                            maximumLineCount: 2
                                                        }

                                                        // expanded body: selectable. Selecting copies it to the clipboard.
                                                        TextEdit {
                                                            id: bodyEdit
                                                            visible: rowItem.expanded && rowItem.body !== ""
                                                            width: parent.width
                                                            height: visible ? implicitHeight : 0
                                                            readOnly: true
                                                            selectByMouse: true
                                                            persistentSelection: true
                                                            wrapMode: TextEdit.Wrap
                                                            textFormat: TextEdit.PlainText
                                                            text: rowItem.body
                                                            color: Theme.text
                                                            selectionColor: Theme.alpha(Theme.text, 0.3)
                                                            selectedTextColor: Theme.text
                                                            font.pixelSize: root.fs(10)
                                                            Keys.onEscapePressed: root.closePanel()
                                                            onSelectedTextChanged: selTimer.restart()
                                                            Timer {
                                                                id: selTimer
                                                                interval: 450
                                                                onTriggered: {
                                                                    if (bodyEdit.selectedText !== "") {
                                                                        root.copyRaw(bodyEdit.selectedText)
                                                                        rowItem.copied = true
                                                                        copiedTimer.restart()
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        Lbl {
                                                            sz: 9
                                                            width: parent.width
                                                            color: Theme.textDim
                                                            opacity: 0.7
                                                            text: (rowItem.appName !== "" ? rowItem.appName + " · " : "") + root.fmtTime(rowItem.time)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════════════ Reusable components ═════════════════════════

    // text follows the component scale AND the text size
    component Lbl: Text {
        property real sz: 10
        font.pixelSize: root.fs(sz)
        color: Theme.text
        elide: Text.ElideRight
    }

    component Thumb: Rectangle {
        id: th
        property real size: 40
        property string src: ""
        property string glyph: "󰂚"
        width: root.px(size)
        height: width
        radius: root.px(8)
        clip: true
        Image {
            id: im
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(th.width * 2, th.height * 2)
            source: th.src
        }
        Text {
            anchors.centerIn: parent
            visible: im.status !== Image.Ready
            text: th.glyph
            font.family: Theme.iconFont
            font.pixelSize: Math.round(th.width * 0.45)
            color: Theme.text
        }
    }

    component IconBtn: Rectangle {
        id: b
        property real base: 24
        property string icon: ""
        property string tip: ""
        property color tint: Theme.text
        property real rest: 0.08
        property real hot: 0.2
        property bool tipReady: false
        signal clicked()
        width: root.px(base)
        height: width
        radius: Math.round(width / 3)
        color: Theme.alpha(tint, area.containsMouse ? hot : rest)

        Text {
            anchors.centerIn: parent
            text: b.icon
            font.family: Theme.iconFont
            font.pixelSize: Math.round(b.width * 0.54)
            color: b.tint
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.clicked()
            onContainsMouseChanged: {
                b.tipReady = false
                if (containsMouse) tipTimer.restart(); else tipTimer.stop()
            }
        }
        Timer { id: tipTimer; interval: 400; onTriggered: b.tipReady = true }

        Rectangle {
            visible: b.tipReady && b.tip !== ""
            anchors.top: parent.bottom
            anchors.topMargin: 6
            anchors.right: parent.right
            z: 100
            width: tipText.implicitWidth + root.px(14)
            height: tipText.implicitHeight + root.px(8)
            radius: root.px(7)
            color: Theme.bg
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.15)
            Lbl { id: tipText; anchors.centerIn: parent; sz: 9; text: b.tip }
        }
    }

    // ---- keyboard-focusable controls (accent ring while focused) ----
    component SpTile: Rectangle {
        id: tl
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property bool blinking: false
        signal clicked()
        signal scrolled(int dir)
        activeFocusOnTab: true
        height: root.px(52)
        radius: root.px(12)
        color: Theme.alpha(Theme.text, tlArea.pressed ? 0.16 : (tlArea.containsMouse || tl.activeFocus) ? 0.1 : 0.06)
        border.width: tl.activeFocus ? 1 : 0
        border.color: root.cAccent
        Behavior on color { ColorAnimation { duration: 100 } }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                tl.clicked()
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                root.focusStep(tl, true)
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                root.focusStep(tl, false)
            } else {
                return
            }
            event.accepted = true
        }

        Column {
            anchors.centerIn: parent
            spacing: root.px(2)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tl.icon
                font.family: Theme.iconFont
                font.pixelSize: root.px(20)
                color: tl.on ? root.cAccent : Theme.text
            }
            Lbl {
                visible: tl.sub !== ""
                width: tl.width - root.px(8)
                horizontalAlignment: Text.AlignHCenter
                sz: 9
                color: tl.on ? root.cAccent : Theme.textDim
                text: tl.sub
            }
        }

        // blinking border while Bluetooth is connecting
        Rectangle {
            visible: tl.blinking
            anchors.fill: parent
            radius: tl.radius
            color: "transparent"
            border.width: 1
            border.color: root.cAccent
            SequentialAnimation on opacity {
                running: tl.blinking && root.animMs > 0
                loops: Animation.Infinite
                NumberAnimation { to: 0.1; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
            }
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => { if (e.angleDelta.y !== 0) tl.scrolled(e.angleDelta.y > 0 ? 1 : -1) }
        }
        MouseArea {
            id: tlArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { tl.forceActiveFocus(); tl.clicked() }
        }
    }

    // Slider (currently unused; kept for reuse)
    component SpSlider: Item {
        id: sr
        property string label: ""
        property string valueText: ""
        property real from: 0
        property real to: 100
        property real step: 1
        property real value: 0
        signal moved(real v)
        readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

        activeFocusOnTab: true
        height: root.px(38)
        opacity: enabled ? 1 : 0.4

        onActiveFocusChanged: if (activeFocus) root.ensureVisible(sr, root.px(32))

        function nudge(delta) { sr.moved(Math.max(from, Math.min(to, value + delta))) }

        Keys.onPressed: function (event) {
            switch (event.key) {
            case Qt.Key_Left:     sr.nudge(-sr.step); break
            case Qt.Key_Right:    sr.nudge(sr.step); break
            case Qt.Key_PageDown: sr.nudge(-sr.step * 5); break
            case Qt.Key_PageUp:   sr.nudge(sr.step * 5); break
            case Qt.Key_Home:     sr.moved(sr.from); break
            case Qt.Key_End:      sr.moved(sr.to); break
            case Qt.Key_Down:     root.focusStep(sr, true); break
            case Qt.Key_Up:       root.focusStep(sr, false); break
            default: return
            }
            event.accepted = true
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: root.px(8)
            color: "transparent"
            visible: sr.activeFocus
            border.width: 1
            border.color: root.cAccent
        }
        Lbl {
            anchors.left: parent.left
            anchors.right: srValue.left
            anchors.rightMargin: root.px(6)
            y: root.px(2)
            sz: 11
            font.bold: true
            text: sr.label
        }
        Lbl {
            id: srValue
            anchors.right: parent.right
            y: root.px(3)
            sz: 10
            color: Theme.textDim
            text: sr.valueText
        }
        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            y: root.px(26)
            height: root.px(4)
            radius: height / 2
            color: Theme.alpha(Theme.text, 0.15)
            Rectangle {
                width: knob.x + knob.width / 2
                height: parent.height
                radius: parent.radius
                color: root.cAccent
            }
            Rectangle {
                id: knob
                width: root.px(14)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: sr.ratio * (track.width - width)
                color: root.cText
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: root.px(16)
            preventStealing: true
            enabled: sr.enabled
            function apply(mx) {
                const usable = track.width - knob.width
                if (usable <= 0) return
                const r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable))
                const raw = sr.from + r * (sr.to - sr.from)
                const snapped = sr.from + Math.round((raw - sr.from) / sr.step) * sr.step
                sr.moved(Math.max(sr.from, Math.min(sr.to, snapped)))
            }
            onPressed: mouse => { sr.forceActiveFocus(); apply(mouse.x) }
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
        }
    }
}