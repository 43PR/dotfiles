import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Scope {
    id: root

    // ---- window lifecycle ------------------------------------------------
    property bool mounted: false      // OSD window exists
    property real winW: 0             // reported by the OSD window while mounted
    property real winH: 0
    property real hitW: 0

    // Must be longer than the fade-out (OsdCard opacity/scale = fadeMs).
    Timer {
        id: unmountTimer
        interval: root.fadeMs + 100
        onTriggered: {
            root.mounted = false
            root.winW = 0
            root.winH = 0
            root.hitW = 0
            root.hovered = false
            root.hoverTip = ""
        }
    }

    // ---- constants / specs -----------------------------------------------
    readonly property int topGap: 30
    readonly property int keepVisible: 40
    readonly property int toolsHeight: 22

    readonly property var numSpec: ({
        osdScale:      { min: 60,   max: 160,   def: 80,  step: 5,  unit: "%" },
        mediaWidth:    { min: 300,  max: 600,   def: 420,  step: 20,  unit: "px" },
        portraitWidth: { min: 200,  max: 400,   def: 260,  step: 20,  unit: "px" },
        flyoutWidth:   { min: 200,  max: 500,   def: 320,  step: 20,  unit: "px" },
        artSize:       { min: 32,   max: 96,    def: 52,   step: 4,   unit: "px" },
        cardRadius:    { min: 0,    max: 40,    def: 24,   step: 2,   unit: "px" },
        barCount:      { min: 4,    max: 64,    def: 24,   step: 2,   unit: "" },
        barRadius:     { min: 0,    max: 20,    def: 20,   step: 2,   unit: "px", full: true },
        barSpacing:    { min: 1,    max: 10,    def: 3,    step: 1,   unit: "px" },
        barHeight:     { min: 10,   max: 60,    def: 20,   step: 2,   unit: "px" },
        barFps:        { min: 15,   max: 60,    def: 30,   step: 5,   unit: " fps" },
        mediaTimeout:  { min: 500,  max: 15000, def: 3000, step: 500, unit: "s" },
        volTimeout:    { min: 300,  max: 8000,  def: 1200, step: 100, unit: "s" },
        fadeMs:        { min: 0,    max: 500,   def: 150,  step: 25,  unit: " ms" },
        volStep:       { min: 1,    max: 20,    def: 5,    step: 1,   unit: "%" },
        bgOpacity:     { min: 10,   max: 100,   def: Math.max(10, Math.round((Theme.bg.a ?? 1) * 20) * 5),        step: 5, unit: "%" },
        artOpacity:    { min: 20,   max: 100,   def: Math.max(20, Math.round((Theme.bgAlpha ?? 1) * 20) * 5),    step: 5, unit: "%" },
        barOpacity:    { min: 30,   max: 100,   def: 90,   step: 5,   unit: "%" },
        barDimOpacity: { min: 0,    max: 60,    def: 30,   step: 5,   unit: "%" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showTips: true,
        showVisualizer: true,
        trackChangeOsd: true,
        showArt: true,
        showControls: true,
        musicOnly: true,
        artistBelow: false,
        portrait: true,
        showBorder: false,
        accentBars: false,
        scrollVolume: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    // One-line explanations shown under each setting (when tips are on).
    readonly property var hints: ({
    })

    readonly property var posKeys: ["offsetX", "offsetY", "volOffsetX", "volOffsetY"]

    property real offsetX: 0
    property real offsetY: 0
    property real volOffsetX: 0
    property real volOffsetY: 0

    property int osdScale: numSpec.osdScale.def
    property int mediaWidth: numSpec.mediaWidth.def
    property int portraitWidth: numSpec.portraitWidth.def
    property int flyoutWidth: numSpec.flyoutWidth.def
    property int artSize: numSpec.artSize.def
    property int cardRadius: numSpec.cardRadius.def
    property int barCount: numSpec.barCount.def
    property int barRadius: numSpec.barRadius.def
    property int barSpacing: numSpec.barSpacing.def
    property int barHeight: numSpec.barHeight.def
    property int barFps: numSpec.barFps.def
    property int mediaTimeout: numSpec.mediaTimeout.def
    property int volTimeout: numSpec.volTimeout.def
    property int fadeMs: numSpec.fadeMs.def
    property int volStep: numSpec.volStep.def
    property int bgOpacity: numSpec.bgOpacity.def
    property int artOpacity: numSpec.artOpacity.def
    property int barOpacity: numSpec.barOpacity.def
    property int barDimOpacity: numSpec.barDimOpacity.def

    property bool showTips: boolDefaults.showTips
    property bool showVisualizer: boolDefaults.showVisualizer
    property bool trackChangeOsd: boolDefaults.trackChangeOsd
    property bool showArt: boolDefaults.showArt
    property bool showControls: boolDefaults.showControls
    property bool musicOnly: boolDefaults.musicOnly
    property bool artistBelow: boolDefaults.artistBelow
    property bool portrait: boolDefaults.portrait
    property bool showBorder: boolDefaults.showBorder
    property bool accentBars: boolDefaults.accentBars
    property bool scrollVolume: boolDefaults.scrollVolume

    readonly property real scaleFactor: osdScale / 100

    // Card background: theme colour with its alpha replaced by the
    // "Background" setting (100% = fully opaque).
    readonly property color cardColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bgOpacity / 100)
    readonly property real curX: showMedia ? offsetX : volOffsetX
    readonly property real curY: showMedia ? offsetY : volOffsetY

    readonly property bool mediaMoved: offsetX !== 0 || offsetY !== 0
    readonly property bool volMoved: volOffsetX !== 0 || volOffsetY !== 0

    readonly property bool modified:
        posKeys.some(k => root[k] !== 0)
        || numKeys.some(k => root[k] !== numSpec[k].def)
        || boolKeys.some(k => root[k] !== boolDefaults[k])

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/mediaosd-state.json"

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

    function isMusic(p) {
        var name = p.player.split(".")[0].toLowerCase()
        if (musicPlayers.indexOf(name) >= 0)
            return true
        if (browserPlayers.indexOf(name) < 0)
            return false
        if (p.album !== "")
            return true
        var u = p.url.toLowerCase()
        return musicSites.some(function (s) { return u.indexOf(s) >= 0 })
    }

    readonly property string playerFormat:
        "{{playerName}}\t{{status}}\t{{title}}\t{{artist}}\t{{album}}\t{{position}}\t{{mpris:length}}\t{{mpris:artUrl}}\t{{xesam:url}}"

    function parsePlayer(line) {
        if (!line)
            return null
        var f = line.split("\t")
        if (f.length < 3)
            return null
        while (f.length < 9)
            f.push("")
        var p = {
            player: f[0],
            status: f[1],
            title: f[2],
            artist: f[3],
            album: f[4],
            position: parseFloat(f[5]) || 0,
            length: parseFloat(f[6]) || 0,
            art: f[7],
            url: f[8]
        }
        p.music = isMusic(p)
        return p
    }

    function ctl(cmd) {
        var c = ["playerctl"]
        if (player !== "")
            c.push("--player=" + player)
        c.push(cmd)
        Quickshell.execDetached(c)
    }

    function mediaCmd(cmd) {
        ctl(cmd)
        hideTimer.restart()
    }

    property string title: ""
    property string artist: ""
    property string status: "Stopped"
    property string artUrl: ""
    property string player: ""
    property real position: 0
    property real length: 0

    readonly property bool playing: status === "Playing"
    readonly property real progress: length > 0 ? Math.min(position / length, 1) : 0

    function applyPlayer(p, withTiming) {
        player = p.player
        status = p.status
        title = p.title
        artist = p.artist
        artUrl = p.art
        if (withTiming) {
            position = p.position
            length = p.length
        }
    }

    function clearPlayer() {
        status = "Stopped"
        title = ""
        artist = ""
        artUrl = ""
        player = ""
        position = 0
        length = 0
    }

    function pickPlayer(text) {
        var lines = text.trim().split("\n")
        var pool = []

        for (var i = 0; i < lines.length; i++) {
            var p = parsePlayer(lines[i])
            if (!p || (musicOnly && !p.music))
                continue
            pool.push(p)
        }

        return pool.find(function (p) { return p.status === "Playing" }) ?? pool[0] ?? null
    }

    function updateMedia() {
        if (!mediaProcess.running)
            mediaProcess.running = true
    }

    // ---- volume watching (always on, cheap) -------------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.triggerOsd() }
        function onMutedChanged() { root.triggerOsd() }
    }

    // Mouse wheel over a popup: change the volume.
    function nudgeVolume(dy) {
        if (!scrollVolume || !sink?.audio || dy === 0)
            return
        if (muted && dy > 0)
            sink.audio.muted = false
        var v = sink.audio.volume + (dy > 0 ? 1 : -1) * volStep / 100
        sink.audio.volume = Math.max(0, Math.min(1, v))
        hideTimer.restart()
    }

    // ---- OSD state ---------------------------------------------------------
    property bool ready: false
    property bool showing: false
    property bool showMedia: false
    property bool pendingShow: false
    property bool settingsOpen: false
    property bool dragging: false
    property bool pinned: false
    property bool hovered: false     // driven by a Binding inside the OSD window
    property string hoverTip: ""     // tooltip text of the control under the pointer

    Timer {
        interval: 2000
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: hideTimer
        interval: root.showMedia ? root.mediaTimeout : root.volTimeout
        onTriggered: {
            if (root.hovered || root.settingsOpen || root.dragging || (root.showMedia && root.pinned))
                hideTimer.restart()
            else
                root.showing = false
        }
    }

    function triggerOsd() {
        if (!ready)
            return
        if (showing) {
            hideTimer.restart()
            return
        }
        pendingShow = true
        updateMedia()
    }

    function showMediaOsd() {
        pendingShow = false
        showMedia = true
        showing = true
        hideTimer.restart()
        updateMedia()
    }

    function triggerMediaOsd() {
        if (ready)
            showMediaOsd()
    }

    function openSettings() {
        pendingShow = false
        settingsOpen = true
        showMedia = true
        showing = true
        hideTimer.restart()
    }

    function closeSettings() {
        settingsOpen = false
        dragging = false
        hideTimer.restart()
    }

    function toggleSettings() {
        if (settingsOpen)
            closeSettings()
        else
            openSettings()
    }

    function togglePinned() {
        pinned = !pinned
        hideTimer.restart()
    }

    function closeAll() {
        settingsOpen = false
        dragging = false
        showing = false
    }

    function finishPendingShow() {
        if (!pendingShow)
            return
        pendingShow = false
        showMedia = playing
        showing = true
        hideTimer.restart()
    }

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            showMedia = false
            settingsOpen = false
            dragging = false
            pinned = false
            hoverTip = ""
            unmountTimer.restart()
        }
    }

    onShowMediaChanged: {
        if (showMedia)
            updateMedia()
        else
            bars = []
    }

    IpcHandler {
        target: "mediaosd"
        function media(): void { root.triggerMediaOsd() }
        function settings(): void { root.openSettings() }
        function hide(): void { root.closeAll() }
    }

    // ---- settings helpers --------------------------------------------------
    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    function fmtValue(key, v) {
        var s = numSpec[key]
        if (s.unit === "s")
            return (v / 1000).toFixed(1) + "s"
        if (s.full && v >= s.max)
            return "full"
        return v + s.unit
    }

    // Only called while the user drags the card. Saved offsets are never
    // rewritten by window resizes, so a transient window/card size during
    // mount can no longer squeeze the position you left it at.
    function setPosition(x, y) {
        var nx = x
        var ny = y
        if (winW > 0 && winH > 0 && hitW > 0) {
            var minX = keepVisible - winW / 2 - hitW / 2
            var maxX = winW / 2 - keepVisible + hitW / 2
            var minY = -topGap
            var maxY = Math.max(minY, winH - keepVisible - topGap)
            nx = Math.max(minX, Math.min(maxX, x))
            ny = Math.max(minY, Math.min(maxY, y))
        }
        if (showMedia) {
            offsetX = nx
            offsetY = ny
        } else {
            volOffsetX = nx
            volOffsetY = ny
        }
    }

    function resetPos(media) {
        if (media) {
            offsetX = 0
            offsetY = 0
        } else {
            volOffsetX = 0
            volOffsetY = 0
        }
        saveState()
    }

    function setNumber(key, v) {
        var s = numSpec[key]
        root[key] = clamp(v, s.min, s.max)
    }

    function toggleSetting(key) {
        root[key] = !root[key]
        saveState()
    }

    function resetAll() {
        posKeys.forEach(function (k) { root[k] = 0 })
        numKeys.forEach(function (k) { root[k] = numSpec[k].def })
        boolKeys.forEach(function (k) { root[k] = boolDefaults[k] })
        saveState()
    }

    function saveState() {
        var s = {}
        posKeys.forEach(function (k) { s[k] = root[k] })
        numKeys.forEach(function (k) { s[k] = root[k] })
        boolKeys.forEach(function (k) { s[k] = root[k] })
        stateFile.setText(JSON.stringify(s))
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())

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
                console.warn("mediaosd: could not read saved state:", e)
            }
        }
    }

    // ---- background processes (not part of the window) --------------------
    Process {
        id: mediaProcess

        command: ["playerctl", "--all-players", "metadata", "--format", root.playerFormat]

        stdout: StdioCollector {
            onStreamFinished: {
                var pick = root.pickPlayer(this.text)
                if (pick)
                    root.applyPlayer(pick, true)
                else
                    root.clearPlayer()
                root.finishPendingShow()
            }
        }
    }

    Process {
        id: playerEventProcess

        command: ["playerctl", "--all-players", "--follow", "metadata", "--format", root.playerFormat]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var p = root.parsePlayer(data.trim())
                if (!p || (root.musicOnly && !p.music))
                    return

                var trackChanged = p.title !== root.title || p.artist !== root.artist
                root.applyPlayer(p, false)

                if (root.ready && root.trackChangeOsd && trackChanged
                        && p.title !== "" && p.status === "Playing")
                    root.triggerMediaOsd()

                if (root.ready)
                    root.updateMedia()
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.showing && root.showMedia
        onTriggered: root.updateMedia()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.playing && root.showing && root.showMedia
        onTriggered: {
            if (root.length > 0)
                root.position = Math.min(root.position + 250000, root.length)
        }
    }

    property var bars: []
    property bool cavaPaused: false

    Timer {
        id: cavaResume
        interval: 350
        onTriggered: root.cavaPaused = false
    }

    function restartCava() {
        if (cavaProcess.running) {
            cavaPaused = true
            cavaResume.restart()
        }
    }

    onBarCountChanged: restartCava()
    onBarFpsChanged: restartCava()

    Process {
        id: cavaProcess

        running: root.showing && root.showMedia && root.showVisualizer && !root.cavaPaused

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
                var parts = data.split(";")
                var n = root.barCount
                var out = new Array(n)
                for (var i = 0; i < n; i++)
                    out[i] = parseInt(parts[i]) || 0
                root.bars = out
            }
        }
    }

    // ---- OSD window: only exists while mounted ----------------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win

            // The window is created with `showing` already true, so cards
            // bound straight to it would pop in with no animation. `reveal`
            // stays false until one tick after creation, then follows `showing`.
            property bool reveal: false

            readonly property Item activeCard: root.showMedia ? mediaPanel : flyout

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "mediaosd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region { item: root.showing ? hitbox : null }

            onWidthChanged: root.winW = width
            onHeightChanged: root.winH = height

            Component.onCompleted: {
                root.winW = width
                root.winH = height
                Qt.callLater(function () {
                    win.reveal = Qt.binding(function () { return root.showing })
                })
            }

            // hover state lives in this window, but the Scope's hide timer needs it
            Binding {
                target: root
                property: "hovered"
                value: flyoutHover.hovered || mediaHover.hovered || toolsHover.hovered
            }

            Item {
                id: scene
                anchors.fill: parent

                Item {
                    id: hitbox
                    width: win.activeCard.width * root.scaleFactor
                    height: (win.activeCard.height + root.toolsHeight) * root.scaleFactor
                    x: (scene.width - width) / 2 + root.curX
                    y: root.topGap + root.curY

                    onWidthChanged: root.hitW = width
                    Component.onCompleted: root.hitW = width
                }

                // ---- volume popup ----
                OsdCard {
                    id: flyout
                    host: root
                    xOffset: root.volOffsetX
                    yOffset: root.volOffsetY
                    open: win.reveal && root.showing && !root.showMedia
                    width: root.flyoutWidth
                    height: 28
                    radius: 36

                    HoverHandler {
                        id: flyoutHover
                        enabled: flyout.open
                    }

                    // The whole card is the drag handle.
                    DragArea {
                        anchors.fill: parent
                        enabled: flyout.open
                        host: root
                        scene: scene
                    }

                    WheelHandler {
                        enabled: flyout.open && root.scrollVolume
                        onWheel: event => root.nudgeVolume(event.angleDelta.y)
                    }

                    Text {
                        id: icon
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter

                        text: {
                            if (root.muted)
                                return "󰖁"
                            if (root.volume <= 0)
                                return "󰕿"
                            if (root.volume < 0.5)
                                return "󰖀"
                            return "󰕾"
                        }

                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                        color: Theme.text
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.text
                    }

                    Rectangle {
                        anchors.left: icon.right
                        anchors.leftMargin: 15
                        anchors.right: parent.right
                        anchors.rightMargin: 68
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: 4
                        color: "#555555"

                        Rectangle {
                            width: root.muted ? 0 : parent.width * Math.min(root.volume, 1)
                            height: parent.height
                            radius: 4
                            color: Theme.text
                            Behavior on width { NumberAnimation { duration: 100 } }
                        }
                    }
                }

                // ---- media popup ----
                OsdCard {
                    id: mediaPanel
                    host: root
                    xOffset: root.offsetX
                    yOffset: root.offsetY
                    open: win.reveal && root.showing && root.showMedia
                    width: root.portrait ? root.portraitWidth : root.mediaWidth
                    height: mediaCol.height + 28
                    radius: root.cardRadius

                    readonly property bool artShown: root.showArt
                        && root.artUrl !== "" && artImg.status !== Image.Error

                    HoverHandler {
                        id: mediaHover
                        enabled: mediaPanel.open
                    }

                    // Background, album art and text all drag the card.
                    // Declared before the content so buttons stay clickable on top.
                    DragArea {
                        anchors.fill: parent
                        enabled: mediaPanel.open
                        host: root
                        scene: scene
                    }

                    WheelHandler {
                        enabled: mediaPanel.open && root.scrollVolume
                        onWheel: event => root.nudgeVolume(event.angleDelta.y)
                    }

                    Column {
                        id: mediaCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 14
                        anchors.leftMargin: root.portrait ? 20 : 25
                        anchors.rightMargin: root.portrait ? 20 : 25
                        spacing: 6

                        Item {
                            id: topBlock
                            width: parent.width
                            readonly property real artSize: mediaPanel.artShown ? (root.portrait ? width : root.artSize) : 0
                            height: root.portrait
                                ? artSize + (artSize > 0 ? 8 : 0) + textCol.height
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
                                readonly property bool sameLine: !root.portrait && !root.artistBelow
                                x: root.portrait ? 0 : (topBlock.artSize > 0 ? topBlock.artSize + 12 : 0)
                                y: root.portrait
                                    ? (topBlock.artSize > 0 ? topBlock.artSize + 8 : 0)
                                    : (topBlock.height - height) / 2
                                width: topBlock.width - x
                                spacing: 2

                                Item {
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
                                    visible: !textCol.sameLine
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

                        Item {
                            id: visualizer
                            visible: root.showVisualizer
                            width: parent.width
                            height: root.barHeight
                            readonly property real barSpacing: root.barSpacing
                            readonly property real barWidth: Math.max(1, (width - barSpacing * (root.barCount - 1)) / root.barCount)

                            Repeater {
                                model: root.barCount
                                Rectangle {
                                    required property int index
                                    x: index * (visualizer.barWidth + visualizer.barSpacing)
                                    width: visualizer.barWidth
                                    radius: Math.min(root.barRadius, width / 2)
                                    color: root.accentBars ? Theme.accent : Theme.text
                                    opacity: (((index + 0.5) / root.barCount) <= root.progress
                                              ? root.barOpacity : root.barDimOpacity) / 100
                                    height: Math.max(3, ((root.bars[index] ?? 0) / 100) * visualizer.height)
                                    y: visualizer.height - height
                                    Behavior on height { NumberAnimation { duration: 60 } }
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }

                        Item {
                            visible: !root.showVisualizer
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
                            height: root.showControls ? 26 : 0

                            Row {
                                anchors.centerIn: parent
                                spacing: 28

                                GlyphButton {
                                    text: "󰒮"
                                    font.pixelSize: 19
                                    onClicked: root.mediaCmd("previous")
                                    onHoveredChanged: root.hoverTip = hovered ? "Previous track" : ""
                                }
                                GlyphButton {
                                    text: root.playing ? "󰏤" : "󰐊"
                                    font.pixelSize: 21
                                    onClicked: root.mediaCmd("play-pause")
                                    onHoveredChanged: root.hoverTip = hovered ? (root.playing ? "Pause" : "Play") : ""
                                }
                                GlyphButton {
                                    text: "󰒭"
                                    font.pixelSize: 19
                                    onClicked: root.mediaCmd("next")
                                    onHoveredChanged: root.hoverTip = hovered ? "Next track" : ""
                                }
                            }
                        }
                    }
                }

                // ---- tools bar under the card: hint text + pin + settings ----
                Item {
                    id: tools
                    width: win.activeCard.width
                    height: root.toolsHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.curX
                    anchors.top: parent.top
                    anchors.topMargin: root.topGap + root.curY + win.activeCard.height * root.scaleFactor
                    transformOrigin: Item.Top
                    scale: root.scaleFactor
                    visible: opacity > 0
                    opacity: (root.showing && (root.hovered || root.dragging)) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: root.fadeMs } }

                    HoverHandler {
                        id: toolsHover
                        enabled: root.showing
                    }

                    // Context hint / tooltip of whatever is under the pointer.
                    Text {
                        visible: root.showTips
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: root.showMedia ? pinButton.left : parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        font.pixelSize: 10
                        color: Theme.textDim
                        horizontalAlignment: root.showMedia ? Text.AlignLeft : Text.AlignHCenter
                        text: root.dragging ? ""
                            : root.hoverTip !== "" ? root.hoverTip
                            : "RMB for settings · Drag to move · double-click resets"
                    }

                    FooterButton {
                        id: pinButton
                        visible: root.showMedia
                        anchors.right: settingsButton.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18
                        color: "transparent"
                        label: "\uDB81\uDC03"
                        fontSize: 13
                        active: root.pinned
                        opacity: (hovered || root.pinned) ? 1 : 0.3
                        onClicked: root.togglePinned()
                        onHoveredChanged: root.hoverTip = hovered
                            ? (root.pinned ? "Unpin (allow auto-hide)" : "Pin open (disable auto-hide)") : ""
                    }

                    // Settings only cover the media popup now, so the button
                    // is only shown on it.
                    FooterButton {
                        id: settingsButton
                        visible: root.showMedia
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18
                        color: "transparent"
                        label: "󰒓"
                        fontSize: 13
                        active: root.settingsOpen
                        opacity: (hovered || root.settingsOpen) ? 1 : 0.3
                        onClicked: root.toggleSettings()
                        onHoveredChanged: root.hoverTip = hovered ? "Settings" : ""
                    }
                }
            }
        }
    }

    // ---- settings window: only exists while settings are open -------------
    // Fixed size on purpose: a window whose height is driven by its content
    // gets resized right after creation, and the first frame can stay blank
    // until the pointer enters. Content scrolls inside the Flickable instead.
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin

            color: "transparent"
            implicitWidth: 420
            implicitHeight: Math.min(600, (screen?.height ?? 800) * 0.85)
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mediaosd-settings"
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
                        text: "OSD settings"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.text
                    }
                    Text {
                        x: 20; y: 34
                        text: "Drag to move it. Right-click to open settings"
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                    Text {
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

                    WheelHandler {
                        onWheel: event => {
                            var max = Math.max(0, flick.contentHeight - flick.height)
                            flick.contentY = Math.max(0, Math.min(max, flick.contentY - event.angleDelta.y / 2))
                        }
                    }

                    Column {
                        id: contentCol
                        x: 20
                        width: flick.width - 48

                        SectionHeader { text: "Hints" }
                        ToggleRow { host: root; key: "showTips"; label: "Tooltips & hints"; checked: root.showTips }

                        SectionHeader { text: "Global" }
                        SliderRow { host: root; key: "osdScale"; label: "Scale" }
                        SliderRow { host: root; key: "fadeMs"; label: "Animation speed" }

                        SectionHeader { text: "Content" }
                        ToggleRow { host: root; key: "showArt"; label: "Album art"; checked: root.showArt }
                        ToggleRow { host: root; key: "showVisualizer"; label: "Visualizer"; checked: root.showVisualizer }
                        ToggleRow { host: root; key: "showControls"; label: "Playback buttons"; checked: root.showControls }

                        SectionHeader { text: "Layout" }
                        ToggleRow { host: root; key: "portrait"; label: "Portrait layout"; checked: root.portrait }
                        ToggleRow {
                            host: root
                            key: "artistBelow"
                            label: "Artist below title"
                            checked: root.artistBelow || root.portrait
                            enabled: !root.portrait
                        }
                        SliderRow {
                            host: root
                            key: root.portrait ? "portraitWidth" : "mediaWidth"
                            label: "Width"
                        }
                        SliderRow {
                            host: root
                            key: "artSize"
                            label: "Art size"
                            enabled: root.showArt && !root.portrait
                        }
                        SliderRow { host: root; key: "cardRadius"; label: "Corner radius" }
                        ToggleRow { host: root; key: "showBorder"; label: "Border"; checked: root.showBorder }

                        SectionHeader { text: "Visualizer" }
                        SliderRow { host: root; key: "barCount"; label: "Bars"; enabled: root.showVisualizer }
                        SliderRow { host: root; key: "barSpacing"; label: "Spacing"; enabled: root.showVisualizer }
                        SliderRow { host: root; key: "barHeight"; label: "Height" }
                        SliderRow { host: root; key: "barRadius"; label: "Round" }
                        SliderRow { host: root; key: "barFps"; label: "Frame rate"; enabled: root.showVisualizer }
                        ToggleRow { host: root; key: "accentBars"; label: "Accent colour"; checked: root.accentBars }

                        SectionHeader { text: "Opacity" }
                        SliderRow { host: root; key: "bgOpacity"; label: "Background" }
                        SliderRow { host: root; key: "artOpacity"; label: "Album art"; enabled: root.showArt }
                        SliderRow { host: root; key: "barOpacity"; label: "Bars / progress (played)" }
                        SliderRow { host: root; key: "barDimOpacity"; label: "Bars / progress (remaining)" }

                        SectionHeader { text: "Behavior" }
                        ToggleRow { host: root; key: "musicOnly"; label: "Music players only"; checked: root.musicOnly }
                        ToggleRow { host: root; key: "trackChangeOsd"; label: "Pop up on track change"; checked: root.trackChangeOsd }
                        SliderRow { host: root; key: "mediaTimeout"; label: "Media hide after" }
                        ToggleRow { host: root; key: "scrollVolume"; label: "Scroll to change volume"; checked: root.scrollVolume }
                        SliderRow { host: root; key: "volStep"; label: "Scroll step"; enabled: root.scrollVolume }

                        SectionHeader { text: "Volume popup" }
                        SliderRow { host: root; key: "volTimeout"; label: "Volume hide after" }

                        SectionHeader { text: "Position" }
                        Row {
                            spacing: 8
                            ActionButton {
                                id: resetMediaBtn
                                label: "Reset media position"
                                enabled: root.mediaMoved
                                onClicked: root.resetPos(true)
                            }
                            ActionButton {
                                id: resetVolBtn
                                label: "Reset volume position"
                                enabled: root.volMoved
                                onClicked: root.resetPos(false)
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

                    ActionButton {
                        id: resetAllBtn
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Reset all"
                        enabled: root.modified
                        onClicked: root.resetAll()
                    }

                    ActionButton {
                        id: doneBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Done"
                        primary: true
                        onClicked: root.closeSettings()
                    }
                }
            }
        }
    }

    // ---- reusable components -----------------------------------------------
    component OsdCard: Rectangle {
        property bool open: false
        property var host
        property real xOffset: 0
        property real yOffset: 0

        color: host.cardColor
        border.width: host.showBorder ? 1 : 0
        border.color: Theme.alpha(Theme.text, 0.12)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: xOffset
        anchors.top: parent.top
        anchors.topMargin: host.topGap + yOffset
        transformOrigin: Item.Top
        opacity: open ? 1 : 0
        visible: opacity > 0
        scale: (open ? 1 : 0.9) * host.scaleFactor

        Behavior on opacity { NumberAnimation { duration: host.fadeMs } }
        Behavior on scale { NumberAnimation { duration: host.fadeMs; easing.type: Easing.OutCubic } }
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
            hoverEnabled: true
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
        MouseArea {
            id: gbArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: gb.clicked()
        }
    }

    // Fill a card with this to make the whole card draggable.
    component DragArea: MouseArea {
        id: da
        property var host
        property Item scene
        property real pressX: 0
        property real pressY: 0
        property real startX: 0
        property real startY: 0

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        function finish() {
            if (!host.dragging)
                return
            host.dragging = false
            host.saveState()
        }
        onPressed: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                if (host.showMedia)
                host.toggleSettings()
                return
            }
            var p = da.mapToItem(da.scene, mouse.x, mouse.y)
            pressX = p.x
            pressY = p.y
            startX = host.curX
            startY = host.curY
            host.dragging = true
        }
        onPositionChanged: function (mouse) {
            if (!host.dragging)
                return
            var p = da.mapToItem(da.scene, mouse.x, mouse.y)
            host.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
        }
        onReleased: finish()
        onCanceled: finish()
        onDoubleClicked: function (mouse) {
            if (mouse.button === Qt.LeftButton)
            host.resetPos(host.showMedia)
        }
    }

    component ActionButton: Rectangle {
        id: ab
        property string label: ""
        property bool primary: false
        readonly property bool hovered: abArea.containsMouse
        signal clicked()

        implicitWidth: abText.implicitWidth + 28
        width: implicitWidth
        height: 30
        radius: 15
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
            onClicked: ab.clicked()
        }
    }

    component SectionHeader: Item {
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

    component ToggleRow: Item {
        id: tr
        property var host
        property string key: ""
        property string label: ""
        property bool checked: false

        readonly property string hint: host.hints[key] ?? ""
        readonly property bool showHint: host.showTips && hint !== ""
        readonly property real hintH: showHint ? trHint.implicitHeight + 2 : 0

        width: parent?.width ?? 0
        height: 34 + hintH
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
            y: tr.showHint ? 4 : 9
            text: tr.label
            elide: Text.ElideRight
            font.pixelSize: 12
            font.bold: true
            color: Theme.text
        }

        Text {
            id: trHint
            visible: tr.showHint
            x: 0
            y: 21
            width: parent.width - 48
            text: tr.hint
            wrapMode: Text.WordWrap
            font.pixelSize: 10
            color: Theme.textDim
        }

        Rectangle {
            id: sw
            anchors.right: parent.right
            y: 7
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
            onClicked: tr.host.toggleSetting(tr.key)
        }
    }

    // Self-contained minimal slider (no external Slider.qml needed).
    // Reads/writes a numSpec entry on the host and saves on release.
    component SliderRow: Item {
        id: sr
        property var host
        property string key: ""
        property string label: ""

        readonly property var spec: host.numSpec[key]
        readonly property real ratio: Math.max(0, Math.min(1,
            (host[key] - spec.min) / (spec.max - spec.min)))

        readonly property string hint: host.hints[key] ?? ""
        readonly property bool showHint: host.showTips && hint !== ""
        readonly property real hintH: showHint ? srHint.implicitHeight + 2 : 0

        width: parent?.width ?? 0
        height: 44 + hintH
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

        Text {
            id: srHint
            visible: sr.showHint
            x: 0
            y: 22
            width: parent.width
            text: sr.hint
            wrapMode: Text.WordWrap
            font.pixelSize: 10
            color: Theme.textDim
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            y: 30 + sr.hintH
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
            anchors.topMargin: 20 + sr.hintH
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
    }
}