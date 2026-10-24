pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

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

    // ---- Global border opacity (Hyprland window borders + Theme.accent) ----
    property real borderOpacity: 1.0

    // ---- Hyprland window border style ----
    property string hyprBorderStyle: "full"   // "full" | "corner"

    property color _bgBase: palette.bg || '#000000'
    property color bg: alpha(_bgBase, bgAlpha)
    property real imageOpacity: palette.imageOpacity !== undefined ? Math.max(0, Math.min(1, Number(palette.imageOpacity))) : 0.8
    property color text: palette.text || '#ffffff'
    property color textDim: palette.textDim || '#c2c2c2'
    property color danger: palette.danger || '#ff003c'

    // accentSolid = raw palette accent (full opacity). Use it where you need an
    // opaque accent (text, icons, Hyprland colour generation).
    // accent      = accentSolid * borderOpacity. This is what your components use
    // for borders, so the global border opacity slider affects all of them.
    property color accentSolid: palette.accent || '#ffffff'
    property color accent: alpha(accentSolid, borderOpacity)

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

    readonly property var hubKeys: ["tiltStrength", "bgAlpha", "radius", "hideSettingsIcons", "clickOutsideClose", "borderOpacity", "hyprBorderStyle"]

    function setHub(key, value) {
        if (hubKeys.indexOf(key) < 0) return
        root[key] = value
        hubSaveTimer.restart()
    }

    function resetHub() {
        tiltStrength = 7
        bgAlpha = 0.7
        radius = 10
        borderOpacity = 1.0
        hyprBorderStyle = "full"
        hideSettingsIcons = false
        clickOutsideClose = true
        hubSaveTimer.restart()
    }

    function saveHub() {
        hubFile.setText(JSON.stringify({
            tiltStrength: tiltStrength,
            bgAlpha: bgAlpha,
            radius: radius,
            borderOpacity: borderOpacity,
            hyprBorderStyle: hyprBorderStyle,
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
                if (typeof s.borderOpacity === "number") root.borderOpacity = Math.max(0.1, Math.min(1, s.borderOpacity))
                if (s.hyprBorderStyle === "full" || s.hyprBorderStyle === "corner") root.hyprBorderStyle = s.hyprBorderStyle
                if (typeof s.hideSettingsIcons === "boolean") root.hideSettingsIcons = s.hideSettingsIcons
                if (typeof s.clickOutsideClose === "boolean") root.clickOutsideClose = s.clickOutsideClose
            } catch (e) {
                console.warn("Theme.qml: malformed hub.json: " + e)
            }
            root.hubReady = true
            root.borderTimer.restart()
        }
        onLoadFailed: error => {
            root.hubReady = true
            root.borderTimer.restart()
        }
    }

    // `qs ipc call theme setBgAlpha 0.8` updates every component that uses Theme.bg, live,
    // and saves the value to hub.json (so the Hub page slider stays in sync).
    // `qs ipc call theme setBorderOpacity 0.6` does the same for border opacity.
    property IpcHandler ipc: IpcHandler {
        target: "theme"
        function setBgAlpha(value: real): void {
            root.setHub("bgAlpha", Math.max(0.2, Math.min(1, value)))
        }
        function setBorderStyle(style: string): void {
            if (style === "full" || style === "corner") root.setHub("hyprBorderStyle", style)
        }
        function setBorderOpacity(value: real): void {
            root.setHub("borderOpacity", Math.max(0.1, Math.min(1, value)))
        }
    }

    // ------------------------------------------------------------------
    // Hyprland window border colours
    // Lives here (not in a settings page) so it runs whenever the palette,
    // opacity or style changes, even if the settings window was never opened.
    // ------------------------------------------------------------------
    property bool hubReady: false
    property bool paletteReady: false
    property double lastApplyMs: 0
    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"

    onAccentSolidChanged: borderTimer.restart()
    onBorderChanged: borderTimer.restart()
    onBorderOpacityChanged: borderTimer.restart()
    onHyprBorderStyleChanged: borderTimer.restart()

    function _hex2(v) {
        const h = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
        return h.length < 2 ? "0" + h : h
    }

    function _hypr(c, a) {
        return "rgba(" + _hex2(c.r) + _hex2(c.g) + _hex2(c.b) + _hex2(a) + ")"
    }

    // Lua expression for one border colour.
    // "corner": 45deg gradient, solid at top-left / bottom-right, transparent between.
    function _borderLua(c) {
        const on = "\"" + _hypr(c, borderOpacity) + "\""
        if (hyprBorderStyle === "corner") {
            const off = "\"" + _hypr(c, 0) + "\""
            return "{ colors = { " + [on, on, off, off, off, on, on].join(", ") + " }, angle = 45 }"
        }
        return on
    }

    function borderLua() {
        return "hl.config({ general = { col = { active_border = " + _borderLua(accentSolid)
            + ", inactive_border = " + _borderLua(border) + " } } })"
    }

    function applyBorders() {
        if (!hubReady || !paletteReady) return
        if (borderApply.running) { borderTimer.restart(); return }
        lastApplyMs = Date.now()
        const lua = borderLua()
        borderFile.setText("-- generated by Theme.qml (border colours)\n" + lua + "\n")
        borderApply.command = ["sh", "-c", "hyprctl eval '" + lua + "'"]
        borderApply.running = true
    }

    // Hyprland drops hyprctl-eval'd settings on every config reload (the colour
    // generator / preset switcher usually triggers one), which resets borders to
    // the default white. Re-apply whenever a reload finishes.
    property Connections hyprEvents: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" && Date.now() - root.lastApplyMs > 500)
                root.borderTimer.restart()
        }
    }

    property Timer borderTimer: Timer {
        interval: 150
        onTriggered: root.applyBorders()
    }

    property Process mkStateDir: Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    // Load this from hyprland.lua after look.lua so colours survive reloads/reboots.
    property FileView borderFile: FileView {
        path: root.stateDir + "/border.lua"
        preload: false   // write-only
    }

    property Process borderApply: Process {
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) console.warn("[border] hyprctl error:", text.trim())
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
                root.paletteReady = true
            } catch (e) {
                console.warn("Theme.qml: malformed quickshell-theme.json: " + e)
            }
            root.borderTimer.restart()
        }
    }
}