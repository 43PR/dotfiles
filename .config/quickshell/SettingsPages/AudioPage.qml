import QtQuick
import QtQuick.Controls
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

    component EmptyText: Text {
        color: Theme.textDim
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
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
                                width: parent.width - 28 - page.labelWidth - 52 - 24
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
                        }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "OUTPUT DEVICE" }

                        Repeater {
                            model: page.outputSinks

                            delegate: ListButton {
                                required property var modelData
                                label: (modelData?.description || modelData?.nickname || modelData?.name || "Unknown output").toUpperCase()
                                current: page.sink?.id === modelData?.id
                                onClicked: if (modelData) Pipewire.preferredDefaultAudioSink = modelData
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
                                width: parent.width - 28 - page.labelWidth - 52 - 24
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
                        }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "INPUT DEVICE" }

                        Repeater {
                            model: page.inputSources

                            delegate: ListButton {
                                required property var modelData
                                label: (modelData?.description || modelData?.nickname || modelData?.name || "Unknown input").toUpperCase()
                                current: page.source?.id === modelData?.id
                                onClicked: if (modelData) Pipewire.preferredDefaultAudioSource = modelData
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