import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import "../"

Item {
    id: page
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false
    property string statusText: ""
    property int contentMargin: 0
    property int contentRightMargin: 48
    property int contentTopMargin: 0
    property int contentBottomMargin: 0
    property var removingDevices: ({})
    FileView {
        id: removedDevicesFile
        path: Quickshell.dataDir + "/removed-bluetooth-devices.json"
        blockLoading: true
        onLoaded: page.loadRemovingDevices()
    }
    function loadRemovingDevices() {
        var text = removedDevicesFile.text()
        if (!text)
            return
        try {
            var saved = JSON.parse(text)
            if (saved && typeof saved === "object")
                page.removingDevices = saved
        } catch (error) {
            console.log("Failed to load removed Bluetooth devices:", error)
        }
    }
    function saveRemovingDevices() {
        removedDevicesFile.setText(JSON.stringify(page.removingDevices))
    }
    function setStatus(text) {
        page.statusText = text
        statusTimer.restart()
    }
    Timer {
        id: statusTimer
        interval: 3000
        onTriggered: page.statusText = ""
    }
    function setDiscovering(on) {
        if (!page.adapter || !page.powered || (on && !page.visible))
            return
        page.adapter.discovering = on
    }
    function togglePower() {
        if (!page.adapter)
            return
        var on = !page.adapter.enabled
        if (!on)
            setDiscovering(false)
        page.adapter.enabled = on
    }
    function deviceAction(dev) {
        if (!dev)
            return
        var name = dev.name || dev.address || "device"
        if (dev.state === BluetoothDeviceState.Connected) {
            setStatus("Disconnecting " + name + "...")
            dev.disconnect()
            return
        }
        if (dev.state === BluetoothDeviceState.Connecting) {
            setStatus("Connecting to " + name + "...")
            return
        }
        if (dev.state === BluetoothDeviceState.Disconnecting) {
            setStatus("Disconnecting " + name + "...")
            return
        }
        setDiscovering(false)
        dev.trusted = true
        setStatus("Connecting to " + name + "...")
        dev.connect()
    }
    function removeDevice(dev) {
        if (!dev)
            return
        var name = dev.name || dev.address || "device"
        var key = dev.address || name
        var updated = Object.assign({}, page.removingDevices)
        updated[key] = true
        page.removingDevices = updated
        saveRemovingDevices()
        if (dev.state === BluetoothDeviceState.Connected ||
            dev.state === BluetoothDeviceState.Connecting ||
            dev.state === BluetoothDeviceState.Disconnecting) {
            dev.disconnect()
        }
        dev.forget()
    }
    function actionLabel(dev) {
        if (!dev)
            return ""
        if (dev.pairing)
            return "PAIRING..."
        switch (dev.state) {
        case BluetoothDeviceState.Connected:
            return "DISCONNECT"
        case BluetoothDeviceState.Connecting:
            return "CONNECTING..."
        case BluetoothDeviceState.Disconnecting:
            return "DISCONNECTING..."
        default:
            return "CONNECT"
        }
    }
    onVisibleChanged: setDiscovering(page.visible && page.powered)
    onPoweredChanged: setDiscovering(page.visible && page.powered)
    Component.onCompleted: {
        if (page.visible && page.powered)
            setDiscovering(true)
    }
    Component.onDestruction: setDiscovering(false)
    Column {
        anchors.fill: parent
        anchors.leftMargin: page.contentMargin
        anchors.rightMargin: page.contentRightMargin
        anchors.topMargin: page.contentTopMargin
        anchors.bottomMargin: page.contentBottomMargin
        spacing: 8
        Row {
            id: header
            width: parent.width
            height: 36
            Text {
                text: "BLUETOOTH"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                id: bluetoothToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                height: 36
                radius: Theme.radius
                color: page.powered ? Theme.alpha(Theme.accent, 0.1) : Theme.alpha("#A0A0A0", 0.15)
                border.width: 1
                border.color: page.powered ? Theme.accent : "#A0A0A0"
                Text {
                    anchors.centerIn: parent
                    text: page.powered ? "ON" : "OFF"
                    color: page.powered ? Theme.accent : "#A0A0A0"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.togglePower()
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }
        Text {
            width: parent.width
            visible: page.statusText !== ""
            text: page.statusText
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
        Flickable {
            id: flick
            width: parent.width
            height: parent.height - 70
            clip: true
            contentWidth: width
            contentHeight: list.height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: list
                width: flick.width
                spacing: 6
                Item {
                    width: list.width
                    height: 100
                    visible: !page.adapter
                    Text {
                        anchors.centerIn: parent
                        text: "NO BLUETOOTH ADAPTER"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                }
                Item {
                    width: list.width
                    height: 100
                    visible: page.adapter && !page.powered
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf294"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BLUETOOTH IS OFF"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Turn it on to see devices."
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
                }
                Item {
                    width: list.width
                    height: 100
                    visible: page.powered && repeater.count === 0
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf1eb"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 22
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SCANNING FOR DEVICES..."
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Keep this open while devices appear."
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
                }
                Repeater {
                    id: repeater
                    model: page.adapter ? page.adapter.devices : null
                    delegate: Rectangle {
                        id: card
                        required property BluetoothDevice modelData
                        readonly property bool isConnected: modelData.state === BluetoothDeviceState.Connected
                        readonly property string deviceKey: modelData.address || modelData.name || ""
                        visible: !page.removingDevices[deviceKey]
                        width: list.width
                        height: visible ? 52 : 0
                        radius: Theme.radius
                        color: isConnected
                            ? Theme.alpha(Theme.accent, 0.10)
                            : Theme.alpha(Theme.text, 0.025)
                        border.width: 1
                        border.color: isConnected ? Theme.accent : Theme.border
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Text {
                                text: "\uf294"
                                color: card.isConnected ? Theme.accent : Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Column {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    width: Math.max(100, list.width - 210)
                                    text: card.modelData.name || card.modelData.address
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: {
                                        var parts = [card.modelData.address]
                                        if (card.isConnected)
                                            parts.push("connected")
                                        else if (card.modelData.paired)
                                            parts.push("paired")
                                        if (card.modelData.batteryAvailable)
                                            parts.push(Math.round(card.modelData.battery * 100) + "%")
                                        return parts.join("  •  ")
                                    }
                                    color: card.isConnected ? Theme.accent : Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                }
                            }
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            Text {
                                text: page.actionLabel(card.modelData)
                                color: card.isConnected ? Theme.danger : Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.deviceAction(card.modelData)
                                }
                            }
                            Item {
                                width: 28
                                height: 28
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf293"
                                    color: Theme.textDim
                                    font.family: Theme.iconFont
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    id: unpairMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: page.removeDevice(card.modelData)
                                }
                                Rectangle { 
                                    visible: unpairMouseArea.containsMouse 
                                    z: 100 
                                    x: -8 
                                    y: height + 6 
                                    width: tooltipText.width + 16 
                                    height: 24 
                                    radius: 4 
                                    color: "transparent" 
                                    Text { 
                                        id: tooltipText 
                                        anchors.centerIn: parent 
                                        text: "Unpair" 
                                        color: "white" 
                                        font.family: Theme.fontFamily 
                                        font.pixelSize: 10 
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
