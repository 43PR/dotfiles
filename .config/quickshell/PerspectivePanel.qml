// PerspectivePanel.qml
import QtQuick
Item {
    id: root

    default property alias content: contentContainer.data
    property bool open: false
    property real tiltStrength: Theme.tiltStrength
    property real parallaxX: 0
    property real parallaxY: 0
    readonly property bool hovered: hover.hovered

    // ---- open timings (unchanged defaults) --------------------------------
    property int fadeDuration: Theme.animMed
    property int popDuration: Theme.animSlow
    property int tiltDuration: Theme.animSlow
    property int popEasing: Easing.OutBack
    property real closedScale: 0.88

    // ---- close timings: faster than opening --------------------------------
    // closeSpeed 1.0 = same as open, 2.0 = twice as fast
    property real closeSpeed: 2.2
    property int closeEasing: Easing.InCubic   // OutBack on close overshoots; InCubic feels snappier

    readonly property int _fade: open ? fadeDuration : Math.round(fadeDuration / closeSpeed)
    readonly property int _pop:  open ? popDuration  : Math.round(popDuration  / closeSpeed)
    readonly property int _tilt: open ? tiltDuration : Math.round(tiltDuration / closeSpeed)
    readonly property int _popEase: open ? popEasing : closeEasing

    property bool cacheContent: false
    property bool prewarm: false

    opacity: open ? 1 : (prewarm ? 0.004 : 0)
    visible: opacity > 0.001

    readonly property bool needsLayer: cacheContent && visible && (
        prewarm || hover.hovered || opacity < 0.999
        || Math.abs(rotX.angle) > 0.05 || Math.abs(rotY.angle) > 0.05
        || scaleT.xScale < 0.999)

    layer.enabled: needsLayer
    layer.smooth: true

    Behavior on opacity {
        NumberAnimation { duration: root._fade; easing.type: Easing.OutCubic }
    }

    transform: [
        Rotation {
            id: rotX
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            // open: follow hover parallax | closing: flat | hidden: entry pose for next open
            angle: root.open ? root.parallaxX : (root.visible ? 0 : 20)

            Behavior on angle {
                enabled: root.open || root.visible   // hidden reset snaps, no animation
                NumberAnimation { duration: root._tilt; easing.type: Easing.OutCubic }
            }
        },
        Rotation {
            id: rotY
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.open ? root.parallaxY : (root.visible ? 0 : -16)

            Behavior on angle {
                enabled: root.open || root.visible
                NumberAnimation { duration: root._tilt; easing.type: Easing.OutCubic }
            }
        },
        Scale {
            id: scaleT
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.open ? 1 : root.closedScale
            yScale: root.open ? 1 : root.closedScale

            Behavior on xScale { NumberAnimation { duration: root._pop; easing.type: root._popEase } }
            Behavior on yScale { NumberAnimation { duration: root._pop; easing.type: root._popEase } }
        }
    ]

    HoverHandler {
        id: hover
        enabled: root.open
        onPointChanged: {
            if (!root.open) return
            var nx = (point.position.x / root.width) - 0.5
            var ny = (point.position.y / root.height) - 0.5
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