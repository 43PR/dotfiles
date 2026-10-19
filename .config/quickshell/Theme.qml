pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property int radius: 10
    property real tiltStrength: 7
    readonly property string fontFamily: "JetBrains Mono"
    property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int animFast: 120
    readonly property int animMed: 220
    readonly property int animSlow: 380

    // ---- Global text sizes (px) ----
    readonly property int textSizeTitle: 18     
    readonly property int textSizeSection: 15  
    readonly property int textSizeGroup: 12    
    readonly property int textSizeBody: 11     
    readonly property int textSizeSmall: 10     

    property real bgAlpha: 0.7
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

    // ---- Hub appearance settings (persisted to state/hub.json) ----
    property bool hideSettingsIcons: false
    property bool clickOutsideClose: true

    readonly property var hubKeys: ["tiltStrength", "bgAlpha", "radius", "hideSettingsIcons", "clickOutsideClose"]

    function setHub(key, value) {
        if (hubKeys.indexOf(key) < 0) return
        root[key] = value
        hubSaveTimer.restart()
    }

    function resetHub() {
        tiltStrength = 7
        bgAlpha = 0.7
        radius = 10
        hideSettingsIcons = false
        clickOutsideClose = true
        hubSaveTimer.restart()
    }

    function saveHub() {
        hubFile.setText(JSON.stringify({
            tiltStrength: tiltStrength,
            bgAlpha: bgAlpha,
            radius: radius,
            hideSettingsIcons: hideSettingsIcons,
            clickOutsideClose: clickOutsideClose
        }, null, 2))
    }

    property Timer hubSaveTimer: Timer {
        interval: 300
        onTriggered: root.saveHub()
    }

    property FileView hubFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/state/hub.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                if (typeof s.tiltStrength === "number") root.tiltStrength = Math.max(0, Math.min(15, s.tiltStrength))
                if (typeof s.bgAlpha === "number") root.bgAlpha = Math.max(0.2, Math.min(1, s.bgAlpha))
                if (typeof s.radius === "number") root.radius = Math.round(Math.max(0, Math.min(50, s.radius)))
                if (typeof s.hideSettingsIcons === "boolean") root.hideSettingsIcons = s.hideSettingsIcons
                if (typeof s.clickOutsideClose === "boolean") root.clickOutsideClose = s.clickOutsideClose
            } catch (e) {
                console.warn("Theme.qml: malformed hub.json: " + e)
            }
        }
    }

    // `qs ipc call theme setBgAlpha 0.8` updates every component that uses Theme.bg, live,
    // and saves the value to hub.json (so the Hub page slider stays in sync).
    property IpcHandler ipc: IpcHandler {
        target: "theme"
        function setBgAlpha(value: real): void {
            root.setHub("bgAlpha", Math.max(0.2, Math.min(1, value)))
        }
    }

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