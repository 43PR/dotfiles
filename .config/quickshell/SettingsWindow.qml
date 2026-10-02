import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Shapes
import "SettingsPages"

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? backdrop : null
    }
    property bool showing: false
    function show()   { showing = true }
    function hide()   { showing = false }
    function toggle() { showing = !showing }

    property real cardMargin: 40

    property real cardHeightCenter: Math.min(640, root.height - cardMargin * 2)
    property real cardHeightSnapped: cardHeightCenter * 0.6
    property real cardHeight: cardHeightCenter
    property real cardCenterY: (root.height - cardHeight) / 2
    property real cardY: cardCenterY

    property real cardWidthCenter: Math.min(980, root.width - cardMargin * 2)
    property real cardWidthSnapped: cardWidthCenter * 0.85
    property real cardHeightSideSnapped: cardHeightCenter * 1.4
    property real cardWidth: cardWidthCenter
    property real cardCenterX: (root.width - cardWidth) / 2
    property real cardX: cardCenterX

    // ---- persisted snap position ----
    property string snapPosition: "center"   // center | top | bottom | left | right
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/settings-state.json"

    function saveState() {
        stateFile.setText(JSON.stringify({ snap: root.snapPosition }))
    }

    // Moves the card to a snap position without saving
    function applySnap(pos) {
        switch (pos) {
        case "top":
            cardHeight = cardHeightSnapped
            cardY = cardMargin
            break
        case "bottom":
            cardHeight = cardHeightSnapped
            cardY = root.height - cardHeight - cardMargin
            break
        case "left":
            cardWidth = cardWidthSnapped
            cardHeight = cardHeightSideSnapped
            cardX = cardMargin
            cardY = (root.height - cardHeight) / 2
            break
        case "right":
            cardWidth = cardWidthSnapped
            cardHeight = cardHeightSideSnapped
            cardX = root.width - cardWidth - cardMargin
            cardY = (root.height - cardHeight) / 2
            break
        default:
            cardHeight = cardHeightCenter
            cardWidth = cardWidthCenter
            cardY = (root.height - cardHeight) / 2
            cardX = (root.width - cardWidth) / 2
        }
    }

    function snapTo(pos) {
        root.snapPosition = pos
        root.applySnap(pos)
        root.saveState()
    }

    function snapTop()    { snapTo("top") }
    function snapBottom() { snapTo("bottom") }
    function snapLeft()   { snapTo("left") }
    function snapRight()  { snapTo("right") }
    function snapCenter() { snapTo("center") }

    // Re-apply the saved snap when the screen size is known or changes
    onWidthChanged:  if (width > 0 && height > 0) applySnap(snapPosition)
    onHeightChanged: if (width > 0 && height > 0) applySnap(snapPosition)

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false   // no warning on first run when the file doesn't exist yet

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                if (["center", "top", "bottom", "left", "right"].indexOf(s.snap) >= 0) {
                    root.snapPosition = s.snap
                    if (root.width > 0 && root.height > 0)
                        root.applySnap(s.snap)
                }
            } catch (e) {
                console.warn("settings: could not read saved state:", e)
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void {
            root.toggle()
        }
        function show(): void {
            root.show()
        }
        function hide(): void {
            root.hide()
        }
        function sound(): void {
            root.selectedIndex = 1
            root.show()
        }
        function network(): void {
            root.selectedIndex = 3
            root.show()
        }
        function snapTop(): void {
            root.snapTop()
        }
        function snapCenter(): void {
            root.snapCenter()
        }
        function snapBottom(): void {
            root.snapBottom()
        }
        function snapLeft(): void {
            root.snapLeft()
        }
        function snapRight(): void {
            root.snapRight()
        }
    }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property var sink: Pipewire.defaultAudioSink
    property real pwVolume: (sink && sink.audio) ? sink.audio.volume : 0
    property bool pwMuted: (sink && sink.audio) ? sink.audio.muted : false

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"

        focus: root.showing
        Keys.onEscapePressed: root.hide()

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    property var navItems: [
        { name: "System", icon: "󰒓", page: "SystemPage" },
        { name: "Audio", icon: "\uf028", page: "AudioPage" },
        { name: "Display", icon: "\uf108", page: "DisplayPage" },
        { name: "Network", icon: "\uf1eb", page: "NetworkPage" },
        { name: "Bluetooth", icon: "󰂯", page: "BluetoothPage" },
        { name: "Storage", icon: "󰋊", page: "StoragePage" },
        { name: "Configs", icon: "󰧮",  page: "ConfigsPage" },
        { name: "Themes", icon: "󰉼",  page: "ThemesPage" }
    ]

    property int selectedIndex: 0

    PerspectivePanel {
        id: card
        x: root.cardX
        y: root.cardY
        width: root.cardWidth
        height: root.cardHeight
        open: root.showing

        Behavior on x {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            border.color: Theme.accent
            border.width: 1
            Rectangle {
                width: 40
                height: 2
                color: Theme.accent2
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: 14
                }
            }

            Rectangle {
                width: 2
                height: 40
                color: Theme.accent2
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: 14
                }
            }

            Rectangle {
                width: 40
                height: 2
                color: Theme.accent2
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    margins: 14
                }
            }

            Rectangle {
                width: 2
                height: 40
                color: Theme.accent2
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    margins: 14
                }
            }

            Item {
                id: positionHandle
                width: 140
                height: 13
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        id: tabPath
                        property real w: positionHandle.width
                        property real h: positionHandle.height
                        property real r: 10
                        property real fx: 30
                        property real fy: 0

                        strokeColor: Theme.accent
                        strokeWidth: 1
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap

                        startX: 0.5 - fx
                        startY: 0.5

                        PathArc {
                            x: 0.5; y: tabPath.fy + 0.5
                            radiusX: tabPath.fx; radiusY: tabPath.fy
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: 0.5; y: tabPath.h - tabPath.r }
                        PathArc {
                            x: tabPath.r + 0.5; y: tabPath.h - 0.5
                            radiusX: tabPath.r; radiusY: tabPath.r
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: tabPath.w - tabPath.r - 0.5; y: tabPath.h - 0.5 }
                        PathArc {
                            x: tabPath.w - 0.5; y: tabPath.h - tabPath.r
                            radiusX: tabPath.r; radiusY: tabPath.r
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: tabPath.w - 0.5; y: tabPath.fy + 0.5 }
                        PathArc {
                            x: tabPath.w - 0.5 + tabPath.fx; y: 0.5
                            radiusX: tabPath.fx; radiusY: tabPath.fy
                            direction: PathArc.Clockwise
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    spacing: 20

                    Text {
                        text: "◀"
                        font.family: Theme.fontFamily
                        font.pixelSize: 7
                        color: Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapLeft() }
                    }
                    Text {
                        text: "▲"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapTop() }
                    }
                    Text {
                        text: "●"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapCenter() }
                    }
                    Text {
                        text: "▼"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapBottom() }
                    }
                    Text {
                        text: "▶"
                        font.family: Theme.fontFamily
                        font.pixelSize: 7
                        color: Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.snapRight() }
                    }
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 28

                Column {
                    id: sidebar
                    width: 130
                    height: parent.height
                    spacing: 12

                    Text {
                        text: " SETTINGS"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 19
                        font.bold: true
                        font.letterSpacing: 4
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    Flickable {
                        id: sidebarFlickable
                        width: parent.width
                        height: Math.max(0, parent.height - 48)
                        contentWidth: width
                        contentHeight: navColumn.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

                        WheelHandler {
                            target: sidebarFlickable
                            property: "contentY"
                            onActiveChanged: {
                                if (!active)
                                    sidebarFlickable.returnToBounds()
                            }
                        }

                        Column {
                            id: navColumn
                            width: sidebarFlickable.width
                            spacing: 4

                            Repeater {
                                model: root.navItems
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: sidebar.width
                                    height: 38
                                    radius: Theme.radius
                                    color: root.selectedIndex === index
                                        ? Theme.alpha(Theme.accent, 0.12)
                                        : "transparent"
                                    border.width: root.selectedIndex === index ? 1 : 0
                                    border.color: Theme.accent

                                    Rectangle {
                                        visible: root.selectedIndex === index
                                        width: 3
                                        height: parent.height - 10
                                        anchors {
                                            verticalCenter: parent.verticalCenter
                                            left: parent.left
                                        }
                                        color: Theme.accent2
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        spacing: 12
                                        height: 20

                                        Text {
                                            width: 18
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData.icon
                                            font.family: Theme.iconFont
                                            font.pixelSize: 14
                                            color: root.selectedIndex === index
                                                ? Theme.text
                                                : Theme.textDim
                                        }

                                        Text {
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: root.selectedIndex === index
                                                ? Theme.text
                                                : Theme.textDim
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.selectedIndex = index
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height
                    color: Theme.border
                }

                Item {
                    width: parent.width - sidebar.width - 29
                    height: parent.height
                    clip: true

                    Loader {
                        id: pageLoader
                        anchors.fill: parent
                        source: "SettingsPages/"
                            + root.navItems[root.selectedIndex].page
                            + ".qml"
                        opacity: 0
                        Component.onCompleted: opacity = 1
                        onSourceChanged: fadeIn.restart()

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animMed
                            }
                        }

                        SequentialAnimation {
                            id: fadeIn

                            PropertyAction {
                                target: pageLoader
                                property: "opacity"
                                value: 0
                            }

                            NumberAnimation {
                                target: pageLoader
                                property: "opacity"
                                to: 1
                                duration: Theme.animMed
                            }
                        }
                    }
                }
            }
        }
    }
}