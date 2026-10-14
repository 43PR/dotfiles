import QtQuick
import Quickshell
import Quickshell.Wayland
import "ColorUtil.js" as CU

PanelWindow {
    id: win
    property var ctl

    readonly property bool active: ctl.mode === "editing"
    property real h: 0
    property real s: 0
    property real l: 0
    readonly property var rgb: CU.hslToRgb(h, s, l)
    readonly property string hexStr: CU.hex(rgb)

    function setRgb(r, g, b) { var c = CU.rgbToHsl(r, g, b); h = c.h; s = c.s; l = c.l; }
    function copyAs(kind) { ctl.copyText(CU.format(rgb, kind)); ctl.pushHistory(hexStr); }

    onActiveChanged: if (active) setRgb(ctl.picked.r, ctl.picked.g, ctl.picked.b)

    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === ctl.curScreen) return Quickshell.screens[i];
        return Quickshell.screens[0];
    }
    visible: active
    color: "#66000000"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "colorpicker-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Small building blocks ──
    component Btn: Rectangle {
        property string text: ""
        signal clicked()
        implicitWidth: t.implicitWidth + 18; height: 26; radius: 6
        color: m.containsMouse ? Theme.accent : Theme.borderAccent
        Text { id: t; anchors.centerIn: parent; text: parent.text
               font.family: Theme.fontFamily; font.pixelSize: 11
               color: m.containsMouse ? CU.readable(Theme.accent) : Theme.text }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }

    component Field: Rectangle {
        id: f
        property var ed
        property string kind: "hex"
        function refresh() { inp.text = CU.format(ed.rgb, kind); }
        height: 34; radius: 6; color: Theme.bgCard
        Component.onCompleted: refresh()
        Connections { target: f.ed; function onRgbChanged() { f.refresh(); } }
        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: f.kind.toUpperCase()
               color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true; width: 28 }
        TextInput {
            id: inp
            x: 44; width: parent.width - 44 - copyBtn.width - 14
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text; selectionColor: Theme.accent
            selectedTextColor: CU.readable(Theme.accent); selectByMouse: true
            font.family: Theme.fontFamily; font.pixelSize: 13
            onAccepted: {
                var c = CU.parse(text);
                if (c) f.ed.setRgb(c.r, c.g, c.b); else f.refresh();
            }
        }
        Btn { id: copyBtn; text: "Copy"; anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
              onClicked: f.ed.copyAs(f.kind) }
    }

    component HSlider: Item {
        id: sl
        property string label: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property var colors: []
        signal moved(real v)
        height: 20
        Text { id: lt; text: sl.label; color: Theme.textFaint; font.family: Theme.fontFamily
               font.pixelSize: 11; font.bold: true
               width: 16; anchors.verticalCenter: parent.verticalCenter }
        Item {
            id: track
            anchors { left: lt.right; right: vt.left; leftMargin: 6; rightMargin: 6; top: parent.top; bottom: parent.bottom }
            Canvas {
                id: cv
                x: 7; width: parent.width - 14; height: 10; anchors.verticalCenter: parent.verticalCenter
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var g = ctx.createLinearGradient(0, 0, width, 0);
                    for (var i = 0; i < sl.colors.length; i++) g.addColorStop(i / (sl.colors.length - 1), sl.colors[i]);
                    ctx.fillStyle = g;
                    ctx.roundedRect(0, 0, width, height, 5, 5);
                    ctx.fill();
                }
                Connections { target: sl; function onColorsChanged() { cv.requestPaint(); } }
            }
            Rectangle {
                width: 14; height: 14; radius: 7; color: "transparent"
                border.color: "white"; border.width: 2
                anchors.verticalCenter: parent.verticalCenter
                x: (sl.value - sl.from) / (sl.to - sl.from) * (track.width - 14)
            }
            MouseArea {
                anchors.fill: parent
                function set(mx) { sl.moved(sl.from + CU.clamp((mx - 7) / (track.width - 14), 0, 1) * (sl.to - sl.from)); }
                onPressed: m => set(m.x)
                onPositionChanged: m => { if (pressed) set(m.x); }
            }
        }
        Text { id: vt; text: Math.round(sl.value); color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
               width: 28; horizontalAlignment: Text.AlignRight; anchors { right: parent.right; verticalCenter: parent.verticalCenter } }
    }

    // ── Backdrop: click outside closes ──
    MouseArea { anchors.fill: parent; onClicked: ctl.stop() }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 360
        height: col.implicitHeight + 32
        radius: Theme.radius
        color: Theme.bgPanel
        border.color: Theme.borderAccent
        focus: true
        Keys.onEscapePressed: ctl.stop()

        MouseArea { anchors.fill: parent }   // swallow clicks on the card

        Column {
            id: col
            x: 16; y: 16; width: parent.width - 32
            spacing: 10

            Row {
                width: parent.width
                Text { text: "Color Picker"; color: Theme.text; font.family: Theme.fontFamily
                       font.pixelSize: 15; font.bold: true
                       width: parent.width - pickAgain.width; anchors.verticalCenter: parent.verticalCenter }
                Btn { id: pickAgain; text: "Pick again"
                      onClicked: ctl.again() }
            }
            Row {
                width: parent.width
                Text {
                    text: ctl.swapped ? "LMB copy  ·  MMB copy + edit" : "LMB copy + edit  ·  MMB copy"
                    color: Theme.textFaint; font.family: Theme.fontFamily
                    font.pixelSize: 11; font.bold: true
                    width: parent.width - swapBtn.width
                    anchors.verticalCenter: parent.verticalCenter
                }
                Btn { id: swapBtn; text: "Swap"; onClicked: ctl.toggleSwap() }
            }
            Rectangle {
                width: parent.width; height: 64; radius: 8
                color: Qt.rgba(win.rgb.r / 255, win.rgb.g / 255, win.rgb.b / 255, 1)
                border.color: Theme.borderAccent
                Text { anchors.centerIn: parent; text: win.hexStr; font.family: Theme.fontFamily; font.pixelSize: 20; font.bold: true
                       color: CU.readable(win.rgb) }
            }

            Field { width: parent.width; ed: win; kind: "hex" }
            Field { width: parent.width; ed: win; kind: "rgb" }
            Field { width: parent.width; ed: win; kind: "hsl" }

            HSlider {
                width: parent.width; label: "H"; from: 0; to: 360; value: win.h
                colors: ["#f00", "#ff0", "#0f0", "#0ff", "#00f", "#f0f", "#f00"]
                onMoved: v => win.h = v
            }
            HSlider {
                width: parent.width; label: "S"; from: 0; to: 100; value: win.s
                colors: [CU.hex(CU.hslToRgb(win.h, 0, win.l)), CU.hex(CU.hslToRgb(win.h, 100, win.l))]
                onMoved: v => win.s = v
            }
            HSlider {
                width: parent.width; label: "L"; from: 0; to: 100; value: win.l
                colors: ["#000000", CU.hex(CU.hslToRgb(win.h, win.s, 50)), "#ffffff"]
                onMoved: v => win.l = v
            }

            Row {
                width: parent.width
                Text { text: "History  " + ctl.history.length + "/" + ctl.historyLimit; color: Theme.textFaint
                       font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true
                       width: parent.width - clr.width; anchors.verticalCenter: parent.verticalCenter }
                Btn { id: clr; text: "Clear"; onClicked: ctl.clearHistory() }
            }

            Grid {
                columns: 10; spacing: 4
                Repeater {
                    model: ctl.history
                    Rectangle {
                        required property string modelData
                        width: 28; height: 28; radius: 5
                        color: modelData
                        border.width: hm.containsMouse ? 2 : 1
                        border.color: hm.containsMouse ? Theme.text : Theme.borderAccent
                        MouseArea {
                            id: hm; anchors.fill: parent; hoverEnabled: true
                            onClicked: { var c = CU.parse(modelData); if (c) win.setRgb(c.r, c.g, c.b); }
                        }
                    }
                }
            }
            Text {
                visible: ctl.history.length === 0
                text: "Sampled colors appear here."; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 11
            }
        }
    }
}