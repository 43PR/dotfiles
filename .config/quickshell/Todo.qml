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
    property int baseWidth: 440
    property int baseRow: 48
    property int maxItems: 200

    property bool showing: false
    property bool ready: false
    property bool dragging: false
    property int remaining: 0
    property int menuSize: 100
    property real offsetX: 0
    property real offsetY: 0

    readonly property int defaultSize: 100
    readonly property real ui: menuSize / 100
    readonly property int cardWidth: Math.round(baseWidth * ui)
    readonly property int rowHeight: Math.round(baseRow * ui)
    readonly property bool movedFromDefault: offsetX !== 0 || offsetY !== 0 || menuSize !== defaultSize

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/todo-state.json"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "todo"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? menuRoot : null }

    onMenuSizeChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)

    ListModel { id: todos }

    function px(n) { return Math.round(n * ui) }

    function setSize(v) {
        root.menuSize = Math.max(60, Math.min(200, v))
        saveTimer.restart()
    }

    function setPosition(x, y) {
        if (root.width <= 0 || root.height <= 0) {
            root.offsetX = x
            root.offsetY = y
            return
        }
        var maxX = root.sideGap
        var minX = Math.min(maxX, root.cardWidth + 2 * root.sideGap - root.width)
        var minY = 0
        var maxY = Math.max(minY, root.height - panel.height - 2 * root.topGap)
        root.offsetX = Math.max(minX, Math.min(maxX, x))
        root.offsetY = Math.max(minY, Math.min(maxY, y))
    }

    function resetPosition() {
        root.offsetX = 0
        root.offsetY = 0
        root.menuSize = root.defaultSize
        saveTimer.restart()
    }

    function recount() {
        var n = 0
        for (var i = 0; i < todos.count; i++)
            if (!todos.get(i).done) n++
        root.remaining = n
    }

    function saveNow() {
        if (!root.ready) return
        var out = []
        for (var i = 0; i < todos.count; i++) {
            var e = todos.get(i)
            out.push({ title: e.title, done: e.done })
        }
        store.setText(JSON.stringify({
            menuSize: root.menuSize,
            offsetX: root.offsetX,
            offsetY: root.offsetY,
            items: out
        }))
    }

    function changed() {
        root.recount()
        saveTimer.restart()
    }

    function addTodo(t) {
        t = t.trim()
        if (t === "" || todos.count >= root.maxItems) return
        todos.insert(0, { title: t, done: false })
        root.changed()
    }

    function editTodo(i, t) {
        if (i < 0 || i >= todos.count) return
        todos.setProperty(i, "title", t)
        saveTimer.restart()
    }

    function toggleTodo(i) {
        todos.setProperty(i, "done", !todos.get(i).done)
        root.changed()
    }

    function removeTodo(i) {
        todos.remove(i)
        root.changed()
    }

    function clearDone() {
        for (var i = todos.count - 1; i >= 0; i--)
            if (todos.get(i).done) todos.remove(i)
        root.changed()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: root.saveNow()
    }

    FileView {
        id: store
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var data = JSON.parse(store.text())
                var arr = Array.isArray(data) ? data : (data.items || [])
                if (!Array.isArray(data)) {
                    if (typeof data.menuSize === "number")
                        root.menuSize = Math.max(60, Math.min(200, Math.round(data.menuSize)))
                    if (typeof data.offsetX === "number") root.offsetX = data.offsetX
                    if (typeof data.offsetY === "number") root.offsetY = data.offsetY
                }
                for (var i = 0; i < arr.length; i++) {
                    if (typeof arr[i].title === "string")
                        todos.append({ title: arr[i].title, done: arr[i].done === true })
                }
            } catch (e) {
                console.warn("todo: could not read saved state:", e)
            }
            root.ready = true
            root.recount()
        }
        onLoadFailed: root.ready = true
    }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.screen = scr
        }
        dragging = false
        showing = true
        Qt.callLater(function () {
            if (root.showing) {
                input.forceActiveFocus()
                root.setPosition(root.offsetX, root.offsetY)
            }
        })
    }

    function closeMenu() { showing = false; dragging = false }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    IpcHandler {
        target: "todo"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
    }

    component FooterButton: Rectangle {
        id: fb
        property real ui: 1
        property string label: ""
        property int fontSize: 11
        property color textColor: Theme.textDim
        readonly property bool hovered: fbArea.containsMouse
        signal clicked()

        width: Math.round(24 * ui)
        height: width
        radius: Math.round(8 * ui)
        color: Theme.bg
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: fb.label
            font.pixelSize: Math.round(fb.fontSize * fb.ui)
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
        height: 16
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: Theme.text
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    Item {
        id: menuRoot
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.closeMenu()

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeMenu()
        }

        Rectangle {
            id: panel
            width: root.cardWidth
            height: panelCol.height + root.px(28)
            radius: root.px(20)
            color: "transparent"

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
                anchors.margins: root.px(14)
                spacing: root.px(10)

                Item {
                    id: header
                    width: parent.width
                    height: root.px(24)

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.px(36)
                        height: root.px(4)
                        radius: root.px(2)
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
                            saveTimer.restart()
                        }

                        onCanceled: {
                            if (!root.dragging) return
                            root.dragging = false
                            saveTimer.restart()
                        }

                        onDoubleClicked: root.resetPosition()
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(root.rowHeight, input.contentHeight + root.px(24))
                    radius: root.px(12)
                    color: Theme.bg
                    border.width: input.activeFocus ? 1 : 0
                    border.color: Theme.accent
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        id: addThumb
                        width: root.px(32)
                        height: width
                        radius: root.px(8)
                        anchors.left: parent.left
                        anchors.leftMargin: root.px(10)
                        anchors.top: parent.top
                        anchors.topMargin: root.px(8)
                        color: Theme.bg

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: root.px(16)
                            font.bold: true
                            color: Theme.text
                        }

                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.addTodo(input.text)
                                input.text = ""
                                input.forceActiveFocus()
                            }
                        }
                    }

                    TextEdit {
                        id: input
                        anchors.left: addThumb.right
                        anchors.leftMargin: root.px(10)
                        anchors.right: parent.right
                        anchors.rightMargin: root.px(12)
                        anchors.top: parent.top
                        anchors.topMargin: root.px(12)
                        font.pixelSize: root.px(12)
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bg
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        textFormat: TextEdit.PlainText

                        Keys.onPressed: function (e) {
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                e.accepted = true
                                if (e.modifiers & Qt.ShiftModifier) {
                                    input.insert(input.cursorPosition, "\n")
                                } else {
                                    root.addTodo(input.text)
                                    input.text = ""
                                }
                            } else if (e.key === Qt.Key_Escape) {
                                e.accepted = true
                                root.closeMenu()
                            }
                        }

                        Text {
                            visible: input.text === "" && !input.inputMethodComposing
                            text: "Add a note/task…  (Shift+Enter = new line)"
                            font.pixelSize: root.px(12)
                            color: Theme.textDim
                            opacity: 0.7
                        }
                    }
                }

                Text {
                    visible: todos.count === 0
                    width: parent.width
                    height: root.px(40)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "Nothing to do"
                    font.pixelSize: root.px(11)
                    color: Theme.textDim
                }

                ListView {
                    id: list
                    visible: todos.count > 0
                    width: parent.width
                    height: Math.max(0, Math.min(contentHeight, root.height - root.topGap - root.offsetY - root.px(240)))
                    clip: true
                    spacing: root.px(8)
                    model: todos
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: entry
                        required property int index
                        required property string title
                        required property bool done

                        width: list.width
                        height: Math.max(root.rowHeight, edit.contentHeight + root.px(24))
                        radius: root.px(12)
                        color: Theme.bg
                        border.width: edit.activeFocus ? 1 : 0
                        border.color: Theme.accent
                        Behavior on color { ColorAnimation { duration: 120 } }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        Rectangle {
                            id: check
                            width: root.px(24)
                            height: width
                            radius: root.px(8)
                            anchors.left: parent.left
                            anchors.leftMargin: root.px(14)
                            anchors.top: parent.top
                            anchors.topMargin: root.px(12)
                            color: entry.done ? Theme.accent : "transparent"
                            border.width: 1
                            border.color: entry.done ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                visible: entry.done
                                text: "✓"
                                font.pixelSize: root.px(13)
                                font.bold: true
                                color: Theme.bg
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.toggleTodo(entry.index)
                            }
                        }

                        TextEdit {
                            id: edit
                            anchors.left: check.right
                            anchors.leftMargin: root.px(12)
                            anchors.right: delBtn.left
                            anchors.rightMargin: root.px(8)
                            anchors.top: parent.top
                            anchors.topMargin: root.px(12)
                            font.pixelSize: root.px(12)
                            font.strikeout: entry.done
                            color: entry.done ? Theme.textDim : Theme.text
                            opacity: entry.done ? 0.7 : 1
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.bg
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            textFormat: TextEdit.PlainText

                            Component.onCompleted: edit.text = entry.title

                            onTextChanged: {
                                if (edit.activeFocus)
                                    root.editTodo(entry.index, edit.text)
                            }

                            Keys.onPressed: function (e) {
                                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    e.accepted = true
                                    if (e.modifiers & Qt.ShiftModifier) {
                                        edit.insert(edit.cursorPosition, "\n")
                                    } else {
                                        input.forceActiveFocus()
                                    }
                                } else if (e.key === Qt.Key_Escape) {
                                    e.accepted = true
                                    root.closeMenu()
                                }
                            }
                        }

                        Item {
                            id: delBtn
                            width: root.px(24)
                            height: width
                            anchors.right: parent.right
                            anchors.rightMargin: root.px(10)
                            anchors.top: parent.top
                            anchors.topMargin: root.px(12)

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: root.px(12)
                                color: delArea.containsMouse ? Theme.danger : Theme.textDim
                                opacity: (hoverArea.containsMouse || delArea.containsMouse) ? 1 : 0.4
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: delArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.removeTodo(entry.index)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: root.px(24)

                    Row {
                        id: sizeRow
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        opacity: sizeHover.hovered ? 0.9 : 0.35

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        HoverHandler { id: sizeHover }

                        SizeBtn { text: "−"; width: 16; font.pixelSize: 12; onClicked: root.setSize(root.menuSize - 10) }
                        SizeBtn { text: "+"; width: 16; font.pixelSize: 12; onClicked: root.setSize(root.menuSize + 10) }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.px(6)

                        FooterButton {
                            ui: root.ui
                            label: "↺"
                            fontSize: 13
                            opacity: root.movedFromDefault ? 1 : 0.4
                            onClicked: root.resetPosition()
                        }

                        FooterButton {
                            ui: root.ui
                            label: "✓"
                            fontSize: 12
                            opacity: (todos.count - root.remaining) > 0 ? 1 : 0.4
                            onClicked: root.clearDone()
                        }
                    }
                }
            }
        }
    }
}