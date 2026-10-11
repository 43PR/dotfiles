import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Scope {

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "mediaosd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: root.showing ? hitbox : null }

    readonly property int topGap: 30
    readonly property int keepVisible: 40
    readonly property int toolsHeight: 22

    readonly property var numSpec: ({
        osdScale:      { min: 70,   max: 160,   def: 100,  step: 10,  unit: "%" },
        mediaWidth:    { min: 300,  max: 600,   def: 420,  step: 20,  unit: "px" },
        portraitWidth: { min: 200,  max: 400,   def: 260,  step: 20,  unit: "px" },
        flyoutWidth:   { min: 200,  max: 500,   def: 320,  step: 20,  unit: "px" },
        barCount:      { min: 8,    max: 48,    def: 24,   step: 4,   unit: "" },
        barRadius:     { min: 0,    max: 20,    def: 20,   step: 2,   unit: "px", full: true },
        mediaTimeout:  { min: 1000, max: 10000, def: 3000, step: 500, unit: "s" },
        volTimeout:    { min: 600,  max: 5000,  def: 1200, step: 200, unit: "s" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showVisualizer: true,
        trackChangeOsd: true,
        showArt: true,
        musicOnly: true,
        artistBelow: false,
        portrait: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    readonly property var posKeys: ["offsetX", "offsetY", "volOffsetX", "volOffsetY"]

    property real offsetX: 0
    property real offsetY: 0
    property real volOffsetX: 0
    property real volOffsetY: 0

    property int osdScale: numSpec.osdScale.def
    property int mediaWidth: numSpec.mediaWidth.def
    property int portraitWidth: numSpec.portraitWidth.def
    property int flyoutWidth: numSpec.flyoutWidth.def
    property int barCount: numSpec.barCount.def
    property int barRadius: numSpec.barRadius.def
    property int mediaTimeout: numSpec.mediaTimeout.def
    property int volTimeout: numSpec.volTimeout.def

    property bool showVisualizer: boolDefaults.showVisualizer
    property bool trackChangeOsd: boolDefaults.trackChangeOsd
    property bool showArt: boolDefaults.showArt
    property bool musicOnly: boolDefaults.musicOnly
    property bool artistBelow: boolDefaults.artistBelow
    property bool portrait: boolDefaults.portrait

    readonly property real scaleFactor: osdScale / 100
    readonly property real curX: showMedia ? offsetX : volOffsetX
    readonly property real curY: showMedia ? offsetY : volOffsetY

    readonly property bool mediaMoved: offsetX !== 0 || offsetY !== 0
    readonly property bool volumeMoved: volOffsetX !== 0 || volOffsetY !== 0

    readonly property bool movedFromDefault: mediaMoved || volumeMoved
        || osdScale !== numSpec.osdScale.def
        || mediaWidth !== numSpec.mediaWidth.def
        || portraitWidth !== numSpec.portraitWidth.def
        || flyoutWidth !== numSpec.flyoutWidth.def
        || barCount !== numSpec.barCount.def
        || barRadius !== numSpec.barRadius.def
        || mediaTimeout !== numSpec.mediaTimeout.def
        || volTimeout !== numSpec.volTimeout.def
        || showVisualizer !== boolDefaults.showVisualizer
        || trackChangeOsd !== boolDefaults.trackChangeOsd
        || showArt !== boolDefaults.showArt
        || musicOnly !== boolDefaults.musicOnly
        || artistBelow !== boolDefaults.artistBelow
        || portrait !== boolDefaults.portrait

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/mediaosd-state.json"

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

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.triggerOsd() }
        function onMutedChanged() { root.triggerOsd() }
    }

    property bool ready: false
    property bool showing: false
    property bool showMedia: false
    property bool pendingShow: false
    property bool settingsOpen: false
    property string settingsTab: "media"
    property bool dragging: false
    property bool pinned: false
    readonly property bool hovered: flyoutHover.hovered || mediaHover.hovered || toolsHover.hovered

    readonly property Item activeCard: showMedia ? mediaPanel : flyout

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
        if (ready && !(settingsOpen && settingsTab === "volume"))
            showMediaOsd()
    }

    function openSettings() {
        var volumeTab = showing && !showMedia
        pendingShow = false
        settingsTab = volumeTab ? "volume" : "media"
        settingsOpen = true
        showMedia = !volumeTab
        showing = true
        hideTimer.restart()
        Qt.callLater(reposition)
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

    function setSettingsTab(tab) {
        settingsTab = tab
        if (tab === "media")
            showMedia = true
        else if (tab === "volume")
            showMedia = false
        hideTimer.restart()
        Qt.callLater(reposition)
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
        if (!showing) {
            showMedia = false
            settingsOpen = false
            dragging = false
            pinned = false
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

    function setPosition(x, y) {
        var nx = x
        var ny = y
        if (width > 0 && height > 0) {
            var w = hitbox.width
            var minX = keepVisible - width / 2 - w / 2
            var maxX = width / 2 - keepVisible + w / 2
            var minY = -topGap
            var maxY = Math.max(minY, height - keepVisible - topGap)
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

    function resetPosition() {
        resetPos(showMedia)
    }

    function reposition() {
        if (showing)
            setPosition(curX, curY)
    }

    onOsdScaleChanged: reposition()
    onMediaWidthChanged: reposition()
    onFlyoutWidthChanged: reposition()
    onPortraitChanged: reposition()
    onPortraitWidthChanged: reposition()

    function setNumber(key, v) {
        var s = numSpec[key]
        root[key] = clamp(v, s.min, s.max)
    }

    function toggleSetting(key) {
        root[key] = !root[key]
        saveState()
    }

    function resetKey(key) {
        root[key] = numSpec[key].def
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
        interval: 500
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

    onBarCountChanged: {
        if (cavaProcess.running) {
            cavaPaused = true
            cavaResume.restart()
        }
    }

    Process {
        id: cavaProcess

        running: root.showing && root.showMedia && root.showVisualizer && !root.cavaPaused

        command: [
            "sh", "-c",
            "printf '%s\\n' " +
            "'[general]' 'bars = " + root.barCount + "' 'framerate = 30' " +
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

    Item {
        id: scene
        anchors.fill: parent

        Item {
            id: hitbox
            width: root.activeCard.width * root.scaleFactor
            height: (root.activeCard.height + root.toolsHeight) * root.scaleFactor
            x: (scene.width - width) / 2 + root.curX
            y: root.topGap + root.curY
        }

        OsdCard {
            id: flyout
            host: root
            xOffset: root.volOffsetX
            yOffset: root.volOffsetY
            open: root.showing && !root.showMedia
            width: root.flyoutWidth
            height: 28
            radius: 36

            HoverHandler {
                id: flyoutHover
                enabled: flyout.open
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

        OsdCard {
            id: mediaPanel
            host: root
            xOffset: root.offsetX
            yOffset: root.offsetY
            open: root.showing && root.showMedia
            width: root.portrait ? root.portraitWidth : root.mediaWidth
            height: mediaCol.height + 28
            radius: 24

            readonly property bool artShown: root.showArt
                && root.artUrl !== "" && artImg.status !== Image.Error

            onHeightChanged: root.reposition()

            HoverHandler {
                id: mediaHover
                enabled: mediaPanel.open
            }

            MouseArea {
                anchors.fill: parent
                enabled: mediaPanel.open
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
                    readonly property real artSize: mediaPanel.artShown ? (root.portrait ? width : 52) : 0
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
                    height: 20
                    readonly property real barSpacing: 3
                    readonly property real barWidth: (width - barSpacing * (root.barCount - 1)) / root.barCount

                    Repeater {
                        model: root.barCount
                        Rectangle {
                            required property int index
                            x: index * (visualizer.barWidth + visualizer.barSpacing)
                            width: visualizer.barWidth
                            radius: Math.min(root.barRadius, width / 2)
                            color: Theme.text
                            opacity: ((index + 0.5) / root.barCount) <= root.progress ? 0.9 : 0.3
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
                    height: 20

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: Math.min(root.barRadius, 2)
                        color: Theme.text
                        opacity: 0.3
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * root.progress
                        height: 4
                        radius: Math.min(root.barRadius, 2)
                        color: Theme.text
                        opacity: 0.9
                    }
                }

                Item {
                    width: parent.width
                    height: 26

                    Row {
                        anchors.centerIn: parent
                        spacing: 28

                        GlyphButton {
                            text: "󰒮"
                            font.pixelSize: 19
                            onClicked: root.mediaCmd("previous")
                        }
                        GlyphButton {
                            text: root.playing ? "󰏤" : "󰐊"
                            font.pixelSize: 21
                            onClicked: root.mediaCmd("play-pause")
                        }
                        GlyphButton {
                            text: "󰒭"
                            font.pixelSize: 19
                            onClicked: root.mediaCmd("next")
                        }
                    }
                }
            }
        }

        Item {
            id: tools
            width: root.activeCard.width
            height: root.toolsHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.curX
            anchors.top: parent.top
            anchors.topMargin: root.topGap + root.curY + root.activeCard.height * root.scaleFactor
            transformOrigin: Item.Top
            scale: root.scaleFactor
            visible: opacity > 0
            opacity: (root.showing && (root.hovered || root.dragging)) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            HoverHandler {
                id: toolsHover
                enabled: root.showing
            }

            Item {
                anchors.centerIn: parent
                width: 60
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 36; height: 4; radius: 2
                    color: Theme.text
                    opacity: (dragArea.containsMouse || root.dragging) ? 1 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                DragArea {
                    id: dragArea
                    anchors.fill: parent
                    host: root
                    scene: scene
                }
            }

            FooterButton {
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
            }

            FooterButton {
                id: settingsButton
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
            }
        }
    }
}

PanelWindow {
    id: settingsWin

    visible: root.settingsOpen
    color: "transparent"
    implicitWidth: 420
    implicitHeight: layout.height
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "mediaosd-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property real maxContent: Math.max(240, (screen?.height ?? 800) * 0.85 - 186)

    Connections {
        target: root
        function onSettingsTabChanged() { flick.contentY = 0 }
    }

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

        Column {
            id: layout
            width: parent.width

            Item {
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
                    text: "Changes apply live and are saved automatically"
                    font.pixelSize: 10
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

            Item {
                width: parent.width
                height: 40

                Rectangle {
                    x: 20
                    width: parent.width - 40
                    height: 32
                    radius: 16
                    color: Theme.alpha(Theme.text, 0.08)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4

                        TabButton {
                            width: parent.width / 3
                            label: "Media"
                            selected: root.settingsTab === "media"
                            onClicked: root.setSettingsTab("media")
                        }
                        TabButton {
                            width: parent.width / 3
                            label: "Volume"
                            selected: root.settingsTab === "volume"
                            onClicked: root.setSettingsTab("volume")
                        }
                        TabButton {
                            width: parent.width / 3
                            label: "General"
                            selected: root.settingsTab === "general"
                            onClicked: root.setSettingsTab("general")
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 30

                Text {
                    x: 20
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    font.pixelSize: 10
                    color: Theme.textDim
                    text: root.settingsTab === "media"
                        ? "Choose what the media popup shows. Drag its handle to move it."
                        : root.settingsTab === "volume"
                            ? "The volume popup stays open while you adjust these."
                            : "Options that apply to both popups."
                }
            }

            Flickable {
                id: flick
                width: parent.width
                height: Math.min(contentCol.height + 12, settingsWin.maxContent)
                contentWidth: width
                contentHeight: contentCol.height + 12
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contentCol
                    x: 20
                    width: flick.width - 40

                    Column {
                        visible: root.settingsTab === "media"
                        width: parent.width

                        SectionHeader { text: "Content" }
                        ToggleRow { host: root; key: "showArt"; label: "Album art"; checked: root.showArt }
                        ToggleRow { host: root; key: "showVisualizer"; label: "Visualizer"; checked: root.showVisualizer }

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
                            key: "mediaWidth"
                            label: "Width"
                            value: root.mediaWidth
                            enabled: !root.portrait
                        }
                        SliderRow {
                            host: root
                            key: "portraitWidth"
                            label: "Portrait width"
                            value: root.portraitWidth
                            enabled: root.portrait
                        }
                        SliderRow {
                            host: root
                            key: "barCount"
                            label: "Visualizer bars"
                            value: root.barCount
                            enabled: root.showVisualizer
                        }
                        SliderRow {
                            host: root
                            key: "barRadius"
                            label: "Roundness"
                            value: root.barRadius
                        }

                        SectionHeader { text: "Behavior" }
                        ToggleRow { host: root; key: "musicOnly"; label: "Music players only"; checked: root.musicOnly }
                        ToggleRow { host: root; key: "trackChangeOsd"; label: "Pop up on track change"; checked: root.trackChangeOsd }
                        SliderRow {
                            host: root
                            key: "mediaTimeout"
                            label: "Hide after"
                            value: root.mediaTimeout
                        }
                    }

                    Column {
                        visible: root.settingsTab === "volume"
                        width: parent.width

                        SectionHeader { text: "Appearance" }
                        SliderRow {
                            host: root
                            key: "flyoutWidth"
                            label: "Width"
                            hint: "Width of the volume popup"
                            value: root.flyoutWidth
                        }

                        SectionHeader { text: "Behavior" }
                        SliderRow {
                            host: root
                            key: "volTimeout"
                            label: "Hide after"
                            hint: "How long the popup stays after a volume change"
                            value: root.volTimeout
                        }
                    }

                    Column {
                        visible: root.settingsTab === "general"
                        width: parent.width

                        SectionHeader { text: "Size" }
                        SliderRow {
                            host: root
                            key: "osdScale"
                            label: "Scale"
                            hint: "Resizes both popups"
                            value: root.osdScale
                        }

                        SectionHeader { text: "Position" }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            font.pixelSize: 10
                            color: Theme.textDim
                            text: "Hover a popup and drag the handle underneath to move it. Media and volume remember their own spots. Double-click the handle to reset it."
                        }
                        Item { width: 1; height: 10 }
                        Row {
                            spacing: 8
                            ActionButton {
                                label: "Reset media position"
                                enabled: root.mediaMoved
                                onClicked: root.resetPos(true)
                            }
                            ActionButton {
                                label: "Reset volume position"
                                enabled: root.volumeMoved
                                onClicked: root.resetPos(false)
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 58

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.alpha(Theme.text, 0.08)
                }

                ActionButton {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Reset all"
                    enabled: root.movedFromDefault
                    onClicked: root.resetAll()
                }
                ActionButton {
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

component OsdCard: Rectangle {
    property bool open: false
    property var host
    property real xOffset: 0
    property real yOffset: 0

    color: Theme.bg
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: xOffset
    anchors.top: parent.top
    anchors.topMargin: host.topGap + yOffset
    transformOrigin: Item.Top
    opacity: open ? 1 : 0
    visible: opacity > 0
    scale: (open ? 1 : 0.9) * host.scaleFactor

    Behavior on opacity { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
    signal clicked()
    font.family: "Symbols Nerd Font"
    color: Theme.text
    MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
}

component DragArea: MouseArea {
    id: da
    property var host
    property Item scene
    property real pressX: 0
    property real pressY: 0
    property real startX: 0
    property real startY: 0

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

    function finish() {
        if (!host.dragging)
            return
        host.dragging = false
        host.saveState()
    }

    onPressed: function (mouse) {
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
    onDoubleClicked: host.resetPosition()
}

component TabButton: Rectangle {
    id: tb
    property string label: ""
    property bool selected: false
    signal clicked()

    height: 24
    radius: 12
    color: selected ? Theme.accent : (tbArea.containsMouse ? Theme.alpha(Theme.text, 0.08) : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: tb.label
        font.pixelSize: 11
        font.bold: true
        color: tb.selected ? Theme.bg : Theme.textDim
    }

    MouseArea {
        id: tbArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tb.clicked()
    }
}

component ActionButton: Rectangle {
    id: ab
    property string label: ""
    property bool primary: false
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

    width: parent?.width ?? 0
    height: 34
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
        onClicked: tr.host.toggleSetting(tr.key)
    }
}

component SliderRow: Item {
    id: sl
    property var host
    property string key: ""
    property string label: ""
    property string hint: ""
    property real value: 0

    readonly property var spec: host.numSpec[key]
    readonly property real range: spec.max - spec.min
    readonly property real frac: (value - spec.min) / range
    readonly property real defFrac: (spec.def - spec.min) / range
    readonly property bool changed: value !== spec.def

    width: parent?.width ?? 0
    height: hint !== "" ? 62 : 48
    opacity: enabled ? 1 : 0.4

    Text {
        x: 0; y: 4
        text: sl.label
        font.pixelSize: 12
        font.bold: true
        color: Theme.text
    }

    Text {
        visible: sl.hint !== ""
        x: 0; y: 21
        width: parent.width - 80
        text: sl.hint
        elide: Text.ElideRight
        font.pixelSize: 10
        color: Theme.textDim
    }

    Row {
        anchors.right: parent.right
        y: 3
        spacing: 6

        Text {
            text: sl.host.fmtValue(sl.key, sl.value)
            font.pixelSize: 11
            font.bold: true
            color: Theme.text
        }
        Text {
            width: 14
            text: "↺"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 13
            color: resetArea.containsMouse ? Theme.accent : Theme.textDim
            opacity: sl.changed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: sl.changed
                onClicked: sl.host.resetKey(sl.key)
            }
        }
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        height: 20

        readonly property real knobSize: 14
        readonly property real span: Math.max(1, width - knobSize)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.alpha(Theme.text, 0.18)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: track.knobSize / 2 + sl.defFrac * track.span - 1
            width: 2; height: 8; radius: 1
            color: Theme.alpha(Theme.text, 0.35)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: sl.frac * track.span + track.knobSize / 2
            height: 4
            radius: 2
            color: Theme.accent
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: sl.frac * track.span
            width: track.knobSize; height: track.knobSize; radius: track.knobSize / 2
            color: Theme.text
            scale: slArea.pressed ? 1.2 : (slArea.containsMouse ? 1.1 : 1)
            Behavior on scale { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: slArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true

            function setFromX(mx) {
                var f = Math.max(0, Math.min(1, (mx - track.knobSize / 2) / track.span))
                var steps = Math.round(f * sl.range / sl.spec.step)
                var v = Math.min(sl.spec.max, sl.spec.min + steps * sl.spec.step)
                if (v !== sl.value)
                    sl.host.setNumber(sl.key, v)
            }

            onPressed: function (mouse) { setFromX(mouse.x) }
            onPositionChanged: function (mouse) { if (pressed) setFromX(mouse.x) }
            onReleased: sl.host.saveState()
            onCanceled: sl.host.saveState()
        }
    }
}

}