import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    property string homeDir: ""
    property string uptime: "..."
    property string os: "..."
    property string wm: "Hyprland"
    property string cpu: "Loading..."
    property string gpu: "Loading..."
    property string memory: "Loading..."
    property string ramSpeed: "Loading..."

    property real cpuUsage: 0
    property real gpuUsage: 0
    property real memoryUsage: 0

    property string cpuTemp: "—"
    property string gpuTemp: "—"

    property var cpuHistory: []
    property var gpuHistory: []
    property var memoryHistory: []

    property var cpuPrev: null

    property int hardwareLabelSize: 12
    property int hardwareTextSize: 12
    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 46

    property string currentTime: ""

    // --- helpers -----------------------------------------------------

    // Pushes `value` (0-100) onto the named history ("cpu"/"gpu"/"memory")
    // and updates the matching *Usage property. HardwareGraph repaints
    // itself via onHistoryChanged, so no manual requestPaint() is needed.
    function updateGraph(value, type) {
        value = parseFloat(value)
        if (isNaN(value)) return
        value = Math.max(0, Math.min(100, value))

        page[type + "Usage"] = value

        var history = page[type + "History"].slice()
        history.push(value)
        if (history.length > 60) history.shift()
        page[type + "History"] = history
    }

    function updateCpuFromStat(value) {
        var p = value.trim().split(/\s+/)
        if (p.length < 5) return

        var user = Number(p[1])
        var nice = Number(p[2])
        var system = Number(p[3])
        var idle = Number(p[4])
        var iowait = Number(p[5] || 0)
        var irq = Number(p[6] || 0)
        var softirq = Number(p[7] || 0)
        var steal = Number(p[8] || 0)

        var idleTime = idle + iowait
        var total = user + nice + system + idle + iowait + irq + softirq + steal

        if (cpuPrev !== null) {
            var totalDelta = total - cpuPrev.total
            var idleDelta = idleTime - cpuPrev.idle

            if (totalDelta > 0)
                updateGraph(100 * (1 - idleDelta / totalDelta), "cpu")
        }

        cpuPrev = { total: total, idle: idleTime }
    }

    function formatMemory(kb) {
        var gb = kb / 1024 / 1024
        return gb >= 1 ? gb.toFixed(1) + " GiB" : Math.round(kb / 1024) + " MiB"
    }

    function updateMemoryFromStat(value) {
        var total = 0
        var available = 0
        var lines = value.trim().split("\n")

        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].trim().split(/\s+/)

            if (parts[0] === "MemTotal:")
                total = Number(parts[1])
            else if (parts[0] === "MemAvailable:")
                available = Number(parts[1])
        }

        if (total <= 0) return

        var used = total - available
        updateGraph((used / total) * 100, "memory")
        page.memory = formatMemory(used) + " / " + formatMemory(total)
    }

    function formatTemp(value) {
        var temp = parseFloat(value.trim())
        return isNaN(temp) ? "—" : Math.round(temp) + "°C"
    }

    // Builds a `sensors | awk` one-liner that prints the first temperature
    // found on any line matching one of `patterns`.
    function sensorTempCmd(patterns) {
        return "sensors 2>/dev/null | awk '/" + patterns.join("|") +
            "/ {for(i=1;i<=NF;i++) if($i ~ /\\+?[0-9]+(\\.[0-9]+)?°C/) " +
            "{gsub(/[+°C]/, \"\", $i); print $i; exit}}'"
    }

    function updateClock() {
        page.currentTime = Qt.formatTime(new Date(), "HH:mm:ss")
    }

    function drawGraph(ctx, history) {
        ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height)

        var w = ctx.canvas.width
        var h = ctx.canvas.height

        if (history.length < 2) return

        var step = w / (history.length - 1)

        ctx.beginPath()
        ctx.moveTo(0, h)
        for (var i = 0; i < history.length; i++)
            ctx.lineTo(i * step, h - history[i] / 100 * h)
        ctx.lineTo(w, h)
        ctx.closePath()

        ctx.fillStyle = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
        ctx.fill()

        ctx.beginPath()
        for (var j = 0; j < history.length; j++) {
            var x = j * step
            var y = h - history[j] / 100 * h
            if (j) ctx.lineTo(x, y)
            else ctx.moveTo(x, y)
        }

        ctx.strokeStyle = Theme.text
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()
    }

    // --- reusable components ------------------------------------------

    component InfoRow: Column {
        property string icon: ""
        property string label: ""
        property string value: ""

        spacing: 3

        Text {
            text: icon + "  " + label
            color: Theme.textDim
            font.family: page.mono
            font.pixelSize: 10
            font.letterSpacing: 2
        }

        Text {
            text: value
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
            width: 500
        }
    }

    component HardwareGraph: Column {
        id: block

        property string icon: ""
        property string label: ""
        property string valueText: ""
        property var badges: []
        property var history: []

        width: parent.width
        spacing: 10

        onHistoryChanged: graphCanvas.requestPaint()

        Row {
            width: parent.width
            height: 24
            spacing: 20

            Text {
                text: block.icon + "  " + block.label
                color: Theme.textDim
                font.family: page.mono
                font.pixelSize: page.hardwareLabelSize
                font.letterSpacing: 2
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: block.valueText
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: page.hardwareTextSize
                elide: Text.ElideLeft
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: block.badges

                Text {
                    text: modelData
                    color: Theme.text
                    font.family: page.mono
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item {
            width: parent.width
            height: 60

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Theme.border
            }

            Repeater {
                model: [0.25, 0.5, 0.75]

                Rectangle {
                    y: parent.height * modelData
                    width: parent.width
                    height: 1
                    color: Theme.border
                    opacity: 0.35
                }
            }

            Canvas {
                id: graphCanvas
                anchors.fill: parent
                anchors.margins: 6
                onPaint: page.drawGraph(getContext("2d"), block.history)
            }

            Text {
                text: "100%"
                anchors { top: parent.top; right: parent.right; margins: 5 }
                color: Theme.text
                opacity: 0.35
                font.family: page.mono
                font.pixelSize: 8
            }

            Text {
                text: "0%"
                anchors { bottom: parent.bottom; right: parent.right; margins: 5 }
                color: Theme.text
                opacity: 0.35
                font.family: page.mono
                font.pixelSize: 8
            }
        }
    }

    // --- processes -------------------------------------------------

    Process {
        id: pHome
        command: ["sh", "-c", "printf '%s' \"$HOME\""]
        running: true
        stdout: StdioCollector { onStreamFinished: page.homeDir = text.trim() }
    }

    Process {
        id: pUptime
        command: ["uptime", "-p"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.uptime = text.trim() }
    }

    Process {
        id: pOs
        command: ["sh", "-c", "grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.os = text.trim() }
    }

    Process {
        id: pCpu
        command: ["sh", "-c", "awk -F: '/model name/ {gsub(/^ +/, \"\", $2); print $2; exit}' /proc/cpuinfo"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.cpu = text.trim() }
    }

    Process {
        id: pCpuUsage
        command: ["sh", "-c", "head -1 /proc/stat"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.updateCpuFromStat(text) }
    }

    Process {
        id: pCpuTemp
        command: ["sh", "-c", page.sensorTempCmd(["Package id 0:", "Tctl:", "Tdie:"])]
        running: true
        stdout: StdioCollector { onStreamFinished: page.cpuTemp = page.formatTemp(text) }
    }

    Process {
        id: pGpu
        command: [
            "sh", "-c",
            "lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | sed -E 's/.*: //; s/ \\(rev.*\\)//' | head -1"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: page.gpu = text.trim() || "Unknown"
        }
    }

    Process {
        id: pGpuUsage
        command: ["sh", "-c", "nvtop -s 2>/dev/null | jq -r '.[0].gpu_util' | tr -d '%'"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.updateGraph(text, "gpu") }
    }

    Process {
        id: pGpuTemp
        command: ["sh", "-c", page.sensorTempCmd(["GPU Temp:", "edge:", "junction:", "temp1:"])]
        running: true
        stdout: StdioCollector { onStreamFinished: page.gpuTemp = page.formatTemp(text) }
    }

    Process {
        id: pMemory
        command: ["sh", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.updateMemoryFromStat(text) }
    }

    Process {
        id: pRamSpeed
        command: ["sudo", "-n", "/usr/bin/dmidecode", "-t", "memory"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var speed = ""

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.indexOf("Configured Memory Speed:") === 0) {
                        var parts = line.split(/\s+/)
                        if (parts.length >= 4 && /^[0-9]+$/.test(parts[3])) {
                            speed = parts[3] + " " + parts[4]
                            break
                        }
                    }
                }

                if (!speed) {
                    for (var j = 0; j < lines.length; j++) {
                        var line2 = lines[j].trim()
                        if (line2.indexOf("Speed:") === 0) {
                            var parts2 = line2.split(/\s+/)
                            if (parts2.length >= 3 && /^[0-9]+$/.test(parts2[1])) {
                                speed = parts2[1] + " " + parts2[2]
                                break
                            }
                        }
                    }
                }

                page.ramSpeed = speed || "Unknown"
            }
        }
    }

    // --- timers ------------------------------------------------------

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            page.updateClock()
            pCpuUsage.running = true
            pCpuTemp.running = true
            pGpuUsage.running = true
            pGpuTemp.running = true
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: pMemory.running = true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: pUptime.running = true
    }

    Component.onCompleted: {
        page.updateClock()
        pRamSpeed.running = true
        pCpuTemp.running = true
        pGpuTemp.running = true
    }

    // --- UI ------------------------------------------------------------

    Flickable {
        id: scrollArea

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function(event) {
                var delta = event.angleDelta.y
                if (delta !== 0) {
                    scrollArea.contentY = Math.max(
                        0,
                        Math.min(scrollArea.contentHeight - scrollArea.height, scrollArea.contentY - delta)
                    )
                }
                event.accepted = true
            }
        }

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.rightMargin

            spacing: 20

            Text {
                text: "SYSTEM"
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

            Row {
                width: parent.width
                height: 150
                spacing: 24

                Item {
                    width: 150
                    height: 150

                    Image {
                        anchors.centerIn: parent
                        source: page.homeDir ? "file://" + page.homeDir + "/.config/quickshell/pfp3.png" : ""
                        width: 140
                        height: 140
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    InfoRow { icon: "󰣇"; label: "OS"; value: page.os }
                    InfoRow { icon: "󱂬"; label: "WM"; value: page.wm }
                    InfoRow { icon: "󰔛"; label: "UPTIME"; value: page.uptime }
                }
            }

            HardwareGraph {
                icon: "󰍛"
                label: "CPU"
                valueText: page.cpu
                badges: [Math.round(page.cpuUsage) + "%", page.cpuTemp]
                history: page.cpuHistory
            }

            HardwareGraph {
                icon: "󰢮"
                label: "GPU"
                valueText: page.gpu
                badges: [Math.round(page.gpuUsage) + "%", page.gpuTemp]
                history: page.gpuHistory
            }

            HardwareGraph {
                icon: "󰘚"
                label: "RAM"
                valueText: page.memory
                badges: [page.ramSpeed, Math.round(page.memoryUsage) + "%"]
                history: page.memoryHistory
            }
        }
    }

    Text {
        id: clock

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: page.rightMargin

        text: page.currentTime
        color: Theme.text
        font.family: page.mono
        font.pixelSize: 18
        font.letterSpacing: 1
    }
}
