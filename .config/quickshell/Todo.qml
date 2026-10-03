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
    property int cardWidth: 440
    property int rowHeight: 48
    property int maxItems: 200

    property bool showing: false
    property bool ready: false
    property int remaining: 0

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/todo-state.json"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "todo"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? menuRoot : null }

    ListModel { id: todos }

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
        store.setText(JSON.stringify(out))
    }

    function changed() {
        root.recount()
        saveTimer.restart()
    }

    function addTodo(t) {
        t = t.trim()
        if (t === "" || todos.count >= root.maxItems) return
        todos.insert(0, { title: t, done: false })   // newest on top
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
                var arr = JSON.parse(store.text())
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
        showing = true
        Qt.callLater(function () {
            if (root.showing) input.forceActiveFocus()
        })
    }

    function closeMenu() { showing = false }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    IpcHandler {
        target: "todo"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
    }
    // Small square button (same look as the power menu footer buttons)
    component FooterButton: Rectangle {
        id: fb
        property string label: ""
        property int fontSize: 11
        property color textColor: Theme.textDim
        readonly property bool hovered: fbArea.containsMouse
        signal clicked()

        width: 24; height: 24; radius: 8
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
    Item {
        id: menuRoot
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.closeMenu()

        // Backdrop: click outside closes
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeMenu()
        }

        Rectangle {
            id: panel
            width: root.cardWidth
            height: panelCol.height + 28
            radius: 20
            color: "transparent"

            anchors.top: parent.top
            anchors.topMargin: root.topGap
            anchors.right: parent.right
            anchors.rightMargin: root.showing ? root.sideGap : -(root.cardWidth + 40)

            opacity: root.showing ? 1 : 0
            visible: opacity > 0

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            // Swallow clicks on the card (so gaps don't close it)
            MouseArea { anchors.fill: parent }

            Column {
                id: panelCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                spacing: 10

                // Top spacer (same as the power menu header)
                Item {
                    width: parent.width
                    height: 24
                }
                Rectangle {
                    width: parent.width
                    height: Math.max(root.rowHeight, input.contentHeight + 24)
                    radius: 12
                    color: Theme.bg
                    border.width: input.activeFocus ? 1 : 0
                    border.color: Theme.accent
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        id: addThumb
                        width: 32; height: 32; radius: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        color: Theme.bg

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 16
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
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        font.pixelSize: 12
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
                            text: "Add a task…  (Shift+Enter = new line)"
                            font.pixelSize: 12
                            color: Theme.textDim
                            opacity: 0.7
                        }
                    }
                }

                Text {
                    visible: todos.count === 0
                    width: parent.width
                    height: 40
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "Nothing to do"
                    font.pixelSize: 11
                    color: Theme.textDim
                }
                ListView {
                    id: list
                    visible: todos.count > 0
                    width: parent.width
                    height: Math.min(contentHeight, root.height - root.topGap - 240)
                    clip: true
                    spacing: 8
                    model: todos
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: entry
                        required property int index
                        required property string title
                        required property bool done

                        width: list.width
                        height: Math.max(root.rowHeight, edit.contentHeight + 24)
                        radius: 12
                        color: Theme.bg
                        border.width: edit.activeFocus ? 1 : 0
                        border.color: Theme.accent
                        Behavior on color { ColorAnimation { duration: 120 } }

                        // Hover tracking only (doesn't steal clicks from the text)
                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        // Checkbox
                        Rectangle {
                            id: check
                            width: 24; height: 24; radius: 8
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            color: entry.done ? Theme.accent : "transparent"
                            border.width: 1
                            border.color: entry.done ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                visible: entry.done
                                text: "✓"
                                font.pixelSize: 13
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
                            anchors.leftMargin: 12
                            anchors.right: delBtn.left
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            font.pixelSize: 12
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
                                        input.forceActiveFocus()   // finish editing
                                    }
                                } else if (e.key === Qt.Key_Escape) {
                                    e.accepted = true
                                    root.closeMenu()
                                }
                            }
                        }

                        // Delete
                        Item {
                            id: delBtn
                            width: 24; height: 24
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 12

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 12
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
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.remaining + " left"
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.textDim
                        opacity: 0.8
                    }

                    FooterButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
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