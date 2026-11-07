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

    // ── Paths ─────────────────────────────────────────────────
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string imgDir: homeDir + "/.config/quickshell/imgs"
    readonly property string defaultAvatar: imgDir + "/pfp3.png"
    readonly property string customAvatar: imgDir + "/pfp_custom"

    // ── State ─────────────────────────────────────────────────
    // CPU / GPU / memory / network / temperatures come from the shared
    // SystemStats singleton. The bar reads the same one, so both always agree.
    property string os: "..."
    property string wm: "Hyprland"
    property string uptime: "..."
    property string currentTime: ""

    readonly property string memoryText: SystemStats.memTotalKb > 0
        ? formatMemory(SystemStats.memUsedKb) + " / " + formatMemory(SystemStats.memTotalKb)
        : "Loading..."

    // Network graph scale: peak of the visible history (at least 100 KB/s)
    function netScaleOf(down, up) {
        var peak = 0
        for (var i = 0; i < down.length; i++) if (down[i] > peak) peak = down[i]
        for (var j = 0; j < up.length; j++) if (up[j] > peak) peak = up[j]
        return Math.max(100 * 1024, peak * 1.15)
    }
    readonly property real netScale: netScaleOf(SystemStats.netDownHistory, SystemStats.netUpHistory)

    // ── Helpers ───────────────────────────────────────────────
    function formatMemory(kb) {
        var gb = kb / 1024 / 1024
        return gb >= 1 ? gb.toFixed(1) + " GiB" : Math.round(kb / 1024) + " MiB"
    }

    function formatRate(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GB/s"
        if (b >= 1048576)    return (b / 1048576).toFixed(1) + " MB/s"
        if (b >= 1024)       return Math.round(b / 1024) + " KB/s"
        return Math.round(b) + " B/s"
    }

    function formatBytes(b) {
        if (b >= 1099511627776) return (b / 1099511627776).toFixed(2) + " TiB"
        if (b >= 1073741824)    return (b / 1073741824).toFixed(1) + " GiB"
        if (b >= 1048576)       return (b / 1048576).toFixed(0) + " MiB"
        return Math.round(b / 1024) + " KiB"
    }

    function formatUptime(text) {
        var s = Math.floor(parseFloat(text))
        if (isNaN(s)) return "—"
        var d = Math.floor(s / 86400)
        var h = Math.floor(s % 86400 / 3600)
        var m = Math.floor(s % 3600 / 60)
        return (d ? d + "d " : "") + (h || d ? h + "h " : "") + m + "m"
    }

    function tempText(t) { return t >= 0 ? t + "°C" : "—" }

    function updateClock() {
        currentTime = Qt.formatTime(new Date(), "HH:mm:ss")
    }

    // Thin line with a soft fade toward the baseline and a live point.
    // The graph scrolls in from the right edge.
    function drawGraph(ctx, hist) {
        var w = ctx.canvas.width
        var h = ctx.canvas.height
        ctx.clearRect(0, 0, w, h)

        // baseline hairline
        ctx.globalAlpha = 0.5
        ctx.strokeStyle = Theme.border
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(0, h - 0.5)
        ctx.lineTo(w, h - 0.5)
        ctx.stroke()
        ctx.globalAlpha = 1

        // No samples yet -> flat line at 0, so the graph is never empty
        var n = hist.length
        if (n === 0) { hist = [0]; n = 1 }

        var a = Theme.accent
        var baseY = h - 1
        var span = h - 6
        // Horizontal zoom: the samples always stretch across the full width,
        // so the graph is complete from the first seconds instead of
        // slowly scrolling in from the right.
        var step = n > 1 ? w / (n - 1) : 0

        // Zoom: fit the vertical range to the visible data (min..max) instead
        // of a fixed 0..100, with a minimum window of 10 points and 15% padding
        var lo = hist[0], hi = hist[0]
        for (var q = 1; q < n; q++) {
            if (hist[q] < lo) lo = hist[q]
            if (hist[q] > hi) hi = hist[q]
        }
        if (hi - lo < 10) {
            var mid = (hi + lo) / 2
            lo = mid - 5
            hi = mid + 5
        }
        var pad = (hi - lo) * 0.15
        lo = Math.max(0, lo - pad)
        hi = Math.min(100, hi + pad)
        var range = Math.max(1, hi - lo)

        var xs = [], ys = []
        for (var i = 0; i < n; i++) {
            xs.push(i * step)
            ys.push(baseY - Math.max(0, Math.min(1, (hist[i] - lo) / range)) * span)
        }

        // Single sample -> flat line across the full width
        if (n === 1) {
            xs = [0, w]
            ys = [ys[0], ys[0]]
            n = 2
        }

        // soft fill
        var g = ctx.createLinearGradient(0, baseY, 0, baseY - span)
        g.addColorStop(0, Qt.rgba(a.r, a.g, a.b, 0.0))
        g.addColorStop(1, Qt.rgba(a.r, a.g, a.b, 0.20))
        ctx.beginPath()
        ctx.moveTo(xs[0], baseY)
        for (var j = 0; j < n; j++) ctx.lineTo(xs[j], ys[j])
        ctx.lineTo(xs[n - 1], baseY)
        ctx.closePath()
        ctx.fillStyle = g
        ctx.fill()

        // line
        ctx.beginPath()
        for (var k = 0; k < n; k++) {
            if (k) ctx.lineTo(xs[k], ys[k])
            else ctx.moveTo(xs[k], ys[k])
        }
        ctx.strokeStyle = a
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()

        // live point
        ctx.beginPath()
        ctx.arc(xs[n - 1], ys[n - 1], 2.5, 0, Math.PI * 2)
        ctx.fillStyle = a
        ctx.fill()
    }

    // One series for the mirrored network graph.
    // dir = -1 grows upward from baseY, +1 grows downward.
    function drawSeries(ctx, hist, maxV, baseY, span, dir, alpha) {
        var w = ctx.canvas.width
        var n = hist.length
        if (n === 0) { hist = [0]; n = 1 }

        var a = Theme.accent
        var step = n > 1 ? w / (n - 1) : 0
        var xs = [], ys = []
        for (var i = 0; i < n; i++) {
            xs.push(i * step)
            ys.push(baseY + dir * Math.min(1, hist[i] / maxV) * span)
        }
        if (n === 1) {
            xs = [0, w]
            ys = [ys[0], ys[0]]
            n = 2
        }

        var g = ctx.createLinearGradient(0, baseY, 0, baseY + dir * span)
        g.addColorStop(0, Qt.rgba(a.r, a.g, a.b, 0.0))
        g.addColorStop(1, Qt.rgba(a.r, a.g, a.b, 0.20 * alpha))
        ctx.beginPath()
        ctx.moveTo(xs[0], baseY)
        for (var j = 0; j < n; j++) ctx.lineTo(xs[j], ys[j])
        ctx.lineTo(xs[n - 1], baseY)
        ctx.closePath()
        ctx.fillStyle = g
        ctx.fill()

        ctx.beginPath()
        for (var k = 0; k < n; k++) {
            if (k) ctx.lineTo(xs[k], ys[k])
            else ctx.moveTo(xs[k], ys[k])
        }
        // same color handling as drawGraph (accent used as-is, alpha via globalAlpha)
        ctx.globalAlpha = alpha
        ctx.strokeStyle = a
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()

        ctx.beginPath()
        ctx.arc(xs[n - 1], ys[n - 1], 2.5, 0, Math.PI * 2)
        ctx.fillStyle = a
        ctx.fill()
        ctx.globalAlpha = 1
    }

    // Mirrored graph: download above the center line, upload below it.
    function drawMirror(ctx, down, up, maxV) {
        var w = ctx.canvas.width
        var h = ctx.canvas.height
        ctx.clearRect(0, 0, w, h)

        var mid = Math.round(h / 2)
        ctx.globalAlpha = 0.5
        ctx.strokeStyle = Theme.border
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(0, mid + 0.5)
        ctx.lineTo(w, mid + 0.5)
        ctx.stroke()
        ctx.globalAlpha = 1

        var span = h / 2 - 4
        drawSeries(ctx, down, maxV, mid, span, -1, 1.0)
        drawSeries(ctx, up, maxV, mid, span, 1, 1.0)
    }

    // Hairline frame with accent corner brackets
    function drawFrame(ctx) {
        var w = ctx.canvas.width
        var h = ctx.canvas.height
        var L = 12
        ctx.clearRect(0, 0, w, h)

        ctx.globalAlpha = 0.35
        ctx.strokeStyle = Theme.border
        ctx.lineWidth = 1
        ctx.strokeRect(0.5, 0.5, w - 1, h - 1)

        ctx.globalAlpha = 0.9
        ctx.strokeStyle = Theme.accent
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.moveTo(0.75, L); ctx.lineTo(0.75, 0.75); ctx.lineTo(L, 0.75)
        ctx.moveTo(w - L, 0.75); ctx.lineTo(w - 0.75, 0.75); ctx.lineTo(w - 0.75, L)
        ctx.moveTo(w - 0.75, h - L); ctx.lineTo(w - 0.75, h - 0.75); ctx.lineTo(w - L, h - 0.75)
        ctx.moveTo(L, h - 0.75); ctx.lineTo(0.75, h - 0.75); ctx.lineTo(0.75, h - L)
        ctx.stroke()
        ctx.globalAlpha = 1
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

    // Header layout:  LABEL (left)  ·  info (next to it)  ·  temp / usage (right)
    component HardwareGraph: Column {
        id: block
        property string label: ""
        property string valueText: ""
        property var badges: []
        property var history: []
        property var history2: []        // second series (network upload)
        property real maxValue: 100      // scale for the mirrored graph
        property bool dual: false        // true = mirrored down/up graph
        width: parent.width
        spacing: 10
        onHistoryChanged: graphCanvas.requestPaint()
        onHistory2Changed: graphCanvas.requestPaint()

        Item {
            id: header
            width: parent.width
            height: 24

            Text {
                id: labelText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: block.label
                color: Theme.textDim
                font.family: page.mono
                font.pixelSize: page.hardwareLabelSize
                font.letterSpacing: 2
            }

            Text {
                id: infoText
                anchors.left: labelText.right
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                // never overlap the usage on the right
                width: Math.max(0, Math.min(implicitWidth,
                    header.width - labelText.implicitWidth - badgeRow.implicitWidth - 40))
                horizontalAlignment: Text.AlignLeft
                text: block.valueText
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: page.hardwareTextSize
                elide: Text.ElideRight
            }

            Row {
                id: badgeRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 20

                Repeater {
                    model: block.badges
                    Text {
                        text: modelData
                        color: Theme.text
                        font.family: page.mono
                        font.pixelSize: Theme.textSizeGroup
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 60

            // hairline frame + accent corner brackets
            Canvas {
                anchors.fill: parent
                onPaint: page.drawFrame(getContext("2d"))
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }
            Canvas {
                id: graphCanvas
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                onPaint: {
                    if (block.dual) page.drawMirror(getContext("2d"), block.history, block.history2, block.maxValue)
                    else page.drawGraph(getContext("2d"), block.history)
                }
                onWidthChanged: requestPaint()
            }
        }
    }

    // ── Data sources ──────────────────────────────────────────
    // What this page shows is polled by SystemStats, only while the page is visible.
    StatsSubscription {
        active: page.visible
        fast: true      // live graphs: CPU / network every second
        keys: ["cpu", "mem", "gpu", "temp", "net", "info"]
    }

    FileView {
        path: "/etc/os-release"
        onLoaded: {
            var m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m)
            page.os = m ? m[1] : "Linux"
        }
    }
    FileView {
        id: upInfo
        path: "/proc/uptime"
        onLoaded: page.uptime = page.formatUptime(text())
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
        onTriggered: page.updateClock()
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

            // top bar: title (left) + clock (right), scrolls away with the content
            Item {
                width: parent.width
                height: titleText.implicitHeight

                Text {
                    id: titleText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SYSTEM"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSizeTitle
                    font.letterSpacing: 3
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.currentTime
                    color: Theme.text
                    font.family: page.mono
                    font.pixelSize: Theme.textSizeTitle
                    font.letterSpacing: 1
                }
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
                        opacity: 0.7
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
                label: "CPU"
                valueText: SystemStats.cpuName
                badges: [page.tempText(SystemStats.cpuTemp), Math.round(SystemStats.cpuUsage) + "%"]
                history: SystemStats.cpuHistory
            }
            HardwareGraph {
                label: "GPU"
                valueText: SystemStats.gpuName
                badges: [page.tempText(SystemStats.gpuTemp), SystemStats.gpuHasUsage ? Math.round(SystemStats.gpuUsage) + "%" : "N/A"]
                history: SystemStats.gpuHistory
            }
            HardwareGraph {
                label: "MEMORY"
                valueText: page.memoryText
                badges: [SystemStats.ramSpeed, Math.round(SystemStats.memPercent) + "%"]
                history: SystemStats.memHistory
            }
            HardwareGraph {
                label: "NETWORK"
                valueText: "↓ " + page.formatBytes(SystemStats.netTotalDown) + "   ↑ " + page.formatBytes(SystemStats.netTotalUp)
                badges: ["↓ " + page.formatRate(SystemStats.netDown), "↑ " + page.formatRate(SystemStats.netUp)]
                dual: true
                history: SystemStats.netDownHistory
                history2: SystemStats.netUpHistory
                maxValue: page.netScale
            }
        }
    }
}