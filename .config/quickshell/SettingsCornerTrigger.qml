import Quickshell
import Quickshell.Wayland
import QtQuick

Item {

    property int settingsWidth: 800
    property int settingsHeight: 10
    property int settingsLeft: 150
    property int settingsTop: 0
    property int wallpaperWidth: 800
    property int wallpaperHeight: 10
    property int wallpaperRight: 150
    property int wallpaperTop: 0

    PanelWindow {
        id: settingsTrigger

        anchors {
            top: true
            left: true
        }

        implicitWidth: settingsWidth
        implicitHeight: settingsHeight

        margins {
            left: settingsLeft
            top: settingsTop
        }

        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: {
                Quickshell.execDetached([
                    "qs",
                    "ipc",
                    "call",
                    "settings",
                    "toggle"
                ])
            }
        }
    }

    PanelWindow {
        id: wallpaperTrigger

        anchors {
            top: true
            right: true
        }

        implicitWidth: wallpaperWidth
        implicitHeight: wallpaperHeight
        margins {
            right: wallpaperRight
            top: wallpaperTop
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: {
                Quickshell.execDetached([
                    "sh",
                    "-c",
                    "qs -n -p ~/.config/quickshell/hyprquickpaper"
                ])
            }
        }
    }
}
