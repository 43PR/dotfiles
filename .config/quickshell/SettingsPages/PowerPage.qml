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

    property string animationMode: "auto"
    property string effectsLevel: "moderate"
    property int lowBatteryPercent: 20
    property string lastPerfLua: ""

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"

    readonly property bool lowPower: currentProfile === "power-saver"
        || (hasBattery && batteryStatus === "Discharging" && batteryPercent <= lowBatteryPercent)
    readonly property bool animationsEnabled: animationMode === "on" || (animationMode === "auto" && !lowPower)

    readonly property var animationOptions: [
        { id: "auto",   label: "AUTO" },
        { id: "on",     label: "ON" },
        { id: "off",    label: "OFF" }
    ]

    readonly property var effectsOptions: [
        { id: "off",      label: "OFF" },
        { id: "moderate", label: "MODERATE" },
        { id: "high",     label: "HIGH" }
    ]

    readonly property var profiles: [
        { id: "power-saver", label: "POWER SAVER" },
        { id: "balanced",    label: "BALANCED" },
        { id: "performance", label: "PERFORMANCE" }
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

    Process {
        id: perfDirProcess
        command: ["mkdir", "-p", page.stateDir]
    }

    FileView {
        id: perfFile
        path: page.stateDir + "/performance.json"
        blockLoading: true
    }

    FileView {
        id: perfLua
        path: page.stateDir + "/performance.lua"
    }

    Process {
        id: pPerf
        stdout: StdioCollector {
            onStreamFinished: if (text.trim().length > 0 && text.trim() !== "ok") console.log("[power] hyprctl:", text.trim())
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) console.warn("[power] hyprctl error:", text.trim())
        }
    }

    function luaString(value) { return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") }

    function luaValue(value) {
        if (typeof value === "boolean") return value ? "true" : "false"
        if (typeof value === "number") return String(value)
        if (typeof value === "object" && value !== null) return luaTable(value)
        return "\"" + luaString(value) + "\""
    }

    function luaTable(obj) {
        const parts = []
        const keys = Object.keys(obj)
        for (let i = 0; i < keys.length; i++)
            parts.push("[\"" + luaString(keys[i]) + "\"]=" + luaValue(obj[keys[i]]))
        return "{" + parts.join(",") + "}"
    }

    function effectsPreset(level) {
        if (level === "off")
            return { blur: { enabled: false }, shadow: { enabled: false } }
        if (level === "high")
            return {
                blur: { enabled: true, size: 10, passes: 3 },
                shadow: { enabled: true, range: 24, render_power: 2 }
            }
        return {
            blur: { enabled: true, size: 6, passes: 2 },
            shadow: { enabled: true, range: 8, render_power: 3 }
        }
    }

    function performanceLua() {
        const fx = effectsPreset(effectsLevel)
        return "hl.config(" + luaTable({
            animations: { enabled: animationsEnabled },
            decoration: { blur: fx.blur, shadow: fx.shadow }
        }) + ")"
    }

    function applyPerformance() {
        if (pPerf.running) { perfApplyTimer.restart(); return }
        const lua = performanceLua()
        if (lua === lastPerfLua) return
        lastPerfLua = lua
        pPerf.command = ["hyprctl", "eval", lua]
        pPerf.running = true
        perfSaveTimer.restart()
    }

    function loadPerformance() {
        try {
            const saved = JSON.parse(perfFile.text())
            if (["auto", "on", "off"].indexOf(saved.animations) !== -1) animationMode = saved.animations
            if (["off", "moderate", "high"].indexOf(saved.effects) !== -1) effectsLevel = saved.effects
        } catch (error) {}
    }

    function setAnimationMode(mode) {
        animationMode = mode
        perfSaveTimer.restart()
        perfApplyTimer.restart()
    }

    function setEffectsLevel(level) {
        effectsLevel = level
        perfSaveTimer.restart()
        perfApplyTimer.restart()
    }

    Timer { id: perfApplyTimer; interval: 250; onTriggered: page.applyPerformance() }

    Timer {
        id: perfSaveTimer
        interval: 300
        onTriggered: {
            try {
                perfFile.setText(JSON.stringify({ animations: page.animationMode, effects: page.effectsLevel }, null, 2))
                if (page.lastPerfLua.length > 0) perfLua.setText(page.lastPerfLua + "\n")
            } catch (error) {}
        }
    }

    onAnimationsEnabledChanged: perfApplyTimer.restart()

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

            Column {
                width: parent.width; spacing: 10
                topPadding: 6
                bottomPadding: 6

                Text {
                    text: "PERFORMANCE"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 15; font.bold: true; font.letterSpacing: 2
                }

                Rectangle {
                    width: parent.width
                    height: perfColumn.implicitHeight + 28
                    radius: Theme.radius
                    color: "#00000000"; border.width: 1; border.color: Theme.border

                    Column {
                        id: perfColumn
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 16

                        Column {
                            width: parent.width; spacing: 8

                            Row {
                                spacing: 10

                                Text {
                                    text: "ANIMATIONS"; color: Theme.text
                                    font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: page.animationsEnabled ? "ON" : "OFF"
                                    color: page.animationsEnabled ? Theme.accent2 : Theme.textDim
                                    font.family: Theme.fontFamily; font.pixelSize: 10
                                }
                            }

                            Row {
                                width: parent.width; spacing: 8

                                Repeater {
                                    model: page.animationOptions

                                    delegate: Rectangle {
                                        id: animButton
                                        required property var modelData
                                        readonly property bool current: page.animationMode === modelData.id
                                        width: (parent.width - parent.spacing * (page.animationOptions.length - 1)) / page.animationOptions.length
                                        height: 28; radius: Theme.radius
                                        color: current ? Theme.alpha(Theme.accent, 0.10) : (animMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                        border.width: 1
                                        border.color: current || animMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: animButton.modelData.label
                                            color: animButton.current ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: animMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.setAnimationMode(animButton.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width; spacing: 8

                            Text {
                                text: "BLUR & SHADOWS"; color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                            }

                            Row {
                                width: parent.width; spacing: 8

                                Repeater {
                                    model: page.effectsOptions

                                    delegate: Rectangle {
                                        id: fxButton
                                        required property var modelData
                                        readonly property bool current: page.effectsLevel === modelData.id
                                        width: (parent.width - parent.spacing * (page.effectsOptions.length - 1)) / page.effectsOptions.length
                                        height: 28; radius: Theme.radius
                                        color: current ? Theme.alpha(Theme.accent, 0.10) : (fxMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                        border.width: 1
                                        border.color: current || fxMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: fxButton.modelData.label
                                            color: fxButton.current ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: fxMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.setEffectsLevel(fxButton.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width; spacing: 8

                            Row {
                                spacing: 10

                                Text {
                                    text: "POWER PROFILE"; color: Theme.text
                                    font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: page.profileLabel(page.currentProfile)
                                    color: Theme.accent2
                                    font.family: Theme.fontFamily; font.pixelSize: 10
                                }
                            }

                            Row {
                                width: parent.width; spacing: 8

                                Repeater {
                                    model: page.profiles

                                    delegate: Rectangle {
                                        id: profButton
                                        required property var modelData
                                        readonly property bool current: page.currentProfile === modelData.id
                                        readonly property bool available: page.availableProfiles.indexOf(modelData.id) !== -1
                                        width: (parent.width - parent.spacing * (page.profiles.length - 1)) / page.profiles.length
                                        height: 28; radius: Theme.radius
                                        opacity: available ? 1.0 : 0.35
                                        color: current ? Theme.alpha(Theme.accent, 0.10) : (profMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                        border.width: 1
                                        border.color: current || profMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: profButton.modelData.label
                                            color: profButton.current ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: profMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            enabled: profButton.available
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.setProfile(profButton.modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        perfDirProcess.running = true
        loadPerformance()
        profileList.running = true
        profileGet.running = true
        batteryGet.running = true
        perfApplyTimer.restart()
    }
}