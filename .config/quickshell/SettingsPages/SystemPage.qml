import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    // ── Config ────────────────────────────────────────────────
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int hardwareLabelSize: Theme.textSizeGroup
    readonly property int hardwareTextSize: Theme.textSizeGroup
    readonly property int rightMargin: 10
    readonly property int historyLength: 60

    // ── Paths ─────────────────────────────────────────────────
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string imgDir: homeDir + "/.config/quickshell/imgs"
    readonly property string defaultAvatar: imgDir + "/pfp3.png"
    readonly property string customAvatar: imgDir + "/pfp_custom"

    // ── GPU probe (vendor-agnostic, no root needed) ───────────
    // Prints "<usage%> <tempC>"; a field is "-" when unavailable.
    // Order of attempts for usage:
    //   1. NVIDIA  : nvidia-smi
    //   2. AMD     : sysfs gpu_busy_percent (largest-VRAM card wins)
    //   3. Intel   : intel_gpu_top (only if permitted, 3s timeout)
    //   4. Intel/other fallback: GPU clock estimate (act_freq / max_freq),
    //      works unprivileged on i915 and xe drivers
    // Temperature: nvidia-smi, else any DRM card hwmon temp, else `sensors`.
    readonly property string gpuProbeScript: `
u=-; t=-
isnum() { case "$1" in ''|*[!0-9.]*) return 1;; *) return 0;; esac; }

# 1. NVIDIA
if command -v nvidia-smi >/dev/null 2>&1; then
  o=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
  if [ -n "$o" ]; then
    a=$(echo "$o" | cut -d, -f1 | tr -d ' ')
    b=$(echo "$o" | cut -d, -f2 | tr -d ' ')
    isnum "$a" && u="$a"
    isnum "$b" && t="$b"
  fi
fi

# 2. AMD (amdgpu sysfs)
if [ "$u" = "-" ]; then
  best=""; bestmem=-1
  for d in /sys/class/drm/card[0-9]*/device; do
    [ -r "$d/gpu_busy_percent" ] || continue
    m=$(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0)
    isnum "$m" || m=0
    if [ "$m" -gt "$bestmem" ]; then best="$d"; bestmem="$m"; fi
  done
  if [ -n "$best" ]; then
    a=$(cat "$best/gpu_busy_percent" 2>/dev/null)
    isnum "$a" && u="$a"
    if [ "$t" = "-" ]; then
      for h in "$best"/hwmon/hwmon*/temp1_input; do
        if [ -r "$h" ]; then t=$(( $(cat "$h") / 1000 )); break; fi
      done
    fi
  fi
fi

# 3. Intel via intel_gpu_top (needs CAP_PERFMON / root; silently skipped otherwise)
if [ "$u" = "-" ] && command -v intel_gpu_top >/dev/null 2>&1; then
  v=$(timeout 3 intel_gpu_top -J -s 500 -n 2 2>/dev/null | grep -o '"busy": *[0-9.]*' | grep -o '[0-9.]*$' | sort -n | tail -n1)
  isnum "$v" && u="$v"
fi

# 4. Unprivileged fallback: GPU clock as a load estimate (i915 / xe)
if [ "$u" = "-" ]; then
  for c in /sys/class/drm/card[0-9]*; do
    [ -d "$c" ] || continue
    for pair in \
      "$c/gt/gt0/rps_act_freq_mhz:$c/gt/gt0/rps_max_freq_mhz" \
      "$c/gt/gt0/rps_cur_freq_mhz:$c/gt/gt0/rps_max_freq_mhz" \
      "$c/gt_act_freq_mhz:$c/gt_max_freq_mhz" \
      "$c/gt_cur_freq_mhz:$c/gt_max_freq_mhz" \
      "$c/device/tile0/gt0/freq0/act_freq:$c/device/tile0/gt0/freq0/max_freq"; do
      f1=\${pair%%:*}; f2=\${pair#*:}
      [ -r "$f1" ] && [ -r "$f2" ] || continue
      cur=$(cat "$f1" 2>/dev/null); max=$(cat "$f2" 2>/dev/null)
      if isnum "$cur" && isnum "$max" && [ "$max" -gt 0 ]; then
        u=$(( cur * 100 / max )); [ "$u" -gt 100 ] && u=100
        break 2
      fi
    done
  done
fi

# Temperature fallback: any DRM card hwmon (i915 / xe / nouveau / amdgpu)
if [ "$t" = "-" ]; then
  for h in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/temp1_input; do
    if [ -r "$h" ]; then
      r=$(cat "$h" 2>/dev/null)
      if isnum "$r"; then t=$(( r / 1000 )); break; fi
    fi
  done
fi

echo "$u $t"
`

    // ── State ─────────────────────────────────────────────────
    property string os: "..."
    property string wm: "Hyprland"
    property string uptime: "..."
    property string cpu: "Loading..."
    property string gpu: "Loading..."
    property string memory: "Loading..."
    property string ramSpeed: "Loading..."
    property string cpuTemp: "—"
    property string gpuTempProbe: "—"      // from nvidia-smi / sysfs hwmon
    property string gpuTempSensors: "—"    // fallback from `sensors`
    readonly property string gpuTemp: gpuTempProbe !== "—" ? gpuTempProbe : gpuTempSensors
    property string currentTime: ""

    property real cpuUsage: 0
    property real gpuUsage: 0
    property bool gpuHasUsage: false
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

    function updateGpuFromProbe(text) {
        var p = text.trim().split(/\s+/)
        var u = parseFloat(p[0])
        var t = parseFloat(p[1])

        gpuHasUsage = !isNaN(u)
        if (gpuHasUsage) updateGraph(u, "gpu")

        gpuTempProbe = isNaN(t) ? "—" : Math.round(t) + "°C"
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
            font.pixelSize: Theme.textSizeSmall
            font.letterSpacing: 2
        }
        Text {
            text: value
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeGroup
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
                    font.pixelSize: Theme.textSizeGroup
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
                font.pixelSize: Theme.textSizeSmall
            }
            Text {
                text: "0%"
                anchors { bottom: parent.bottom; right: parent.right; margins: 5 }
                color: Theme.text
                opacity: 0.35
                font.family: page.mono
                font.pixelSize: Theme.textSizeSmall
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
        // GPU name: prefer a discrete NVIDIA/AMD/Arc card over a plain iGPU
        command: ["sh", "-c",
            "l=$(lspci 2>/dev/null | grep -Ei 'VGA|3D|Display'); " +
            "g=$(echo \"$l\" | grep -Ei 'NVIDIA|AMD|ATI|Arc' | head -n1); " +
            "[ -n \"$g\" ] || g=$(echo \"$l\" | head -n1); " +
            "echo \"$g\" | sed -E 's/.*: //; s/ \\(rev.*\\)//'"]
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
        // single `sensors` call serves CPU temp and the GPU temp fallback
        id: pSensors
        command: ["sensors"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                page.cpuTemp = page.tempFromSensors(lines, ["Package id 0:", "Tctl:", "Tdie:"])
                page.gpuTempSensors = page.tempFromSensors(lines, ["GPU Temp:", "edge:", "junction:"])
            }
        }
    }
    Process {
        id: pGpu
        command: ["sh", "-c", page.gpuProbeScript]
        stdout: StdioCollector { onStreamFinished: page.updateGpuFromProbe(text) }
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
            page.poll(pGpu)
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
                font.pixelSize: Theme.textSizeTitle
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
                        font.pixelSize: Theme.textSizeGroup
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
                badges: [page.gpuHasUsage ? Math.round(page.gpuUsage) + "%" : "N/A", page.gpuTemp]
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
        font.pixelSize: Theme.textSizeTitle
        font.letterSpacing: 1
    }
}