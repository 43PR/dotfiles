import QtQuick
import Quickshell.Services.Pipewire
import "../"

Item {
    id: page

    // =========================
    // Global layout controls
    // =========================
    property real marginLeft: 0
    property real marginRight: 30
    property real marginTop: 0
    property real marginBottom: 0

    // General spacing controls
    property real contentSpacing: 10
    property real sectionSpacing: 6

    PwObjectTracker {
        // Track every audio node so .audio / .description are populated
        objects: Pipewire.nodes.values
    }

    property var sink: Pipewire.defaultAudioSink

    property real volume: (sink && sink.audio)
        ? sink.audio.volume
        : 0

    property bool muted: (sink && sink.audio)
        ? sink.audio.muted
        : false

    // Physical / virtual output devices
    property var outputSinks:
        Pipewire.nodes.values.filter(
            n => n.isSink &&
                 !n.isStream &&
                 n.audio
        )

    // Active application audio streams
    property var appStreams:
        Pipewire.nodes.values.filter(
            n => n.isStream && n.isSink
        )

    Column {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom

            leftMargin: page.marginLeft
            rightMargin: page.marginRight
            topMargin: page.marginTop
            bottomMargin: page.marginBottom
        }

        spacing: page.contentSpacing

        // =========================
        // SOUND
        // =========================

        Text {
            text: "SOUND"

            color: Theme.text

            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.bold: true
            font.letterSpacing: 3
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // =========================
        // OUTPUT VOLUME
        // =========================

        Row {
            width: parent.width
            spacing: 2

            Rectangle {
                width: 28
                height: 28

                radius: Theme.radius

                anchors.verticalCenter:
                    parent.verticalCenter

                color: page.muted
                    ? Theme.alpha(
                          Theme.danger,
                          0.15
                      )
                    : Theme.alpha(
                          Theme.accent,
                          0.10
                      )

                border.width: 1

                border.color: page.muted
                    ? Theme.danger
                    : Theme.border

                Text {
                    anchors.centerIn: parent

                    text: page.muted
                        ? "\uf026"
                        : "\uf028"

                    color: page.muted
                        ? Theme.danger
                        : Theme.accent

                    font.family:
                        Theme.iconFont

                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        if (page.sink &&
                            page.sink.audio) {

                            page.sink.audio.muted =
                                !page.sink.audio.muted
                        }
                    }
                }
            }

            Text {
                width: 82

                anchors.verticalCenter:
                    parent.verticalCenter

                text: " VOLUME"

                color: page.muted
                    ? Theme.textDim
                    : Theme.text

                font.family:
                    Theme.fontFamily

                font.pixelSize: 11

                elide:
                    Text.ElideRight
            }

            Slider {
                width: parent.width -
                       28 -
                       82 -
                       12

                height: 72

                anchors.verticalCenter:
                    parent.verticalCenter

                label: ""
                icon: ""

                value: page.muted
                    ? 0
                    : page.volume

                onCommitted: (v) => {
                    if (page.sink &&
                        page.sink.audio) {

                        page.sink.audio.muted = false
                        page.sink.audio.volume = v
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // =========================
        // OUTPUT DEVICE
        // =========================

        Row {
            width: parent.width
            spacing: 10

            Text {
                text: "OUTPUT"

                color: Theme.accent

                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2

                anchors.verticalCenter:
                    parent.verticalCenter
            }

            
        }

        // =========================
        // OUTPUT SELECTOR
        // =========================

        Column {
            width: parent.width
            spacing: page.sectionSpacing

            Repeater {
                model: page.outputSinks

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 40

                    radius: Theme.radius

                    property var output:
                        modelData

                    property bool active:
                        page.sink &&
                        output &&
                        page.sink.id === output.id

                    color: active
                        ? Theme.alpha(
                              Theme.accent,
                              0.10
                          )
                        : "transparent"

                    border.width: 1

                    border.color: active
                        ? Theme.accent
                        : Theme.border

                    Row {
                        anchors.fill: parent

                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        spacing: 8

                        Text {
                            width: 20

                            anchors.verticalCenter:
                                parent.verticalCenter

                            text: active
                                ? "\uf192"
                                : "\uf10c"

                            color: active
                                ? Theme.accent
                                : Theme.textFaint

                            font.family:
                                Theme.iconFont

                            font.pixelSize: 11
                        }

                        Text {
                            width: parent.width - 28

                            anchors.verticalCenter:
                                parent.verticalCenter

                            text: (
                                output.description ||
                                output.nickname ||
                                output.name ||
                                "Unknown output"
                            ).toUpperCase()

                            color: active
                                ? Theme.accent
                                : Theme.text

                            font.family:
                                Theme.fontFamily

                            font.pixelSize: 10

                            elide:
                                Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            if (output) {
                                Pipewire.preferredDefaultAudioSink =
                                    output
                            }
                        }
                    }
                }
            }

            Text {
                visible:
                    page.outputSinks.length === 0

                text:
                    "NO AUDIO OUTPUTS"

                color: Theme.textFaint

                font.family:
                    Theme.fontFamily

                font.pixelSize: 10

                font.letterSpacing: 1.5

                leftPadding: 4
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // =========================
        // PER-APP AUDIO
        // =========================

        Row {
            width: parent.width
            spacing: 10

            Text {
                text: "PLAYING APPS"

                color: Theme.accent

                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 2

                anchors.verticalCenter:
                    parent.verticalCenter
            }

            Text {
                text: page.appStreams.length

                color: Theme.textFaint

                font.family: Theme.fontFamily
                font.pixelSize: 10

                anchors.verticalCenter:
                    parent.verticalCenter
            }
        }

        Column {
            width: parent.width
            spacing: page.sectionSpacing

            Repeater {
                model: page.appStreams

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 48

                    radius: Theme.radius

                    property var stream:
                        modelData

                    property bool streamMuted:
                        stream &&
                        stream.audio &&
                        stream.audio.muted

                    property real streamVolume:
                        stream &&
                        stream.audio
                            ? stream.audio.volume
                            : 0

                    color: streamMuted
                        ? Theme.alpha(
                              Theme.danger,
                              0.06
                          )
                        : "transparent"

                    border.width: 1

                    border.color: streamMuted
                        ? Theme.alpha(
                              Theme.danger,
                              0.5
                          )
                        : Theme.border

                    Row {
                        anchors.fill: parent

                        anchors.leftMargin: 10
                        anchors.rightMargin: 14

                        spacing: 6

                        Rectangle {
                            width: 28
                            height: 28

                            radius: Theme.radius

                            anchors.verticalCenter:
                                parent.verticalCenter

                            color: streamMuted
                                ? Theme.alpha(
                                      Theme.danger,
                                      0.15
                                  )
                                : Theme.alpha(
                                      Theme.accent,
                                      0.10
                                  )

                            border.width: 1

                            border.color: streamMuted
                                ? Theme.danger
                                : Theme.border

                            Text {
                                anchors.centerIn: parent

                                text: streamMuted
                                    ? "\uf026"
                                    : "\uf028"

                                color: streamMuted
                                    ? Theme.danger
                                    : Theme.accent

                                font.family:
                                    Theme.iconFont

                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    if (stream &&
                                        stream.audio) {

                                        stream.audio.muted =
                                            !stream.audio.muted
                                    }
                                }
                            }
                        }

                        Text {
                            width: 82

                            anchors.verticalCenter:
                                parent.verticalCenter

                            text: (
                                stream.description ||
                                stream.name ||
                                "Unknown app"
                            ).toUpperCase()

                            color: streamMuted
                                ? Theme.textDim
                                : Theme.text

                            font.family:
                                Theme.fontFamily

                            font.pixelSize: 11

                            elide:
                                Text.ElideRight
                        }

                        Slider {
                            width: parent.width -
                                   28 -
                                   82 -
                                   12

                            height: 72

                            anchors.verticalCenter:
                                parent.verticalCenter

                            label: ""
                            icon: ""

                            value: streamMuted
                                ? 0
                                : streamVolume

                            onCommitted: (v) => {
                                if (stream &&
                                    stream.audio) {

                                    stream.audio.muted = false
                                    stream.audio.volume = v
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible:
                    page.appStreams.length === 0

                text:
                    "NO ACTIVE AUDIO STREAMS"

                color: Theme.textFaint

                font.family:
                    Theme.fontFamily

                font.pixelSize: 10

                font.letterSpacing: 1.5

                leftPadding: 4
            }
        }
    }
}
