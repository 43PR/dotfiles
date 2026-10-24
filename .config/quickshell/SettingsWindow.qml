import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "SettingsPages"

Scope {
    id: root

    // ---- resize limits (tweak these) -------------------------------------
    property real minCardWidth: 700
    property real minCardHeight: 255
    property real maxCardWidth: 1600
    property real maxCardHeight: 1100
    property real resizeGripSize: 40     // hit area of each corner grip (px)

    // ---- sidebar collapse (tweak these) ----------------------------------
    property real sidebarExpandedWidth: 130   // current expanded width (drag the divider to change)
    property real sidebarDefaultWidth: 80    // double-click the divider to reset to this
    property real sidebarMinWidth: 30
    property real sidebarMaxWidth: 420
    property real sidebarHandleHitWidth: 9    // invisible grab area around the 1px divider line
    property bool sidebarResizing: false
    property real sidebarCollapsedWidth: 37   // only the toggle button stays visible
    property bool sidebarCollapsed: false

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
            sidebarResizing = false
            searchQuery = ""
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
        { name: "Configs", icon: "󰧮",  page: "ConfigsPage" },
        { name: "Appearance", icon: "󰏘", page: "AppearancePage" },
        { name: "Themes", icon: "󰉼",  page: "ThemesPage" },
        { name: "Bar", icon: "󰖔",  page: "BarPage" },
        { name: "Input", icon: "󰍽", page: "InputPage" },
        { name: "Network", icon: "󰖩", page: "NetworkPage" },
        { name: "Bluetooth", icon: "󰂯", page: "BluetoothPage" },
        { name: "Storage", icon: "󰋊", page: "StoragePage" },
        { name: "Updates", icon: "󰚰",  page: "UpdatesPage" },
    ]

    // ---- search -----------------------------------------------------------
    property string searchQuery: ""

    // navItems filtered by the search text; origIndex keeps the real page index
    property var filteredNavItems: {
        var q = searchQuery.trim().toLowerCase()
        var out = []
        for (var i = 0; i < navItems.length; i++) {
            if (q === "" || navItems[i].name.toLowerCase().indexOf(q) >= 0)
                out.push({ name: navItems[i].name, icon: navItems[i].icon,
                           page: navItems[i].page, origIndex: i })
        }
        return out
    }

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
            sidebarWidth: root.sidebarExpandedWidth
        }))
    }

    function setSidebarWidth(w) {
        sidebarExpandedWidth = clampRange(w, sidebarMinWidth, sidebarMaxWidth)
    }

    function resetSidebarWidth() {
        setSidebarWidth(sidebarDefaultWidth)
        saveState()
    }

    function finishSidebarResize() {
        sidebarResizing = false
        saveState()
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
                if (typeof s.sidebarWidth === "number")
                    root.setSidebarWidth(s.sidebarWidth)
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

    IpcHandler { // ipc call
        target: "settings"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function toggleSidebar(): void { root.toggleSidebar() }
        function resetSidebarWidth(): void { root.resetSidebarWidth() }
        function sound(): void { root.selectedIndex = 1, root.show() } 
        function network(): void { root.selectedIndex = 8, root.show() }
        function bar(): void { root.selectedIndex = 6, root.show() }
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

            // Input region: the whole screen only when click-outside-to-close is on (the backdrop
            // has to catch those clicks). Otherwise only the card takes input and every click
            // outside it passes through to the windows underneath.
            // The card's rect is bound explicitly (rather than via `item: card`) so the input
            // region always follows drags, resizes and snaps, with a little padding so the
            // drag tab and snap buttons at the very top edge are never clipped.
            mask: Region {
                readonly property real pad: 16
                readonly property bool cardOnly: root.showing && !Theme.clickOutsideClose

                item: root.showing && Theme.clickOutsideClose ? backdrop : null
                x: Math.round(root.cardX) - pad
                y: Math.round(root.cardY) - pad
                width: cardOnly ? Math.round(root.cardWidth) + pad * 2 : 0
                height: cardOnly ? Math.round(root.cardHeight) + pad * 2 : 0
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

            // Ctrl+F: expand the sidebar if collapsed, focus the search box and select its text
            function focusSearch() {
                if (root.sidebarCollapsed)
                    root.toggleSidebar()
                searchInput.forceActiveFocus()
                searchInput.selectAll()
            }

            Shortcut {
                sequence: "Ctrl+F"
                context: Qt.WindowShortcut
                enabled: root.showing
                onActivated: win.focusSearch()
            }

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

                Behavior on width {
                    enabled: !root.dragging && !root.resizing && win.reveal
                    NumberAnimation {
                        duration: Theme.animMed
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on height {
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

                    // drag handle + snap buttons
                    Item {
                        id: positionHandle
                        width: 100
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
                                text: "●"
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
                                text: "●"
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                color: Theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapBottom() }
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 15

                        // ---- sidebar (collapsible) ----
                        Column {
                            id: sidebar
                            width: root.sidebarCollapsed ? root.sidebarCollapsedWidth : root.sidebarExpandedWidth
                            height: parent.height
                            spacing: 10
                            clip: true

                            Behavior on width {
                                enabled: !root.sidebarResizing
                                NumberAnimation {
                                    duration: Theme.animMed
                                    easing.type: Easing.OutCubic
                                }
                            }

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
                                            ? Theme.alpha(Theme.text, 0.08)
                                            : "transparent"
                                        border.width: 1
                                        border.color: collapseMouse.containsMouse
                                            ? Theme.alpha(Theme.text, 0.18)
                                            : "transparent"

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.animFast }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: Theme.animFast }
                                        }

                                        // ChatGPT-style sidebar icon
                                        Item {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16

                                            // Rounded window outline
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 3
                                                color: "transparent"
                                                border.width: 1.4
                                                border.color: collapseMouse.containsMouse
                                                    ? Theme.accent
                                                    : Theme.textDim
                                            }

                                            // Sidebar divider
                                            Rectangle {
                                                x: root.sidebarCollapsed ? 5 : 7
                                                y: 1.5
                                                width: 1.3
                                                height: parent.height - 3
                                                radius: 1
                                                color: collapseMouse.containsMouse
                                                    ? Theme.accent
                                                    : Theme.textDim

                                                Behavior on x {
                                                    NumberAnimation {
                                                        duration: Theme.animMed
                                                        easing.type: Easing.OutCubic
                                                    }
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

                                    // Search box (replaces the old "SETTINGS" title)
                                    Rectangle {
                                        id: searchBox
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: root.sidebarExpandedWidth - collapseButton.width - 10
                                        height: 26
                                        radius: Theme.radius
                                        color: "transparent"
                                        border.width: 1
                                        border.color: searchInput.activeFocus
                                            ? Theme.accent
                                            : Theme.border
                                        opacity: root.sidebarCollapsed ? 0 : 1

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.animFast
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Text {
                                            id: searchIcon
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰍉"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 12
                                            color: searchInput.activeFocus
                                                ? Theme.accent
                                                : Theme.textDim
                                            visible: !Theme.hideSettingsIcons
                                        }

                                        TextInput {
                                            id: searchInput
                                            anchors.left: Theme.hideSettingsIcons
                                                ? parent.left
                                                : searchIcon.right
                                            anchors.leftMargin: 8
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            clip: true
                                            enabled: !root.sidebarCollapsed
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            selectByMouse: true

                                            onTextChanged: root.searchQuery = text

                                            // Enter jumps to the first match
                                            onAccepted: {
                                                if (root.filteredNavItems.length > 0)
                                                    root.selectedIndex = root.filteredNavItems[0].origIndex
                                            }

                                            // Esc clears the box first; a further Esc closes settings
                                            Keys.onEscapePressed: {
                                                if (text !== "") {
                                                    root.searchQuery = ""
                                                } else {
                                                    focus = false
                                                    root.hide()
                                                }
                                            }

                                            // Keep the box in sync when searchQuery is cleared from outside
                                            Connections {
                                                target: root
                                                function onSearchQueryChanged() {
                                                    if (searchInput.text !== root.searchQuery)
                                                        searchInput.text = root.searchQuery
                                                }
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Search…"
                                                font: parent.font
                                                color: Theme.textDim
                                                visible: parent.text === "" && !parent.activeFocus
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !root.sidebarCollapsed
                                            acceptedButtons: Qt.NoButton
                                            hoverEnabled: true
                                            cursorShape: Qt.IBeamCursor
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
                                opacity: 1
                                visible: true
                                enabled: true

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
                                        model: root.filteredNavItems
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            readonly property bool isSelected: root.selectedIndex === modelData.origIndex

                                            width: sidebar.width
                                            height: 38
                                            radius: Theme.radius
                                            color: isSelected
                                                ? Theme.alpha(Theme.accent, 0.12)
                                                : "transparent"
                                            border.width: isSelected ? 1 : 0
                                            border.color: Theme.accent

                                            // Icon – always visible, centers itself when collapsed
                                            Text {
                                                id: navIcon
                                                visible: !Theme.hideSettingsIcons
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.leftMargin: root.sidebarCollapsed
                                                    ? Math.max(0, (parent.width - 18) / 2)
                                                    : 12
                                                width: 18
                                                height: 20
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                                text: modelData.icon
                                                font.family: Theme.iconFont
                                                font.pixelSize: 14
                                                color: isSelected ? Theme.text : Theme.textDim
                                            }

                                            // Label – only visible when expanded
                                            Text {
                                                visible: !root.sidebarCollapsed
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: navIcon.right
                                                anchors.leftMargin: 10
                                                height: 20
                                                verticalAlignment: Text.AlignVCenter
                                                text: modelData.name
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                color: isSelected ? Theme.text : Theme.textDim
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: root.selectedIndex = modelData.origIndex
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---- sidebar divider + thin drag handle ----
                        // 1px line; the MouseArea is a few px wider so it's easy to grab.
                        // Drag to resize the sidebar, double-click to reset its width.
                        Item {
                            id: sidebarDivider
                            width: 1
                            height: parent.height
                            z: 5

                            Rectangle {
                                anchors.fill: parent
                                color: !root.sidebarCollapsed
                                       && (sidebarResizeArea.containsMouse || root.sidebarResizing)
                                    ? Theme.accent
                                    : Theme.border

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animFast }
                                }
                            }

                            MouseArea {
                                id: sidebarResizeArea
                                x: -Math.floor(root.sidebarHandleHitWidth / 2)
                                width: root.sidebarHandleHitWidth
                                height: parent.height
                                enabled: !root.sidebarCollapsed
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.SplitHCursor

                                property real pressX: 0
                                property real startW: 0

                                onPressed: function (mouse) {
                                    pressX = sidebarResizeArea.mapToItem(null, mouse.x, mouse.y).x
                                    startW = root.sidebarExpandedWidth
                                    root.sidebarResizing = true
                                }

                                onPositionChanged: function (mouse) {
                                    if (!pressed || !root.sidebarResizing) return
                                    var px = sidebarResizeArea.mapToItem(null, mouse.x, mouse.y).x
                                    root.setSidebarWidth(startW + (px - pressX))
                                }

                                onReleased: if (root.sidebarResizing) root.finishSidebarResize()
                                onCanceled: if (root.sidebarResizing) root.finishSidebarResize()
                                onDoubleClicked: root.resetSidebarWidth()
                            }
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
                            Connections {
                                target: pageLoader.item
                                ignoreUnknownSignals: true   // other pages don't have these signals
                                function onCloseRequested() { root.hide() }
                                function onSearchFocusReleased() { backdrop.forceActiveFocus() }
                            }
                        }
                    }

                    // ---- corner resize grips ----
                    Repeater {
                        model: ["tr", "bl", "br"]

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