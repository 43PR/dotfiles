import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    property bool wifiEnabled: true
    property var networks: []
    property bool scanning: false
    property string pendingSsid: ""

    // ------------------------------------------------------------------
    // Global content margins
    // ------------------------------------------------------------------

    property int contentMargin: 0
    property int contentRightMargin: 48
    property int contentTopMargin: 0
    property int contentBottomMargin: 0

    // ------------------------------------------------------------------
    // Wi-Fi radio
    // ------------------------------------------------------------------

    Process {
        id: pRadioGet
        command: ["nmcli", "radio", "wifi"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                page.wifiEnabled = text.trim() === "enabled"
            }
        }
    }

    Process {
        id: pRadioSet

        stdout: StdioCollector {
            onStreamFinished: {
                pRadioGet.running = true

                if (page.wifiEnabled)
                    page.scan()
                else
                    page.networks = []
            }
        }
    }

    function setWifiEnabled(on) {
        pRadioSet.command = [
            "nmcli",
            "radio",
            "wifi",
            on ? "on" : "off"
        ]
        pRadioSet.running = true
    }

    // ------------------------------------------------------------------
    // Scan
    // ------------------------------------------------------------------

    Process {
        id: pRescan
        command: ["nmcli", "device", "wifi", "rescan"]

        stdout: StdioCollector {
            onStreamFinished: {
                rescanSettle.restart()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                rescanSettle.restart()
            }
        }
    }

    Timer {
        id: rescanSettle
        interval: 1200

        onTriggered: {
            page.scanning = false
            pList.running = true
        }
    }

    function scan() {
        if (!page.wifiEnabled)
            return

        page.scanning = true
        pRescan.running = true
    }

    // ------------------------------------------------------------------
    // Network list
    // ------------------------------------------------------------------

    Process {
        id: pList

        command: [
            "nmcli",
            "-t",
            "-f", "IN-USE,SSID,SIGNAL,SECURITY",
            "device",
            "wifi",
            "list"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.trim().split("\n")

                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i].trim()

                    if (!line)
                        continue

                    /*
                     * nmcli terse output uses ':' as the separator.
                     * A literal ':' inside an SSID is escaped as '\:'.
                     *
                     * Find the first three unescaped ':' characters.
                     */
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

                    if (fields.length < 4)
                        continue

                    var inUse = fields[0]
                    var ssid = fields[1]
                    var signal = parseInt(fields[2])
                    var security = fields[3]

                    if (!ssid)
                        continue

                    if (isNaN(signal))
                        signal = 0

                    out.push({
                        ssid: ssid,
                        signal: signal,
                        secured: security !== "" && security !== "--",
                        connected: inUse === "*"
                    })
                }

                page.networks = out
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                // Keep the UI alive even if NetworkManager emits stderr.
            }
        }
    }

    // ------------------------------------------------------------------
    // Connect / disconnect
    // ------------------------------------------------------------------

    Process {
        id: pConnect

        stdout: StdioCollector {
            onStreamFinished: {
                page.pendingSsid = ""
                pList.running = true
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                page.pendingSsid = ""
                pList.running = true
            }
        }
    }

    function connectOpen(ssid) {
        pConnect.command = [
            "nmcli",
            "device",
            "wifi",
            "connect",
            ssid
        ]
        pConnect.running = true
    }

    function connectSecured(ssid, password) {
        pConnect.command = [
            "nmcli",
            "device",
            "wifi",
            "connect",
            ssid,
            "password",
            password
        ]
        pConnect.running = true
    }

    function disconnect(ssid) {
        pConnect.command = [
            "nmcli",
            "connection",
            "down",
            "id",
            ssid
        ]
        pConnect.running = true
    }

    Component.onCompleted: {
        pRadioGet.running = true
        pList.running = true
    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------

    Column {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        anchors.leftMargin: page.contentMargin
        anchors.rightMargin: page.contentRightMargin
        anchors.topMargin: page.contentTopMargin
        anchors.bottomMargin: page.contentBottomMargin

        spacing: 12

        // ------------------------------------------------------------------
        // Header
        // ------------------------------------------------------------------

        Row {
            id: header

            width: parent.width
            height: 28
            spacing: 16

            Text {
                text: "NETWORK"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.bold: true
                font.letterSpacing: 3

                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: Math.max(
                    0,
                    parent.width
                    - 18
                    - 100
                    - 44
                    - 16
                )

                height: 1
            }

            Text {
                text: page.scanning ? "SCANNING..." : "󰑐"

                color: page.scanning
                       ? Theme.textDim
                       : Theme.accent

                font.family: Theme.fontFamily
                font.pixelSize: 22

                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent

                    enabled: !page.scanning &&
                             page.wifiEnabled

                    onClicked: page.scan()
                }
            }

            Rectangle {
                width: 44
                height: 22
                radius: 11

                anchors.verticalCenter: parent.verticalCenter

                color: page.wifiEnabled
                       ? Theme.accent
                       : Theme.trackBg

                border.color: Theme.border
                border.width: 1

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8

                    color: Theme.text

                    anchors.verticalCenter: parent.verticalCenter

                    x: page.wifiEnabled
                       ? parent.width - width - 3
                       : 3

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        page.setWifiEnabled(
                            !page.wifiEnabled
                        )
                    }
                }
            }
        }

        // ------------------------------------------------------------------
        // Divider
        // ------------------------------------------------------------------

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // ------------------------------------------------------------------
        // Content
        // ------------------------------------------------------------------

        Item {
            width: parent.width
            height: parent.height
                    - header.height
                    - 12
                    - 1

            Flickable {
                anchors.fill: parent
                clip: true

                contentWidth: width
                contentHeight: list.height

                Column {
                    id: list

                    width: parent.width
                    spacing: 6

                    // ------------------------------------------------------
                    // Wi-Fi disabled
                    // ------------------------------------------------------

                    Text {
                        visible: !page.wifiEnabled

                        width: parent.width

                        text: "Wi-Fi is disabled"

                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12

                        horizontalAlignment:
                            Text.AlignHCenter
                    }

                    // ------------------------------------------------------
                    // Scanning
                    // ------------------------------------------------------

                    Text {
                        visible: page.wifiEnabled &&
                                 page.scanning &&
                                 page.networks.length === 0

                        width: parent.width

                        text: "Scanning for networks..."

                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12

                        horizontalAlignment:
                            Text.AlignHCenter
                    }

                    // ------------------------------------------------------
                    // Nothing found
                    // ------------------------------------------------------

                    Text {
                        visible: page.wifiEnabled &&
                                 !page.scanning &&
                                 page.networks.length === 0

                        width: parent.width

                        text: "No Wi-Fi networks found"

                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12

                        horizontalAlignment:
                            Text.AlignHCenter
                    }

                    // ------------------------------------------------------
                    // Networks
                    // ------------------------------------------------------

                    Repeater {
                        model: page.networks

                        delegate: Column {
                            required property var modelData

                            width: list.width
                            spacing: 6

                            // --------------------------------------------------
                            // Network card
                            // --------------------------------------------------

                            Rectangle {
                                width: parent.width
                                height: 46
                                radius: Theme.radius

                                color: modelData.connected
                                       ? Theme.alpha(
                                             Theme.accent,
                                             0.10
                                         )
                                       : "#00000000"

                                border.width: 1

                                border.color:
                                    modelData.connected
                                    ? Theme.accent
                                    : Theme.border

                                // ----------------------------------------------
                                // Left side
                                // ----------------------------------------------

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14

                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    spacing: 9

                                    Text {
                                        text: modelData.signal > 66
                                              ? ""
                                              : modelData.signal > 33
                                                ? ""
                                                : ""

                                        color: modelData.connected
                                               ? Theme.accent
                                               : Theme.textDim

                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        visible:
                                            modelData.secured

                                        text: ""

                                        color: Theme.textFaint

                                        font.family:
                                            Theme.iconFont

                                        font.pixelSize: 10
                                    }

                                    Text {
                                        text: modelData.ssid

                                        color: Theme.text

                                        font.family:
                                            Theme.fontFamily

                                        font.pixelSize: 12

                                        elide:
                                            Text.ElideRight

                                        width: Math.min(
                                            implicitWidth,
                                            list.width - 170
                                        )
                                    }
                                }

                                // ----------------------------------------------
                                // Connect / disconnect
                                // ----------------------------------------------

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14

                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    text: modelData.connected
                                          ? "DISCONNECT"
                                          : "CONNECT"

                                    color: modelData.connected
                                           ? Theme.danger
                                           : Theme.accent

                                    font.family:
                                        Theme.fontFamily

                                    font.pixelSize: 10

                                    MouseArea {
                                        anchors.fill: parent

                                        onClicked: {
                                            if (
                                                modelData.connected
                                            ) {
                                                page.disconnect(
                                                    modelData.ssid
                                                )
                                            } else if (
                                                modelData.secured
                                            ) {
                                                page.pendingSsid =
                                                    page.pendingSsid ===
                                                    modelData.ssid
                                                    ? ""
                                                    : modelData.ssid
                                            } else {
                                                page.connectOpen(
                                                    modelData.ssid
                                                )
                                            }
                                        }
                                    }
                                }
                            }

                            // --------------------------------------------------
                            // Password row
                            // --------------------------------------------------

                            Row {
                                visible:
                                    page.pendingSsid ===
                                    modelData.ssid

                                width: parent.width
                                height: 32
                                spacing: 10

                                Rectangle {
                                    width: 220
                                    height: 32

                                    color: Theme.bgCard

                                    border.color:
                                        Theme.accent

                                    border.width: 1

                                    radius: Theme.radius

                                    TextInput {
                                        id: pwField

                                        anchors.fill: parent
                                        anchors.margins: 8

                                        color: Theme.text

                                        font.family:
                                            Theme.fontFamily

                                        font.pixelSize: 12

                                        echoMode:
                                            TextInput.Password

                                        focus:
                                            page.pendingSsid ===
                                            modelData.ssid

                                        Keys.onReturnPressed: {
                                            page.connectSecured(
                                                modelData.ssid,
                                                text
                                            )
                                        }
                                    }
                                }

                                Text {
                                    text: "CONNECT"

                                    color: Theme.accent2

                                    font.family:
                                        Theme.fontFamily

                                    font.pixelSize: 11

                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent

                                        onClicked: {
                                            page.connectSecured(
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
}
