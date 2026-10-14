import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    // ── Config ────────────────────────────────────────────────
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int hardwareLabelSize: 12
    readonly property int hardwareTextSize: 12
    readonly property int rightMargin: 46
    readonly property int historyLength: 60

    // ── Paths ─────────────────────────────────────────────────
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string imgDir: homeDir + "/.config/quickshell/imgs"
    readonly property string defaultAvatar: imgDir + "/pfp3.png"
    readonly property string customAvatar: imgDir + "/pfp_custom"

    // ── State ─────────────────────────────────────────────────
    property string os: "..."
    property string wm: "Hyprland"
    property string uptime: "..."
    property string cpu: "Loading..."
    property string gpu: "Loading..."
    property string memory: "Loading..."
    property string ramSpeed: "Loading..."
    property string cpuTemp: "—"
    property string gpuTemp: "—"
    property string currentTime: ""

    property real cpuUsage: 0
    property real gpuUsage: 0
    property real memoryUsage: 0
    property var cpuHistory: []
    property var gpuHistory: []
    property var memoryHistory: []
    property var cpuPrev: null

    // ── Helpers ───────────────────────────────────────────────
    function poll(proc) {
        if (!proc.running) proc.running = true
    }

    function updateGraph(value, type) {
        value = parseFloat(value)
        if (isNaN(value)) return
        value = Math.max(0, Math.min(100, value))
        page[type + "Usage"] = value
        page[type + "History"] = page[type + "History"].concat([value]).slice(-historyLength)
    }

    function updateCpuFromStat(line) {
        var p = line.trim().split(/\s+/)
        if (p.length < 5) return
        // user nice system idle iowait irq softirq steal
        var v = []
        for (var i = 1; i <= 8; i++) v.push(Number(p[i] || 0))
        var idle = v[3] + v[4]
        var total = v.reduce(function(a, b) { return a + b }, 0)

        if (cpuPrev) {
            var totalDelta = total - cpuPrev.total
            if (totalDelta > 0)
                updateGraph(100 * (1 - (idle - cpuPrev.idle) / totalDelta), "cpu")
        }
        cpuPrev = { total: total, idle: idle }
    }

    function formatMemory(kb) {
        var gb = kb / 1024 / 1024
        return gb >= 1 ? gb.toFixed(1) + " GiB" : Math.round(kb / 1024) + " MiB"
    }

    function updateMemoryFromStat(text) {
        var total = Number((text.match(/^MemTotal:\s+(\d+)/m) || [])[1])
        var available = Number((text.match(/^MemAvailable:\s+(\d+)/m) || [])[1])
        if (!(total > 0)) return
        var used = total - available
        updateGraph(used / total * 100, "memory")
        memory = formatMemory(used) + " / " + formatMemory(total)
    }

    function formatUptime(text) {
        var s = Math.floor(parseFloat(text))
        if (isNaN(s)) return "—"
        var d = Math.floor(s / 86400)
        var h = Math.floor(s % 86400 / 3600)
        var m = Math.floor(s % 3600 / 60)
        return (d ? d + "d " : "") + (h || d ? h + "h " : "") + m + "m"
    }

    // Finds the first `sensors` line starting with one of the keys
    // (keys are tried in priority order) and returns "NN°C".
    function tempFromSensors(lines, keys) {
        for (var k = 0; k < keys.length; k++) {
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line.indexOf(keys[k]) !== 0) continue
                var m = line.match(/([+-]?\d+(?:\.\d+)?)\s*°C/)
                if (m) return Math.round(parseFloat(m[1])) + "°C"
            }
        }
        return "—"
    }

    function parseRamSpeed(text) {
        var m = text.match(/^\s*Configured Memory Speed:\s*(\d+)\s*(\S+)/m)
            || text.match(/^\s*Speed:\s*(\d+)\s*(\S+)/m)
        return m ? m[1] + " " + m[2] : "Unknown"
    }

    function updateClock() {
        currentTime = Qt.formatTime(new Date(), "HH:mm:ss")
    }

    function drawGraph(ctx, history) {
        var w = ctx.canvas.width
        var h = ctx.canvas.height
        ctx.clearRect(0, 0, w, h)
        if (history.length < 2) return

        var step = w / (history.length - 1)
        ctx.beginPath()
        for (var i = 0; i < history.length; i++) {
            var x = i * step
            var y = h - history[i] / 100 * h
            if (i) ctx.lineTo(x, y)
            else ctx.moveTo(x, y)
        }
        ctx.strokeStyle = Theme.accent
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()

        ctx.lineTo(w, h)
        ctx.lineTo(0, h)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
        ctx.fill()
    }

    // ── Avatar handling ───────────────────────────────────────
    function reloadAvatar() {
        // blank first so Qt re-reads the file even if the path is unchanged
        avatar.source = ""
        Qt.callLater(function() { avatar.source = "file://" + customAvatar })
    }

    function pickAvatar() {
        if (!pPicker.running) pPicker.running = true
    }

    function resetAvatar() {
        pReset.running = true
    }

    // ── Components ────────────────────────────────────────────
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

    // ── One-shot data sources ─────────────────────────────────
    FileView {
        path: "/etc/os-release"
        onLoaded: {
            var m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m)
            page.os = m ? m[1] : "Linux"
        }
    }
    FileView {
        path: "/proc/cpuinfo"
        onLoaded: {
            var m = text().match(/^model name\s*:\s*(.+)$/m)
            page.cpu = m ? m[1].trim() : "Unknown"
        }
    }
    Process {
        command: ["sh", "-c",
            "lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | sed -E 's/.*: //; s/ \\(rev.*\\)//' | head -1"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.gpu = text.trim() || "Unknown" }
    }
    Process {
        // needs a NOPASSWD sudoers rule for dmidecode
        command: ["sudo", "-n", "/usr/bin/dmidecode", "-t", "memory"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.ramSpeed = page.parseRamSpeed(text) }
    }

    // ── Polled data sources ───────────────────────────────────
    FileView {
        id: cpuStat
        path: "/proc/stat"
        onLoaded: page.updateCpuFromStat(text().split("\n")[0])
    }
    FileView {
        id: memInfo
        path: "/proc/meminfo"
        onLoaded: page.updateMemoryFromStat(text())
    }
    FileView {
        id: upInfo
        path: "/proc/uptime"
        onLoaded: page.uptime = page.formatUptime(text())
    }
    Process {
        // single `sensors` call serves both CPU and GPU temps
        id: pSensors
        command: ["sensors"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                page.cpuTemp = page.tempFromSensors(lines, ["Package id 0:", "Tctl:", "Tdie:"])
                page.gpuTemp = page.tempFromSensors(lines, ["GPU Temp:", "edge:", "junction:", "temp1:"])
            }
        }
    }
    Process {
        id: pGpuUsage
        command: ["sh", "-c", "nvtop -s 2>/dev/null | jq -r '.[0].gpu_util' | tr -d '%'"]
        stdout: StdioCollector { onStreamFinished: page.updateGraph(text, "gpu") }
    }

    // ── Avatar processes ──────────────────────────────────────
    Process {
        id: pPicker
        command: ["sh", "-c",
            "if command -v zenity >/dev/null; then " +
            "  zenity --file-selection --title='Choose a picture' " +
            "    --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg' 2>/dev/null; " +
            "elif command -v kdialog >/dev/null; then " +
            "  kdialog --getopenfilename \"$HOME\" 'image/*' 2>/dev/null; " +
            "elif command -v yad >/dev/null; then " +
            "  yad --file --title='Choose a picture' 2>/dev/null; " +
            "fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var src = text.trim()
                if (!src) return
                pCopy.command = ["sh", "-c",
                    "mkdir -p \"$(dirname \"$2\")\" && cp -f -- \"$1\" \"$2\"",
                    "sh", src, page.customAvatar]
                pCopy.running = true
            }
        }
    }
    Process {
        id: pCopy
        onExited: page.reloadAvatar()
    }
    Process {
        id: pReset
        command: ["rm", "-f", "--", page.customAvatar]
        onExited: page.reloadAvatar()
    }

    // ── Timers (paused while the page is hidden) ──────────────
    Timer {
        interval: 1000
        running: page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            page.updateClock()
            cpuStat.reload()
        }
    }
    Timer {
        interval: 2000
        running: page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            memInfo.reload()
            page.poll(pSensors)
            page.poll(pGpuUsage)
        }
    }
    Timer {
        interval: 10000
        running: page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: upInfo.reload()
    }

    Component.onCompleted: reloadAvatar()

    // ── UI ────────────────────────────────────────────────────
    Flickable {
        id: scrollArea
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function(event) {
                var maxY = Math.max(0, scrollArea.contentHeight - scrollArea.height)
                scrollArea.contentY = Math.max(0, Math.min(maxY, scrollArea.contentY - event.angleDelta.y))
                event.accepted = true
            }
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.rightMargin
            spacing: 14

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
                    id: avatarBox
                    width: 150
                    height: 150

                    AnimatedImage {
                        id: avatar
                        playing: page.visible                // pause animation while the page is hidden
                        anchors.centerIn: parent
                        width: 140
                        height: 140
                        sourceSize: Qt.size(280, 280)
                        fillMode: Image.PreserveAspectCrop   // fills the circle, any aspect ratio
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        cache: false
                        visible: false                        // drawn through the circular mask below

                        // no custom picture (or unreadable) -> default one
                        onStatusChanged: {
                            var def = "file://" + page.defaultAvatar
                            if (status === Image.Error && source.toString() !== def)
                                source = def
                        }
                    }

                    // circle mask
                    Item {
                        id: avatarMask
                        anchors.fill: avatar
                        layer.enabled: true
                        visible: false
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                        }
                    }

                    MultiEffect {
                        anchors.fill: avatar
                        source: avatar
                        maskEnabled: true
                        maskSource: avatarMask
                        opacity: Theme.bg.a
                    }

                    // Barely-visible change button: left click = pick, right click = reset
                    Text {
                        id: changeBtn
                        anchors { right: parent.right; bottom: parent.bottom }
                        text: "✎"
                        color: Theme.textDim
                        font.family: page.mono
                        font.pixelSize: 12
                        opacity: btnArea.containsMouse ? 0.9 : (hoverArea.containsMouse ? 0.35 : 0.12)
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) page.resetAvatar()
                                else page.pickAvatar()
                            }
                        }
                    }

                    // lets the button fade in when hovering the picture
                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        z: -1
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
                icon: "󰘚"
                label: "RAM"
                valueText: page.memory
                badges: [page.ramSpeed, Math.round(page.memoryUsage) + "%"]
                history: page.memoryHistory
            }
            HardwareGraph {
                icon: "󰢮"
                label: "GPU"
                valueText: page.gpu
                badges: [Math.round(page.gpuUsage) + "%", page.gpuTemp]
                history: page.gpuHistory
            }
        }
    }

    Text {
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