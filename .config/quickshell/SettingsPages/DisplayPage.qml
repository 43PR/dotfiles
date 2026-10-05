import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property var monitors: []
    property var savedState: ({})
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property real brightnessValue: 0.6
    property real nightlightValue: 0.5
    property bool nightlightEnabled: false
    property real sliderMarginRight: 10
    property real labelWidth: 96
    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"

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

    Process {
        id: stateDirProcess
        command: ["mkdir", "-p", page.stateDir]
    }

    FileView {
        id: displayFile
        path: page.stateDir + "/display.json"
        blockLoading: true
    }

    FileView {
        id: displayLua
        path: page.stateDir + "/display.lua"
    }

    function loadState() {
        try {
            const saved = JSON.parse(displayFile.text())
            if (saved && typeof saved.monitors === "object" && saved.monitors !== null) {
                savedState = saved.monitors
            }
        } catch (error) {}
    }

    function luaFileText() {
        const lines = []
        const names = Object.keys(savedState)
        for (let i = 0; i < names.length; i++) {
            const entry = savedState[names[i]]
            if (!entry || typeof entry.mode !== "string") continue
            lines.push(monitorLua({ name: names[i] }, {
                mode: entry.mode,
                position: typeof entry.position === "string" ? entry.position : "auto",
                scale: typeof entry.scale === "number" ? entry.scale : 1
            }))
        }
        return lines.join("\n") + "\n"
    }

    Timer {
        id: stateSaveTimer
        interval: 300
        onTriggered: {
            try {
                displayFile.setText(JSON.stringify({ monitors: page.savedState }, null, 2))
                displayLua.setText(page.luaFileText())
            } catch (error) {}
        }
    }

    function monitorPosition(mon) {
        return page.monitors.length <= 1 ? "auto" : mon.x + "x" + mon.y
    }

    function rememberMonitor(mon, fields) {
        if (!mon || !mon.name) return
        const next = Object.assign({}, savedState)
        next[mon.name] = Object.assign({}, next[mon.name] || {}, fields)
        savedState = next
        stateSaveTimer.restart()
    }

    Process {
        id: pReset
        onExited: exitCode => {
            refreshTimer.restart()
        }
    }

    function resetToConfig() {
        stateSaveTimer.stop()
        savedState = ({})
        pReset.command = [
            "sh", "-c",
            "rm -f '" + page.stateDir + "/display.json' '" + page.stateDir + "/display.lua'; hyprctl reload"
        ]
        pReset.running = true
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

        rememberMonitor(mon, { mode: monitorMode(mon), scale: applied, position: monitorPosition(mon) })

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

    function resolutionList(mon) {
        if (!mon || !mon.availableModes) return []
        const seen = {}
        const items = []
        for (let i = 0; i < mon.availableModes.length; i++) {
            const match = String(mon.availableModes[i]).match(/^(\d+)x(\d+)@/)
            if (!match) continue
            const key = match[1] + "x" + match[2]
            if (seen[key]) continue
            seen[key] = true
            items.push({ key: key, width: parseInt(match[1]), height: parseInt(match[2]) })
        }
        items.sort((a, b) => (b.width * b.height - a.width * a.height) || (b.width - a.width))
        return items.map(item => item.key)
    }

    function bestMode(mon, resolution) {
        if (!mon || !mon.availableModes) return null
        const prefix = resolution + "@"
        let bestRate = null
        let bestDistance = Infinity
        for (let i = 0; i < mon.availableModes.length; i++) {
            const mode = String(mon.availableModes[i])
            if (mode.indexOf(prefix) !== 0) continue
            const rate = parseFloat(mode.substring(prefix.length))
            if (isNaN(rate)) continue
            const distance = Math.abs(rate - mon.refreshRate)
            if (distance < bestDistance || (distance === bestDistance && rate > bestRate)) {
                bestRate = rate
                bestDistance = distance
            }
        }
        return bestRate === null ? null : prefix + bestRate.toFixed(2)
    }

    function setResolution(mon, resolution) {
        if (!mon || !mon.name || !resolution) {
            return
        }
        const scale = mon.scale !== undefined ? mon.scale : 1
        rememberMonitor(mon, { mode: resolution, scale: scale, position: monitorPosition(mon) })
        const lua = monitorLua(mon, {
            mode: resolution,
            position: mon.x + "x" + mon.y,
            scale: scale
        })
        try {
            pResolution.command = ["hyprctl", "eval", lua]
            pResolution.running = true
        } catch (error) {}
    }

    function refreshRates(mon) {
        if (!mon || !mon.availableModes) return []
        const prefix = mon.width + "x" + mon.height + "@"
        const seen = {}
        const rates = []
        for (let i = 0; i < mon.availableModes.length; i++) {
            const mode = String(mon.availableModes[i])
            if (mode.indexOf(prefix) !== 0) continue
            const match = mode.match(/@([\d.]+)/)
            if (!match) continue
            const rate = parseFloat(match[1])
            if (isNaN(rate)) continue
            const key = rate.toFixed(2)
            if (seen[key]) continue
            seen[key] = true
            rates.push(rate)
        }
        rates.sort((a, b) => b - a)
        return rates
    }

    function setRefreshRate(mon, rate) {
        if (!mon || !mon.name || rate === undefined) {
            return
        }
        const mode = mon.width + "x" + mon.height + "@" + rate.toFixed(2)
        const scale = mon.scale !== undefined ? mon.scale : 1
        rememberMonitor(mon, { mode: mode, scale: scale, position: monitorPosition(mon) })
        const lua = monitorLua(mon, {
            mode: mode,
            position: mon.x + "x" + mon.y,
            scale: scale
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
                text: "DISPLAY"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
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
                    label: ""; icon: ""; value: page.nightlightValue; accentColor: Theme.accent2
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

                Repeater {
                    model: page.monitors

                    delegate: Column {
                        id: resBlock
                        required property var modelData
                        property var resolutions: page.resolutionList(modelData)
                        width: parent.width; spacing: 8

                        Text {
                            text: modelData.name; color: Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }

                        Flow {
                            width: parent.width; spacing: 10

                            Repeater {
                                model: resBlock.resolutions

                                delegate: Rectangle {
                                    id: resButton
                                    required property string modelData
                                    property bool current: modelData === resBlock.modelData.width + "x" + resBlock.modelData.height
                                    width: 112; height: 38; radius: Theme.radius
                                    color: current ? Theme.alpha(Theme.accent, 0.10) : (resMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                    border.width: 1
                                    border.color: current || resMouse.containsMouse ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: resButton.modelData
                                        color: Theme.text
                                        font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                                    }

                                    MouseArea {
                                        id: resMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const mode = page.bestMode(resBlock.modelData, resButton.modelData)
                                            if (mode) page.setResolution(resBlock.modelData, mode)
                                        }
                                    }
                                }
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
                    text: "REFRESH RATE"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 15; font.bold: true; font.letterSpacing: 2
                }

                Repeater {
                    model: page.monitors

                    delegate: Column {
                        id: rateBlock
                        required property var modelData
                        property var rates: page.refreshRates(modelData)
                        width: parent.width; spacing: 8

                        Text {
                            text: modelData.name; color: Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }

                        Flow {
                            width: parent.width; spacing: 10

                            Repeater {
                                model: rateBlock.rates

                                delegate: Rectangle {
                                    id: rateButton
                                    required property var modelData
                                    property bool current: Math.abs(modelData - rateBlock.modelData.refreshRate) < 0.05
                                    width: 96; height: 38; radius: Theme.radius
                                    color: current ? Theme.alpha(Theme.accent, 0.10) : (rateMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                    border.width: 1
                                    border.color: current || rateMouse.containsMouse ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: rateButton.modelData.toFixed(2) + " Hz"
                                        color: Theme.text
                                        font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true
                                    }

                                    MouseArea {
                                        id: rateMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setRefreshRate(rateBlock.modelData, rateButton.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 42; radius: Theme.radius
                color: resetMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                border.width: 1
                border.color: resetMouse.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent; text: "RESET TO CONFIG"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.resetToConfig()
                }
            }
        }
    }

    Component.onCompleted: {
        stateDirProcess.running = true
        loadState()
        brightnessGet.running = true
        loadNightlight()
        nightlightCheck.running = true
    }
}