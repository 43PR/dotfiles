import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    // ── State ────────────────────────────────────────────────────
    property bool wifiEnabled: true
    property var networks: []
    property string pendingSsid: ""

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

    property int contentMargin: 0
    property int contentRightMargin: 48
    property int contentTopMargin: 0
    property int contentBottomMargin: 0

    // Nerd Font glyphs
    readonly property string icDown: "\uf019"
    readonly property string icUp: "\uf093"
    readonly property string icWifi: "\uf1eb"
    readonly property string icLock: "\uf023"
    readonly property string icEth: "\uf6ff"

    function formatSpeed(bps) {
        if (bps < 1024) return bps.toFixed(0) + " B/s"
        if (bps < 1024 * 1024) return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024) return (bps / 1024 / 1024).toFixed(2) + " MB/s"
        return (bps / 1024 / 1024 / 1024).toFixed(2) + " GB/s"
    }

    // ── Network speed (all real interfaces, wifi + ethernet) ───────
    Process {
        id: pNet
        command: ["cat", "/proc/net/dev"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
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
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pNet.running) pNet.running = true
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

    // ── Wi-Fi radio ──────────────────────────────────────────────
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

    // ── Wi-Fi network list ───────────────────────────────────────
    Process {
        id: pList
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var raw = text.trim()

                if (raw) {
                    var lines = raw.split("\n")

                    for (var i = 0; i < lines.length; ++i) {
                        var line = lines[i].trim()
                        if (!line) continue

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
                            } else if (ch === ":" && fields.length < 3) {
                                fields.push(current)
                                current = ""
                            } else {
                                current += ch
                            }
                        }

                        fields.push(current)
                        if (fields.length < 4 || !fields[1]) continue

                        var signal = parseInt(fields[2])
                        if (isNaN(signal)) signal = 0

                        out.push({
                            ssid: fields[1],
                            signal: signal,
                            secured: fields[3] !== "" && fields[3] !== "--",
                            connected: fields[0] === "*"
                        })
                    }
                }

                page.networks = out
            }
        }

        stderr: StdioCollector {}
    }

    Process {
        id: pConnect

        function refresh() {
            page.pendingSsid = ""
            pEthernet.running = true
            if (page.wifiEnabled) pList.running = true
        }

        stdout: StdioCollector { onStreamFinished: pConnect.refresh() }
        stderr: StdioCollector { onStreamFinished: pConnect.refresh() }
    }

    function connectOpen(ssid) {
        pConnect.command = ["nmcli", "device", "wifi", "connect", ssid]
        pConnect.running = true
    }

    function connectSecured(ssid, password) {
        pConnect.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        pConnect.running = true
    }

    function disconnect(ssid) {
        pConnect.command = ["nmcli", "connection", "down", "id", ssid]
        pConnect.running = true
    }

    Component.onCompleted: {
        pRadioGet.running = true
        pList.running = true
        pEthernet.running = true
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.contentMargin
        anchors.rightMargin: page.contentRightMargin
        anchors.topMargin: page.contentTopMargin
        anchors.bottomMargin: page.contentBottomMargin
        spacing: 9

        // ── Header ───────────────────────────────────────────────
        Item {
            id: header
            width: parent.width
            height: 36

            Text {
                text: "NETWORK"
                color: Theme.text
                font.family: page.monoFont
                font.pixelSize: 19
                font.letterSpacing: 3
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -6
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // ── Wi-Fi toggle + speed stats ──────────────────────────
        Column {
            id: statsRow
            width: parent.width
            spacing: 9

            Rectangle {
                id: wifiToggle
                width: parent.width
                height: 36
                radius: Theme.radius
                color: page.wifiEnabled
                    ? Theme.alpha(Theme.accent, 0.1)
                    : Theme.alpha("#A0A0A0", 0.15)
                border.width: 1
                border.color: page.wifiEnabled ? Theme.accent : "#A0A0A0"

                Text {
                    anchors.centerIn: parent
                    text: page.wifiEnabled ? "WI-FI ON" : "WI-FI OFF"
                    color: page.wifiEnabled ? Theme.accent : "#A0A0A0"
                    font.family: page.monoFont
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.setWifiEnabled(!page.wifiEnabled)
                }
            }

            Row {
                id: statsInner
                width: parent.width
                height: 40
                spacing: 9

                Repeater {
                    model: [
                        { icon: page.icDown, label: "DOWNLOAD", value: page.downSpeed, down: true },
                        { icon: page.icUp,   label: "UPLOAD",   value: page.upSpeed,   down: false }
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
                            font.pixelSize: 14
                        }

                        Text {
                            anchors.left: statIcon.right
                            anchors.leftMargin: 90
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.textDim
                            font.family: page.monoFont
                            font.pixelSize: 12
                            font.letterSpacing: 1.5
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.formatSpeed(modelData.value)
                            color: Theme.text
                            font.family: page.monoFont
                            font.pixelSize: 12
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
                    font.pixelSize: 15
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Ethernet"
                        color: Theme.text
                        font.family: page.monoFont
                        font.pixelSize: 12
                    }

                    Text {
                        text: page.ethernet.state === "connected"
                            ? (page.ethernet.connection || page.ethernet.device)
                            : "Disconnected"
                        color: Theme.textDim
                        font.family: page.monoFont
                        font.pixelSize: 10
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
                font.pixelSize: 10
                font.letterSpacing: 1
            }
        }

        // ── Wi-Fi network list ───────────────────────────────────
        Item {
            id: listContainer
            width: parent.width
            height: parent.height - header.height - 1 - statsRow.height - ethCard.height - 4 * 9

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
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: page.wifiEnabled && !page.networks.length
                        width: parent.width
                        text: "Scanning Wi-Fi networks"
                        color: Theme.textDim
                        font.family: page.monoFont
                        font.pixelSize: 12
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
                                    font.family: page.monoFont
                                    font.pixelSize: 10

                                    MouseArea {
                                        anchors.fill: parent

                                        onClicked: {
                                            if (modelData.connected) {
                                                page.disconnect(modelData.ssid)
                                            } else if (modelData.secured) {
                                                page.pendingSsid = page.pendingSsid === modelData.ssid
                                                    ? ""
                                                    : modelData.ssid
                                            } else {
                                                page.connectOpen(modelData.ssid)
                                            }
                                        }
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
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        visible: modelData.secured
                                        text: page.icLock
                                        color: Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: Theme.text
                                        font.family: page.monoFont
                                        font.pixelSize: 12
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
                                        font.pixelSize: 12
                                        echoMode: TextInput.Password
                                        focus: page.pendingSsid === modelData.ssid

                                        Keys.onReturnPressed: page.connectSecured(
                                            modelData.ssid,
                                            text
                                        )
                                    }
                                }

                                Text {
                                    text: "CONNECT"
                                    color: Theme.accent2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: page.connectSecured(
                                            modelData.ssid,
                                            pwField.text
                                        )
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
