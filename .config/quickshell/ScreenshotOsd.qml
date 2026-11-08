import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Scope {
    id: root

    // ---- OSD state ---------------------------------------------------------
    property bool showing: false
    property bool cancelled: false
    property string imagePath: ""

    property string kind: "screenshot"   // "screenshot" | "ocr"
    property string ocrState: ""         // "working" | "done" | "empty" | "cancelled"
    property string ocrText: ""

    // window size, reported by the OSD window (used to keep the card on screen)
    property real winW: 0
    property real winH: 0

    readonly property int topGap: 30         // default distance from the top edge
    readonly property int keepVisible: 40    // px that must stay on screen when dragged

    // ---- settings (right-click the OSD, or `qs ipc call screenshot settings`) ----
    // radius and imageRadius share the same default on purpose.
    readonly property var numSpec: ({
        osdWidth:    { min: 240,  max: 600,  def: 320,  step: 10,  unit: " px" },
        osdHeight:   { min: 56,   max: 200,  def: 84,   step: 2,   unit: " px" },
        radius:      { min: 0,    max: 100,  def: 20,   step: 1,   unit: " px" },
        thumbSize:   { min: 24,   max: 150,  def: 60,   step: 2,   unit: " px" },
        imageRadius: { min: 0,    max: 75,   def: 20,   step: 1,   unit: " px" },
        textSize:    { min: 9,    max: 28,   def: 13,   step: 1,   unit: " px" },
        bgOpacity:   { min: 0,    max: 100,  def: 80,   step: 5,   unit: " %" },
        showMs:      { min: 1000, max: 8000, def: 2200, step: 200, unit: " ms" },
        animMs:      { min: 0,    max: 500,  def: 150,  step: 25,  unit: " ms" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showThumb: true,
        showDetail: true,
        showBorder: false,
        hoverPause: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    readonly property var posKeys: ["offsetX", "offsetY"]

    // rows of the settings window: header / slider / toggle
    readonly property var settingRows: [
        { type: "header", label: "Size" },
        { type: "slider", key: "osdWidth",    label: "Width" },
        { type: "slider", key: "osdHeight",   label: "Height" },
        { type: "slider", key: "radius",      label: "Corner radius" },

        { type: "header", label: "Thumbnail" },
        { type: "toggle", key: "showThumb",   label: "Show thumbnail" },
        { type: "slider", key: "thumbSize",   label: "Thumbnail size" },
        { type: "slider", key: "imageRadius", label: "Image corner radius" },

        { type: "header", label: "Text" },
        { type: "slider", key: "textSize",    label: "Text size" },
        { type: "toggle", key: "showDetail",  label: "File name / text preview" },

        { type: "header", label: "Appearance" },
        { type: "slider", key: "bgOpacity",   label: "Background opacity" },
        { type: "toggle", key: "showBorder",  label: "Border" },

        { type: "header", label: "Behavior" },
        { type: "slider", key: "showMs",      label: "Display time" },
        { type: "slider", key: "animMs",      label: "Animation duration" },
        { type: "toggle", key: "hoverPause",  label: "Stay open while hovered" }
    ]

    property real offsetX: 0
    property real offsetY: 0

    property int osdWidth: numSpec.osdWidth.def
    property int osdHeight: numSpec.osdHeight.def
    property int radius: numSpec.radius.def
    property int thumbSize: numSpec.thumbSize.def
    property int imageRadius: numSpec.imageRadius.def
    property int textSize: numSpec.textSize.def
    property int bgOpacity: numSpec.bgOpacity.def
    property int showMs: numSpec.showMs.def
    property int animMs: numSpec.animMs.def

    property bool showThumb: boolDefaults.showThumb
    property bool showDetail: boolDefaults.showDetail
    property bool showBorder: boolDefaults.showBorder
    property bool hoverPause: boolDefaults.hoverPause

    property bool settingsOpen: false
    property bool dragging: false

    readonly property bool moved: offsetX !== 0 || offsetY !== 0
    readonly property bool modified: moved
        || numKeys.some(k => root[k] !== numSpec[k].def)
        || boolKeys.some(k => root[k] !== boolDefaults[k])

    readonly property string statePath:
        Quickshell.env("HOME") + "/.config/quickshell/state/screenshotosd-state.json"

    function setNumber(key, v) {
        var s = numSpec[key]
        root[key] = Math.max(s.min, Math.min(s.max, Math.round(v)))
    }

    function toggleSetting(key) {
        root[key] = !root[key]
        saveState()
    }

    // Only called while dragging. Keeps at least `keepVisible` px on screen.
    function setPosition(x, y) {
        var nx = x, ny = y
        if (winW > 0 && winH > 0) {
            nx = Math.max(keepVisible - winW / 2 - osdWidth / 2,
                          Math.min(winW / 2 - keepVisible + osdWidth / 2, x))
            ny = Math.max(-topGap, Math.min(Math.max(-topGap, winH - keepVisible - topGap), y))
        }
        offsetX = nx
        offsetY = ny
    }

    function resetPosition() {
        offsetX = 0
        offsetY = 0
        saveState()
    }

    function resetAll() {
        offsetX = 0
        offsetY = 0
        numKeys.forEach(k => { root[k] = numSpec[k].def })
        boolKeys.forEach(k => { root[k] = boolDefaults[k] })
        saveState()
    }

    function saveState() {
        saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            var s = {}
            root.posKeys.concat(root.numKeys, root.boolKeys).forEach(k => { s[k] = root[k] })
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
                root.posKeys.forEach(k => { if (typeof s[k] === "number") root[k] = s[k] })
                root.numKeys.forEach(k => { if (typeof s[k] === "number") root.setNumber(k, s[k]) })
                root.boolKeys.forEach(k => { if (typeof s[k] === "boolean") root[k] = s[k] })
            } catch (e) {
                console.warn("screenshotosd: could not read saved state:", e)
            }
        }
    }

    function openSettings() {
        if (!showing) {
            // show a placeholder so there is something to tweak
            kind = "screenshot"
            cancelled = false
            ocrState = ""
            ocrText = ""
            imagePath = ""
            showing = true
        }
        hideTimer.stop()
        settingsOpen = true
    }

    function closeSettings() {
        settingsOpen = false
        dragging = false
        saveState()
        hideTimer.interval = 1200
        hideTimer.restart()
    }

    function toggleSettings() { settingsOpen ? closeSettings() : openSettings() }

    readonly property bool isOcr: kind === "ocr"
    readonly property string titleText: {
        if (isOcr) {
            switch (ocrState) {
            case "working":   return "Reading text…"
            case "done":      return "Text copied"
            case "empty":     return "No text found"
            default:          return "OCR cancelled"
            }
        }
        return cancelled ? "Screenshot cancelled" : "Screenshot saved"
    }
    readonly property string subText: {
        if (isOcr) {
            switch (ocrState) {
            case "working":   return "Please wait"
            case "done":      return "Copied to clipboard"
            case "empty":     return "Try a larger area"
            default:          return "No area selected"
            }
        }
        return cancelled ? "No area selected" : "Copied to clipboard"
    }

    function showOsd(path) {
        kind = "screenshot"
        cancelled = false
        ocrState = ""
        ocrText = ""
        imagePath = path
        showing = true
        hideTimer.interval = root.showMs
        hideTimer.restart()
    }

    function showCancelled() {
        kind = "screenshot"
        cancelled = true
        ocrState = ""
        ocrText = ""
        imagePath = ""
        showing = true
        hideTimer.interval = root.showMs
        hideTimer.restart()
    }

    function showOcr(state, text) {
        kind = "ocr"
        ocrState = state
        ocrText = text
        cancelled = false
        imagePath = ""
        showing = true
        // "working" gets a long fallback so the OSD can't get stuck if the script dies
        hideTimer.interval = state === "working" ? 15000 : root.showMs
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 2200
        repeat: false
        onTriggered: {
            // stays up while settings are open, while dragging, or while hovered
            if (root.settingsOpen || root.dragging || (root.hoverPause && flyoutHover.hovered))
                hideTimer.restart()
            else
                root.showing = false
        }
    }

    IpcHandler {
        target: "screenshot"
        function notify(path: string): void {
            root.showOsd(path)
        }
        function cancelled(): void {
            root.showCancelled()
        }
        function settings(): void {
            root.openSettings()
        }
    }

    IpcHandler {
        target: "ocr"
        function working(): void { root.showOcr("working", "") }
        function done(preview: string): void { root.showOcr("done", preview) }
        function empty(): void { root.showOcr("empty", "") }
        function cancelled(): void { root.showOcr("cancelled", "") }
    }

    // ---- the OSD window ------------------------------------------------------
    // Covers the whole screen so the card can be dragged anywhere; only the card
    // itself receives input (mask).
    PanelWindow {
        id: win
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Unmap the surface when idle; stay mapped during the fade-out
        visible: root.showing || flyout.opacity > 0

        mask: Region {
            item: root.showing ? flyout : null
        }

        onWidthChanged: root.winW = width
        onHeightChanged: root.winH = height
        Component.onCompleted: {
            root.winW = width
            root.winH = height
        }

        // Release the decoded pixmap only after the fade-out has finished
        onVisibleChanged: if (!visible) root.imagePath = ""

        Rectangle {
            id: flyout
            width: root.osdWidth
            height: root.osdHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.offsetX
            anchors.top: parent.top
            anchors.topMargin: root.topGap + root.offsetY
            transformOrigin: Item.Top
            radius: root.radius
            color: Theme.alpha(Theme.bg, root.bgOpacity / 100)
            border.width: root.showBorder ? 1 : 0
            border.color: Theme.alpha(Theme.text, 0.12)
            opacity: root.showing ? 1 : 0
            scale: root.showing ? 1 : 0.9

            Behavior on opacity {
                NumberAnimation {
                    duration: root.animMs
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.animMs
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: flyoutHover
                enabled: root.showing
            }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                Rectangle {
                    id: thumb
                    visible: root.showThumb
                    width: Math.min(root.thumbSize, root.osdHeight - 24)
                    height: width
                    radius: root.imageRadius
                    color: "#33ffffff"
                    anchors.verticalCenter: parent.verticalCenter

                    // `clip: true` on a Rectangle only clips to its bounding box,
                    // not to its radius, so the picture is rounded with a mask.
                    Image {
                        id: shot
                        anchors.fill: parent
                        source: root.imagePath ? "file://" + root.imagePath : ""
                        sourceSize: Qt.size(240, 240)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        visible: false
                    }

                    Rectangle {
                        id: shotMask
                        anchors.fill: parent
                        radius: root.imageRadius
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: shot
                        maskEnabled: true
                        maskSource: shotMask
                        visible: root.imagePath !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.imagePath
                        text: root.isOcr
                              ? (root.ocrState === "done" || root.ocrState === "working" ? "Aa" : "󰜺")
                              : (root.cancelled ? "󰜺" : "󰄀")
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: Math.max(12, thumb.width * 0.37)
                        color: Theme.text
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    width: parent.width - (thumb.visible ? thumb.width + parent.spacing : 0)

                    // title
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.titleText
                        font.pixelSize: root.textSize
                        font.bold: true
                        color: Theme.text
                    }
                    // middle line: filename for screenshots, text preview for OCR
                    Text {
                        visible: root.showDetail && (root.isOcr ? root.ocrState === "done" : !root.cancelled)
                        text: root.isOcr ? root.ocrText : root.imagePath.split("/").pop()
                        font.pixelSize: Math.max(8, root.textSize - 2)
                        color: Theme.textDim
                        elide: root.isOcr ? Text.ElideRight : Text.ElideMiddle
                        width: parent.width
                    }
                    // bottom line
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.subText
                        font.pixelSize: Math.max(8, root.textSize - 3)
                        color: Theme.textDim
                    }
                }
            }

            // Drag anywhere on the card to move it. Right-click toggles the settings,
            // double-click puts it back to the default position.
            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0
                property real startX: 0
                property real startY: 0

                function finish() {
                    if (!root.dragging) return
                    root.dragging = false
                    root.saveState()
                }

                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.toggleSettings()
                        return
                    }
                    var p = dragArea.mapToItem(null, mouse.x, mouse.y)
                    pressX = p.x
                    pressY = p.y
                    startX = root.offsetX
                    startY = root.offsetY
                    root.dragging = true
                }
                onPositionChanged: mouse => {
                    if (!root.dragging) return
                    var p = dragArea.mapToItem(null, mouse.x, mouse.y)
                    root.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
                }
                onReleased: finish()
                onCanceled: finish()
                onDoubleClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) root.resetPosition()
                }
            }
        }
    }

    // ---- settings window: only exists while open -----------------------------
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin
            screen: win.screen

            color: "transparent"
            implicitWidth: 380
            implicitHeight: Math.min(560, (screen?.height ?? 800) * 0.85)
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

                Item {
                    id: head
                    anchors.top: parent.top
                    width: parent.width
                    height: 54

                    Text {
                        x: 20; y: 10
                        text: "Screenshot OSD settings"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.text
                    }
                    Text {
                        x: 20; y: 31
                        text: "Drag the OSD to move it. Double-click resets."
                        font.family: "JetBrains Mono"
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
                        font.family: "JetBrains Mono"
                        font.pixelSize: 22
                        color: closeArea.containsMouse ? Theme.text : Theme.textDim
                        MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.closeSettings() }
                    }
                }

                // everything between header and footer scrolls (mouse wheel / drag)
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

                    Column {
                        id: rowsCol
                        x: 20
                        width: flick.width - 40

                        Repeater {
                            model: root.settingRows
                            delegate: Item {
                                id: row
                                required property var modelData
                                readonly property string t: modelData.type
                                readonly property var spec: t === "slider" ? root.numSpec[modelData.key] : null
                                readonly property real ratio: spec
                                    ? Math.max(0, Math.min(1, (root[modelData.key] - spec.min) / (spec.max - spec.min)))
                                    : 0
                                readonly property bool checked: t === "toggle" ? root[modelData.key] : false

                                width: rowsCol.width
                                height: t === "header" ? 32 : (t === "slider" ? 46 : 34)

                                // ---- section header ----
                                Text {
                                    visible: row.t === "header"
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    text: row.modelData.label
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                    font.capitalization: Font.AllUppercase
                                    color: Theme.textDim
                                }

                                // ---- slider ----
                                Item {
                                    visible: row.t === "slider"
                                    anchors.fill: parent

                                    Text {
                                        anchors.left: parent.left
                                        y: 6
                                        text: row.modelData.label
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Theme.text
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        y: 6
                                        text: row.spec ? root[row.modelData.key] + row.spec.unit : ""
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 11
                                        color: Theme.textDim
                                    }

                                    Rectangle {
                                        id: track
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        y: 31
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.text, 0.15)

                                        Rectangle {
                                            width: knob.x + knob.width / 2
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.accent
                                        }
                                        Rectangle {
                                            id: knob
                                            width: 14; height: 14; radius: 7
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: row.ratio * (track.width - width)
                                            color: Theme.text
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.topMargin: 20
                                        preventStealing: true
                                        enabled: row.t === "slider"

                                        function apply(mx) {
                                            var usable = track.width - knob.width
                                            if (usable <= 0) return
                                            var r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable))
                                            var s = row.spec
                                            root.setNumber(row.modelData.key,
                                                s.min + Math.round(r * (s.max - s.min) / s.step) * s.step)
                                        }

                                        onPressed: mouse => apply(mouse.x)
                                        onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
                                        onReleased: root.saveState()
                                    }
                                }

                                // ---- toggle ----
                                Item {
                                    visible: row.t === "toggle"
                                    anchors.fill: parent

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: -6
                                        anchors.rightMargin: -6
                                        radius: 8
                                        color: toggleArea.containsMouse ? Theme.alpha(Theme.text, 0.06) : "transparent"
                                    }
                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: sw.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.modelData.label
                                        elide: Text.ElideRight
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Theme.text
                                    }
                                    Rectangle {
                                        id: sw
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 36; height: 20; radius: 10
                                        color: row.checked ? Theme.accent : "transparent"
                                        border.width: 1
                                        border.color: row.checked ? Theme.accent : Theme.alpha(Theme.text, 0.3)
                                        Behavior on color { ColorAnimation { duration: 220 } }

                                        Rectangle {
                                            width: 14; height: 14; radius: 7
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: row.checked ? parent.width - width - 3 : 3
                                            color: row.checked ? Theme.bg : Theme.text
                                            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                    MouseArea {
                                        id: toggleArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: row.t === "toggle"
                                        onClicked: root.toggleSetting(row.modelData.key)
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: foot
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 56

                    Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.text, 0.08) }

                    Rectangle {
                        id: resetAllBtn
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: resetAllText.implicitWidth + 28
                        height: 30
                        radius: 10
                        enabled: root.modified
                        opacity: enabled ? 1 : 0.4
                        color: Theme.alpha(Theme.text, resetAllArea.containsMouse && enabled ? 0.18 : 0.1)
                        Text {
                            id: resetAllText
                            anchors.centerIn: parent
                            text: "Reset all"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.text
                        }
                        MouseArea {
                            id: resetAllArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.enabled
                            onClicked: root.resetAll()
                        }
                    }

                    Rectangle {
                        x: resetAllBtn.x + resetAllBtn.width + 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: resetPosText.implicitWidth + 28
                        height: 30
                        radius: 10
                        enabled: root.moved
                        opacity: enabled ? 1 : 0.4
                        color: Theme.alpha(Theme.text, resetPosArea.containsMouse && enabled ? 0.18 : 0.1)
                        Text {
                            id: resetPosText
                            anchors.centerIn: parent
                            text: "Reset position"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.text
                        }
                        MouseArea {
                            id: resetPosArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.enabled
                            onClicked: root.resetPosition()
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: doneText.implicitWidth + 28
                        height: 30
                        radius: 10
                        color: Theme.accent
                        Text {
                            id: doneText
                            anchors.centerIn: parent
                            text: "Done"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.bg
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.closeSettings()
                        }
                    }
                }
            }
        }
    }
}