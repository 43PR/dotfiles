import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 150
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: root.showing
            ? (root.showMedia ? mediaPanel : flyout)
            : null
    }

    PwObjectTracker {
        id: audioTracker
        objects: [Pipewire.defaultAudioSink]
    }

    property var sink: Pipewire.defaultAudioSink

    property real volume: {
        if (!sink || !sink.audio)
            return 0
        return sink.audio.volume
    }

    property bool muted: {
        if (!sink || !sink.audio)
            return false
        return sink.audio.muted
    }

    property bool ready: false
    property bool showing: false
    property bool showMedia: false
    property bool pendingShow: false
    property bool hovered: flyoutArea.containsMouse || panelArea.containsMouse

    Timer {
        id: startupTimer

        interval: 2000
        repeat: false
        running: true

        onTriggered: root.ready = true
    }

    function showOsd() {
        showing = true
        hideTimer.restart()
    }

    function triggerOsd() {
        if (!ready)
            return

        if (showing) {
            hideTimer.restart()
            return
        }

        pendingShow = true
        updateMedia()
    }

    function triggerMediaOsd() {
        if (!ready)
            return

        pendingShow = false
        showMedia = true
        showing = true
        hideTimer.restart()
        updateMedia()
    }

    function finishPendingShow() {
        if (!pendingShow)
            return

        pendingShow = false
        showMedia = playing
        showOsd()
    }

    Timer {
        id: hideTimer

        interval: root.showMedia ? 3000 : 1200
        repeat: false

        onTriggered: {
            if (root.hovered) {
                hideTimer.restart()
                return
            }

            root.showing = false
        }
    }

    onShowingChanged: {
        if (!showing)
            showMedia = false
    }

    onShowMediaChanged: {
        if (showMedia)
            updateMedia()
        else
            bars = []
    }

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            root.triggerOsd()
        }

        function onMutedChanged() {
            root.triggerOsd()
        }
    }

    property string title: ""
    property string artist: ""
    property string status: "Stopped"

    property real position: 0
    property real length: 0

    property bool playing: status === "Playing"

    Process {
        id: mediaProcess

        command: [
            "playerctl",
            "metadata",
            "--format",
            "{{status}}|{{title}}|{{artist}}|{{position}}|{{mpris:length}}"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim()

                if (!output) {
                    root.status = "Stopped"
                    root.title = ""
                    root.artist = ""
                    root.position = 0
                    root.length = 0
                    root.finishPendingShow()
                    return
                }

                var parts = output.split("|")

                if (parts.length < 5) {
                    root.finishPendingShow()
                    return
                }

                root.status = parts[0]
                root.title = parts[1]
                root.artist = parts[2]
                root.position = parseFloat(parts[3]) || 0
                root.length = parseFloat(parts[4]) || 0

                root.finishPendingShow()
            }
        }
    }

    function updateMedia() {
        if (!mediaProcess.running)
            mediaProcess.running = true
    }

    Process {
        id: playerEventProcess

        command: [
            "playerctl",
            "--follow",
            "metadata",
            "--format",
            "{{status}}|{{title}}|{{artist}}"
        ]

        running: true

        stdout: SplitParser {
            onRead: data => {
                var output = data.trim()

                if (!output)
                    return

                var parts = output.split("|")

                if (parts.length < 3)
                    return

                var newStatus = parts[0]
                var newTitle = parts[1]
                var newArtist = parts[2]

                var trackChanged =
                    newTitle !== root.title ||
                    newArtist !== root.artist

                root.status = newStatus
                root.title = newTitle
                root.artist = newArtist

                if (root.ready && trackChanged && newTitle !== "") {
                    root.triggerMediaOsd()
                }

                if (root.ready)
                    root.updateMedia()
            }
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.showing && root.showMedia

        onTriggered: root.updateMedia()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.playing && root.showing && root.showMedia

        onTriggered: {
            if (root.length > 0) {
                root.position += 250000

                if (root.position > root.length)
                    root.position = root.length
            }
        }
    }

    readonly property int barCount: 24
    property var bars: []

    Process {
        id: cavaProcess

        running: root.showing && root.showMedia

        command: [
            "sh", "-c",
            "printf '%s\\n' " +
            "'[general]' 'bars = " + root.barCount + "' 'framerate = 30' " +
            "'[input]' 'method = pipewire' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'bar_delimiter = 59' 'frame_delimiter = 10' " +
            "> /tmp/quickshell-cava.conf && exec cava -p /tmp/quickshell-cava.conf"
        ]

        stdout: SplitParser {
            onRead: data => {
                var parts = data.split(";")
                var out = []

                for (var i = 0; i < root.barCount; i++)
                    out.push(parseInt(parts[i]) || 0)

                root.bars = out
            }
        }
    }

    Rectangle {
        id: flyout
        property bool open: root.showing && !root.showMedia
        width: 320
        height: 28
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        radius: 36
        color: Theme.bg
        opacity: open ? 1 : 0
        scale: open ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        MouseArea {
            id: flyoutArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: flyout.open
        }
        Text {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (root.muted)
                    return "󰖁"
                if (root.volume <= 0)
                    return "󰕿"
                if (root.volume < 0.5)
                    return "󰖀"
                return "󰕾"
            }

            font.family: "Symbols Nerd Font"
            font.pixelSize: 20

            color: Theme.text
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted
                ? "Muted"
                : Math.round(root.volume * 100) + "%"
            font.pixelSize: 12
            font.bold: true
            color: Theme.text
        }
        Rectangle {
            anchors.left: icon.right
            anchors.leftMargin: 15
            anchors.right: parent.right
            anchors.rightMargin: 68
            anchors.verticalCenter: parent.verticalCenter
            height: 5
            radius: 4
            color: "#555555"
            Rectangle {
                width: root.muted
                    ? 0
                    : parent.width * Math.min(root.volume, 1)
                height: parent.height
                radius: 4
                color: Theme.text
                Behavior on width {
                    NumberAnimation { duration: 100 }
                }
            }
        }
    }
    Rectangle {
        id: mediaPanel
        property bool open: root.showing && root.showMedia
        width: 420
        height: 105
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        radius: 24
        color: Theme.bg
        opacity: open ? 1 : 0
        scale: open ? 1 : 0.9
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        MouseArea {
            id: panelArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: mediaPanel.open
        }
        Row {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 16
                leftMargin: 25
                rightMargin: 25
            }
            spacing: 10
            Text {
                width: parent.width / 2 - 5
                text: root.title || "Nothing playing"
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                font.pixelSize: 13
                font.bold: true
                color: Theme.text
            }
            Text {
                width: parent.width / 2 - 5
                text: root.artist || "No artist"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                font.pixelSize: 11
                color: Theme.text
                opacity: 0.65
            }
        }
        Item {
            id: visualizer
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 42
                leftMargin: 25
                rightMargin: 25
            }
            height: 20
            property real progress: root.length > 0
                ? Math.min(root.position / root.length, 1)
                : 0
            property real barSpacing: 3
            property real barWidth: (width - barSpacing * (root.barCount - 1)) / root.barCount
            Repeater {
                model: root.barCount
                Rectangle {
                    required property int index
                    x: index * (visualizer.barWidth + visualizer.barSpacing)
                    width: visualizer.barWidth
                    radius: width / 2
                    color: Theme.text
                    opacity: ((index + 0.5) / root.barCount) <= visualizer.progress
                        ? 0.9
                        : 0.3
                    height: Math.max(
                        3,
                        ((root.bars[index] ?? 0) / 100) * visualizer.height
                    )
                    y: visualizer.height - height
                    Behavior on height {
                        NumberAnimation { duration: 60 }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }
            }
        }
        Row {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 9
            }
            spacing: 28
            Text {
                text: "󰒮"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 19
                color: Theme.text
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Quickshell.execDetached(["playerctl", "previous"])
                        hideTimer.restart()
                    }
                }
            }
            Text {
                text: root.playing ? "󰏤" : "󰐊"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 21
                color: Theme.text
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Quickshell.execDetached(["playerctl", "play-pause"])
                        hideTimer.restart()
                    }
                }
            }
            Text {
                text: "󰒭"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 19
                color: Theme.text
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Quickshell.execDetached(["playerctl", "next"])
                        hideTimer.restart()
                    }
                }
            }
        }
    }
}