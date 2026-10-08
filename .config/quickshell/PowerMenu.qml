pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    property int topGap: 12
    property int sideGap: 24
    property int edgeGap: 0
    property int pad: 6

    // how much of the panel must stay on screen when dragged past borders
    readonly property int keepVisible: 40

    // layout controls (persisted)
    readonly property int minWidth: 200
    readonly property int maxWidth: 500
    readonly property int defaultWidth: 284
    property int cardWidth: defaultWidth

    readonly property int minItemHeight: 40
    readonly property int maxItemHeight: 100
    readonly property int defaultItemHeight: 56
    property int itemHeight: defaultItemHeight

    readonly property int minSpacing: 0
    readonly property int maxSpacing: 24
    readonly property int defaultSpacing: 8
    property int itemSpacing: defaultSpacing

    property bool showing: false
    property bool settingsOpen: false
    property bool dragging: false
    property int currentIndex: 0
    property var hiddenNames: []
    property real offsetX: 0
    property real offsetY: 0
    property bool horizontal: false

    readonly property int minSize: 70
    readonly property int maxSize: 160
    readonly property int defaultSize: 100
    property int menuSize: defaultSize
    property string icon: ""
    readonly property int iconRes: 128
    readonly property bool lightMode: Theme._bgBase.hslLightness > 0.5

    Component.onCompleted: BluetoothState.init()

    readonly property bool movedFromDefault: offsetX !== 0 || offsetY !== 0 || horizontal
        || menuSize !== defaultSize
        || cardWidth !== defaultWidth
        || itemHeight !== defaultItemHeight
        || itemSpacing !== defaultSpacing

    readonly property string iconDir: "file://" + Quickshell.env("HOME") + "/.config/quickshell/imgs/"
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/powermenu-state.json"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "powermenu"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? menuRoot : null }

    onMenuSizeChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)
    onCardWidthChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)

    component FooterButton: Rectangle {
        id: fb
        property string label: ""
        property int fontSize: 11
        property color textColor: Theme.textDim
        readonly property bool hovered: fbArea.containsMouse
        signal clicked()

        width: 16; height: 16; radius: 6
        color: Theme.bg
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

    component SizeBtn: Text {
        signal clicked()
        height: 14
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: Theme.text
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    component SizeControl: Row {
        id: sc
        property int value: 100
        signal step(int delta)
        signal reset()

        spacing: 4
        opacity: scHover.hovered ? 0.9 : 0.35
        Behavior on opacity { NumberAnimation { duration: 150 } }
        HoverHandler { id: scHover }

        SizeBtn { text: "−"; width: 16; font.pixelSize: 12; onClicked: sc.step(-10) }
        SizeBtn { text: "+"; width: 16; font.pixelSize: 12; onClicked: sc.step(10) }
    }

    // label on the left, value + [−][+] on the right
    component StepRow: Item {
        id: sr
        property string label: ""
        property string valueText: ""
        signal step(int dir)

        height: 20
        opacity: srHover.hovered ? 0.95 : 0.6
        Behavior on opacity { NumberAnimation { duration: 150 } }
        HoverHandler { id: srHover }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: sr.label
            font.pixelSize: 10
            font.bold: true
            color: Theme.textDim
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: 34
                height: 20
                text: sr.valueText
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 10
                color: Theme.text
            }
            SizeBtn { text: "−"; width: 16; height: 20; font.pixelSize: 12; onClicked: sr.step(-1) }
            SizeBtn { text: "+"; width: 16; height: 20; font.pixelSize: 12; onClicked: sr.step(1) }
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

    function iconFile(name) {
        if (!root.lightMode) return name
        return name.replace(/\.png$/, "2.png")
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

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
        showing = true
        Qt.callLater(function () {
            if (root.showing) {
                menuRoot.forceActiveFocus()
                root.setPosition(root.offsetX, root.offsetY)
            }
        })
    }

    function closeMenu() { showing = false; settingsOpen = false; dragging = false }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    function saveState() {
        stateFile.setText(JSON.stringify({
            hidden: root.hiddenNames,
            offsetX: root.offsetX,
            offsetY: root.offsetY,
            horizontal: root.horizontal,
            menuSize: root.menuSize,
            cardWidth: root.cardWidth,
            itemHeight: root.itemHeight,
            itemSpacing: root.itemSpacing
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

    function resetPosition() {
        root.offsetX = 0
        root.offsetY = 0
        root.horizontal = false
        root.menuSize = root.defaultSize
        root.cardWidth = root.defaultWidth
        root.itemHeight = root.defaultItemHeight
        root.itemSpacing = root.defaultSpacing
        root.saveState()
    }

    function setMenuSize(v) {
        root.menuSize = root.clamp(v, root.minSize, root.maxSize)
    }

    function stepSize(d) {
        root.setMenuSize(root.menuSize + d)
        root.saveState()
    }

    function resetSize() {
        root.menuSize = root.defaultSize
        root.saveState()
    }

    function stepWidth(dir) {
        root.cardWidth = root.clamp(root.cardWidth + dir * 10, root.minWidth, root.maxWidth)
        root.saveState()
    }

    function stepHeight(dir) {
        root.itemHeight = root.clamp(root.itemHeight + dir * 4, root.minItemHeight, root.maxItemHeight)
        root.saveState()
    }

    function stepSpacing(dir) {
        root.itemSpacing = root.clamp(root.itemSpacing + dir * 2, root.minSpacing, root.maxSpacing)
        root.saveState()
    }

    // Allows the panel to go past the screen borders (left, right, bottom),
    // keeping at least `keepVisible` px on screen. Top is kept on screen so the
    // drag handle always stays reachable.
    function setPosition(x, y) {
        if (root.width <= 0 || root.height <= 0) {
            root.offsetX = x
            root.offsetY = y
            return
        }
        var s = root.menuSize / 100
        var kv = root.keepVisible
        var minX = kv - root.width + root.sideGap
        var maxX = root.sideGap + root.cardWidth * s - kv
        var minY = root.edgeGap - root.topGap
        var maxY = Math.max(minY, root.height - kv - root.topGap)
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
                    root.menuSize = root.clamp(s.menuSize, root.minSize, root.maxSize)
                if (typeof s.cardWidth === "number")
                    root.cardWidth = root.clamp(s.cardWidth, root.minWidth, root.maxWidth)
                if (typeof s.itemHeight === "number")
                    root.itemHeight = root.clamp(s.itemHeight, root.minItemHeight, root.maxItemHeight)
                if (typeof s.itemSpacing === "number")
                    root.itemSpacing = root.clamp(s.itemSpacing, root.minSpacing, root.maxSpacing)
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
            if (event.key === Qt.Key_Down
                    || event.key === Qt.Key_Right
                    || event.key === Qt.Key_Tab) {
                root.currentIndex = (root.currentIndex + 1) % root.visibleActions.length
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Up
                    || event.key === Qt.Key_Left
                    || event.key === Qt.Key_Backtab) {
                root.currentIndex = (root.currentIndex - 1 + root.visibleActions.length) % root.visibleActions.length
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
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
        MouseArea {
            anchors.fill: parent
            onClicked: root.settingsOpen ? root.settingsOpen = false : root.closeMenu()
        }
        Rectangle {
            id: panel
            width: root.cardWidth
            height: panelCol.height + 2 * root.pad
            radius: 20
            color: "transparent"
            transformOrigin: Item.TopRight
            scale: root.menuSize / 100
            anchors.top: parent.top
            anchors.topMargin: root.topGap + root.offsetY
            anchors.right: parent.right
            anchors.rightMargin: root.sideGap - root.offsetX
            opacity: root.showing ? 1 : 0
            visible: opacity > 0

            Behavior on anchors.rightMargin {
                enabled: !root.dragging && root.showing
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on anchors.topMargin {
                enabled: !root.dragging && root.showing
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                enabled: root.showing
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            onHeightChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)
            MouseArea { anchors.fill: parent }
            Column {
                id: panelCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: root.pad
                spacing: 6

                Item {
                    id: header
                    width: parent.width
                    height: 12
                    Rectangle {
                        anchors.centerIn: parent
                        width: 36; height: 4; radius: 2
                        color: Theme.bg
                        opacity: (dragArea.containsMouse || root.dragging) ? 1 : 0.1
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property real pressX: 0
                        property real pressY: 0
                        property real startX: 0
                        property real startY: 0
                        onPressed: function (mouse) {
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
                        onDoubleClicked: root.resetPosition()
                    }
                }

                Column {
                    visible: !root.settingsOpen
                    width: parent.width
                    spacing: root.itemSpacing
                    Repeater {
                        model: root.visibleActions
                        delegate: Rectangle {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property bool focused: index === root.currentIndex

                            width: parent.width
                            height: root.itemHeight
                            radius: 12
                            color: entryArea.pressed || entryArea.containsMouse || entry.focused
                            ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Math.min(1, Theme.bg.a + 0.12))
                            : Theme.bg
                            border.width: entry.focused ? 1 : 0
                            border.color: Theme.accent
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Rectangle {
                                id: eThumb
                                width: 32; height: 32; radius: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: "transparent"
                                Image {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    sourceSize: Qt.size(root.iconRes, root.iconRes)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    asynchronous: true
                                    source: root.iconDir + root.iconFile(entry.modelData.icon)
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

                    Item {
                        width: parent.width
                        height: 16

                        SizeControl {
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            value: root.menuSize
                            onStep: function (d) { root.stepSize(d) }
                            onReset: root.resetSize()
                        }

                        FooterButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            label: "󰒓"
                            fontSize: 12
                            textColor: Theme.textDim
                            opacity: hovered ? 1 : 0.1
                            onClicked: {
                                root.settingsOpen = true
                                root.dragging = false
                            }
                        }
                    }
                }

                Column {
                    visible: root.settingsOpen
                    width: parent.width
                    spacing: root.itemSpacing

                    Repeater {
                        model: root.actions

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool on: root.hiddenNames.indexOf(modelData.name) < 0

                            width: parent.width
                            height: Math.max(36, root.itemHeight - 8)
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
                                color: "transparent"

                                Image {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    sourceSize: Qt.size(root.iconRes, root.iconRes)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    asynchronous: true
                                    source: root.iconDir + root.iconFile(row.modelData.icon)
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

                    // layout steppers
                    Column {
                        width: parent.width
                        spacing: 2

                        StepRow {
                            width: parent.width
                            label: "Width"
                            valueText: root.cardWidth + "px"
                            onStep: function (dir) { root.stepWidth(dir) }
                        }
                        StepRow {
                            width: parent.width
                            label: "Height"
                            valueText: root.itemHeight + "px"
                            onStep: function (dir) { root.stepHeight(dir) }
                        }
                        StepRow {
                            width: parent.width
                            label: "Spacing"
                            valueText: root.itemSpacing + "px"
                            onStep: function (dir) { root.stepSpacing(dir) }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 16

                        SizeControl {
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            value: root.menuSize
                            onStep: function (d) { root.stepSize(d) }
                            onReset: root.resetSize()
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            FooterButton {
                                label: "↺"
                                fontSize: 11
                                opacity: root.movedFromDefault ? 1 : 0.4
                                onClicked: root.resetPosition()
                            }

                            FooterButton {
                                label: "󰒓"
                                fontSize: 12
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
}