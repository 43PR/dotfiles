import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

// Drop-in background picture for panels/windows.
//
//     BackgroundImage { anchors.fill: parent }
//
// Pipeline: Image -> (optional blur via MultiEffect) -> OpacityMask (top->bottom fade).
// OpacityMask multiplies the picture's alpha by the mask's alpha, so the fade is a
// true transparency gradient rather than a threshold/crop.
// The blur pass only runs when blur > 0.
Item {
    id: root

    property real radius: Theme.radius
    // true when there is nothing to wait for, or the picture has finished loading
    readonly property bool ready: !Theme.bgImageActive || img.status === Image.Ready

    visible: Theme.bgImageActive

    // Clipped holder: the picture is enlarged around its centre inside it,
    // so the blur/fade stages below stay fixed to the panel.
    Item {
        id: imgHolder
        anchors.fill: parent
        visible: false
        clip: true

        Image {
            id: img
            // picture's own aspect ratio (1 while still loading)
            readonly property real aspect: implicitHeight > 0 ? implicitWidth / implicitHeight : 1
            // smallest size that fully covers the panel, then scaled by ZOOM
            readonly property real coverW: Math.max(parent.width, parent.height * aspect)

            width: coverW * Theme.bgImageZoom
            height: width / aspect
            // centred, then shifted by POSITION X / Y (fraction of the panel)
            x: (parent.width - width) / 2 + parent.width * Theme.bgImagePosX
            y: (parent.height - height) / 2 + parent.height * Theme.bgImagePosY
            source: root.visible ? Theme.bgImageSource : ""
            fillMode: Image.Stretch      // the box already has the right aspect
            asynchronous: true
            cache: true
            mipmap: false   // mipmaps add ~33% memory; sourceSize already decodes near display size
            // Fixed decode width so every panel shares one cached pixmap.
            sourceSize.width: 1280   // raise (e.g. 1920) if the picture looks soft
        }
    }

    // Blur stage (hidden; feeds the mask stage). Disabled blur = plain passthrough.
    MultiEffect {
        id: blurred
        anchors.fill: parent
        source: imgHolder
        visible: false
        blurEnabled: Theme.bgImageBlur > 0.001
        blurMax: 64
        blur: Theme.bgImageBlur
        autoPaddingEnabled: false
    }

    // Alpha mask: top opacity -> bottom opacity, rounded corners.
    Rectangle {
        id: fadeMask
        anchors.fill: parent
        radius: root.radius
        visible: false
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, Theme.bgImageFadeTop) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, Theme.bgImageFadeBottom) }
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: blurred
        maskSource: fadeMask
        visible: img.status === Image.Ready
        opacity: Theme.bgImageOpacity
    }
}