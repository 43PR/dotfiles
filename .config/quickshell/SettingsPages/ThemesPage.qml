import QtQuick
import QtQuick.Controls
import Quickshell.Io
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

        // Re-read state.json shortly after, so the buttons reflect the new
        // colorgen / appearance (presets can change the appearance too).
        reloadTimer.restart()
    }

    property bool colorGen: true
    property bool darkMode: true

    FileView {
        id: stateView
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/43pr/state.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            page.colorGen = stateAdapter.colorgen
            page.darkMode = stateAdapter.mode_appearance !== "light"
        }
        adapter: JsonAdapter {
            id: stateAdapter
            property bool colorgen: true
            property string mode_appearance: "dark"
        }
    }

    Timer {
        id: reloadTimer
        interval: 700
        onTriggered: stateView.reload()
    }

    function setColorGen(on) {
        page.colorGen = on
        runTheme("colorgen " + (on ? "on" : "off"))
    }

    function toggleMode() {
        page.darkMode = !page.darkMode      // optimistic; state.json reload corrects it
        runTheme("toggle")
    }

    component ToggleButton: Rectangle {
        required property string label
        required property bool checked
        property string valueText: checked ? "ON" : "OFF"
        signal toggled()

        width: parent.width
        height: 42
        radius: Theme.radius
        color: "#00000000"
        border.width: 1
        border.color: checked ? Theme.accent : Theme.border

        Text {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            text: label + ": " + valueText
            color: checked ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
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
                parent.border.color = parent.checked ? Theme.accent : Theme.border
            }

            onClicked: parent.toggled()
        }
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

        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
        height: 42
        radius: Theme.radius
        color: "#00000000"
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            text: label
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
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

                Row {
                    width: parent.width
                    spacing: page.sectionSpacing

                    ToggleButton {
                        width: (parent.width - parent.spacing) / 2
                        label: "COLOR GENERATION"
                        checked: page.colorGen
                        onToggled: page.setColorGen(!page.colorGen)
                    }

                    ToggleButton {
                        width: (parent.width - parent.spacing) / 2
                        label: "MODE"
                        checked: true
                        valueText: page.darkMode ? "DARK" : "LIGHT"
                        onToggled: page.toggleMode()
                    }
                }

                Grid {
                    width: parent.width
                    columns: 3
                    spacing: page.sectionSpacing

                    ThemeButton {
                        label: "DEFAULT"
                        command: "default"
                    }
                    ThemeButton {
                        label: "WHITE"
                        command: "preset white"
                    }
                    ThemeButton {
                        label: "METAL"
                        command: "preset metal"
                    }
                    ThemeButton {
                        label: "LIGHT GRAY"
                        command: "preset light-gray"
                    }
                    ThemeButton {
                        label: "BEIGE"
                        command: "preset beige"
                    }
                    ThemeButton {
                        label: "SILVER"
                        command: "preset silver"
                    }
                    ThemeButton {
                        label: "GOLD"
                        command: "preset gold"
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
                    ThemeButton {
                        label: "DRACULA"
                        command: "preset dracula"
                    }
                    ThemeButton {
                        label: "ONE DARK"
                        command: "preset one-dark"
                    }
                    ThemeButton {
                        label: "KANAGAWA"
                        command: "preset kanagawa"
                    }
                    ThemeButton {
                        label: "ROSE PINE"
                        command: "preset rose-pine"
                    }
                    ThemeButton {
                        label: "RED"
                        command: "preset red"
                    }
                    ThemeButton {
                        label: "MATRIX"
                        command: "preset matrix"
                    }
                }
            }

            Column {
                width: parent.width
                spacing: page.sectionSpacing

                ConfigButton {
                    label: "THEME"
                    path: "~/.config/quickshell/Theme.qml"
                }
            }
        }
    }
}