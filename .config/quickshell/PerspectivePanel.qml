// PerspectivePanel.qml
import QtQuick
Item {
    id: root

    default property alias content: contentContainer.data
    property bool open: false
    property real tiltStrength: Theme.tiltStrength
    property real parallaxX: 0
    property real parallaxY: 0
    readonly property bool hovered: hover.hovered   // used by the settings window for Esc

    // ---- optional knobs; defaults keep the previous behaviour -------------
    property int fadeDuration: Theme.animMed
    property int popDuration: Theme.animSlow
    property int tiltDuration: Theme.animSlow
    property int popEasing: Easing.OutBack
    property real closedScale: 0.88

    property bool cacheContent: false
    property bool prewarm: false

    opacity: open ? 1 : (prewarm ? 0.004 : 0)
    visible: opacity > 0.001

    // Cached texture only while it saves work (fade / pop / tilt / hover / prewarm).
    // At rest the card renders directly: no FBO pass, no extra texture, crisper text.
    readonly property bool needsLayer: cacheContent && visible && (
        prewarm || hover.hovered || opacity < 0.999
        || Math.abs(rotX.angle) > 0.05 || Math.abs(rotY.angle) > 0.05
        || scaleT.xScale < 0.999)

    layer.enabled: needsLayer
    layer.smooth: true

    Behavior on opacity {
        NumberAnimation { duration: root.fadeDuration; easing.type: Easing.OutCubic }
    }

    transform: [
        Rotation {
            id: rotX
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: root.open ? root.parallaxX : 20

            Behavior on angle {
                NumberAnimation { duration: root.tiltDuration; easing.type: Easing.OutCubic }
            }
        },
        Rotation {
            id: rotY
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.open ? root.parallaxY : -16

            Behavior on angle {
                NumberAnimation { duration: root.tiltDuration; easing.type: Easing.OutCubic }
            }
        },
        Scale {
            id: scaleT
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.open ? 1 : root.closedScale
            yScale: root.open ? 1 : root.closedScale

            Behavior on xScale { NumberAnimation { duration: root.popDuration; easing.type: root.popEasing } }
            Behavior on yScale { NumberAnimation { duration: root.popDuration; easing.type: root.popEasing } }
        }
    ]

    HoverHandler {
        id: hover
        enabled: root.open
        onPointChanged: {
            if (!root.open) return
            var nx = (point.position.x / root.width) - 0.5
            var ny = (point.position.y / root.height) - 0.5
            // quantize to 0.25 deg: tiny mouse moves no longer retarget the animations
            root.parallaxX = Math.round(-ny * root.tiltStrength * 4) / 4
            root.parallaxY = Math.round( nx * root.tiltStrength * 4) / 4
        }
        onHoveredChanged: if (!hovered) { root.parallaxX = 0; root.parallaxY = 0 }
    }

    Item {
        id: contentContainer
        anchors.fill: parent
    }
}