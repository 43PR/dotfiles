pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    property int topGap: 4
    property int sideGap: 16
    property int cardWidth: 300

    property bool showing: false
    property bool settingsOpen: false
    property bool dragging: false
    property bool resizing: false
    property int currentIndex: 0
    property var hiddenNames: []
    property real offsetX: 0
    property real offsetY: 0
    property bool horizontal: false

    readonly property int minSize: 70
    readonly property int maxSize: 150
    readonly property int defaultSize: 100
    property int menuSize: defaultSize        // percent

    readonly property bool movedFromDefault: offsetX !== 0 || offsetY !== 0 || horizontal || menuSize !== defaultSize

    readonly property string iconDir: "file://" + Quickshell.env("HOME") + "/.config/quickshell/imgs/"
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/powermenu-state.json"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "powermenu"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? menuRoot : null }

    // Keep the card on screen whenever the size changes
    onMenuSizeChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)

    // Small square button used in the footers (same look as notification header buttons)
    component FooterButton: Rectangle {
        id: fb
        property string label: ""
        property int fontSize: 11
        property color textColor: Theme.textDim
        readonly property bool hovered: fbArea.containsMouse
        signal clicked()

        width: 24; height: 24; radius: 8
        color: Theme.alpha(Theme.text, fbArea.pressed ? 0.22 : fbArea.containsMouse ? 0.2 : 0.08)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: fb.label
            font.pixelSize: fb.fontSize
            font.bold: true
            color: fb.hovered ? Theme.text : fb.textColor
        }

        MouseArea {
            id: fbArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: fb.clicked()
        }
    }

    readonly property var actions: [
        { name: "shutdown",  label: "Shut down", icon: "shutdown.png",  key: "s", cmd: ["systemctl", "poweroff"] },
        { name: "reboot",    label: "Reboot",    icon: "reboot.png",    key: "r", cmd: ["systemctl", "reboot"] },
        { name: "suspend",   label: "Suspend",   icon: "suspend.png",   key: "z", cmd: ["systemctl", "suspend"] },
        { name: "logout",    label: "Log out",   icon: "logout.png",    key: "e", dispatch: "hl.dsp.exit()" },
        { name: "hibernate", label: "Hibernate", icon: "hibernate.png", key: "h", cmd: ["systemctl", "hibernate"] }
    ]

    readonly property var visibleActions: actions.filter(function (a) {
        return root.hiddenNames.indexOf(a.name) < 0
    })

    function runAction(a) {
        if (a.dispatch)
            Hyprland.dispatch(a.dispatch)
        else if (a.cmd)
            Quickshell.execDetached({ command: a.cmd })
        root.closeMenu()
    }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.screen = scr
        }
        currentIndex = 0
        settingsOpen = false
        dragging = false
        resizing = false
        showing = true
        Qt.callLater(function () {
            if (root.showing) {
                menuRoot.forceActiveFocus()
                root.setPosition(root.offsetX, root.offsetY)   // keep saved position on-screen
            }
        })
    }

    function closeMenu() { showing = false; settingsOpen = false; dragging = false; resizing = false }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    function saveState() {
        stateFile.setText(JSON.stringify({
            hidden: root.hiddenNames,
            offsetX: root.offsetX,
            offsetY: root.offsetY,
            horizontal: root.horizontal,
            menuSize: root.menuSize
        }))
    }

    function toggleAction(name) {
        var h = root.hiddenNames.slice()
        var i = h.indexOf(name)
        if (i >= 0)
            h.splice(i, 1)
        else if (root.visibleActions.length > 1)
            h.push(name)
        root.hiddenNames = h
        if (root.currentIndex >= root.visibleActions.length)
            root.currentIndex = 0
        root.saveState()
    }

    // Back to default position AND default size
    function resetPosition() {
        root.offsetX = 0
        root.offsetY = 0
        root.horizontal = false
        root.menuSize = root.defaultSize
        root.saveState()
    }

    function setMenuSize(v) {
        root.menuSize = Math.max(root.minSize, Math.min(root.maxSize, Math.round(v)))
    }

    // Sets the offset, clamped so the whole (scaled) card stays on screen.
    //   offsetX > 0 moves right, offsetX < 0 moves left
    //   offsetY > 0 moves down
    function setPosition(x, y) {
        if (root.width <= 0 || root.height <= 0) {
            root.offsetX = x
            root.offsetY = y
            return
        }
        var s = root.menuSize / 100
        var maxX = root.sideGap
        var minX = Math.min(maxX, root.cardWidth * s + 2 * root.sideGap - root.width)
        var minY = 0
        var maxY = Math.max(minY, root.height - panel.height * s - 2 * root.topGap)
        root.offsetX = Math.max(minX, Math.min(maxX, x))
        root.offsetY = Math.max(minY, Math.min(maxY, y))
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                var valid = root.actions.map(function (a) { return a.name })

                if (Array.isArray(s.hidden)) {
                    var h = s.hidden.filter(function (n) { return valid.indexOf(n) >= 0 })
                    if (h.length < valid.length) root.hiddenNames = h
                }

                if (typeof s.offsetX === "number") root.offsetX = s.offsetX
                if (typeof s.offsetY === "number") root.offsetY = s.offsetY
                if (typeof s.horizontal === "boolean") root.horizontal = s.horizontal
                if (typeof s.menuSize === "number")
                    root.menuSize = Math.max(root.minSize, Math.min(root.maxSize, Math.round(s.menuSize)))
            } catch (e) {
                console.warn("powermenu: could not read saved state:", e)
            }
        }
    }

    Item {
        id: menuRoot
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (!root.showing) return

            if (root.settingsOpen) {
                if (event.key === Qt.Key_Escape
                        || event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter
                        || event.text.toLowerCase() === "c") {
                    root.settingsOpen = false
                    root.dragging = false
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Escape) {
                root.closeMenu()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                root.currentIndex = (root.currentIndex + 1) % root.visibleActions.length
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                root.currentIndex = (root.currentIndex - 1 + root.visibleActions.length) % root.visibleActions.length
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.runAction(root.visibleActions[root.currentIndex])
                event.accepted = true
                return
            }

            if (event.text.toLowerCase() === "c") {
                root.settingsOpen = true
                root.dragging = false
                event.accepted = true
                return
            }

            for (var i = 0; i < root.visibleActions.length; i++) {
                if (event.text.toLowerCase() === root.visibleActions[i].key) {
                    root.runAction(root.visibleActions[i])
                    event.accepted = true
                    return
                }
            }
        }

        // Backdrop: outside click leaves settings first, then closes
        MouseArea {
            anchors.fill: parent
            onClicked: root.settingsOpen ? root.settingsOpen = false : root.closeMenu()
        }

        Rectangle {
            id: panel
            width: root.cardWidth
            height: panelCol.height + 28
            radius: 20
            color: "transparent"

            // Scale from the top-right corner so the card stays pinned to its anchor
            transformOrigin: Item.TopRight
            scale: root.menuSize / 100

            anchors.top: parent.top
            anchors.topMargin: root.topGap + root.offsetY
            anchors.right: parent.right
            anchors.rightMargin: root.showing ? root.sideGap - root.offsetX : -(root.cardWidth + 40)

            opacity: root.showing ? 1 : 0
            visible: opacity > 0

            // Animations are disabled while dragging / resizing, otherwise the card lags
            // behind the cursor. They still run for the slide-in and for reset.
            Behavior on anchors.rightMargin {
                enabled: !root.dragging && !root.resizing
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on anchors.topMargin {
                enabled: !root.dragging && !root.resizing
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                enabled: !root.resizing
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            // Switching between list and settings changes the height: keep it on screen
            onHeightChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)

            // Always swallows clicks on the card (so gaps don't close the menu).
            // Drags only in settings mode.
            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: !root.settingsOpen ? Qt.ArrowCursor
                           : root.dragging ? Qt.ClosedHandCursor
                           : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0
                property real startX: 0
                property real startY: 0

                onPressed: function (mouse) {
                    if (!root.settingsOpen) return
                    // Use menuRoot coordinates: the card itself moves while dragging,
                    // so local mouse.x/y would give jittery deltas.
                    var p = dragArea.mapToItem(menuRoot, mouse.x, mouse.y)
                    pressX = p.x
                    pressY = p.y
                    startX = root.offsetX
                    startY = root.offsetY
                    root.dragging = true
                }

                onPositionChanged: function (mouse) {
                    if (!root.dragging) return
                    var p = dragArea.mapToItem(menuRoot, mouse.x, mouse.y)
                    root.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
                }

                onReleased: {
                    if (!root.dragging) return
                    root.dragging = false
                    root.saveState()
                }

                onCanceled: {
                    if (!root.dragging) return
                    root.dragging = false
                    root.saveState()
                }
            }

            Column {
                id: panelCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                spacing: 10

                // Header: grip shown in settings mode (drag from here or anywhere on the card)
                Item {
                    width: parent.width
                    height: 24

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36; height: 4; radius: 2
                        color: Theme.alpha(Theme.text, root.dragging ? 0.5 : 0.25)
                        opacity: root.settingsOpen ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                // ---------------- Action list ----------------
                Column {
                    visible: !root.settingsOpen
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: root.visibleActions

                        delegate: Rectangle {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property bool focused: index === root.currentIndex

                            width: parent.width
                            height: 56
                            radius: 12
                            color: Theme.alpha(
                                Theme._bgBase,
                                entryArea.pressed ? 0.95
                                : (entryArea.containsMouse || entry.focused) ? 0.9
                                : 0.8
                            )
                            border.width: entry.focused ? 1 : 0
                            border.color: Theme.accent
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Rectangle {
                                id: eThumb
                                width: 32; height: 32; radius: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.alpha(Theme.text, 0.1)

                                Image {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    fillMode: Image.PreserveAspectFit
                                    source: root.iconDir + entry.modelData.icon
                                }
                            }

                            Text {
                                anchors.left: eThumb.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.label
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.text
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20; height: 20; radius: 6
                                color: Theme.alpha(Theme.text, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: entry.modelData.key.toUpperCase()
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: Theme.textDim
                                }
                            }

                            MouseArea {
                                id: entryArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.currentIndex = entry.index
                                onClicked: root.runAction(entry.modelData)
                            }
                        }
                    }

                    // Footer: customize
                    Item {
                        width: parent.width
                        height: 24

                        FooterButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            label: "C"
                            fontSize: 4
                            textColor: Theme.textDim
                            opacity: hovered ? 1 : 0.1
                            onClicked: {
                                root.settingsOpen = true
                                root.dragging = false
                            }
                        }
                    }
                }

                // ---------------- Settings ----------------
                Column {
                    visible: root.settingsOpen
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: root.actions

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool on: root.hiddenNames.indexOf(modelData.name) < 0

                            width: parent.width
                            height: 48
                            radius: 12
                            color: Theme.alpha(
                                Theme._bgBase,
                                rowArea.containsMouse ? 0.9 : 0.8
                            )
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Rectangle {
                                id: rThumb
                                width: 32; height: 32; radius: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.alpha(Theme.text, 0.1)

                                Image {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    fillMode: Image.PreserveAspectFit
                                    source: root.iconDir + row.modelData.icon
                                    opacity: row.on ? 1 : 0.4
                                }
                            }

                            Text {
                                anchors.left: rThumb.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                font.pixelSize: 11
                                font.bold: true
                                color: row.on ? Theme.text : Theme.textDim
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34; height: 18; radius: 9
                                color: row.on ? Theme.accent : "transparent"
                                border.width: 1
                                border.color: row.on ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    width: 12; height: 12; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: row.on ? parent.width - width - 3 : 3
                                    color: row.on ? Theme.bg : Theme.text
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.toggleAction(row.modelData.name)
                            }
                        }
                    }

                    // Size bar
                    Item {
                        id: sizeRow
                        width: parent.width
                        height: 24

                        Text {
                            id: sizeLabel
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Size"
                            font.pixelSize: 10
                            font.bold: true
                            color: Theme.textDim
                        }

                        Text {
                            id: sizeValue
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            horizontalAlignment: Text.AlignRight
                            text: root.menuSize + "%"
                            font.pixelSize: 10
                            color: Theme.textDim
                        }

                        Item {
                            id: sizeBox
                            anchors.left: sizeLabel.right
                            anchors.leftMargin: 10
                            anchors.right: sizeValue.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24

                            readonly property real ratio: (root.menuSize - root.minSize) / (root.maxSize - root.minSize)

                            Rectangle {
                                id: sizeTrack
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 4
                                radius: 2
                                color: Theme.alpha(Theme.text, 0.15)

                                Rectangle {
                                    width: sizeHandle.x + sizeHandle.width / 2
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.accent
                                }

                                Rectangle {
                                    id: sizeHandle
                                    width: 12; height: 12; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: sizeBox.ratio * (sizeTrack.width - width)
                                    color: Theme.text
                                    scale: sizeArea.pressed ? 1.2 : 1
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }
                            }

                            // The card scales while you drag, so the track moves under the cursor.
                            // To avoid feedback, the drag is relative and measured in menuRoot
                            // coordinates using the track width frozen at press time.
                            MouseArea {
                                id: sizeArea
                                anchors.fill: parent
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor

                                property real pressX: 0
                                property real startSize: 0
                                property real sceneW: 1

                                onPressed: function (m) {
                                    root.resizing = true
                                    var p = sizeArea.mapToItem(menuRoot, m.x, m.y)
                                    // click on the track = jump there first
                                    var r = Math.max(0, Math.min(1, (m.x - 6) / Math.max(1, sizeTrack.width - 12)))
                                    root.setMenuSize(root.minSize + r * (root.maxSize - root.minSize))
                                    pressX = p.x
                                    startSize = root.menuSize
                                    sceneW = Math.max(1, (sizeTrack.width - 12) * panel.scale)
                                }

                                onPositionChanged: function (m) {
                                    if (!pressed) return
                                    var p = sizeArea.mapToItem(menuRoot, m.x, m.y)
                                    var d = (p.x - pressX) / sceneW * (root.maxSize - root.minSize)
                                    root.setMenuSize(startSize + d)
                                }

                                onReleased: {
                                    root.resizing = false
                                    root.saveState()
                                }

                                onCanceled: {
                                    root.resizing = false
                                    root.saveState()
                                }
                            }
                        }
                    }

                    // Footer: reset (left) + back (right) on one row
                    Item {
                        width: parent.width
                        height: 24

                        FooterButton {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            label: "↺"
                            fontSize: 13
                            opacity: root.movedFromDefault ? 1 : 0.4
                            onClicked: root.resetPosition()
                        }

                        FooterButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            label: "C"
                            onClicked: {
                                root.settingsOpen = false
                                root.dragging = false
                            }
                        }
                    }
                }
            }
        }
    }
}