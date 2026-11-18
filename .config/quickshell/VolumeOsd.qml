import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Scope {
    id: root

    // ---- window lifecycle ------------------------------------------------
    property bool mounted: false
    property real winW: 0; property real winH: 0
    // Card heights, reported by the OSD window (used to keep the cards apart while settings are open).
    property var cardH: ({ media: 100, vol: 28, bright: 28 })

    // Must be longer than the fade-out (OsdCard opacity/scale = fadeMs).
    Timer {
        id: unmountTimer
        interval: root.fadeMs + 100
        onTriggered: { root.mounted = false; root.winW = 0; root.winH = 0; root.hovered = false; root.hoverTip = "" }
    }

    // ---- constants / specs -----------------------------------------------
    readonly property int topGap: 30
    readonly property int keepVisible: 40
    readonly property int toolsHeight: 28

    readonly property var numSpec: ({
        mediaScale:    { min: 20,  max: 200,   def: 70,   step: 2,   unit: "%" },
        volScale:      { min: 20,  max: 200,   def: 80,   step: 5,   unit: "%" },
        mediaWidth:    { min: 200, max: 1000,  def: 420,  step: 10,  unit: "px" },
        portraitWidth: { min: 120, max: 700,   def: 260,  step: 10,  unit: "px" },
        flyoutWidth:   { min: 120, max: 800,   def: 320,  step: 10,  unit: "px" },
        artSize:       { min: 16,  max: 200,   def: 52,   step: 4,   unit: "px" },
        cardRadius:    { min: 0,   max: 80,    def: 24,   step: 2,   unit: "px" },
        barCount:      { min: 2,   max: 128,   def: 24,   step: 2,   unit: "" },
        barRadius:     { min: 0,   max: 40,    def: 40,   step: 2,   unit: "px", full: true },
        barSpacing:    { min: 0,   max: 30,    def: 3,    step: 1,   unit: "px" },
        barHeight:     { min: 4,   max: 400,   def: 20,   step: 2,   unit: "px" },
        barFps:        { min: 5,   max: 144,   def: 30,   step: 5,   unit: " fps" },
        barSensitivity:{ min: 20,  max: 300,   def: 100,  step: 10,  unit: "%" },
        mediaTimeout:  { min: 250, max: 60000, def: 3000, step: 250, unit: "s" },
        volTimeout:    { min: 100, max: 30000, def: 1200, step: 100, unit: "s" },
        flyoutHeight:  { min: 20,  max: 60,    def: 28,   step: 2,   unit: "px" },
        flyoutRadius:  { min: 0,   max: 40,    def: 40,   step: 2,   unit: "px", full: true },
        flyoutIconSize:{ min: 10,  max: 40,    def: 20,   step: 1,   unit: "px" },
        flyoutTextSize:{ min: 8,   max: 24,    def: 12,   step: 1,   unit: "px" },
        flyoutTrack:   { min: 2,   max: 16,    def: 5,    step: 1,   unit: "px" },
        flyoutPad:     { min: 4,   max: 40,    def: 20,   step: 2,   unit: "px" },
        fadeMs:        { min: 0,   max: 1500,  def: 150,  step: 25,  unit: " ms" },
        bgOpacity:     { min: 0,   max: 100,   def: Math.max(10, Math.round((Theme.bg.a ?? 1) * 20) * 5),     step: 5, unit: "%" },
        flyoutBgOpacity: { min: 0,   max: 100,   def: Math.max(10, Math.round((Theme.bg.a ?? 1) * 20) * 5),     step: 5, unit: "%" },
        artOpacity:    { min: 0,   max: 100,   def: Math.max(20, Math.round((Theme.bgAlpha ?? 1) * 20) * 5), step: 5, unit: "%" },
        barOpacity:    { min: 0,   max: 100,   def: 90,   step: 5,   unit: "%" },
        barDimOpacity: { min: 0,   max: 100,   def: 30,   step: 5,   unit: "%" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        volOsd: true, mediaOsd: true, brightOsd: true,
        flyoutIcon: true, flyoutPercent: true, flyoutAccent: false, flyoutBorder: false,
        showTips: true, showTitle: true, showArtist: true, showBar: true, showVisualizer: true,
        trackChangeOsd: true, showArt: true, showControls: true, musicOnly: true, artistBelow: false,
        portrait: true, showBorder: false, accentBars: false
    })
    readonly property var boolKeys: Object.keys(boolDefaults)
    readonly property var posKeys: ["offsetX", "offsetY", "volOffsetX", "volOffsetY", "brightOffsetX", "brightOffsetY"]

    property real offsetX: 0; property real offsetY: 0; property real volOffsetX: 0; property real volOffsetY: 0
    property real brightOffsetX: 0; property real brightOffsetY: 0

    // Settings window: remembered position (offset from screen centre) and zoom (%).
    // Saved in the same state file, but deliberately NOT part of "Reset all" /
    // `modified` (they belong to the menu itself, not the OSD). Double-click the
    // settings header / footer to reset them.
    readonly property var winKeys: ["setOffsetX", "setOffsetY", "settingsZoom"]
    readonly property real zoomMin: 50
    readonly property real zoomMax: 200
    property real setOffsetX: 0; property real setOffsetY: 0
    property real settingsZoom: 100

    // Every key in numSpec needs a matching property here (mediaWidth was
    // missing, which collapsed the landscape card).
    property int mediaScale: numSpec.mediaScale.def; property int volScale: numSpec.volScale.def
    property int mediaWidth: numSpec.mediaWidth.def
    property int portraitWidth: numSpec.portraitWidth.def; property int flyoutWidth: numSpec.flyoutWidth.def
    property int artSize: numSpec.artSize.def; property int cardRadius: numSpec.cardRadius.def
    property int barCount: numSpec.barCount.def; property int barRadius: numSpec.barRadius.def
    property int barSpacing: numSpec.barSpacing.def; property int barHeight: numSpec.barHeight.def
    property int barFps: numSpec.barFps.def; property int barSensitivity: numSpec.barSensitivity.def
    property int mediaTimeout: numSpec.mediaTimeout.def
    property int volTimeout: numSpec.volTimeout.def; property int fadeMs: numSpec.fadeMs.def
    property int bgOpacity: numSpec.bgOpacity.def
    property int flyoutBgOpacity: numSpec.flyoutBgOpacity.def
    property int flyoutHeight: numSpec.flyoutHeight.def; property int flyoutRadius: numSpec.flyoutRadius.def
    property int flyoutIconSize: numSpec.flyoutIconSize.def; property int flyoutTextSize: numSpec.flyoutTextSize.def
    property int flyoutTrack: numSpec.flyoutTrack.def; property int flyoutPad: numSpec.flyoutPad.def
    property bool flyoutIcon: boolDefaults.flyoutIcon; property bool flyoutPercent: boolDefaults.flyoutPercent
    property bool flyoutAccent: boolDefaults.flyoutAccent; property bool flyoutBorder: boolDefaults.flyoutBorder
    property int artOpacity: numSpec.artOpacity.def; property int barOpacity: numSpec.barOpacity.def
    property int barDimOpacity: numSpec.barDimOpacity.def

    property bool volOsd: boolDefaults.volOsd; property bool mediaOsd: boolDefaults.mediaOsd
    property bool brightOsd: boolDefaults.brightOsd
    property bool showTips: boolDefaults.showTips; property bool showTitle: boolDefaults.showTitle
    property bool showArtist: boolDefaults.showArtist; property bool showBar: boolDefaults.showBar
    property bool showVisualizer: boolDefaults.showVisualizer; property bool trackChangeOsd: boolDefaults.trackChangeOsd
    property bool showArt: boolDefaults.showArt; property bool showControls: boolDefaults.showControls
    property bool musicOnly: boolDefaults.musicOnly; property bool artistBelow: boolDefaults.artistBelow
    property bool portrait: boolDefaults.portrait; property bool showBorder: boolDefaults.showBorder
    property bool accentBars: boolDefaults.accentBars

    readonly property real scaleFactor: scaleOf(curKind)
    readonly property color cardColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bgOpacity / 100)
    readonly property real curX: offX(curKind)
    readonly property real curY: offY(curKind)
    readonly property bool mediaMoved: offsetX !== 0 || offsetY !== 0
    readonly property bool volMoved: volOffsetX !== 0 || volOffsetY !== 0
    readonly property bool brightMoved: brightOffsetX !== 0 || brightOffsetY !== 0

    // ---- the three cards: "media", "vol", "bright" ----------------------------
    // mode     : which card the OSD is showing right now (normal operation)
    // focusKind: while the settings are open ALL cards are shown; this is the one
    //            that owns the hint / pin bar (last hovered or dragged card)
    // curKind  : the card that scaleFactor / curX / curY / tools bar refer to
    property string focusKind: "media"
    readonly property string mode: showMedia ? "media" : showBright ? "bright" : "vol"
    readonly property string curKind: settingsOpen ? focusKind : mode

    function offX(k) { return k === "media" ? offsetX : k === "bright" ? brightOffsetX : volOffsetX }
    function offY(k) { return k === "media" ? offsetY : k === "bright" ? brightOffsetY : volOffsetY }
    function setOff(k, x, y) {
        if (k === "media") { offsetX = x; offsetY = y }
        else if (k === "bright") { brightOffsetX = x; brightOffsetY = y }
        else { volOffsetX = x; volOffsetY = y }
    }
    function scaleOf(k) { return (k === "media" ? mediaScale : volScale) / 100 }   // volume + brightness share one scale
    function cardW(k) { return k === "media" ? (portrait ? portraitWidth : mediaWidth) : flyoutWidth }
    function cardHt(k) { return cardH[k] ?? 28 }

    // While the settings are open the cards are previewed together. Cards whose
    // saved positions would overlap are pushed down (preview only, nothing is saved
    // until you drag one). Each card reserves room for its hint bar underneath.
    function computeShift() {
        var out = { media: 0, vol: 0, bright: 0 }
        var order = ["media", "vol", "bright"]
        var gap = 6
        for (var i = 1; i < order.length; i++) {
            var k = order[i], s = scaleOf(k)
            var x0 = offX(k) - cardW(k) * s / 2, x1 = offX(k) + cardW(k) * s / 2
            var y = offY(k)
            for (var pass = 0; pass < order.length; pass++) {
                var moved = false
                for (var j = 0; j < i; j++) {
                    var o = order[j], so = scaleOf(o)
                    var ox0 = offX(o) - cardW(o) * so / 2, ox1 = offX(o) + cardW(o) * so / 2
                    if (x1 <= ox0 || x0 >= ox1) continue
                    var oy0 = offY(o) + out[o]
                    var oy1 = oy0 + (cardHt(o) + toolsHeight) * so + gap
                    if (y < oy1 && y + cardHt(k) * s > oy0) { y = oy1; moved = true }
                }
                if (!moved) break
            }
            out[k] = y - offY(k)
        }
        return out
    }

    readonly property var noShift: ({ media: 0, vol: 0, bright: 0 })
    property var frozenShift: ({ media: 0, vol: 0, bright: 0 })
    readonly property var previewShift: !settingsOpen ? noShift : dragging ? frozenShift : computeShift()

    // Called when a drag starts: the card's preview shift is baked into its saved
    // offset so it does not jump, and the shifts are frozen until the drag ends.
    function beginDrag(k) {
        focusKind = k
        if (settingsOpen) {
            var sh = previewShift
            var f = { media: sh.media, vol: sh.vol, bright: sh.bright }
            setOff(k, offX(k), offY(k) + f[k])
            f[k] = 0
            frozenShift = f
        }
        dragging = true
    }
    readonly property bool modified: posKeys.some(k => root[k] !== 0)
        || numKeys.some(k => root[k] !== numSpec[k].def)
        || boolKeys.some(k => root[k] !== boolDefaults[k])
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/mediaosd-state.json"

    // ---- settings menu look / scale -----------------------------------------
    // The settings controls (ActionButton, SectionHeader, ToggleRow, SliderRow)
    // live in CustomizationSettings.qml, shared by all menus. They read from
    // this Scope (the "host"): menuUi, th, cAccent, numSpec and the helper
    // functions below (cellW, focusStep, ensureVisible, fmtValue, setNumber,
    // toggleSetting, saveState).
    //
    // Scale system (same as the wallpaper picker's menu):
    //   ui            : screen height / 1080 (resolution independence)
    //   settingsScale : Theme.settingsScale (user's "settings scale" from hub.json)
    //   settingsZoom  : Shift+scroll zoom of the settings window (percent)
    //   menuUi        : ui * settingsScale * zoom, multiplies every size in the settings menu.
    // menuUi is kept up to date by a Binding inside the settings window (it knows its screen).
    // Everything falls back to the picker's defaults if Theme doesn't define it.
    readonly property real settingsScale: Theme.settingsScale ?? 1
    property real menuUi: settingsScale
    readonly property color cAccent: Theme.accent

    readonly property QtObject th: QtObject {
        readonly property string fontFamily: Theme.fontFamily ?? "JetBrains Mono"
        readonly property int radius: Theme.radius ?? 20
        readonly property int animFast: Theme.animFast ?? 120
        readonly property int animMed: Theme.animMed ?? 220
        readonly property int textSizeSection: Theme.textSizeSection ?? 15
        readonly property int textSizeGroup: Theme.textSizeGroup ?? 12
        readonly property int textSizeBody: Theme.textSizeBody ?? 11
        readonly property int textSizeSmall: Theme.textSizeSmall ?? 10
    }

    // ---- player detection --------------------------------------------------
    readonly property var musicPlayers: [
        "spotify", "spotifyd", "spotify_player", "spotify-launcher", "mpd", "mopidy", "cmus",
        "rhythmbox", "strawberry", "amberol", "lollypop", "deadbeef", "audacious",
        "quodlibet", "clementine", "elisa", "youtube-music", "ncspot"
    ]
    readonly property var browserPlayers: [
        "firefox", "librewolf", "zen", "chromium", "chrome", "google-chrome", "brave",
        "vivaldi", "opera", "edge", "microsoft-edge", "plasma-browser-integration"
    ]
    readonly property var musicSites: [
        "music.youtube.com", "open.spotify.com", "soundcloud.com", "bandcamp.com",
        "music.apple.com", "tidal.com", "deezer.com", "music.amazon.", "pandora.com",
        "qobuz.com", "listen.tidal.com", "radio.", "last.fm"
    ]
    readonly property string playerFormat:
        "{{playerName}}\t{{status}}\t{{title}}\t{{artist}}\t{{album}}\t{{position}}\t{{mpris:length}}\t{{mpris:artUrl}}\t{{xesam:url}}"

    function isMusic(p) {
        var name = p.player.split(".")[0].toLowerCase()
        if (musicPlayers.indexOf(name) >= 0) return true
        if (browserPlayers.indexOf(name) < 0) return false
        if (p.album !== "") return true
        var u = p.url.toLowerCase()
        return musicSites.some(s => u.indexOf(s) >= 0)
    }

    function parsePlayer(line) {
        if (!line) return null
        var f = line.split("\t")
        if (f.length < 3) return null
        while (f.length < 9) f.push("")
        var p = { player: f[0], status: f[1], title: f[2], artist: f[3], album: f[4],
                  position: parseFloat(f[5]) || 0, length: parseFloat(f[6]) || 0, art: f[7], url: f[8] }
        p.music = isMusic(p)
        return p
    }

    function mediaCmd(cmd) {
        var c = ["playerctl"]
        if (player !== "") c.push("--player=" + player)
        c.push(cmd)
        Quickshell.execDetached(c)
        hideTimer.restart()
    }

    property string title: ""; property string artist: ""; property string status: "Stopped"
    property string artUrl: ""; property string player: ""
    property real position: 0; property real length: 0

    readonly property bool playing: status === "Playing"
    readonly property real progress: length > 0 ? Math.min(position / length, 1) : 0

    function applyPlayer(p, withTiming) {
        player = p.player; status = p.status; title = p.title; artist = p.artist; artUrl = p.art
        if (withTiming) { position = p.position; length = p.length }
    }

    function clearPlayer() {
        status = "Stopped"; title = ""; artist = ""; artUrl = ""; player = ""; position = 0; length = 0
    }

    function pickPlayer(text) {
        var pool = text.trim().split("\n").map(parsePlayer).filter(p => p && (!musicOnly || p.music))
        return pool.find(p => p.status === "Playing") ?? pool[0] ?? null
    }

    function updateMedia() {
        if (!mediaProcess.running) mediaProcess.running = true
    }

    // ---- volume watching ---------------------------------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.triggerOsd() }
        function onMutedChanged() { root.triggerOsd() }
    }

    // ---- scroll to change volume (same behaviour as the bar) ---------------
    // Step / max come from the bar's settings file so both stay in sync.
    property int volStep: 2
    property int volMax: 100
    property int brightStep: 5
    property real wheelAcc: 0

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var j = JSON.parse(text())
                if (typeof j.volStep === "number") root.volStep = j.volStep
                if (typeof j.volMax === "number") root.volMax = j.volMax
                if (typeof j.brightStep === "number") root.brightStep = j.brightStep
            } catch (e) {}
        }
    }

    function scrollVolume(delta) {
        if (!sink || !sink.audio) return

        // accumulate so smooth-scroll devices still give exactly one step per notch
        wheelAcc += delta
        if (Math.abs(wheelAcc) < 120) return
        var dir = wheelAcc > 0 ? 1 : -1
        wheelAcc = 0
        var step = Math.max(1, volStep)
        var cur = Math.round(sink.audio.volume * 100)
        // snap to the step grid (0, 3, 6, 9 ...)
        var next = dir > 0 ? (Math.floor(cur / step) + 1) * step
                           : (Math.ceil(cur / step) - 1) * step
        next = Math.max(0, Math.min(volMax, next))
        if (dir > 0 && sink.audio.muted) sink.audio.muted = false
        sink.audio.volume = next / 100
    }

    // ---- brightness watching ------------------------------------------------
    // Same source as the bar (brightnessctl). brightnessctl is asked once for the
    // backlight device; after that the device's sysfs "brightness" file is polled
    // (sysfs has no inotify events), so keyboard keys, the bar scroll and
    // `brightnessctl set` from anywhere all show the OSD.
    property real brightness: -1          // 0..1, -1 = no backlight
    property string brightDevPath: ""
    property real brightMaxRaw: 0
    property real brightAcc: 0
    readonly property bool hasBacklight: brightness >= 0
    readonly property int brightPct: Math.round(Math.max(0, brightness) * 100)

    Process {
        command: ["brightnessctl", "-m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n").filter(l => l !== "")
                var line = lines.find(l => l.split(",")[1] === "backlight") ?? lines[0]
                if (!line) return
                var f = line.split(",")
                var cur = parseInt(f[2]), max = parseInt(f[4])
                if (f.length < 5 || isNaN(cur) || isNaN(max) || max <= 0) return
                root.brightMaxRaw = max
                root.brightness = cur / max
                root.brightDevPath = "/sys/class/" + f[1] + "/" + f[0]
            }
        }
    }

    FileView {
        id: brightFile
        path: root.brightDevPath !== "" ? root.brightDevPath + "/brightness" : ""
        printErrors: false

        onLoaded: {
            var raw = parseInt(brightFile.text())
            if (!isNaN(raw) && root.brightMaxRaw > 0) root.applyBrightness(raw / root.brightMaxRaw)
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.brightDevPath !== "" && (root.brightOsd || root.settingsOpen)
        onTriggered: brightFile.reload()
    }

    function applyBrightness(v) {
        var changed = brightness >= 0 && Math.round(v * 100) !== Math.round(brightness * 100)
        brightness = v
        if (changed) triggerBrightOsd()
    }

    function scrollBrightness(delta) {
        if (!hasBacklight) return
        brightAcc += delta
        if (Math.abs(brightAcc) < 120) return
        var dir = brightAcc > 0 ? 1 : -1
        brightAcc = 0
        var step = Math.max(1, brightStep)
        var cur = Math.round(brightness * 100)
        var next = dir > 0 ? (Math.floor(cur / step) + 1) * step
                           : (Math.ceil(cur / step) - 1) * step
        next = Math.max(1, Math.min(100, next))
        brightness = next / 100
        Quickshell.execDetached(["brightnessctl", "set", next + "%"])
        hideTimer.restart()
    }

    // scrolling on a card: brightness card -> brightness, everything else -> volume
    function scrollFor(kind, delta) {
        if (kind === "bright") scrollBrightness(delta)
        else scrollVolume(delta)
    }

    // ---- OSD state ---------------------------------------------------------
    property bool ready: false; property bool showing: false; property bool showMedia: false
    property bool showBright: false
    property bool pendingShow: false; property bool settingsOpen: false; property bool dragging: false
    property bool pinned: false
    property bool hovered: false     // driven by a Binding inside the OSD window
    property string hoverTip: ""     // tooltip text of the control under the pointer

    Timer { interval: 2000; running: true; onTriggered: root.ready = true }

    Timer {
        id: hideTimer
        interval: root.showMedia ? root.mediaTimeout : root.volTimeout   // volume + brightness share one timeout
        onTriggered: {
            if (root.hovered || root.settingsOpen || root.dragging || (root.showMedia && root.pinned))
                hideTimer.restart()
            else
                root.showing = false
        }
    }

    // Volume change: shows the media card instead if a player is playing (and the
    // media OSD is on), otherwise the volume card (if the volume OSD is on).
    function triggerOsd() {
        if (!ready || settingsOpen) return
        if (showing && !showBright) { hideTimer.restart(); return }
        if (!volOsd && !mediaOsd) return
        pendingShow = true
        updateMedia()
    }

    function triggerBrightOsd() {
        if (!ready || !brightOsd || settingsOpen) return
        if (showing && showBright) { hideTimer.restart(); return }
        pendingShow = false; showMedia = false; showBright = true; showing = true
        hideTimer.restart()
    }

    function showMediaOsd() {
        pendingShow = false; showBright = false; showMedia = true; showing = true
        hideTimer.restart()
        updateMedia()
    }

    function triggerMediaOsd() { if (ready && mediaOsd) showMediaOsd() }

    // Settings show ALL cards at once (the ones that are switched off are dimmed).
    function openSettings() {
        pendingShow = false; settingsOpen = true; showBright = false; showMedia = true; showing = true
        focusKind = "media"
        hideTimer.restart()
    }

    function closeSettings() {
        settingsOpen = false; dragging = false
        if (!mediaOsd) showing = false      // the media card was only up for the preview
        else hideTimer.restart()
    }
    function toggleSettings() { settingsOpen ? closeSettings() : openSettings() }
    function togglePinned() { pinned = !pinned; hideTimer.restart() }
    function closeAll() { settingsOpen = false; dragging = false; showing = false }

    function finishPendingShow() {
        if (!pendingShow) return
        pendingShow = false
        var m = playing && mediaOsd
        if (!m && !volOsd) return
        showBright = false; showMedia = m; showing = true
        hideTimer.restart()
    }

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            showMedia = false; showBright = false; settingsOpen = false; dragging = false; pinned = false; hoverTip = ""
            unmountTimer.restart()
        }
    }

    onShowMediaChanged: { if (showMedia) updateMedia(); else bars = [] }

    IpcHandler {
        target: "mediaosd"
        function media(): void { root.triggerMediaOsd() }
        function brightness(): void { root.triggerBrightOsd() }
        function settings(): void { root.openSettings() }
        function hide(): void { root.closeAll() }
    }

    // ---- settings helpers (also the host API used by CustomizationSettings) --
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Math.round(v))) }

    // width of one cell when `p` is a multi-column Grid, else the full width
    function cellW(p) {
        if (!p) return 0
        if (p.columns !== undefined && p.columns > 1 && p.columnSpacing !== undefined)
            return Math.floor((p.width - (p.columns - 1) * p.columnSpacing) / p.columns)
        return p.width
    }

    function fmtValue(key, v) {
        var s = numSpec[key]
        if (s.unit === "s") return (v / 1000).toFixed(1) + "s"
        if (s.full && v >= s.max) return "full"
        return v + s.unit
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

    // Only called while dragging; saved offsets are never rewritten by window resizes.
    function setPosition(kind, x, y) {
        var nx = x, ny = y
        var hw = cardW(kind) * scaleOf(kind)
        if (winW > 0 && winH > 0) {
            var minY = -topGap
            nx = Math.max(keepVisible - winW / 2 - hw / 2, Math.min(winW / 2 - keepVisible + hw / 2, x))
            ny = Math.max(minY, Math.min(Math.max(minY, winH - keepVisible - topGap), y))
        }
        setOff(kind, nx, ny)
    }

    function resetPos(kind) {
        setOff(kind, 0, 0)
        saveState()
    }

    // ---- settings window position / zoom -------------------------------------
    // The panel sits at screen centre + (setOffsetX, setOffsetY). sw/sh = screen
    // (window) size, pw/ph = panel size. The header row always stays on screen
    // and at least `keepVisible` px of the panel stay reachable on every side.
    function setSettingsPosition(x, y, sw, sh, pw, ph) {
        if (sw <= 0 || sh <= 0 || pw <= 0 || ph <= 0) { setOffsetX = x; setOffsetY = y; return }
        var minX = keepVisible - (sw + pw) / 2
        var maxX = (sw + pw) / 2 - keepVisible
        var minY = -(sh - ph) / 2
        var maxY = Math.max(minY, (sh + ph) / 2 - keepVisible)
        setOffsetX = Math.max(minX, Math.min(maxX, x))
        setOffsetY = Math.max(minY, Math.min(maxY, y))
    }

    // Zoom is applied around the panel centre (the centre stays put because the
    // position is stored as an offset from the screen centre).
    function zoomSettings(deltaPercent) {
        settingsZoom = Math.max(zoomMin, Math.min(zoomMax, settingsZoom + deltaPercent))
        zoomSaveTimer.restart()   // wheel events are frequent; write the file once they stop
    }

    function resetSettingsWindow() {
        setOffsetX = 0; setOffsetY = 0; settingsZoom = 100
        saveState()
    }

    Timer { id: zoomSaveTimer; interval: 400; onTriggered: root.saveState() }

    function setNumber(key, v) { root[key] = clamp(v, numSpec[key].min, numSpec[key].max) }
    function toggleSetting(key) { root[key] = !root[key]; saveState() }

    function resetAll() {
        posKeys.forEach(k => root[k] = 0)
        numKeys.forEach(k => root[k] = numSpec[k].def)
        boolKeys.forEach(k => root[k] = boolDefaults[k])
        saveState()
    }

    function saveState() {
        var s = {}
        posKeys.concat(winKeys, numKeys, boolKeys).forEach(k => s[k] = root[k])
        stateFile.setText(JSON.stringify(s))
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                root.posKeys.forEach(k => { if (typeof s[k] === "number") root[k] = s[k] })
                if (typeof s.setOffsetX === "number") root.setOffsetX = s.setOffsetX
                if (typeof s.setOffsetY === "number") root.setOffsetY = s.setOffsetY
                if (typeof s.settingsZoom === "number")
                    root.settingsZoom = Math.max(root.zoomMin, Math.min(root.zoomMax, s.settingsZoom))
                root.numKeys.forEach(k => {
                    if (typeof s[k] === "number") root[k] = root.clamp(s[k], root.numSpec[k].min, root.numSpec[k].max)
                })
                root.boolKeys.forEach(k => { if (typeof s[k] === "boolean") root[k] = s[k] })
            } catch (e) {
                console.warn("mediaosd: could not read saved state:", e)
            }
        }
    }

    // ---- background processes ---------------------------------------------
    Process {
        id: mediaProcess
        command: ["playerctl", "--all-players", "metadata", "--format", root.playerFormat]

        stdout: StdioCollector {
            onStreamFinished: {
                var pick = root.pickPlayer(this.text)
                if (pick) root.applyPlayer(pick, true); else root.clearPlayer()
                root.finishPendingShow()
            }
        }
    }

    Process {
        command: ["playerctl", "--all-players", "--follow", "metadata", "--format", root.playerFormat]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var p = root.parsePlayer(data.trim())
                if (!p || (root.musicOnly && !p.music)) return

                var trackChanged = p.title !== root.title || p.artist !== root.artist
                root.applyPlayer(p, false)

                if (root.ready && root.trackChangeOsd && trackChanged && p.title !== "" && p.status === "Playing")
                    root.triggerMediaOsd()
                if (root.ready) root.updateMedia()
            }
        }
    }

    Timer { interval: 1000; repeat: true; running: root.showing && root.showMedia; onTriggered: root.updateMedia() }

    Timer {
        interval: 250
        repeat: true
        running: root.playing && root.showing && root.showMedia
        onTriggered: { if (root.length > 0) root.position = Math.min(root.position + 250000, root.length) }
    }

    property var bars: []
    property bool cavaPaused: false

    Timer { id: cavaResume; interval: 350; onTriggered: root.cavaPaused = false }

    function restartCava() {
        if (cavaProcess.running) { cavaPaused = true; cavaResume.restart() }
    }

    onBarCountChanged: restartCava()
    onBarFpsChanged: restartCava()

    Process {
        id: cavaProcess
        running: root.showing && root.showMedia && root.showBar && root.showVisualizer && !root.cavaPaused

        command: [
            "sh", "-c",
            "printf '%s\\n' " +
            "'[general]' 'bars = " + root.barCount + "' 'framerate = " + root.barFps + "' " +
            "'[input]' 'method = pipewire' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'bar_delimiter = 59' 'frame_delimiter = 10' " +
            "> /tmp/quickshell-cava.conf && exec cava -p /tmp/quickshell-cava.conf"
        ]

        stdout: SplitParser {
            onRead: data => {
                var parts = data.split(";"), n = root.barCount, out = new Array(n)
                for (var i = 0; i < n; i++) out[i] = parseInt(parts[i]) || 0
                root.bars = out
            }
        }
    }

    // ---- OSD window: only exists while mounted ----------------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win

            // Stays false until one tick after creation so cards animate in.
            property bool reveal: false
            readonly property Item activeCard: root.curKind === "media" ? mediaPanel
                                              : root.curKind === "bright" ? brightPanel : flyout

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "mediaosd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Every visible card (plus the hint bar of the focused one) takes input.
            mask: Region {
                Region { item: flyout.open ? hitVol : null }
                Region { item: mediaPanel.open ? hitMedia : null }
                Region { item: brightPanel.open ? hitBright : null }
            }

            onWidthChanged: root.winW = width
            onHeightChanged: root.winH = height

            Component.onCompleted: {
                root.winW = width
                root.winH = height
                Qt.callLater(() => win.reveal = Qt.binding(() => root.showing))
            }

            Binding {
                target: root
                property: "hovered"
                value: flyout.hovered || mediaPanel.hovered || brightPanel.hovered || toolsHover.hovered
            }

            Binding {
                target: root
                property: "cardH"
                value: ({ media: mediaPanel.height, vol: flyout.height, bright: brightPanel.height })
            }

            Item {
                id: scene
                anchors.fill: parent

                Item {
                    id: hitVol
                    readonly property real k: root.scaleOf("vol")
                    width: flyout.width * k
                    height: (flyout.height + (root.curKind === "vol" ? root.toolsHeight : 0)) * k
                    x: (scene.width - width) / 2 + root.offX("vol")
                    y: root.topGap + root.offY("vol") + root.previewShift.vol
                }
                Item {
                    id: hitMedia
                    readonly property real k: root.scaleOf("media")
                    width: mediaPanel.width * k
                    height: (mediaPanel.height + (root.curKind === "media" ? root.toolsHeight : 0)) * k
                    x: (scene.width - width) / 2 + root.offX("media")
                    y: root.topGap + root.offY("media") + root.previewShift.media
                }
                Item {
                    id: hitBright
                    readonly property real k: root.scaleOf("bright")
                    width: brightPanel.width * k
                    height: (brightPanel.height + (root.curKind === "bright" ? root.toolsHeight : 0)) * k
                    x: (scene.width - width) / 2 + root.offX("bright")
                    y: root.topGap + root.offY("bright") + root.previewShift.bright
                }

                // ---- volume popup ----
                OsdCard {
                    id: flyout
                    kind: "vol"
                    cardScale: root.volScale / 100
                    xOffset: root.volOffsetX
                    yOffset: root.volOffsetY
                    shiftY: root.previewShift.vol
                    open: win.reveal && root.showing && (root.settingsOpen || root.mode === "vol")
                    dim: root.settingsOpen && !root.volOsd
                    width: root.flyoutWidth
                    height: root.flyoutHeight
                    radius: Math.min(root.flyoutRadius, height / 2)

                    DragArea { anchors.fill: parent; enabled: flyout.open; scene: scene; kind: "vol" }

                    Text {
                        id: icon
                        anchors.left: parent.left
                        anchors.leftMargin: root.flyoutPad
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.muted ? "\udb81\udd81"
                            : root.volume <= 0 ? "\udb81\udd7f"
                            : root.volume < 0.5 ? "\udb81\udd80"
                            : "\udb81\udd7e"
                        visible: root.flyoutIcon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: root.flyoutIconSize
                        color: root.flyoutAccent ? Theme.accent : Theme.text
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: root.flyoutPad
                        visible: root.flyoutPercent
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
                        font.pixelSize: root.flyoutTextSize
                        font.bold: true
                        color: Theme.text
                    }

                    Rectangle {
                        anchors.left: icon.visible ? icon.right : parent.left
                        anchors.leftMargin: icon.visible ? 15 : root.flyoutPad
                        anchors.right: parent.right
                        anchors.rightMargin: root.flyoutPercent ? root.flyoutPad + 48 : root.flyoutPad
                        anchors.verticalCenter: parent.verticalCenter
                        height: root.flyoutTrack
                        radius: height / 2
                        color: "#555555"

                        Rectangle {
                            width: root.muted ? 0 : parent.width * Math.min(root.volume, 1)
                            height: parent.height
                            radius: parent.radius
                            color: root.flyoutAccent ? Theme.accent : Theme.text
                            Behavior on width { NumberAnimation { duration: 100 } }
                        }
                    }
                }

                // ---- brightness popup (same look as the volume popup) ----
                OsdCard {
                    id: brightPanel
                    kind: "bright"
                    cardScale: root.volScale / 100
                    xOffset: root.brightOffsetX
                    yOffset: root.brightOffsetY
                    shiftY: root.previewShift.bright
                    open: win.reveal && root.showing && (root.settingsOpen || root.mode === "bright")
                    dim: root.settingsOpen && !root.brightOsd
                    width: root.flyoutWidth
                    height: root.flyoutHeight
                    radius: Math.min(root.flyoutRadius, height / 2)

                    DragArea { anchors.fill: parent; enabled: brightPanel.open; scene: scene; kind: "bright" }

                    Text {
                        id: brightIcon
                        anchors.left: parent.left
                        anchors.leftMargin: root.flyoutPad
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.brightness < 0.34 ? "\udb80\udcde"
                            : root.brightness < 0.67 ? "\udb80\udcdf"
                            : "\udb80\udce0"
                        visible: root.flyoutIcon
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: root.flyoutIconSize
                        color: root.flyoutAccent ? Theme.accent : Theme.text
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: root.flyoutPad
                        visible: root.flyoutPercent
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hasBacklight ? root.brightPct + "%" : "N/A"
                        font.pixelSize: root.flyoutTextSize
                        font.bold: true
                        color: Theme.text
                    }

                    Rectangle {
                        anchors.left: brightIcon.visible ? brightIcon.right : parent.left
                        anchors.leftMargin: brightIcon.visible ? 15 : root.flyoutPad
                        anchors.right: parent.right
                        anchors.rightMargin: root.flyoutPercent ? root.flyoutPad + 48 : root.flyoutPad
                        anchors.verticalCenter: parent.verticalCenter
                        height: root.flyoutTrack
                        radius: height / 2
                        color: "#555555"

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(root.brightness, 1))
                            height: parent.height
                            radius: parent.radius
                            color: root.flyoutAccent ? Theme.accent : Theme.text
                            Behavior on width { NumberAnimation { duration: 100 } }
                        }
                    }
                }

                // ---- media popup ----
                OsdCard {
                    id: mediaPanel
                    kind: "media"
                    cardScale: root.mediaScale / 100
                    xOffset: root.offsetX
                    yOffset: root.offsetY
                    shiftY: root.previewShift.media
                    open: win.reveal && root.showing && root.showMedia
                    dim: root.settingsOpen && !root.mediaOsd
                    width: root.portrait ? root.portraitWidth : root.mediaWidth
                    height: mediaCol.height + 28
                    radius: root.cardRadius

                    readonly property bool artShown: root.showArt && root.artUrl !== "" && artImg.status !== Image.Error
                    readonly property bool hasText: root.showTitle || root.showArtist
                    readonly property bool barShown: root.showBar && root.showVisualizer
                    readonly property bool lineShown: root.showBar && !root.showVisualizer

                    // Declared before the content so buttons stay clickable on top.
                    DragArea { anchors.fill: parent; enabled: mediaPanel.open; scene: scene; kind: "media" }

                    Column {
                        id: mediaCol
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.topMargin: 14
                        anchors.leftMargin: root.portrait ? 20 : 25
                        anchors.rightMargin: root.portrait ? 20 : 25
                        spacing: 6

                        Item {
                            id: topBlock
                            visible: mediaPanel.artShown || mediaPanel.hasText
                            width: parent.width
                            readonly property real artSize: mediaPanel.artShown ? (root.portrait ? width : root.artSize) : 0
                            height: root.portrait
                                ? artSize + (artSize > 0 && mediaPanel.hasText ? 8 : 0) + textCol.height
                                : Math.max(artSize, textCol.height)

                            Item {
                                visible: mediaPanel.artShown
                                width: topBlock.artSize
                                height: topBlock.artSize

                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: root.showArt ? root.artUrl : ""
                                    sourceSize: Qt.size(400, 400)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    visible: false
                                }

                                Rectangle {
                                    id: artMask
                                    anchors.fill: parent
                                    radius: root.portrait ? 16 : 10
                                    visible: false
                                    layer.enabled: true
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: artImg
                                    maskEnabled: true
                                    maskSource: artMask
                                    opacity: root.artOpacity / 100
                                }
                            }

                            Column {
                                id: textCol
                                visible: mediaPanel.hasText
                                readonly property bool sameLine: !root.portrait && !root.artistBelow && root.showTitle && root.showArtist
                                x: root.portrait ? 0 : (topBlock.artSize > 0 ? topBlock.artSize + 12 : 0)
                                y: root.portrait
                                    ? (topBlock.artSize > 0 ? topBlock.artSize + 8 : 0)
                                    : (topBlock.height - height) / 2
                                width: topBlock.width - x
                                spacing: 2

                                Item {
                                    visible: root.showTitle
                                    width: parent.width
                                    height: titleText.implicitHeight

                                    Text {
                                        id: titleText
                                        width: textCol.sameLine ? parent.width / 2 - 5 : parent.width
                                        text: root.title || "Nothing playing"
                                        horizontalAlignment: root.portrait ? Text.AlignHCenter : Text.AlignLeft
                                        elide: Text.ElideRight
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: Theme.text
                                    }
                                    Text {
                                        visible: textCol.sameLine
                                        anchors.right: parent.right
                                        width: parent.width / 2 - 5
                                        text: root.artist || "No artist"
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideLeft
                                        font.pixelSize: 11
                                        color: Theme.text
                                        opacity: 0.65
                                    }
                                }

                                Text {
                                    visible: root.showArtist && !textCol.sameLine
                                    width: parent.width
                                    text: root.artist || "No artist"
                                    horizontalAlignment: root.portrait ? Text.AlignHCenter : Text.AlignLeft
                                    elide: Text.ElideRight
                                    font.pixelSize: 11
                                    color: Theme.text
                                    opacity: 0.65
                                }
                            }
                        }

                        // visualizer (played part is brighter)
                        // Bar heights are the cava level (0-100) times the sensitivity setting,
                        // clamped to the visualizer height.
                        Item {
                            id: visualizer
                            visible: mediaPanel.barShown
                            width: parent.width
                            height: root.barHeight
                            readonly property real barWidth: Math.max(1, (width - root.barSpacing * (root.barCount - 1)) / root.barCount)

                            Repeater {
                                model: root.barCount
                                Rectangle {
                                    required property int index
                                    x: index * (visualizer.barWidth + root.barSpacing)
                                    width: visualizer.barWidth
                                    radius: Math.min(root.barRadius, width / 2)
                                    color: root.accentBars ? Theme.accent : Theme.text
                                    opacity: (((index + 0.5) / root.barCount) <= root.progress
                                              ? root.barOpacity : root.barDimOpacity) / 100
                                    height: Math.min(visualizer.height,
                                                     Math.max(3, ((root.bars[index] ?? 0) / 100)
                                                                 * (root.barSensitivity / 100) * visualizer.height))
                                    y: visualizer.height - height
                                    Behavior on height { NumberAnimation { duration: 60 } }
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }

                        // plain duration bar (when the visualizer is off)
                        Item {
                            visible: mediaPanel.lineShown
                            width: parent.width
                            height: Math.min(root.barHeight, 20)

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: Math.min(root.barRadius, 2)
                                color: root.accentBars ? Theme.accent : Theme.text
                                opacity: root.barDimOpacity / 100
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * root.progress
                                height: 4
                                radius: Math.min(root.barRadius, 2)
                                color: root.accentBars ? Theme.accent : Theme.text
                                opacity: root.barOpacity / 100
                            }
                        }

                        Item {
                            visible: root.showControls
                            width: parent.width
                            height: 26

                            Row {
                                anchors.centerIn: parent
                                spacing: 28

                                GlyphButton {
                                    text: "\udb81\udcae"
                                    font.pixelSize: 19
                                    onClicked: root.mediaCmd("previous")
                                    onHoveredChanged: root.hoverTip = hovered ? "Previous track" : ""
                                }
                                GlyphButton {
                                    text: root.playing ? "\udb80\udfe4" : "\udb81\udc0a"
                                    font.pixelSize: 21
                                    onClicked: root.mediaCmd("play-pause")
                                    onHoveredChanged: root.hoverTip = hovered ? (root.playing ? "Pause" : "Play") : ""
                                }
                                GlyphButton {
                                    text: "\udb81\udcad"
                                    font.pixelSize: 19
                                    onClicked: root.mediaCmd("next")
                                    onHoveredChanged: root.hoverTip = hovered ? "Next track" : ""
                                }
                            }
                        }
                    }
                }

                // ---- tools bar under the card: hint text + pin ----
                Item {
                    id: tools
                    width: win.activeCard.width
                    height: root.toolsHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.curX
                    anchors.top: parent.top
                    anchors.topMargin: root.topGap + root.curY + root.previewShift[root.curKind]
                                       + win.activeCard.height * root.scaleFactor
                    transformOrigin: Item.Top
                    scale: root.scaleFactor
                    visible: opacity > 0
                    opacity: (root.showing && (root.hovered || root.dragging)) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: root.fadeMs } }

                    HoverHandler { id: toolsHover; enabled: root.showing }

                    Text {
                        visible: root.showTips
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: root.curKind === "media" ? pinButton.left : parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        font.pixelSize: 10
                        color: Theme.textDim
                        horizontalAlignment: root.curKind === "media" ? Text.AlignLeft : Text.AlignHCenter
                        text: root.dragging ? ""
                            : root.hoverTip !== "" ? root.hoverTip
                            : "RMB for settings · Drag to move · double-click resets"
                    }

                    // Larger pin button: bigger hit area + glyph, hover highlight,
                    // always reasonably visible (was a tiny 18px, 30% opacity button).
                    FooterButton {
                        id: pinButton
                        visible: root.curKind === "media"
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26
                        radius: 8
                        color: root.pinned ? Theme.alpha(Theme.accent, 0.18)
                             : hovered ? Theme.alpha(Theme.text, 0.12)
                             : "transparent"
                        label: "\uDB81\uDC03"
                        fontSize: 17
                        active: root.pinned
                        opacity: (hovered || root.pinned) ? 1 : 0.55
                        onClicked: root.togglePinned()
                        onHoveredChanged: root.hoverTip = hovered
                            ? (root.pinned ? "Unpin (allow auto-hide)" : "Pin open (disable auto-hide)") : ""
                    }
                }
            }
        }
    }

    // ---- settings window: only exists while settings are open -------------
    // The window itself covers the whole screen (transparent, input mask = the
    // panel only), exactly like the OSD window, so the panel can be dragged
    // anywhere without moving a layer-shell surface around.
    //
    // Every size below is multiplied by `u` (= ui * Theme.settingsScale * zoom), exactly like the
    // wallpaper picker's menu, so all menus scale together. The controls come
    // from CustomizationSettings.qml.
    //
    // Mouse: drag the header (or the empty part of the footer) to move the
    // window; Shift + scroll zooms it (50 - 200 %); double-click the header /
    // footer to reset position and zoom. Position and zoom are remembered.
    //
    // Keyboard: every toggle, slider and footer button is Tab-focusable (Qt's
    // normal focus chain, in visual order). Tab / Shift+Tab or Up / Down move
    // between controls, Left / Right (PgUp / PgDn for bigger steps, Home / End
    // for min / max) adjust a focused slider, Space / Enter flips a toggle or
    // presses a button, and the page auto-scrolls to keep the focused control
    // in view. Esc or C closes the window.
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin

            readonly property real ui: (screen?.height ?? 1080) / 1080
            readonly property real u: ui * root.settingsScale * (root.settingsZoom / 100)

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mediaosd-settings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // Only the panel receives input; everything else passes through.
            mask: Region { item: panel }

            // Shares the scale with the reusable components (they read host.menuUi).
            Binding { target: root; property: "menuUi"; value: settingsWin.u }

            // Keep the panel reachable after a resolution change / zoom.
            function reclamp() {
                root.setSettingsPosition(root.setOffsetX, root.setOffsetY,
                                         sScene.width, sScene.height, panel.width, panel.height)
            }

            // Shift + wheel: 10 % per notch (smooth-scroll devices accumulate smoothly).
            // Some compositors turn Shift+wheel into a horizontal scroll, so accept both axes.
            function zoomBy(e) {
                var d = e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x
                if (d === 0) return
                root.zoomSettings(d / 120 * 10)
                reclamp()
            }

            // Header / footer drag. Positions are measured in sScene coordinates, which
            // don't move while the panel does, so the drag stays stable.
            property real dragPressX: 0; property real dragPressY: 0
            property real dragStartX: 0; property real dragStartY: 0

            function dragStart(area, mouse) {
                var p = area.mapToItem(sScene, mouse.x, mouse.y)
                dragPressX = p.x; dragPressY = p.y
                dragStartX = root.setOffsetX; dragStartY = root.setOffsetY
            }

            function dragMove(area, mouse) {
                var p = area.mapToItem(sScene, mouse.x, mouse.y)
                root.setSettingsPosition(dragStartX + (p.x - dragPressX), dragStartY + (p.y - dragPressY),
                                         sScene.width, sScene.height, panel.width, panel.height)
            }

            Component.onCompleted: Qt.callLater(settingsWin.reclamp)

            Item {
                id: sScene
                anchors.fill: parent

                Item {
                    id: panel
                    width: 440 * settingsWin.u
                    height: Math.min(600 * settingsWin.u, (settingsWin.screen?.height ?? 800) * 0.85)
                    x: (sScene.width - width) / 2 + root.setOffsetX
                    y: (sScene.height - height) / 2 + root.setOffsetY

                    // Shift + scroll over the frame / header / footer.
                    WheelHandler {
                        acceptedModifiers: Qt.ShiftModifier
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: e => settingsWin.zoomBy(e)
                    }

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

                        Item {
                            id: head
                            anchors.top: parent.top
                            width: parent.width
                            height: 54 * settingsWin.u

                            // Drag handle (declared first so the close button stays on top).
                            MouseArea {
                                id: headDrag
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                onPressed: mouse => settingsWin.dragStart(headDrag, mouse)
                                onPositionChanged: mouse => { if (pressed) settingsWin.dragMove(headDrag, mouse) }
                                onReleased: root.saveState()
                                onCanceled: root.saveState()
                                onDoubleClicked: root.resetSettingsWindow()
                            }

                            Text {
                                x: 20 * settingsWin.u; y: 10 * settingsWin.u
                                text: "OSD settings"
                                font.family: root.th.fontFamily
                                font.pixelSize: root.th.textSizeSection * settingsWin.u
                                font.bold: true
                                color: Theme.text
                            }
                            Text {
                                x: 20 * settingsWin.u; y: 31 * settingsWin.u
                                text: "Drag · Tab · Shift+scroll"
                                font.family: root.th.fontFamily
                                font.pixelSize: root.th.textSizeSmall * settingsWin.u
                                color: Theme.textDim
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 20 * settingsWin.u
                                y: 10 * settingsWin.u
                                width: 24 * settingsWin.u; height: 24 * settingsWin.u
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "×"
                                font.family: root.th.fontFamily
                                font.pixelSize: 22 * settingsWin.u
                                color: closeArea.containsMouse ? Theme.text : Theme.textDim
                                MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.closeSettings() }
                            }
                        }

                        Flickable {
                            id: flick
                            anchors { top: head.bottom; bottom: foot.top; left: parent.left; right: parent.right }
                            anchors.topMargin: 4 * settingsWin.u
                            contentWidth: width
                            contentHeight: contentCol.height + 12 * settingsWin.u
                            clip: true
                            flickableDirection: Flickable.VerticalFlick
                            boundsBehavior: Flickable.StopAtBounds

                            // Shift + scroll over the content zooms instead of scrolling.
                            WheelHandler {
                                acceptedModifiers: Qt.ShiftModifier
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: e => settingsWin.zoomBy(e)
                            }

                            Column {
                                id: contentCol
                                x: 20 * settingsWin.u
                                width: flick.width - 48 * settingsWin.u

                                CustomizationSettings.SectionHeader { host: root; text: "Show OSDs" }
                                Grid {
                                    width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                    CustomizationSettings.ToggleRow { host: root; key: "volOsd"; label: "Volume" }
                                    CustomizationSettings.ToggleRow { host: root; key: "mediaOsd"; label: "Media" }
                                    CustomizationSettings.ToggleRow { host: root; key: "brightOsd"; label: "Brightness" }
                                }

                                CustomizationSettings.SectionHeader { host: root; text: "Global" }
                                Grid {
                                    width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                    CustomizationSettings.ToggleRow { host: root; key: "showTips"; label: "Tooltips" }
                                    CustomizationSettings.SliderRow { host: root; key: "fadeMs"; label: "Animation" }
                                }

                                // Volume and brightness are the same kind of card, so they share these settings.
                                CustomizationSettings.SectionHeader { host: root; text: "Volume & brightness" }
                                Grid {
                                    width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                    CustomizationSettings.SliderRow { host: root; key: "volScale"; label: "Scale"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "volTimeout"; label: "Hide after"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "flyoutWidth"; label: "Width"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "flyoutHeight"; label: "Height"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "flyoutRadius"; label: "Corner radius"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "flyoutBgOpacity"; label: "Background"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "flyoutIconSize"; label: "Icon size"; enabled: root.flyoutIcon && (root.volOsd || root.brightOsd) }
                                    CustomizationSettings.SliderRow { host: root; key: "flyoutTextSize"; label: "Text size"; enabled: root.flyoutPercent && (root.volOsd || root.brightOsd) }
                                    CustomizationSettings.SliderRow { host: root; key: "flyoutTrack"; label: "Bar thickness"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "flyoutPad"; label: "Side padding"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.ToggleRow { host: root; key: "flyoutIcon"; label: "Icon"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.ToggleRow { host: root; key: "flyoutPercent"; label: "Percentage"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.ToggleRow { host: root; key: "flyoutAccent"; label: "Accent colour"; enabled: root.volOsd || root.brightOsd }
                                    CustomizationSettings.ToggleRow { host: root; key: "flyoutBorder"; label: "Border"; enabled: root.volOsd || root.brightOsd }
                                }

                                CustomizationSettings.SectionHeader { host: root; text: "Media" }
                                Grid {
                                    width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                    CustomizationSettings.SliderRow { host: root; key: "mediaScale"; label: "Scale"; enabled: root.mediaOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "mediaTimeout"; label: "Hide after"; enabled: root.mediaOsd }
                                    CustomizationSettings.ToggleRow { host: root; key: "musicOnly"; label: "Music only" }
                                    CustomizationSettings.ToggleRow { host: root; key: "trackChangeOsd"; label: "On track change" }
                                }

                                CustomizationSettings.SectionHeader { host: root; text: "Media content" }
                                Grid {
                                    width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                    CustomizationSettings.ToggleRow { host: root; key: "showArt"; label: "Album art" }
                                    CustomizationSettings.ToggleRow { host: root; key: "showTitle"; label: "Title" }
                                    CustomizationSettings.ToggleRow { host: root; key: "showArtist"; label: "Artist" }
                                    CustomizationSettings.ToggleRow { host: root; key: "showControls"; label: "Controls" }
                                    CustomizationSettings.ToggleRow { host: root; key: "showBar"; label: "Visualizer & bar" }
                                    CustomizationSettings.ToggleRow { host: root; key: "showVisualizer"; label: "Visualizer"; enabled: root.showBar }
                                }

                                CustomizationSettings.SectionHeader { host: root; text: "Media layout" }
                                Grid {
                                    width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                    CustomizationSettings.ToggleRow { host: root; key: "portrait"; label: "Portrait" }
                                    CustomizationSettings.ToggleRow {
                                        host: root
                                        key: "artistBelow"
                                        label: "Artist below"
                                        checked: root.artistBelow || root.portrait
                                        enabled: !root.portrait && root.showTitle && root.showArtist
                                    }
                                    CustomizationSettings.ToggleRow { host: root; key: "showBorder"; label: "Border" }
                                    CustomizationSettings.SliderRow { host: root; key: root.portrait ? "portraitWidth" : "mediaWidth"; label: "Width" }
                                    CustomizationSettings.SliderRow { host: root; key: "artSize"; label: "Art size"; enabled: root.showArt && !root.portrait }
                                    CustomizationSettings.SliderRow { host: root; key: "cardRadius"; label: "Corner radius" }
                                }

                                CustomizationSettings.SectionHeader { host: root; text: "Media visualizer" }
                                Grid {
                                    width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                    CustomizationSettings.SliderRow { host: root; key: "barCount"; label: "Bars"; enabled: root.showBar && root.showVisualizer }
                                    CustomizationSettings.SliderRow { host: root; key: "barSpacing"; label: "Spacing"; enabled: root.showBar && root.showVisualizer }
                                    CustomizationSettings.SliderRow { host: root; key: "barHeight"; label: "Height"; enabled: root.showBar }
                                    CustomizationSettings.SliderRow { host: root; key: "barRadius"; label: "Round"; enabled: root.showBar }
                                    CustomizationSettings.SliderRow { host: root; key: "barFps"; label: "Frame rate"; enabled: root.showBar && root.showVisualizer }
                                    CustomizationSettings.SliderRow { host: root; key: "barSensitivity"; label: "Sensitivity"; enabled: root.showBar && root.showVisualizer }
                                    CustomizationSettings.ToggleRow { host: root; key: "accentBars"; label: "Accent colour"; enabled: root.showBar }
                                }

                                CustomizationSettings.SectionHeader { host: root; text: "Media opacity" }
                                Grid {
                                    width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                                    CustomizationSettings.SliderRow { host: root; key: "bgOpacity"; label: "Background"; enabled: root.mediaOsd }
                                    CustomizationSettings.SliderRow { host: root; key: "artOpacity"; label: "Album art"; enabled: root.showArt }
                                    CustomizationSettings.SliderRow { host: root; key: "barOpacity"; label: "Bars played"; enabled: root.showBar }
                                    CustomizationSettings.SliderRow { host: root; key: "barDimOpacity"; label: "Bars remaining"; enabled: root.showBar }
                                }

                                CustomizationSettings.SectionHeader { host: root; text: "Position" }
                                Flow {
                                    width: parent.width
                                    spacing: 8 * settingsWin.u
                                    CustomizationSettings.ActionButton { host: root; label: "Reset media position"; enabled: root.mediaMoved; onClicked: root.resetPos("media") }
                                    CustomizationSettings.ActionButton { host: root; label: "Reset volume position"; enabled: root.volMoved; onClicked: root.resetPos("vol") }
                                    CustomizationSettings.ActionButton { host: root; label: "Reset brightness position"; enabled: root.brightMoved; onClicked: root.resetPos("bright") }
                                }
                            }
                        }

                        // Scrollbar lives outside the Flickable content so it doesn't scroll away.
                        Rectangle {
                            visible: flick.contentHeight > flick.height
                            x: flick.x + flick.width - 14 * settingsWin.u
                            y: flick.y
                            width: 4 * settingsWin.u
                            height: flick.height
                            radius: 2 * settingsWin.u
                            color: Theme.alpha(Theme.text, 0.08)
                        }

                        Rectangle {
                            id: sbHandle
                            visible: flick.contentHeight > flick.height
                            x: flick.x + flick.width - 14 * settingsWin.u
                            width: 4 * settingsWin.u
                            radius: 2 * settingsWin.u
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

                                // Drive contentY instead of drag.target (which would break the y binding).
                                property real grabY: 0

                                onPressed: mouse => {
                                    grabY = mapToItem(flick, mouse.x, mouse.y).y - flick.visibleArea.yPosition * flick.height
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed) return
                                    var span = flick.height - sbHandle.height
                                    if (span <= 0) return
                                    var r = Math.max(0, Math.min(1, (mapToItem(flick, mouse.x, mouse.y).y - grabY) / span))
                                    flick.contentY = r * (flick.contentHeight - flick.height)
                                }
                            }
                        }

                        Item {
                            id: foot
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 50 * settingsWin.u

                            Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.text, 0.08) }

                            // Empty footer space is a drag handle too (buttons sit on top).
                            MouseArea {
                                id: footDrag
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                onPressed: mouse => settingsWin.dragStart(footDrag, mouse)
                                onPositionChanged: mouse => { if (pressed) settingsWin.dragMove(footDrag, mouse) }
                                onReleased: root.saveState()
                                onCanceled: root.saveState()
                                onDoubleClicked: root.resetSettingsWindow()
                            }

                            CustomizationSettings.ActionButton {
                                host: root
                                x: 20 * settingsWin.u
                                anchors.verticalCenter: parent.verticalCenter
                                label: "Reset all"
                                enabled: root.modified
                                onClicked: root.resetAll()
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
                }
            }
        }
    }

    // ---- OSD-only components (not shared with the settings menus) ----------
    component OsdCard: Rectangle {
        id: card
        property bool open: false
        property var host: root
        property string kind: "vol"          // "vol" | "bright" | "media"
        property real xOffset: 0
        property real yOffset: 0
        property real shiftY: 0              // settings preview only (keeps the cards apart)
        property real cardScale: 1
        property bool dim: false             // OSD switched off, shown only for the settings preview
        readonly property bool hovered: cardHover.hovered

        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, (kind === "media" ? host.bgOpacity : host.flyoutBgOpacity) / 100)
        border.width: (kind === "media" ? host.showBorder : host.flyoutBorder) ? 1 : 0
        border.color: Theme.alpha(Theme.text, 0.12)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: xOffset
        anchors.top: parent.top
        anchors.topMargin: host.topGap + yOffset + shiftY
        transformOrigin: Item.Top
        opacity: open ? (dim ? 0.4 : 1) : 0
        visible: opacity > 0
        scale: (open ? 1 : 0.9) * cardScale

        Behavior on opacity { NumberAnimation { duration: host.fadeMs } }
        Behavior on scale { NumberAnimation { duration: host.fadeMs; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: cardHover
            enabled: card.open
            onHoveredChanged: if (hovered && card.host.settingsOpen) card.host.focusKind = card.kind
        }

        // scroll anywhere on the card: brightness card -> brightness, others -> volume
        WheelHandler {
            enabled: card.open
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => host.scrollFor(card.kind, e.angleDelta.y)
        }
    }

    component FooterButton: Rectangle {
        id: fb
        property string label: ""
        property int fontSize: 11
        property bool active: false
        readonly property bool hovered: fbArea.containsMouse
        signal clicked()

        width: 16; height: 16; radius: 6
        color: Theme.bg
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: fb.label
            font.family: "Symbols Nerd Font"
            font.pixelSize: fb.fontSize
            font.bold: true
            color: fb.active ? Theme.accent : (fb.hovered ? Theme.text : Theme.textDim)
        }

        MouseArea {
            id: fbArea
            anchors.fill: parent
            anchors.margins: -4          // slightly larger click target than the visible button
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fb.clicked()
        }
    }

    component GlyphButton: Text {
        id: gb
        readonly property bool hovered: gbArea.containsMouse
        signal clicked()
        font.family: "Symbols Nerd Font"
        color: Theme.text
        opacity: hovered ? 1 : 0.8
        Behavior on opacity { NumberAnimation { duration: 120 } }
        MouseArea { id: gbArea; anchors.fill: parent; hoverEnabled: true; onClicked: gb.clicked() }
    }

    // Fill a card with this to make the whole card draggable.
    component DragArea: MouseArea {
        id: da
        property var host: root
        property Item scene
        property string kind: "vol"
        property real pressX: 0; property real pressY: 0; property real startX: 0; property real startY: 0

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        function finish() {
            if (!host.dragging) return
            host.dragging = false
            host.saveState()
        }

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                host.toggleSettings()
                return
            }
            var p = da.mapToItem(da.scene, mouse.x, mouse.y)
            pressX = p.x; pressY = p.y
            host.beginDrag(da.kind)          // bakes the preview shift into the offset first
            startX = host.offX(da.kind); startY = host.offY(da.kind)
        }
        onPositionChanged: mouse => {
            if (!host.dragging) return
            var p = da.mapToItem(da.scene, mouse.x, mouse.y)
            host.setPosition(da.kind, startX + (p.x - pressX), startY + (p.y - pressY))
        }
        onReleased: finish()
        onCanceled: finish()
        onDoubleClicked: mouse => { if (mouse.button === Qt.LeftButton) host.resetPos(da.kind) }
    }
}