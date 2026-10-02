pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus:
        root.showing
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

    property bool showing: false
    property bool settingsOpen: false
    property bool horizontal: false
    property int currentIndex: 0
    property var hiddenNames: []
    property real offsetX: 0
    property real offsetY: 0
    property real menuSize: 100
    readonly property real defaultMenuSize: 100
    readonly property real minMenuSize: 60
    readonly property real maxMenuSize: 160
    readonly property real edgeGapFrac: 0.06
    readonly property string iconDir: "file://" + Quickshell.env("HOME") + "/.config/quickshell/imgs/"
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/powermenu-state.json"
    mask: Region { item: root.showing ? menuRoot : null }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.screen = scr
        }
        currentIndex = 0
        settingsOpen = false
        showing = true
        Qt.callLater(function () {
            if (root.showing) {
                menuRoot.forceActiveFocus()
                root.setOffset(root.offsetX, root.offsetY)
            }
        })
    }
    function closeMenu() { showing = false; settingsOpen = false }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    function isHidden(name) { return root.hiddenNames.indexOf(name) >= 0 }

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
        if (i >= 0) {
            h.splice(i, 1)
        } else if (root.visibleActions.length > 1) {
            h.push(name)
        }
        root.hiddenNames = h
        if (root.currentIndex >= root.visibleActions.length)
            root.currentIndex = 0
        root.saveState()
    }

    function toggleHorizontal() {
        root.horizontal = !root.horizontal
        root.saveState()
    }

    function setMenuSize(size) {
        root.menuSize = Math.max(root.minMenuSize, Math.min(root.maxMenuSize, size))
        root.setOffset(root.offsetX, root.offsetY)
        root.saveState()
    }

    function setOffset(x, y) {
        var base = root.width * root.edgeGapFrac
        var rm = Math.max(0, Math.min(root.width - layout.width - 60, base - x))
        var maxY = Math.max(0, (menuRoot.height - layout.height) / 2)
        root.offsetX = base - rm
        root.offsetY = Math.max(-maxY, Math.min(maxY, y))
    }

    function resetPosition() { resetAnim.restart() }

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
                if (typeof s.offsetX === "number") root.offsetX = s.offsetX
                if (typeof s.offsetY === "number") root.offsetY = s.offsetY
                if (typeof s.horizontal === "boolean") root.horizontal = s.horizontal
                if (typeof s.menuSize === "number")
                    root.menuSize = Math.max(root.minMenuSize, Math.min(root.maxMenuSize, s.menuSize))
                if (Array.isArray(s.hidden)) {
                    var valid = root.actions.map(function (a) { return a.name })
                    var h = s.hidden.filter(function (n) { return valid.indexOf(n) >= 0 })
                    if (h.length < valid.length) root.hiddenNames = h
                }
            } catch (e) {
                console.warn("powermenu: could not read saved state:", e)
            }
        }
    }

    readonly property var actions: [
        { name: "shutdown",  icon: "shutdown.png",  key: "s", cmd: ["systemctl", "poweroff"] },
        { name: "reboot",    icon: "reboot.png",    key: "r", cmd: ["systemctl", "reboot"] },
        { name: "suspend",   icon: "suspend.png",   key: "z", cmd: ["systemctl", "suspend"] },
        { name: "logout",    icon: "logout.png",    key: "e", dispatch: "hl.dsp.exit()" },
        { name: "hibernate", icon: "hibernate.png", key: "h", cmd: ["systemctl", "hibernate"] }
    ]

    readonly property var visibleActions: actions.filter(function (a) { return root.hiddenNames.indexOf(a.name) < 0 })

    function runAction(a) {
        if (a.dispatch) {
            Hyprland.dispatch(a.dispatch)
        } else if (a.cmd) {
            Quickshell.execDetached({ command: a.cmd })
        }
        root.closeMenu()
    }

    Item {
        id: menuRoot
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (event) {
            if (!root.showing) return
            if (root.settingsOpen) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.settingsOpen = false
                }
                event.accepted = true; return
            }
            if (event.key === Qt.Key_Escape) {
                root.closeMenu(); event.accepted = true; return
            }
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                root.currentIndex = (root.currentIndex + 1) % root.visibleActions.length
                event.accepted = true; return
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                root.currentIndex = (root.currentIndex - 1 + root.visibleActions.length) % root.visibleActions.length
                event.accepted = true; return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.runAction(root.visibleActions[root.currentIndex])
                event.accepted = true; return
            }
            if (event.text.toLowerCase() === "c") {
                root.settingsOpen = true
                event.accepted = true; return
            }
            for (var i = 0; i < root.visibleActions.length; i++) {
                if (event.text.toLowerCase() === root.visibleActions[i].key) {
                    root.runAction(root.visibleActions[i])
                    event.accepted = true
                    return
                }
            }
        }

        Connections {
            target: layout
            function onWidthChanged() { if (root.showing) root.setOffset(root.offsetX, root.offsetY) }
            function onHeightChanged() { if (root.showing) root.setOffset(root.offsetX, root.offsetY) }
        }

        ParallelAnimation {
            id: resetAnim
            onFinished: root.saveState()
            NumberAnimation { target: root; property: "offsetX"; to: 0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "offsetY"; to: 0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "menuSize"; to: root.defaultMenuSize; duration: 200; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.showing ? 0.2 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.settingsOpen) root.settingsOpen = false
                    else root.closeMenu()
                }
            }
        }

        Grid {
            id: layout
            anchors.right: parent.right
            anchors.rightMargin: root.width * root.edgeGapFrac - root.offsetX
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.offsetY
            spacing: 20
            flow: Grid.LeftToRight
            columns: root.horizontal ? Math.max(1, root.visibleActions.length) : 1
            opacity: root.showing ? 1 : 0
            scale: root.showing ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Repeater {
                model: root.visibleActions
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool keyFocused: index === root.currentIndex
                    width: root.menuSize
                    height: root.menuSize
                    radius: width / 2
                    color: mouse.pressed ? Theme.alpha(Theme.text, 0.18)
                         : (mouse.containsMouse || btn.keyFocused) ? Theme.alpha(Theme.text, 0.12)
                         : Theme.alpha(Theme.bg, 0.4)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        id: focusRing
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.width: 3
                        border.color: Theme.accent
                        opacity: 0
                    }

                    SequentialAnimation {
                        id: focusAnim
                        PropertyAction { target: focusRing; property: "opacity"; value: 1 }
                        PauseAnimation { duration: 1800 }
                        NumberAnimation { target: focusRing; property: "opacity"; to: 0; duration: 1200 }
                    }

                    onKeyFocusedChanged: {
                        if (btn.keyFocused) {
                            focusAnim.restart()
                        } else {
                            focusAnim.stop()
                            focusRing.opacity = 0
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        source: root.iconDir + btn.modelData.icon
                        width: parent.width * 0.2
                        height: width
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.currentIndex = btn.index
                        onClicked: root.runAction(btn.modelData)
                    }
                }
            }
        }

        Rectangle {
            id: editBtn
            anchors.right: layout.left
            anchors.rightMargin: 16
            anchors.verticalCenter: layout.verticalCenter
            width: 32; height: 32; radius: 16
            visible: !root.settingsOpen
            opacity: root.showing ? 1 : 0
            color: editMouse.pressed ? Theme.alpha(Theme.text, 0.18)
                 : editMouse.containsMouse ? Theme.alpha(Theme.text, 0.12)
                 : Theme.alpha(Theme.bg, 0)
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -1
                text: "<"
                color: editMouse.containsMouse ? Theme.text : Theme.textDim
                font.family: Theme.fontFamily; font.pixelSize: 16; font.bold: true
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: editMouse
                anchors.fill: parent
                hoverEnabled: true
                property real startX: 0
                property real startY: 0
                property real startOffX: 0
                property real startOffY: 0
                property bool moved: false
                onPressed: function (m) {
                    resetAnim.stop()
                    var p = editMouse.mapToItem(menuRoot, m.x, m.y)
                    startX = p.x; startY = p.y
                    startOffX = root.offsetX; startOffY = root.offsetY
                    moved = false
                }
                onPositionChanged: function (m) {
                    if (!pressed) return
                    var p = editMouse.mapToItem(menuRoot, m.x, m.y)
                    var dx = p.x - startX
                    var dy = p.y - startY
                    if (!moved && Math.abs(dx) + Math.abs(dy) < 6) return
                    moved = true
                    root.setOffset(startOffX + dx, startOffY + dy)
                }
                onReleased: {
                    if (moved) root.saveState()
                }
                onClicked: {
                    if (!moved) root.settingsOpen = true
                }
            }
        }

        Rectangle {
            id: settingsPopup
            visible: root.settingsOpen; anchors.centerIn: parent; z: 100
            width: Math.min(parent.width - 30, 420); height: settingsColumn.implicitHeight + 36; radius: Theme.radius
            color: Theme.bg; border.width: 1; border.color: Theme.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: settingsColumn
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 18; spacing: 12

                Text {
                    text: "POWER MENU"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 17; font.bold: true
                }

                Text {
                    width: parent.width; text: "Choose which buttons are shown in the power menu. Hold and drag the < button to move them."; color: Theme.textDim
                    font.family: Theme.fontFamily; font.pixelSize: 13; wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool on: root.hiddenNames.indexOf(modelData.name) < 0
                        width: settingsColumn.width; height: 40; radius: Theme.radius
                        color: rowMouse.pressed ? Theme.alpha(Theme.text, 0.18)
                             : rowMouse.containsMouse ? Theme.alpha(Theme.text, 0.12)
                             : Theme.alpha(Theme.bg, 0.4)
                        border.width: 1; border.color: row.on ? Theme.accent : Theme.alpha(Theme.text, 0.2)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Image {
                            id: rowIcon
                            anchors.left: parent.left; anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.iconDir + row.modelData.icon
                            width: 20; height: 20
                            fillMode: Image.PreserveAspectFit
                            opacity: row.on ? 1 : 0.4
                        }

                        Text {
                            anchors.left: rowIcon.right; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.name.toUpperCase()
                            color: row.on ? Theme.text : Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true
                        }

                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 20; radius: 10
                            color: row.on ? Theme.accent : "transparent"
                            border.width: 1; border.color: row.on ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Rectangle {
                                width: 14; height: 14; radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                x: row.on ? parent.width - width - 3 : 3
                                color: row.on ? Theme.bg : Theme.text
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.toggleAction(row.modelData.name)
                        }
                    }
                }

                Rectangle {
                    id: orientRow
                    width: settingsColumn.width; height: 40; radius: Theme.radius
                    color: orientMouse.pressed ? Theme.alpha(Theme.text, 0.18)
                         : orientMouse.containsMouse ? Theme.alpha(Theme.text, 0.12)
                         : Theme.alpha(Theme.bg, 0.4)
                    border.width: 1; border.color: root.horizontal ? Theme.accent : Theme.alpha(Theme.text, 0.2)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "HORIZONTAL LAYOUT"
                        color: root.horizontal ? Theme.text : Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true
                    }

                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 20; radius: 10
                        color: root.horizontal ? Theme.accent : "transparent"
                        border.width: 1; border.color: root.horizontal ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 14; height: 14; radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.horizontal ? parent.width - width - 3 : 3
                            color: root.horizontal ? Theme.bg : Theme.text
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        id: orientMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.toggleHorizontal()
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "SIZE " + Math.round(root.menuSize) + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 10
                        radius: 10
                        color: Theme.alpha(Theme.text, 0.08)
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.2)

                        Rectangle {
                            width: Math.max(0, parent.width * ((root.menuSize - root.minMenuSize) / (root.maxMenuSize - root.minMenuSize)))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: function (m) {
                                var ratio = Math.max(0, Math.min(1, m.x / width))
                                root.setMenuSize(root.minMenuSize + ratio * (root.maxMenuSize - root.minMenuSize))
                            }
                            onPositionChanged: function (m) {
                                if (!pressed) return
                                var ratio = Math.max(0, Math.min(1, m.x / width))
                                root.setMenuSize(root.minMenuSize + ratio * (root.maxMenuSize - root.minMenuSize))
                            }
                        }
                    }
                }

                Item {
                    width: parent.width; height: 32

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32; radius: 16
                        opacity: (root.offsetX !== 0 || root.offsetY !== 0 || root.menuSize !== root.defaultMenuSize) ? 1 : 0.4
                        color: resetMouse.pressed ? Theme.alpha(Theme.text, 0.18)
                             : resetMouse.containsMouse ? Theme.alpha(Theme.text, 0.12)
                             : Theme.alpha(Theme.bg, 0.4)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "↺"
                            color: resetMouse.containsMouse ? Theme.text : Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: 16; font.bold: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.resetPosition()
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32; radius: 16
                        color: doneMouse.pressed ? Theme.alpha(Theme.text, 0.18)
                             : doneMouse.containsMouse ? Theme.alpha(Theme.text, 0.12)
                             : Theme.alpha(Theme.bg, 0.4)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 1
                            text: ">"
                            color: doneMouse.containsMouse ? Theme.text : Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: 16; font.bold: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: doneMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.settingsOpen = false
                        }
                    }
                }
            }
        }
    }
}
