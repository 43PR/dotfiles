import QtQuick

// Labeled 0..1 slider row: optional reset icon, label, track, and a
// right-aligned value readout — everything a caller previously had to
// build by hand around a bare track now lives in here.
//
// `value` is normalized 0..1 and owned by the caller.
// `moved` fires continuously while dragging — use it for cheap, local
//         state updates (e.g. live-formatting `displayText`).
// `committed` fires once when the drag (or a reset-click) ends — use it
//         for anything with a side effect (writing a file, shelling out).
//
// While dragging, a small bubble above the handle shows the position as
// a percentage, independent of whatever `displayText` is showing.

Item {
    id: root

    property string label: ""
    property string icon: ""
    property real value: 0
    property color accentColor: Theme.accent
    property real rowSpacing: 4

    // Right-aligned readout text, e.g. "+0.35" or "1.20x". Empty hides it.
    property string displayText: ""

    // Click the icon to snap back to `resetValue` (0..1 ratio).
    property bool resettable: false
    property real resetValue: 0

    signal moved(real value)
    signal committed(real value)

    implicitHeight: 38

    readonly property bool hasIcon: root.icon !== ""
    readonly property bool hasLabel: root.label !== ""
    readonly property bool hasDisplay: root.displayText !== ""

    function setFromRatio(v) {
        const clamped = Math.max(0, Math.min(1, v))
        root.value = clamped
        root.moved(clamped)
    }

    Rectangle {
        id: iconBox
        visible: root.hasIcon
        width: 28
        height: 28
        radius: Theme.radius
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.alpha(root.accentColor, 0.10)
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.accentColor
            font.family: Theme.iconFont
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.resettable
            cursorShape: root.resettable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                root.setFromRatio(root.resetValue)
                root.committed(root.value)
            }
        }
    }

    Text {
        id: labelText
        visible: root.hasLabel
        width: 76
        anchors.left: root.hasIcon ? iconBox.right : parent.left
        anchors.leftMargin: root.hasIcon ? root.rowSpacing : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.accentColor
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.letterSpacing: 2
    }

    Text {
        id: valueText
        visible: root.hasDisplay
        width: 44
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.displayText
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Item {
        id: trackArea
        height: 16
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.hasLabel
            ? labelText.right
            : (root.hasIcon ? iconBox.right : parent.left)
        anchors.leftMargin: (root.hasLabel || root.hasIcon) ? root.rowSpacing : 0
        anchors.right: root.hasDisplay ? valueText.left : parent.right
        anchors.rightMargin: root.hasDisplay ? root.rowSpacing : 0

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
                width: track.width * Math.max(0, Math.min(1, root.value))
                height: parent.height
                radius: 2
                color: root.accentColor

                Behavior on width {
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: Theme.animFast }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: 4
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.alpha(root.accentColor, 0.35)
                }
            }

            Rectangle {
                id: handle
                width: 12
                height: 12
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: fill.width - width / 2
                color: Theme.text
                border.color: root.accentColor
                border.width: 2
                scale: dragArea.pressed ? 1.4 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: Theme.animFast }
                }
            }

            // Live percentage readout, shown only while dragging.
            Rectangle {
                id: bubble
                visible: dragArea.pressed
                width: bubbleText.implicitWidth + 12
                height: 20
                radius: 4
                color: Theme.bgCard
                border.width: 1
                border.color: root.accentColor
                y: -handle.height - height - 6
                x: Math.max(
                    0,
                    Math.min(
                        track.width - width,
                        handle.x + handle.width / 2 - width / 2
                    )
                )

                Text {
                    id: bubbleText
                    anchors.centerIn: parent
                    text: Math.round(root.value * 100) + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -6
            preventStealing: true

            onPressed: (mouse) => root.setFromRatio(mouse.x / track.width)
            onPositionChanged: (mouse) => { if (pressed) root.setFromRatio(mouse.x / track.width) }
            onReleased: root.committed(root.value)
        }
    }
}