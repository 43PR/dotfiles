import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import "../"

Item {
    id: page
    property real marginLeft: 0
    property real marginRight: 10
    property real marginTop: 0
    property real marginBottom: 0
    property real sectionSpacing: 6

// Order: bg, surface, fg, muted, accent, accent2
readonly property var palettes: ({
    // Fixed preview for the DEFAULT button. Edit to match your default theme.
    "default":          ["#000000", "#0d0d0d", "#ffffff", "#8b93a7", "#ffffff", '#e1e1e1'],
    "catppuccin-mocha": ["#1e1e2e", "#313244", "#cdd6f4", "#6c7086", "#cba6f7", "#89b4fa"],
    "one-dark":         ["#282c34", "#353b45", "#abb2bf", "#5c6370", "#61afef", "#c678dd"],
    "tokyo-night":      ["#1a1b26", "#24283b", "#c0caf5", "#565f89", "#7aa2f7", "#bb9af7"],
    "nord":             ["#2e3440", "#3b4252", "#d8dee9", "#616e88", "#88c0d0", "#81a1c1"],
    "arctic":           ["#292E35", "#323943", "#E0E8F0", "#879FB4", "#7198B8", "#8CAFC8"],
    "everforest-dark":  ["#2d353b", "#343f44", "#d3c6aa", "#859289", "#a7c080", "#7fbbb3"],
    "kanagawa":         ["#1f1f28", "#2a2a37", "#dcd7ba", "#727169", "#7e9cd8", "#957fb8"],
    "graphite":         ["#1c1c1e", "#2c2c2e", "#e5e5e7", "#6e6e73", "#8e8e93", "#aeaeb2"],
    "slate":            ["#2B3438", "#354145", "#E0E7E9", "#879CA1", "#829599", "#7FA8AD"],
    "matrix":           ["#000d00", "#001a00", "#00ff41", "#008f11", "#00ff41", "#39ff14"],
    "dracula":          ["#282a36", "#44475a", "#f8f8f2", "#6272a4", "#bd93f9", "#ff79c6"],
    "rose-pine":        ["#191724", "#1f1d2e", "#e0def4", "#6e6a86", "#ebbcba", "#c4a7e7"],
    "light-gray":       ["#e5e7eb", "#d1d5db", "#1f2937", "#6b7280", "#374151", '#9bb1df'],
    "metal":            ['#23272c', "#3a4046", "#cfd4d9", "#7b848c", "#9fb0bf", "#c0c8d0"],
    "silver":           ['#C8CCD2', "#c4c8cc", "#23272b", "#6b7279", "#4b5563", "#7b8794"],
    "beige":            ["#f1e9d8", "#e4d9c1", "#3b3228", "#8a7d6a", "#a0522d", "#b08968"],
    "moss":             ["#1c2418", "#2a3524", "#d4e0c8", "#7a8c6a", "#8fbf6a", "#c4d86a"],
    "gold":             ["#1a1608", "#2a2410", "#f5e6b8", "#8c7a3c", "#ffc832", "#e6a817"],
    "red":              ["#1a0b0b", "#2a1212", "#f5d6d6", "#8c4a4a", "#ff3b3b", "#ff7a59"],
    "cyan":             ["#0e1a1f", "#16282f", "#d6eef2", "#6a8f99", "#22d3ee", "#67e8f9"],
    "gruvbox-dark":     ["#282828", "#3c3836", "#ebdbb2", "#928374", "#fabd2f", "#fe8019"],
    "solarized-dark":   ["#002b36", "#073642", "#93a1a1", "#586e75", "#268bd2", "#2aa198"],
    "monokai":          ["#272822", "#3e3d32", "#f8f8f2", "#75715e", "#a6e22e", "#f92672"],
    "catppuccin-latte": ["#e6e9ef", "#ccd0da", "#4c4f69", "#8c8fa1", "#8839ef", "#1e66f5"],
    "solarized-light":  ["#fdf6e3", "#eee8d5", "#073642", "#657b83", "#268bd2", "#2aa198"],
    "gruvbox-light":    ["#fbf1c7", "#ebdbb2", "#3c3836", "#7c6f64", "#b57614", "#af3a03"]
})

function pal(id) {
    var c = palettes[id] || palettes["default"]
    return { bg: c[0], surface: c[1], fg: c[2], muted: c[3],
             accent: c[4], accent2: c[5] }
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
property string activeId: "default"   // last applied preset

FileView {
    id: stateView
    path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
          + "/43pr/state.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
        page.colorGen = stateAdapter.colorgen
        page.darkMode = stateAdapter.mode_appearance !== "light"
        // Optional: if theme.py writes a "preset" key, pick it up.
        if (stateAdapter.preset !== "")
            page.activeId = stateAdapter.preset
    }
    adapter: JsonAdapter {
        id: stateAdapter
        property bool colorgen: true
        property string mode_appearance: "dark"
        property string preset: ""
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
    color: hover.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
    border.width: 1
    border.color: (checked || hover.containsMouse) ? Theme.accent : Theme.border

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        text: label + ": " + valueText
        color: checked ? Theme.accent : Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSizeBody
        font.bold: true
        font.letterSpacing: 1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.toggled()
    }
}

// Theme button: mini "window" painted in the preset's own colors,
// palette swatches underneath, label, and an active marker.
component ThemeButton: Rectangle {
    id: btn
    required property string label
    required property string command
    property string pid: command.indexOf("preset ") === 0 ? command.substring(7) : "default"

    readonly property var p: page.pal(pid)
    readonly property bool active: page.activeId === pid
    readonly property bool hovered: mouse.containsMouse

    width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
    height: 78
    radius: Theme.radius
    color: hovered ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
    border.width: active ? 2 : 1
    border.color: (active || hovered) ? Theme.accent : Theme.border

    scale: hovered ? 1.02 : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 5

        // mini window
        Rectangle {
            width: parent.width
            height: 34
            radius: 3
            color: btn.p.bg
            border.width: 1
            border.color: Theme.alpha(btn.p.muted, 0.5)

            // title bar
            Rectangle {
                x: 0; y: 0
                width: parent.width
                height: 8
                radius: 3
                color: btn.p.surface
            }
            Row {
                x: 4; y: 2
                spacing: 2
                Repeater {
                    model: 3
                    Rectangle { width: 4; height: 4; radius: 2; color: index === 0 ? btn.p.accent : btn.p.muted }
                }
            }
            // fake text lines
            Rectangle { x: 6; y: 13; width: parent.width * 0.55; height: 3; radius: 1; color: btn.p.fg }
            Rectangle { x: 6; y: 19; width: parent.width * 0.35; height: 3; radius: 1; color: btn.p.muted }
            // fake accent button
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                width: parent.width * 0.28
                height: 8
                radius: 2
                color: btn.p.accent
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.top: parent.top
                anchors.topMargin: 13
                width: 8; height: 8; radius: 4
                color: btn.p.accent2
            }
        }

        // swatch strip
        Row {
            width: parent.width
            height: 6
            spacing: 2
            Repeater {
                model: [btn.p.bg, btn.p.surface, btn.p.muted, btn.p.fg, btn.p.accent2, btn.p.accent]
                Rectangle {
                    width: (parent.width - 5 * parent.spacing) / 6
                    height: 6
                    radius: 1
                    color: modelData
                    border.width: 1
                    border.color: Theme.alpha(Theme.textDim, 0.25)
                }
            }
        }

        // label + active dot
        Item {
            width: parent.width
            height: 12

            Text {
                anchors.left: parent.left
                anchors.right: dot.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: (btn.active || btn.hovered) ? Theme.accent : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeSmall
                font.bold: true
                font.letterSpacing: 1
                elide: Text.ElideRight
            }
            Rectangle {
                id: dot
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: Theme.accent
                visible: btn.active
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            page.activeId = btn.pid      // optimistic
            page.runTheme(btn.command)
        }
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
            font.pixelSize: Theme.textSizeTitle
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

                ThemeButton { label: "MONOCHROME"; command: "default" }
                ThemeButton { label: "SLATE"; command: "preset slate" }
                ThemeButton { label: "GRAPHITE"; command: "preset graphite" }
                ThemeButton { label: "NORD"; command: "preset nord" }
                ThemeButton { label: "ARCTIC"; command: "preset arctic" }
                ThemeButton { label: "METAL"; command: "preset metal" }
                ThemeButton { label: "CATPPUCCIN MOCHA"; command: "preset catppuccin-mocha" }
                ThemeButton { label: "TOKYO NIGHT"; command: "preset tokyo-night" }
                ThemeButton { label: "KANAGAWA"; command: "preset kanagawa" }
                ThemeButton { label: "ONE DARK"; command: "preset one-dark" }
                ThemeButton { label: "DRACULA"; command: "preset dracula" }
                ThemeButton { label: "ROSE PINE"; command: "preset rose-pine" }
                ThemeButton { label: "EVERFOREST DARK"; command: "preset everforest-dark" }
                ThemeButton { label: "MOSS"; command: "preset moss" }
                ThemeButton { label: "GOLD"; command: "preset gold" }
                ThemeButton { label: "CYAN"; command: "preset cyan" }
                ThemeButton { label: "MATRIX"; command: "preset matrix" }
                ThemeButton { label: "RED"; command: "preset red" }
                ThemeButton { label: "GRUVBOX DARK"; command: "preset gruvbox-dark" }
                ThemeButton { label: "SOLARIZED DARK"; command: "preset solarized-dark" }
                ThemeButton { label: "MONOKAI"; command: "preset monokai" }
                ThemeButton { label: "SILVER"; command: "preset silver" }
                ThemeButton { label: "LIGHT GRAY"; command: "preset light-gray" }
                ThemeButton { label: "BEIGE"; command: "preset beige" }
                ThemeButton { label: "CATPPUCCIN LATTE"; command: "preset catppuccin-latte" }
                ThemeButton { label: "SOLARIZED LIGHT"; command: "preset solarized-light" }
                ThemeButton { label: "GRUVBOX LIGHT"; command: "preset gruvbox-light" }
            }
        }
    }
}
}