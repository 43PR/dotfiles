import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property var monitors: []
    property int rightMargin: 50
    property real brightnessValue: 0.6
    property real nightlightValue: 0.5
    property bool nightlightEnabled: false
    property real sliderMarginRight: 10
    property real labelWidth: 96

    Process {
        id: brightnessGet
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",")
                if (parts.length >= 4) {
                    const pct = parseInt(parts[3])
                    if (!isNaN(pct)) page.brightnessValue = pct / 100
                }
            }
        }
    }

    Process { id: brightnessSet }

    function commitBrightness(value) {
        const pct = Math.round(value * 100) + "%"
        brightnessSet.command = ["brightnessctl", "set", pct]
        brightnessSet.running = true
    }

    Process { id: nightlightProcess }

    function nightlightTemperature(value) { return Math.round(2500 + value * 4000) }

    function startNightlight(value, delay) {
        const temp = nightlightTemperature(value)
        nightlightProcess.command = [
            "sh", "-c",
            "pkill -x gammastep 2>/dev/null; " +
            "sleep " + delay + "; " +
            "nohup gammastep -O " + temp + " >/dev/null 2>&1 &"
        ]
        nightlightProcess.running = true
    }

    function nightlightOn() { nightlightEnabled = true; startNightlight(nightlightValue, "0.05") }

    function nightlightOff() {
        nightlightEnabled = false
        nightlightProcess.command = ["pkill", "-x", "gammastep"]
        nightlightProcess.running = true
    }

    function commitNightlight(value) {
        nightlightValue = value
        nightlightSaveTimer.restart()
        if (nightlightEnabled) startNightlight(value, "0.03")
    }

    FileView {
        id: nightlightFile
        path: Quickshell.dataDir + "/nightlight.json"
        blockLoading: true
    }

    function loadNightlight() {
        try {
            const saved = JSON.parse(nightlightFile.text())
            if (typeof saved.value === "number") nightlightValue = saved.value
        } catch (error) {}
    }

    Timer {
        id: nightlightSaveTimer
        interval: 300
        onTriggered: {
            nightlightFile.setText(JSON.stringify({ value: page.nightlightValue }))
        }
    }

    Process {
        id: nightlightCheck
        command: ["pgrep", "-x", "gammastep"]
        onExited: exitCode => {
            page.nightlightEnabled = exitCode === 0
        }
    }

    function monitorMode(mon) { return mon.width + "x" + mon.height + "@" + mon.refreshRate.toFixed(2) }

    function luaString(value) { return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") }

    function monitorLua(mon, options = {}) {
        const values = ["output = \"" + luaString(mon.name) + "\""]
        if (options.mode !== undefined) values.push("mode = \"" + luaString(options.mode) + "\"")
        if (options.position !== undefined) values.push("position = \"" + luaString(options.position) + "\"")
        if (options.scale !== undefined) values.push("scale = " + options.scale)
        if (options.disabled !== undefined) values.push("disabled = " + options.disabled)
        if (options.mirrorOf !== undefined) values.push("mirrorOf = \"" + luaString(options.mirrorOf) + "\"")
        return "hl.monitor({" + values.join(",") + "})"
    }

    Process {
        id: pList
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.monitors = JSON.parse(text)
                } catch (error) {
                    page.monitors = []
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {}
        }
    }

    function refresh() {
        pList.running = true
    }

    Process {
        id: pApply
        property var pendingMon: null

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out.length === 0) return

                const match = out.match(/using suggested scale:\s*([\d.]+)/i)
                if (match && pApply.pendingMon) {
                    const suggested = parseFloat(match[1])
                    page.setScale(pApply.pendingMon, suggested, true)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {}
        }
        onExited: exitCode => {
            refreshTimer.restart()
        }
    }

    function gcd(a, b) { while (b) { [a, b] = [b, a % b] }; return a }

    function validScale(mon, requested) {
        const width = mon.width
        const height = mon.height
        let best = requested
        let bestDistance = Infinity

        for (let i = 84; i <= 1560; i++) {
            const scale = i / 120
            if (scale < 0.7 || scale > 1.3) continue

            const logicalWidth = width / scale
            const logicalHeight = height / scale

            if (Math.abs(logicalWidth - Math.round(logicalWidth)) < 0.0001 &&
                Math.abs(logicalHeight - Math.round(logicalHeight)) < 0.0001) {
                const distance = Math.abs(scale - requested)
                if (distance < bestDistance) {
                    best = scale
                    bestDistance = distance
                }
            }
        }

        return best
    }

    function setScale(mon, scale, isRetry = false) {
        const requested = scale
        const applied = isRetry ? scale : validScale(mon, requested)

        const idx = page.monitors.findIndex(m => m.name === mon.name)
        if (idx !== -1) {
            const updated = page.monitors.slice()
            updated[idx] = Object.assign({}, updated[idx], { scale: applied })
            page.monitors = updated
        }

        pApply.pendingMon = mon
        pApply.command = [
            "hyprctl", "eval",
            monitorLua(mon, { mode: monitorMode(mon), position: mon.x + "x" + mon.y, scale: applied })
        ]
        pApply.running = true
    }

    Process {
        id: pResolution
        stdout: StdioCollector {
            onStreamFinished: {}
        }
        stderr: StdioCollector {
            onStreamFinished: {}
        }
        onExited: exitCode => {
            refreshTimer.restart()
        }
    }

    function setResolution(mon, resolution) {
        if (!mon || !mon.name || !resolution) {
            return
        }
        const lua = monitorLua(mon, {
            mode: resolution,
            position: mon.x + "x" + mon.y,
            scale: mon.scale !== undefined ? mon.scale : 1
        })
        try {
            pResolution.command = ["hyprctl", "eval", lua]
            pResolution.running = true
        } catch (error) {}
    }

    Timer { id: refreshTimer; interval: 250; onTriggered: page.refresh() }

    Process {
        id: pEditConfig
        command: ["sh", "-c", "xed ~/.config/hypr/monitors.lua"]
        onExited: exitCode => {}
    }

    function editConfig() {
        if (pEditConfig.running) {
            return
        }
        pEditConfig.running = true
    }

    Column {
        anchors { left: parent.left; right: parent.right; rightMargin: page.rightMargin; top: parent.top; bottom: parent.bottom }
        spacing: 9

        Row {
            width: parent.width; height: 36

            Text {
                text: "DISPLAY"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -6
            }

            Item { width: parent.width - 150; height: 1 }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Row {
            width: parent.width; height: 38; spacing: 8

            Rectangle {
                width: 28; height: 28; radius: Theme.radius; anchors.verticalCenter: parent.verticalCenter
                color: Theme.alpha(Theme.accent2, 0.10); border.width: 1; border.color: Theme.border
                Text {
                    anchors.centerIn: parent; text: "\uf185"; color: Theme.accent2
                    font.family: Theme.iconFont; font.pixelSize: 12
                }
            }

            Text {
                width: page.labelWidth; anchors.verticalCenter: parent.verticalCenter
                text: "BRIGHTNESS"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 15
            }

            Slider {
                width: parent.width - 28 - page.labelWidth - 16 - page.sliderMarginRight
                height: 72; anchors.verticalCenter: parent.verticalCenter
                label: ""; icon: ""; value: page.brightnessValue; accentColor: Theme.accent2
                onCommitted: value => page.commitBrightness(value)
            }
        }

        Row {
            width: parent.width; height: 38; spacing: 10

            Rectangle {
                width: 28; height: 28; radius: Theme.radius; anchors.verticalCenter: parent.verticalCenter
                color: page.nightlightEnabled ? Theme.alpha(Theme.accent, 0.10) : Theme.alpha("#A0A0A0", 0.15)
                border.width: 1; border.color: page.nightlightEnabled ? Theme.accent : Theme.border
                Text {
                    anchors.centerIn: parent; text: "\uf186"
                    color: page.nightlightEnabled ? Theme.accent : "#A0A0A0"
                    font.family: Theme.iconFont; font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: page.nightlightEnabled ? page.nightlightOff() : page.nightlightOn()
                }
            }

            Text {
                width: page.labelWidth; anchors.verticalCenter: parent.verticalCenter
                text: "NIGHTLIGHT"; color: page.nightlightEnabled ? Theme.text : Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 15
            }

            Slider {
                width: parent.width - 28 - page.labelWidth - 16 - page.sliderMarginRight
                height: 72; anchors.verticalCenter: parent.verticalCenter
                label: ""; icon: ""; value: page.nightlightValue; accentColor: "#ffffff"
                onMoved: value => page.commitNightlight(value)
            }
        }

        Column {
            width: parent.width; spacing: 16

            Repeater {
                model: page.monitors

                delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 100; radius: Theme.radius
                    color: "#00000000"; border.width: 1
                    border.color: modelData.focused ? "#454545" : Theme.border

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        Row {
                            spacing: 10

                            Text {
                                text: modelData.name; color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true
                            }

                            Text {
                                text: modelData.width + "x" + modelData.height + " @ " + Math.round(modelData.refreshRate) + "Hz"
                                color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12
                            }

                            Text {
                                visible: modelData.focused; text: "ACTIVE"; color: Theme.accent2
                                font.family: Theme.fontFamily; font.pixelSize: 10
                            }
                        }

                        Item {
                            width: parent.width
                            height: scaleLabel.implicitHeight
                            Text {
                                id: scaleLabel
                                anchors.left: parent.left
                                text: "SCALE"
                                color: Theme.textDim
                                font.family: Theme.fontFamily; font.pixelSize: 11
                                }
                            Text {
                                anchors.right: parent.right
                                text: modelData.scale.toFixed(2) + "x"
                                color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: 11
                                }
                            }
                            Slider {
                                width: parent.width
                                icon: "\uf00e"
                                value: Math.max(0, Math.min(1, (modelData.scale - 0.7) / 0.6))
                                onCommitted: value => page.setScale(modelData, 0.7 + value * 0.6)
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width; spacing: 10
            topPadding: 6
            bottomPadding: 6

            Text {
                text: "RESOLUTION"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 15; font.bold: true; font.letterSpacing: 2
            }

            Row {
                width: parent.width; spacing: 10
                topPadding: 6
                bottomPadding: 6
                Repeater {
                    model: [
                        "1920x1080",
                        "2560x1440",
                        "3840x2160",
                        "1280x720"
                    ]

                    delegate: Rectangle {
                        required property string modelData
                        width: (parent.width - parent.spacing * 3) / 4; height: 42; radius: Theme.radius
                        color: "#00000000"; border.width: 1; border.color: Theme.border

                        Text {
                            anchors.centerIn: parent; text: modelData; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: { parent.color = Theme.alpha(Theme.accent, 0.08); parent.border.color = Theme.accent }
                            onExited: { parent.color = "#00000000"; parent.border.color = Theme.border }
                            onClicked: {
                                if (page.monitors.length === 0) {
                                    page.refresh()
                                    return
                                }
                                page.setResolution(page.monitors[0], modelData + "@60")
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        brightnessGet.running = true
        loadNightlight()
        nightlightCheck.running = true
    }
}