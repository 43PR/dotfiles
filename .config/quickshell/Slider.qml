import QtQuick

// Generic 0..1 slider.
//
// `value` is owned by the caller.
// `moved` is emitted continuously while dragging.
// `committed` is emitted once when the mouse is released.

Item {
    id: root

    property string label: ""
    property string icon: ""
    property real value: 0
    property color accentColor: Theme.accent

    signal moved(real value)
    signal committed(real value)

    implicitHeight: 50

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            spacing: 0

            Text {
                text: root.icon
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: root.accentColor
                width: 22
            }

            Text {
                text: root.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.letterSpacing: 1
            }

            Item {
                width: parent.width - 22
                height: 1
            }
        }

        Item {
            width: parent.width
            height: 16

            Rectangle {
                id: track

                width: parent.width
                height: 4

                radius: 2

                anchors.verticalCenter: parent.verticalCenter

                color: Theme.trackBg

                border.color: Theme.border
                border.width: 1

                Rectangle {
                    id: fill

                    width: track.width
                        * Math.max(
                            0,
                            Math.min(1, root.value)
                        )

                    height: parent.height

                    radius: 2

                    color: root.accentColor

                    Behavior on width {
                        enabled: !dragArea.pressed

                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2

                        radius: 4

                        color: "transparent"

                        border.width: 2

                        border.color:
                            Theme.alpha(
                                root.accentColor,
                                0.35
                            )
                    }
                }

                Rectangle {
                    id: handle

                    width: 12
                    height: 12

                    radius: 6

                    anchors.verticalCenter:
                        parent.verticalCenter

                    x: fill.width - width / 2

                    color: Theme.text

                    border.color: root.accentColor
                    border.width: 2

                    scale:
                        dragArea.pressed
                            ? 1.4
                            : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }
                }
            }

            MouseArea {
                id: dragArea

                anchors.fill: parent
                anchors.margins: -6

                preventStealing: true

                function setFromX(px) {
                    var v =
                        Math.max(
                            0,
                            Math.min(
                                1,
                                px / track.width
                            )
                        )

                    root.value = v
                    root.moved(v)
                }

                onPressed: (mouse) => {
                    setFromX(mouse.x)
                }

                onPositionChanged: (mouse) => {
                    if (pressed)
                        setFromX(mouse.x)
                }

                onReleased: {
                    root.committed(root.value)
                }
            }
        }
    }
}
