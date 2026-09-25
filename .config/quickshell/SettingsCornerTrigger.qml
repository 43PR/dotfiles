import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root
    property int triggerHeight: 10
    property color triggerColor: '#0037ff00'

    // Each trigger occupies a fixed % range of the screen width.
    // Ranges are non-overlapping by construction — adjust freely,
    // just keep each "From" >= previous "To".
    property real hyprlockFrom: 0.0
    property real hyprlockTo: 0.01

    property real settingsFrom: 0.25
    property real settingsTo: 0.40

    property real rofiFrom: 0.45
    property real rofiTo: 0.55
    
    property real wallpaperFrom: 0.60
    property real wallpaperTo: 0.75

    property real wlogoutFrom: 0.99
    property real wlogoutTo: 1.0

    PanelWindow {
        id: hyprlockTrigger
        anchors { top: true; left: true }
        implicitHeight: root.triggerHeight
        implicitWidth: screen ? Math.round(screen.width * (root.hyprlockTo - root.hyprlockFrom)) : 0
        margins {
            left: screen ? Math.round(screen.width * root.hyprlockFrom) : 0
            top: 0
        }
        color: root.triggerColor
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: Quickshell.execDetached([
                "hyprlock"
            ])
        }
    }

    PanelWindow {
        id: settingsTrigger
        anchors { top: true; left: true }
        implicitHeight: root.triggerHeight
        implicitWidth: screen ? Math.round(screen.width * (root.settingsTo - root.settingsFrom)) : 0
        margins {
            left: screen ? Math.round(screen.width * root.settingsFrom) : 0
            top: 0
        }
        color: root.triggerColor
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: Quickshell.execDetached([
                "qs", "ipc", "call", "settings", "toggle"
            ])
        }
    }

    PanelWindow {
        id: rofiTrigger
        anchors { top: true; left: true }
        implicitHeight: root.triggerHeight
        implicitWidth: screen ? Math.round(screen.width * (root.rofiTo - root.rofiFrom)) : 0
        margins {
            left: screen ? Math.round(screen.width * root.rofiFrom) : 0
            top: 0
        }
        color: root.triggerColor
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: Quickshell.execDetached([
                "rofi", "-show", "drun"
            ])
        }
    }

    PanelWindow {
        id: wallpaperTrigger
        anchors { top: true; left: true }
        implicitHeight: root.triggerHeight
        implicitWidth: screen ? Math.round(screen.width * (root.wallpaperTo - root.wallpaperFrom)) : 0
        margins {
            left: screen ? Math.round(screen.width * root.wallpaperFrom) : 0
            top: 0
        }
        color: root.triggerColor
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: Quickshell.execDetached([
                "sh", "-c", "qs -n -p ~/.config/quickshell/hyprquickpaper"
            ])
        }
    }

    PanelWindow {
        id: wlogoutTrigger
        anchors { top: true; left: true }
        implicitHeight: root.triggerHeight
        implicitWidth: screen ? Math.round(screen.width * (root.wlogoutTo - root.wlogoutFrom)) : 0
        margins {
            left: screen ? Math.round(screen.width * root.wlogoutFrom) : 0
            top: 0
        }
        color: root.triggerColor
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: Quickshell.execDetached([
                ".config/hypr/scripts/wlogout.sh"
            ])
        }
    }
}