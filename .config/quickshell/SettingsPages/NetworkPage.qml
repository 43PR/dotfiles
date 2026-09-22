import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page
    property bool wifiEnabled: true
    property var networks: []
    property string pendingSsid: ""
    property int contentMargin: 0
    property int contentRightMargin: 48
    property int contentTopMargin: 0
    property int contentBottomMargin: 0

    Process {
        id: pRadioGet
        command: ["nmcli", "radio", "wifi"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.wifiEnabled = text.trim() === "enabled" }
    }

    Process {
        id: pRadioSet
        stdout: StdioCollector {
            onStreamFinished: {
                pRadioGet.running = true
                page.wifiEnabled ? pList.running = true : page.networks = []
            }
        }
    }

    function setWifiEnabled(on) {
        pRadioSet.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        pRadioSet.running = true
    }

    Process {
        id: pList
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i].trim()
                    if (!line) continue
                    var fields = [], current = "", escaped = false
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
                    out.push({ssid: fields[1], signal: signal, secured: fields[3] !== "" && fields[3] !== "--", connected: fields[0] === "*"})
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
            pList.running = true
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
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.contentMargin
        anchors.rightMargin: page.contentRightMargin
        anchors.topMargin: page.contentTopMargin
        anchors.bottomMargin: page.contentBottomMargin
        spacing: 9

        Row {
            id: header
            width: parent.width
            height: 36

            Text {
                id: networkTitle
                text: "NETWORK"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -6
            }

            Rectangle {
                id: wifiToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                height: 36
                radius: Theme.radius
                color: page.wifiEnabled ? Theme.alpha(Theme.accent, 0.1) : Theme.alpha("#A0A0A0", 0.15)
                border.width: 1
                border.color: page.wifiEnabled ? Theme.accent : "#A0A0A0"

                Text {
                    anchors.centerIn: parent
                    text: page.wifiEnabled ? "ON" : "OFF"
                    color: page.wifiEnabled ? Theme.accent : "#A0A0A0"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.setWifiEnabled(!page.wifiEnabled)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Item {
            width: parent.width
            height: parent.height - header.height - 12 - 1

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
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: page.wifiEnabled && !page.networks.length
                        width: parent.width
                        text: "Scanning Wi-Fi networks"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
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
                                color: modelData.connected ? Theme.alpha(Theme.accent, 0.10) : "#00000000"
                                border.width: 1
                                border.color: modelData.connected ? Theme.accent : Theme.border

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 9

                                    Text {
                                        text: ""
                                        color: modelData.connected ? Theme.accent : Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        visible: modelData.secured
                                        text: ""
                                        color: Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, list.width - 170)
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.connected ? "DISCONNECT" : "CONNECT"
                                    color: modelData.connected ? Theme.danger : Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (modelData.connected) {
                                                page.disconnect(modelData.ssid)
                                            } else if (modelData.secured) {
                                                page.pendingSsid = page.pendingSsid === modelData.ssid ? "" : modelData.ssid
                                            } else {
                                                page.connectOpen(modelData.ssid)
                                            }
                                        }
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
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        echoMode: TextInput.Password
                                        focus: page.pendingSsid === modelData.ssid
                                        Keys.onReturnPressed: page.connectSecured(modelData.ssid, text)
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
                                        onClicked: page.connectSecured(modelData.ssid, pwField.text)
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
