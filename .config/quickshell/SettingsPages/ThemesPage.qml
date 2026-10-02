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
    property real sectionSpacing: 6

    function editConfig(path) {
        Quickshell.execDetached([
            "xed",
            path.replace(/^~/, Quickshell.env("HOME"))
        ])
    }

    function runTheme(themeCommand) {
        console.log("Running theme:", themeCommand)

        Quickshell.execDetached([
            "/bin/sh",
            "-c",
            "python3 \"$HOME/.config/43pr/bin/theme.py\" " + themeCommand
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

    component ThemeButton: Rectangle {
        required property string label
        required property string command

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
                text: "\uf0c8"
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: command.toUpperCase()
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

            onClicked: page.runTheme(command)
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
                text: "THEMES"
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

            Column {
                width: parent.width
                spacing: page.sectionSpacing

                ThemeButton {
                    label: "DEFAULT THEME"
                    command: "default"
                }
                ThemeButton {
                    label: "NORD"
                    command: "preset nord"
                }
                ThemeButton {
                    label: "TOKYO NIGHT"
                    command: "preset tokyo-night"
                }
                ThemeButton {
                    label: "CATPPUCCIN MOCHA"
                    command: "preset catppuccin-mocha"
                }
                ThemeButton {
                    label: "EVERFOREST DARK"
                    command: "preset everforest-dark"
                }
            }

            Text {
                text: "SETTINGS MENU"
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
                    label: "OPACITY"
                    path: "~/.config/43pr/templates/quickshell-theme.json"
                }

                ConfigButton {
                    label: "THEME"
                    path: "~/.config/quickshell/Theme.qml"
                }
            }
        }
    }
}