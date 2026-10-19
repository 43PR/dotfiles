import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    // ── State ────────────────────────────────────────────────────
    property bool wifiEnabled: true
    property var networks: []
    property var savedProfiles: []     // names of saved Wi-Fi profiles
    property string pendingSsid: ""
    property string statusMsg: ""      // last connect error (empty = none)
    readonly property bool connecting: pConnect.running

    // ── Debug (output: run `qs` in a terminal, or `qs log`) ────────
    readonly property bool debug: true
    function dbg(msg) { if (debug) console.log("[net] " + msg) }

    // Ethernet status (device, connection state, active connection name)
    property var ethernet: ({
        device: "",
        state: "disconnected",
        connection: ""
    })

    // Fonts
    property string monoFont: "JetBrains Mono"

    // Speed stats (bytes / second)
    property real downSpeed: 0
    property real upSpeed: 0
    property real lastRx: -1
    property real lastTx: -1
    property real lastTs: 0

    property real marginLeft: 0
    property real marginRight: 10
    property real marginTop: 0
    property real marginBottom: 0

    // Nerd Font glyphs
    readonly property string icDown: "\uf019"
    readonly property string icUp: "\uf093"
    readonly property string icWifi: "\uf1eb"
    readonly property string icLock: "\uf023"
    readonly property string icEth: "\uf6ff"
    readonly property string icRefresh: "\uf021"

    function formatSpeed(bps) {
        if (bps < 1024) return bps.toFixed(0) + " B/s"
        if (bps < 1024 * 1024) return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024) return (bps / 1024 / 1024).toFixed(2) + " MB/s"
        return (bps / 1024 / 1024 / 1024).toFixed(2) + " GB/s"
    }

    // Split an nmcli "terse" (-t) line on unescaped ":" and unescape "\:" / "\\".
    function splitTerse(line) {
        var fields = []
        var current = ""
        var escaped = false

        for (var j = 0; j < line.length; ++j) {
            var ch = line[j]

            if (escaped) {
                current += ch
                escaped = false
            } else if (ch === "\\") {
                escaped = true
            } else if (ch === ":") {
                fields.push(current)
                current = ""
            } else {
                current += ch
            }
        }

        fields.push(current)
        return fields
    }

    function isSaved(ssid) {
        return page.savedProfiles.indexOf(ssid) !== -1
    }

    // ── Network speed (all real interfaces, wifi + ethernet) ───────
    FileView {
        id: netDev
        path: "/proc/net/dev"

        onLoaded: {
            var lines = text().split("\n")
            var rx = 0
            var tx = 0

            for (var i = 2; i < lines.length; ++i) {
                var line = lines[i].trim()
                if (!line) continue

                var idx = line.indexOf(":")
                if (idx < 0) continue

                var name = line.slice(0, idx).trim()
                if (name === "lo"
                    || name.indexOf("veth") === 0
                    || name.indexOf("docker") === 0
                    || name.indexOf("br-") === 0
                    || name.indexOf("virbr") === 0) continue

                var parts = line.slice(idx + 1).trim().split(/\s+/)
                rx += parseFloat(parts[0]) || 0
                tx += parseFloat(parts[8]) || 0
            }

            var now = Date.now()
            if (page.lastTs > 0) {
                var dt = (now - page.lastTs) / 1000
                if (dt > 0) {
                    page.downSpeed = Math.max(0, (rx - page.lastRx) / dt)
                    page.upSpeed = Math.max(0, (tx - page.lastTx) / dt)
                }
            }

            page.lastRx = rx
            page.lastTx = tx
            page.lastTs = now
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netDev.reload()
    }

    // ── Ethernet status (device / state / connection name) ─────────
    Process {
        id: pEthernet
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]

        stdout: StdioCollector {
            onStreamFinished: {
                var result = { device: "", state: "disconnected", connection: "" }
                var raw = text.trim()

                if (raw) {
                    var lines = raw.split("\n")

                    for (var i = 0; i < lines.length; ++i) {
                        var line = lines[i].trim()
                        if (!line) continue

                        var fields = line.split(":")
                        if (fields.length < 4) continue

                        if (fields[1] === "ethernet") {
                            result.device = fields[0]
                            result.state = fields[2]
                            result.connection = fields.slice(3).join(":")
                            break
                        }
                    }
                }

                page.ethernet = result
            }
        }

        stderr: StdioCollector {}
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pEthernet.running) pEthernet.running = true
    }

    // ── Wi-Fi radio ────────────────────────────────────────────────
    Process {
        id: pRadioGet
        command: ["nmcli", "radio", "wifi"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.wifiEnabled = text.trim() === "enabled"
        }
    }

    Process {
        id: pRadioSet
        stdout: StdioCollector {
            onStreamFinished: {
                pRadioGet.running = true
                if (page.wifiEnabled) pList.running = true
                else page.networks = []
            }
        }
    }

    function setWifiEnabled(on) {
        pRadioSet.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        pRadioSet.running = true
    }

    // ── Saved Wi-Fi profiles ───────────────────────────────────────
    // Saved profiles are matched by their real SSID, not their name: NetworkManager often names
    // them "Auto <ssid>", so comparing names misses them.
    Process {
        id: pSaved
        command: [
            "sh", "-c",
            "nmcli -t -f UUID,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1 | "
            + "while read -r u; do nmcli -g 802-11-wireless.ssid connection show uuid \"$u\"; done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")

                for (var i = 0; i < lines.length; ++i) {
                    var ssid = lines[i].trim().replace(/\\:/g, ":")
                    if (ssid) out.push(ssid)
                }

                page.savedProfiles = out
                page.dbg("saved wifi SSIDs = " + JSON.stringify(out))
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) page.dbg("pSaved stderr: " + text.trim())
        }
    }

    // ── Wi-Fi scan list ────────────────────────────────────────────
    Process {
        id: pList
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var seen = {}
                var raw = text.trim()

                if (raw) {
                    var lines = raw.split("\n")

                    for (var i = 0; i < lines.length; ++i) {
                        var line = lines[i].trim()
                        if (!line) continue

                        var fields = page.splitTerse(line)
                        if (fields.length < 4 || !fields[1]) continue

                        var signal = parseInt(fields[2])
                        if (isNaN(signal)) signal = 0

                        var entry = {
                            ssid: fields[1],
                            signal: signal,
                            secured: fields[3] !== "" && fields[3] !== "--",
                            connected: fields[0] === "*"
                        }

                        // Same SSID on several APs: keep one row (connected / strongest wins)
                        if (seen[entry.ssid] !== undefined) {
                            var prev = out[seen[entry.ssid]]
                            if (entry.connected || (!prev.connected && entry.signal > prev.signal))
                                out[seen[entry.ssid]] = entry
                            continue
                        }

                        seen[entry.ssid] = out.length
                        out.push(entry)
                    }
                }

                out.sort(function(a, b) {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1
                    return b.signal - a.signal
                })

                page.networks = out
                page.dbg("scan: " + out.length + " networks = " + JSON.stringify(
                    out.map(n => n.ssid + (n.secured ? " [sec]" : " [open]") + (n.connected ? " [*]" : "")
                        + (page.savedProfiles.indexOf(n.ssid) !== -1 ? " [saved]" : ""))))
            }
        }

        stderr: StdioCollector {}
    }

    Process {
        id: pRescan
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: pList.running = true
    }

    function rescan() {
        if (!page.wifiEnabled || pRescan.running) return
        pRescan.running = true
    }

    // ── Connect / disconnect ───────────────────────────────────────
    // mode: "open" | "saved" | "password" | "disconnect"
    Process {
        id: pConnect
        property string mode: ""
        property string ssid: ""

        onExited: exitCode => {
            page.dbg("pConnect exited: mode=" + mode + " ssid=" + ssid + " exitCode=" + exitCode
                + " statusMsg=" + JSON.stringify(page.statusMsg))
            // A saved profile that fails (missing / stale secrets): ask for the password
            // ourselves instead of letting a desktop secret agent pop up.
            if (exitCode !== 0 && (mode === "saved" || mode === "password"))
                page.pendingSsid = ssid
            else
                page.pendingSsid = ""

            pSaved.running = true
            pEthernet.running = true
            if (page.wifiEnabled) pList.running = true
        }

        stdout: StdioCollector {
            onStreamFinished: page.dbg("pConnect stdout: " + JSON.stringify(text.trim()))
        }

        stderr: StdioCollector {
            onStreamFinished: {
                page.dbg("pConnect stderr: " + JSON.stringify(text.trim()))
                var msg = text.trim()
                if (msg.indexOf("Secrets were required") !== -1)
                    msg = "Password rejected by the network (wrong password?). Try again."
                else
                    msg = msg.replace(/^Error:\s*/, "")
                page.statusMsg = msg
            }
        }
    }

    function startConnect(mode, ssid, command) {
        if (pConnect.running) { page.dbg("startConnect ignored, pConnect already running"); return }
        var shown = command.slice()
        if (mode === "password") shown[shown.length - 1] = "***"
        page.dbg("startConnect mode=" + mode + " ssid=" + JSON.stringify(ssid) + " cmd=" + JSON.stringify(shown))
        page.statusMsg = ""
        pConnect.mode = mode
        pConnect.ssid = ssid
        pConnect.command = command
        pConnect.running = true
    }

    // Open network
    function connectOpen(ssid) {
        startConnect("open", ssid, ["nmcli", "--wait", "20", "device", "wifi", "connect", ssid])
    }

    // Shell snippet: finds the UUID of the saved Wi-Fi profile whose SSID is "$1" (into $uuid).
    readonly property string uuidResolve:
        "uuid=$(nmcli -t -f UUID,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1 | "
        + "while read -r u; do s=$(nmcli -g 802-11-wireless.ssid connection show uuid \"$u\"); "
        + "if [ \"$s\" = \"$1\" ]; then echo \"$u\"; break; fi; done); "

    // Secured network that already has a saved profile.
    // The stored password is read and handed to nmcli via passwd-file, so no secret agent popup.
    // If no password is stored (exit 10) or the connect fails, onExited opens our own password box.
    function connectSaved(ssid) {
        startConnect("saved", ssid, [
            "sh", "-c",
            uuidResolve
            + "if [ -z \"$uuid\" ]; then echo 'No saved profile' >&2; exit 10; fi; "
            + "flags=$(nmcli -g 802-11-wireless-security.psk-flags connection show uuid \"$uuid\" 2>/dev/null); "
            + "km=$(nmcli -g 802-11-wireless-security.key-mgmt connection show uuid \"$uuid\" 2>/dev/null); "
            + "psk=$(nmcli -s -g 802-11-wireless-security.psk connection show uuid \"$uuid\" 2>/dev/null); "
            + "echo \"probe: uuid=$uuid key-mgmt=$km psk-flags=$flags psk-length=${#psk}\"; "
            + "if [ -z \"$psk\" ]; then echo 'No saved password, enter it below' >&2; exit 10; fi; "
            + "f=$(mktemp); chmod 600 \"$f\"; trap 'rm -f \"$f\"' EXIT; "
            + "printf '802-11-wireless-security.psk:%s\\n' \"$psk\" > \"$f\"; "
            + "nmcli --wait 20 connection up uuid \"$uuid\" passwd-file \"$f\"",
            "sh", ssid
        ])
    }

    // Shell snippet: deletes every saved Wi-Fi profile whose SSID is "$1", whatever its name.
    readonly property string deleteBySsid:
        "nmcli -t -f UUID,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1 | "
        + "while read -r u; do s=$(nmcli -g 802-11-wireless.ssid connection show uuid \"$u\"); "
        + "if [ \"$s\" = \"$1\" ]; then nmcli connection delete uuid \"$u\" >/dev/null 2>&1; fi; done; "

    // New secured network, or re-entering a password.
    // Old profiles for the SSID are deleted first (nmcli would reuse them and ignore the password).
    // If the connect fails, the profile it created is deleted too, so a wrong password isn't left
    // behind as a "saved" network.
    function connectSecured(ssid, password) {
        if (!password) return
        startConnect("password", ssid, [
            "sh", "-c",
            deleteBySsid
            + "nmcli --wait 20 device wifi connect \"$1\" password \"$2\"; rc=$?; "
            + "if [ $rc -ne 0 ]; then " + deleteBySsid + "fi; exit $rc",
            "sh", ssid, password
        ])
    }

    function disconnect() {
        startConnect("disconnect", "", [
            "sh", "-c",
            "dev=$(nmcli -t -f DEVICE,TYPE device | grep ':wifi$' | head -n1 | cut -d: -f1); "
            + "[ -n \"$dev\" ] && nmcli device disconnect \"$dev\""
        ])
    }

    function onNetworkClicked(net) {
        page.dbg("clicked ssid=" + JSON.stringify(net.ssid) + " connected=" + net.connected
            + " secured=" + net.secured + " saved=" + page.isSaved(net.ssid))
        if (net.connected) {
            page.disconnect()
        } else if (!net.secured) {
            page.connectOpen(net.ssid)
        } else if (page.isSaved(net.ssid)) {
            page.connectSaved(net.ssid)
        } else {
            page.pendingSsid = page.pendingSsid === net.ssid ? "" : net.ssid
        }
    }

    Component.onCompleted: {
        pRadioGet.running = true
        pSaved.running = true
        pList.running = true
        pEthernet.running = true
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft; anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop; anchors.bottomMargin: page.marginBottom
        spacing: 14
        Text {
            text: "NETWORK"; color: Theme.text
            font.family: page.monoFont; font.pixelSize: Theme.textSizeTitle; font.letterSpacing: 3
        }
        Rectangle { width: parent.width; height: 1; color: Theme.border }
        Column {
            id: statsRow
            width: parent.width
            spacing: 9

            Row {
                width: parent.width
                height: 36
                spacing: 9

                Rectangle {
                    id: wifiToggle
                    width: parent.width - rescanBtn.width - parent.spacing
                    height: 36
                    radius: Theme.radius
                    color: page.wifiEnabled
                        ? Theme.alpha(Theme.accent, 0.1)
                        : Theme.alpha(Theme.textFaint, 0.15)
                    border.width: 1
                    border.color: page.wifiEnabled ? Theme.accent : Theme.textFaint

                    Text {
                        anchors.centerIn: parent
                        text: page.wifiEnabled ? "WI-FI ON" : "WI-FI OFF"
                        color: page.wifiEnabled ? Theme.accent : Theme.textFaint
                        font.family: page.monoFont
                        font.pixelSize: Theme.textSizeSmall
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.setWifiEnabled(!page.wifiEnabled)
                    }
                }

                Rectangle {
                    id: rescanBtn
                    width: 36
                    height: 36
                    radius: Theme.radius
                    color: "#00000000"
                    border.width: 1
                    border.color: rescanMouse.containsMouse ? Theme.accent : Theme.border
                    opacity: page.wifiEnabled ? 1.0 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: page.icRefresh
                        color: pRescan.running ? Theme.accent : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.textSizeGroup
                    }

                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: page.wifiEnabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.rescan()
                    }
                }
            }

            Row {
                id: statsInner
                width: parent.width
                height: 40
                spacing: 9

                Repeater {
                    model: [
                        { icon: page.icDown, label: "", value: page.downSpeed, down: true },
                        { icon: page.icUp,   label: "",   value: page.upSpeed,   down: false }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: (statsInner.width - statsInner.spacing) / 2
                        height: statsInner.height
                        radius: Theme.radius
                        color: "#00000000"
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            id: statIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            color: modelData.down ? Theme.accent : Theme.accent2
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.textSizeSection
                        }

                        Text {
                            anchors.left: statIcon.right
                            anchors.leftMargin: 90
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.textDim
                            font.family: page.monoFont
                            font.pixelSize: Theme.textSizeGroup
                            font.letterSpacing: 1.5
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.formatSpeed(modelData.value)
                            color: Theme.text
                            font.family: page.monoFont
                            font.pixelSize: Theme.textSizeGroup
                            font.bold: true
                        }
                    }
                }
            }
        }

        // ── Ethernet status card (always shown) ─────────────────
        Rectangle {
            id: ethCard
            width: parent.width
            height: 46
            radius: Theme.radius
            color: page.ethernet.state === "connected"
                ? Theme.alpha(Theme.accent2, 0.10)
                : "#00000000"
            border.width: 1
            border.color: page.ethernet.state === "connected" ? Theme.accent2 : Theme.border

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                Text {
                    text: page.icEth
                    color: page.ethernet.state === "connected" ? Theme.accent2 : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.textSizeSection
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Ethernet"
                        color: Theme.text
                        font.family: page.monoFont
                        font.pixelSize: Theme.textSizeGroup
                    }

                    Text {
                        text: page.ethernet.state === "connected"
                            ? (page.ethernet.connection || page.ethernet.device)
                            : "Disconnected"
                        color: Theme.textDim
                        font.family: page.monoFont
                        font.pixelSize: Theme.textSizeSmall
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: page.ethernet.state === "connected" ? "CONNECTED" : "DISCONNECTED"
                color: page.ethernet.state === "connected" ? Theme.accent2 : Theme.textDim
                font.family: page.monoFont
                font.pixelSize: Theme.textSizeSmall
                font.letterSpacing: 1
            }
        }

        // ── Connect status / error ───────────────────────────────
        Text {
            visible: page.connecting || page.statusMsg.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: page.connecting ? "CONNECTING…" : page.statusMsg
            color: page.connecting ? Theme.accent : Theme.danger
            font.family: page.monoFont
            font.pixelSize: Theme.textSizeSmall
            font.letterSpacing: 1
        }

        // ── Wi-Fi network list ───────────────────────────────────
        Item {
            id: listContainer
            width: parent.width
            height: parent.height - y

            Flickable {
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: list.height

                Column {
                    id: list
                    width: parent.width
                    spacing: 6

                    Text {
                        visible: !page.wifiEnabled
                        width: parent.width
                        text: "Wi-Fi is disabled"
                        color: Theme.textDim
                        font.family: page.monoFont
                        font.pixelSize: Theme.textSizeGroup
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: page.wifiEnabled && !page.networks.length
                        width: parent.width
                        text: "Scanning Wi-Fi networks"
                        color: Theme.textDim
                        font.family: page.monoFont
                        font.pixelSize: Theme.textSizeGroup
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Repeater {
                        model: page.networks

                        delegate: Column {
                            required property var modelData
                            width: list.width
                            spacing: 6

                            Rectangle {
                                width: parent.width
                                height: 46
                                radius: Theme.radius
                                color: modelData.connected
                                    ? Theme.alpha(Theme.accent, 0.10)
                                    : "#00000000"
                                border.width: 1
                                border.color: modelData.connected ? Theme.accent : Theme.border

                                Text {
                                    id: connectBtn
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 84
                                    text: modelData.connected ? "DISCONNECT" : "CONNECT"
                                    color: modelData.connected ? Theme.danger : Theme.accent
                                    opacity: page.connecting ? 0.4 : 1.0
                                    font.family: page.monoFont
                                    font.pixelSize: Theme.textSizeSmall

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !page.connecting
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.onNetworkClicked(modelData)
                                    }
                                }

                                Row {
                                    anchors.left: connectBtn.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 9

                                    Text {
                                        text: page.icWifi
                                        color: modelData.connected ? Theme.accent : Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.textSizeSection
                                    }

                                    Text {
                                        visible: modelData.secured
                                        text: page.icLock
                                        color: Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.textSizeSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: Theme.text
                                        font.family: page.monoFont
                                        font.pixelSize: Theme.textSizeGroup
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, list.width - 190)
                                    }
                                }
                            }

                            Row {
                                visible: page.pendingSsid === modelData.ssid
                                width: parent.width
                                height: 32
                                spacing: 10

                                Rectangle {
                                    width: 220
                                    height: 32
                                    color: Theme.bgCard
                                    border.color: Theme.accent
                                    border.width: 1
                                    radius: Theme.radius

                                    TextInput {
                                        id: pwField
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: Theme.text
                                        font.family: page.monoFont
                                        font.pixelSize: Theme.textSizeGroup
                                        echoMode: TextInput.Password
                                        focus: page.pendingSsid === modelData.ssid

                                        Keys.onReturnPressed: page.connectSecured(modelData.ssid, text)
                                        Keys.onEnterPressed: page.connectSecured(modelData.ssid, text)
                                        Keys.onEscapePressed: page.pendingSsid = ""
                                    }
                                }

                                Text {
                                    text: "CONNECT"
                                    color: Theme.accent2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.textSizeBody
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !page.connecting
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.connectSecured(modelData.ssid, pwField.text)
                                    }
                                }

                                Text {
                                    text: "CANCEL"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.textSizeBody
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.pendingSsid = ""
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