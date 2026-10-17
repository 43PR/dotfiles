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

    // ---- lifecycle -------------------------------------------------------
    property bool showing: false      // logical "settings are open"
    property bool mounted: false      // window exists
    property real winW: 0             // reported by the window while mounted
    property real winH: 0

    function show()   { showing = true }
    function hide()   { showing = false }
    function toggle() { showing = !showing }

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
        { name: "Network", icon: "󰖩", page: "NetworkPage" },    
        { name: "Bluetooth", icon: "󰂯", page: "BluetoothPage" },
        { name: "Storage", icon: "󰋊", page: "StoragePage" },
        { name: "Power", icon: "󰐥", page: "PowerPage" },
        { name: "Configs", icon: "󰧮",  page: "ConfigsPage" },
        { name: "Themes", icon: "󰉼",  page: "ThemesPage" }
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
            h: root.freeH
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
        function sound(): void {
            root.selectedIndex = 1
            root.show()
        }
        function network(): void {
            root.selectedIndex = 3
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
                    onClicked: root.hide()
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

                    // corner accents
                    Rectangle {
                        width: 40
                        height: 2
                        color: Theme.accent2
                        anchors {
                            top: parent.top
                            left: parent.left
                            margins: 14
                        }
                    }

                    Rectangle {
                        width: 2
                        height: 40
                        color: Theme.accent2
                        anchors {
                            top: parent.top
                            left: parent.left
                            margins: 14
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 2
                        color: Theme.accent2
                        anchors {
                            bottom: parent.bottom
                            right: parent.right
                            margins: 14
                        }
                    }

                    Rectangle {
                        width: 2
                        height: 40
                        color: Theme.accent2
                        anchors {
                            bottom: parent.bottom
                            right: parent.right
                            margins: 14
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

                        // ---- sidebar ----
                        Column {
                            id: sidebar
                            width: 130
                            height: parent.height
                            spacing: 12

                            Text {
                                text: " SETTINGS"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 19
                                font.bold: true
                                font.letterSpacing: 4
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.border
                            }

                            Flickable {
                                id: sidebarFlickable
                                width: parent.width
                                height: Math.max(0, parent.height - 48)
                                contentWidth: width
                                contentHeight: navColumn.height
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: contentHeight > height

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

                            Loader {
                                id: pageLoader
                                anchors.fill: parent
                                active: true
                                asynchronous: true
                                source: "SettingsPages/"
                                    + root.navItems[root.selectedIndex].page
                                    + ".qml"

                                // quick fade for every freshly loaded page
                                onLoaded: fadeIn.restart()

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