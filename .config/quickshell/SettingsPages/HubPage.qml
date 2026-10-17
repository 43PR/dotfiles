import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property real labelWidth: 200

    // Corner accent opacity. The settings window owns the value (it draws the accents,
    // persists it and pushes it in when this page loads); this page only edits it.
    property real accentOpacity: 1.0
    signal accentOpacityEdited(real value)      // live, while dragging
    signal accentOpacityCommitted(real value)   // on release: save it

    // Slider ranges. Opacity stops at 20% so the window can't become invisible.
    readonly property real opacityMin: 0.2
    readonly property real opacityMax: 1.0
    readonly property real tiltMin: 0
    readonly property real tiltMax: 15
    readonly property real radiusMin: 0
    readonly property real radiusMax: 35
    readonly property real accentOpacityMin: 0.0
    readonly property real accentOpacityMax: 1.0

    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    function round2(v) { return Math.round(v * 100) / 100 }

    // Theme.setHub() also persists to state/hub.json; the state dir must exist.
    Process {
        id: stateDirProcess
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.config/quickshell/state"]
    }

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
                text: "HUB"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Row {
                spacing: 10

                Text {
                    text: "APPEARANCE"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true; font.letterSpacing: 2
                }
            }

            Rectangle {
                width: parent.width
                height: appearanceColumn.implicitHeight + 20
                radius: Theme.radius
                color: "#00000000"; border.width: 1; border.color: Theme.border

                Column {
                    id: appearanceColumn
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6

                    // ---- background opacity ----
                    Row {
                        width: parent.width; spacing: 8

                        Text {
                            width: page.labelWidth
                            anchors.verticalCenter: parent.verticalCenter
                            text: "BACKGROUND OPACITY"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }

                        Slider {
                            width: parent.width - page.labelWidth - 52 - 16
                            anchors.verticalCenter: parent.verticalCenter
                            label: ""; icon: ""
                            value: page.clamp01((Theme.bgAlpha - page.opacityMin) / (page.opacityMax - page.opacityMin))
                            onMoved: value => Theme.bgAlpha = page.opacityMin + page.clamp01(value) * (page.opacityMax - page.opacityMin)
                            onCommitted: value => Theme.setHub("bgAlpha", page.round2(page.opacityMin + page.clamp01(value) * (page.opacityMax - page.opacityMin)))
                        }

                        Text {
                            width: 52
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(Theme.bgAlpha * 100) + "%"
                            color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                    }
                    // ---- corner accent opacity ----
                    Row {
                        width: parent.width; spacing: 8

                        Text {
                            width: page.labelWidth
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CORNER ACCENT OPACITY"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }

                        Slider {
                            width: parent.width - page.labelWidth - 52 - 16
                            anchors.verticalCenter: parent.verticalCenter
                            label: ""; icon: ""
                            value: page.clamp01((page.accentOpacity - page.accentOpacityMin) / (page.accentOpacityMax - page.accentOpacityMin))
                            onMoved: value => {
                                page.accentOpacity = page.round2(page.accentOpacityMin + page.clamp01(value) * (page.accentOpacityMax - page.accentOpacityMin))
                                page.accentOpacityEdited(page.accentOpacity)
                            }
                            onCommitted: value => {
                                page.accentOpacity = page.round2(page.accentOpacityMin + page.clamp01(value) * (page.accentOpacityMax - page.accentOpacityMin))
                                page.accentOpacityCommitted(page.accentOpacity)
                            }
                        }

                        Text {
                            width: 52
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(page.accentOpacity * 100) + "%"
                            color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                    }
                    // ---- corner radius ----
                    Row {
                        width: parent.width; spacing: 8

                        Text {
                            width: page.labelWidth
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CORNER RADIUS"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }

                        Slider {
                            width: parent.width - page.labelWidth - 52 - 16
                            anchors.verticalCenter: parent.verticalCenter
                            label: ""; icon: ""
                            value: page.clamp01((Theme.radius - page.radiusMin) / (page.radiusMax - page.radiusMin))
                            onMoved: value => Theme.radius = Math.round(page.radiusMin + page.clamp01(value) * (page.radiusMax - page.radiusMin))
                            onCommitted: value => Theme.setHub("radius", Math.round(page.radiusMin + page.clamp01(value) * (page.radiusMax - page.radiusMin)))
                        }

                        Text {
                            width: 52
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(Theme.radius) + "px"
                            color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                    }
                    // ---- tilt strength ----
                    Row {
                        width: parent.width; spacing: 8

                        Text {
                            width: page.labelWidth
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TILT STRENGTH"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }

                        Slider {
                            width: parent.width - page.labelWidth - 52 - 16
                            anchors.verticalCenter: parent.verticalCenter
                            label: ""; icon: ""
                            value: page.clamp01((Theme.tiltStrength - page.tiltMin) / (page.tiltMax - page.tiltMin))
                            onMoved: value => Theme.tiltStrength = page.tiltMin + page.clamp01(value) * (page.tiltMax - page.tiltMin)
                            onCommitted: value => Theme.setHub("tiltStrength", page.round2(page.tiltMin + page.clamp01(value) * (page.tiltMax - page.tiltMin)))
                        }

                        Text {
                            width: 52
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Theme.tiltStrength.toFixed(1)
                            color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                    }

                    // ---- hide sidebar icons ----
                    Row {
                        width: parent.width; height: 28; spacing: 8

                        Text {
                            width: page.labelWidth; height: 28
                            verticalAlignment: Text.AlignVCenter
                            text: "HIDE SIDEBAR ICONS"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }

                        Rectangle {
                            width: 64; height: 28; radius: Theme.radius
                            color: Theme.hideSettingsIcons ? Theme.alpha(Theme.accent, 0.10) : (iconsMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                            border.width: 1
                            border.color: Theme.hideSettingsIcons || iconsMouse.containsMouse ? Theme.accent : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: Theme.hideSettingsIcons ? "ON" : "OFF"
                                color: Theme.hideSettingsIcons ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                            }

                            MouseArea {
                                id: iconsMouse
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.setHub("hideSettingsIcons", !Theme.hideSettingsIcons)
                            }
                        }
                    }

                    // ---- click outside closes ----
                    Row {
                        width: parent.width; height: 28; spacing: 8

                        Text {
                            width: page.labelWidth; height: 28
                            verticalAlignment: Text.AlignVCenter
                            text: "CLOSE ON OUTSIDE CLICK"; color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: 11
                        }

                        Rectangle {
                            width: 64; height: 28; radius: Theme.radius
                            color: Theme.clickOutsideClose ? Theme.alpha(Theme.accent, 0.10) : (outsideMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                            border.width: 1
                            border.color: Theme.clickOutsideClose || outsideMouse.containsMouse ? Theme.accent : Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: Theme.clickOutsideClose ? "ON" : "OFF"
                                color: Theme.clickOutsideClose ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                            }

                            MouseArea {
                                id: outsideMouse
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.setHub("clickOutsideClose", !Theme.clickOutsideClose)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 34; radius: Theme.radius
                color: resetMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                border.width: 1
                border.color: resetMouse.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent; text: "RESET APPEARANCE"; color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Theme.resetHub()
                        page.accentOpacity = 1.0
                        page.accentOpacityCommitted(1.0)
                    }
                }
            }
        }
    }

    Component.onCompleted: stateDirProcess.running = true
}