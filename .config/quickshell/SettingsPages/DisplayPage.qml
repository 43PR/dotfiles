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
    readonly property var activeMonitors: monitors.filter(m => !m.disabled)

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
            if (!entry) continue
            if (entry.disabled === true) {
                lines.push(monitorLua({ name: names[i] }, { disabled: true }))
                continue
            }
            if (typeof entry.mode !== "string") continue
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
        return page.activeMonitors.length <= 1 ? "auto" : mon.x + "x" + mon.y
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

    function isMain(mon) {
        return !mon.disabled && page.activeMonitors.length > 0 && mon.x === 0 && mon.y === 0
    }

    Process {
        id: pShell
        onExited: exitCode => {
            refreshTimer.restart()
        }
    }

    function layoutCommands(ordered) {
        const cmds = []
        let x = 0
        for (let i = 0; i < ordered.length; i++) {
            const m = ordered[i]
            const mode = monitorMode(m)
            const pos = x + "x0"
            rememberMonitor(m, { mode: mode, scale: m.scale, position: pos, disabled: false })
            cmds.push("hyprctl eval '" + monitorLua(m, { mode: mode, position: pos, scale: m.scale }) + "'")
            x += Math.round(m.width / m.scale)
        }
        if (ordered.length > 0) cmds.push("hyprctl dispatch focusmonitor '" + ordered[0].name + "'")
        return cmds
    }

    function setMainMonitor(main) {
        if (!main || !main.name || main.disabled) return
        const others = page.activeMonitors.filter(m => m.name !== main.name).sort((a, b) => a.x - b.x)
        const cmds = layoutCommands([main].concat(others))
        pShell.command = ["sh", "-c", cmds.join("; ")]
        pShell.running = true
    }

    function setMonitorEnabled(mon, enabled) {
        if (!mon || !mon.name) return
        let cmds = []
        if (enabled) {
            const entry = savedState[mon.name] || {}
            const mode = typeof entry.mode === "string" ? entry.mode : "preferred"
            const scale = typeof entry.scale === "number" ? entry.scale : 1
            rememberMonitor(mon, { mode: mode, scale: scale, position: "auto", disabled: false })
            cmds.push("hyprctl eval '" + monitorLua(mon, { mode: mode, position: "auto", scale: scale }) + "'")
        } else {
            if (page.activeMonitors.length <= 1) return
            const wasMain = isMain(mon)
            rememberMonitor(mon, { mode: monitorMode(mon), scale: mon.scale, disabled: true })
            cmds.push("hyprctl eval '" + monitorLua(mon, { disabled: true }) + "'")
            if (wasMain) {
                const rest = page.activeMonitors.filter(m => m.name !== mon.name).sort((a, b) => a.x - b.x)
                cmds = cmds.concat(layoutCommands(rest))
            }
        }
        pShell.command = ["sh", "-c", cmds.join("; ")]
        pShell.running = true
    }

    Process {
        id: pList
        command: ["hyprctl", "monitors", "all", "-j"]
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
        return items.slice(0, 6).map(item => item.key)
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
                width: parent.width; spacing: 8

                Repeater {
                    model: page.monitors

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        property bool off: modelData.disabled === true
                        property bool main: page.isMain(modelData)
                        width: parent.width
                        height: cardColumn.implicitHeight + 20
                        radius: Theme.radius
                        color: "#00000000"; border.width: 1
                        border.color: modelData.focused && !off ? "#454545" : Theme.border

                        Column {
                            id: cardColumn
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 6

                            Item {
                                width: parent.width; height: 24

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        text: card.modelData.name
                                        color: card.off ? Theme.textDim : Theme.text
                                        font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true
                                    }

                                    Text {
                                        visible: !card.off
                                        text: card.modelData.width + "x" + card.modelData.height + " @ " + Math.round(card.modelData.refreshRate) + "Hz"
                                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Rectangle {
                                        visible: !card.off && page.activeMonitors.length > 1
                                        width: 84; height: 24; radius: Theme.radius
                                        color: card.main ? Theme.alpha(Theme.accent, 0.10) : (mainMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                        border.width: 1
                                        border.color: card.main || mainMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.main ? "MAIN" : "SET MAIN"
                                            color: card.main ? Theme.accent : Theme.text
                                            font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: mainMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            enabled: !card.main
                                            cursorShape: card.main ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: page.setMainMonitor(card.modelData)
                                        }
                                    }

                                    Rectangle {
                                        visible: card.off || page.activeMonitors.length > 1
                                        width: 72; height: 24; radius: Theme.radius
                                        color: toggleMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                                        border.width: 1
                                        border.color: toggleMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.off ? "ENABLE" : "DISABLE"
                                            color: Theme.text
                                            font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: toggleMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.setMonitorEnabled(card.modelData, card.off)
                                        }
                                    }
                                }
                            }

                            Row {
                                visible: !card.off
                                width: parent.width; spacing: 8

                                Text {
                                    id: scaleLabel
                                    width: 36; anchors.verticalCenter: parent.verticalCenter
                                    text: "SCALE"; color: Theme.textDim
                                    font.family: Theme.fontFamily; font.pixelSize: 11
                                }

                                Slider {
                                    width: parent.width - 36 - 44 - 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "\uf00e"
                                    value: Math.max(0, Math.min(1, (card.modelData.scale - 0.7) / 0.6))
                                    onCommitted: value => page.setScale(card.modelData, 0.7 + value * 0.6)
                                }

                                Text {
                                    width: 44; anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: card.modelData.scale.toFixed(2) + "x"
                                    color: Theme.text
                                    font.family: Theme.fontFamily; font.pixelSize: 11
                                }
                            }

                            Row {
                                visible: !card.off
                                width: parent.width; spacing: 8

                                Text {
                                    width: 36; height: 28
                                    verticalAlignment: Text.AlignVCenter
                                    text: "RES"; color: Theme.textDim
                                    font.family: Theme.fontFamily; font.pixelSize: 11
                                }

                                Flow {
                                    width: parent.width - 36 - 8; spacing: 6

                                    Repeater {
                                        model: card.off ? [] : page.resolutionList(card.modelData)

                                        delegate: Rectangle {
                                            id: resButton
                                            required property string modelData
                                            property bool current: modelData === card.modelData.width + "x" + card.modelData.height
                                            width: 92; height: 28; radius: Theme.radius
                                            color: current ? Theme.alpha(Theme.accent, 0.10) : (resMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                            border.width: 1
                                            border.color: current || resMouse.containsMouse ? Theme.accent : Theme.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: resButton.modelData
                                                color: Theme.text
                                                font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true
                                            }

                                            MouseArea {
                                                id: resMouse
                                                anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const mode = page.bestMode(card.modelData, resButton.modelData)
                                                    if (mode) page.setResolution(card.modelData, mode)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                visible: !card.off
                                width: parent.width; spacing: 8

                                Text {
                                    width: 36; height: 28
                                    verticalAlignment: Text.AlignVCenter
                                    text: "HZ"; color: Theme.textDim
                                    font.family: Theme.fontFamily; font.pixelSize: 11
                                }

                                Flow {
                                    width: parent.width - 36 - 8; spacing: 6

                                    Repeater {
                                        model: card.off ? [] : page.refreshRates(card.modelData)

                                        delegate: Rectangle {
                                            id: rateButton
                                            required property var modelData
                                            property bool current: Math.abs(modelData - card.modelData.refreshRate) < 0.05
                                            width: 76; height: 28; radius: Theme.radius
                                            color: current ? Theme.alpha(Theme.accent, 0.10) : (rateMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                            border.width: 1
                                            border.color: current || rateMouse.containsMouse ? Theme.accent : Theme.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: rateButton.modelData.toFixed(2)
                                                color: Theme.text
                                                font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true
                                            }

                                            MouseArea {
                                                id: rateMouse
                                                anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: page.setRefreshRate(card.modelData, rateButton.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 34; radius: Theme.radius
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