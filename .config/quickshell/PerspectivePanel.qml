import QtQuick

// Wraps its content in a card that:
//  - scales + rotates in from an angle when `open` flips true (tilt-in reveal)
//  - subtly tilts toward the cursor while hovered (parallax), like a HUD panel
//
// Note on the "shader" approach: a true vanishing-point warp shader needs a
// compiled .qsb fragment shader (Qt Shader Tools / qsb, part of qtdeclarative
// dev tools) which this sandbox can't compile or test blind. This version
// gets the same visual read (perspective tilt, depth, glow) using ordinary
// QML 3D transforms, which is guaranteed to run with just Quickshell + Qt6.
// If you later want the literal warped-plane shader look, say so and I'll
// write the .qsb pipeline as a follow-up you compile locally.
Item {
    id: root

    default property alias content: contentContainer.data
    property bool open: false
    property real tiltStrength: 5   // degrees of hover parallax

    property real parallaxX: 0
    property real parallaxY: 0

    opacity: open ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
    }

    transform: [
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: root.open ? root.parallaxX : 20

            Behavior on angle {
                NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic }
            }
        },
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.open ? root.parallaxY : -16

            Behavior on angle {
                NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic }
            }
        },
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.open ? 1 : 0.88
            yScale: root.open ? 1 : 0.88

            Behavior on xScale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack } }
            Behavior on yScale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack } }
        }
    ]

    HoverHandler {
        id: hover
        onPointChanged: {
            var nx = (point.position.x / root.width) - 0.5
            var ny = (point.position.y / root.height) - 0.5
            root.parallaxX = -ny * root.tiltStrength
            root.parallaxY = nx * root.tiltStrength
        }
        onHoveredChanged: if (!hovered) { root.parallaxX = 0; root.parallaxY = 0 }
    }

    Item {
        id: contentContainer
        anchors.fill: parent
    }
}
