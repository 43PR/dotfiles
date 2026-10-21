pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    // ---- lifecycle -------------------------------------------------------
    property bool showing: false      // logical "panel is open"
    property bool mounted: false      // window exists
    property var targetScreen: Quickshell.screens[0]
    property real winW: 0             // reported by the window while mounted
    property real winH: 0
    property real panelH: 0           // MINIMUM panel height (notes list hidden), used for clamping

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            unmountTimer.restart()
        }
    }

    // must be longer than the fade-out (panel opacity = 180ms)
    Timer {
        id: unmountTimer
        interval: 300
        onTriggered: {
            root.mounted = false
            root.winW = 0
            root.winH = 0
            root.panelH = 0
        }
    }

    // ---- layout / state ---------------------------------------------------
    property int topGap: 4
    property int sideGap: 16
    property int baseWidth: 440
    property int baseRow: 48
    property int maxItems: 200

    property bool ready: false
    property bool dragging: false     // moving the panel
    property int menuSize: 100        // COMPONENT scale (%): panel, spacing, text
    property int textSize: 100        // TEXT size (%): fonts only, on top of the component scale
    property real offsetX: 0
    property real offsetY: 0

    // wheel accumulators so touchpads / smooth wheels step once per notch
    property real wheelAccText: 0
    property real wheelAccScale: 0

    readonly property int defaultSize: 100
    readonly property int defaultText: 100
    readonly property real ui: menuSize / 100
    readonly property real tx: textSize / 100
    readonly property int cardWidth: Math.round(baseWidth * ui)
    readonly property int rowHeight: Math.round(baseRow * ui)

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/todo-state.json"

    onMenuSizeChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)
    onCardWidthChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)

    // Each note has:
    //   heading   - the note's title (optional, single line)
    //   title     - the note's body text (name kept for compatibility with old saved state)
    //   done, remindAt, notified, collapsed
    // dynamicRoles: remindAt can be 0 (int) or a big epoch-ms value (double)
    ListModel { id: todos; dynamicRoles: true }

    // layout size: follows the component scale only
    function px(n) { return Math.round(n * ui) }
    // font size: follows the component scale AND the text size
    function fpx(n) { return Math.round(n * ui * tx) }

    // component scale
    function setSize(v) {
        root.menuSize = Math.max(60, Math.min(200, Math.round(v)))
        saveTimer.restart()
    }

    // text size
    function setTextSize(v) {
        root.textSize = Math.max(60, Math.min(200, Math.round(v)))
        saveTimer.restart()
    }

    // Ctrl + wheel -> text size. One 5% step per 120 units of angleDelta (one wheel notch)
    function wheelText(delta) {
        root.wheelAccText += delta
        while (root.wheelAccText >= 120) {
            root.wheelAccText -= 120
            root.setTextSize(root.textSize + 5)
        }
        while (root.wheelAccText <= -120) {
            root.wheelAccText += 120
            root.setTextSize(root.textSize - 5)
        }
    }

    // Shift + wheel -> component scale
    function wheelScale(delta) {
        root.wheelAccScale += delta
        while (root.wheelAccScale >= 120) {
            root.wheelAccScale -= 120
            root.setSize(root.menuSize + 5)
        }
        while (root.wheelAccScale <= -120) {
            root.wheelAccScale += 120
            root.setSize(root.menuSize - 5)
        }
    }

    // The panel can go anywhere on screen: right edge .. left edge, top edge .. bottom edge.
    // offsetX: rightMargin = sideGap - offsetX, so offsetX = sideGap puts the panel flush right.
    // offsetY: topMargin = topGap + offsetY, so offsetY = -topGap puts the panel flush top.
    function setPosition(x, y) {
        if (root.winW <= 0 || root.winH <= 0) {
            root.offsetX = x
            root.offsetY = y
            return
        }
        var maxX = root.sideGap
        var minX = Math.min(maxX, root.cardWidth + root.sideGap - root.winW)
        var minY = -root.topGap
        var maxY = Math.max(minY, root.winH - root.panelH - root.topGap)
        root.offsetX = Math.max(minX, Math.min(maxX, x))
        root.offsetY = Math.max(minY, Math.min(maxY, y))
    }

    // double-click on the drag handle: back to defaults (position, scale, text size)
    function resetPosition() {
        root.offsetX = 0
        root.offsetY = 0
        root.menuSize = root.defaultSize
        root.textSize = root.defaultText
        saveTimer.restart()
    }

    function saveNow() {
        if (!root.ready) return
        var out = []
        for (var i = 0; i < todos.count; i++) {
            var e = todos.get(i)
            out.push({
                heading: e.heading,
                title: e.title,
                done: e.done,
                remindAt: e.remindAt,
                notified: e.notified,
                collapsed: e.collapsed
            })
        }
        store.setText(JSON.stringify({
            menuSize: root.menuSize,
            textSize: root.textSize,
            offsetX: root.offsetX,
            offsetY: root.offsetY,
            items: out
        }))
    }

    // returns true when a note was actually added
    function addTodo(t) {
        t = t.trim()
        if (t === "" || todos.count >= root.maxItems) return false
        todos.insert(0, {
            heading: "",
            title: t,
            done: false,
            remindAt: 0,
            notified: false,
            collapsed: false
        })
        saveTimer.restart()
        return true
    }

    // body text
    function editTodo(i, t) {
        if (i < 0 || i >= todos.count) return
        todos.setProperty(i, "title", t)
        saveTimer.restart()
    }

    // note title
    function editHeading(i, h) {
        if (i < 0 || i >= todos.count) return
        todos.setProperty(i, "heading", h)
        saveTimer.restart()
    }

    function toggleTodo(i) {
        todos.setProperty(i, "done", !todos.get(i).done)
        saveTimer.restart()
    }

    function toggleCollapsed(i) {
        if (i < 0 || i >= todos.count) return
        todos.setProperty(i, "collapsed", !todos.get(i).collapsed)
        saveTimer.restart()
    }

    function removeTodo(i) {
        todos.remove(i)
        saveTimer.restart()
    }

    // right-click drag: move a note to another position in the list
    function moveTodo(from, to) {
        if (from === to || from < 0 || to < 0 || from >= todos.count || to >= todos.count) return
        todos.move(from, to, 1)
        saveTimer.restart()
    }

    // ---- reminders ---------------------------------------------------------
    function setReminder(i, ts) {
        if (i < 0 || i >= todos.count) return
        todos.setProperty(i, "remindAt", ts)
        todos.setProperty(i, "notified", false)
        saveTimer.restart()
        root.checkReminders()   // fires immediately if already due
    }

    function clearReminder(i) { root.setReminder(i, 0) }

    // Accepted:
    //   relative:   "30s" "45m" "2h" "1d" (a bare number = minutes)
    //   time:       "14:30" "14:30:15" "2pm" "2:30pm" "2:30 pm"  (next occurrence)
    //   day + time: "tmr 9am" "tomorrow 14:30" "fri 2:30pm" "2d 1pm" "today 6pm"
    // Returns epoch ms, or 0 if invalid.
    function parseTime(s) {
        var m = s.match(/^(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*(am|pm)?$/)
        if (!m) return null
        // a bare number is not a time (it is handled as relative minutes)
        if (m[2] === undefined && m[4] === undefined) return null
        var hh = parseInt(m[1])
        var mm = m[2] !== undefined ? parseInt(m[2]) : 0
        var ss = m[3] !== undefined ? parseInt(m[3]) : 0
        if (mm > 59 || ss > 59) return null
        if (m[4] !== undefined) {
            if (hh < 1 || hh > 12) return null
            if (m[4] === "am") hh = (hh === 12) ? 0 : hh
            else hh = (hh === 12) ? 12 : hh + 12
        } else if (hh > 23) {
            return null
        }
        return { h: hh, m: mm, s: ss }
    }

    function parseWhen(s) {
        s = s.trim().toLowerCase()

        // relative: 30s / 45m / 2h / 1d
        var m = s.match(/^(\d+)\s*(s|sec|m|min|h|hr|d)?$/)
        if (m) {
            var n = parseInt(m[1])
            var u = m[2] || "m"
            var ms
            if (u === "s" || u === "sec") ms = 1000
            else if (u.charAt(0) === "h") ms = 3600000
            else if (u === "d") ms = 86400000
            else ms = 60000
            return n > 0 ? Date.now() + n * ms : 0
        }

        // optional day word in front: today / tmr / tomorrow / fri / 2d
        var dayOffset = -1          // -1 = no day given
        var weekday = -1
        var rest = s
        var dm = s.match(/^(\S+)\s+(.+)$/)
        if (dm) {
            var tok = dm[1]
            var dd
            if (tok === "today") dayOffset = 0
            else if (tok === "tomorrow" || tok === "tmr" || tok === "tom") dayOffset = 1
            else if ((dd = tok.match(/^(\d+)d$/))) dayOffset = parseInt(dd[1])
            else if (/^(sun|mon|tue|wed|thu|fri|sat)[a-z]*$/.test(tok))
                weekday = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"].indexOf(tok.slice(0, 3))
            if (dayOffset >= 0 || weekday >= 0) rest = dm[2]
        }

        var t = root.parseTime(rest)
        if (!t) return 0

        var d = new Date()
        d.setHours(t.h, t.m, t.s, 0)

        if (weekday >= 0) {
            var diff = (weekday - new Date().getDay() + 7) % 7
            d.setDate(d.getDate() + diff)
            if (d.getTime() <= Date.now()) d.setDate(d.getDate() + 7)   // same weekday, time passed -> next week
        } else if (dayOffset >= 0) {
            d.setDate(d.getDate() + dayOffset)
            if (d.getTime() <= Date.now()) return 0                      // explicit day, but already in the past
        } else if (d.getTime() <= Date.now()) {
            d.setDate(d.getDate() + 1)                                   // plain time: next occurrence
        }
        return d.getTime()
    }

    function formatWhen(ts) {
        var d = new Date(ts)
        var now = new Date()
        var tom = new Date()
        tom.setDate(now.getDate() + 1)
        var hm = Qt.formatTime(d, d.getSeconds() !== 0 ? "HH:mm:ss" : "HH:mm")
        if (d.toDateString() === now.toDateString()) return "Today " + hm
        if (d.toDateString() === tom.toDateString()) return "Tomorrow " + hm
        return Qt.formatDate(d, "d MMM") + " " + hm
    }

    function notify(title) {
        Quickshell.execDetached([
            "notify-send",
            "-a", "Todo",
            "-u", "critical",
            "--",
            "Reminder",
            title
        ])
    }

    function checkReminders() {
        if (!root.ready) return
        var now = Date.now()
        var fired = false
        for (var i = 0; i < todos.count; i++) {
            var e = todos.get(i)
            if (!e.done && e.remindAt > 0 && !e.notified && e.remindAt <= now) {
                // prefer the note's title; fall back to its body text
                root.notify(e.heading !== "" ? e.heading : e.title)
                todos.setProperty(i, "notified", true)
                fired = true
            }
        }
        if (fired) saveTimer.restart()
    }

    // lives on the Scope, so reminders fire even while the panel is closed.
    // 1 s so second-level reminders are accurate.
    Timer {
        id: reminderTimer
        interval: 1000
        repeat: true
        running: root.ready
        triggeredOnStart: true
        onTriggered: root.checkReminders()
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
                    if (typeof data.textSize === "number")
                        root.textSize = Math.max(60, Math.min(200, Math.round(data.textSize)))
                    if (typeof data.offsetX === "number") root.offsetX = data.offsetX
                    if (typeof data.offsetY === "number") root.offsetY = data.offsetY
                }
                for (var i = 0; i < arr.length; i++) {
                    if (typeof arr[i].title === "string")
                        todos.append({
                            heading: typeof arr[i].heading === "string" ? arr[i].heading : "",
                            title: arr[i].title,
                            done: arr[i].done === true,
                            remindAt: typeof arr[i].remindAt === "number" ? arr[i].remindAt : 0,
                            notified: arr[i].notified === true,
                            collapsed: arr[i].collapsed === true
                        })
                }
            } catch (e) {
                console.warn("todo: could not read saved state:", e)
            }
            root.ready = true
        }
        onLoadFailed: root.ready = true
    }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.targetScreen = scr
        }
        dragging = false
        showing = true   // onShowingChanged mounts the window
    }

    function closeMenu() { showing = false; dragging = false }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    IpcHandler {
        target: "todo"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
    }

    // ---- small reusable components ---------------------------------------
    component ChipBtn: Rectangle {
        id: chip
        property real ui: 1
        property real tx: 1
        property string label: ""
        signal clicked()

        height: Math.max(Math.round(24 * ui), chipText.implicitHeight + Math.round(8 * ui))
        width: chipText.implicitWidth + Math.round(20 * ui)
        radius: Math.round(8 * ui)
        color: chipArea.containsMouse ? Theme.alpha(Theme.text, 0.18) : Theme.alpha(Theme.text, 0.08)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.pixelSize: Math.round(11 * chip.ui * chip.tx)
            color: Theme.text
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    // ---- the window: only exists while mounted ---------------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win
            screen: root.targetScreen

            // The window is created with `showing` already true, so a plain
            // `opacity: root.showing ? 1 : 0` would pop in with no fade.
            // `reveal` starts false and is bound to `showing` one tick later.
            property bool reveal: false

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "todo"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: Region { item: root.showing ? panel : null }

            onWidthChanged: {
                root.winW = width
                if (root.showing) root.setPosition(root.offsetX, root.offsetY)
            }
            onHeightChanged: {
                root.winH = height
                if (root.showing) root.setPosition(root.offsetX, root.offsetY)
            }

            Component.onCompleted: {
                root.setPosition(root.offsetX, root.offsetY)
                Qt.callLater(function () {
                    win.reveal = Qt.binding(function () { return root.showing })
                })
            }

            Item {
                id: menuRoot
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.closeMenu()
                Rectangle {
                    id: panel
                    width: root.cardWidth
                    // panelCol top margin (6) + bottom padding (6)
                    height: panelCol.height + root.px(12)
                    radius: root.px(20)
                    color: "transparent"

                    anchors.top: parent.top
                    anchors.topMargin: root.topGap + root.offsetY
                    anchors.right: parent.right
                    anchors.rightMargin: root.sideGap - root.offsetX

                    opacity: win.reveal ? 1 : 0
                    visible: opacity > 0

                    // ---- space accounting for the notes list ----------------
                    // Height of everything except the list (list visible: 2 gaps).
                    readonly property real chromeH: root.px(12) + header.height + inputBox.height
                                                    + panelCol.spacing * 2
                    // Vertical room left below the panel's top edge for the list.
                    readonly property real listAvail: root.winH - root.topGap - root.offsetY - chromeH
                    // The list hides itself when there isn't room for a row.
                    readonly property bool listFits: listAvail >= root.rowHeight
                    // Smallest the panel can ever be (list hidden). Used to clamp dragging
                    // so the panel can reach the very bottom of the screen.
                    readonly property real minH: chromeH - panelCol.spacing
                                                 + (todos.count === 0 ? root.px(40) + panelCol.spacing : 0)

                    onMinHChanged: {
                        root.panelH = minH
                        if (root.showing) root.setPosition(root.offsetX, root.offsetY)
                    }

                    // the panel starts invisible (fade-in), so focus the input
                    // as soon as it actually becomes visible
                    onVisibleChanged: if (visible && root.showing) input.forceActiveFocus()

                    Component.onCompleted: root.panelH = panel.minH

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

                    MouseArea { anchors.fill: parent }

                    Column {
                        id: panelCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: root.px(6)
                        anchors.leftMargin: root.px(14)
                        anchors.rightMargin: root.px(14)
                        spacing: root.px(10)

                        Item {
                            id: header
                            width: parent.width
                            height: root.px(38)

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
                            id: inputBox
                            width: parent.width
                            // the placeholder can wrap to two lines, so it counts toward the height
                            height: Math.max(root.rowHeight,
                                             Math.max(input.contentHeight,
                                                      input.text === "" ? hint.implicitHeight : 0)
                                             + root.px(24))
                            radius: root.px(12)
                            color: Theme.bg
                            border.width: input.activeFocus ? 1 : 0
                            border.color: Theme.accent
                            Behavior on color { ColorAnimation { duration: 120 } }

                            // click anywhere in the box (not just on the text) to focus the input
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                onClicked: {
                                    input.forceActiveFocus()
                                    input.cursorPosition = input.length
                                }
                            }

                            TextEdit {
                                id: input
                                anchors.left: parent.left
                                anchors.leftMargin: root.px(14)
                                anchors.right: parent.right
                                anchors.rightMargin: root.px(12)
                                anchors.top: parent.top
                                anchors.topMargin: root.px(12)
                                font.pixelSize: root.fpx(12)
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
                                        } else if (root.addTodo(input.text)) {
                                            input.text = ""
                                        }
                                    } else if (e.key === Qt.Key_Escape) {
                                        e.accepted = true
                                        root.closeMenu()
                                    }
                                }

                                Text {
                                    id: hint
                                    visible: input.text === "" && !input.inputMethodComposing
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: "Enter: Save | Shift+Enter: New line | Ctrl+Scroll: Text size | Shift+Scroll: Scale"
                                    font.pixelSize: root.fpx(11)
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
                            font.pixelSize: root.fpx(11)
                            color: Theme.textDim
                        }

                        ListView {
                            id: list
                            // hides itself when the panel is dragged so low there's no room
                            visible: todos.count > 0 && panel.listFits
                            width: parent.width
                            height: Math.max(0, Math.min(contentHeight, panel.listAvail))
                            clip: true
                            spacing: root.px(8)
                            model: todos
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: entry
                                required property int index
                                required property string heading
                                required property string title
                                required property bool done
                                required property real remindAt
                                required property bool notified
                                required property bool collapsed

                                // reminder picker open?
                                property bool picking: false
                                // being dragged with right-click
                                property bool reordering: false

                                // a collapsed note never shows the reminder picker
                                onCollapsedChanged: if (entry.collapsed) entry.picking = false

                                width: list.width
                                height: Math.max(root.rowHeight,
                                                 content.height + root.px(22),
                                                 btnCol.height + root.px(16))
                                radius: root.px(12)
                                color: Theme.bg
                                border.width: (edit.activeFocus || titleEdit.activeFocus || entry.reordering) ? 1 : 0
                                border.color: Theme.accent
                                z: entry.reordering ? 2 : 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                MouseArea {
                                    id: hoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        // clicking a collapsed note expands it
                                        if (entry.collapsed) {
                                            root.toggleCollapsed(entry.index)
                                        } else {
                                            edit.forceActiveFocus()
                                            edit.cursorPosition = edit.length
                                        }
                                    }
                                }

                                Rectangle {
                                    id: check
                                    width: root.px(15)
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
                                        font.pixelSize: root.fpx(13)
                                        font.bold: true
                                        color: Theme.bg
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.toggleTodo(entry.index)
                                    }
                                }

                                // title + body + reminder stuff, stacked
                                Column {
                                    id: content
                                    anchors.left: check.right
                                    anchors.leftMargin: root.px(11)
                                    anchors.right: btnCol.left
                                    anchors.rightMargin: root.px(6)
                                    anchors.top: parent.top
                                    anchors.topMargin: root.px(11)
                                    spacing: root.px(4)

                                    // note title (single line)
                                    TextInput {
                                        id: titleEdit
                                        width: content.width
                                        visible: !entry.collapsed || entry.heading !== "" || titleEdit.activeFocus
                                        font.pixelSize: root.fpx(12)
                                        font.bold: true
                                        font.strikeout: entry.done
                                        color: entry.done ? Theme.textDim : Theme.text
                                        opacity: entry.done ? 0.7 : 1
                                        selectionColor: Theme.accent
                                        selectedTextColor: Theme.bg
                                        selectByMouse: true
                                        clip: true

                                        Component.onCompleted: titleEdit.text = entry.heading

                                        onTextChanged: {
                                            if (titleEdit.activeFocus)
                                                root.editHeading(entry.index, titleEdit.text)
                                        }

                                        Keys.onPressed: function (e) {
                                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter
                                                    || e.key === Qt.Key_Tab) {
                                                e.accepted = true
                                                if (entry.collapsed) input.forceActiveFocus()
                                                else edit.forceActiveFocus()
                                            } else if (e.key === Qt.Key_Escape) {
                                                e.accepted = true
                                                root.closeMenu()
                                            }
                                        }

                                        Text {
                                            visible: titleEdit.text === "" && !entry.collapsed
                                                     && !titleEdit.inputMethodComposing
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Title"
                                            font.pixelSize: root.fpx(11)
                                            font.bold: false
                                            color: Theme.textDim
                                            opacity: 0.5
                                        }
                                    }

                                    // collapsed + no title: show the first line of the body instead
                                    Text {
                                        visible: entry.collapsed && entry.heading === ""
                                        width: content.width
                                        text: entry.title.split("\n")[0] !== "" ? entry.title.split("\n")[0] : "(empty)"
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        font.pixelSize: root.fpx(11)
                                        font.strikeout: entry.done
                                        color: entry.done ? Theme.textDim : Theme.text
                                        opacity: entry.done ? 0.7 : 1
                                    }

                                    // note body
                                    TextEdit {
                                        id: edit
                                        width: content.width
                                        visible: !entry.collapsed
                                        font.pixelSize: root.fpx(11)
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

                                    // reminder label + picker, below the text
                                    Column {
                                        id: extras
                                        width: content.width
                                        // an empty Column would still add spacing to `content`
                                        visible: entry.remindAt > 0 || entry.picking
                                        spacing: root.px(6)

                                        Text {
                                            visible: entry.remindAt > 0
                                            text: "⏰ " + root.formatWhen(entry.remindAt)
                                                  + (entry.notified ? "  ·  sent" : "")
                                            font.pixelSize: root.fpx(10)
                                            color: entry.notified ? Theme.textDim : Theme.accent
                                        }

                                        Flow {
                                            visible: entry.picking
                                            width: parent.width
                                            spacing: root.px(6)

                                            Repeater {
                                                // s = seconds
                                                model: [
                                                    { l: "5m",  s: 300 },
                                                    { l: "25m", s: 1500 },
                                                    { l: "1h",  s: 3600 },
                                                ]

                                                delegate: ChipBtn {
                                                    required property var modelData
                                                    ui: root.ui
                                                    tx: root.tx
                                                    label: modelData.l
                                                    onClicked: {
                                                        root.setReminder(entry.index, Date.now() + modelData.s * 1000)
                                                        entry.picking = false
                                                    }
                                                }
                                            }

                                            ChipBtn {
                                                visible: entry.remindAt > 0
                                                ui: root.ui
                                                tx: root.tx
                                                label: "Clear"
                                                onClicked: {
                                                    root.clearReminder(entry.index)
                                                    entry.picking = false
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: customBox
                                            visible: entry.picking
                                            property bool bad: false
                                            width: parent.width
                                            height: Math.max(root.px(26), customInput.contentHeight + root.px(10))
                                            radius: root.px(8)
                                            color: Theme.alpha(Theme.text, 0.08)
                                            border.width: (customInput.activeFocus || bad) ? 1 : 0
                                            border.color: bad ? Theme.danger : Theme.accent

                                            TextInput {
                                                id: customInput
                                                anchors.fill: parent
                                                anchors.leftMargin: root.px(8)
                                                anchors.rightMargin: root.px(8)
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.pixelSize: root.fpx(11)
                                                color: Theme.text
                                                selectionColor: Theme.accent
                                                selectedTextColor: Theme.bg
                                                clip: true

                                                onTextChanged: customBox.bad = false

                                                Keys.onPressed: function (e) {
                                                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                                        e.accepted = true
                                                        var ts = root.parseWhen(customInput.text)
                                                        if (ts > 0) {
                                                            root.setReminder(entry.index, ts)
                                                            customInput.text = ""
                                                            entry.picking = false
                                                            input.forceActiveFocus()
                                                        } else {
                                                            customBox.bad = true
                                                        }
                                                    } else if (e.key === Qt.Key_Escape) {
                                                        e.accepted = true
                                                        entry.picking = false
                                                        input.forceActiveFocus()
                                                    }
                                                }

                                                Text {
                                                    visible: customInput.text === ""
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "e.g. 15m · 20:10 · 9am · 2:30pm · fri 14:30"
                                                    font.pixelSize: root.fpx(11)
                                                    color: Theme.textDim
                                                    opacity: 0.7
                                                }
                                            }
                                        }
                                    }
                                }

                                // Right-hand button stack, top to bottom:
                                //   ✕ delete
                                //   ⏰ reminder   (hidden while the note is collapsed)
                                //   ▾/▸ collapse / expand
                                Column {
                                    id: btnCol
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.px(10)
                                    anchors.top: parent.top
                                    anchors.topMargin: root.px(8)
                                    spacing: 0
                                    Item {
                                        id: collapseBtn
                                        width: root.px(22)
                                        height: width

                                        Text {
                                            anchors.centerIn: parent
                                            text: entry.collapsed ? "⌵" : "⌃"
                                            font.pixelSize: root.fpx(12)
                                            color: collapseArea.containsMouse ? Theme.accent : Theme.textDim
                                            opacity: (hoverArea.containsMouse || collapseArea.containsMouse) ? 1 : 0.4
                                            Behavior on opacity { NumberAnimation { duration: 120 } }
                                        }

                                        MouseArea {
                                            id: collapseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: root.toggleCollapsed(entry.index)
                                        }
                                    }
                                    Item {
                                        id: bellBtn
                                        width: root.px(22)
                                        height: width
                                        visible: !entry.collapsed

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰂚"
                                            font.pixelSize: root.fpx(12)
                                            color: Theme.textDim
                                            opacity: (entry.remindAt > 0 && !entry.notified) || entry.picking ? 1
                                                     : (hoverArea.containsMouse || bellArea.containsMouse) ? 0.9
                                                     : 0.4
                                            Behavior on opacity { NumberAnimation { duration: 120 } }
                                        }

                                        MouseArea {
                                            id: bellArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                entry.picking = !entry.picking
                                                if (entry.picking)
                                                    Qt.callLater(function () { customInput.forceActiveFocus() })
                                            }
                                        }
                                    }
                                    Item {
                                        id: delBtn
                                        width: root.px(22)
                                        height: width

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: root.fpx(12)
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
                                // Right-click + drag: reorder this note.
                                // Last child = topmost; only reacts to the right button,
                                // so left-clicks still reach the checkbox, text, buttons.
                                MouseArea {
                                    id: reorderArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    preventStealing: true

                                    onPressed: entry.reordering = true
                                    onReleased: entry.reordering = false
                                    onCanceled: entry.reordering = false

                                    onPositionChanged: function (mouse) {
                                        if (!pressed) return
                                        // cursor position in the list's content coordinates
                                        var p = reorderArea.mapToItem(list.contentItem, mouse.x, mouse.y)
                                        var idx = list.indexAt(list.width / 2, p.y)
                                        if (idx < 0) {
                                            if (p.y <= 0) idx = 0                                       // above the first note
                                            else if (p.y >= list.contentHeight) idx = todos.count - 1   // below the last note
                                            else return                                                 // in the gap between notes
                                        }
                                        if (idx === entry.index) return
                                        var it = list.itemAtIndex(idx)
                                        if (!it) return
                                        // swap only after crossing the middle of the other note, so notes
                                        // of different heights don't flip back and forth
                                        var mid = it.y + it.height / 2
                                        if ((idx > entry.index && p.y > mid) || (idx < entry.index && p.y < mid))
                                            root.moveTodo(entry.index, idx)
                                    }
                                }
                            }
                        }
                    }

                    // Topmost overlay for wheel shortcuts:
                    //   Ctrl  + scroll -> text size only
                    //   Shift + scroll -> component scale
                    // Plain scroll passes through so the list scrolls normally.
                    // Starts below the header so the drag handle keeps its hover/cursor.
                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.top: parent.top
                        anchors.topMargin: panelCol.anchors.topMargin + header.height + panelCol.spacing
                        z: 100
                        acceptedButtons: Qt.NoButton   // never steals clicks
                        onWheel: function (wheel) {
                            var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                            if (wheel.modifiers & Qt.ControlModifier) {
                                root.wheelText(dy)
                                wheel.accepted = true
                            } else if (wheel.modifiers & Qt.ShiftModifier) {
                                root.wheelScale(dy)
                                wheel.accepted = true
                            } else {
                                wheel.accepted = false
                            }
                        }
                    }
                }
            }
        }
    }
}