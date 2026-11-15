import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 10
    property real marginTop: 0
    property real marginBottom: 0
    property real labelWidth: 70

    PwObjectTracker { objects: Pipewire.nodes.values }

    property var sink: Pipewire.defaultAudioSink
    property real volume: sink?.audio?.volume ?? 0
    property bool muted: sink?.audio?.muted ?? false
    property var source: Pipewire.defaultAudioSource
    property real inputVolume: source?.audio?.volume ?? 0
    property bool inputMuted: source?.audio?.muted ?? false
    property var outputSinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    property var inputSources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    property var appStreams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink)

    // ------------------------------------------------------------------
    // Port info (via pactl, since Quickshell doesn't expose device ports)
    //   sinkInfo / sourceInfo: { "<node name>": { ports: [...], active: "<port name>" } }
    // ------------------------------------------------------------------

    property var sinkInfo: ({})
    property var sourceInfo: ({})

    function parsePorts(text) {
        var out = ({})
        try {
            var arr = JSON.parse(text)
            for (var i = 0; i < arr.length; i++) {
                var d = arr[i]
                var ports = []
                var src = d.ports || []
                for (var j = 0; j < src.length; j++) {
                    var p = src[j]
                    ports.push({
                        name: p.name,
                        description: p.description || p.name,
                        available: p.availability !== "not available"
                    })
                }
                out[d.name] = { ports: ports, active: d.active_port || "" }
            }
        } catch (e) {}
        return out
    }

    function refreshPorts() {
        if (!sinkProc.running) sinkProc.running = true
        if (!sourceProc.running) sourceProc.running = true
    }

    function selectPort(isSink, node, port) {
        if (!node) return
        setPortProc.command = ["pactl", isSink ? "set-sink-port" : "set-source-port", node.name, port]
        setPortProc.running = true
        // make the device the default too, so picking a port "just works"
        if (isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }

    Process {
        id: sinkProc
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector { onStreamFinished: page.sinkInfo = page.parsePorts(text) }
    }

    Process {
        id: sourceProc
        command: ["pactl", "-f", "json", "list", "sources"]
        stdout: StdioCollector { onStreamFinished: page.sourceInfo = page.parsePorts(text) }
    }

    Process {
        id: setPortProc
        onExited: page.refreshPorts()
    }

    Timer {
        interval: 3000; repeat: true; running: page.visible
        onTriggered: page.refreshPorts()
    }

    Component.onCompleted: refreshPorts()

    // ------------------------------------------------------------------
    // Reusable inline components
    // ------------------------------------------------------------------

    component SectionTitle: Text {
        color: Theme.text
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSection; font.bold: true; font.letterSpacing: 2
    }

    component GroupLabel: Text {
        color: Theme.text
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup; font.bold: true; font.letterSpacing: 1
    }

    component Card: Rectangle {
        id: card
        default property alias contentData: cardColumn.data
        width: parent.width
        height: cardColumn.implicitHeight + 28
        radius: Theme.radius
        color: "#00000000"; border.width: 1; border.color: Theme.border

        Column {
            id: cardColumn
            x: 14; y: 14
            width: parent.width - 28
            spacing: 16
        }
    }

    // 28x28 mute toggle (speaker / mic icon), turns red while muted
    component MuteButton: Rectangle {
        id: mb
        property bool muted: false
        property string iconOn: "\uf028"
        property string iconMuted: "\uf026"
        signal clicked()

        width: 28; height: 28; radius: Theme.radius
        color: muted ? Theme.alpha(Theme.danger, 0.15)
                     : (mbMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : Theme.alpha(Theme.accent, 0.10))
        border.width: 1
        border.color: muted ? Theme.danger : (mbMouse.containsMouse ? Theme.accent : Theme.border)

        Text {
            anchors.centerIn: parent
            text: mb.muted ? mb.iconMuted : mb.iconOn
            color: mb.muted ? Theme.danger : Theme.accent
            font.family: Theme.iconFont; font.pixelSize: Theme.textSizeGroup
        }

        MouseArea {
            id: mbMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }

    // Full-width selectable row used for device lists
    component ListButton: Rectangle {
        id: lb
        property string label: ""
        property bool current: false
        signal clicked()

        width: parent.width; height: 28; radius: Theme.radius
        color: current ? Theme.alpha(Theme.accent, 0.10) : (lbMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
        border.width: 1
        border.color: current || lbMouse.containsMouse ? Theme.accent : Theme.border

        Text {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 10; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: lb.label
            elide: Text.ElideRight
            color: lb.current ? Theme.accent : Theme.text
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.bold: true; font.letterSpacing: 1
        }

        MouseArea {
            id: lbMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lb.clicked()
        }
    }

    // Smaller row used for a device's ports
    component PortButton: Rectangle {
        id: pb
        property string label: ""
        property bool current: false
        property bool unavailable: false
        signal clicked()

        height: 24; radius: Theme.radius
        color: current ? Theme.alpha(Theme.accent, 0.10) : (pbMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
        border.width: 1
        border.color: current || pbMouse.containsMouse ? Theme.accent : Theme.border

        Text {
            anchors.left: parent.left; anchors.right: tag.left
            anchors.leftMargin: 10; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: pb.label
            elide: Text.ElideRight
            color: pb.current ? Theme.accent : (pb.unavailable ? Theme.textDim : Theme.text)
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall; font.letterSpacing: 1
        }

        Text {
            id: tag
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: pb.unavailable
            text: "UNPLUGGED"
            color: Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall; font.letterSpacing: 1
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    component EmptyText: Text {
        color: Theme.textDim
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
    }

    // Thin live level meter: fills with the node's current peak, empty when silent
    component LevelBar: Rectangle {
        id: lvl
        property var node: null
        property bool muted: false
        readonly property real level: muted ? 0 : Math.min(1, Math.sqrt(mon.peak))

        width: parent.width; height: 3; radius: 1.5
        color: Theme.alpha(Theme.accent, 0.10)

        PwNodePeakMonitor {
            id: mon
            node: lvl.node
            enabled: lvl.node !== null && !lvl.muted
        }

        Rectangle {
            height: parent.height; radius: parent.radius
            width: parent.width * lvl.level
            color: Theme.accent
            opacity: lvl.level > 0.02 ? 1 : 0
            Behavior on width { NumberAnimation { duration: 60 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    // dB slider + readout, meant to sit inside a volume Row, to the right of the % slider.
    // Same volume as the % slider on PulseAudio's dB scale
    // (dB = 60 * log10(volume), so 100% = 0 dB and 15% = -49.4 dB).
    // Slider range is minDb..0 dB; dragging to the far left sets silence.
    // Total width = sliderWidth + 8 + 60.
    component DbControl: Row {
        id: dc
        property real volume: 0
        property bool muted: false
        property real sliderWidth: 80
        property real minDb: -60
        readonly property real db: volume > 0.0001 ? 60 * Math.log(volume) / Math.LN10 : -Infinity
        signal commit(real vol)

        spacing: 8

        Slider {
            width: dc.sliderWidth
            anchors.verticalCenter: parent.verticalCenter
            label: ""; icon: ""
            value: dc.muted || !isFinite(dc.db) ? 0 : Math.max(0, Math.min(1, (dc.db - dc.minDb) / -dc.minDb))
            onCommitted: v => dc.commit(v <= 0 ? 0 : Math.pow(10, (dc.minDb + v * -dc.minDb) / 60))
        }

        Text {
            width: 60
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: dc.muted ? "MUTED" : (isFinite(dc.db) ? (dc.db > 0 ? "+" : "") + dc.db.toFixed(1) + " dB" : "-\u221e dB")
            color: dc.muted ? Theme.danger : Theme.text
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup
        }
    }

    // Device row: click the name to make it the default, click the chevron to
    // expand and list all of its ports (e.g. Internal Mic / Headset Mic).
    component DeviceItem: Column {
        id: di
        property string label: ""
        property bool current: false
        property var ports: []
        property string activePort: ""
        property bool expanded: false
        signal selected()
        signal portSelected(string port)

        width: parent.width
        spacing: 4

        Row {
            width: parent.width
            spacing: 4

            ListButton {
                width: parent.width - 32
                label: di.label
                current: di.current
                onClicked: di.selected()
            }

            Rectangle {
                width: 28; height: 28; radius: Theme.radius
                color: di.expanded ? Theme.alpha(Theme.accent, 0.10)
                                   : (chevMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                border.width: 1
                border.color: di.expanded || chevMouse.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: di.expanded ? "\uf077" : "\uf078"
                    color: di.expanded ? Theme.accent : Theme.text
                    font.family: Theme.iconFont; font.pixelSize: Theme.textSizeSmall
                }

                MouseArea {
                    id: chevMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        di.expanded = !di.expanded
                        page.refreshPorts()
                    }
                }
            }
        }

        Column {
            visible: di.expanded
            width: parent.width
            leftPadding: 16
            spacing: 4

            Repeater {
                model: di.ports

                delegate: PortButton {
                    required property var modelData
                    width: parent.width - 16
                    label: (modelData.description || modelData.name).toUpperCase()
                    current: di.activePort === modelData.name
                    unavailable: !modelData.available
                    onClicked: di.portSelected(modelData.name)
                }
            }

            EmptyText {
                visible: di.ports.length === 0
                text: "NO PORTS"
            }
        }
    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft; anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop; anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            background: Rectangle {
                color: "transparent"
                radius: width / 2
            }
            contentItem: Rectangle {
                color: "transparent"
                radius: width / 2
            }
        }

        Column {
            id: content
            width: flick.width
            spacing: 14

            Text {
                text: "AUDIO"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeTitle; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------- OUTPUT ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                SectionTitle { text: "OUTPUT" }

                Card {
                    Column {
                        width: parent.width; spacing: 8

                        Row {
                            width: parent.width; spacing: 8

                            MuteButton {
                                anchors.verticalCenter: parent.verticalCenter
                                muted: page.muted
                                onClicked: if (page.sink?.audio) page.sink.audio.muted = !page.sink.audio.muted
                            }

                            Text {
                                width: page.labelWidth
                                anchors.verticalCenter: parent.verticalCenter
                                text: "VOLUME"; color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup
                            }

                            Slider {
                                width: Math.max(40, (parent.width - page.labelWidth - 180) / 2)
                                anchors.verticalCenter: parent.verticalCenter
                                label: ""; icon: ""
                                value: page.muted ? 0 : page.volume
                                onCommitted: v => {
                                    if (page.sink?.audio) {
                                        page.sink.audio.muted = false
                                        page.sink.audio.volume = v
                                    }
                                }
                            }

                            Text {
                                width: 52
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: page.muted ? "MUTED" : Math.round(page.volume * 100) + "%"
                                color: page.muted ? Theme.danger : Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup
                            }

                            DbControl {
                                anchors.verticalCenter: parent.verticalCenter
                                sliderWidth: Math.max(40, (parent.width - page.labelWidth - 180) / 2)
                                volume: page.volume
                                muted: page.muted
                                onCommit: v => {
                                    if (page.sink?.audio) {
                                        page.sink.audio.muted = false
                                        page.sink.audio.volume = v
                                    }
                                }
                            }
                        }

                        LevelBar { node: page.sink; muted: page.muted }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "OUTPUT DEVICE" }

                        Repeater {
                            model: page.outputSinks

                            delegate: DeviceItem {
                                required property var modelData
                                label: (modelData?.description || modelData?.nickname || modelData?.name || "Unknown output").toUpperCase()
                                current: page.sink?.id === modelData?.id
                                ports: page.sinkInfo[modelData?.name]?.ports ?? []
                                activePort: page.sinkInfo[modelData?.name]?.active ?? ""
                                onSelected: if (modelData) Pipewire.preferredDefaultAudioSink = modelData
                                onPortSelected: port => page.selectPort(true, modelData, port)
                            }
                        }

                        EmptyText {
                            visible: page.outputSinks.length === 0
                            text: "NO AUDIO OUTPUTS"
                        }
                    }
                }
            }

            // ---------------- INPUT ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                SectionTitle { text: "INPUT" }

                Card {
                    Column {
                        width: parent.width; spacing: 8

                        Row {
                            width: parent.width; spacing: 8

                            MuteButton {
                                anchors.verticalCenter: parent.verticalCenter
                                muted: page.inputMuted
                                iconOn: "\uf130"
                                iconMuted: "\uf131"
                                onClicked: if (page.source?.audio) page.source.audio.muted = !page.source.audio.muted
                            }

                            Text {
                                width: page.labelWidth
                                anchors.verticalCenter: parent.verticalCenter
                                text: "VOLUME"; color: Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup
                            }

                            Slider {
                                width: Math.max(40, (parent.width - page.labelWidth - 180) / 2)
                                anchors.verticalCenter: parent.verticalCenter
                                label: ""; icon: ""
                                value: page.inputMuted ? 0 : page.inputVolume
                                onCommitted: v => {
                                    if (page.source?.audio) {
                                        page.source.audio.muted = false
                                        page.source.audio.volume = v
                                    }
                                }
                            }

                            Text {
                                width: 52
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: page.inputMuted ? "MUTED" : Math.round(page.inputVolume * 100) + "%"
                                color: page.inputMuted ? Theme.danger : Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup
                            }

                            DbControl {
                                anchors.verticalCenter: parent.verticalCenter
                                sliderWidth: Math.max(40, (parent.width - page.labelWidth - 180) / 2)
                                volume: page.inputVolume
                                muted: page.inputMuted
                                onCommit: v => {
                                    if (page.source?.audio) {
                                        page.source.audio.muted = false
                                        page.source.audio.volume = v
                                    }
                                }
                            }
                        }

                        LevelBar { node: page.source; muted: page.inputMuted }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "INPUT DEVICE" }

                        Repeater {
                            model: page.inputSources

                            delegate: DeviceItem {
                                required property var modelData
                                label: (modelData?.description || modelData?.nickname || modelData?.name || "Unknown input").toUpperCase()
                                current: page.source?.id === modelData?.id
                                ports: page.sourceInfo[modelData?.name]?.ports ?? []
                                activePort: page.sourceInfo[modelData?.name]?.active ?? ""
                                onSelected: if (modelData) Pipewire.preferredDefaultAudioSource = modelData
                                onPortSelected: port => page.selectPort(false, modelData, port)
                            }
                        }

                        EmptyText {
                            visible: page.inputSources.length === 0
                            text: "NO AUDIO INPUTS"
                        }
                    }
                }
            }

            // ---------------- PER-APP VOLUME ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6
                bottomPadding: 6

                Row {
                    spacing: 10
                    SectionTitle { text: "PER-APP VOLUME" }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.appStreams.length
                        color: Theme.textDim
                        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
                    }
                }

                Card {
                    Column {
                        width: parent.width; spacing: 8
                        Repeater {
                            model: page.appStreams

                            delegate: Row {
                                id: streamRow
                                required property var modelData
                                property var stream: modelData
                                property bool streamMuted: stream?.audio?.muted ?? false
                                property real streamVolume: stream?.audio?.volume ?? 0

                                width: parent.width; spacing: 8

                                MuteButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    muted: streamRow.streamMuted
                                    onClicked: if (streamRow.stream?.audio) streamRow.stream.audio.muted = !streamRow.stream.audio.muted
                                }

                                Text {
                                    width: 110
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (streamRow.stream?.description || streamRow.stream?.name || "Unknown app").toUpperCase()
                                    elide: Text.ElideRight
                                    color: streamRow.streamMuted ? Theme.textDim : Theme.text
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                                }

                                Slider {
                                    width: parent.width - 28 - 110 - 52 - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: ""; icon: ""
                                    value: streamRow.streamMuted ? 0 : streamRow.streamVolume
                                    onCommitted: v => {
                                        if (streamRow.stream?.audio) {
                                            streamRow.stream.audio.muted = false
                                            streamRow.stream.audio.volume = v
                                        }
                                    }
                                }

                                Text {
                                    width: 52
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: streamRow.streamMuted ? "MUTED" : Math.round(streamRow.streamVolume * 100) + "%"
                                    color: streamRow.streamMuted ? Theme.danger : Theme.text
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody
                                }
                            }
                        }

                        EmptyText {
                            visible: page.appStreams.length === 0
                            text: "NO ACTIVE AUDIO STREAMS"
                        }
                    }
                }
            }
        }
    }
}