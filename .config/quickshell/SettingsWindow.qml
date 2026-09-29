import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
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
    property real cardHeightSnapped: cardHeightCenter * 0.6   // 40% smaller when pinned top/bottom
    property real cardHeight: cardHeightCenter
    property real cardCenterY: (root.height - cardHeight) / 2
    property real cardY: cardCenterY

    property real cardWidthCenter: Math.min(980, root.width - cardMargin * 2)
    property real cardWidthSnapped: cardWidthCenter * 0.85    // width when pinned left/right
    property real cardHeightSideSnapped: cardHeightCenter * 1.4   // height when pinned left/right (taller than top/bottom snap)
    property real cardWidth: cardWidthCenter
    property real cardCenterX: (root.width - cardWidth) / 2
    property real cardX: cardCenterX

    function snapTop() {
        cardHeight = cardHeightSnapped
        cardY = cardMargin
    }
    function snapBottom() {
        cardHeight = cardHeightSnapped
        cardY = root.height - cardHeight - cardMargin
    }
    function snapLeft() {
        cardWidth = cardWidthSnapped
        cardHeight = cardHeightSideSnapped
        cardX = cardMargin
        cardY = (root.height - cardHeight) / 2
    }
    function snapRight() {
        cardWidth = cardWidthSnapped
        cardHeight = cardHeightSideSnapped
        cardX = root.width - cardWidth - cardMargin
        cardY = (root.height - cardHeight) / 2
    }
    function snapCenter() {
        cardHeight = cardHeightCenter
        cardWidth = cardWidthCenter
        cardY = (root.height - cardHeight) / 2
        cardX = (root.width - cardWidth) / 2
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
        { name: "Audio", icon: "\uf028", page: "SoundPage" },
        { name: "Display", icon: "\uf108", page: "MonitorsPage" },
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
            radius: 6
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
            Rectangle {
                id: positionHandle

                width: 150
                height: 16
                radius: Theme.radius

                color: Theme.bg
                border.color: Theme.accent
                border.width: 1

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: -8
                }

                MouseArea {
                    // Clicking the pill body (not the glyphs) snaps to top.
                    anchors.fill: parent
                    onClicked: root.snapTop()
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 20

                    Text {
                        text: "◀"
                        font.family: Theme.fontFamily
                        font.pixelSize: 7
                        color: Theme.textDim

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: root.snapLeft()
                        }
                    }

                    Text {
                        text: "▲"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: root.snapTop()
                        }
                    }

                    Text {
                        text: "●"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: root.snapCenter()
                        }
                    }

                    Text {
                        text: "▼"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: root.snapBottom()
                        }
                    }

                    Text {
                        text: "▶"
                        font.family: Theme.fontFamily
                        font.pixelSize: 7
                        color: Theme.textDim

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: root.snapRight()
                        }
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
