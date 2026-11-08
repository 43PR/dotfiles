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
    property real winW: 0; property real winH: 0; property real hitW: 0

    // Must be longer than the fade-out (OsdCard opacity/scale = fadeMs).
    Timer {
        id: unmountTimer
        interval: root.fadeMs + 100
        onTriggered: { root.mounted = false; root.winW = 0; root.winH = 0; root.hitW = 0; root.hovered = false; root.hoverTip = "" }
    }

    // ---- constants / specs -----------------------------------------------
    readonly property int topGap: 30
    readonly property int keepVisible: 40
    readonly property int toolsHeight: 28

    readonly property var numSpec: ({
        mediaScale:    { min: 20,  max: 200,   def: 70,   step: 5,   unit: "%" },
        volScale:      { min: 20,  max: 200,   def: 80,   step: 5,   unit: "%" },
        mediaWidth:    { min: 200, max: 1000,  def: 420,  step: 20,  unit: "px" },
        portraitWidth: { min: 120, max: 700,   def: 260,  step: 20,  unit: "px" },
        flyoutWidth:   { min: 120, max: 800,   def: 320,  step: 20,  unit: "px" },
        artSize:       { min: 16,  max: 200,   def: 52,   step: 4,   unit: "px" },
        cardRadius:    { min: 0,   max: 80,    def: 24,   step: 2,   unit: "px" },
        barCount:      { min: 2,   max: 128,   def: 24,   step: 2,   unit: "" },
        barRadius:     { min: 0,   max: 40,    def: 40,   step: 2,   unit: "px", full: true },
        barSpacing:    { min: 0,   max: 30,    def: 3,    step: 1,   unit: "px" },
        barHeight:     { min: 4,   max: 400,   def: 20,   step: 2,   unit: "px" },
        barFps:        { min: 5,   max: 144,   def: 30,   step: 5,   unit: " fps" },
        mediaTimeout:  { min: 250, max: 60000, def: 3000, step: 250, unit: "s" },
        volTimeout:    { min: 100, max: 30000, def: 1200, step: 100, unit: "s" },
        fadeMs:        { min: 0,   max: 1500,  def: 150,  step: 25,  unit: " ms" },
        bgOpacity:     { min: 0,   max: 100,   def: Math.max(10, Math.round((Theme.bg.a ?? 1) * 20) * 5),     step: 5, unit: "%" },
        artOpacity:    { min: 0,   max: 100,   def: Math.max(20, Math.round((Theme.bgAlpha ?? 1) * 20) * 5), step: 5, unit: "%" },
        barOpacity:    { min: 0,   max: 100,   def: 90,   step: 5,   unit: "%" },
        barDimOpacity: { min: 0,   max: 100,   def: 30,   step: 5,   unit: "%" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showTips: true, showTitle: true, showArtist: true, showBar: true, showVisualizer: true,
        trackChangeOsd: true, showArt: true, showControls: true, musicOnly: true, artistBelow: false,
        portrait: true, showBorder: false, accentBars: false
    })
    readonly property var boolKeys: Object.keys(boolDefaults)
    readonly property var posKeys: ["offsetX", "offsetY", "volOffsetX", "volOffsetY"]

    property real offsetX: 0; property real offsetY: 0; property real volOffsetX: 0; property real volOffsetY: 0

    // Every key in numSpec needs a matching property here (mediaWidth was
    // missing, which collapsed the landscape card).
    property int mediaScale: numSpec.mediaScale.def; property int volScale: numSpec.volScale.def
    property int mediaWidth: numSpec.mediaWidth.def
    property int portraitWidth: numSpec.portraitWidth.def; property int flyoutWidth: numSpec.flyoutWidth.def
    property int artSize: numSpec.artSize.def; property int cardRadius: numSpec.cardRadius.def
    property int barCount: numSpec.barCount.def; property int barRadius: numSpec.barRadius.def
    property int barSpacing: numSpec.barSpacing.def; property int barHeight: numSpec.barHeight.def
    property int barFps: numSpec.barFps.def; property int mediaTimeout: numSpec.mediaTimeout.def
    property int volTimeout: numSpec.volTimeout.def; property int fadeMs: numSpec.fadeMs.def
    property int bgOpacity: numSpec.bgOpacity.def
    property int artOpacity: numSpec.artOpacity.def; property int barOpacity: numSpec.barOpacity.def
    property int barDimOpacity: numSpec.barDimOpacity.def

    property bool showTips: boolDefaults.showTips; property bool showTitle: boolDefaults.showTitle
    property bool showArtist: boolDefaults.showArtist; property bool showBar: boolDefaults.showBar
    property bool showVisualizer: boolDefaults.showVisualizer; property bool trackChangeOsd: boolDefaults.trackChangeOsd
    property bool showArt: boolDefaults.showArt; property bool showControls: boolDefaults.showControls
    property bool musicOnly: boolDefaults.musicOnly; property bool artistBelow: boolDefaults.artistBelow
    property bool portrait: boolDefaults.portrait; property bool showBorder: boolDefaults.showBorder
    property bool accentBars: boolDefaults.accentBars

    readonly property real scaleFactor: (showMedia ? mediaScale : volScale) / 100
    readonly property color cardColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bgOpacity / 100)
    readonly property real curX: showMedia ? offsetX : volOffsetX
    readonly property real curY: showMedia ? offsetY : volOffsetY
    readonly property bool mediaMoved: offsetX !== 0 || offsetY !== 0
    readonly property bool volMoved: volOffsetX !== 0 || volOffsetY !== 0
    readonly property bool modified: posKeys.some(k => root[k] !== 0)
        || numKeys.some(k => root[k] !== numSpec[k].def)
        || boolKeys.some(k => root[k] !== boolDefaults[k])
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/mediaosd-state.json"

    // ---- settings menu look / scale -----------------------------------------
    // Same scale system as the wallpaper picker's menu:
    //   ui            : screen height / 1080 (resolution independence)
    //   settingsScale : Theme.settingsScale (user's "settings scale" from hub.json)
    //   menuUi        : ui * settingsScale, multiplies every size in the settings menu.
    // menuUi is kept up to date by a Binding inside the settings window (it knows its screen).
    // Everything below falls back to the picker's defaults if Theme doesn't define it.
    readonly property real settingsScale: Theme.settingsScale ?? 1
    property real menuUi: settingsScale
    readonly property real menuRadius: Theme.radius ?? 20
    readonly property string menuFont: Theme.fontFamily ?? "JetBrains Mono"
    readonly property int menuAnimFast: Theme.animFast ?? 120
    readonly property int menuAnimMed: Theme.animMed ?? 220
    readonly property int textSizeSection: Theme.textSizeSection ?? 15
    readonly property int textSizeGroup: Theme.textSizeGroup ?? 12
    readonly property int textSizeBody: Theme.textSizeBody ?? 11
    readonly property int textSizeSmall: Theme.textSizeSmall ?? 10

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

    // ---- OSD state ---------------------------------------------------------
    property bool ready: false; property bool showing: false; property bool showMedia: false
    property bool pendingShow: false; property bool settingsOpen: false; property bool dragging: false
    property bool pinned: false
    property bool hovered: false     // driven by a Binding inside the OSD window
    property string hoverTip: ""     // tooltip text of the control under the pointer

    Timer { interval: 2000; running: true; onTriggered: root.ready = true }

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
        if (!ready) return
        if (showing) { hideTimer.restart(); return }
        pendingShow = true
        updateMedia()
    }

    function showMediaOsd() {
        pendingShow = false; showMedia = true; showing = true
        hideTimer.restart()
        updateMedia()
    }

    function triggerMediaOsd() { if (ready) showMediaOsd() }

    function openSettings() {
        pendingShow = false; settingsOpen = true; showMedia = true; showing = true
        hideTimer.restart()
    }

    function closeSettings() { settingsOpen = false; dragging = false; hideTimer.restart() }
    function toggleSettings() { settingsOpen ? closeSettings() : openSettings() }
    function togglePinned() { pinned = !pinned; hideTimer.restart() }
    function closeAll() { settingsOpen = false; dragging = false; showing = false }

    function finishPendingShow() {
        if (!pendingShow) return
        pendingShow = false; showMedia = playing; showing = true
        hideTimer.restart()
    }

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            showMedia = false; settingsOpen = false; dragging = false; pinned = false; hoverTip = ""
            unmountTimer.restart()
        }
    }

    onShowMediaChanged: { if (showMedia) updateMedia(); else bars = [] }

    IpcHandler {
        target: "mediaosd"
        function media(): void { root.triggerMediaOsd() }
        function settings(): void { root.openSettings() }
        function hide(): void { root.closeAll() }
    }

    // ---- settings helpers --------------------------------------------------
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

    // Only called while dragging; saved offsets are never rewritten by window resizes.
    function setPosition(x, y) {
        var nx = x, ny = y
        if (winW > 0 && winH > 0 && hitW > 0) {
            var minY = -topGap
            nx = Math.max(keepVisible - winW / 2 - hitW / 2, Math.min(winW / 2 - keepVisible + hitW / 2, x))
            ny = Math.max(minY, Math.min(Math.max(minY, winH - keepVisible - topGap), y))
        }
        if (showMedia) { offsetX = nx; offsetY = ny } else { volOffsetX = nx; volOffsetY = ny }
    }

    function resetPos(media) {
        if (media) { offsetX = 0; offsetY = 0 } else { volOffsetX = 0; volOffsetY = 0 }
        saveState()
    }

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
        posKeys.concat(numKeys, boolKeys).forEach(k => s[k] = root[k])
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
                Qt.callLater(() => win.reveal = Qt.binding(() => root.showing))
            }

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
                    cardScale: root.volScale / 100
                    xOffset: root.volOffsetX
                    yOffset: root.volOffsetY
                    open: win.reveal && root.showing && !root.showMedia
                    width: root.flyoutWidth
                    height: 28
                    radius: 36

                    HoverHandler { id: flyoutHover; enabled: flyout.open }
                    DragArea { anchors.fill: parent; enabled: flyout.open; scene: scene }

                    Text {
                        id: icon
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.muted ? "󰖁" : root.volume <= 0 ? "󰕿" : root.volume < 0.5 ? "󰖀" : "󰕾"
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
                    cardScale: root.mediaScale / 100
                    xOffset: root.offsetX
                    yOffset: root.offsetY
                    open: win.reveal && root.showing && root.showMedia
                    width: root.portrait ? root.portraitWidth : root.mediaWidth
                    height: mediaCol.height + 28
                    radius: root.cardRadius

                    readonly property bool artShown: root.showArt && root.artUrl !== "" && artImg.status !== Image.Error
                    readonly property bool hasText: root.showTitle || root.showArtist
                    readonly property bool barShown: root.showBar && root.showVisualizer
                    readonly property bool lineShown: root.showBar && !root.showVisualizer

                    HoverHandler { id: mediaHover; enabled: mediaPanel.open }

                    // Declared before the content so buttons stay clickable on top.
                    DragArea { anchors.fill: parent; enabled: mediaPanel.open; scene: scene }

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
                                    height: Math.max(3, ((root.bars[index] ?? 0) / 100) * visualizer.height)
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

                // ---- tools bar under the card: hint text + pin ----
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

                    HoverHandler { id: toolsHover; enabled: root.showing }

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

                    // Larger pin button: bigger hit area + glyph, hover highlight,
                    // always reasonably visible (was a tiny 18px, 30% opacity button).
                    FooterButton {
                        id: pinButton
                        visible: root.showMedia
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
    // Fixed size on purpose (content-driven height can leave a blank first frame).
    // Every size below is multiplied by `u` (= ui * Theme.settingsScale), exactly like the
    // wallpaper picker's menu, so both menus scale together.
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin

            readonly property real ui: (screen?.height ?? 1080) / 1080
            readonly property real u: ui * root.settingsScale

            color: "transparent"
            implicitWidth: 440 * u
            implicitHeight: Math.min(600 * u, (screen?.height ?? 800) * 0.85)
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mediaosd-settings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // Shares the scale with the reusable components (they read root.menuUi).
            Binding { target: root; property: "menuUi"; value: settingsWin.u }

            Rectangle {
                anchors.fill: parent
                radius: root.menuRadius * settingsWin.u
                color: Theme.bg
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.12)
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.closeSettings()

                Item {
                    id: head
                    anchors.top: parent.top
                    width: parent.width
                    height: 54 * settingsWin.u

                    Text {
                        x: 20 * settingsWin.u; y: 10 * settingsWin.u
                        text: "OSD settings"
                        font.family: root.menuFont
                        font.pixelSize: root.textSizeSection * settingsWin.u
                        font.bold: true
                        color: Theme.text
                    }
                    Text {
                        x: 20 * settingsWin.u; y: 31 * settingsWin.u
                        text: "Drag to move it. Right-click to open settings"
                        font.family: root.menuFont
                        font.pixelSize: root.textSizeSmall * settingsWin.u
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
                        font.family: root.menuFont
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

                    Column {
                        id: contentCol
                        x: 20 * settingsWin.u
                        width: flick.width - 48 * settingsWin.u

                        SectionHeader { text: "Global" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            ToggleRow { key: "showTips"; label: "Tooltips" }
                            SliderRow { key: "fadeMs"; label: "Animation" }
                            SliderRow { key: "mediaScale"; label: "Media scale" }
                            SliderRow { key: "volScale"; label: "Volume scale" }
                        }

                        SectionHeader { text: "Content" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            ToggleRow { key: "showArt"; label: "Album art" }
                            ToggleRow { key: "showTitle"; label: "Title" }
                            ToggleRow { key: "showArtist"; label: "Artist" }
                            ToggleRow { key: "showControls"; label: "Controls" }
                            ToggleRow { key: "showBar"; label: "Visualizer & bar" }
                            ToggleRow { key: "showVisualizer"; label: "Visualizer"; enabled: root.showBar }
                        }

                        SectionHeader { text: "Layout" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            ToggleRow { key: "portrait"; label: "Portrait" }
                            ToggleRow {
                                key: "artistBelow"
                                label: "Artist below"
                                checked: root.artistBelow || root.portrait
                                enabled: !root.portrait && root.showTitle && root.showArtist
                            }
                            ToggleRow { key: "showBorder"; label: "Border" }
                            SliderRow { key: root.portrait ? "portraitWidth" : "mediaWidth"; label: "Width" }
                            SliderRow { key: "artSize"; label: "Art size"; enabled: root.showArt && !root.portrait }
                            SliderRow { key: "cardRadius"; label: "Corner radius" }
                        }

                        SectionHeader { text: "Visualizer" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            SliderRow { key: "barCount"; label: "Bars"; enabled: root.showBar && root.showVisualizer }
                            SliderRow { key: "barSpacing"; label: "Spacing"; enabled: root.showBar && root.showVisualizer }
                            SliderRow { key: "barHeight"; label: "Height"; enabled: root.showBar }
                            SliderRow { key: "barRadius"; label: "Round"; enabled: root.showBar }
                            SliderRow { key: "barFps"; label: "Frame rate"; enabled: root.showBar && root.showVisualizer }
                            ToggleRow { key: "accentBars"; label: "Accent colour"; enabled: root.showBar }
                        }

                        SectionHeader { text: "Opacity" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            SliderRow { key: "bgOpacity"; label: "Background" }
                            SliderRow { key: "artOpacity"; label: "Album art"; enabled: root.showArt }
                            SliderRow { key: "barOpacity"; label: "Bars played"; enabled: root.showBar }
                            SliderRow { key: "barDimOpacity"; label: "Bars remaining"; enabled: root.showBar }
                        }

                        SectionHeader { text: "Behavior" }
                        Grid {
                            width: parent.width; columns: 2; columnSpacing: 18 * settingsWin.u
                            ToggleRow { key: "musicOnly"; label: "Music only" }
                            ToggleRow { key: "trackChangeOsd"; label: "On track change" }
                            SliderRow { key: "mediaTimeout"; label: "Media hide after" }
                            SliderRow { key: "volTimeout"; label: "Volume hide after" }
                        }

                        SectionHeader { text: "Position" }
                        Row {
                            spacing: 8 * settingsWin.u
                            ActionButton { label: "Reset media position"; enabled: root.mediaMoved; onClicked: root.resetPos(true) }
                            ActionButton { label: "Reset volume position"; enabled: root.volMoved; onClicked: root.resetPos(false) }
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

                    ActionButton {
                        x: 20 * settingsWin.u
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Reset all"
                        enabled: root.modified
                        onClicked: root.resetAll()
                    }

                    ActionButton {
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

    // ---- reusable components -----------------------------------------------
    component OsdCard: Rectangle {
        property bool open: false
        property var host: root
        property real xOffset: 0
        property real yOffset: 0
        property real cardScale: 1

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
        scale: (open ? 1 : 0.9) * cardScale

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
            startX = host.curX; startY = host.curY
            host.dragging = true
        }
        onPositionChanged: mouse => {
            if (!host.dragging) return
            var p = da.mapToItem(da.scene, mouse.x, mouse.y)
            host.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
        }
        onReleased: finish()
        onCanceled: finish()
        onDoubleClicked: mouse => { if (mouse.button === Qt.LeftButton) host.resetPos(host.showMedia) }
    }

    // ---- settings-menu components (all sizes scale with host.menuUi) --------
    component ActionButton: Rectangle {
        id: ab
        property var host: root
        property string label: ""
        property bool primary: false
        readonly property real u: host.menuUi
        signal clicked()

        implicitWidth: abText.implicitWidth + 28 * u
        width: implicitWidth
        height: 30 * u
        radius: Math.min(height / 2, ab.host.menuRadius * u)
        opacity: enabled ? 1 : 0.4
        color: primary ? Theme.accent : Theme.alpha(Theme.text, abArea.containsMouse && enabled ? 0.18 : 0.1)
        Behavior on color { ColorAnimation { duration: ab.host.menuAnimFast } }

        Text {
            id: abText
            anchors.centerIn: parent
            text: ab.label
            font.family: ab.host.menuFont
            font.pixelSize: ab.host.textSizeBody * ab.u
            font.bold: true
            color: ab.primary ? Theme.bg : Theme.text
        }

        MouseArea { id: abArea; anchors.fill: parent; hoverEnabled: true; enabled: ab.enabled; onClicked: ab.clicked() }
    }

    component SectionHeader: Item {
        id: sh
        property var host: root
        property string text: ""
        readonly property real u: host.menuUi
        width: parent?.width ?? 0
        height: 26 * u

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3 * sh.u
            text: sh.text
            font.family: sh.host.menuFont
            font.pixelSize: sh.host.textSizeSmall * sh.u
            font.bold: true
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
            color: Theme.textDim
        }
    }

    component ToggleRow: Item {
        id: tr
        property var host: root
        property string key: ""
        property string label: ""
        property bool checked: host[key]
        readonly property real u: host.menuUi

        width: host.cellW(parent)
        height: 28 * u
        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6 * tr.u
            anchors.rightMargin: -6 * tr.u
            radius: Math.min(8 * tr.u, tr.host.menuRadius * tr.u)
            color: trArea.containsMouse && tr.enabled ? Theme.alpha(Theme.text, 0.06) : "transparent"
        }

        Text {
            anchors.left: parent.left
            anchors.right: sw.left
            anchors.rightMargin: 8 * tr.u
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            elide: Text.ElideRight
            font.family: tr.host.menuFont
            font.pixelSize: tr.host.textSizeGroup * tr.u
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
            Behavior on color { ColorAnimation { duration: tr.host.menuAnimMed } }

            Rectangle {
                width: 12 * tr.u; height: 12 * tr.u; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: tr.checked ? parent.width - width - 3 * tr.u : 3 * tr.u
                color: tr.checked ? Theme.bg : Theme.text
                Behavior on x { NumberAnimation { duration: tr.host.menuAnimMed; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea { id: trArea; anchors.fill: parent; hoverEnabled: true; enabled: tr.enabled; onClicked: tr.host.toggleSetting(tr.key) }
    }

    // Minimal slider bound to a numSpec entry on the host; saves on release.
    component SliderRow: Item {
        id: sr
        property var host: root
        property string key: ""
        property string label: ""
        readonly property real u: host.menuUi

        readonly property var spec: host.numSpec[key]
        readonly property real ratio: Math.max(0, Math.min(1, (host[key] - spec.min) / (spec.max - spec.min)))

        width: host.cellW(parent)
        height: 38 * u
        opacity: enabled ? 1 : 0.4

        Text {
            anchors.left: parent.left; anchors.right: srValue.left; anchors.rightMargin: 6 * sr.u; y: 4 * sr.u
            elide: Text.ElideRight
            text: sr.label
            font.family: sr.host.menuFont
            font.pixelSize: sr.host.textSizeGroup * sr.u
            font.bold: true
            color: Theme.text
        }
        Text {
            id: srValue
            anchors.right: parent.right; y: 5 * sr.u
            text: sr.host.fmtValue(sr.key, sr.host[sr.key])
            font.family: sr.host.menuFont
            font.pixelSize: sr.host.textSizeBody * sr.u
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

            Rectangle { width: knob.x + knob.width / 2; height: parent.height; radius: parent.radius; color: Theme.accent }

            Rectangle {
                id: knob
                width: 14 * sr.u; height: 14 * sr.u; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: sr.ratio * (track.width - width)
                color: Theme.text
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: 18 * sr.u
            preventStealing: true
            enabled: sr.enabled

            function apply(mx) {
                var usable = track.width - knob.width
                if (usable <= 0) return
                var r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable)), s = sr.spec
                sr.host.setNumber(sr.key, s.min + Math.round(r * (s.max - s.min) / s.step) * s.step)
            }

            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
            onReleased: sr.host.saveState()
        }
    }
}