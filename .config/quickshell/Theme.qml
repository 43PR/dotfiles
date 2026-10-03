// Theme.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property int radius: 10
    readonly property real tiltStrength: 7
    readonly property string fontFamily: "JetBrains Mono"
    property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int animFast: 120
    readonly property int animMed: 220
    readonly property int animSlow: 380

    property real bgAlpha: 1.0   
    property color _bgBase: palette.bg || '#000000'
    property color bg: alpha(_bgBase, bgAlpha)
    property real imageOpacity: palette.imageOpacity !== undefined ? Math.max(0, Math.min(1, Number(palette.imageOpacity))) : 0.8
    property color text: palette.text || '#ffffff'
    property color textDim: palette.textDim || '#c2c2c2'
    property color danger: palette.danger || '#ff003c'
    property color accent: palette.accent || '#ffffff'
    property color accent2: palette.accent2 || '#ffffff'
    property color border: palette.border || '#151515'
    property color bgPanel: palette.bgPanel || '#050505'
    property color bgCard: palette.bgCard || '#0d0d0d'
    property color borderAccent: palette.borderAccent || '#2a2a2a'
    property color textFaint: palette.textFaint || '#4a4a4a'
    property color ok: palette.ok || '#00ff9c'
    property color trackBg: palette.trackBg || '#161616'

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    property var palette: ({})

    property FileView themeFile: FileView {
        path: Qt.resolvedUrl(Quickshell.env("HOME") + "/.cache/43pr/quickshell-theme.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.palette = JSON.parse(text())
            } catch (e) {
                console.warn("Theme.qml: malformed quickshell-theme.json: " + e)
            }
        }
    }
}
