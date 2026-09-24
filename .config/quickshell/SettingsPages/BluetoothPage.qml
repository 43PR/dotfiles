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

    // key -> timestamp (ms) the device was hidden after "unpair".
    // Entries are pruned automatically (see pruneRemovingDevices) so a
    // device reappears once it's actually gone or after a grace period,
    // instead of staying hidden forever.
    property var removingDevices: ({})
    property int removalHideDurationMs: 10000

    FileView {
        id: removedDevicesFile
        path: Quickshell.dataDir + "/removed-bluetooth-devices.json"
        blockLoading: true
        onLoaded: page.loadRemovingDevices()
    }

    function loadRemovingDevices() {
        var text = removedDevicesFile.text()
        if (!text) return
        try {
            var saved = JSON.parse(text)
            if (saved && typeof saved === "object")
                page.removingDevices = saved
        } catch (error) {
            console.log("Failed to load removed Bluetooth devices:", error)
        }
        // Drop anything stale/no-longer-present left over from a previous session.
        page.pruneRemovingDevices()
    }

    function saveRemovingDevices() {
        removedDevicesFile.setText(JSON.stringify(page.removingDevices))
    }

    // Clears removingDevices entries once the device is no longer known to
    // the adapter (forget actually completed) or after removalHideDurationMs
    // has elapsed, whichever comes first. This is what lets a device that
    // was unpaired show up again the next time it's discovered by a scan.
    function pruneRemovingDevices() {
        var now = Date.now()
        var present = ({})

        if (page.adapter) {
            var devs = page.adapter.devices
            for (var i = 0; i < devs.length; i++) {
                var d = devs[i]
                var key = d.address || d.name || ""
                if (key) present[key] = true
            }
        }

        var updated = {}
        var changed = false

        for (var k in page.removingDevices) {
            var ts = page.removingDevices[k]
            var stillPresent = !!present[k]
            var expired = (now - ts) > page.removalHideDurationMs

            if (stillPresent && !expired) {
                updated[k] = ts
            } else {
                changed = true
            }
        }

        if (changed) {
            page.removingDevices = updated
            page.saveRemovingDevices()
        }
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
        if (!page.adapter || !page.powered)
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
        if (!dev) return

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
        if (!dev) return

        var name = dev.name || dev.address || "device"
        var key = dev.address || name
        var updated = Object.assign({}, page.removingDevices)

        updated[key] = Date.now()
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
        if (!dev) return ""
        if (dev.pairing) return "PAIRING..."

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
    Component.onCompleted: if (page.visible && page.powered) setDiscovering(true)
    Component.onDestruction: setDiscovering(false)

    // Reacts directly to adapter signals rather than only to the derived
    // "powered" property, and prunes the unpair-hide list whenever the
    // device list changes (e.g. once a forgotten device is actually gone).
    Connections {
        target: page.adapter
        function onEnabledChanged() {
            page.setDiscovering(page.visible && page.powered)
        }
        function onDevicesChanged() {
            page.pruneRemovingDevices()
        }
    }

    // Safety net: if the very first StartDiscovery call was sent before
    // BlueZ finished powering the adapter on, "discovering" can silently
    // stay false. Keep nudging it back on until it actually takes, instead
    // of requiring the user to leave and reopen the page.
    Timer {
        id: discoveryRetryTimer
        interval: 1500
        repeat: true
        running: page.visible && page.powered
        onTriggered: {
            if (page.adapter && page.powered && !page.adapter.discovering)
                page.adapter.discovering = true
        }
    }

    // Periodic safety net for the unpair-hide list, independent of
    // devicesChanged firing (covers adapters/backends that don't emit it
    // promptly after forget()).
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: page.pruneRemovingDevices()
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.contentMargin
        anchors.rightMargin: page.contentRightMargin
        anchors.topMargin: page.contentTopMargin
        anchors.bottomMargin: page.contentBottomMargin
        spacing: 9

        Item {
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
                anchors.verticalCenterOffset: -6
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Rectangle {
            id: bluetoothToggle
            width: parent.width
            height: 36
            radius: Theme.radius
            color: page.powered
                ? Theme.alpha(Theme.accent, 0.1)
                : Theme.alpha("#A0A0A0", 0.15)
            border.width: 1
            border.color: page.powered ? Theme.accent : "#A0A0A0"

            Text {
                anchors.centerIn: parent
                text: page.powered ? "BLUETOOTH ON" : "BLUETOOTH OFF"
                color: page.powered ? Theme.accent : "#A0A0A0"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: page.togglePower()
            }
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
            height: parent.height - header.height - 1 - bluetoothToggle.height - 3 * 9
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
                    // Only bind to the device list while the adapter is powered on;
                    // otherwise the model is null so no device cards render,
                    // even for devices that remain paired/known while BT is off.
                    model: (page.adapter && page.powered) ? page.adapter.devices : null

                    delegate: Rectangle {
                        id: card

                        required property BluetoothDevice modelData

                        readonly property bool isConnected:
                            modelData.state === BluetoothDeviceState.Connected

                        readonly property string deviceKey:
                            modelData.address || modelData.name || ""

                        visible: !page.removingDevices[deviceKey]
                        width: list.width
                        height: visible ? 52 : 0
                        radius: Theme.radius

                        color: isConnected
                            ? Theme.alpha(Theme.accent, 0.10)
                            : Theme.alpha(Theme.text, 0.025)

                        border.width: 1
                        border.color: isConnected
                            ? Theme.accent
                            : Theme.border

                        Item {
                            id: actionArea
                            width: 120
                            height: card.height
                            x: 14
                            y: 0

                            Text {
                                id: actionText
                                x: 0
                                y: (parent.height - height) / 2

                                width: Math.min(
                                    implicitWidth,
                                    parent.width - removeButton.width - 12
                                )

                                text: page.actionLabel(card.modelData)

                                color: card.isConnected
                                    ? Theme.danger
                                    : Theme.accent

                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                verticalAlignment: Text.AlignVCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked:
                                        page.deviceAction(card.modelData)
                                }
                            }

                            Item {
                                id: removeButton
                                width: 28
                                height: 28
                                x: actionText.width + 12
                                y: (parent.height - height) / 2

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
                                    onClicked:
                                        page.removeDevice(card.modelData)
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

                        Item {
                            id: deviceInfo
                            x: actionArea.width + 28
                            y: 0
                            width: Math.max(
                                100,
                                card.width - actionArea.width - 42
                            )
                            height: card.height

                            Text {
                                id: deviceIcon
                                x: 0
                                y: (parent.height - height) / 2
                                width: 18
                                height: 18
                                text: "\uf294"
                                color: card.isConnected
                                    ? Theme.accent
                                    : Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignVCenter
                            }

                            Column {
                                id: deviceText
                                x: 28
                                y: (parent.height - height) / 2
                                width: parent.width - x
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: card.modelData.name ||
                                          card.modelData.address
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                Text {
                                    width: parent.width

                                    text: {
                                        var parts = [card.modelData.address]

                                        if (card.isConnected)
                                            parts.push("connected")
                                        else if (card.modelData.paired)
                                            parts.push("paired")

                                        if (card.modelData.batteryAvailable)
                                            parts.push(
                                                Math.round(
                                                    card.modelData.battery * 100
                                                ) + "%"
                                            )

                                        return parts.join("  •  ")
                                    }

                                    color: card.isConnected
                                        ? Theme.accent
                                        : Theme.textFaint

                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}