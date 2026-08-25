import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main

    // ---- Settings ----
    property int speed: 5000
    property int animDuration: 1000
    property real zoomScale: 0.8
    property real edgeScale: 0.3
    property real skewFactor: 0
    property int baseSpacing: 8

    implicitHeight: 500
    implicitWidth: Screen.width
    color: "transparent"
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir])

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + configs.wallpaper_path
        showDirs: false
        nameFilters: ["*.png", "*.jpg"]
        sortField: FolderListModel.Name
    }

    ListView {
        id: list
        anchors.fill: parent
        focus: true
        model: folderModel
        orientation: ListView.Horizontal
        spacing: main.baseSpacing
        clip: true
        cacheBuffer: 400

        property int selectedIndex: 0
        property real tileWidth: width / configs.number_of_pictures - 10
        property real viewportCenterX: width / 2

        function clampIndex(i) { return Math.max(0, Math.min(i, count - 1)) }
        function clampX(x) { return Math.max(0, Math.min(x, contentWidth - width)) }

        function activateCurrent() {
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), folderModel.get(selectedIndex, "filePath")])
            Qt.quit()
        }

        function ensureVisibleAnimated(i) {
            const step = tileWidth + spacing
            const itemStart = i * step
            const itemEnd = itemStart + tileWidth + 20
            if (itemStart < contentX) contentX = clampX(itemStart)
            else if (itemEnd > contentX + width) contentX = clampX(itemStart - (width - step))
        }

        // Moves selection by delta tiles, animating at speedMultiplier x speed
        function moveSelection(delta, speedMultiplier) {
            anim.v = main.speed * speedMultiplier
            selectedIndex = clampIndex(selectedIndex + delta)
            ensureVisibleAnimated(selectedIndex)
        }

        Behavior on contentX {
            SmoothedAnimation { id: anim; property int v: main.speed; duration: main.animDuration }
        }

        delegate: Item {
            id: delegateItem
            height: 500
            property bool active: index === list.selectedIndex
            // Base slot width, independent of this item's own width to avoid a binding loop
            readonly property real baseWidth: list.tileWidth

            // Dock-style magnification based on on-screen position (smoothstep falloff)
            property real scaleFactor: {
                const centerX = x - list.contentX + baseWidth / 2
                const frac = Math.min(1, Math.abs(centerX - list.viewportCenterX) / list.viewportCenterX)
                const t = 1 - frac * frac * (3 - 2 * frac)
                return main.edgeScale + (main.zoomScale - main.edgeScale) * t
            }

            width: baseWidth * scaleFactor // real layout width -> pushes following tiles

            Item {
                id: content
                anchors.centerIn: parent
                width: parent.width
                height: delegateItem.height * Math.min(1, delegateItem.scaleFactor) // cap at full height

                Text {
                    id: alt
                    text: ""
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 16
                    transform: Shear { xFactor: main.skewFactor }
                }

                Image {
                    id: img
                    anchors.fill: parent
                    opacity: 0.8
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    source: "file://" + configs.cache_path + fileName
                    // Decode once at max (zoomed) size to avoid re-decoding/blinking during animation
                    sourceSize.width: delegateItem.baseWidth * main.zoomScale
                    sourceSize.height: delegateItem.height
                    transform: Shear { xFactor: main.skewFactor }

                    Timer {
                        id: retryTimer
                        interval: 1000
                        repeat: false
                        onTriggered: { const s = img.source; img.source = ""; img.source = s }
                    }

                    onStatusChanged: if (status === Image.Error) { alt.text = "Caching"; retryTimer.start() }
                }

                Rectangle {
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"
                    border.width: 2
                    border.color: configs.border_color
                    transform: Shear { xFactor: main.skewFactor }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: list.selectedIndex = index
                onClicked: list.activateCurrent()
                onWheel: function(wheel) { list.flick(-wheel.angleDelta.y * 8, 0); wheel.accepted = true }
            }
        }

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_D: moveSelection(1, 1); break
            case Qt.Key_A: moveSelection(-1, 1); break
            case Qt.Key_Space: activateCurrent(); break
            case Qt.Key_Escape: Qt.quit(); break
            default: return
            }
            event.accepted = true
        }
    }
}
