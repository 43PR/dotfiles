import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main

    // ---- Resolution independence -----------------------------------------
    // ui  : vertical / general scale (1.0 at 1080p height). Heights, fonts, borders.
    // uiW : horizontal scale (1.0 at 1920px width). Every horizontal distance.
    readonly property real ui: Screen.height / 1080
    readonly property real uiW: Screen.width / 1920
    readonly property real screenW: Screen.width
    readonly property real refHeight: 500
    // -----------------------------------------------------------------------

    // ---- Settings spec ----------------------------------------------------
    // One entry per slider in the menu. To add an option:
    //   1. add it here, 2. add a matching `property real <key>` below,
    //   3. add a `SliderRow { key: "<key>" ... }` to the panel, 4. use it in the carousel.
    // mult/dec/unit only affect how the value is *displayed*.
    readonly property var numSpec: ({
        tileCount:          { min: 3,    max: 20,   def: 10,   step: 1,    dec: 0, mult: 1,   unit: "" },
        globalScale:        { min: 0.5,  max: 1.5,  def: 1.0,  step: 0.05, dec: 0, mult: 100, unit: "%" },
        zoomScale:          { min: 0.3,  max: 1.2,  def: 0.4,  step: 0.05, dec: 0, mult: 100, unit: "%" },
        edgeScale:          { min: 0.1,  max: 1.0,  def: 0.7,  step: 0.05, dec: 0, mult: 100, unit: "%" },
        edgeSpacing:        { min: -200, max: 600,  def: 130,  step: 10,   dec: 0, mult: 1,   unit: " px" },
        edgeCurve:          { min: 1,    max: 4,    def: 1,    step: 0.25, dec: 2, mult: 1,   unit: "" },
        baseSpacing:        { min: 0,    max: 100,  def: 0,    step: 2,    dec: 0, mult: 1,   unit: " px" },
        skewFactor:         { min: -0.5, max: 0.5,  def: 0,    step: 0.05, dec: 2, mult: 1,   unit: "" },
        shadowOpacity:      { min: 0,    max: 1,    def: 0.4,  step: 0.05, dec: 0, mult: 100, unit: "%" },
        sizeCurve:          { min: 0.5,  max: 3,    def: 1.75, step: 0.25, dec: 2, mult: 1,   unit: "" },
        tiltAngle:          { min: -80,  max: 80,   def: -25,  step: 5,    dec: 0, mult: 1,   unit: "°" },
        tiltDepth:          { min: 1,    max: 8,    def: 3,    step: 0.5,  dec: 1, mult: 1,   unit: "×" },
        tiltCurve:          { min: 1,    max: 3,    def: 1.25, step: 0.25, dec: 2, mult: 1,   unit: "" },
        animDuration:       { min: 100,  max: 2000, def: 1000, step: 50,   dec: 0, mult: 1,   unit: " ms" },
        transitionDuration: { min: 0.2,  max: 3,    def: 1,    step: 0.1,  dec: 1, mult: 1,   unit: " s" },
        activeOpacity:      { min: 0.1,  max: 1,    def: 1.0,  step: 0.05, dec: 0, mult: 100, unit: "%" },
        inactiveOpacity:    { min: 0,    max: 1,    def: 0.8,  step: 0.05, dec: 0, mult: 100, unit: "%" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({ shadowEnabled: true })
    readonly property var boolKeys: Object.keys(boolDefaults)

    // Wallpaper change transition (passed to commands.sh -> awww)
    readonly property var transitions: ["fade", "wipe", "grow", "outer", "wave", "center", "any", "random"]
    readonly property string transitionDefault: "outer"
    property string transition: transitionDefault

    // tileCount follows config.json (number_of_pictures) until you change it in the menu.
    property real tileCount: configs.number_of_pictures
    // Scales the whole carousel (tiles, gaps, edge pull-in, tilt) around the screen center.
    property real globalScale: numSpec.globalScale.def
    property real zoomScale: numSpec.zoomScale.def
    property real edgeScale: numSpec.edgeScale.def
    property real edgeSpacing: numSpec.edgeSpacing.def   // px @1920 wide, how far outer tiles are pulled inward
    property real edgeCurve: numSpec.edgeCurve.def       // 1 = linear, 2 = quadratic, 4 = only the very edge
    // How tile size falls off from center to the screen edge: 1 = steady (linear), higher = stay big
    // longer then shrink near the edges, lower = shrink quickly near the center.
    property real sizeCurve: numSpec.sizeCurve.def
    property real baseSpacing: numSpec.baseSpacing.def   // px @1920 wide
    property real skewFactor: numSpec.skewFactor.def
    // 3D tilt: rotation around the vertical axis, growing toward the screen edges.
    property real tiltAngle: numSpec.tiltAngle.def       // degrees reached at the screen edge (negative = flips direction)
    property real tiltDepth: numSpec.tiltDepth.def       // camera distance in tile widths (lower = stronger perspective)
    property real tiltCurve: numSpec.tiltCurve.def       // 1 = linear with distance from center, higher = only near the edges
    property real shadowOpacity: numSpec.shadowOpacity.def
    property real activeOpacity: numSpec.activeOpacity.def       // selected tile
    property real inactiveOpacity: numSpec.inactiveOpacity.def   // all other tiles
    property real animDuration: numSpec.animDuration.def
    property real transitionDuration: numSpec.transitionDuration.def   // seconds, awww transition length
    property bool shadowEnabled: boolDefaults.shadowEnabled

    // Not in the menu (yet)
    property int speed: 5000
    property color shadowColor: '#000000'
    property real shadowX: 4
    property real shadowY: 4

    property string wallpaperPath: configs.wallpaper_path.replace("$HOME", Quickshell.env("HOME"))
    property string cachePath: configs.cache_path.replace("$HOME", Quickshell.env("HOME"))

    // ---- Menu look ----------------------------------------------------------
    // Self-contained copy of the bits of Theme.qml the menu needs. It reads the same
    // files (palette + hub.json), so colours/radius/scale match the rest of the shell
    // without needing the Theme singleton to be importable from this folder.
    readonly property QtObject th: QtObject {
        property var palette: ({})
        property real bgAlpha: 0.7
        property real settingsScale: 1.0
        property real borderOpacity: 1.0
        property int radius: 10

        readonly property string fontFamily: "JetBrains Mono"
        readonly property int animFast: 120
        readonly property int animMed: 220
        readonly property int textSizeSection: 15
        readonly property int textSizeGroup: 12
        readonly property int textSizeBody: 11
        readonly property int textSizeSmall: 10

        function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

        readonly property color text: palette.text || "#ffffff"
        readonly property color textDim: palette.textDim || "#c2c2c2"
        readonly property color bgPanel: palette.bgPanel || "#050505"
        readonly property color accentSolid: palette.accent || "#ffffff"
        readonly property color accent: alpha(accentSolid, borderOpacity)
        readonly property color bg: alpha(palette.bg || "#000000", bgAlpha)
    }

    // Theme.settingsScale scales the whole menu, like it does for the settings window.
    readonly property real menuUi: ui * th.settingsScale

    FileView {
        path: Quickshell.env("HOME") + "/.cache/43pr/quickshell-theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { main.th.palette = JSON.parse(text()) }
            catch (e) { console.warn("wallpaper picker: malformed quickshell-theme.json:", e) }
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/state/hub.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const h = JSON.parse(text())
                if (typeof h.bgAlpha === "number") main.th.bgAlpha = Math.max(0, Math.min(1, h.bgAlpha))
                if (typeof h.settingsScale === "number") main.th.settingsScale = Math.max(0.6, Math.min(1.2, h.settingsScale))
                if (typeof h.borderOpacity === "number") main.th.borderOpacity = Math.max(0.1, Math.min(1, h.borderOpacity))
                if (typeof h.radius === "number") main.th.radius = Math.round(Math.max(0, Math.min(50, h.radius)))
            } catch (e) { console.warn("wallpaper picker: malformed hub.json:", e) }
        }
    }

    // ---- Settings state / helpers ----------------------------------------
    property bool settingsOpen: false
    function openSettings() { settingsOpen = true }
    function closeSettings() { settingsOpen = false }
    function toggleSettings() { settingsOpen = !settingsOpen }

    function defOf(key) { return key === "tileCount" ? configs.number_of_pictures : numSpec[key].def }

    readonly property bool modified:
        numKeys.some(k => Math.abs(main[k] - defOf(k)) > 1e-6)
        || boolKeys.some(k => main[k] !== boolDefaults[k])
        || transition !== transitionDefault

    function snap(key, v) {
        var s = numSpec[key]
        var q = Math.round((v - s.min) / s.step) * s.step + s.min
        q = Math.max(s.min, Math.min(s.max, q))
        return parseFloat(q.toFixed(4))
    }
    function setNumber(key, v) { main[key] = snap(key, v) }
    function toggleSetting(key) { main[key] = !main[key]; saveState() }

    function fmtValue(key, v) {
        var s = numSpec[key]
        return (v * s.mult).toFixed(s.dec) + s.unit
    }

    function resetAll() {
        numKeys.forEach(k => main[k] = defOf(k))
        boolKeys.forEach(k => main[k] = boolDefaults[k])
        transition = transitionDefault
        saveState()
    }

    // Only values that differ from the defaults are written, so edits to
    // config.json (e.g. number_of_pictures) keep working until you override them.
    function saveState() {
        var s = {}
        numKeys.forEach(k => { if (Math.abs(main[k] - defOf(k)) > 1e-6) s[k] = main[k] })
        boolKeys.forEach(k => { if (main[k] !== boolDefaults[k]) s[k] = main[k] })
        if (transition !== transitionDefault) s.transition = transition
        stateFile.setText(JSON.stringify(s))
    }

    FileView {
        id: stateFile
        path: Quickshell.shellPath("settings.json")
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                main.numKeys.forEach(k => { if (typeof s[k] === "number") main[k] = main.snap(k, s[k]) })
                main.boolKeys.forEach(k => { if (typeof s[k] === "boolean") main[k] = s[k] })
                if (typeof s.transition === "string" && main.transitions.indexOf(s.transition) >= 0)
                    main.transition = s.transition
            } catch (e) {
                console.warn("wallpaper picker: could not read saved settings:", e)
            }
        }
    }
    // -----------------------------------------------------------------------

    // ---- Launch animation -------------------------------------------------
    property int introDuration: 300
    property real introScale: 0.94
    property real introRise: 24
    property real intro: 0
    property real fade: 0

    NumberAnimation on intro {
        from: 0
        to: 1
        duration: main.introDuration
        easing.type: Easing.OutCubic
        running: true
    }

    NumberAnimation on fade {
        from: 0
        to: 1
        duration: main.introDuration
        easing.type: Easing.InOutQuad
        running: true
    }
    // -----------------------------------------------------------------------

    property bool showEmpty: false
    readonly property bool looksEmpty: wallpaperPath !== ""
                                       && folderModel.status === FolderListModel.Ready
                                       && folderModel.count === 0

    onLooksEmptyChanged: {
        if (looksEmpty) {
            emptyDelay.restart()
        } else {
            emptyDelay.stop()
            showEmpty = false
        }
    }

    implicitHeight: Screen.height
    implicitWidth: Screen.width
    color: "transparent"
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1
    WlrLayershell.namespace: "wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir])

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
            property int cache_batch_size
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + main.wallpaperPath
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.webm", "*.mov"]
        sortField: FolderListModel.Name
    }

    // Click on empty space: close the menu if it is open, otherwise quit.
    // Right-click anywhere opens / closes the menu.
    // Wheel anywhere (outside the settings panel) scrolls the wallpapers.
    MouseArea {
        id: outsideClickArea
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) main.toggleSettings()
            else if (main.settingsOpen) main.closeSettings()
            else Qt.quit()
        }
        onWheel: wheel => list.wheelScroll(wheel)
    }

    Timer {
        id: emptyDelay
        interval: 300
        onTriggered: main.showEmpty = main.looksEmpty
    }

    Column {
        id: emptyState
        anchors.centerIn: parent
        spacing: 10 * main.ui
        z: 2
        visible: main.showEmpty
        opacity: main.fade

        Text {
            text: "No wallpapers found"
            color: "#ffffff"
            font.pixelSize: 22 * main.ui
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Add images to:"
            color: "#aaaaaa"
            font.pixelSize: 13 * main.ui
            anchors.horizontalCenter: parent.horizontalCenter
        }

        TextEdit {
            id: pathText
            text: main.wallpaperPath
            color: "#dddddd"
            font.pixelSize: 14 * main.ui
            readOnly: true
            selectByMouse: true
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }

    ListView {
        id: list

        // The list is wider than the screen ("overscan") so edge tiles that are pulled
        // toward the center are not hidden while their slot is still off-screen.
        // The window clips whatever is really off-screen. Symmetric => same center.
        readonly property real overscan: Math.abs(main.edgeSpacing) * main.uiW + tileWidth
        width: main.screenW + 2 * overscan
        height: tileHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        z: 1
        focus: true
        orientation: ListView.Horizontal
        spacing: main.baseSpacing * main.uiW
        clip: false
        cacheBuffer: tileWidth
        boundsBehavior: Flickable.StopAtBounds

        // ---- Infinite loop ---------------------------------------------------
        // The list shows the wallpapers repeated `reps` times (an odd number, so there is a
        // "middle copy"). `index` is therefore a *virtual* index; the real wallpaper is
        // index % n. Before every move the view is silently shifted by whole copies so it
        // always sits near the middle copy. Copies look identical, so the shift is invisible
        // and the strip never reaches an end.
        readonly property int n: folderModel.count
        readonly property int halfVisible: Math.ceil((width / 2) / Math.max(1, step)) + 2
        readonly property int sideCopies: n > 0 ? Math.ceil(halfVisible / n) + 1 : 0
        readonly property int reps: 2 * sideCopies + 1
        readonly property int midStart: sideCopies * n
        model: n > 0 ? n * reps : 0
        // ---------------------------------------------------------------------

        // Launch animation (fade + subtle scale-up + small rise) combined with the global scale.
        opacity: main.fade
        scale: main.globalScale * (main.introScale + (1 - main.introScale) * main.intro)
        transformOrigin: Item.Center
        transform: Translate { y: (1 - main.intro) * main.introRise * main.ui }

        property int selectedIndex: 0   // highlighted tile (hover or keyboard), virtual index
        property int scrollIndex: 0     // tile the strip is centered on, virtual index

        readonly property real tileHeight: main.refHeight * main.ui
        // tileCount tiles fill the *screen width*, whatever the resolution/aspect ratio.
        readonly property real tileWidth: Math.max(1, main.screenW / Math.max(1, main.tileCount)
                                                   - (10 + main.baseSpacing) * main.uiW)

        readonly property real viewportCenterX: width / 2
        readonly property real falloffRadius: main.screenW / 2

        readonly property real step: tileWidth + main.baseSpacing * main.uiW
        readonly property real sideMargin: Math.max(0, viewportCenterX - tileWidth / 2)
        property bool ready: false
        property bool userMoved: false
        property bool jumping: false
        property real lastMouseX: -1
        property real lastMouseY: -1
        property real wheelAcc: 0

        leftMargin: sideMargin
        rightMargin: sideMargin

        function mod(a, m) { return ((a % m) + m) % m }
        function centerX(i) { return i * step - sideMargin }

        function centerOnStart() {
            if (userMoved || n <= 0 || main.tileCount <= 0) return
            selectedIndex = midStart + Math.floor((n - 1) / 2)
            scrollIndex = selectedIndex
            jumping = true                      // never animate this initial placement
            contentX = centerX(scrollIndex)
            jumping = false
            ready = true
        }

        // The model was rebuilt (settings changed the number of copies): keep the same
        // wallpapers selected/centered, but move them into the new middle copy.
        function reanchor() {
            if (n <= 0) return
            selectedIndex = midStart + mod(selectedIndex, n)
            scrollIndex = midStart + mod(scrollIndex, n)
            jumping = true
            contentX = centerX(scrollIndex)
            jumping = false
        }

        // Called when tile size / spacing / overscan change (e.g. from the settings menu):
        // keeps the centered tile centered, without animating.
        function recenter() {
            if (count <= 0 || main.tileCount <= 0) return
            if (!userMoved) { centerOnStart(); return }
            jumping = true
            contentX = centerX(scrollIndex)
            jumping = false
        }

        // Shifts the view (and indices) by whole copies so the center tile sits in the middle
        // copy. Invisible, because every copy shows the same wallpapers in the same order.
        function normalize() {
            if (n <= 0 || step <= 0) return
            const c = Math.round((contentX + sideMargin) / step)
            const k = Math.floor((c - midStart) / n)
            if (k === 0) return
            const shift = k * n
            jumping = true
            contentX = contentX - shift * step
            selectedIndex = selectedIndex - shift
            scrollIndex = scrollIndex - shift
            jumping = false
        }

        function activateCurrent() {
            if (n <= 0) return
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"),
                folderModel.get(mod(selectedIndex, n), "filePath"),
                main.transition, String(main.transitionDuration)])
            Qt.quit()
        }

        function moveSelection(delta, speedMultiplier) {
            if (n <= 0) return
            normalize()
            anim.velocity = main.speed * speedMultiplier
            const next = selectedIndex + delta
            selectedIndex = next
            scrollIndex = next
            contentX = centerX(next)            // animated by the Behavior below
        }

        // Shared by the background, the strip and every tile, so the wheel works
        // wherever the cursor is. One wheel notch (120) = one tile, so it also loops.
        // Falls back to the horizontal axis for tilt wheels / touchpads.
        function wheelScroll(wheel) {
            const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
            userMoved = true
            wheelAcc += d
            while (Math.abs(wheelAcc) >= 120) {
                const dir = wheelAcc > 0 ? -1 : 1
                moveSelection(dir, 1)
                wheelAcc += dir * 120
            }
            wheel.accepted = true
        }

        onCountChanged: {
            if (count <= 0) return
            if (!userMoved) centerOnStart()
            else reanchor()
        }
        onWidthChanged: Qt.callLater(recenter)
        onTileWidthChanged: Qt.callLater(recenter)
        onStepChanged: Qt.callLater(recenter)

        Behavior on contentX {
            enabled: list.ready && !list.jumping
            SmoothedAnimation { id: anim; property real velocity: main.speed; duration: main.animDuration }
        }

        delegate: Item {
            id: delegateItem
            width: list.tileWidth
            height: list.tileHeight

            // `index` is virtual; the real wallpaper is index % n.
            readonly property int realIndex: list.n > 0 ? index % list.n : 0
            readonly property string fileName: folderModel.get(realIndex, "fileName") || ""
            readonly property string filePath: folderModel.get(realIndex, "filePath") || ""

            property bool active: index === list.selectedIndex
            readonly property bool isGif: fileName.toLowerCase().endsWith(".gif")
            readonly property bool isVideo: /\.(mp4|mkv|webm|mov)$/i.test(fileName)
            // Debounced so sweeping the mouse across tiles doesn't spin up a decoder per tile.
            property bool videoArmed: false
            onActiveChanged: {
                if (active && isVideo) videoDelay.restart()
                else { videoDelay.stop(); videoArmed = false }
            }
            Timer { id: videoDelay; interval: 250; onTriggered: delegateItem.videoArmed = true }
            readonly property real baseWidth: list.tileWidth
            readonly property real baseCenterX: x - list.contentX + baseWidth / 2
            readonly property real distance: Math.abs(baseCenterX - list.viewportCenterX)
            readonly property real fraction: Math.min(1, distance / list.falloffRadius)
            readonly property real compression: Math.pow(fraction, main.edgeCurve)
            readonly property real edgeOffset: {
                const amount = main.edgeSpacing * main.uiW * compression
                return baseCenterX < list.viewportCenterX ? amount : -amount
            }
            // Size and tilt both follow where the tile is actually *drawn* (slot + edge pull-in).
            // Slot-based values stop changing once a slot is past the screen edge, which made the
            // last tiles identical; the drawn position keeps changing all the way to the corners.
            readonly property real drawnCenterX: baseCenterX + edgeOffset
            readonly property real drawnFraction: Math.min(1, Math.abs(drawnCenterX - list.viewportCenterX) / list.falloffRadius)
            // No smoothstep here on purpose: it is flat at both ends, so tiles stopped changing
            // size before they reached the corners. A power curve keeps shrinking to the very edge.
            readonly property real scaleFactor:
                main.zoomScale + (main.edgeScale - main.zoomScale) * Math.pow(drawnFraction, main.sizeCurve)

            // ---- 3D tilt ---------------------------------------------------
            // Signed rotation around the tile's vertical center line. Tiles left of center
            // turn one way, tiles right of center the other, so the inner edge is nearer.
            readonly property real tiltRad: (drawnCenterX < list.viewportCenterX ? -1 : 1)
                                            * main.tiltAngle * Math.pow(drawnFraction, main.tiltCurve) * Math.PI / 180
            // Projective matrix: rotate about the tile center, then divide by w for real
            // perspective (plain Rotation has none). The camera distance d is measured in
            // *current* tile widths, so big and small tiles get the same trapezoid shape.
            readonly property matrix4x4 tiltMatrix: {
                const a = tiltRad
                if (Math.abs(a) < 1e-4) return Qt.matrix4x4()
                const c = Math.cos(a), sn = Math.sin(a)
                const cx = content.width / 2, cy = content.height / 2
                const d = Math.max(1, content.width * main.tiltDepth)
                return Qt.matrix4x4(
                    c + cx * sn / d, 0, sn - cx * c / d, cx * (1 - c) - cx * cx * sn / d,
                    cy * sn / d,     1, -cy * c / d,     -cy * sn * cx / d,
                    0,               0, 1,               0,
                    sn / d,          0, -c / d,          1 - sn * cx / d)
            }

            // Bigger / more central tiles draw (and receive the mouse) on top.
            z: active ? 1000 : Math.round(scaleFactor * 100)

            Item {
                id: content
                anchors.verticalCenter: parent.verticalCenter
                width: delegateItem.baseWidth * delegateItem.scaleFactor
                height: delegateItem.height * Math.min(1, delegateItem.scaleFactor)
                x: (delegateItem.baseWidth - width) / 2 + delegateItem.edgeOffset
                transform: Matrix4x4 { matrix: delegateItem.tiltMatrix }

                Image {
                    id: shadowImage
                    x: main.shadowX * main.uiW
                    y: main.shadowY * main.ui
                    width: parent.width
                    height: parent.height
                    source: img.source
                    sourceSize.width: img.sourceSize.width
                    sourceSize.height: img.sourceSize.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: main.shadowEnabled
                    opacity: main.shadowOpacity
                    layer.enabled: true
                    layer.effect: MultiEffect { brightness: -1 }
                    transform: Shear { xFactor: main.skewFactor }
                }

                Text {
                    id: alt
                    text: ""
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 16 * main.ui
                    transform: Shear { xFactor: main.skewFactor }
                }

                Image {
                    id: img
                    anchors.fill: parent
                    opacity: delegateItem.active ? main.activeOpacity : main.inactiveOpacity
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // cache: true so tiles that get re-created when the loop shifts
                    // by one copy appear instantly instead of flickering.
                    cache: true
                    smooth: true
                    source: delegateItem.fileName !== "" ? "file://" + main.cachePath + delegateItem.fileName : ""
                    // Decode at a higher resolution when the global scale is above 100% so it stays sharp.
                    sourceSize.width: delegateItem.baseWidth * main.zoomScale * Math.max(1, main.globalScale)
                    sourceSize.height: delegateItem.height * Math.max(1, main.globalScale)
                    transform: Shear { xFactor: main.skewFactor }

                    Timer {
                        id: retryTimer
                        interval: 1000
                        repeat: false
                        onTriggered: { const s = img.source; img.source = ""; img.source = s }
                    }

                    onStatusChanged: {
                        if (status === Image.Error) { alt.text = "Caching"; retryTimer.start() }
                        else if (status === Image.Ready) alt.text = ""
                    }
                }
                AnimatedImage {
                    id: gifImage
                    anchors.fill: parent
                    z: 5
                    source: (delegateItem.isGif && delegateItem.active)
                    ? "file://" + delegateItem.filePath : ""
                    visible: status === AnimatedImage.Ready
                    playing: visible
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    opacity: 1.0
                    transform: Shear { xFactor: main.skewFactor }
                }
                AnimatedImage {
                    id: videoPreview
                    anchors.fill: parent
                    z: 5
                    source: delegateItem.videoArmed
                    ? "file://" + main.cachePath + delegateItem.fileName + ".preview.gif" : ""
                    visible: status === AnimatedImage.Ready
                    playing: visible
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    transform: Shear { xFactor: main.skewFactor }
                }

                Rectangle {
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"
                    border.width: Math.max(1, Math.round(2 * main.ui))
                    border.color: configs.border_color
                    transform: Shear { xFactor: main.skewFactor }
                }

                // Lives inside `content` so it follows the tile's real (scaled + shifted) position.
                MouseArea {
                    anchors.fill: parent
                    z: 20
                    hoverEnabled: list.ready
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPositionChanged: function(mouse) {
                        const p = mapToItem(null, mouse.x, mouse.y)
                        if (p.x === list.lastMouseX && p.y === list.lastMouseY) return
                        list.lastMouseX = p.x
                        list.lastMouseY = p.y
                        list.userMoved = true
                        list.selectedIndex = index
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) main.toggleSettings()
                        else list.activateCurrent()
                    }
                    onWheel: function(wheel) { list.wheelScroll(wheel) }
                }
            }
        }

        Keys.onPressed: function(event) {
            const fast = event.isAutoRepeat ? 2 : 1
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_A:
                userMoved = true
                moveSelection(-1, fast)
                break
            case Qt.Key_Right:
            case Qt.Key_D:
                userMoved = true
                moveSelection(1, fast)
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (count > 0) activateCurrent()
                break
            case Qt.Key_W:
            case Qt.Key_Escape:
                // Escape closes the menu first; a second press quits.
                if (main.settingsOpen) main.closeSettings()
                else Qt.quit()
                break
            default:
                return
            }
            event.accepted = true
        }
    }

    // ---- Settings panel (right-click to open) -----------------------------
    // Draggable by its header. Everything under the panel is shielded from the mouse.
    Rectangle {
        id: panel
        readonly property real u: main.menuUi
        z: 50
        width: 340 * u
        height: Math.min(Screen.height * 0.88, 720 * u)
        x: Screen.width - width - 12 * u
        y: (Screen.height - height) / 2
        radius: main.th.radius * u
        color: main.th.bg
        border.width: 1
        border.color: main.th.alpha(main.th.text, 0.12)
        opacity: main.settingsOpen ? 1 : 0
        visible: opacity > 0
        scale: main.settingsOpen ? 1 : 0.96
        transformOrigin: Item.TopRight
        Behavior on opacity { NumberAnimation { duration: main.th.animMed } }
        Behavior on scale { NumberAnimation { duration: main.th.animMed; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
        }

        Item {
            id: head
            anchors.top: parent.top
            width: parent.width
            height: 58 * panel.u

            MouseArea {
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: panel
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.maximumX: Screen.width - panel.width
                drag.minimumY: 0
                drag.maximumY: Screen.height - panel.height
            }

            Text {
                x: 20 * panel.u; y: 9 * panel.u
                text: "Wallpaper picker settings"
                font.family: main.th.fontFamily
                font.pixelSize: main.th.textSizeSection * panel.u
                font.bold: true
                color: main.th.text
            }
            Text {
                x: 20 * panel.u; y: 34 * panel.u
                text: "Right-click toggles · drag here to move"
                font.family: main.th.fontFamily
                font.pixelSize: main.th.textSizeSmall * panel.u
                color: main.th.textDim
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16 * panel.u
                y: 8 * panel.u
                width: 26 * panel.u; height: 26 * panel.u
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "×"
                font.family: main.th.fontFamily
                font.pixelSize: 22 * panel.u
                color: closeArea.containsMouse ? main.th.text : main.th.textDim
                MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: main.closeSettings() }
            }
        }

        Flickable {
            id: flick
            anchors { top: head.bottom; bottom: foot.top; left: parent.left; right: parent.right }
            contentWidth: width
            contentHeight: contentCol.height + 16 * panel.u
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                x: 20 * panel.u
                width: flick.width - 40 * panel.u

                SectionHeader { text: "Layout" }
                SliderRow { key: "globalScale"; label: "Scale" }
                SliderRow { key: "tileCount"; label: "Tiles on screen" }
                SliderRow { key: "zoomScale"; label: "Center tile size" }
                SliderRow { key: "edgeScale"; label: "Edge tile size" }
                SliderRow { key: "sizeCurve"; label: "Size falloff curve" }
                SliderRow { key: "baseSpacing"; label: "Gap between tiles" }

                SectionHeader { text: "Edges" }
                SliderRow { key: "edgeSpacing"; label: "Edge pull-in" }
                SliderRow { key: "edgeCurve"; label: "Edge curve" }

                SectionHeader { text: "3D" }
                SliderRow { key: "tiltAngle"; label: "Tilt at the edges" }
                SliderRow { key: "tiltDepth"; label: "Perspective depth" }
                SliderRow { key: "tiltCurve"; label: "Tilt curve" }

                SectionHeader { text: "Style" }
                SliderRow { key: "skewFactor"; label: "Skew" }
                SliderRow { key: "activeOpacity"; label: "Selected tile opacity" }
                SliderRow { key: "inactiveOpacity"; label: "Other tiles opacity" }
                ToggleRow { key: "shadowEnabled"; label: "Shadow" }
                SliderRow { key: "shadowOpacity"; label: "Shadow opacity"; enabled: main.shadowEnabled }

                SectionHeader { text: "Behavior" }
                SliderRow { key: "animDuration"; label: "Scroll animation" }

                SectionHeader { text: "Wallpaper change" }
                ChoiceRow {
                    label: "Transition"
                    options: main.transitions
                    current: main.transition
                    onPicked: v => { main.transition = v; main.saveState() }
                }
                SliderRow { key: "transitionDuration"; label: "Transition duration" }
            }
        }

        Item {
            id: foot
            anchors.bottom: parent.bottom
            width: parent.width
            height: 58 * panel.u

            Rectangle { width: parent.width; height: 1; color: main.th.alpha(main.th.text, 0.08) }

            ActionButton {
                x: 20 * panel.u
                anchors.verticalCenter: parent.verticalCenter
                label: "Reset all"
                enabled: main.modified
                onClicked: main.resetAll()
            }

            ActionButton {
                anchors.right: parent.right
                anchors.rightMargin: 20 * panel.u
                anchors.verticalCenter: parent.verticalCenter
                label: "Done"
                primary: true
                onClicked: main.closeSettings()
            }
        }
    }

    // ---- Reusable components ----------------------------------------------
    component ActionButton: Rectangle {
        id: ab
        property var host: main
        property string label: ""
        property bool primary: false
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        signal clicked()

        implicitWidth: abText.implicitWidth + 28 * u
        width: implicitWidth
        height: 30 * u
        radius: Math.min(height / 2, ab.th.radius * u)
        opacity: enabled ? 1 : 0.4
        color: primary ? ab.th.accent : ab.th.alpha(ab.th.text, abArea.containsMouse && enabled ? 0.18 : 0.1)
        Behavior on color { ColorAnimation { duration: ab.th.animFast } }

        Text {
            id: abText
            anchors.centerIn: parent
            text: ab.label
            font.family: ab.th.fontFamily
            font.pixelSize: ab.th.textSizeBody * ab.u
            font.bold: true
            color: ab.primary ? ab.th.bgPanel : ab.th.text
        }

        MouseArea { id: abArea; anchors.fill: parent; hoverEnabled: true; enabled: ab.enabled; onClicked: ab.clicked() }
    }

    component SectionHeader: Item {
        id: sh
        property var host: main
        property string text: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        width: parent?.width ?? 0
        height: 32 * u

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4 * sh.u
            text: sh.text
            font.family: sh.th.fontFamily
            font.pixelSize: sh.th.textSizeSmall * sh.u
            font.bold: true
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
            color: sh.th.textDim
        }
    }

    component ToggleRow: Item {
        id: tr
        property var host: main
        property string key: ""
        property string label: ""
        readonly property bool checked: host[key]
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th

        width: parent?.width ?? 0
        height: 34 * u
        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -8 * tr.u
            anchors.rightMargin: -8 * tr.u
            radius: Math.min(8 * tr.u, tr.th.radius * tr.u)
            color: trArea.containsMouse && tr.enabled ? tr.th.alpha(tr.th.text, 0.06) : "transparent"
        }

        Text {
            anchors.left: parent.left
            anchors.right: sw.left
            anchors.rightMargin: 12 * tr.u
            y: 9 * tr.u
            text: tr.label
            elide: Text.ElideRight
            font.family: tr.th.fontFamily
            font.pixelSize: tr.th.textSizeGroup * tr.u
            font.bold: true
            color: tr.th.text
        }

        Rectangle {
            id: sw
            anchors.right: parent.right
            y: 7 * tr.u
            width: 36 * tr.u; height: 20 * tr.u; radius: height / 2
            color: tr.checked ? tr.th.accent : "transparent"
            border.width: 1
            border.color: tr.checked ? tr.th.accent : tr.th.alpha(tr.th.text, 0.3)
            Behavior on color { ColorAnimation { duration: tr.th.animMed } }

            Rectangle {
                width: 14 * tr.u; height: 14 * tr.u; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: tr.checked ? parent.width - width - 3 * tr.u : 3 * tr.u
                color: tr.checked ? tr.th.bgPanel : tr.th.text
                Behavior on x { NumberAnimation { duration: tr.th.animMed; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea { id: trArea; anchors.fill: parent; hoverEnabled: true; enabled: tr.enabled; onClicked: tr.host.toggleSetting(tr.key) }
    }

    // Row of selectable chips (one choice out of a list of strings).
    component ChoiceRow: Item {
        id: cr
        property var host: main
        property string label: ""
        property var options: []
        property string current: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        signal picked(string value)

        width: parent?.width ?? 0
        height: 28 * u + flow.implicitHeight + 8 * u
        opacity: enabled ? 1 : 0.4

        Text {
            y: 6 * cr.u
            text: cr.label
            font.family: cr.th.fontFamily
            font.pixelSize: cr.th.textSizeGroup * cr.u
            font.bold: true
            color: cr.th.text
        }

        Flow {
            id: flow
            y: 28 * cr.u
            width: parent.width
            spacing: 6 * cr.u

            Repeater {
                model: cr.options
                delegate: Rectangle {
                    id: chip
                    required property string modelData
                    readonly property bool sel: modelData === cr.current
                    width: chipText.implicitWidth + 20 * cr.u
                    height: 24 * cr.u
                    radius: Math.min(height / 2, cr.th.radius * cr.u)
                    color: sel ? cr.th.accent
                               : cr.th.alpha(cr.th.text, chipArea.containsMouse ? 0.18 : 0.1)
                    Behavior on color { ColorAnimation { duration: cr.th.animFast } }

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData
                        font.family: cr.th.fontFamily
                        font.pixelSize: cr.th.textSizeBody * cr.u
                        font.bold: chip.sel
                        color: chip.sel ? cr.th.bgPanel : cr.th.text
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: cr.picked(chip.modelData)
                    }
                }
            }
        }
    }

    // Slider bound to a numSpec entry; saves on release, double-click resets that value.
    component SliderRow: Item {
        id: sr
        property var host: main
        property string key: ""
        property string label: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th

        readonly property var spec: host.numSpec[key]
        readonly property real ratio: Math.max(0, Math.min(1, (host[key] - spec.min) / (spec.max - spec.min)))

        width: parent?.width ?? 0
        height: 46 * u
        opacity: enabled ? 1 : 0.4

        Text {
            anchors.left: parent.left; y: 6 * sr.u
            text: sr.label
            font.family: sr.th.fontFamily
            font.pixelSize: sr.th.textSizeGroup * sr.u
            font.bold: true
            color: sr.th.text
        }
        Text {
            anchors.right: parent.right; y: 6 * sr.u
            text: sr.host.fmtValue(sr.key, sr.host[sr.key])
            font.family: sr.th.fontFamily
            font.pixelSize: sr.th.textSizeBody * sr.u
            color: sr.th.textDim
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            y: 31 * sr.u
            height: 4 * sr.u
            radius: height / 2
            color: sr.th.alpha(sr.th.text, 0.15)

            Rectangle { width: knob.x + knob.width / 2; height: parent.height; radius: parent.radius; color: sr.th.accent }

            Rectangle {
                id: knob
                width: 14 * sr.u; height: 14 * sr.u; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: sr.ratio * (track.width - width)
                color: sr.th.text
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: 20 * sr.u
            preventStealing: true
            enabled: sr.enabled

            function apply(mx) {
                var usable = track.width - knob.width
                if (usable <= 0) return
                var r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable)), s = sr.spec
                sr.host.setNumber(sr.key, s.min + r * (s.max - s.min))
            }

            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
            onReleased: sr.host.saveState()
            onDoubleClicked: { sr.host.setNumber(sr.key, sr.host.defOf(sr.key)); sr.host.saveState() }
        }
    }
}