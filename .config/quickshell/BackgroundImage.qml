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

    Image {
        id: img
        anchors.fill: parent
        visible: false
        source: root.visible ? Theme.bgImageSource : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        mipmap: true
        // Fixed decode width so every panel shares one cached pixmap.
        sourceSize.width: 1920
    }

    // Blur stage (hidden; feeds the mask stage). Disabled blur = plain passthrough.
    MultiEffect {
        id: blurred
        anchors.fill: parent
        source: img
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