import QtQuick
import QtQuick.Shapes

// Ring gauge: icon inside, arc follows `level` (0..1). The arc turns red while `warning` is set.
// Used by the stat badges (CPU / RAM / GPU / temps), the battery and the volume module.
Item {
    id: rg

    property real level: 0                      // 0..1
    property string glyph: ""                   // icon drawn in the middle
    property string glyphFont: Theme.iconFont   // font family of the glyph
    property color fg: Theme.text               // glyph colour
    property bool warning: false                // arc + glyph turn red from the caller (fg / warning)
    property int diameter: 20                   // outer size in px (callers clamp it to the bar)
    property real strokeRatio: 0.09             // ring thickness as a fraction of the diameter
    property real minStroke: 1.5                // ring thickness never goes below this

    readonly property real stroke: Math.max(minStroke, diameter * strokeRatio)
    property real shownLevel: Math.max(0, Math.min(1, level))
    Behavior on shownLevel { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

    implicitWidth: diameter
    implicitHeight: diameter

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        // track
        ShapePath {
            strokeColor: Qt.alpha(Theme.accent2, 0.2)
            strokeWidth: rg.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: rg.width / 2; centerY: rg.height / 2
                radiusX: (rg.width - rg.stroke) / 2
                radiusY: (rg.height - rg.stroke) / 2
                startAngle: -90; sweepAngle: 360
            }
        }
        // level arc (starts at 12 o'clock, clockwise)
        ShapePath {
            strokeColor: rg.shownLevel <= 0 ? "transparent"
                       : rg.warning ? Theme.danger : Theme.accent2
            strokeWidth: rg.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: rg.width / 2; centerY: rg.height / 2
                radiusX: (rg.width - rg.stroke) / 2
                radiusY: (rg.height - rg.stroke) / 2
                startAngle: -90
                sweepAngle: Math.min(359.9, 360 * rg.shownLevel)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: rg.glyph
        color: rg.fg
        font.family: rg.glyphFont
        font.pixelSize: Math.round(rg.diameter * 0.5)
        renderType: Text.NativeRendering
    }
}
