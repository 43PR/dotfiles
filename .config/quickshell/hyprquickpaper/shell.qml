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
    property int baseSpacing: 10
    property int startPosition: 20

    implicitHeight: 500
    implicitWidth: Screen.width
    color: "transparent"
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted:
        Quickshell.execDetached([
            "bash",
            Quickshell.shellPath("cache.sh"),
            Quickshell.shellDir
        ])

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
        boundsBehavior: Flickable.StopAtBounds

        property int selectedIndex: main.startPosition
        property real tileWidth: width / configs.number_of_pictures - 10
        property real viewportCenterX: width / 2
        property bool ready: false

        // Extend the scrollable area on both ends so the first/last
        // wallpaper can be centered in the viewport.
        leftMargin: Math.max(0, viewportCenterX - tileWidth / 2)
        rightMargin: leftMargin

        onCountChanged: {
            if (!ready && count > 0) {
                selectedIndex = clampIndex(main.startPosition)
                ensureVisibleAnimated(selectedIndex)
                ready = true
            }
        }

        function clampIndex(i) {
            return Math.max(0, Math.min(i, count - 1))
        }

        function activateCurrent() {
            Quickshell.execDetached([
                "bash",
                Quickshell.shellPath("commands.sh"),
                folderModel.get(selectedIndex, "filePath")
            ])

            Qt.quit()
        }

        function ensureVisibleAnimated(i) {
            const step = tileWidth + spacing
            const itemStart = i * step

            // Always center the selected tile.
            contentX = itemStart + tileWidth / 2 - viewportCenterX
        }

        function moveSelection(delta, speedMultiplier) {
            anim.v = main.speed * speedMultiplier
            selectedIndex = clampIndex(selectedIndex + delta)
            ensureVisibleAnimated(selectedIndex)
        }

        Behavior on contentX {
            enabled: list.ready

            SmoothedAnimation {
                id: anim
                property int v: main.speed
                duration: main.animDuration
            }
        }

        delegate: Item {
            id: delegateItem

            height: 500
            property bool active: index === list.selectedIndex

            // Base slot width, independent of this item's own width.
            readonly property real baseWidth: list.tileWidth

            // Dock-style magnification based on on-screen position.
            property real scaleFactor: {
                const centerX = x - list.contentX + baseWidth / 2
                const frac = Math.min(
                    1,
                    Math.abs(centerX - list.viewportCenterX) / list.viewportCenterX
                )

                const t = 1 - frac * frac * (3 - 2 * frac)

                return main.edgeScale +
                       (main.zoomScale - main.edgeScale) * t
            }

            width: baseWidth * scaleFactor

            Item {
                id: content

                anchors.centerIn: parent
                width: parent.width
                height: delegateItem.height *
                        Math.min(1, delegateItem.scaleFactor)

                Text {
                    id: alt

                    text: ""
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 16

                    transform: Shear {
                        xFactor: main.skewFactor
                    }
                }

                Image {
                    id: img

                    anchors.fill: parent
                    opacity: 0.8
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true

                    source: "file://" +
                            configs.cache_path +
                            fileName

                    // Decode once at max zoomed size.
                    sourceSize.width:
                        delegateItem.baseWidth * main.zoomScale

                    sourceSize.height:
                        delegateItem.height

                    transform: Shear {
                        xFactor: main.skewFactor
                    }

                    Timer {
                        id: retryTimer

                        interval: 1000
                        repeat: false

                        onTriggered: {
                            const s = img.source
                            img.source = ""
                            img.source = s
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Error) {
                            alt.text = "Caching"
                            retryTimer.start()
                        }
                    }
                }

                Rectangle {
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"
                    border.width: 2
                    border.color: configs.border_color

                    transform: Shear {
                        xFactor: main.skewFactor
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onEntered:
                    list.selectedIndex = index

                onClicked:
                    list.activateCurrent()

                onWheel: function(wheel) {
                    list.flick(-wheel.angleDelta.y * 8, 0)
                    wheel.accepted = true
                }
            }
        }

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Space:
                activateCurrent()
                break
            case Qt.Key_W:
                Qt.quit()
                break    
            case Qt.Key_Escape:
                Qt.quit()
                break
            default:
                return
            }
            event.accepted = true
        }
    }
}
