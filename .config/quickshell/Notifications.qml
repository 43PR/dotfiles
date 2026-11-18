import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Notification popup SETTINGS only.
//
// This file no longer shows any popup and no longer runs a NotificationServer.
// Your original popup (the one with the copy icon) is the only popup; it reads
// the values saved here from
//     ~/.config/quickshell/state/notifications-state.json
//
//   - qs ipc call notifications settings    open / close this window
//   - right-click the original popup        calls the same IPC command
//
// Uses the reusable components from CustomizationSettings.qml (same directory).
Scope {
    id: root

    // ---- host interface required by CustomizationSettings ------------------
    readonly property real menuUi: 1.0
    readonly property color cAccent: Theme.accent

    readonly property QtObject th: QtObject {
        readonly property real radius: 10
        readonly property string fontFamily: "JetBrains Mono"
        readonly property int animFast: 120
        readonly property int animMed: 220
        readonly property int textSizeGroup: 12
        readonly property int textSizeBody: 11
        readonly property int textSizeSmall: 10
    }

    readonly property var numSpec: ({
        popupWidth:  { min: 240,  max: 600,   def: 310,  step: 10,  unit: " px" },
        popupHeight: { min: 56,   max: 240,   def: 56,   step: 2,   unit: " px" },
        uiScale:     { min: 70,   max: 160,   def: 90,   step: 5,   unit: " %" },
        textSize:    { min: 9,    max: 28,    def: 12,   step: 1,   unit: " px" },
        bgOpacity:   { min: 0,    max: 100,   def: 50,   step: 5,   unit: " %" },
        radius:      { min: 0,    max: 60,    def: 12,   step: 1,   unit: " px" },
        showMs:      { min: 1000, max: 15000, def: 5000, step: 500, unit: " ms" },
        animMs:      { min: 0,    max: 500,   def: 150,  step: 25,  unit: " ms" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showIcon: true,
        showBody: true,
        showBorder: true,
        hoverPause: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    // ---- settings values (saved to the state file) -------------------------
    property int popupWidth: numSpec.popupWidth.def
    property int popupHeight: numSpec.popupHeight.def
    property int uiScale: numSpec.uiScale.def
    property int textSize: numSpec.textSize.def
    property int bgOpacity: numSpec.bgOpacity.def
    property int radius: numSpec.radius.def
    property int showMs: numSpec.showMs.def
    property int animMs: numSpec.animMs.def

    property bool showIcon: boolDefaults.showIcon
    property bool showBody: boolDefaults.showBody
    property bool showBorder: boolDefaults.showBorder
    property bool hoverPause: boolDefaults.hoverPause

    property bool settingsOpen: false

    // the settings window registers its Flickable here (for ensureVisible)
    property Item flickItem: null

    readonly property bool modified:
        numKeys.some(k => root[k] !== numSpec[k].def)
        || boolKeys.some(k => root[k] !== boolDefaults[k])

    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/state/notifications-state.json"

    // ---- functions used by CustomizationSettings ---------------------------
    function cellW(p) { return p ? p.width : 0 }

    function focusStep(item, forward) {
        var n = item.nextItemInFocusChain(forward)
        if (n) n.forceActiveFocus()
    }

    function ensureVisible(item, margin) {
        var f = root.flickItem
        if (!f || !item) return
        var y = item.mapToItem(f.contentItem, 0, 0).y
        var h = item.height
        if (y - margin < f.contentY)
            f.contentY = Math.max(0, y - margin)
        else if (y + h + margin > f.contentY + f.height)
            f.contentY = Math.max(0, Math.min(f.contentHeight - f.height,
                                              y + h + margin - f.height))
    }

    function fmtValue(key, v) {
        var s = numSpec[key]
        return v + (s ? s.unit : "")
    }

    function setNumber(key, v) {
        var s = numSpec[key]
        root[key] = Math.max(s.min, Math.min(s.max, Math.round(v)))
        saveState()                       // debounced: popup updates while dragging
    }

    function toggleSetting(key) {
        root[key] = !root[key]
        saveState()
    }

    function resetAll() {
        numKeys.forEach(k => { root[k] = numSpec[k].def })
        boolKeys.forEach(k => { root[k] = boolDefaults[k] })
        saveState()
    }

    function saveState() { saveTimer.restart() }
    function openSettings() {
        settingsOpen = true
        uiFlag.setText('{"open":true}')
        sendTest()          // shows a popup to adjust; remove this line if you don't want it
    }
    function closeSettings() {
        settingsOpen = false
        uiFlag.setText('{"open":false}')
        saveState()
    }
    function toggleSettings() { settingsOpen ? closeSettings() : openSettings() }

    function sendTest() {
        Quickshell.execDetached(["notify-send", "Test notification", "Body message"])
    }

    // ---- persistence ---------------------------------------------------------
    Timer {
        id: saveTimer
        interval: 120
        onTriggered: {
            var s = {}
            root.numKeys.concat(root.boolKeys).forEach(k => { s[k] = root[k] })
            stateFile.setText(JSON.stringify(s))
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                root.numKeys.forEach(k => { if (typeof s[k] === "number") root.setNumber(k, s[k]) })
                root.boolKeys.forEach(k => { if (typeof s[k] === "boolean") root[k] = s[k] })
            } catch (e) {
                console.warn("notification settings: could not read saved state:", e)
            }
        }
    }
    // tells SidePanel the settings window is open, so popups stay on screen
    FileView {
        id: uiFlag
        path: Quickshell.env("HOME") + "/.config/quickshell/state/notifications-ui.json"
        printErrors: false
    }
    // clear a stale flag after a crash or reload
    Component.onCompleted: uiFlag.setText('{"open":false}')
    IpcHandler {
        target: "notifications"
        function settings(): void { root.toggleSettings() }
    }

    // ---- settings window: only exists while open -----------------------------
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin
            screen: Quickshell.screens[0]

            color: "transparent"
            implicitWidth: Math.round(380 * root.menuUi)
            implicitHeight: Math.min(Math.round(560 * root.menuUi),
                                     (screen?.height ?? 800) * 0.85)
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.bg
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.12)
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.closeSettings()

                // ---- header ----
                Item {
                    id: head
                    anchors.top: parent.top
                    width: parent.width
                    height: 54

                    Text {
                        x: 20; y: 10
                        text: "Notification popup settings"
                        font.family: root.th.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.text
                    }
                    Text {
                        x: 20; y: 31
                        text: "Changes are applied to the popup live."
                        font.family: root.th.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        y: 8
                        width: 26; height: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "×"
                        font.family: root.th.fontFamily
                        font.pixelSize: 22
                        color: closeArea.containsMouse ? Theme.text : Theme.textDim
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.closeSettings()
                        }
                    }
                }

                // ---- scrolling rows (reusable components) ----
                Flickable {
                    id: flick
                    anchors.top: head.bottom
                    anchors.bottom: foot.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    contentWidth: width
                    contentHeight: rowsCol.height + 12
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Component.onCompleted: root.flickItem = flick
                    Component.onDestruction: if (root.flickItem === flick) root.flickItem = null

                    Column {
                        id: rowsCol
                        x: 20
                        width: flick.width - 40

                        // ---- Size ----
                        CustomizationSettings.SectionHeader { host: root; text: "Size" }
                        CustomizationSettings.SliderRow { host: root; key: "popupWidth";  label: "Width" }
                        CustomizationSettings.SliderRow { host: root; key: "popupHeight"; label: "Height" }
                        CustomizationSettings.SliderRow { host: root; key: "uiScale";     label: "Scale" }
                        CustomizationSettings.SliderRow { host: root; key: "radius";      label: "Corner radius" }

                        // ---- Text ----
                        CustomizationSettings.SectionHeader { host: root; text: "Text" }
                        CustomizationSettings.SliderRow { host: root; key: "textSize"; label: "Text size" }
                        CustomizationSettings.ToggleRow { host: root; key: "showBody"; label: "Show message text" }
                        CustomizationSettings.ToggleRow { host: root; key: "showIcon"; label: "Show icon / image" }

                        // ---- Appearance ----
                        CustomizationSettings.SectionHeader { host: root; text: "Appearance" }
                        CustomizationSettings.SliderRow { host: root; key: "bgOpacity";  label: "Background opacity" }
                        CustomizationSettings.ToggleRow { host: root; key: "showBorder"; label: "Border" }

                        // ---- Behavior ----
                        CustomizationSettings.SectionHeader { host: root; text: "Behavior" }
                        CustomizationSettings.SliderRow { host: root; key: "showMs"; label: "Display time" }
                        CustomizationSettings.SliderRow { host: root; key: "animMs"; label: "Animation duration" }
                        CustomizationSettings.ToggleRow { host: root; key: "hoverPause"; label: "Stay open while hovered" }
                    }
                }

                // ---- footer ----
                Item {
                    id: foot
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 56

                    Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.text, 0.08) }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        CustomizationSettings.ActionButton {
                            host: root
                            label: "Reset all"
                            enabled: root.modified
                            onClicked: root.resetAll()
                        }
                        CustomizationSettings.ActionButton {
                            host: root
                            label: "Send test"
                            onClicked: root.sendTest()
                        }
                    }

                    CustomizationSettings.ActionButton {
                        host: root
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Done"
                        primary: true
                        onClicked: root.closeSettings()
                    }
                }
            }
        }
    }
}