import QtQuick
import QtQuick.Controls
import Quickshell
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property real sliderMarginRight: 10
    property real sectionSpacing: 6

    function editConfig(path) {
        Quickshell.execDetached([
            "xed",
            path.replace(/^~/, Quickshell.env("HOME"))
        ])
    }

    component ConfigButton: Rectangle {
        required property string label
        required property string path

        width: parent.width
        height: 42
        radius: Theme.radius
        color: "#00000000"
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 2
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "\uf120"
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "EDIT " + path.split("/").pop().toUpperCase()
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: {
                parent.color = Theme.alpha(Theme.accent, 0.08)
                parent.border.color = Theme.accent
            }

            onExited: {
                parent.color = "#00000000"
                parent.border.color = Theme.border
            }

            onClicked: page.editConfig(path)
        }
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            background: Rectangle {
                color: Theme.alpha(Theme.border, 0.3)
                radius: width / 2
            }

            contentItem: Rectangle {
                color: Theme.accent
                radius: width / 2
            }
        }

        Column {
            id: content
            width: flick.width
            spacing: 14

            Text {
                text: "CONFIGS"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Text {
                text: "HYPRLAND"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                width: parent.width
                spacing: page.sectionSpacing

                ConfigButton {
                    label: "PROGRAMS - AUTOSTART - INPUT"
                    path: "~/.config/hypr/hyprland.lua"
                }

                ConfigButton {
                    label: "MONITORS - WORKSPACES"
                    path: "~/.config/hypr/monitors.lua"
                }

                ConfigButton {
                    label: "LOOK AND FEEL"
                    path: "~/.config/hypr/look.lua"
                }

                ConfigButton {
                    label: "KEYBINDS"
                    path: "~/.config/hypr/keybinds.lua"
                }

                ConfigButton {
                    label: "RULES"
                    path: "~/.config/hypr/rules.lua"
                }

                ConfigButton {
                    label: "LOCK SCREEN"
                    path: "~/.config/hypr/hyprlock.conf"
                }

                ConfigButton {
                    label: "APPS LAUNCHER"
                    path: "~/.config/rofi/config.rasi"
                }

                ConfigButton {
                    label: "SETTINGS THEME"
                    path: "~/.config/quickshell/Theme.qml"
                }
            }

            Text {
                text: "WAYBAR"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                width: parent.width
                spacing: page.sectionSpacing

                ConfigButton {
                    label: "CONFIG"
                    path: "~/.config/waybar/config.jsonc"
                }

                ConfigButton {
                    label: "STYLE"
                    path: "~/.config/waybar/style.css"
                }
            }

            Text {
                text: "WLOGOUT"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                width: parent.width
                spacing: page.sectionSpacing

                ConfigButton {
                    label: "STYLE"
                    path: "~/.config/wlogout/style.css"
                }

                ConfigButton {
                    label: "LAYOUT"
                    path: "~/.config/wlogout/layout"
                }
            }
        }
    }
}
