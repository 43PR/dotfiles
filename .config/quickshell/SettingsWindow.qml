
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "SettingsPages"

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only actually grab input/paint when open - mirrors the OSD's mask trick
    // so the window is a no-op on the compositor while closed.
    mask: Region {
        item: root.showing ? backdrop : null
    }

    property bool showing: false

    function show()   { showing = true }
    function hide()   { showing = false }
    function toggle() { showing = !showing }

    // Bind a Hyprland key to this, e.g. in hyprland.conf:
    //   bind = SUPER, S, exec, qs ipc call settings toggle
    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    // -------------------------
    // PipeWire (for volume)
    // -------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property var sink: Pipewire.defaultAudioSink
    property real pwVolume: (sink && sink.audio) ? sink.audio.volume : 0
    property bool pwMuted: (sink && sink.audio) ? sink.audio.muted : false

    // -------------------------
    // Backdrop (click-outside-to-close)
    // -------------------------
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"

        focus: root.showing
        Keys.onEscapePressed: root.hide()

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    // -------------------------
    // Nav model
    // -------------------------
    property var navItems: [
        { name: "System",     icon: "󰒓", page: "SystemPage" },
        { name: "Sound",      icon: "\uf028", page: "SoundPage" },
        { name: "Monitors",   icon: "\uf108", page: "MonitorsPage" },
        { name: "Network",    icon: "\uf1eb", page: "NetworkPage" },
        { name: "Bluetooth",  icon: "󰂯", page: "BluetoothPage" }
    ]

    property int selectedIndex: 0

    // -------------------------
    // Card
    // -------------------------
    PerspectivePanel {
        id: card
        anchors.centerIn: parent
        width: Math.min(980, root.width - 80)
        height: Math.min(640, root.height - 80)
        open: root.showing

        MouseArea {
            // swallow clicks so they don't fall through to the backdrop
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 6
            border.color: Theme.accent
            border.width: 1

            // faint corner glow accents, cyberpunk HUD style
            Rectangle {
                width: 40; height: 2; color: Theme.accent2
                anchors { top: parent.top; left: parent.left; margins: 14 }
            }

            Rectangle {
                width: 2; height: 40; color: Theme.accent2
                anchors { top: parent.top; left: parent.left; margins: 14 }
            }

            Rectangle {
                width: 40; height: 2; color: Theme.accent2
                anchors { bottom: parent.bottom; right: parent.right; margins: 14 }
            }

            Rectangle {
                width: 2; height: 40; color: Theme.accent2
                anchors { bottom: parent.bottom; right: parent.right; margins: 14 }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 28

                // ---------------- Sidebar ----------------
                Column {
                    id: sidebar
                    width: 220
                    height: parent.height
                    spacing: 22

                    Text {
                        text: "SETTINGS"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        font.bold: true
                        font.letterSpacing: 4
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    // ---------------- Nav buttons ----------------
                    Column {
                        width: parent.width
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
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    color: Theme.accent2
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    spacing: 12

                                    Text {
                                        text: modelData.icon
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                        color: root.selectedIndex === index
                                            ? Theme.accent
                                            : Theme.textDim
                                    }

                                    Text {
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

                Rectangle {
                    width: 1
                    height: parent.height
                    color: Theme.border
                }

                // ---------------- Page content ----------------
                Item {
                    width: parent.width - sidebar.width - 29
                    height: parent.height
                    clip: true

                    Loader {
                        id: pageLoader
                        anchors.fill: parent
                        source: "SettingsPages/" + root.navItems[root.selectedIndex].page + ".qml"

                        opacity: 0
                        Component.onCompleted: opacity = 1
                        onSourceChanged: fadeIn.restart()

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animMed
                            }
                        }

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
                                duration: Theme.animMed
                            }
                        }
                    }
                }
            }
        }
    }
}


