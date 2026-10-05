import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0

    property string currentProfile: "balanced"
    property var availableProfiles: ["power-saver", "balanced", "performance"]

    property bool hasBattery: false
    property int batteryPercent: 0
    property string batteryStatus: ""

    readonly property var profiles: [
        { id: "power-saver", label: "POWER SAVER", icon: "\uf06c", desc: "Quiet, longer battery" },
        { id: "balanced",    label: "BALANCED",    icon: "\uf24e", desc: "Default behaviour" },
        { id: "performance", label: "PERFORMANCE", icon: "\uf0e7", desc: "Maximum speed" }
    ]

    function profileLabel(id) {
        for (let i = 0; i < profiles.length; i++)
            if (profiles[i].id === id) return profiles[i].label
        return id.toUpperCase()
    }
    Process {
        id: profileGet
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim()
                if (v.length > 0) page.currentProfile = v
            }
        }
    }
    Process {
        id: profileList
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                const re = /^\s*\*?\s*([a-z-]+):\s*$/gm
                let m
                while ((m = re.exec(text)) !== null) found.push(m[1])
                if (found.length > 0) page.availableProfiles = found
            }
        }
    }
    Process {
        id: profileSet
        onExited: exitCode => refreshTimer.restart()
    }

    function setProfile(id) {
        if (profileSet.running) return
        page.currentProfile = id
        profileSet.command = ["powerprofilesctl", "set", id]
        profileSet.running = true
    }
    Process {
        id: batteryGet
        command: [
            "sh", "-c",
            "cat /sys/class/power_supply/BAT*/capacity /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 2"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length >= 2 && lines[0].length > 0) {
                    const pct = parseInt(lines[0])
                    if (!isNaN(pct)) {
                        page.batteryPercent = pct
                        page.batteryStatus = lines[1].trim()
                        page.hasBattery = true
                        return
                    }
                }
                page.hasBattery = false
            }
        }
    }

    function refresh() {
        profileGet.running = true
        batteryGet.running = true
    }

    Timer { id: refreshTimer; interval: 250; onTriggered: page.refresh() }

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: if (!batteryGet.running) batteryGet.running = true
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft; anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop; anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            background: Rectangle {
                color: "transparent"
                radius: width / 2
            }
            contentItem: Rectangle {
                color: "transparent"
                radius: width / 2
            }
        }

        Column {
            id: content
            width: flick.width
            spacing: 14

            Text {
                text: "POWER"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Row {
                width: parent.width; height: 38; spacing: 10

                Rectangle {
                    width: 28; height: 28; radius: Theme.radius; anchors.verticalCenter: parent.verticalCenter
                    color: Theme.alpha(Theme.accent2, 0.10); border.width: 1; border.color: Theme.border
                    Text {
                        anchors.centerIn: parent; text: "\uf0e7"; color: Theme.accent2
                        font.family: Theme.iconFont; font.pixelSize: 12
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PROFILE"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 15
                }
            }
            Column {
                width: parent.width; spacing: 10
                topPadding: 6
                bottomPadding: 6

                Text {
                    text: "POWER PROFILE"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 15; font.bold: true; font.letterSpacing: 2
                }

                Row {
                    width: parent.width; spacing: 10
                    topPadding: 6
                    bottomPadding: 6

                    Repeater {
                        model: page.profiles

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property bool selected: page.currentProfile === modelData.id
                            readonly property bool available: page.availableProfiles.indexOf(modelData.id) !== -1
                            property bool hovered: false

                            width: (parent.width - parent.spacing * 2) / 3; height: 100; radius: Theme.radius
                            opacity: available ? 1.0 : 0.35
                            color: selected ? Theme.alpha(Theme.accent, 0.10)
                                 : hovered ? Theme.alpha(Theme.accent, 0.08)
                                 : "#00000000"
                            border.width: 1
                            border.color: (selected || hovered) ? Theme.accent : Theme.border

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Rectangle {
                                    width: 28; height: 28; radius: Theme.radius
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: card.selected ? Theme.alpha(Theme.accent, 0.10) : Theme.alpha("#A0A0A0", 0.15)
                                    border.width: 1
                                    border.color: card.selected ? Theme.accent : Theme.border
                                    Text {
                                        anchors.centerIn: parent; text: card.modelData.icon
                                        color: card.selected ? Theme.accent : "#A0A0A0"
                                        font.family: Theme.iconFont; font.pixelSize: 12
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.modelData.label; color: Theme.text
                                    font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.available ? card.modelData.desc : "Unavailable"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily; font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                enabled: card.available
                                cursorShape: Qt.PointingHandCursor
                                onEntered: card.hovered = true
                                onExited: card.hovered = false
                                onClicked: page.setProfile(card.modelData.id)
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: page.hasBattery
                width: parent.width; height: 100; radius: Theme.radius
                color: "#00000000"; border.width: 1; border.color: Theme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Row {
                        spacing: 10

                        Text {
                            text: "BATTERY"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true
                        }

                        Text {
                            text: page.batteryStatus.toUpperCase()
                            color: Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: 12
                        }

                        Text {
                            visible: page.batteryStatus === "Charging"
                            text: "CHARGING"; color: Theme.accent2
                            font.family: Theme.fontFamily; font.pixelSize: 10
                        }
                    }

                    Item {
                        width: parent.width
                        height: levelLabel.implicitHeight
                        Text {
                            id: levelLabel
                            anchors.left: parent.left
                            text: "LEVEL"
                            color: Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                        Text {
                            anchors.right: parent.right
                            text: page.batteryPercent + "%"
                            color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 6; radius: 3
                        color: Theme.alpha("#A0A0A0", 0.15)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, page.batteryPercent / 100))
                            height: parent.height; radius: 3
                            color: page.batteryPercent <= 15 ? "#E05555" : Theme.accent2
                            Behavior on width { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        profileList.running = true
        profileGet.running = true
        batteryGet.running = true
    }
}