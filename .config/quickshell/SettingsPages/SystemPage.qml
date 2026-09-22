import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    property string homeDir: ""
    property string hostname: "..."
    property string uptime: "..."
    property string os: "..."
    property string cpu: "Loading..."
    property string gpu: "Loading..."
    property string memory: "Loading..."
    property string ramSpeed: "Loading..."

    property real cpuUsage: 0
    property real gpuUsage: 0
    property real memoryUsage: 0

    property string cpuTemp: "—"

    property var cpuHistory: []
    property var gpuHistory: []
    property var memoryHistory: []

    property var cpuPrev: null

    property int hardwareLabelSize: 12
    property int hardwareTextSize: 12
    property string mono: "JetBrainsMono Nerd Font"
    property int rightMargin: 36

    property string currentTime: ""

    function updateGraph(value, type) {
        value = parseFloat(value)
        if (isNaN(value)) return

        value = Math.max(0, Math.min(100, value))

        var history

        if (type === "cpu")
            history = cpuHistory.slice()
        else if (type === "gpu")
            history = gpuHistory.slice()
        else
            history = memoryHistory.slice()

        history.push(value)

        if (history.length > 60)
            history.shift()

        if (type === "cpu") {
            cpuUsage = value
            cpuHistory = history
            cpuGraph.requestPaint()
        } else if (type === "gpu") {
            gpuUsage = value
            gpuHistory = history
            gpuGraph.requestPaint()
        } else {
            memoryUsage = value
            memoryHistory = history
            memoryGraph.requestPaint()
        }
    }

    function updateCpu(value) {
        updateGraph(value, "cpu")
    }

    function updateGpu(value) {
        updateGraph(value, "gpu")
    }

    function updateMemory(value) {
        updateGraph(value, "memory")
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
                updateCpu(100 * (1 - idleDelta / totalDelta))
        }

        cpuPrev = {
            total: total,
            idle: idleTime
        }
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
        var usage = (used / total) * 100

        updateMemory(usage)

        function formatMemory(kb) {
            var gb = kb / 1024 / 1024

            if (gb >= 1)
                return gb.toFixed(1) + " GiB"

            return Math.round(kb / 1024) + " MiB"
        }

        page.memory =
            formatMemory(used) +
            " / " +
            formatMemory(total)
    }

    function updateTemp(value) {
        value = parseFloat(value.trim())

        cpuTemp = isNaN(value)
            ? "—"
            : Math.round(value) + "°C"
    }

    function updateClock() {
        page.currentTime = Qt.formatTime(new Date(), "HH:mm:ss")
    }

    component HardwareLabel: Text {
        property string value: ""

        text: value
        color: Theme.accent
        font.family: page.mono
        font.pixelSize: page.hardwareLabelSize
        font.letterSpacing: 2
    }

    component HardwareValue: Text {
        property string value: ""

        text: value
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: page.hardwareTextSize
        elide: Text.ElideRight
        width: parent.width
    }

    Process {
        id: pHome

        command: ["sh", "-c", "printf '%s' \"$HOME\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.homeDir = text.trim()
        }
    }

    Process {
        id: pHost

        command: [
            "sh",
            "-c",
            "hostnamectl --static 2>/dev/null || cat /etc/hostname"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.hostname = text.trim()
        }
    }

    Process {
        id: pUptime

        command: ["uptime", "-p"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.uptime = text.trim()
        }
    }

    Process {
        id: pOs

        command: [
            "sh",
            "-c",
            "grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.os = text.trim()
        }
    }

    Process {
        id: pCpu

        command: [
            "sh",
            "-c",
            "awk -F: '/model name/ {gsub(/^ +/, \"\", $2); print $2; exit}' /proc/cpuinfo"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.cpu = text.trim()
        }
    }

    Process {
        id: pCpuUsage

        command: ["sh", "-c", "head -1 /proc/stat"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateCpuFromStat(text)
        }
    }

    Process {
        id: pCpuTemp

        command: [
            "sh",
            "-c",
            "sensors 2>/dev/null | awk '/Package id 0:|Tctl:|Tdie:/ {for(i=1;i<=NF;i++) if($i ~ /\\+?[0-9]+(\\.[0-9]+)?°C/) {gsub(/[+°C]/, \"\", $i); print $i; exit}}'"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateTemp(text)
        }
    }

    Process {
        id: pGpu

        command: [
            "sh",
            "-c",
            "lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | sed -E 's/.*: //; s/ \\(rev.*\\)//' | head -1"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                page.gpu = text.trim()

                if (!page.gpu)
                    page.gpu = "Unknown"
            }
        }
    }

    Process {
        id: pGpuUsage

        command: [
            "sh",
            "-c",
            "nvtop -s 2>/dev/null | jq -r '.[0].gpu_util' | tr -d '%'"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateGpu(text)
        }
    }

    Process {
        id: pMemory

        command: [
            "sh",
            "-c",
            "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.updateMemoryFromStat(text)
        }
    }

    Process {
        id: pRamSpeed

        command: [
            "sudo",
            "-n",
            "/usr/bin/dmidecode",
            "-t",
            "memory"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var speed = ""

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()

                    if (line.indexOf("Configured Memory Speed:") === 0) {
                        var parts = line.split(/\s+/)

                        if (parts.length >= 4 &&
                            /^[0-9]+$/.test(parts[3])) {
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

                            if (parts2.length >= 3 &&
                                /^[0-9]+$/.test(parts2[1])) {
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

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            page.updateClock()
            pCpuUsage.running = true
            pCpuTemp.running = true
            pGpuUsage.running = true
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: {
            pMemory.running = true
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true

        onTriggered: {
            pUptime.running = true
        }
    }

    Component.onCompleted: {
        page.updateClock()
        pRamSpeed.running = true
    }

    Flickable {
        id: scrollArea

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            id: wheelHandler

            onWheel: function(event) {
                var delta = event.angleDelta.y

                if (delta !== 0) {
                    scrollArea.contentY = Math.max(
                        0,
                        Math.min(
                            scrollArea.contentHeight - scrollArea.height,
                            scrollArea.contentY - delta
                        )
                    )
                }

                event.accepted = true
            }
        }

        Column {
            id: contentColumn

            anchors {
                left: parent.left
                right: parent.right
                rightMargin: page.rightMargin
            }

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
                        source: page.homeDir
                            ? "file://" + page.homeDir + "/.config/quickshell/pfp3.png"
                            : ""

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

                    Column {
                        spacing: 3

                        Text {
                            text: "󰒋  HOSTNAME"
                            color: Theme.accent
                            font.family: page.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }

                        Text {
                            text: page.hostname
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                    }

                    Column {
                        spacing: 3

                        Text {
                            text: "󰣇  OS"
                            color: Theme.accent
                            font.family: page.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }

                        Text {
                            text: page.os
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            width: 500
                        }
                    }

                    Column {
                        spacing: 3

                        Text {
                            text: "󰔛  UPTIME"
                            color: Theme.accent
                            font.family: page.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }

                        Text {
                            text: page.uptime
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    height: 24
                    spacing: 20

                    Text {
                        id: cpuHeader

                        text: "󰍛  CPU"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: page.hardwareLabelSize
                        font.letterSpacing: 2

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: cpuValue

                        text: page.cpu
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: page.hardwareTextSize
                        elide: Text.ElideLeft

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "USAGE  " + Math.round(page.cpuUsage) + "%"
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: 11

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "TEMP  " + page.cpuTemp
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: 11

                        anchors.verticalCenter: parent.verticalCenter
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
                            x: 0
                            y: parent.height * modelData
                            width: parent.width
                            height: 1
                            color: Theme.border
                            opacity: 0.35
                        }
                    }

                    Canvas {
                        id: cpuGraph

                        anchors.fill: parent
                        anchors.margins: 6

                        onPaint: page.drawGraph(
                            getContext("2d"),
                            page.cpuHistory
                        )
                    }

                    Text {
                        text: "100%"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: 8
                    }

                    Text {
                        text: "0%"
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: 8
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    height: 24
                    spacing: 20

                    Text {
                        id: gpuHeader

                        text: "󰢮  GPU"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: page.hardwareLabelSize
                        font.letterSpacing: 2

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: gpuValue

                        text: page.gpu
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: page.hardwareTextSize
                        elide: Text.ElideLeft

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "USAGE  " + Math.round(page.gpuUsage) + "%"
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: 11

                        anchors.verticalCenter: parent.verticalCenter
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
                        id: gpuGraph

                        anchors.fill: parent
                        anchors.margins: 6

                        onPaint: page.drawGraph(
                            getContext("2d"),
                            page.gpuHistory
                        )
                    }

                    Text {
                        text: "100%"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: 8
                    }

                    Text {
                        text: "0%"
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: 8
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    height: 24
                    spacing: 20

                    Text {
                        id: memoryHeader

                        text: "󰘚  RAM"
                        color: Theme.accent
                        font.family: page.mono
                        font.pixelSize: page.hardwareLabelSize
                        font.letterSpacing: 2

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "SPEED  " + page.ramSpeed
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: 11

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: memoryValue

                        text: page.memory
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: page.hardwareTextSize
                        elide: Text.ElideLeft

                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "USAGE  " + Math.round(page.memoryUsage) + "%"
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: 11

                        anchors.verticalCenter: parent.verticalCenter
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
                        id: memoryGraph

                        anchors.fill: parent
                        anchors.margins: 6

                        onPaint: page.drawGraph(
                            getContext("2d"),
                            page.memoryHistory
                        )
                    }

                    Text {
                        text: "100%"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: 8
                    }

                    Text {
                        text: "0%"
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 5

                        color: Theme.text
                        opacity: 0.35
                        font.family: page.mono
                        font.pixelSize: 8
                    }
                }
            }
        }
    }

    Text {
        id: clock

        anchors {
            top: parent.top
            right: parent.right
            rightMargin: page.rightMargin
        }

        text: page.currentTime
        color: Theme.text
        font.family: page.mono
        font.pixelSize: 18
        font.letterSpacing: 1
    }

    function drawGraph(ctx, history) {
        ctx.clearRect(
            0,
            0,
            ctx.canvas.width,
            ctx.canvas.height
        )

        var w = ctx.canvas.width
        var h = ctx.canvas.height

        if (history.length < 2)
            return

        var step = w / (history.length - 1)

        // Filled area
        ctx.beginPath()
        ctx.moveTo(0, h)

        for (var i = 0; i < history.length; i++) {
            ctx.lineTo(
                i * step,
                h - history[i] / 100 * h
            )
        }

        ctx.lineTo(w, h)
        ctx.closePath()

        ctx.fillStyle = Qt.rgba(
            Theme.accent.r,
            Theme.accent.g,
            Theme.accent.b,
            0.10
        )

        ctx.fill()

        // Line
        ctx.beginPath()

        for (var j = 0; j < history.length; j++) {
            var x = j * step
            var y = h - history[j] / 100 * h

            if (j)
                ctx.lineTo(x, y)
            else
                ctx.moveTo(x, y)
        }

        ctx.strokeStyle = Theme.accent
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()
    }
}
