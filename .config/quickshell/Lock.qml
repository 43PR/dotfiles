pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

// Lock screen (ext-session-lock) with a settings window.
//
//   qs ipc call lock lock       lock the session
//   qs ipc call lock settings   open a NON-locking preview + the settings window
//   qs ipc call lock preview    same preview, without the settings window
//
// Right-click anywhere on the screen (preview or real lock) opens the settings.
// Settings are cosmetic only. Saved to state/lock-state.json.
//
// Why the settings live inside the lock surface: while the session is locked
// the compositor only shows lock surfaces, so a separate PanelWindow (like the
// power menu's settings window) would be invisible. The preview mode exists so
// you can tweak the look without locking.
//
// SAFETY: a session lock stays active if quickshell crashes. Keep a TTY ready.

Scope {
    id: root

    // ======================================================================
    // runtime state
    // ======================================================================
    property string buffer: ""
    property bool checking: false
    property bool failed: false
    property string failText: ""

    property bool previewing: false
    property var previewScreen: null
    property bool wantSettings: false
    property string shotMode: "lock"

    // PAM service from /etc/pam.d ("hyprlock" exists while hyprlock is installed)
    readonly property string pamConfig: "hyprlock"

    // users offered by the switch button (regular accounts, you first)
    property var users: []
    property int userIdx: 0
    readonly property string activeUser: users.length > 0 ? users[userIdx % users.length] : sysUser
    readonly property bool ownUser: activeUser === sysUser

    function cycleUser() {
        if (users.length < 2) return
        userIdx = (userIdx + 1) % users.length
        buffer = ""
        failed = false
    }

    Process {
        id: usersProc
        running: true
        command: ["sh", "-c",
            "getent passwd | awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").map(s => s.trim()).filter(s => s !== "")
                const me = root.sysUser
                root.users = me !== "" ? [me].concat(l.filter(u => u !== me)) : l
                root.userIdx = 0
            }
        }
    }

    // hyprlock used Roboto Mono; use Theme.fontFamily to follow the hub font
    readonly property string fontFamily: cfg.font === "theme" ? Theme.fontFamily : (cfg.font ?? "Roboto Mono")
    readonly property string iconFont: Theme.iconFont

    // profile picture (same files as the system page) + name
    readonly property string imgDir: Quickshell.env("HOME") + "/.config/quickshell/imgs"
    readonly property string pfpCustom: imgDir + "/pfp_custom"
    readonly property string pfpDefault: imgDir + "/pfp3.png"
    readonly property string sysUser: Quickshell.env("USER") || ""
    readonly property string userDisplay: (cfg.userText !== "" && ownUser) ? cfg.userText : activeUser

    // layout name -> short label (hyprlock's $LAYOUT[en,ru])
    readonly property var layoutShort: ({
        "English (US)": "en",
        "Russian": "ru"
    })

    // ======================================================================
    // settings spec
    // ======================================================================
    readonly property var numSpec: ({
        // general
        fadeMs:         { min: 0,    max: 1500, def: 500, step: 50, unit: " ms" },
        fadeOutMs:      { min: 0,    max: 1500, def: 300, step: 50, unit: " ms" },
        blur:           { min: 0,    max: 100,  def: 85,  step: 5,  unit: "%" },
        dim:            { min: 0,    max: 100,  def: 0,   step: 5,  unit: "%" },
        // input field
        fieldWidth:     { min: 8,    max: 60,   def: 20,  step: 1,  unit: "%" },
        fieldHeight:    { min: 2,    max: 12,   def: 5,   step: 1,  unit: "%" },
        outlineWidth:   { min: 0,    max: 10,   def: 3,   step: 1,  unit: "px" },
        fieldRadius:    { min: 0,    max: 60,   def: 25,  step: 1,  unit: "px" },
        dotSize:        { min: 5,    max: 60,   def: 20,  step: 1,  unit: "%" },
        dotSpacing:     { min: 0,    max: 100,  def: 30,  step: 5,  unit: "%" },
        fieldOffsetY:   { min: -400, max: 400,  def: 0,   step: 5,  unit: "px" },
        // text sizes
        timeSize:       { min: 20,   max: 160,  def: 70,  step: 2,  unit: "px" },
        dateSize:       { min: 8,    max: 48,   def: 18,  step: 1,  unit: "px" },
        layoutSize:     { min: 8,    max: 40,   def: 14,  step: 1,  unit: "px" },
        mediaSize:      { min: 8,    max: 40,   def: 15,  step: 1,  unit: "px" },
        controlSize:    { min: 10,   max: 48,   def: 18,  step: 1,  unit: "px" },
        // positions (px at 1080p; top-based for time/date, centre-based for the rest)
        timeY:          { min: 0,    max: 600,  def: 130, step: 5,  unit: "px" },
        dateY:          { min: 0,    max: 700,  def: 250, step: 5,  unit: "px" },
        layoutY:        { min: -540, max: 540,  def: 70,  step: 5,  unit: "px" },
        mediaY:         { min: -540, max: 540,  def: 300, step: 5,  unit: "px" },
        controlsY:      { min: -540, max: 540,  def: 345, step: 5,  unit: "px" },
        mediaWidth:     { min: 10,   max: 60,   def: 15,  step: 1,  unit: "%" },
        controlSpacing: { min: 30,   max: 120,  def: 50,  step: 2,  unit: "px" },
        // weather
        weatherSize:    { min: 8,    max: 60,   def: 14,  step: 1,  unit: "px" },
        weatherY:       { min: 0,    max: 900,  def: 290, step: 5,  unit: "px" },
        // spacing between clock, date and weather when they are pushed down
        stackGap:       { min: 0,    max: 100,  def: 10,  step: 1,  unit: "px" },
        ampmGap:        { min: 0,    max: 60,   def: 14,   step: 1,  unit: "px" },
        // profile
        pfpSize:        { min: 40,   max: 300,  def: 100, step: 5,  unit: "px" },
        pfpY:           { min: 0,    max: 1000, def: 330, step: 5,  unit: "px" },
        pfpOpacity:     { min: 10,   max: 100,  def: 100, step: 5,  unit: "%" },
        userSize:       { min: 8,    max: 48,   def: 16,  step: 1,  unit: "px" },
        userGap:        { min: 0,    max: 60,   def: 10,  step: 1,  unit: "px" },
        // hide until key press
        idleHideSec:    { min: 1,    max: 60,   def: 5,   step: 1,  unit: " s" },
        revealMs:       { min: 0,    max: 1000, def: 300, step: 50, unit: " ms" }
    })

    readonly property var boolDefaults: ({
        useScreenshot: true,
        useWallpaper: true,
        showTime: true,
        showDate: true,
        showLayout: true,
        showCaps: true,
        showMedia: true,
        showControls: true,
        clock24: true,
        clockSeconds: false,
        fadeOnEmpty: false,
        showFailText: true,
        showWeather: true,
        showWeatherCity: false,
        showWeatherCond: true,
        dateMonthFirst: true,
        ampmLower: false,
        showPfp: true,
        showUser: true,
        showSwitchUser: true,
        hideUntilKey: true,
        hideInput: true,
        hidePfp: true,
        hideLayout: true,
        clockVertical: false
    })

    readonly property var colorChoices: [
        { id: "accent",  label: "Accent" },
        { id: "accent2", label: "Accent 2" },
        { id: "text",    label: "Text" },
        { id: "textDim", label: "Dim text" },
        { id: "danger",  label: "Danger" },
        { id: "ok",      label: "OK" },
        { id: "bg",      label: "Background" },
        { id: "black",   label: "Black" },
        { id: "white",   label: "White" }
    ]

    readonly property var colorDefaults: ({
        outlineColor: "accent2",    // $lock_outline
        checkColor:   "accent2",    // $lock_check
        failColor:    "danger",     // $lock_fail
        dotColor:     "text",       // $lock_font
        timeColor:    "text",       // $lock_time
        dateColor:    "textDim",    // $lock_date
        layoutColor:  "textDim",    // $lock_layout
        mediaColor:   "textDim",
        weatherColor: "textDim",
        userColor:    "textDim"
    })

    // ids are font family names (same list as the Appearance page); "theme" follows Theme.fontFamily
    readonly property var fontChoices: [
        { id: "Roboto Mono",             label: "Roboto Mono" },
        { id: "JetBrains Mono",          label: "JetBrains" },
        { id: "JetBrainsMono Nerd Font", label: "JetBrains NF" },
        { id: "Iosevka Nerd Font",       label: "Iosevka NF" },
        { id: "theme",                   label: "Theme font" }
    ]

    readonly property var defaults: {
        const o = {}
        for (const k in numSpec) o[k] = numSpec[k].def
        for (const k in boolDefaults) o[k] = boolDefaults[k]
        for (const k in colorDefaults) o[k] = colorDefaults[k]
        o.font = "Roboto Mono"
        o.userText = ""
        return o
    }

    // current values (reassigned as a whole so bindings update)
    property var cfg: defaults

    function setCfg(k, v) {
        if (cfg[k] === v) return
        const o = Object.assign({}, cfg)
        o[k] = v
        cfg = o
    }

    readonly property bool modified: {
        for (const k in defaults)
            if (cfg[k] !== defaults[k]) return true
        return false
    }

    function themeColor(id) {
        switch (id) {
        case "accent":  return Theme.accentSolid
        case "accent2": return Theme.accent2
        case "text":    return Theme.text
        case "textDim": return Theme.textDim
        case "danger":  return Theme.danger
        case "ok":      return Theme.ok
        case "bg":      return Theme.bgPanel
        case "black":   return Qt.rgba(0, 0, 0, 1)
        case "white":   return Qt.rgba(1, 1, 1, 1)
        }
        return Theme.text
    }
    function colorOf(key) { return themeColor(cfg[key]) }
    function colorLabel(id) {
        const c = colorChoices.find(x => x.id === id)
        return c ? c.label : id
    }

    function clampNum(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function fmt(k, v) { return v + numSpec[k].unit }

    function setNumber(k, v) {
        const s = numSpec[k]
        const snapped = Math.round((v - s.min) / s.step) * s.step + s.min
        setCfg(k, clampNum(Math.round(snapped), s.min, s.max))
    }
    function toggleBool(k) { setCfg(k, !cfg[k]); saveState() }
    function cycleColor(k, dir) {
        const n = colorChoices.length
        let i = colorChoices.findIndex(c => c.id === cfg[k])
        if (i < 0) i = 0
        setCfg(k, colorChoices[((i + dir) % n + n) % n].id)
        saveState()
    }
    function fontLabel(id) {
        const f = fontChoices.find(x => x.id === id)
        return f ? f.label : id
    }
    function cycleFont(dir) {
        const n = fontChoices.length
        let i = fontChoices.findIndex(f => f.id === cfg.font)
        if (i < 0) i = 0
        setCfg("font", fontChoices[((i + dir) % n + n) % n].id)
        saveState()
    }
    function resetAll() { cfg = defaults; saveState() }

    // clock text: one line, or hours / minutes (/ seconds / AM-PM) stacked
    function timeText(d) {
        const c = cfg
        if (c.clockVertical) {
            const p = [Qt.formatDateTime(d, c.clock24 ? "hh" : "h"), Qt.formatDateTime(d, "mm")]
            if (c.clockSeconds) p.push(Qt.formatDateTime(d, "ss"))
            if (!c.clock24) p.push(Qt.formatDateTime(d, c.ampmLower ? "ap" : "AP"))
            return p.join("\n")
        }
        return Qt.formatDateTime(d, c.clock24
            ? (c.clockSeconds ? "hh:mm:ss" : "hh:mm")
            : (c.clockSeconds ? "h:mm:ss" : "h:mm"))
    }
    function ampmText(d) { return Qt.formatDateTime(d, cfg.ampmLower ? "ap" : "AP") }

    // ======================================================================
    // settings window state (position / zoom / folded sections)
    // ======================================================================
    readonly property real zoomMin: 0.6
    readonly property real zoomMax: 2.0
    readonly property real zoomStep: 0.05
    readonly property int keepVisible: 40

    property bool settingsOpen: false
    property string settingsScreenName: ""
    property real settingsScreenW: 1920
    property real settingsScreenH: 1080
    property real settingsZoom: 1.0
    property bool settingsPosSet: false
    property real settingsX: 0
    property real settingsY: 0
    property bool settingsDragging: false
    property var collapsedSections: ({ positions: true, colors: true, field: true, elements: true })

    // same source as the power menu: settingsScale from state/hub.json (clamped 0.6-1.2)
    property real hubScale: 1.0
    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/state/hub.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const h = JSON.parse(text())
                if (typeof h.settingsScale === "number")
                    root.hubScale = Math.max(0.6, Math.min(1.2, h.settingsScale))
            } catch (e) {}
        }
    }

    readonly property real settingsU: (settingsScreenH / 1080) * hubScale * settingsZoom
    readonly property real settingsWinW: Math.round(Math.min(440 * settingsU, settingsScreenW * 0.95))
    readonly property real settingsWinH: Math.round(Math.min(640 * settingsU, settingsScreenH * 0.88))

    function clampSX(x) {
        return Math.round(Math.max(keepVisible - settingsWinW, Math.min(settingsScreenW - keepVisible, x)))
    }
    function clampSY(y) {
        return Math.round(Math.max(0, Math.min(settingsScreenH - keepVisible, y)))
    }
    readonly property real settingsEffX: settingsPosSet
        ? clampSX(settingsX) : Math.round((settingsScreenW - settingsWinW) / 2)
    readonly property real settingsEffY: settingsPosSet
        ? clampSY(settingsY) : Math.round((settingsScreenH - settingsWinH) / 2)

    function setSettingsPos(x, y) {
        settingsX = clampSX(x)
        settingsY = clampSY(y)
        settingsPosSet = true
    }
    function setSettingsZoom(z) {
        const nz = Math.max(zoomMin, Math.min(zoomMax, Math.round(z * 100) / 100))
        if (nz === settingsZoom) return
        if (settingsPosSet) {
            const cx = settingsEffX + settingsWinW / 2
            const cy = settingsEffY + settingsWinH / 2
            settingsZoom = nz
            settingsX = clampSX(cx - settingsWinW / 2)
            settingsY = clampSY(cy - settingsWinH / 2)
        } else {
            settingsZoom = nz
        }
        saveTimer.restart()
    }
    function resetSettingsWindow() {
        settingsPosSet = false
        settingsZoom = 1.0
        saveState()
    }
    function isCollapsed(k) { return collapsedSections[k] === true }
    function toggleSection(k) {
        const o = Object.assign({}, collapsedSections)
        if (o[k]) delete o[k]; else o[k] = true
        collapsedSections = o
        saveTimer.restart()
    }
    function cellW(p) {
        if (!p) return 0
        if (p.columns !== undefined && p.columns > 1 && p.columnSpacing !== undefined)
            return Math.floor((p.width - (p.columns - 1) * p.columnSpacing) / p.columns)
        return p.width
    }

    function openSettings(screenName, w, h) {
        settingsScreenName = screenName
        settingsScreenW = w
        settingsScreenH = h
        settingsDragging = false
        settingsOpen = true
    }
    function closeSettings() {
        settingsOpen = false
        settingsDragging = false
    }

    Timer { id: saveTimer; interval: 400; onTriggered: root.saveState() }

    // ======================================================================
    // persistence
    // ======================================================================
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/lock-state.json"

    function saveState() {
        const s = Object.assign({}, cfg)
        s.settingsZoom = settingsZoom
        s.collapsed = collapsedSections
        if (settingsPosSet) { s.settingsX = settingsX; s.settingsY = settingsY }
        stateFile.setText(JSON.stringify(s))
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(stateFile.text())
                const o = Object.assign({}, root.defaults)
                for (const k in root.numSpec)
                    if (typeof s[k] === "number")
                        o[k] = root.clampNum(Math.round(s[k]), root.numSpec[k].min, root.numSpec[k].max)
                for (const k in root.boolDefaults)
                    if (typeof s[k] === "boolean") o[k] = s[k]
                for (const k in root.colorDefaults)
                    if (typeof s[k] === "string" && root.colorChoices.some(c => c.id === s[k]))
                        o[k] = s[k]
                if (typeof s.font === "string" && root.fontChoices.some(f => f.id === s.font))
                    o.font = s.font
                if (typeof s.userText === "string")
                    o.userText = s.userText.slice(0, 40)
                root.cfg = o
                if (s.collapsed && typeof s.collapsed === "object" && !Array.isArray(s.collapsed))
                    root.collapsedSections = s.collapsed
                if (typeof s.settingsZoom === "number")
                    root.settingsZoom = root.clampNum(s.settingsZoom, root.zoomMin, root.zoomMax)
                if (typeof s.settingsX === "number" && typeof s.settingsY === "number") {
                    root.settingsX = s.settingsX
                    root.settingsY = s.settingsY
                    root.settingsPosSet = true
                }
            } catch (e) {
                console.warn("lock: could not read saved state:", e)
            }
        }
    }

    // ======================================================================
    // wallpaper (written by commands.sh -> ~/.cache/43pr/last-wallpaper)
    // videos / GIFs use the first-frame PNG that commands.sh already extracts
    // ======================================================================
    property string wallpaperSrc: ""

    function fileUrl(p) {
        return "file://" + encodeURI(p).replace(/#/g, "%23")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/43pr/last-wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const p = text().trim()
            if (p === "") return
            const low = p.toLowerCase()
            const base = p.split("/").pop().replace(/\.[^.]*$/, "")
            const animated = /\.(mp4|mkv|webm|mov|gif)$/.test(low)
            root.wallpaperSrc = animated
                ? Quickshell.env("HOME") + "/.cache/43pr/gif-frames/" + base + ".png"
                : p
        }
    }

    // ======================================================================
    // services
    // ======================================================================
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // same player selection as the bar's media module
    readonly property var player: {
        const ps = Mpris.players.values
        return ps.find(p => p.isPlaying)
            ?? ps.find(p => (p.trackTitle ?? "") !== "")
            ?? ps[0] ?? null
    }
    readonly property bool playing: player !== null && player.isPlaying === true
    readonly property string nowPlaying: player
        ? ((player.trackArtist ? player.trackArtist + " - " : "") + (player.trackTitle ?? ""))
        : ""

    function mediaAct(kind) {
        const p = root.player
        if (!p) return
        if (kind === "toggle") {
            if (p.canTogglePlaying) p.togglePlaying()
            else if (p.isPlaying && p.canPause) p.pause()
            else if (p.canPlay) p.play()
        }
        else if (kind === "next") { if (p.canGoNext) p.next() }
        else { if (p.canGoPrevious) p.previous() }
    }

    // ======================================================================
    // keyboard layout + Caps Lock (HyprlandXkb is not available in every
    // Quickshell build, so ask hyprctl instead)
    // ======================================================================
    property string layoutName: ""
    property bool capsLock: false

    Process {
        id: kbProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const kb = j.keyboards.find(k => k.main) ?? j.keyboards[0]
                    if (kb) {
                        root.layoutName = kb.active_keymap ?? ""
                        root.capsLock = kb.capsLock === true
                    }
                } catch (e) {}
            }
        }
    }
    Timer {
        id: kbTimer
        interval: 60
        onTriggered: if (!kbProc.running) kbProc.running = true
    }
    function refreshKb() { kbTimer.restart() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") root.refreshKb()
        }
    }
    Component.onCompleted: refreshKb()

    // ======================================================================
    // weather (Open-Meteo). City + unit come from bar-state.json like the side
    // panel; its cache gives an instant first paint. Refreshed when you lock.
    // ======================================================================
    property bool wxOk: false
    property real wxTemp: 0
    property int wxCode: 0
    property bool wxDay: true
    property string wxLoc: ""
    property real wxLat: 0
    property real wxLon: 0
    property bool wxHaveGeo: false
    property string wxGeoCity: ""
    property real wxAt: 0
    property bool wxF: false
    property string wxCity: ""

    readonly property var wxNames: ({
        0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
        45: "Fog", 48: "Fog", 51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
        56: "Freezing drizzle", 57: "Freezing drizzle", 61: "Light rain", 63: "Rain", 65: "Heavy rain",
        66: "Freezing rain", 67: "Freezing rain", 71: "Light snow", 73: "Snow", 75: "Heavy snow",
        77: "Snow grains", 80: "Rain showers", 81: "Rain showers", 82: "Heavy showers",
        85: "Snow showers", 86: "Snow showers", 95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm"
    })
    function wxCond(c, day) {
        if (c === 0) return day ? "Sunny" : "Clear"
        if (c === 1) return day ? "Mostly sunny" : "Mostly clear"
        if (c === 3) return "Cloudy"
        return wxNames[c] ?? ""
    }
    function wxGlyph(c, day) {
        if (c === 0 || c === 1) return day ? "󰖙" : "󰖔"
        if (c === 2) return day ? "󰖕" : "󰼱"
        if (c === 3) return "󰖐"
        if (c === 45 || c === 48) return "󰖑"
        if (c >= 95) return "󰙾"
        if (c === 56 || c === 57 || c === 66 || c === 67) return "󰙿"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "󰖘"
        if (c === 65 || c === 82) return "󰖖"
        return "󰖗"
    }
    readonly property string wxLine: {
        let out = Math.round(wxF ? wxTemp * 9 / 5 + 32 : wxTemp) + "°"
        if (cfg.showWeatherCond) out += "  " + wxCond(wxCode, wxDay)
        if (cfg.showWeatherCity && wxLoc !== "") out += "  ·  " + wxLoc
        return out
    }

    function refreshWeather() {
        if (geoProc.running || wxProc.running) return
        if (wxGeoCity !== wxCity) wxHaveGeo = false
        const fresh = wxOk && wxGeoCity === wxCity && Date.now() - wxAt < 600000
        if (fresh) return
        if (wxHaveGeo) wxProc.running = true
        else geoProc.running = true
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text())
                if (typeof j.weatherF === "boolean") root.wxF = j.weatherF
                if (typeof j.weatherCity === "string") root.wxCity = j.weatherCity
            } catch (e) {}
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.cache/43pr/weather-panel.json"
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text())
                if (!o || typeof o.at !== "number" || Date.now() - o.at > 6 * 3600 * 1000) return
                if (root.wxOk) return
                root.wxAt = o.at
                root.wxGeoCity = String(o.city ?? "")
                root.wxHaveGeo = typeof o.lat === "number" && typeof o.lon === "number"
                root.wxLat = o.lat ?? 0
                root.wxLon = o.lon ?? 0
                root.wxLoc = String(o.loc ?? "")
                root.wxTemp = o.tempC
                root.wxCode = o.code
                root.wxDay = o.isDay === true
                root.wxOk = true
            } catch (e) {}
        }
    }
    Process {
        id: geoProc
        command: root.wxCity === ""
            ? ["curl", "-sf", "-m", "10", "http://ip-api.com/json/?fields=status,city,regionName,lat,lon"]
            : ["curl", "-sf", "-m", "10",
               "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(root.wxCity)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const r = root.wxCity === "" ? j : j.results[0]
                    root.wxLat = r.lat ?? r.latitude
                    root.wxLon = r.lon ?? r.longitude
                    root.wxLoc = root.wxCity === "" ? (r.city || r.regionName || "") : (r.name || root.wxCity)
                    root.wxGeoCity = root.wxCity
                    root.wxHaveGeo = true
                    wxProc.running = true
                } catch (e) {}
            }
        }
    }
    Process {
        id: wxProc
        command: ["curl", "-sf", "-m", "15",
                  "https://api.open-meteo.com/v1/forecast?latitude=" + root.wxLat + "&longitude=" + root.wxLon
                  + "&current=temperature_2m,weather_code,is_day&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).current
                    root.wxTemp = c.temperature_2m
                    root.wxCode = c.weather_code
                    root.wxDay = c.is_day === 1
                    root.wxAt = Date.now()
                    root.wxOk = true
                } catch (e) {}
            }
        }
    }

    // ======================================================================
    // lock / preview lifecycle
    // ======================================================================
    function shotPath(name) {
        return (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qslock-" + name + ".png"
    }

    function pickScreen() {
        const mon = Hyprland.focusedMonitor
        if (mon) {
            const s = Quickshell.screens.find(x => x.name === mon.name)
            if (s) return s
        }
        return Quickshell.screens[0]
    }

    function resetInput() {
        buffer = ""
        failed = false
        checking = false
        awake = false
        idleTimer.stop()
        previewTimer.stop()
        userIdx = 0
    }

    // ---- hide until key press ----
    property bool awake: false
    readonly property bool uiShown: !cfg.hideUntilKey || awake || settingsOpen
                                    || buffer !== "" || checking

    function wake() {
        if (!cfg.hideUntilKey) return
        awake = true
        idleTimer.restart()
    }
    // a failed attempt wakes the UI so the fail text is seen
    onFailedChanged: if (failed) wake()

    Timer {
        id: idleTimer
        interval: root.cfg.idleHideSec * 1000
        onTriggered: {
            if (root.buffer !== "" || root.checking) restart()
            else root.awake = false
        }
    }

    // grab every output first, then lock/preview, so the background is the desktop
    function startShot(mode) {
        resetInput()
        refreshKb()
        refreshWeather()
        shotMode = mode
        const names = Quickshell.screens.map(s => s.name)
        const dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
        shot.command = ["sh", "-c",
            "d=\"$1\"; shift; for o in \"$@\"; do grim -o \"$o\" \"$d/qslock-$o.png\" & done; wait",
            "sh", dir].concat(names)
        shot.running = true
    }

    property bool unlocking: false

    function lockNow() {
        if (sessionLock.locked || shot.running || unlocking) return
        if (previewing) doClosePreview()
        startShot("lock")
    }

    // fade the view out first, then actually release the lock
    function beginFadeOut() {
        if (unlocking) return
        if (cfg.fadeOutMs <= 0) { finishFadeOut(); return }
        unlocking = true
        fadeOutTimer.interval = cfg.fadeOutMs + 40
        fadeOutTimer.restart()
    }
    function finishFadeOut() {
        if (sessionLock.locked) sessionLock.locked = false
        else previewing = false
        settingsOpen = false
        unlocking = false
        resetInput()
    }
    Timer { id: fadeOutTimer; onTriggered: root.finishFadeOut() }

    function unlock() { beginFadeOut() }

    function previewNow(withSettings) {
        if (sessionLock.locked || shot.running || previewing) return
        previewScreen = pickScreen()
        wantSettings = withSettings
        startShot("preview")
    }

    function closePreview() { beginFadeOut() }

    // immediate close, no animation (used when locking from a preview)
    function doClosePreview() {
        previewing = false
        settingsOpen = false
        resetInput()
    }

    Process {
        id: shot
        // proceed even if grim fails: the background falls back to a flat colour
        onExited: {
            if (root.shotMode === "lock") {
                sessionLock.locked = true
            } else {
                root.previewing = true
                if (root.wantSettings && root.previewScreen)
                    root.openSettings(root.previewScreen.name, root.previewScreen.width, root.previewScreen.height)
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lockNow() }
        function unlock(): void { root.unlock() }   // dev helper, remove for daily use
        function toggle(): void { sessionLock.locked ? root.unlock() : root.lockNow() }
        function preview(): void { root.previewing ? root.closePreview() : root.previewNow(false) }
        function settings(): void { root.previewing ? root.closePreview() : root.previewNow(true) }
    }

    // ======================================================================
    // authentication
    // ======================================================================
    function submit(isPreview) {
        if (checking || buffer === "") return
        checking = true
        failed = false
        if (isPreview) previewTimer.restart()      // fake attempt: lets you style the fail look
        else pam.start()
    }

    Timer {
        id: previewTimer
        interval: 700
        onTriggered: {
            root.checking = false
            root.failText = "Authentication failed (preview)"
            root.buffer = ""
            root.failed = true
        }
    }

    PamContext {
        id: pam
        config: root.pamConfig
        user: root.activeUser

        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.buffer)
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock()
                return
            }
            root.failText = (pam.message && pam.message !== "") ? pam.message : "Authentication failed"
            root.buffer = ""
            root.checking = false
            root.failed = true
        }
        onError: {
            root.failText = "Authentication error"
            root.buffer = ""
            root.checking = false
            root.failed = true
        }
    }

    function handleKey(event, isPreview) {
        event.accepted = true
        if (unlocking) return
        wake()
        refreshKb()
        if (event.key === Qt.Key_Escape) {
            if (settingsOpen) closeSettings()
            else if (isPreview) closePreview()
            else { buffer = ""; failed = false }
            return
        }
        if (checking) return

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            submit(isPreview)
            return
        }
        if (event.key === Qt.Key_Backspace) {
            failed = false
            buffer = (event.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1)
            return
        }
        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) {
            if (event.key === Qt.Key_U) buffer = ""
            return
        }
        if (event.text.length > 0 && event.text.charCodeAt(0) >= 32
                && event.text.charCodeAt(0) !== 127) {
            failed = false
            buffer += event.text
        }
    }

    // ======================================================================
    // inline components (declared before use, in dependency order)
    // settings rows are mouse-only: the keyboard types the password
    // ======================================================================
    component SecHeader: Item {
        id: sh
        property string skey: ""
        property string label: ""
        readonly property real u: root.settingsU
        width: parent.width
        height: 34 * u

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 3 * sh.u
            text: sh.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeSection * sh.u
            font.bold: true
            color: Theme.text
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4 * sh.u
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 3 * sh.u
            text: "\uf077"
            font.family: Theme.iconFont
            font.pixelSize: Theme.textSizeBody * sh.u
            color: Theme.textDim
            rotation: root.isCollapsed(sh.skey) ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleSection(sh.skey)
        }
    }

    component SliderRow: Item {
        id: sr
        property string key: ""
        property string label: ""
        readonly property real u: root.settingsU
        readonly property var spec: root.numSpec[key]
        readonly property real value: root.cfg[key]
        readonly property real frac: (value - spec.min) / (spec.max - spec.min)

        width: root.cellW(parent)
        height: 42 * u
        opacity: enabled ? 1 : 0.4

        Text {
            y: 4 * sr.u
            width: parent.width - valueText.implicitWidth - 6 * sr.u
            elide: Text.ElideRight
            text: sr.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeBody * sr.u
            color: Theme.text
        }
        Text {
            id: valueText
            y: 4 * sr.u
            anchors.right: parent.right
            text: root.fmt(sr.key, sr.value)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeBody * sr.u
            color: Theme.textDim
        }
        Rectangle {
            id: track
            y: 28 * sr.u
            width: parent.width
            height: 4 * sr.u
            radius: height / 2
            color: Theme.alpha(Theme.text, 0.12)

            Rectangle {
                width: parent.width * sr.frac
                height: parent.height
                radius: parent.radius
                color: Theme.accentSolid
            }
            Rectangle {
                x: parent.width * sr.frac - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 12 * sr.u
                height: width
                radius: width / 2
                color: Theme.accentSolid
            }
        }
        MouseArea {
            x: 0
            y: 20 * sr.u
            width: parent.width
            height: 22 * sr.u
            cursorShape: Qt.PointingHandCursor
            function apply(mx) {
                const f = Math.max(0, Math.min(1, mx / width))
                root.setNumber(sr.key, sr.spec.min + f * (sr.spec.max - sr.spec.min))
            }
            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
            onReleased: root.saveState()
            onDoubleClicked: { root.setCfg(sr.key, sr.spec.def); root.saveState() }
        }
    }

    component ToggleRow: Item {
        id: tr
        property string key: ""
        property string label: ""
        readonly property real u: root.settingsU
        readonly property bool on: root.cfg[key] === true

        width: root.cellW(parent)
        height: 30 * u
        opacity: enabled ? 1 : 0.4

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 42 * tr.u
            elide: Text.ElideRight
            text: tr.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeBody * tr.u
            color: Theme.text
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * tr.u
            height: 16 * tr.u
            radius: height / 2
            color: tr.on ? Theme.alpha(Theme.accentSolid, 0.35) : Theme.alpha(Theme.text, 0.12)
            border.width: 1
            border.color: tr.on ? Theme.accentSolid : Theme.alpha(Theme.text, 0.2)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                x: tr.on ? parent.width - width - 2 * tr.u : 2 * tr.u
                anchors.verticalCenter: parent.verticalCenter
                width: 10 * tr.u
                height: width
                radius: width / 2
                color: tr.on ? Theme.accentSolid : Theme.textDim
                Behavior on x { NumberAnimation { duration: 100 } }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleBool(tr.key)
        }
    }

    component ColorPickRow: Item {
        id: cr
        property string key: ""
        property string label: ""
        readonly property real u: root.settingsU

        width: root.cellW(parent)
        height: 30 * u

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: cr.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeBody * cr.u
            color: Theme.text
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * cr.u
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10 * cr.u
                height: width
                radius: width / 2
                color: root.colorOf(cr.key)
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.25)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.colorLabel(root.cfg[cr.key])
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeBody * cr.u
                color: Theme.textDim
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => root.cycleColor(cr.key, mouse.button === Qt.RightButton ? -1 : 1)
        }
    }

    component FontPickRow: Item {
        id: fr
        readonly property real u: root.settingsU

        width: root.cellW(parent)
        height: 30 * u

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Font"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeBody * fr.u
            color: Theme.text
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.fontLabel(root.cfg.font)
            font.family: root.fontFamily
            font.pixelSize: Theme.textSizeBody * fr.u
            color: Theme.textDim
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => root.cycleFont(mouse.button === Qt.RightButton ? -1 : 1)
        }
    }

    component ActionButton: Rectangle {
        id: ab
        property string label: ""
        property bool primary: false
        signal clicked()
        readonly property real u: root.settingsU

        implicitWidth: abText.implicitWidth + 24 * u
        implicitHeight: 28 * u
        radius: Math.min(8 * u, Theme.radius * u)
        opacity: enabled ? 1 : 0.4
        color: primary ? Theme.alpha(Theme.accentSolid, abArea.containsMouse ? 0.35 : 0.22)
                       : (abArea.containsMouse ? Theme.alpha(Theme.text, 0.1) : "transparent")
        border.width: 1
        border.color: primary ? Theme.accentSolid : Theme.alpha(Theme.text, 0.2)

        Text {
            id: abText
            anchors.centerIn: parent
            text: ab.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeBody * ab.u
            font.bold: ab.primary
            color: Theme.text
        }
        MouseArea {
            id: abArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: ab.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.clicked()
        }
    }

    component LockMarquee: Item {
        id: m
        property string text: ""
        property bool playing: false
        property real maxW: 300
        property color color: "white"
        property real pixelSize: 15
        property int stepPx: 1
        property bool scrollOn: true

        readonly property int gap: 20
        readonly property int interval: 33
        readonly property int holdMs: 2500

        readonly property real textW: measure.implicitWidth
        readonly property bool animating: scrollOn && playing && textW > maxW
        readonly property real titleW: Math.min(textW, maxW)

        property int scrollX: 0
        property bool hold: true

        implicitWidth: titleW
        implicitHeight: measure.implicitHeight

        Text {
            id: measure
            visible: false
            text: m.text
            font.family: root.fontFamily
            font.pixelSize: m.pixelSize
        }

        onAnimatingChanged: { scrollX = 0; hold = true }
        onTextChanged: { scrollX = 0; hold = true }
        onMaxWChanged: { scrollX = 0; hold = true }

        Timer {
            interval: m.holdMs
            repeat: false
            running: m.animating && m.hold
            onTriggered: m.hold = false
        }
        Timer {
            interval: m.interval
            repeat: true
            running: m.animating && !m.hold
            onTriggered: {
                m.scrollX -= m.stepPx
                if (m.scrollX <= -(m.textW + m.gap)) {
                    m.scrollX = 0
                    m.hold = true
                }
            }
        }

        Item {
            width: m.titleW
            height: parent.height
            clip: true

            Row {
                x: m.animating ? m.scrollX : 0
                spacing: m.gap
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: m.animating ? 2 : 1
                    delegate: Text {
                        required property int index
                        text: m.text
                        color: m.color
                        font.family: root.fontFamily
                        font.pixelSize: m.pixelSize
                        renderType: Text.NativeRendering
                        width: index === 0 ? (m.animating ? m.textW : m.titleW) : implicitWidth
                        elide: index === 0 && !m.animating ? Text.ElideRight : Text.ElideNone
                    }
                }
            }
        }
    }

    component SettingsCard: Item {
        id: card
        property Item view: null
        readonly property real u: root.settingsU

        x: root.settingsEffX
        y: root.settingsEffY
        Component.onDestruction: if (view) view.forceActiveFocus()
        width: root.settingsWinW
        height: root.settingsWinH

        // swallows clicks so they never reach the lock screen behind
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius * card.u
            color: Theme.bg
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.12)
        }

        // ---- header (drag handle) ----------------------------------------
        Item {
            id: head
            anchors.top: parent.top
            width: parent.width
            height: 52 * card.u

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
                    const p = headDrag.mapToItem(card.view, mouse.x, mouse.y)
                    pressX = p.x
                    pressY = p.y
                    startX = root.settingsEffX
                    startY = root.settingsEffY
                    root.settingsDragging = true
                }
                onPositionChanged: mouse => {
                    if (!root.settingsDragging) return
                    const p = headDrag.mapToItem(card.view, mouse.x, mouse.y)
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
                x: 20 * card.u; y: 8 * card.u
                text: "Lock screen settings"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeSection * card.u
                font.bold: true
                color: Theme.text
            }
            Text {
                x: 20 * card.u; y: 30 * card.u
                text: "Drag · Shift+scroll · Esc"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeSmall * card.u
                color: Theme.textDim
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16 * card.u
                y: 8 * card.u
                width: 26 * card.u; height: 26 * card.u
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "×"
                font.family: Theme.fontFamily
                font.pixelSize: 22 * card.u
                color: closeArea.containsMouse ? Theme.text : Theme.textDim
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeSettings()
                }
            }
        }

        // ---- scrolling content --------------------------------------------
        Flickable {
            id: flick
            anchors.top: head.bottom
            anchors.topMargin: 2 * card.u
            anchors.bottom: foot.top
            anchors.left: parent.left
            anchors.right: parent.right
            contentWidth: width
            contentHeight: contentCol.height + 12 * card.u
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                x: 20 * card.u
                width: flick.width - 48 * card.u

                // ---------------- GENERAL ----------------
                SecHeader { skey: "general"; label: "General" }
                Grid {
                    visible: !root.isCollapsed("general")
                    width: parent.width; columns: 2; columnSpacing: 18 * card.u
                    SliderRow { key: "fadeMs"; label: "Fade-in" }
                    SliderRow { key: "fadeOutMs"; label: "Fade-out" }
                    SliderRow { key: "blur"; label: "Blur"; enabled: root.cfg.useScreenshot }
                    SliderRow { key: "dim"; label: "Dim" }
                    ToggleRow { key: "useScreenshot"; label: "Image background" }
                    ToggleRow { key: "useWallpaper"; label: "Use wallpaper"; enabled: root.cfg.useScreenshot }
                    ToggleRow { key: "clock24"; label: "24-hour clock" }
                    ToggleRow { key: "clockSeconds"; label: "Seconds" }
                    ToggleRow { key: "clockVertical"; label: "Vertical clock" }
                    ToggleRow { key: "dateMonthFirst"; label: "Month first (date)" }
                    ToggleRow { key: "ampmLower"; label: "Lowercase am/pm"; enabled: !root.cfg.clock24 }
                    FontPickRow {}
                }

                // ---------------- ELEMENTS ----------------
                SecHeader { skey: "elements"; label: "Elements" }
                Grid {
                    visible: !root.isCollapsed("elements")
                    width: parent.width; columns: 2; columnSpacing: 18 * card.u
                    ToggleRow { key: "showTime"; label: "Time" }
                    ToggleRow { key: "showDate"; label: "Date" }
                    ToggleRow { key: "showLayout"; label: "Layout label" }
                    ToggleRow { key: "showCaps"; label: "Caps Lock hint" }
                    ToggleRow { key: "showMedia"; label: "Now playing" }
                    ToggleRow { key: "showControls"; label: "Media controls" }
                    ToggleRow { key: "showWeather"; label: "Weather" }
                    ToggleRow { key: "showWeatherCity"; label: "Weather city" }
                    ToggleRow { key: "showWeatherCond"; label: "Weather forecast" }
                }

                // ---------------- PROFILE ----------------
                SecHeader { skey: "profile"; label: "Profile" }
                Grid {
                    visible: !root.isCollapsed("profile")
                    width: parent.width; columns: 2; columnSpacing: 18 * card.u
                    ToggleRow { key: "showPfp"; label: "Profile picture" }
                    ToggleRow { key: "showUser"; label: "Name" }
                    SliderRow { key: "pfpSize"; label: "Picture size"; enabled: root.cfg.showPfp }
                    SliderRow { key: "pfpOpacity"; label: "Picture opacity"; enabled: root.cfg.showPfp }
                    SliderRow { key: "userSize"; label: "Name size"; enabled: root.cfg.showUser }
                    SliderRow { key: "userGap"; label: "Name spacing"; enabled: root.cfg.showUser && root.cfg.showPfp }
                    SliderRow { key: "pfpY"; label: "Position (min. from top)" }
                }
                Item {
                    visible: !root.isCollapsed("profile")
                    width: parent.width
                    height: 34 * card.u
                    opacity: root.cfg.showUser ? 1 : 0.4

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Name text"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSizeBody * card.u
                        color: Theme.text
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.55
                        height: 24 * card.u
                        radius: 6 * card.u
                        color: Theme.alpha(Theme.text, nameInput.activeFocus ? 0.1 : 0.05)
                        border.width: 1
                        border.color: nameInput.activeFocus ? Theme.accentSolid : Theme.alpha(Theme.text, 0.2)

                        TextInput {
                            id: nameInput
                            anchors.fill: parent
                            anchors.leftMargin: 8 * card.u
                            anchors.rightMargin: 8 * card.u
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            enabled: root.cfg.showUser
                            maximumLength: 40
                            selectByMouse: true
                            text: root.cfg.userText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSizeBody * card.u
                            color: Theme.text
                            selectionColor: Theme.accentSolid
                            onTextEdited: { root.setCfg("userText", text); saveTimer.restart() }
                            onAccepted: { nameInput.focus = false; if (card.view) card.view.forceActiveFocus() }
                            Keys.onEscapePressed: event => {
                                nameInput.focus = false
                                if (card.view) card.view.forceActiveFocus()
                                event.accepted = true
                            }
                        }
                        Text {
                            anchors.fill: nameInput
                            verticalAlignment: Text.AlignVCenter
                            visible: nameInput.text === "" && !nameInput.activeFocus
                            text: root.sysUser
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSizeBody * card.u
                            color: Theme.textDim
                            opacity: 0.6
                        }
                    }
                }

                // ---------------- HIDE UNTIL KEY ----------------
                SecHeader { skey: "idle"; label: "Hide until key press" }
                Grid {
                    visible: !root.isCollapsed("idle")
                    width: parent.width; columns: 2; columnSpacing: 18 * card.u
                    ToggleRow { key: "hideUntilKey"; label: "Enable" }
                    ToggleRow { key: "hideInput"; label: "Input field"; enabled: root.cfg.hideUntilKey }
                    ToggleRow { key: "hidePfp"; label: "Picture + name"; enabled: root.cfg.hideUntilKey }
                    ToggleRow { key: "hideLayout"; label: "Layout label"; enabled: root.cfg.hideUntilKey }
                    SliderRow { key: "idleHideSec"; label: "Hide after"; enabled: root.cfg.hideUntilKey }
                    SliderRow { key: "revealMs"; label: "Animation"; enabled: root.cfg.hideUntilKey }
                }

                // ---------------- INPUT FIELD ----------------
                SecHeader { skey: "field"; label: "Input field" }
                Grid {
                    visible: !root.isCollapsed("field")
                    width: parent.width; columns: 2; columnSpacing: 18 * card.u
                    SliderRow { key: "fieldWidth"; label: "Width" }
                    SliderRow { key: "fieldHeight"; label: "Height" }
                    SliderRow { key: "outlineWidth"; label: "Outline" }
                    SliderRow { key: "fieldRadius"; label: "Roundness" }
                    SliderRow { key: "dotSize"; label: "Dot size" }
                    SliderRow { key: "dotSpacing"; label: "Dot spacing" }
                    SliderRow { key: "fieldOffsetY"; label: "Vertical offset" }
                    ToggleRow { key: "fadeOnEmpty"; label: "Fade when empty" }
                    ToggleRow { key: "showFailText"; label: "Fail text" }
                    ToggleRow { key: "showSwitchUser"; label: "Switch user button" }
                }

                // ---------------- TEXT SIZES (folded) ----------------
                SecHeader { skey: "sizes"; label: "Text sizes" }
                Grid {
                    visible: !root.isCollapsed("sizes")
                    width: parent.width; columns: 2; columnSpacing: 18 * card.u
                    SliderRow { key: "timeSize"; label: "Time" }
                    SliderRow { key: "dateSize"; label: "Date" }
                    SliderRow { key: "layoutSize"; label: "Layout label" }
                    SliderRow { key: "mediaSize"; label: "Now playing" }
                    SliderRow { key: "controlSize"; label: "Media controls" }
                    SliderRow { key: "weatherSize"; label: "Weather" }
                }

                // ---------------- POSITIONS (folded) ----------------
                SecHeader { skey: "positions"; label: "Positions" }
                Grid {
                    visible: !root.isCollapsed("positions")
                    width: parent.width; columns: 2; columnSpacing: 18 * card.u
                    SliderRow { key: "timeY"; label: "Time (from top)" }
                    SliderRow { key: "dateY"; label: "Date (min. from top)" }
                    SliderRow { key: "layoutY"; label: "Layout (from mid)" }
                    SliderRow { key: "mediaY"; label: "Now playing" }
                    SliderRow { key: "controlsY"; label: "Controls" }
                    SliderRow { key: "mediaWidth"; label: "Marquee width" }
                    SliderRow { key: "controlSpacing"; label: "Control spacing" }
                    SliderRow { key: "weatherY"; label: "Weather (min. from top)" }
                    SliderRow { key: "stackGap"; label: "Spacing below clock" }
                    SliderRow { key: "ampmGap"; label: "AM/PM spacing" }
                }

                // ---------------- COLORS (folded) ----------------
                SecHeader { skey: "colors"; label: "Colors" }
                Grid {
                    visible: !root.isCollapsed("colors")
                    width: parent.width; columns: 1
                    ColorPickRow { key: "outlineColor"; label: "Outline" }
                    ColorPickRow { key: "checkColor"; label: "Checking" }
                    ColorPickRow { key: "failColor"; label: "Failed" }
                    ColorPickRow { key: "dotColor"; label: "Dots" }
                    ColorPickRow { key: "timeColor"; label: "Time" }
                    ColorPickRow { key: "dateColor"; label: "Date" }
                    ColorPickRow { key: "layoutColor"; label: "Layout label" }
                    ColorPickRow { key: "mediaColor"; label: "Now playing / controls" }
                    ColorPickRow { key: "weatherColor"; label: "Weather" }
                    ColorPickRow { key: "userColor"; label: "Name" }
                }
            }
        }

        // scroll indicator
        Rectangle {
            visible: flick.contentHeight > flick.height
            x: flick.x + flick.width - 14 * card.u
            y: flick.y + flick.visibleArea.yPosition * flick.height
            width: 4 * card.u
            height: Math.max(24 * card.u, flick.height * flick.visibleArea.heightRatio)
            radius: width / 2
            color: Theme.text
            opacity: flick.moving ? 0.7 : 0.3
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // ---- footer --------------------------------------------------------
        Item {
            id: foot
            anchors.bottom: parent.bottom
            width: parent.width
            height: 50 * card.u

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.text, 0.08)
            }

            Row {
                x: 20 * card.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * card.u

                ActionButton {
                    label: "Reset all"
                    enabled: root.modified
                    onClicked: root.resetAll()
                }
                ActionButton {
                    label: "Reset window"
                    enabled: root.settingsPosSet || root.settingsZoom !== 1.0
                    onClicked: root.resetSettingsWindow()
                }
            }

            ActionButton {
                anchors.right: parent.right
                anchors.rightMargin: 20 * card.u
                anchors.verticalCenter: parent.verticalCenter
                label: "Done"
                primary: true
                onClicked: root.closeSettings()
            }
        }

        // Shift + scroll = zoom the settings window; plain scroll falls through to the list
        MouseArea {
            anchors.fill: parent
            z: 100
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                if (wheel.modifiers & Qt.ShiftModifier) {
                    const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                    if (d !== 0) root.setSettingsZoom(root.settingsZoom + (d / 120) * root.zoomStep)
                    wheel.accepted = true
                } else {
                    wheel.accepted = false
                }
            }
        }
    }

    component LockView: Item {
        id: lv
        property string screenName: ""
        property bool preview: false

        readonly property real ui: height / 1080
        property real reveal: 0

        // reveal-on-key animation (1 = shown, 0 = hidden)
        property real uiP: root.uiShown ? 1 : 0
        Behavior on uiP { NumberAnimation { duration: root.cfg.revealMs; easing.type: Easing.Linear } }
        readonly property real pInput:  root.cfg.hideInput  ? uiP : 1
        readonly property real pPfp:    root.cfg.hidePfp    ? uiP : 1
        readonly property real pLayout: root.cfg.hideLayout ? uiP : 1

        focus: true
        Component.onCompleted: {
            reveal = 1
            lv.forceActiveFocus()
        }
        Keys.onPressed: event => root.handleKey(event, lv.preview)

        Item {
            id: content
            anchors.fill: parent
            opacity: root.unlocking ? 0 : lv.reveal
            Behavior on opacity {
                NumberAnimation {
                    duration: root.unlocking ? root.cfg.fadeOutMs : root.cfg.fadeMs
                    easing.type: Easing.Linear
                }
            }

            // ---- background: screenshot + blur + dim ---------------------
            Rectangle {
                anchors.fill: parent
                color: Theme.bgPanel
            }
            Image {
                id: bgImg
                anchors.fill: parent
                source: (root.cfg.useWallpaper && root.wallpaperSrc !== "")
                        ? root.fileUrl(root.wallpaperSrc)
                        : "file://" + root.shotPath(lv.screenName)
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: bgImg
                visible: root.cfg.useScreenshot && bgImg.status === Image.Ready
                autoPaddingEnabled: false
                blurEnabled: root.cfg.blur > 0
                blurMax: 48
                blur: root.cfg.blur / 100
            }
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.cfg.dim / 100
                visible: opacity > 0
            }
            // extra dim while the UI is revealed by a key press (only when "Hide until key press" is on)
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.cfg.hideUntilKey ? lv.uiP * 0.25 : 0
                visible: opacity > 0
            }

            // click handling: right-click = settings, left-click outside = close settings
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    lv.forceActiveFocus()
                    if (mouse.button === Qt.RightButton)
                        root.openSettings(lv.screenName, lv.width, lv.height)
                    else if (root.settingsOpen)
                        root.closeSettings()
                }
            }

            // ---- TIME ----------------------------------------------------
            Row {
                id: timeLbl
                visible: root.cfg.showTime
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.cfg.timeY * lv.ui
                spacing: root.cfg.ampmGap * lv.ui

                Text {
                    text: root.timeText(clock.date)
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: root.cfg.clockVertical ? 0.85 : 1.0
                    font.family: root.fontFamily
                    font.pixelSize: root.cfg.timeSize * lv.ui
                    color: root.colorOf("timeColor")
                }
                Text {
                    visible: !root.cfg.clock24 && !root.cfg.clockVertical
                    text: root.ampmText(clock.date)
                    font.family: root.fontFamily
                    font.pixelSize: root.cfg.timeSize * lv.ui
                    color: root.colorOf("timeColor")
                }
            }

            // ---- DATE ----------------------------------------------------
            Text {
                id: dateLbl
                visible: root.cfg.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                // the Y slider is the minimum: the date moves down when the clock grows (vertical layout)
                y: Math.max(root.cfg.dateY * lv.ui,
                            root.cfg.showTime ? timeLbl.y + timeLbl.height + root.cfg.stackGap * lv.ui : 0)
                text: Qt.formatDateTime(clock.date, root.cfg.dateMonthFirst
                                                    ? "dddd, MMMM dd, yyyy"
                                                    : "dddd, dd MMMM yyyy")
                font.family: root.fontFamily
                font.pixelSize: root.cfg.dateSize * lv.ui
                color: root.colorOf("dateColor")
            }

            // ---- WEATHER -------------------------------------------------
            Row {
                id: wxRow
                visible: root.cfg.showWeather && root.wxOk
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real above: root.cfg.showDate ? dateLbl.y + dateLbl.height
                                            : root.cfg.showTime ? timeLbl.y + timeLbl.height : 0
                y: Math.max(root.cfg.weatherY * lv.ui, above + root.cfg.stackGap * lv.ui)
                spacing: root.cfg.weatherSize * 0.4 * lv.ui

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wxGlyph(root.wxCode, root.wxDay)
                    font.family: root.iconFont
                    font.pixelSize: root.cfg.weatherSize * 1.3 * lv.ui
                    color: root.colorOf("weatherColor")
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wxLine
                    font.family: root.fontFamily
                    font.pixelSize: root.cfg.weatherSize * lv.ui
                    color: root.colorOf("weatherColor")
                }
            }

            // ---- PROFILE PICTURE + NAME ----------------------------------
            // sits under the weather (or the date / clock if those are hidden)
            Column {
                id: userCol
                visible: root.cfg.showPfp || (root.cfg.showUser && root.userDisplay !== "")
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real above: wxRow.visible ? wxRow.y + wxRow.height
                                            : root.cfg.showDate ? dateLbl.y + dateLbl.height
                                            : root.cfg.showTime ? timeLbl.y + timeLbl.height : 0
                y: Math.max(root.cfg.pfpY * lv.ui, above + root.cfg.stackGap * lv.ui)
                spacing: root.cfg.userGap * lv.ui
                opacity: lv.pPfp

                Item {
                    id: pfpBox
                    visible: root.cfg.showPfp
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.cfg.pfpSize * lv.ui
                    height: width

                    AnimatedImage {
                        id: pfpImg
                        anchors.fill: parent
                        property bool useDefault: false
                        source: root.ownUser
                                ? "file://" + (useDefault ? root.pfpDefault : root.pfpCustom)
                                : ""
                        sourceSize: Qt.size(512, 512)
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        cache: false
                        playing: true
                        visible: false          // drawn through the circular mask below
                        // no custom picture (or unreadable) -> default one
                        onStatusChanged: if (status === Image.Error) useDefault = true
                    }
                    Item {
                        id: pfpMask
                        anchors.fill: pfpImg
                        layer.enabled: true
                        visible: false
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                        }
                    }
                    MultiEffect {
                        anchors.fill: pfpImg
                        source: pfpImg
                        maskEnabled: true
                        maskSource: pfpMask
                        visible: root.ownUser
                        opacity: root.cfg.pfpOpacity / 100
                    }

                    // placeholder for users without a picture: circle outline
                    Rectangle {
                        anchors.fill: parent
                        visible: !root.ownUser
                        radius: width / 2
                        color: "transparent"
                        border.width: Math.max(2, Math.round(3 * lv.ui))
                        border.color: root.colorOf("userColor")
                        opacity: root.cfg.pfpOpacity / 100
                    }
                }

                Text {
                    visible: root.cfg.showUser && root.userDisplay !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.userDisplay
                    font.family: root.fontFamily
                    font.pixelSize: root.cfg.userSize * lv.ui
                    color: root.colorOf("userColor")
                }
            }

            // ---- INPUT FIELD --------------------------------------------
            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + root.cfg.fieldOffsetY * lv.ui - height / 2
                width: parent.width * root.cfg.fieldWidth / 100
                height: parent.height * root.cfg.fieldHeight / 100
                radius: root.cfg.fieldRadius * lv.ui
                color: "transparent"
                border.width: Math.round(root.cfg.outlineWidth * lv.ui)
                border.color: root.checking ? root.colorOf("checkColor")
                            : root.failed   ? root.colorOf("failColor")
                            :                 root.colorOf("outlineColor")
                Behavior on border.color { ColorAnimation { duration: 120 } }

                // "fade when empty" animates on its own; the reveal fade multiplies with it
                property real emptyFade: (root.cfg.fadeOnEmpty && root.buffer === "" && !root.failed && !root.checking) ? 0 : 1
                Behavior on emptyFade { NumberAnimation { duration: 150 } }
                opacity: emptyFade * lv.pInput

                readonly property real dotPx: height * root.cfg.dotSize / 100
                readonly property real dotGap: dotPx * root.cfg.dotSpacing / 100
                readonly property int maxDots: Math.max(1, Math.floor(
                    (width - 2 * radius) / Math.max(1, dotPx + dotGap)))
                readonly property int dotCount: Math.min(root.buffer.length, maxDots)

                Row {
                    anchors.centerIn: parent
                    spacing: field.dotGap
                    visible: !root.failed || !root.cfg.showFailText

                    Repeater {
                        model: field.dotCount
                        delegate: Rectangle {
                            required property int index
                            width: field.dotPx
                            height: field.dotPx
                            radius: width / 2
                            color: root.colorOf("dotColor")
                            scale: 0
                            Component.onCompleted: scale = 1
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.Linear } }
                        }
                    }
                }

                // fail text replaces the dots, like $PAMFAIL in hyprlock
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 2 * parent.radius
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: root.failed && root.cfg.showFailText
                    text: root.failText
                    font.family: root.fontFamily
                    font.pixelSize: 14 * lv.ui
                    color: root.colorOf("failColor")
                }

                // switch user: minimal arrow, right-aligned, no background
                Item {
                    id: switchBtn
                    visible: root.cfg.showSwitchUser && !root.unlocking
                    anchors.right: parent.right
                    anchors.rightMargin: Math.max(8 * lv.ui, field.radius * 0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: field.height * 0.6
                    height: width

                    Text {
                        anchors.centerIn: parent
                        text: ">"
                        font.family: root.fontFamily
                        font.pixelSize: switchBtn.height * 0.6
                        color: root.colorOf("dotColor")
                        opacity: switchArea.containsMouse ? 1.0 : 0.5
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: switchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: field.opacity > 0.5      // not clickable while faded out
                        onClicked: root.cycleUser()
                    }
                }
            }

            // ---- KEYBOARD LAYOUT (click = next layout) -------------------
            Text {
                visible: root.cfg.showLayout
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + root.cfg.layoutY * lv.ui - height / 2
                readonly property string raw: root.layoutName
                text: root.layoutShort[raw] ?? (raw !== "" ? raw.slice(0, 2).toLowerCase() : "")
                font.family: root.fontFamily
                font.pixelSize: root.cfg.layoutSize * lv.ui
                color: root.colorOf("layoutColor")
                opacity: (layoutArea.containsMouse ? 1.0 : 0.8) * lv.pLayout

                MouseArea {
                    id: layoutArea
                    anchors.fill: parent
                    anchors.margins: -8 * lv.ui
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: lv.pLayout > 0.5
                    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + (root.cfg.fieldOffsetY + 100) * lv.ui
                visible: root.cfg.showCaps && root.capsLock
                text: "Caps Lock"
                font.family: root.fontFamily
                font.pixelSize: 12 * lv.ui
                color: root.colorOf("failColor")
            }

            // ---- NOW PLAYING (the bar's marquee) -------------------------
            LockMarquee {
                visible: root.cfg.showMedia && root.player !== null && root.nowPlaying !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + root.cfg.mediaY * lv.ui - height / 2
                text: root.nowPlaying
                playing: root.playing
                maxW: lv.width * root.cfg.mediaWidth / 100
                color: root.colorOf("mediaColor")
                pixelSize: root.cfg.mediaSize * lv.ui
                stepPx: Math.max(1, Math.round(lv.ui))
            }

            // ---- MEDIA CONTROLS ------------------------------------------
            Row {
                visible: root.cfg.showControls && root.player !== null
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + root.cfg.controlsY * lv.ui - height / 2
                spacing: Math.max(0, root.cfg.controlSpacing - 28) * lv.ui

                Repeater {
                    model: ["previous", "toggle", "next"]
                    delegate: Item {
                        id: btn
                        required property string modelData
                        width: 28 * lv.ui
                        height: 28 * lv.ui

                        Text {
                            anchors.centerIn: parent
                            font.family: root.iconFont
                            font.pixelSize: root.cfg.controlSize * lv.ui
                            color: root.colorOf("mediaColor")
                            opacity: btnArea.containsMouse ? 1.0 : 0.8
                            // nf-md: skip_previous / pause / play / skip_next
                            text: btn.modelData === "previous" ? "\udb81\udcae"
                                : btn.modelData === "next"     ? "\udb81\udcad"
                                : (root.playing ? "\udb80\udfe4" : "\udb81\udc0a")
                        }
                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mediaAct(btn.modelData)
                        }
                    }
                }
            }

            // preview-only hint
            Text {
                visible: lv.preview && !root.settingsOpen
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24 * lv.ui
                text: "Preview · right-click: settings · Enter: fake attempt · Esc: close"
                font.family: Theme.fontFamily
                font.pixelSize: 12 * lv.ui
                color: Theme.textDim
            }

            // ---- settings window (only on the screen it was opened on) ---
            // no anchors.fill: a sized Loader would resize the card to the full screen
            Loader {
                id: cardLoader
                active: root.settingsOpen && root.settingsScreenName === lv.screenName
                sourceComponent: SettingsCard {}
                onLoaded: item.view = lv
            }
        }
    }

    // ======================================================================
    // windows
    // ======================================================================
    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: surf
            color: "black"

            LockView {
                anchors.fill: parent
                screenName: surf.screen ? surf.screen.name : ""
                preview: false
            }
        }
    }

    // non-locking preview, so the look can be tweaked without locking the session
    LazyLoader {
        active: root.previewing

        PanelWindow {
            id: pw
            screen: root.previewScreen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockView {
                anchors.fill: parent
                screenName: pw.screen ? pw.screen.name : ""
                preview: true
            }
        }
    }
}