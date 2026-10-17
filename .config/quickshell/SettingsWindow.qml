import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "SettingsPages"

Scope {
    id: root

    // ---- resize limits (tweak these) -------------------------------------
    property real minCardWidth: 780
    property real minCardHeight: 255
    property real maxCardWidth: 1600
    property real maxCardHeight: 1100
    property real resizeGripSize: 40     // hit area of each corner grip (px)

    // ---- sidebar collapse (tweak these) ----------------------------------
    property real sidebarExpandedWidth: 170   // wide enough for the button + SETTINGS title
    property real sidebarCollapsedWidth: 26   // only the toggle button stays visible
    property bool sidebarCollapsed: false

    // ---- corner accents --------------------------------------------------
    property real accentArm: 40          // length of each accent arm (px)
    property real accentInset: 14        // distance from the card edge (px)
    property real accentOpacity: 1.0     // 0..1, edited on the Hub page, persisted in settings-state.json

    // ---- lifecycle -------------------------------------------------------
    property bool showing: false      // logical "settings are open"
    property bool mounted: false      // window exists
    property real winW: 0             // reported by the window while mounted
    property real winH: 0

    function show()   { showing = true }
    function hide()   { showing = false }
    function toggle() { showing = !showing }

    function toggleSidebar() {
        sidebarCollapsed = !sidebarCollapsed
        saveState()
    }

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            dragging = false
            resizing = false
            unmountTimer.restart()
        }
    }

    function unmount() {
        if (root.showing) return        // reopened in the meantime
        root.mounted = false
        root.winW = 0
        root.winH = 0
    }

    property int keepAliveMs: 20000

    Timer {
        id: unmountTimer
        interval: Math.max(600, root.keepAliveMs)
        onTriggered: root.unmount()
    }

    // ---- navigation -------------------------------------------------------
    property int selectedIndex: 0

    property var navItems: [
        { name: "System", icon: "󰒓", page: "SystemPage" },
        { name: "Audio", icon: "󰕾", page: "AudioPage" },
        { name: "Display", icon: "󰍹", page: "DisplayPage" },
        { name: "Input", icon: "󰌌", page: "InputPage" },
        { name: "Network", icon: "󰖩", page: "NetworkPage" },
        { name: "Bluetooth", icon: "󰂯", page: "BluetoothPage" },
        { name: "Storage", icon: "󰋊", page: "StoragePage" },
        { name: "Configs", icon: "󰧮",  page: "ConfigsPage" },
        { name: "Themes", icon: "󰉼",  page: "ThemesPage" },
        { name: "Power", icon: "󰐥", page: "PowerPage" },
        { name: "Hub", icon: "󰋜", page: "HubPage" }
    ]

    function nextPage() { selectedIndex = (selectedIndex + 1) % navItems.length }
    function prevPage() { selectedIndex = (selectedIndex - 1 + navItems.length) % navItems.length }

    // ---- card geometry (persisted snap state) ----------------------------
    property real cardMargin: 40
    property real dragMargin: 8
    property bool dragging: false
    property bool resizing: false

    property real cardHeightCenter: Math.min(640, root.winH - cardMargin * 2)
    property real cardHeightSnapped: cardHeightCenter * 0.6
    property real cardWidthCenter: Math.min(980, root.winW - cardMargin * 2)
    property real cardWidthSnapped: cardWidthCenter * 0.85
    property real cardHeightSideSnapped: cardHeightCenter * 1.4

    property real cardHeight: cardHeightCenter
    property real cardWidth: cardWidthCenter
    property real cardY: (root.winH - cardHeight) / 2
    property real cardX: (root.winW - cardWidth) / 2

    property string snapPosition: "center"
    property real freeX: 0
    property real freeY: 0
    property real freeW: 0
    property real freeH: 0

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/settings-state.json"

    function saveState() {
        stateFile.setText(JSON.stringify({
            snap: root.snapPosition,
            x: root.freeX,
            y: root.freeY,
            w: root.freeW,
            h: root.freeH,
            sidebarCollapsed: root.sidebarCollapsed,
            accentOpacity: root.accentOpacity
        }))
    }

    function clampX(v) {
        return Math.max(dragMargin, Math.min(root.winW - cardWidth - dragMargin, v))
    }

    function clampY(v) {
        return Math.max(dragMargin, Math.min(root.winH - cardHeight - dragMargin, v))
    }

    function clampRange(v, lo, hi) {
        return Math.min(hi, Math.max(lo, v))
    }

    function applySnap(pos) {
        switch (pos) {
        case "top":
            cardWidth = cardWidthCenter
            cardHeight = cardHeightSnapped
            cardX = (root.winW - cardWidth) / 2
            cardY = cardMargin
            break
        case "bottom":
            cardWidth = cardWidthCenter
            cardHeight = cardHeightSnapped
            cardX = (root.winW - cardWidth) / 2
            cardY = root.winH - cardHeight - cardMargin
            break
        case "left":
            cardWidth = cardWidthSnapped
            cardHeight = cardHeightSideSnapped
            cardX = cardMargin
            cardY = (root.winH - cardHeight) / 2
            break
        case "right":
            cardWidth = cardWidthSnapped
            cardHeight = cardHeightSideSnapped
            cardX = root.winW - cardWidth - cardMargin
            cardY = (root.winH - cardHeight) / 2
            break
        case "free":
            cardWidth = clampRange(freeW > 0 ? freeW : cardWidthCenter,
                                   Math.min(minCardWidth, root.winW - 2 * dragMargin),
                                   Math.min(maxCardWidth, root.winW - 2 * dragMargin))
            cardHeight = clampRange(freeH > 0 ? freeH : cardHeightCenter,
                                    Math.min(minCardHeight, root.winH - 2 * dragMargin),
                                    Math.min(maxCardHeight, root.winH - 2 * dragMargin))
            cardX = clampX(freeX)
            cardY = clampY(freeY)
            break
        default:
            cardHeight = cardHeightCenter
            cardWidth = cardWidthCenter
            cardY = (root.winH - cardHeight) / 2
            cardX = (root.winW - cardWidth) / 2
        }
    }

    function snapTo(pos) {
        root.snapPosition = pos
        root.applySnap(pos)
        root.saveState()
    }

    function snapTop()    { snapTo("top") }
    function snapBottom() { snapTo("bottom") }
    function snapLeft()   { snapTo("left") }
    function snapRight()  { snapTo("right") }
    function snapCenter() { snapTo("center") }

    function finishDrag() {
        root.dragging = false
        root.snapPosition = "free"
        root.freeX = root.cardX
        root.freeY = root.cardY
        root.freeW = root.cardWidth
        root.freeH = root.cardHeight
        root.saveState()
    }

    // corner: "tl" | "tr" | "bl" | "br"; sx/sy/sw/sh = card geometry at press; dx/dy = pointer delta
    function resizeCard(corner, sx, sy, sw, sh, dx, dy) {
        var onLeft = corner.charAt(1) === "l"
        var onTop  = corner.charAt(0) === "t"
        var maxW = Math.min(maxCardWidth,  root.winW - 2 * dragMargin)
        var maxH = Math.min(maxCardHeight, root.winH - 2 * dragMargin)
        var w, h, x, y, lo, hi

        if (onLeft) {
            hi = Math.min(maxW, sx + sw - dragMargin)
            lo = Math.min(minCardWidth, hi)
            w = clampRange(sw - dx, lo, hi)
            x = sx + sw - w
        } else {
            hi = Math.min(maxW, root.winW - dragMargin - sx)
            lo = Math.min(minCardWidth, hi)
            w = clampRange(sw + dx, lo, hi)
            x = sx
        }

        if (onTop) {
            hi = Math.min(maxH, sy + sh - dragMargin)
            lo = Math.min(minCardHeight, hi)
            h = clampRange(sh - dy, lo, hi)
            y = sy + sh - h
        } else {
            hi = Math.min(maxH, root.winH - dragMargin - sy)
            lo = Math.min(minCardHeight, hi)
            h = clampRange(sh + dy, lo, hi)
            y = sy
        }

        cardWidth = w
        cardHeight = h
        cardX = x
        cardY = y
    }

    function finishResize() {
        root.resizing = false
        root.snapPosition = "free"
        root.freeX = root.cardX
        root.freeY = root.cardY
        root.freeW = root.cardWidth
        root.freeH = root.cardHeight
        root.saveState()
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                if (typeof s.sidebarCollapsed === "boolean")
                    root.sidebarCollapsed = s.sidebarCollapsed
                if (typeof s.accentOpacity === "number")
                    root.accentOpacity = Math.max(0, Math.min(1, s.accentOpacity))
                if (["center", "top", "bottom", "left", "right", "free"].indexOf(s.snap) >= 0) {
                    if (typeof s.x === "number") root.freeX = s.x
                    if (typeof s.y === "number") root.freeY = s.y
                    if (typeof s.w === "number") root.freeW = s.w
                    if (typeof s.h === "number") root.freeH = s.h
                    root.snapPosition = s.snap
                    if (root.winW > 0 && root.winH > 0)
                        root.applySnap(s.snap)
                }
            } catch (e) {
                console.warn("settings: could not read saved state:", e)
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function toggleSidebar(): void { root.toggleSidebar() }
        function sound(): void {
            root.selectedIndex = 1
            root.show()
        }
        function network(): void {
            root.selectedIndex = 4
            root.show()
        }
        function snapTop(): void { root.snapTop() }
        function snapCenter(): void { root.snapCenter() }
        function snapBottom(): void { root.snapBottom() }
        function snapLeft(): void { root.snapLeft() }
        function snapRight(): void { root.snapRight() }
    }

    // ---- the window: only exists while mounted ---------------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win

            // `reveal` drives the open animation. A freshly created window has
            // to build its render resources (first frame, offscreen texture of
            // the card, glyphs, shape geometry, first page compile) and all of
            // that lands in the middle of the animation, so the first frames
            // are dropped and it looks like a different, stuttery animation.
            //
            // So: once the window has its size, the card is drawn once while
            // practically invisible (`prewarm`), and `reveal` only flips after
            // a few frames have really been presented and the first page is
            // loaded. A timer is the fallback if no frame signal arrives.
            property bool reveal: false
            property bool sized: false
            property bool warm: false       // fallback so a broken page can't keep the window hidden
            property bool revealBound: false
            property int warmFrames: 0

            readonly property bool pageReady: pageLoader.status === Loader.Ready
            readonly property bool canReveal: sized && (pageReady || warm)

            function bindReveal() {
                if (revealBound)
                    return
                revealBound = true
                reveal = Qt.binding(function () { return root.showing })
            }

            Timer {
                running: true
                interval: 600
                onTriggered: win.warm = true
            }

            Timer {
                running: win.canReveal && !win.revealBound
                interval: 250
                onTriggered: win.bindReveal()
            }

            Connections {
                target: card.Window.window
                ignoreUnknownSignals: true
                function onFrameSwapped() {
                    if (win.sized && win.pageReady && !win.revealBound && ++win.warmFrames >= 3)
                        win.bindReveal()
                }
            }

            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "settings"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            mask: Region {
                item: root.showing ? backdrop : null
            }

            function syncSize() {
                root.winW = width
                root.winH = height
                if (width > 0 && height > 0) {
                    root.applySnap(root.snapPosition)
                    sized = true
                }
            }

            onWidthChanged: syncSize()
            onHeightChanged: syncSize()
            Component.onCompleted: syncSize()

            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: "transparent"

                focus: root.showing
                Keys.onEscapePressed: root.hide()
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Backtab ||
                    (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                        root.prevPage()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        root.nextPage()
                        event.accepted = true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: if (Theme.clickOutsideClose) root.hide()
                }
            }

            // Keeps the 3D tilt/parallax, but with OSD-like timing (see PerspectivePanel.qml).
            PerspectivePanel {
                id: card
                // whole pixels so the cached texture is never sampled between pixels
                x: Math.round(root.cardX)
                y: Math.round(root.cardY)
                width: Math.round(root.cardWidth)
                height: Math.round(root.cardHeight)
                open: win.reveal

                cacheContent: true
                prewarm: win.sized && !win.revealBound
                fadeDuration: 150
                popDuration: 170
                tiltDuration: 220
                popEasing: Easing.OutCubic
                closedScale: 0.93

                Behavior on x {
                    enabled: !root.dragging && !root.resizing && win.reveal
                    NumberAnimation {
                        duration: Theme.animMed
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    enabled: !root.dragging && !root.resizing && win.reveal
                    NumberAnimation {
                        duration: Theme.animMed
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    radius: Theme.radius
                    border.color: Theme.accent
                    border.width: 1

                    // corner accents: L-shapes whose outer corner follows Theme.radius.
                    // One shape is drawn top-left and rotated 0/90/180/270 for the others.
                    Repeater {
                        model: ["tl", "tr", "br", "bl"]

                        delegate: Shape {
                            id: accent
                            required property string modelData
                            required property int index

                            readonly property real arm: root.accentArm
                            // Concentric with the card corner: the accent sits `accentInset` px inside the
                            // card edge, so its outer radius is Theme.radius - accentInset. The path runs
                            // along the middle of the 2px stroke, hence the extra -1.
                            readonly property real r: Math.max(0, Math.min(Theme.radius - root.accentInset - 1, arm - 2))

                            width: arm
                            height: arm
                            x: modelData.charAt(1) === "l" ? root.accentInset : parent.width - width - root.accentInset
                            y: modelData.charAt(0) === "t" ? root.accentInset : parent.height - height - root.accentInset
                            rotation: index * 90
                            opacity: root.accentOpacity
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: Theme.accent2
                                strokeWidth: 2
                                fillColor: "transparent"
                                capStyle: ShapePath.FlatCap

                                // path runs along the middle of the 2px stroke (offset 1px)
                                startX: 1
                                startY: accent.arm

                                PathLine { x: 1; y: accent.r + 1 }
                                PathArc {
                                    x: accent.r + 1; y: 1
                                    radiusX: Math.max(accent.r, 0.01)
                                    radiusY: Math.max(accent.r, 0.01)
                                    direction: PathArc.Clockwise
                                }
                                PathLine { x: accent.arm; y: 1 }
                            }
                        }
                    }

                    // drag handle + snap buttons
                    Item {
                        id: positionHandle
                        width: 140
                        height: 9
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                        }

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                id: tabPath
                                property real w: positionHandle.width
                                property real h: positionHandle.height
                                property real r: 6
                                property real fx: 30
                                property real fy: 0

                                strokeColor: Theme.accent
                                strokeWidth: 1
                                fillColor: "transparent"
                                capStyle: ShapePath.FlatCap

                                startX: 0.5 - fx
                                startY: 0.5

                                PathArc {
                                    x: 0.5; y: tabPath.fy + 0.5
                                    radiusX: tabPath.fx; radiusY: tabPath.fy
                                    direction: PathArc.Clockwise
                                }
                                PathLine { x: 0.5; y: tabPath.h - tabPath.r }
                                PathArc {
                                    x: tabPath.r + 0.5; y: tabPath.h - 0.5
                                    radiusX: tabPath.r; radiusY: tabPath.r
                                    direction: PathArc.Counterclockwise
                                }
                                PathLine { x: tabPath.w - tabPath.r - 0.5; y: tabPath.h - 0.5 }
                                PathArc {
                                    x: tabPath.w - 0.5; y: tabPath.h - tabPath.r
                                    radiusX: tabPath.r; radiusY: tabPath.r
                                    direction: PathArc.Counterclockwise
                                }
                                PathLine { x: tabPath.w - 0.5; y: tabPath.fy + 0.5 }
                                PathArc {
                                    x: tabPath.w - 0.5 + tabPath.fx; y: 0.5
                                    radiusX: tabPath.fx; radiusY: tabPath.fy
                                    direction: PathArc.Clockwise
                                }
                            }
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            anchors.bottomMargin: -6
                            acceptedButtons: Qt.LeftButton
                            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            property real pressX: 0
                            property real pressY: 0
                            property real startX: 0
                            property real startY: 0
                            property bool moved: false

                            onPressed: function (mouse) {
                                var p = dragArea.mapToItem(backdrop, mouse.x, mouse.y)
                                pressX = p.x
                                pressY = p.y
                                startX = root.cardX
                                startY = root.cardY
                                moved = false
                                root.dragging = true
                            }

                            onPositionChanged: function (mouse) {
                                if (!root.dragging) return
                                var p = dragArea.mapToItem(backdrop, mouse.x, mouse.y)
                                moved = true
                                root.cardX = root.clampX(startX + (p.x - pressX))
                                root.cardY = root.clampY(startY + (p.y - pressY))
                            }

                            onReleased: {
                                if (!root.dragging) return
                                if (moved) root.finishDrag()
                                else root.dragging = false
                            }

                            onCanceled: {
                                if (!root.dragging) return
                                if (moved) root.finishDrag()
                                else root.dragging = false
                            }

                            onDoubleClicked: root.snapCenter()
                        }

                        Row {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            spacing: 20

                            Text {
                                text: "◀"
                                font.family: Theme.fontFamily
                                font.pixelSize: 6
                                color: Theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapLeft() }
                            }
                            Text {
                                text: "▲"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: Theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapTop() }
                            }
                            Text {
                                text: "●"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: Theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapCenter() }
                            }
                            Text {
                                text: "▼"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: Theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapBottom() }
                            }
                            Text {
                                text: "▶"
                                font.family: Theme.fontFamily
                                font.pixelSize: 6
                                color: Theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapRight() }
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 28
                        spacing: 28

                        // ---- sidebar (collapsible) ----
                        Column {
                            id: sidebar
                            width: root.sidebarCollapsed ? root.sidebarCollapsedWidth : root.sidebarExpandedWidth
                            height: parent.height
                            spacing: 12
                            clip: true

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.animMed
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // header: [toggle button] SETTINGS
                            Item {
                                id: sidebarHeader
                                width: parent.width
                                height: 26
                                clip: true

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10

                                    Rectangle {
                                        id: collapseButton
                                        width: 26
                                        height: 26
                                        radius: Theme.radius
                                        color: collapseMouse.containsMouse
                                            ? Theme.alpha(Theme.accent, 0.10)
                                            : "transparent"
                                        border.width: 1
                                        border.color: collapseMouse.containsMouse ? Theme.accent : Theme.border

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.animFast }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "◀"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: collapseMouse.containsMouse ? Theme.accent : Theme.textDim
                                            // points left while open, flips to point right when collapsed
                                            rotation: root.sidebarCollapsed ? 180 : 0

                                            Behavior on rotation {
                                                NumberAnimation {
                                                    duration: Theme.animMed
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: collapseMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleSidebar()
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "SETTINGS"
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 19
                                        font.bold: true
                                        font.letterSpacing: 4
                                        opacity: root.sidebarCollapsed ? 0 : 1

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.animFast
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.border
                            }

                            Flickable {
                                id: sidebarFlickable
                                width: parent.width
                                height: Math.max(0, sidebar.height - sidebarHeader.height - 1 - sidebar.spacing * 2)
                                contentWidth: width
                                contentHeight: navColumn.height
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: contentHeight > height

                                opacity: root.sidebarCollapsed ? 0 : 1
                                visible: opacity > 0
                                enabled: !root.sidebarCollapsed

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.animFast
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                WheelHandler {
                                    target: sidebarFlickable
                                    property: "contentY"
                                    onActiveChanged: {
                                        if (!active)
                                            sidebarFlickable.returnToBounds()
                                    }
                                }

                                Column {
                                    id: navColumn
                                    width: sidebarFlickable.width
                                    spacing: 4

                                    Repeater {
                                        model: root.navItems
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: sidebar.width
                                            height: 38
                                            radius: Theme.radius
                                            color: root.selectedIndex === index
                                                ? Theme.alpha(Theme.accent, 0.12)
                                                : "transparent"
                                            border.width: root.selectedIndex === index ? 1 : 0
                                            border.color: Theme.accent

                                            Rectangle {
                                                visible: root.selectedIndex === index
                                                width: 3
                                                height: parent.height - 10
                                                anchors {
                                                    verticalCenter: parent.verticalCenter
                                                    left: parent.left
                                                }
                                                color: Theme.accent2
                                            }

                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.leftMargin: 16
                                                spacing: 12
                                                height: 20

                                                Text {
                                                    visible: !Theme.hideSettingsIcons
                                                    width: 18
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: modelData.icon
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: 14
                                                    color: root.selectedIndex === index
                                                        ? Theme.text
                                                        : Theme.textDim
                                                }

                                                Text {
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: modelData.name
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 13
                                                    color: root.selectedIndex === index
                                                        ? Theme.text
                                                        : Theme.textDim
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: root.selectedIndex = index
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: parent.height
                            color: Theme.border
                        }

                        // ---- page area: one page loaded at a time ----
                        Item {
                            width: parent.width - sidebar.width - 29
                            height: parent.height
                            clip: true

                            // Pages that expose `accentOpacity` (the Hub page) get the current value
                            // pushed in and report edits back through these signals.
                            Connections {
                                target: pageLoader.item
                                ignoreUnknownSignals: true

                                function onAccentOpacityEdited(value) {
                                    root.accentOpacity = value
                                }

                                function onAccentOpacityCommitted(value) {
                                    root.accentOpacity = value
                                    root.saveState()
                                }
                            }

                            Loader {
                                id: pageLoader
                                anchors.fill: parent
                                active: true
                                asynchronous: true
                                source: "SettingsPages/"
                                    + root.navItems[root.selectedIndex].page
                                    + ".qml"

                                // quick fade for every freshly loaded page
                                onLoaded: {
                                    if (item && item.accentOpacity !== undefined)
                                        item.accentOpacity = root.accentOpacity
                                    fadeIn.restart()
                                }

                                SequentialAnimation {
                                    id: fadeIn

                                    PropertyAction {
                                        target: pageLoader
                                        property: "opacity"
                                        value: 0
                                    }

                                    NumberAnimation {
                                        target: pageLoader
                                        property: "opacity"
                                        to: 1
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }

                    // ---- corner resize grips (sit over the corner accents) ----
                    Repeater {
                        model: ["tl", "tr", "bl", "br"]

                        delegate: MouseArea {
                            id: grip
                            required property string modelData

                            width: root.resizeGripSize
                            height: root.resizeGripSize
                            x: modelData.charAt(1) === "l" ? 0 : parent.width - width
                            y: modelData.charAt(0) === "t" ? 0 : parent.height - height
                            z: 10
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            cursorShape: (modelData === "tl" || modelData === "br")
                                ? Qt.SizeFDiagCursor
                                : Qt.SizeBDiagCursor

                            property real pressX: 0
                            property real pressY: 0
                            property real sx: 0
                            property real sy: 0
                            property real sw: 0
                            property real sh: 0

                            onPressed: function (mouse) {
                                var p = grip.mapToItem(null, mouse.x, mouse.y)
                                pressX = p.x
                                pressY = p.y
                                sx = root.cardX
                                sy = root.cardY
                                sw = root.cardWidth
                                sh = root.cardHeight
                                root.resizing = true
                            }

                            onPositionChanged: function (mouse) {
                                if (!pressed || !root.resizing) return
                                var p = grip.mapToItem(null, mouse.x, mouse.y)
                                root.resizeCard(modelData, sx, sy, sw, sh,
                                                p.x - pressX, p.y - pressY)
                            }

                            onReleased: if (root.resizing) root.finishResize()
                            onCanceled: if (root.resizing) root.finishResize()
                        }
                    }
                }
            }
        }
    }
}