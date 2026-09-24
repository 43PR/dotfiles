import QtQuick
import Quickshell.Services.Pipewire
import "../"

Item {
    id: page
    property real marginLeft: 0
    property real marginRight: 45
    property real marginTop: 0
    property real marginBottom: 0
    property real sliderMarginRight: 10
    property real sectionSpacing: 6
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

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom
        spacing: 14

        Text {
            text: "AUDIO"; color: Theme.text
            font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // OUTPUT: icon + label + slider
        Row {
            width: parent.width; height: 48; spacing: 8
            Rectangle {
                width: 28; height: 28; radius: Theme.radius; anchors.verticalCenter: parent.verticalCenter
                color: page.muted ? Theme.alpha(Theme.danger, 0.15) : Theme.alpha(Theme.accent, 0.10)
                border.width: 1; border.color: page.muted ? Theme.danger : Theme.border
                Text {
                    anchors.centerIn: parent
                    text: page.muted ? "\uf026" : "\uf028"
                    color: page.muted ? Theme.danger : Theme.accent
                    font.family: Theme.iconFont; font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (page.sink?.audio) page.sink.audio.muted = !page.sink.audio.muted
                }
            }
            Text {
                width: 76; anchors.verticalCenter: parent.verticalCenter
                text: "OUTPUT"; color: page.muted ? Theme.textDim : Theme.accent
                font.family: Theme.fontFamily; font.pixelSize: 15; font.letterSpacing: 2
            }
            Slider {
                width: parent.width - 28 - 76 - 8 - page.sliderMarginRight
                height: 72; anchors.verticalCenter: parent.verticalCenter
                label: ""; icon: ""; value: page.muted ? 0 : page.volume
                onCommitted: v => { if (page.sink?.audio) { page.sink.audio.muted = false; page.sink.audio.volume = v } }
            }
        }

        Column {
            width: parent.width; spacing: page.sectionSpacing
            Repeater {
                model: page.outputSinks
                delegate: Rectangle {
                    required property var modelData
                    property var output: modelData
                    property bool active: page.sink?.id === output?.id
                    width: parent.width; height: 40; radius: Theme.radius
                    color: active ? Theme.alpha(Theme.accent, 0.10) : "transparent"
                    border.width: 1; border.color: active ? Theme.accent : Theme.border

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text {
                            width: 20; anchors.verticalCenter: parent.verticalCenter
                            text: active ? "\uf192" : "\uf10c"; color: active ? Theme.accent : Theme.textFaint
                            font.family: Theme.iconFont; font.pixelSize: 11
                        }
                        Text {
                            width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                            text: (output?.description || output?.nickname || output?.name || "Unknown output").toUpperCase()
                            color: active ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 10; elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (output) Pipewire.preferredDefaultAudioSink = output
                    }
                }
            }
            Text {
                visible: page.outputSinks.length === 0
                text: "NO AUDIO OUTPUTS"; color: Theme.textFaint; leftPadding: 4
                font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.5
            }
        }

        // INPUT: icon + label + slider
        Row {
            width: parent.width; height: 48; spacing: 8
            Rectangle {
                width: 28; height: 28; radius: Theme.radius; anchors.verticalCenter: parent.verticalCenter
                color: page.inputMuted ? Theme.alpha(Theme.danger, 0.15) : Theme.alpha(Theme.accent, 0.10)
                border.width: 1; border.color: page.inputMuted ? Theme.danger : Theme.border
                Text {
                    anchors.centerIn: parent
                    text: page.inputMuted ? "\uf131" : "\uf130"
                    color: page.inputMuted ? Theme.danger : Theme.accent
                    font.family: Theme.iconFont; font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (page.source?.audio) page.source.audio.muted = !page.source.audio.muted
                }
            }
            Text {
                width: 76; anchors.verticalCenter: parent.verticalCenter
                text: "INPUT"; color: page.inputMuted ? Theme.textDim : Theme.accent
                font.family: Theme.fontFamily; font.pixelSize: 15; font.letterSpacing: 2
            }
            Slider {
                width: parent.width - 28 - 76 - 8 - page.sliderMarginRight
                height: 72; anchors.verticalCenter: parent.verticalCenter
                label: ""; icon: ""; value: page.inputMuted ? 0 : page.inputVolume
                onCommitted: v => { if (page.source?.audio) { page.source.audio.muted = false; page.source.audio.volume = v } }
            }
        }

        Column {
            width: parent.width; spacing: page.sectionSpacing
            Repeater {
                model: page.inputSources
                delegate: Rectangle {
                    required property var modelData
                    property var input: modelData
                    property bool active: page.source?.id === input?.id
                    width: parent.width; height: 40; radius: Theme.radius
                    color: active ? Theme.alpha(Theme.accent, 0.10) : "transparent"
                    border.width: 1; border.color: active ? Theme.accent : Theme.border

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text {
                            width: 20; anchors.verticalCenter: parent.verticalCenter
                            text: active ? "\uf192" : "\uf10c"; color: active ? Theme.accent : Theme.textFaint
                            font.family: Theme.iconFont; font.pixelSize: 11
                        }
                        Text {
                            width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                            text: (input?.description || input?.nickname || input?.name || "Unknown input").toUpperCase()
                            color: active ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 10; elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (input) Pipewire.preferredDefaultAudioSource = input
                    }
                }
            }
            Text {
                visible: page.inputSources.length === 0
                text: "NO AUDIO INPUTS"; color: Theme.textFaint; leftPadding: 4
                font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.5
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Row {
            width: parent.width; spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PER-APP VOLUME"; color: Theme.accent
                font.family: Theme.fontFamily; font.pixelSize: 14; font.letterSpacing: 2
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.appStreams.length; color: Theme.textFaint
                font.family: Theme.fontFamily; font.pixelSize: 10
            }
        }

        Column {
            width: parent.width; spacing: page.sectionSpacing
            Repeater {
                model: page.appStreams
                delegate: Rectangle {
                    required property var modelData
                    property var stream: modelData
                    property bool streamMuted: stream?.audio?.muted ?? false
                    property real streamVolume: stream?.audio?.volume ?? 0
                    width: parent.width; height: 48; radius: Theme.radius
                    color: streamMuted ? Theme.alpha(Theme.danger, 0.06) : "transparent"
                    border.width: 1
                    border.color: streamMuted ? Theme.alpha(Theme.danger, 0.5) : Theme.border

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 14; spacing: 6
                        Rectangle {
                            width: 28; height: 28; radius: Theme.radius; anchors.verticalCenter: parent.verticalCenter
                            color: streamMuted ? Theme.alpha(Theme.danger, 0.15) : Theme.alpha(Theme.accent, 0.10)
                            border.width: 1; border.color: streamMuted ? Theme.danger : Theme.border
                            Text {
                                anchors.centerIn: parent
                                text: streamMuted ? "\uf026" : "\uf028"
                                color: streamMuted ? Theme.danger : Theme.accent
                                font.family: Theme.iconFont; font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (stream?.audio) stream.audio.muted = !stream.audio.muted
                            }
                        }
                        Text {
                            width: 82; anchors.verticalCenter: parent.verticalCenter
                            text: (stream?.description || stream?.name || "Unknown app").toUpperCase()
                            color: streamMuted ? Theme.textDim : Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight
                        }
                        Slider {
                            width: parent.width - 28 - 82 - 12 - page.sliderMarginRight
                            height: 72; anchors.verticalCenter: parent.verticalCenter
                            label: ""; icon: ""; value: streamMuted ? 0 : streamVolume
                            onCommitted: v => { if (stream?.audio) { stream.audio.muted = false; stream.audio.volume = v } }
                        }
                    }
                }
            }
            Text {
                visible: page.appStreams.length === 0
                text: "NO ACTIVE AUDIO STREAMS"; color: Theme.textDim; leftPadding: 4
                font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.5
            }
        }
    }
}