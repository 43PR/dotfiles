import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../"

Item {
    id: page

    // ------------------------------------------------------------
    // State
    // ------------------------------------------------------------

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    readonly property bool powered:
        adapter ? adapter.enabled : false

    readonly property bool scanning:
        adapter ? adapter.discovering : false

    property string statusText: ""
    property int contentMargin: 20

    function setStatus(text) {
        page.statusText = text
        statusTimer.restart()
    }

    Timer {
        id: statusTimer

        interval: 3000
        repeat: false

        onTriggered: page.statusText = ""
    }

    // ------------------------------------------------------------
    // Power
    // ------------------------------------------------------------

    function togglePower() {
        if (!page.adapter)
            return

        var on = !page.adapter.enabled

        // Stop discovery before powering Bluetooth off.
        if (!on)
            setDiscovering(false)

        page.adapter.enabled = on

        setStatus(
            on
                ? "Enabling Bluetooth..."
                : "Disabling Bluetooth..."
        )
    }

    // ------------------------------------------------------------
    // Discovery
    // ------------------------------------------------------------

    function setDiscovering(on) {
        if (!page.adapter || !page.adapter.enabled)
            return

        // Don't start discovery if the page isn't visible.
        if (on && !page.visible)
            return

        page.adapter.discovering = on
    }

    function toggleScan() {
        if (!page.adapter || !page.powered)
            return

        var newState = !page.scanning

        setDiscovering(newState)

        setStatus(
            newState
                ? "Scanning for devices..."
                : "Scan stopped"
        )
    }

    // ------------------------------------------------------------
    // Page visibility
    //
    // Discovery is active while the page is visible.
    // It is stopped when the page disappears.
    // ------------------------------------------------------------

    onVisibleChanged: {
        if (page.visible && page.powered) {
            setDiscovering(true)
        } else {
            setDiscovering(false)
        }
    }

    Component.onCompleted: {
        if (page.visible && page.powered)
            setDiscovering(true)
    }

    Component.onDestruction: {
        setDiscovering(false)
    }

    onPoweredChanged: {
        if (page.powered && page.visible)
            setDiscovering(true)
        else
            setDiscovering(false)
    }

    // ------------------------------------------------------------
    // Reset scan animation when discovery actually stops.
    // ------------------------------------------------------------

    onScanningChanged: {
        if (!page.scanning)
            scanIcon.rotation = 0
    }

    // ------------------------------------------------------------
    // Device actions
    //
    // IMPORTANT:
    //
    // We do NOT explicitly call dev.pair() anymore.
    //
    // bluetoothctl successfully handled the MINI using:
    //
    //     connect 41:42:98:02:9E:88
    //
    // BlueZ then reported:
    //
    //     Connected: yes
    //     Paired: yes
    //
    // Therefore we let BlueZ perform pairing as part of the
    // connection attempt.
    // ------------------------------------------------------------

    function deviceAction(dev) {
        if (!dev)
            return

        var deviceName =
            dev.name || dev.address || "device"

        // --------------------------------------------------------
        // Already connected -> disconnect
        // --------------------------------------------------------

        if (dev.state === BluetoothDeviceState.Connected) {
            setStatus(
                "Disconnecting " + deviceName + "..."
            )

            dev.disconnect()
            return
        }

        // --------------------------------------------------------
        // Already connecting
        // --------------------------------------------------------

        if (dev.state === BluetoothDeviceState.Connecting) {
            setStatus(
                "Connecting to " + deviceName + "..."
            )

            return
        }

        // --------------------------------------------------------
        // Currently disconnecting
        // --------------------------------------------------------

        if (dev.state === BluetoothDeviceState.Disconnecting) {
            setStatus(
                "Disconnecting " + deviceName + "..."
            )

            return
        }

        // --------------------------------------------------------
        // Stop discovery before connecting.
        //
        // This prevents:
        //
        //     Resource Not Ready
        //
        // from BlueZ when discovery and connection operations
        // overlap.
        // --------------------------------------------------------

        setDiscovering(false)

        // --------------------------------------------------------
        // Trust the device.
        //
        // This is safe for the user's explicitly selected device
        // and allows BlueZ to reconnect it later.
        // --------------------------------------------------------

        dev.trusted = true

        // --------------------------------------------------------
        // Connect.
        //
        // Do NOT call dev.pair() first.
        //
        // BlueZ will perform the required pairing/bonding as part
        // of the connection operation, matching the successful
        // bluetoothctl test.
        // --------------------------------------------------------

        setStatus(
            "Connecting to " + deviceName + "..."
        )

        dev.connect()
    }

    // ------------------------------------------------------------
    // Action label
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // UI
    // ------------------------------------------------------------

    Column {
        anchors.fill: parent

        anchors.leftMargin: page.contentMargin
        anchors.rightMargin: page.contentMargin
        anchors.topMargin: page.contentMargin
        anchors.bottomMargin: page.contentMargin

        spacing: 18

        // --------------------------------------------------------
        // Header
        // --------------------------------------------------------

        Row {
            width: parent.width
            height: 30

            spacing: 16

            Text {
                text: "BLUETOOTH"

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
                    parent.width - 250
                )

                height: 1
            }

            Text {
                id: scanIcon

                text: "󰑐"

                color: page.scanning
                    ? Theme.accent
                    : Theme.textDim

                opacity: page.powered
                    ? 1.0
                    : 0.4

                font.family: Theme.fontFamily
                font.pixelSize: 22

                anchors.verticalCenter: parent.verticalCenter

                // ------------------------------------------------
                // Continuous scan animation
                // ------------------------------------------------

                RotationAnimation on rotation {
                    running: page.scanning

                    loops: Animation.Infinite

                    from: 0
                    to: 360

                    duration: 1600
                }

                MouseArea {
                    anchors.fill: parent

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        page.toggleScan()
                    }
                }
            }

            // ----------------------------------------------------
            // Bluetooth power switch
            // ----------------------------------------------------

            Rectangle {
                width: 44
                height: 22

                radius: 11

                anchors.verticalCenter: parent.verticalCenter

                color: page.powered
                    ? Theme.accent
                    : Theme.trackBg

                border.color: Theme.border
                border.width: 1

                Rectangle {
                    width: 16
                    height: 16

                    radius: 8

                    color: Theme.text

                    anchors.verticalCenter:
                        parent.verticalCenter

                    x: page.powered
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

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        page.togglePower()
                    }
                }
            }
        }

        // --------------------------------------------------------
        // Divider
        // --------------------------------------------------------

        Rectangle {
            width: parent.width
            height: 1

            color: Theme.border
        }

        // --------------------------------------------------------
        // Status
        // --------------------------------------------------------

        Text {
            width: parent.width

            visible:
                page.statusText !== ""

            text: page.statusText

            color: Theme.accent

            font.family: Theme.fontFamily
            font.pixelSize: 10

            horizontalAlignment:
                Text.AlignHCenter
        }

        // --------------------------------------------------------
        // Device list
        // --------------------------------------------------------

        Flickable {
            id: flick

            width: parent.width
            height: parent.height - 70

            clip: true

            contentWidth: width
            contentHeight: list.height

            boundsBehavior:
                Flickable.StopAtBounds

            Column {
                id: list

                width: flick.width

                spacing: 6

                // ------------------------------------------------
                // No adapter
                // ------------------------------------------------

                Item {
                    width: list.width
                    height: 100

                    visible:
                        !page.adapter

                    Text {
                        anchors.centerIn:
                            parent

                        text:
                            "NO BLUETOOTH ADAPTER"

                        color:
                            Theme.textDim

                        font.family:
                            Theme.fontFamily

                        font.pixelSize: 11

                        font.letterSpacing: 1
                    }
                }

                // ------------------------------------------------
                // Bluetooth off
                // ------------------------------------------------

                Item {
                    width: list.width
                    height: 100

                    visible:
                        page.adapter
                        && !page.powered

                    Column {
                        anchors.centerIn:
                            parent

                        spacing: 8

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text: "\uf294"

                            color:
                                Theme.textDim

                            font.family:
                                Theme.iconFont

                            font.pixelSize: 24
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text:
                                "BLUETOOTH IS OFF"

                            color:
                                Theme.textDim

                            font.family:
                                Theme.fontFamily

                            font.pixelSize: 11

                            font.letterSpacing: 1
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text:
                                "Turn it on to see devices."

                            color:
                                Theme.textFaint

                            font.family:
                                Theme.fontFamily

                            font.pixelSize: 9
                        }
                    }
                }

                // ------------------------------------------------
                // Empty
                // ------------------------------------------------

                Item {
                    width: list.width
                    height: 100

                    visible:
                        page.powered
                        && repeater.count === 0

                    Column {
                        anchors.centerIn:
                            parent

                        spacing: 8

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text: "\uf1eb"

                            color:
                                Theme.textDim

                            font.family:
                                Theme.iconFont

                            font.pixelSize: 22
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text:
                                page.scanning
                                ? "SCANNING FOR DEVICES..."
                                : "NO DEVICES FOUND"

                            color:
                                Theme.textDim

                            font.family:
                                Theme.fontFamily

                            font.pixelSize: 11

                            font.letterSpacing: 1
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text:
                                page.scanning
                                ? "Keep this open while devices appear."
                                : "Tap the refresh icon to scan."

                            color:
                                Theme.textFaint

                            font.family:
                                Theme.fontFamily

                            font.pixelSize: 9
                        }
                    }
                }

                // ------------------------------------------------
                // Devices
                // ------------------------------------------------

                Repeater {
                    id: repeater

                    model:
                        page.adapter
                        ? page.adapter.devices
                        : null

                    delegate: Rectangle {
                        id: card

                        required property BluetoothDevice modelData

                        readonly property bool isConnected:
                            modelData.state
                            === BluetoothDeviceState.Connected

                        width:
                            list.width

                        height: 52

                        radius:
                            Theme.radius

                        color:
                            isConnected
                            ? Theme.alpha(
                                Theme.accent,
                                0.10
                              )
                            : Theme.alpha(
                                Theme.text,
                                0.025
                              )

                        border.width: 1

                        border.color:
                            isConnected
                            ? Theme.accent
                            : Theme.border

                        // ------------------------------------------------
                        // Device information
                        // ------------------------------------------------

                        Row {
                            anchors.left:
                                parent.left

                            anchors.leftMargin:
                                14

                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 10

                            Text {
                                text: "\uf294"

                                color:
                                    card.isConnected
                                    ? Theme.accent
                                    : Theme.textDim

                                font.family:
                                    Theme.iconFont

                                font.pixelSize: 15

                                anchors.verticalCenter:
                                    parent.verticalCenter
                            }

                            Column {
                                spacing: 2

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                Text {
                                    width:
                                        Math.max(
                                            100,
                                            list.width - 210
                                        )

                                    text:
                                        card.modelData.name
                                        || card.modelData.address

                                    elide:
                                        Text.ElideRight

                                    color:
                                        Theme.text

                                    font.family:
                                        Theme.fontFamily

                                    font.pixelSize: 12
                                }

                                Text {
                                    text: {
                                        var parts = [
                                            card.modelData.address
                                        ]

                                        if (card.isConnected) {
                                            parts.push(
                                                "connected"
                                            )
                                        } else if (
                                            card.modelData.paired
                                        ) {
                                            parts.push(
                                                "paired"
                                            )
                                        }

                                        if (
                                            card.modelData
                                            .batteryAvailable
                                        ) {
                                            parts.push(
                                                Math.round(
                                                    card.modelData
                                                    .battery * 100
                                                ) + "%"
                                            )
                                        }

                                        return parts.join(
                                            "  •  "
                                        )
                                    }

                                    color:
                                        card.isConnected
                                        ? Theme.accent
                                        : Theme.textFaint

                                    font.family:
                                        Theme.fontFamily

                                    font.pixelSize: 9
                                }
                            }
                        }

                        // ------------------------------------------------
                        // Action button
                        // ------------------------------------------------

                        Text {
                            anchors.right:
                                parent.right

                            anchors.rightMargin:
                                14

                            anchors.verticalCenter:
                                parent.verticalCenter

                            text:
                                page.actionLabel(
                                    card.modelData
                                )

                            color:
                                card.isConnected
                                ? Theme.danger
                                : Theme.accent

                            font.family:
                                Theme.fontFamily

                            font.pixelSize: 10

                            MouseArea {
                                anchors.fill:
                                    parent

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    page.deviceAction(
                                        card.modelData
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
