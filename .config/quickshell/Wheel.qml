pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    property string iconFont: "Symbols Nerd Font"
    property int ringRadius: 118
    property int ringThickness: 46
    property int gapAngle: 5
    property int deadZone: 40

    property bool showing: false
    property int selected: -1

    readonly property int outerZone: ringRadius + ringThickness
    readonly property real step: 360 / items.length
    readonly property var items: [
        { icon: "\udb81\udc93", name: "Settings",  cmd: ["qs", "ipc", "call", "settings", "toggle"] },
        { icon: "\udb80\udd00", name: "Capture",   cmd: ["sh", "-c", "sleep 0.25; f=$HOME/Pictures/$(date +%s).png; grim \"$f\"; wl-copy < \"$f\"; qs ipc call screenshot notify \"$f\""] },
        { icon: "\uf125", name: "Area",      cmd: ["sh", "-c", "sleep 0.15; f=$HOME/Pictures/$(date +%s).png; grim -g \"$(slurp)\" \"$f\"; wl-copy < \"$f\"; qs ipc call screenshot notify \"$f\""] },
        { icon: "\uf03e", name: "Wallpaper", cmd: ["sh", "-c", "qs -n -p ~/.config/quickshell/hyprquickpaper"] },
        { icon: "\uf0f3", name: "Notifs",    cmd: ["qs", "ipc", "call", "notifications", "toggle"] },
        { icon: "\uf0ae", name: "To-do",     cmd: ["qs", "ipc", "call", "todo", "toggle"] },
        { icon: "\udb80\udd68", name: "Opacity",   cmd: ["sh", "-c", "$HOME/.config/hypr/scripts/opacity.sh"] }
    ]

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wheel"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? menuRoot : null }

    function run(i) {
        if (i < 0 || i >= root.items.length) return
        var a = root.items[i]
        root.closeMenu()
        Quickshell.execDetached({ command: a.cmd })
    }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.screen = scr
        }
        root.selected = -1
        root.showing = true
        Qt.callLater(function () {
            if (root.showing) menuRoot.forceActiveFocus()
        })
    }

    function closeMenu() { root.showing = false }
    function toggleMenu() { root.showing ? root.closeMenu() : root.openMenu() }

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
            }
            event.accepted = true
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: function (mouse) { root.pointAt(mouse.x, mouse.y) }
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
            scale: root.showing ? 1 : 0.92
            opacity: root.showing ? 1 : 0
            visible: opacity > 0

            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

            Rectangle {
                width: 2 * (root.deadZone + 14)
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: "transparent"
                border.width: 1
                border.color: root.selected >= 0 ? Theme.accent : Theme.alpha(Theme.text, 0.5)
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: root.selected >= 0 ? root.items[root.selected].name : ""
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.text
                }
            }

            Repeater {
                model: root.items

                delegate: Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool focused: index === root.selected
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
                        text: seg.modelData.icon
                        font.family: root.iconFont
                        font.pixelSize: 20
                        color: seg.focused ? Theme.text : Theme.textDim
                    }
                }
            }
        }
    }
}