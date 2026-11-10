import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    // ── Config ────────────────────────────────────────────────
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int rightMargin: 10

    // ── State ─────────────────────────────────────────────────
    property bool wifiEnabled: true
    property var networks: []
    property var savedProfiles: []     // names of saved Wi-Fi profiles
    property string pendingSsid: ""
    property string statusMsg: ""      // last connect error (empty = none)
    readonly property bool connecting: pConnect.running

    // ── Debug (output: run `qs` in a terminal, or `qs log`) ────
    readonly property bool debug: true
    function dbg(msg) { if (debug) console.log("[net] " + msg) }

    // Ethernet status (device, connection state, active connection name)
    property var ethernet: ({
        device: "",
        state: "disconnected",
        connection: ""
    })

    // Nerd Font glyphs
    readonly property string icWifi: "\uf1eb"
    readonly property string icEth: "\uf6ff"
    readonly property string icRefresh: "\uf021"

    // ── Helpers ───────────────────────────────────────────────
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

    function networkSubtitle(net) {
        var parts = []
        if (net.connected) parts.push("connected")
        if (!net.secured) parts.push("open")
        else if (page.isSaved(net.ssid)) parts.push("saved")
        else parts.push("secured")
        return parts.join("  •  ")
    }

    // Hairline frame with accent corner brackets (same look as SystemPage)
    function drawFrame(ctx, active) {
        var w = ctx.canvas.width
        var h = ctx.canvas.height
        var L = 12
        ctx.clearRect(0, 0, w, h)

        ctx.globalAlpha = 0.35
        ctx.strokeStyle = Theme.border
        ctx.lineWidth = 1
        ctx.strokeRect(0.5, 0.5, w - 1, h - 1)

        ctx.globalAlpha = active ? 0.9 : 0.5
        ctx.strokeStyle = active ? Theme.accent : Theme.textFaint
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.moveTo(0.75, L); ctx.lineTo(0.75, 0.75); ctx.lineTo(L, 0.75)
        ctx.moveTo(w - L, 0.75); ctx.lineTo(w - 0.75, 0.75); ctx.lineTo(w - 0.75, L)
        ctx.moveTo(w - 0.75, h - L); ctx.lineTo(w - 0.75, h - 0.75); ctx.lineTo(w - L, h - 0.75)
        ctx.moveTo(L, h - 0.75); ctx.lineTo(0.75, h - 0.75); ctx.lineTo(0.75, h - L)
        ctx.stroke()
        ctx.globalAlpha = 1
    }

    // ── Components ────────────────────────────────────────────
    // Painted only on size / state change, never per frame.
    component Frame: Canvas {
        property bool active: true
        anchors.fill: parent
        onPaint: page.drawFrame(getContext("2d"), active)
        onActiveChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // Small text button: dim by default, accent on hover.
    component TextButton: Item {
        id: btn
        property string text: ""
        property color baseColor: Theme.textDim
        property color hoverColor: Theme.accent
        property bool clickable: true
        signal clicked()

        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight
        opacity: clickable ? 1.0 : 0.5

        Text {
            id: label
            text: btn.text
            color: area.containsMouse && btn.clickable ? btn.hoverColor : btn.baseColor
            font.family: page.mono
            font.pixelSize: Theme.textSizeSmall
            font.letterSpacing: 2
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            enabled: btn.clickable
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // Header layout:  LABEL (left)  ·  info (next to it)  ·  badges (right)
    component SectionHeader: Item {
        id: head
        property string label: ""
        property string info: ""
        property var badges: []
        width: parent.width
        height: 24

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: head.label
            color: Theme.textDim
            font.family: page.mono
            font.pixelSize: Theme.textSizeGroup
            font.letterSpacing: 2
        }

        Text {
            anchors.left: labelText.right
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            // never overlap the badges on the right
            width: Math.max(0, Math.min(implicitWidth,
                head.width - labelText.implicitWidth - badgeRow.implicitWidth - 40))
            text: head.info
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSizeGroup
            elide: Text.ElideRight
        }

        Row {
            id: badgeRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20

            Repeater {
                model: head.badges
                Text {
                    text: modelData
                    color: Theme.text
                    font.family: page.mono
                    font.pixelSize: Theme.textSizeGroup
                }
            }
        }
    }

    // Centered placeholder (Wi-Fi off / scanning)
    component EmptyState: Item {
        id: empty
        property string icon: ""
        property string title: ""
        width: parent.width
        height: 110

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: empty.icon
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: 24
                visible: empty.icon !== ""
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: empty.title
                color: Theme.textDim
                font.family: page.mono
                font.pixelSize: Theme.textSizeGroup
                font.letterSpacing: 2
            }
        }
    }

    // ── Ethernet status (device / state / connection name) ─────
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

    // Polled only while the page is visible.
    Timer {
        interval: 3000
        running: page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pEthernet.running) pEthernet.running = true
    }

    // ── Wi-Fi radio ────────────────────────────────────────────
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

    // ── Saved Wi-Fi profiles ───────────────────────────────────
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

    // ── Wi-Fi scan list ────────────────────────────────────────
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

    // ── Connect / disconnect ───────────────────────────────────
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

            // top bar: title, scrolls away with the content
            Text {
                text: "NETWORK"
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

            // ── Wi-Fi toggle + rescan ────────────────────────
            Item {
                width: parent.width
                height: 60

                Frame { active: page.wifiEnabled }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        id: wifiToggle
                        width: parent.width - rescanBtn.width - parent.spacing
                        height: parent.height
                        radius: Theme.radius
                        color: page.wifiEnabled
                            ? Theme.alpha(Theme.accent, 0.1)
                            : Theme.alpha(Theme.textFaint, 0.15)
                        border.width: 1
                        border.color: toggleMouse.containsMouse
                            ? Theme.accent
                            : (page.wifiEnabled ? Theme.accent : Theme.textFaint)

                        Text {
                            anchors.centerIn: parent
                            text: page.wifiEnabled ? "WI-FI ON" : "WI-FI OFF"
                            color: page.wifiEnabled ? Theme.accent : Theme.textFaint
                            font.family: page.mono
                            font.pixelSize: Theme.textSizeSmall
                            font.bold: true
                            font.letterSpacing: 2
                        }

                        MouseArea {
                            id: toggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.setWifiEnabled(!page.wifiEnabled)
                        }
                    }

                    Rectangle {
                        id: rescanBtn
                        width: parent.height
                        height: parent.height
                        radius: Theme.radius
                        color: "transparent"
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
            }

            // ── Connect status / error ───────────────────────
            Text {
                visible: page.connecting || page.statusMsg.length > 0
                width: parent.width
                wrapMode: Text.WordWrap
                text: page.connecting ? "CONNECTING…" : page.statusMsg
                color: page.connecting ? Theme.accent : Theme.danger
                font.family: page.mono
                font.pixelSize: Theme.textSizeSmall
                font.letterSpacing: 1
            }

            // ── Ethernet ─────────────────────────────────────
            // One row: Ethernet status on the left, Wi-Fi network count on the right
            SectionHeader {
                label: "ETHERNET"
                info: page.ethernet.state === "connected"
                    ? (page.ethernet.connection || page.ethernet.device)
                    : "Disconnected"
                badges: page.wifiEnabled && page.networks.length > 0
                    ? ["NETWORKS " + page.networks.length]
                    : []
            }

            // ── Wi-Fi networks ───────────────────────────────

            EmptyState {
                visible: !page.wifiEnabled
                icon: page.icWifi
                title: "WI-FI IS DISABLED"
            }

            EmptyState {
                visible: page.wifiEnabled && page.networks.length === 0
                icon: page.icWifi
                title: "SCANNING WI-FI NETWORKS..."
            }

            Column {
                id: list
                width: parent.width
                spacing: 10

                Repeater {
                    model: page.networks

                    delegate: Column {
                        id: entry

                        required property var modelData
                        width: list.width
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 64

                            Frame { active: entry.modelData.connected }

                            // right side: signal + action
                            Row {
                                id: actions
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 20

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: entry.modelData.signal + "%"
                                    color: Theme.text
                                    font.family: page.mono
                                    font.pixelSize: Theme.textSizeGroup
                                }

                                TextButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: entry.modelData.connected ? "DISCONNECT" : "CONNECT"
                                    baseColor: entry.modelData.connected ? Theme.danger : Theme.accent
                                    hoverColor: baseColor
                                    clickable: !page.connecting
                                    onClicked: page.onNetworkClicked(entry.modelData)
                                }
                            }

                            // left side: icon + name + subtitle
                            Text {
                                id: netIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.icWifi
                                color: entry.modelData.connected ? Theme.accent : Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.textSizeSection
                            }

                            Column {
                                anchors.left: netIcon.right
                                anchors.leftMargin: 14
                                anchors.right: actions.left
                                anchors.rightMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: entry.modelData.ssid
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.textSizeGroup
                                }

                                Text {
                                    width: parent.width
                                    text: page.networkSubtitle(entry.modelData)
                                    elide: Text.ElideRight
                                    color: entry.modelData.connected ? Theme.accent : Theme.textDim
                                    font.family: page.mono
                                    font.pixelSize: Theme.textSizeSmall
                                    font.letterSpacing: 1
                                }
                            }
                        }

                        // password prompt
                        Row {
                            visible: page.pendingSsid === entry.modelData.ssid
                            width: parent.width
                            height: 32
                            spacing: 20

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
                                    font.family: page.mono
                                    font.pixelSize: Theme.textSizeGroup
                                    echoMode: TextInput.Password
                                    focus: page.pendingSsid === entry.modelData.ssid

                                    Keys.onReturnPressed: page.connectSecured(entry.modelData.ssid, text)
                                    Keys.onEnterPressed: page.connectSecured(entry.modelData.ssid, text)
                                    Keys.onEscapePressed: page.pendingSsid = ""
                                }
                            }

                            TextButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CONNECT"
                                baseColor: Theme.accent
                                hoverColor: baseColor
                                clickable: !page.connecting
                                onClicked: page.connectSecured(entry.modelData.ssid, pwField.text)
                            }

                            TextButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CANCEL"
                                onClicked: page.pendingSsid = ""
                            }
                        }
                    }
                }
            }
        }
    }
}