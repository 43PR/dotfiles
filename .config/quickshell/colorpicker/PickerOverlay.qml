import QtQuick
import Quickshell
import Quickshell.Wayland
import "ColorUtil.js" as CU

PanelWindow {
    id: win
    property var ctl

    readonly property bool active: ctl.mode === "picking"
    readonly property bool mine: ctl.curScreen === screen.name
    readonly property string url: "file:///tmp/qs-colorpicker-" + screen.name + ".png"
    readonly property real sf: shot.implicitWidth > 0 ? shot.implicitWidth / width : 1   // physical / logical
    readonly property int px: Math.max(0, Math.min(shot.implicitWidth - 1, Math.floor(ctl.mx * sf)))
    readonly property int py: Math.max(0, Math.min(shot.implicitHeight - 1, Math.floor(ctl.my * sf)))
    readonly property color pc: Qt.rgba(ctl.picked.r / 255, ctl.picked.g / 255, ctl.picked.b / 255, 1)

    visible: active
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "colorpicker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active && screen.name === ctl.focusScreen
                                 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onActiveChanged: active ? sampler.loadImage(url) : sampler.unloadImage(url)
    onPxChanged: if (mine) sampler.requestPaint()
    onPyChanged: if (mine) sampler.requestPaint()
    onMineChanged: if (mine) sampler.requestPaint()

    // 1×1 canvas used to read the exact pixel under the cursor
    Canvas {
        id: sampler
        width: 1; height: 1; opacity: 0
        renderTarget: Canvas.Image
        onImageLoaded: requestPaint()
        onPaint: {
            if (!win.mine || !isImageLoaded(win.url)) return;
            var ctx = getContext("2d");
            ctx.imageSmoothingEnabled = false;
            ctx.clearRect(0, 0, 1, 1);
            ctx.drawImage(win.url, win.px, win.py, 1, 1, 0, 0, 1, 1);
            var d = ctx.getImageData(0, 0, 1, 1).data;
            win.ctl.picked = { r: d[0], g: d[1], b: d[2] };
        }
    }

    Item {
        id: scene
        anchors.fill: parent
        focus: true

        Keys.onPressed: e => {
            var step = (e.modifiers & Qt.ShiftModifier) ? 10 : 1;
            switch (e.key) {
            case Qt.Key_Escape: ctl.act("cancel"); break;
            case Qt.Key_Left:  ctl.nudge(-step, 0); break;
            case Qt.Key_Right: ctl.nudge(step, 0); break;
            case Qt.Key_Up:    ctl.nudge(0, -step); break;
            case Qt.Key_Down:  ctl.nudge(0, step); break;
            case Qt.Key_Plus: case Qt.Key_Equal: ctl.zoomIn(); break;
            case Qt.Key_Minus: ctl.zoomOut(); break;
            case Qt.Key_Tab:   ctl.cycleFormat(); break;
            case Qt.Key_Return: case Qt.Key_Enter: ctl.act(ctl.leftClick); break;
            case Qt.Key_Space: ctl.act(ctl.middleClick); break;
            default: return;
            }
            e.accepted = true;
        }

        Image {
            id: shot
            anchors.fill: parent
            source: win.active ? win.url : ""
            cache: false
            smooth: false
            fillMode: Image.Stretch
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            function track() { ctl.curScreen = win.screen.name; ctl.mx = mouseX; ctl.my = mouseY; }
            onEntered: track()
            onPositionChanged: track()
            onWheel: w => {
                if (w.angleDelta.y > 0) ctl.zoomIn();
                else if (w.angleDelta.y < 0) ctl.zoomOut();
            }
            onClicked: m => {
                track();
                if (m.button === Qt.LeftButton) ctl.act(ctl.leftClick);
                else if (m.button === Qt.MiddleButton) ctl.act(ctl.middleClick);
                else ctl.act(ctl.rightClick);
            }
        }

        // ── Magnifier + readout ──
        Item {
            id: loupe
            visible: win.mine && ma.containsMouse
            width: 180
            height: 6 + 168 + 8 + info.implicitHeight + 8
            x: { var nx = ctl.mx + 28; return nx + width > win.width ? ctl.mx - 28 - width : nx; }
            y: { var ny = ctl.my + 28; return ny + height > win.height ? ctl.my - 28 - height : ny; }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.bgPanel
                border.color: Theme.borderAccent
            }

            Item {
                id: view
                x: 6; y: 6; width: 168; height: 168
                clip: true
                readonly property real cell: width / ctl.zoomLevels[ctl.zoomIndex]

                Image {
                    source: shot.source
                    cache: false
                    smooth: false
                    fillMode: Image.Stretch
                    width: shot.implicitWidth * view.cell
                    height: shot.implicitHeight * view.cell
                    x: view.width / 2 - (win.px + 0.5) * view.cell
                    y: view.height / 2 - (win.py + 0.5) * view.cell
                }
                // crosshair stays white/black so it is visible on any pixel
                Rectangle {
                    anchors.centerIn: parent
                    width: view.cell; height: view.cell
                    color: "transparent"
                    border.color: "white"; border.width: 2
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 2
                        color: "transparent"; border.color: "black"; border.width: 1
                    }
                }
            }

            Row {
                id: info
                x: 10; y: 6 + 168 + 8
                spacing: 8
                Rectangle {
                    width: 40; height: 40; radius: 6
                    color: win.pc; border.color: Theme.text
                }
                Column {
                    Text { text: CU.hex(ctl.picked); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true }
                    Text { text: CU.format(ctl.picked, "rgb"); color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 10 }
                    Text { text: CU.format(ctl.picked, "hsl"); color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 10 }
                }
            }
        }

        // ── Hint bar ──
        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 24 }
            width: hint.implicitWidth + 28; height: 30; radius: 15
            color: Theme.alpha(Theme.bgPanel, 0.8)
            Text {
                id: hint
                anchors.centerIn: parent
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                text: (ctl.swapped ? "LMB copy  ·  MMB copy + edit" : "LMB copy + edit  ·  MMB copy")
                      + "  ·  RMB/Esc cancel  ·  scroll zoom  ·  arrows nudge  ·  Tab: copy as " + ctl.copyFormat.toUpperCase()
            }
        }
    }
}