pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth

Scope {
    id: root

    // ---- lifecycle -------------------------------------------------------
    property bool showing: false
    property bool mounted: false
    property var targetScreen: Quickshell.screens[0]

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            unmountTimer.restart()
        }
    }

    Timer {
        id: unmountTimer
        interval: 200
        onTriggered: root.mounted = false
    }

    // ---- config / state ---------------------------------------------------
    property string iconFont: "Symbols Nerd Font"
    property int ringRadius: 118
    property int ringThickness: 46
    property int gapAngle: 5
    property int deadZone: 40
    property int nightTemp: 4500

    property int selected: -1

    // toggle states
    property bool wifiOn: false
    property bool nightOn: false
    property bool dndOn: false
    property real brightness: 0.6          // 0..1, synced from brightnessctl
    property int brightnessStep: 5         // percent per scroll notch / keypress
    readonly property bool btOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false

    readonly property int outerZone: ringRadius + ringThickness
    readonly property real step: 360 / items.length
    readonly property var items: [
        { key: "area",   name: "Area",        toggle: false,
          cmd: ["sh", "-c", "sleep 0.25; exec \"$HOME/.config/hypr/scripts/screenshot-area.sh\""] },
        { key: "wifi",   name: "Wi-Fi",       toggle: true },
        { key: "bt",     name: "Bluetooth",   toggle: true },
        { key: "dnd",    name: "DND",         toggle: true },
        { key: "night",  name: "Night Light", toggle: true },
        { key: "bright", name: "Brightness",  toggle: false, adjust: true }
    ]

    function isOn(key) {
        switch (key) {
        case "wifi":  return wifiOn
        case "bt":    return btOn
        case "night": return nightOn
        case "dnd":   return dndOn
        }
        return false
    }

    function iconFor(key) {
        switch (key) {
        case "area":   return "\uf125"
        case "wifi":   return wifiOn ? "\udb81\udda9" : "\udb81\uddaa"   // 󰖩 / 󰖪
        case "bt":     return btOn ? "\udb80\udcaf" : "\udb80\udcb2"      // 󰂯 / 󰂲
        case "night":  return "\uf186"                                    //  moon
        case "dnd":    return dndOn ? "\udb80\udc9b" : "\udb80\udc9a"    // 󰂛 / 󰂚
        case "bright": return "\uf185"                                    //  sun
        }
        return ""
    }

    // ---- state readers ----------------------------------------------------
    Process {
        id: wifiCheck
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiOn = text.trim() === "enabled"
        }
    }

    Process {
        id: nightCheck
        command: ["pgrep", "-x", "gammastep"]
        onExited: function (code) { root.nightOn = (code === 0) }
    }

    Process {
        id: dndCheck
        command: ["qs", "ipc", "call", "notifications", "isDnd"]
        stdout: StdioCollector {
            onStreamFinished: root.dndOn = text.trim() === "true"
        }
    }

    Process {
        id: brightCheck
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(",")
                if (parts.length >= 4) {
                    var pct = parseInt(parts[3])
                    if (!isNaN(pct)) root.brightness = pct / 100
                }
            }
        }
    }

    function refreshStates() {
        wifiCheck.running = true
        nightCheck.running = true
        dndCheck.running = true
        brightCheck.running = true
    }

    // re-sync with reality shortly after a toggle
    Timer {
        id: recheckTimer
        interval: 700
        onTriggered: root.refreshStates()
    }

    // ---- bluetooth: disconnect devices first, then power off --------------
    Timer {
        id: btOffTimer
        interval: 400
        onTriggered: {
            if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = false
        }
    }

    function toggleBluetooth() {
        var a = Bluetooth.defaultAdapter
        if (!a) return
        if (a.enabled) {
            var devs = a.devices.values
            for (var i = 0; i < devs.length; i++) {
                if (devs[i].connected) devs[i].disconnect()
            }
            btOffTimer.restart()
        } else {
            a.enabled = true
        }
    }

    // ---- actions ----------------------------------------------------------
    function toggleItem(key) {
        switch (key) {
        case "wifi":
            Quickshell.execDetached({ command: ["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"] })
            root.wifiOn = !root.wifiOn
            break
        case "bt":
            toggleBluetooth()
            break
        case "night":
            if (root.nightOn)
                Quickshell.execDetached({ command: ["pkill", "-x", "gammastep"] })
            else
                Quickshell.execDetached({ command: ["gammastep", "-O", String(root.nightTemp)] })
            root.nightOn = !root.nightOn
            break
        case "dnd":
            Quickshell.execDetached({ command: ["qs", "ipc", "call", "notifications", "dnd"] })
            root.dndOn = !root.dndOn
            break
        }
        recheckTimer.restart()
    }

    // floor of 1% so you can't scroll the screen fully black
    function adjustBrightness(deltaPct) {
        var v = Math.max(0.01, Math.min(1, root.brightness + deltaPct / 100))
        root.brightness = v
        Quickshell.execDetached({ command: ["brightnessctl", "set", Math.round(v * 100) + "%"] })
    }

    function selectedIsAdjust() {
        return root.selected >= 0 && root.items[root.selected].adjust === true
    }

    function run(i) {
        if (i < 0 || i >= root.items.length) return
        var a = root.items[i]
        if (a.adjust) return
        if (a.toggle) {
            root.toggleItem(a.key)
        } else {
            root.closeMenu()
            Quickshell.execDetached({ command: a.cmd })
        }
    }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.targetScreen = scr
        }
        root.selected = -1
        root.refreshStates()
        root.showing = true
    }

    function closeMenu() { root.showing = false }
    function toggleMenu() { root.showing ? root.closeMenu() : root.openMenu() }

    IpcHandler {
        target: "wheel"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
        function confirm(): void {
            if (!root.showing) return
            if (root.selected >= 0) root.run(root.selected)
            else root.closeMenu()
        }
    }

    // ---- the window -------------------------------------------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win
            screen: root.targetScreen

            property bool reveal: false

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "wheel"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            mask: Region { item: root.showing ? menuRoot : null }

            Component.onCompleted: {
                menuRoot.forceActiveFocus()
                Qt.callLater(function () {
                    win.reveal = Qt.binding(function () { return root.showing })
                })
            }

            function pointAt(x, y) {
                var dx = x - menuRoot.width / 2
                var dy = y - menuRoot.height / 2
                var d = Math.sqrt(dx * dx + dy * dy)
                if (d < root.deadZone) {
                    root.selected = -1
                    return
                }
                var n = root.items.length
                var a = Math.atan2(dy, dx) * 180 / Math.PI + 90
                if (a < 0) a += 360
                root.selected = Math.round(a / root.step) % n
            }

            Item {
                id: menuRoot
                anchors.fill: parent
                focus: true

                Keys.onPressed: function (event) {
                    if (!root.showing) return
                    var n = root.items.length

                    if (event.key === Qt.Key_Escape) {
                        root.closeMenu()
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        root.selected = (root.selected + 1) % n
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        root.selected = root.selected < 0 ? n - 1 : (root.selected - 1 + n) % n
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                        if (root.selected >= 0) root.run(root.selected)
                        else root.closeMenu()
                    } else if (root.selectedIsAdjust() &&
                               (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.key === Qt.Key_PageUp)) {
                        root.adjustBrightness(root.brightnessStep)
                    } else if (root.selectedIsAdjust() &&
                               (event.key === Qt.Key_Minus || event.key === Qt.Key_PageDown)) {
                        root.adjustBrightness(-root.brightnessStep)
                    }
                    event.accepted = true
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: function (mouse) { win.pointAt(mouse.x, mouse.y) }
                    onWheel: function (ev) {
                        if (root.selectedIsAdjust())
                            root.adjustBrightness(ev.angleDelta.y > 0 ? root.brightnessStep : -root.brightnessStep)
                    }
                    onClicked: function (mouse) {
                        var dx = mouse.x - width / 2
                        var dy = mouse.y - height / 2
                        var d = Math.sqrt(dx * dx + dy * dy)
                        if (d <= root.outerZone && root.selected >= 0) root.run(root.selected)
                        else root.closeMenu()
                    }
                }

                Item {
                    id: wheel
                    width: 2 * (root.ringRadius + root.ringThickness) + 24
                    height: width
                    anchors.centerIn: parent

                    transformOrigin: Item.Center
                    scale: win.reveal ? 1 : 0.92
                    opacity: win.reveal ? 1 : 0
                    visible: opacity > 0

                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                    // center hub: name + on/off state (or brightness %)
                    Rectangle {
                        width: 2 * (root.deadZone + 14)
                        height: width
                        radius: width / 2
                        anchors.centerIn: parent
                        color: "transparent"
                        border.width: 1
                        border.color: root.selected >= 0 ? Theme.accent : Theme.alpha(Theme.text, 0.5)
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            visible: root.selected >= 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.selected >= 0 ? root.items[root.selected].name : ""
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: root.selected >= 0 &&
                                         (root.items[root.selected].toggle || root.items[root.selected].adjust === true)
                                text: {
                                    if (root.selected < 0) return ""
                                    var it = root.items[root.selected]
                                    if (it.adjust) return Math.round(root.brightness * 100) + "%"
                                    return root.isOn(it.key) ? "ON" : "OFF"
                                }
                                font.pixelSize: 9
                                color: {
                                    if (root.selected < 0) return Theme.textDim
                                    var it = root.items[root.selected]
                                    return (it.adjust || root.isOn(it.key)) ? Theme.accent : Theme.textDim
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.items

                        delegate: Item {
                            id: seg
                            required property var modelData
                            required property int index
                            readonly property bool focused: index === root.selected
                            readonly property bool active: modelData.toggle && root.isOn(modelData.key)
                            readonly property real midAngle: (index * root.step - 90) * Math.PI / 180
                            property real rad: root.ringRadius + (focused ? 6 : 0)
                            property real thick: root.ringThickness + (focused ? 6 : 0)
                            readonly property real a0: index * root.step - 90 - root.step / 2 + root.gapAngle / 2
                            readonly property real sweep: root.step - root.gapAngle

                            anchors.fill: parent

                            Behavior on rad { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                            Behavior on thick { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                            Shape {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    fillColor: "transparent"
                                    strokeWidth: 1.5
                                    strokeColor: seg.focused ? Theme.accent : Theme.alpha(Theme.text, 0.5)
                                    joinStyle: ShapePath.RoundJoin
                                    startX: wheel.width / 2 + Math.cos(seg.a0 * Math.PI / 180) * (seg.rad - seg.thick / 2)
                                    startY: wheel.height / 2 + Math.sin(seg.a0 * Math.PI / 180) * (seg.rad - seg.thick / 2)

                                    PathLine {
                                        x: wheel.width / 2 + Math.cos(seg.a0 * Math.PI / 180) * (seg.rad + seg.thick / 2)
                                        y: wheel.height / 2 + Math.sin(seg.a0 * Math.PI / 180) * (seg.rad + seg.thick / 2)
                                    }
                                    PathAngleArc {
                                        moveToStart: false
                                        centerX: wheel.width / 2
                                        centerY: wheel.height / 2
                                        radiusX: seg.rad + seg.thick / 2
                                        radiusY: seg.rad + seg.thick / 2
                                        startAngle: seg.a0
                                        sweepAngle: seg.sweep
                                    }
                                    PathLine {
                                        x: wheel.width / 2 + Math.cos((seg.a0 + seg.sweep) * Math.PI / 180) * (seg.rad - seg.thick / 2)
                                        y: wheel.height / 2 + Math.sin((seg.a0 + seg.sweep) * Math.PI / 180) * (seg.rad - seg.thick / 2)
                                    }
                                }

                                ShapePath {
                                    fillColor: "transparent"
                                    strokeWidth: 1.5
                                    strokeColor: seg.focused ? Theme.accent : Theme.alpha(Theme.text, 0.5)

                                    PathAngleArc {
                                        centerX: wheel.width / 2
                                        centerY: wheel.height / 2
                                        radiusX: seg.rad - seg.thick / 2
                                        radiusY: seg.rad - seg.thick / 2
                                        startAngle: seg.a0
                                        sweepAngle: seg.sweep
                                    }
                                }
                            }

                            Text {
                                x: wheel.width / 2 + Math.cos(seg.midAngle) * seg.rad - width / 2
                                y: wheel.height / 2 + Math.sin(seg.midAngle) * seg.rad - height / 2
                                text: root.iconFor(seg.modelData.key)
                                font.family: root.iconFont
                                font.pixelSize: 20
                                // accent = toggle is ON, bright = hovered, dim = off
                                color: seg.active ? Theme.accent : (seg.focused ? Theme.text : Theme.textDim)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }
                }
            }
        }
    }
}