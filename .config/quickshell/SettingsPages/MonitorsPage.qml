import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    property var monitors: []
    property int rightMargin: 36

    // -------------------------
    // Brightness
    // -------------------------
    property real brightnessValue: 0.6

    Process {
        id: brightnessGet

        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",")

                if (parts.length < 4)
                    return

                const pct = parseInt(parts[3])

                if (!isNaN(pct))
                    page.brightnessValue = pct / 100
            }
        }
    }

    Process {
        id: brightnessSet

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function commitBrightness(value) {
        brightnessSet.command = [
            "brightnessctl",
            "set",
            Math.round(value * 100) + "%"
        ]

        brightnessSet.running = true
    }

    // -------------------------
    // Night Light
    // -------------------------
    property real nightlightValue: 0.5
    property bool nightlightEnabled: false

    Process {
        id: nightlightProcess

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function nightlightTemperature(value) {
        return Math.round(2500 + value * 4000)
    }

    function startNightlight(value, delay) {
        const temp = nightlightTemperature(value)

        nightlightProcess.command = [
            "sh",
            "-c",
            "pkill -x gammastep 2>/dev/null; " +
            "sleep " + delay + "; " +
            "nohup gammastep -O " + temp +
            " >/dev/null 2>&1 &"
        ]

        nightlightProcess.running = true
    }

    function nightlightOn() {
        page.nightlightEnabled = true
        startNightlight(page.nightlightValue, "0.05")
    }

    function nightlightOff() {
        page.nightlightEnabled = false

        nightlightProcess.command = [
            "pkill",
            "-x",
            "gammastep"
        ]

        nightlightProcess.running = true
    }

    function commitNightlight(value) {
        page.nightlightValue = value

        if (!page.nightlightEnabled)
            return

        startNightlight(value, "0.03")
    }

    // -------------------------
    // Monitor helpers
    // -------------------------
    function isInternalMonitor(mon) {
        return mon.name.indexOf("eDP") === 0
            || mon.name.indexOf("LVDS") === 0
    }

    function findMonitors() {
        let internal = null
        let external = null

        for (let i = 0; i < page.monitors.length; i++) {
            const mon = page.monitors[i]

            if (isInternalMonitor(mon)) {
                internal = mon
            } else if (!external) {
                external = mon
            }
        }

        return {
            internal: internal,
            external: external
        }
    }

    function monitorMode(mon) {
        return mon.width
            + "x"
            + mon.height
            + "@"
            + mon.refreshRate.toFixed(2)
    }

    function monitorLua(mon, options) {
        let lua =
            "hl.monitor({" +
            "output = \"" + luaString(mon.name) + "\","

        if (options.mode !== undefined)
            lua += "mode = \"" + options.mode + "\","

        if (options.position !== undefined)
            lua += "position = \"" + options.position + "\","

        if (options.scale !== undefined)
            lua += "scale = " + options.scale + ","

        if (options.disabled !== undefined)
            lua += "disabled = " + options.disabled + ","

        if (options.mirrorOf !== undefined)
            lua += "mirrorOf = \"" +
                luaString(options.mirrorOf) + "\","

        if (lua.endsWith(","))
            lua = lua.slice(0, -1)

        return lua + "})"
    }

    // -------------------------
    // Monitor list
    // -------------------------
    Process {
        id: pList

        command: ["hyprctl", "monitors", "-j"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.monitors = JSON.parse(text)

                    console.log(
                        "MONITORS FOUND:",
                        page.monitors.length
                    )

                    for (let i = 0; i < page.monitors.length; i++) {
                        const mon = page.monitors[i]

                        console.log(
                            "MONITOR:",
                            mon.name,
                            mon.width,
                            "x",
                            mon.height,
                            "@",
                            mon.refreshRate
                        )
                    }
                } catch (error) {
                    console.log(
                        "Failed to parse monitor list:",
                        error
                    )

                    page.monitors = []
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output !== "")
                    console.log(
                        "hyprctl monitors ERROR:",
                        output
                    )
            }
        }
    }

    function refresh() {
        pList.running = true
    }

    // -------------------------
    // Monitor scale
    // -------------------------
    Process {
        id: pApply

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output !== "")
                    console.log("SCALE:", output)
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output !== "")
                    console.log("SCALE ERROR:", output)
            }
        }
    }

    function setScale(mon, scale) {
        const lua = monitorLua(mon, {
            mode: monitorMode(mon),
            position: mon.x + "x" + mon.y,
            scale: scale.toFixed(2)
        })

        pApply.command = [
            "hyprctl",
            "eval",
            lua
        ]

        console.log("SETTING SCALE:", lua)

        pApply.running = true
    }

    // -------------------------
    // Monitor mode process
    // -------------------------
    Process {
        id: pMode

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output !== "")
                    console.log(
                        "MONITOR MODE OUTPUT:",
                        output
                    )
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output !== "")
                    console.log(
                        "MONITOR MODE ERROR:",
                        output
                    )
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.log(
                "MONITOR MODE EXIT:",
                exitCode,
                exitStatus
            )

            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer

        interval: 250
        repeat: false

        onTriggered: page.refresh()
    }

    function luaString(value) {
        return String(value)
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
    }

    function runMonitorLua(lua) {
        console.log("LUA:", lua)

        pMode.command = [
            "hyprctl",
            "eval",
            lua
        ]

        console.log(
            "EXECUTING:",
            pMode.command.join(" ")
        )

        pMode.running = true
    }

    // -------------------------
    // Monitor modes
    // -------------------------
    function applyMonitorMode(mode) {
        console.log("================================")
        console.log("APPLY MONITOR MODE:", mode)

        if (page.monitors.length === 0) {
            console.log("ERROR: No monitors available")
            page.refresh()
            return
        }

        const displays = findMonitors()
        const internal = displays.internal
        const external = displays.external

        for (let i = 0; i < page.monitors.length; i++)
            console.log(
                "Checking monitor:",
                page.monitors[i].name
            )

        if (!internal) {
            console.log(
                "ERROR: Could not find internal display"
            )
            return
        }

        if (!external) {
            console.log(
                "ERROR: Could not find external display"
            )
            return
        }

        console.log("INTERNAL:", internal.name)
        console.log("EXTERNAL:", external.name)

        const internalMode = monitorMode(internal)
        const externalMode = monitorMode(external)

        if (mode === "first") {
            runMonitorLua(monitorLua(internal, {
                mode: internalMode,
                position: "0x0",
                scale: internal.scale
            }))

            firstTimer.restart()
            return
        }

        if (mode === "second") {
            runMonitorLua(monitorLua(external, {
                mode: externalMode,
                position: "0x0",
                scale: external.scale
            }))

            secondTimer.restart()
            return
        }

        if (mode === "extend") {
            runMonitorLua(monitorLua(external, {
                mode: externalMode,
                position: "0x0",
                scale: external.scale
            }))

            extendTimer.restart()
            return
        }

        if (mode === "duplicate") {
            runMonitorLua(monitorLua(internal, {
                mode: internalMode,
                position: "0x0",
                scale: internal.scale
            }))

            duplicateTimer.restart()
            return
        }

        console.log("ERROR: Unknown monitor mode:", mode)
    }

    // -------------------------
    // FIRST continuation
    // -------------------------
    Timer {
        id: firstTimer

        interval: 100
        repeat: false

        onTriggered: {
            if (page.monitors.length < 1)
                return

            const external = findMonitors().external

            if (!external)
                return

            runMonitorLua(monitorLua(external, {
                disabled: true
            }))
        }
    }

    // -------------------------
    // SECOND continuation
    // -------------------------
    Timer {
        id: secondTimer

        interval: 100
        repeat: false

        onTriggered: {
            page.refresh()
            secondRefreshTimer.restart()
        }
    }

    Timer {
        id: secondRefreshTimer

        interval: 200
        repeat: false

        onTriggered: {
            const external = findMonitors().external

            if (!external)
                return

            runMonitorLua(monitorLua(external, {
                mode: "preferred",
                position: "0x0",
                scale: "\"auto\""
            }))
        }
    }

    // -------------------------
    // EXTEND continuation
    // -------------------------
    Timer {
        id: extendTimer

        interval: 100
        repeat: false

        onTriggered: {
            page.refresh()
            extendRefreshTimer.restart()
        }
    }

    Timer {
        id: extendRefreshTimer

        interval: 200
        repeat: false

        onTriggered: {
            const displays = findMonitors()
            const internal = displays.internal
            const external = displays.external

            if (!internal || !external)
                return

            runMonitorLua(monitorLua(external, {
                mode: monitorMode(external),
                position: "0x0",
                scale: external.scale
            }))

            extendFinalTimer.restart()
        }
    }

    Timer {
        id: extendFinalTimer

        interval: 100
        repeat: false

        onTriggered: {
            page.refresh()
            extendFinalApplyTimer.restart()
        }
    }

    Timer {
        id: extendFinalApplyTimer

        interval: 200
        repeat: false

        onTriggered: {
            const displays = findMonitors()
            const internal = displays.internal
            const external = displays.external

            if (!internal || !external)
                return

            runMonitorLua(monitorLua(internal, {
                mode: monitorMode(internal),
                position: external.width + "x0",
                scale: internal.scale
            }))
        }
    }

    // -------------------------
    // DUPLICATE continuation
    // -------------------------
    Timer {
        id: duplicateTimer

        interval: 100
        repeat: false

        onTriggered: {
            page.refresh()
            duplicateApplyTimer.restart()
        }
    }

    Timer {
        id: duplicateApplyTimer

        interval: 200
        repeat: false

        onTriggered: {
            const displays = findMonitors()
            const internal = displays.internal
            const external = displays.external

            if (!internal || !external)
                return

            runMonitorLua(monitorLua(external, {
                mode: monitorMode(internal),
                position: "0x0",
                scale: external.scale,
                mirrorOf: internal.name
            }))
        }
    }

    // -------------------------
    // Page
    // -------------------------
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: page.rightMargin
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 20

        // -------------------------
        // Header
        // -------------------------
        Row {
            width: parent.width

            Text {
                text: "MONITORS"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.bold: true
                font.letterSpacing: 3
            }

            Item {
                width: parent.width - 150
                height: 1
            }

            Text {
                text: "󰑐"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 22

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.refresh()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // -------------------------
        // MONITOR MODE
        // -------------------------
        Column {
            width: parent.width
            spacing: 10

            Text {
                text: "MONITOR MODE"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                font.letterSpacing: 2
            }

            Row {
                width: parent.width
                spacing: 10

                Repeater {
                    model: [
                        { name: "FIRST", mode: "first" },
                        { name: "SECOND", mode: "second" },
                        { name: "EXTEND", mode: "extend" },
                        { name: "DUPLICATE", mode: "duplicate" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width:
                            (
                                parent.width -
                                parent.spacing * 3
                            ) / 4

                        height: 42
                        radius: Theme.radius
                        color: "#00000000"
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true

                            onEntered: {
                                parent.color =
                                    Theme.alpha(
                                        Theme.accent,
                                        0.08
                                    )

                                parent.border.color =
                                    Theme.accent
                            }

                            onExited: {
                                parent.color = "#00000000"
                                parent.border.color = Theme.border
                            }

                            onClicked: {
                                console.log(
                                    "BUTTON CLICKED:",
                                    modelData.name,
                                    modelData.mode
                                )

                                page.applyMonitorMode(
                                    modelData.mode
                                )
                            }
                        }
                    }
                }
            }
        }

        // -------------------------
        // BRIGHTNESS
        // -------------------------
        Item {
            width: parent.width
            height: 58

            Slider {
                anchors.fill: parent

                label: "BRIGHTNESS"
                icon: "\uf185"
                value: page.brightnessValue
                accentColor: Theme.accent2

                onCommitted: (value) =>
                    page.commitBrightness(value)
            }
        }

        // -------------------------
        // NIGHT LIGHT
        // -------------------------
        Item {
            width: parent.width
            height: 58

            property int controlMargin: 25

            Row {
                anchors.fill: parent
                spacing: parent.controlMargin

                Slider {
                    width:
                        parent.width -
                        70 -
                        parent.spacing

                    height: parent.height

                    label: "NIGHT LIGHT"
                    icon: "\uf186"
                    value: page.nightlightValue
                    accentColor: "#ffffff"

                    onMoved: (value) =>
                        page.commitNightlight(value)
                }

                Rectangle {
                    width: 70
                    height: 36
                    radius: Theme.radius
                    anchors.verticalCenter: parent.verticalCenter

                    color:
                        page.nightlightEnabled
                            ? Theme.alpha(
                                Theme.accent,
                                0.1
                            )
                            : Theme.alpha(
                                "#A0A0A0",
                                0.15
                            )

                    border.width: 1

                    border.color:
                        page.nightlightEnabled
                            ? Theme.accent
                            : "#A0A0A0"

                    Text {
                        anchors.centerIn: parent

                        text:
                            page.nightlightEnabled
                                ? "ON"
                                : "OFF"

                        color:
                            page.nightlightEnabled
                                ? Theme.accent
                                : "#A0A0A0"

                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            if (page.nightlightEnabled)
                                page.nightlightOff()
                            else
                                page.nightlightOn()
                        }
                    }
                }
            }
        }

        // -------------------------
        // MONITOR LIST
        // -------------------------
        Column {
            width: parent.width
            spacing: 16

            Repeater {
                model: page.monitors

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 100
                    radius: Theme.radius
                    color: "#00000000"
                    border.width: 1
                    border.color:
                        modelData.focused
                            ? "#454545"
                            : Theme.border

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Row {
                            spacing: 10

                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text:
                                    modelData.width +
                                    "x" +
                                    modelData.height +
                                    " @ " +
                                    Math.round(
                                        modelData.refreshRate
                                    ) +
                                    "Hz"

                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }

                            Text {
                                visible: modelData.focused
                                text: "ACTIVE"
                                color: Theme.accent2
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }

                        Slider {
                            width: parent.width

                            label:
                                "SCALE (" +
                                modelData.scale.toFixed(2) +
                                "x)"

                            icon: "\uf00e"

                            value:
                                (
                                    modelData.scale - 0.5
                                ) / 1.5

                            onCommitted: (value) =>
                                page.setScale(
                                    modelData,
                                    0.5 + value * 1.5
                                )
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        brightnessGet.running = true
    }
}
