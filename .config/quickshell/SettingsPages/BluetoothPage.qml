import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

Item {
    id: page

    // ── Config ────────────────────────────────────────────────
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int rightMargin: 10

    // ── State ─────────────────────────────────────────────────
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false
    property string statusText: ""

    // Nerd Font glyphs
    readonly property string icRefresh: "\uf021"
    readonly property string icBluetooth: "\uf294"
    readonly property string icScan: "\uf1eb"

    // Power state (saved/restored/toggled) lives in BluetoothState so the
    // quick actions menu and this page share one code path.

    // ── Helpers ───────────────────────────────────────────────
    function setStatus(text) {
        page.statusText = text
        statusTimer.restart()
    }

    function setDiscovering(on) {
        if (!page.adapter || !page.powered)
            return
        page.adapter.discovering = on
    }

    // Restart discovery: stop, then start again after a short pause.
    function rescan() {
        if (!page.adapter || !page.powered || rescanTimer.running)
            return
        page.adapter.discovering = false
        setStatus("Refreshing devices...")
        rescanTimer.restart()
    }

    function togglePower() {
        BluetoothState.togglePower()
    }

    function deviceAction(dev) {
        if (!dev) return

        var name = dev.name || dev.address || "device"

        if (dev.state === BluetoothDeviceState.Connected) {
            setStatus("Disconnecting " + name + "...")
            BluetoothState.forget(dev.address)
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
        setStatus("Connecting to " + name + "...")
        delete BluetoothState.reconnectBackoff[dev.address]   // manual attempt resets auto-retry
        dev.trusted = true
        dev.connect()
    }

    function removeDevice(dev) {
        if (!dev) return

        BluetoothState.markRemoved(dev)

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

    function deviceSubtitle(dev) {
        var parts = [dev.address]
        if (dev.state === BluetoothDeviceState.Connected) parts.push("connected")
        else if (dev.paired) parts.push("paired")
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

    // Centered placeholder (no adapter / off / scanning)
    component EmptyState: Item {
        id: empty
        property string icon: ""
        property string title: ""
        property string hint: ""
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
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: empty.hint
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSizeSmall
                visible: empty.hint !== ""
            }
        }
    }

    // ── Timers ────────────────────────────────────────────────
    Timer {
        id: statusTimer
        interval: 3000
        onTriggered: page.statusText = ""
    }

    Timer {
        id: rescanTimer
        interval: 400
        onTriggered: page.setDiscovering(true)
    }

    // Keeps discovery alive only while the page is visible and powered.
    Timer {
        id: discoveryRetryTimer
        interval: 1500
        repeat: true
        running: page.visible && page.powered && BluetoothState.wantPower !== "off"
        onTriggered: {
            if (page.adapter && page.powered && !page.adapter.discovering && !rescanTimer.running)
                page.adapter.discovering = true
        }
    }

    // ── Discovery lifecycle ───────────────────────────────────
    onVisibleChanged: setDiscovering(page.visible && page.powered)
    onPoweredChanged: setDiscovering(page.visible && page.powered)
    Component.onCompleted: {
        if (page.visible && page.powered) setDiscovering(true)
    }
    Component.onDestruction: setDiscovering(false)

    Connections {
        target: page.adapter
        function onEnabledChanged() {
            page.setDiscovering(page.visible && page.powered)
        }
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

            // top bar: title (left) + status (right), scrolls away with the content
            Item {
                width: parent.width
                height: titleText.implicitHeight

                Text {
                    id: titleText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BLUETOOTH"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSizeTitle
                    font.letterSpacing: 3
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.statusText
                    color: Theme.accent
                    font.family: page.mono
                    font.pixelSize: Theme.textSizeSmall
                    font.letterSpacing: 1
                    elide: Text.ElideLeft
                    width: Math.min(implicitWidth, parent.width - titleText.implicitWidth - 20)
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // ── Adapter block ────────────────────────────────
            Column {
                width: parent.width
                spacing: 10

                Item {
                    width: parent.width
                    height: 60

                    Frame { active: page.powered }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // power toggle
                        Rectangle {
                            id: powerBtn
                            width: parent.width - rescanBtn.width - parent.spacing
                            height: parent.height
                            radius: Theme.radius
                            color: page.powered
                                ? Theme.alpha(Theme.accent, 0.1)
                                : Theme.alpha(Theme.textFaint, 0.15)
                            border.width: 1
                            border.color: powerMouse.containsMouse
                                ? Theme.accent
                                : (page.powered ? Theme.accent : Theme.textFaint)
                            opacity: page.adapter ? 1.0 : 0.35

                            Text {
                                anchors.centerIn: parent
                                text: page.powered ? "BLUETOOTH ON" : "BLUETOOTH OFF"
                                color: page.powered ? Theme.accent : Theme.textFaint
                                font.family: page.mono
                                font.pixelSize: Theme.textSizeSmall
                                font.bold: true
                                font.letterSpacing: 2
                            }

                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !!page.adapter
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.togglePower()
                            }
                        }

                        // rescan
                        Rectangle {
                            id: rescanBtn
                            width: parent.height
                            height: parent.height
                            radius: Theme.radius
                            color: "transparent"
                            border.width: 1
                            border.color: rescanMouse.containsMouse ? Theme.accent : Theme.border
                            opacity: page.powered ? 1.0 : 0.35

                            Text {
                                anchors.centerIn: parent
                                text: page.icRefresh
                                color: (rescanTimer.running || page.scanning) ? Theme.accent : Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.textSizeGroup
                            }

                            MouseArea {
                                id: rescanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: page.powered
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.rescan()
                            }
                        }
                    }
                }
            }

            // ── Devices block ────────────────────────────────
            SectionHeader {
                label: "DEVICES"
                badges: page.powered ? [repeater.count + ""] : []
            }

            EmptyState {
                visible: !page.adapter
                icon: page.icBluetooth
                title: "NO BLUETOOTH ADAPTER"
            }

            EmptyState {
                visible: !!page.adapter && !page.powered
                icon: page.icBluetooth
                title: "BLUETOOTH IS OFF"
            }

            EmptyState {
                visible: page.powered && repeater.count === 0
                icon: page.icScan
                title: "SCANNING FOR DEVICES..."
                hint: "Devices will appear here."
            }

            Column {
                id: deviceList
                width: parent.width
                spacing: 10

                Repeater {
                    id: repeater
                    model: (page.adapter && page.powered) ? page.adapter.devices : null

                    delegate: Item {
                        id: card

                        required property BluetoothDevice modelData

                        readonly property bool isConnected:
                            modelData.state === BluetoothDeviceState.Connected

                        readonly property string deviceKey:
                            modelData.address || modelData.name || ""

                        readonly property bool busy:
                            modelData.pairing
                            || modelData.state === BluetoothDeviceState.Connecting
                            || modelData.state === BluetoothDeviceState.Disconnecting

                        visible: !BluetoothState.removingDevices[deviceKey]
                        width: deviceList.width
                        height: visible ? 64 : 0

                        Frame { active: card.isConnected }

                        // right side: battery + actions
                        Row {
                            id: actions
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 20

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: card.modelData.batteryAvailable
                                text: Math.round(card.modelData.battery * 100) + "%"
                                color: Theme.text
                                font.family: page.mono
                                font.pixelSize: Theme.textSizeGroup
                            }

                            TextButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.actionLabel(card.modelData)
                                baseColor: card.isConnected ? Theme.danger : Theme.accent
                                hoverColor: baseColor
                                clickable: !card.busy
                                onClicked: page.deviceAction(card.modelData)
                            }

                            TextButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "UNPAIR"
                                onClicked: page.removeDevice(card.modelData)
                            }
                        }

                        // left side: icon + name + address
                        Text {
                            id: deviceIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.icBluetooth
                            color: card.isConnected ? Theme.accent : Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.textSizeSection
                        }

                        Column {
                            anchors.left: deviceIcon.right
                            anchors.leftMargin: 14
                            anchors.right: actions.left
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                width: parent.width
                                text: card.modelData.name || card.modelData.address
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSizeGroup
                            }

                            Text {
                                width: parent.width
                                text: page.deviceSubtitle(card.modelData)
                                elide: Text.ElideRight
                                color: card.isConnected ? Theme.accent : Theme.textDim
                                font.family: page.mono
                                font.pixelSize: Theme.textSizeSmall
                                font.letterSpacing: 1
                            }
                        }
                    }
                }
            }
        }
    }
}