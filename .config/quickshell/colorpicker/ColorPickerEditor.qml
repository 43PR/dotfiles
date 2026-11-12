import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
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
    color: "#8c000000"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "colorpicker-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Small building blocks ──

    // Ghost pill button: transparent, hairline border, accent on hover
    component Btn: Rectangle {
        property string text: ""
        signal clicked()
        implicitWidth: t.implicitWidth + 20; height: 24; radius: 12
        color: m.containsMouse ? Theme.alpha(Theme.accent, 0.16) : "transparent"
        border.width: 1
        border.color: m.containsMouse ? Theme.accent : Theme.borderAccent
        Behavior on color { ColorAnimation { duration: 120 } }
        Text { id: t; anchors.centerIn: parent; text: parent.text
               font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 0.5
               color: m.containsMouse ? Theme.accent : Theme.textDim }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }

    // Flat input row: LABEL  value  [Copy]
    component Field: Rectangle {
        id: f
        property var ed
        property string kind: "hex"
        function refresh() { inp.text = CU.format(ed.rgb, kind); }
        height: 34; radius: 8; color: Theme.bgCard
        border.width: 1
        border.color: inp.activeFocus ? Theme.accent : "transparent"
        Component.onCompleted: refresh()
        Connections { target: f.ed; function onRgbChanged() { f.refresh(); } }
        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: f.kind.toUpperCase()
               color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 9
               font.bold: true; font.letterSpacing: 1.5; width: 28 }
        TextInput {
            id: inp
            x: 46; width: parent.width - 46 - copyBtn.width - 14
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text; selectionColor: Theme.accent
            selectedTextColor: CU.readable(Theme.accent); selectByMouse: true
            font.family: Theme.fontFamily; font.pixelSize: 12
            onAccepted: {
                var c = CU.parse(text);
                if (c) f.ed.setRgb(c.r, c.g, c.b); else f.refresh();
            }
        }
        Btn { id: copyBtn; text: "Copy"; height: 22; radius: 11
              anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
              onClicked: f.ed.copyAs(f.kind) }
    }

    // Thin gradient track with a ring handle
    component HSlider: Item {
        id: sl
        property string label: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property var colors: []
        signal moved(real v)
        height: 18
        Text { id: lt; text: sl.label; color: Theme.textFaint; font.family: Theme.fontFamily
               font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
               width: 14; anchors.verticalCenter: parent.verticalCenter }
        Item {
            id: track
            anchors { left: lt.right; right: vt.left; leftMargin: 6; rightMargin: 6; top: parent.top; bottom: parent.bottom }
            Canvas {
                id: cv
                x: 6; width: parent.width - 12; height: 4; anchors.verticalCenter: parent.verticalCenter
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var g = ctx.createLinearGradient(0, 0, width, 0);
                    for (var i = 0; i < sl.colors.length; i++) g.addColorStop(i / (sl.colors.length - 1), sl.colors[i]);
                    ctx.fillStyle = g;
                    ctx.roundedRect(0, 0, width, height, 2, 2);
                    ctx.fill();
                }
                Connections { target: sl; function onColorsChanged() { cv.requestPaint(); } }
            }
            Rectangle {
                width: 12; height: 12; radius: 6; color: "white"
                border.color: Theme.bgPanel; border.width: 2
                anchors.verticalCenter: parent.verticalCenter
                x: (sl.value - sl.from) / (sl.to - sl.from) * (track.width - 12)
            }
            MouseArea {
                anchors.fill: parent
                function set(mx) { sl.moved(sl.from + CU.clamp((mx - 6) / (track.width - 12), 0, 1) * (sl.to - sl.from)); }
                onPressed: m => set(m.x)
                onPositionChanged: m => { if (pressed) set(m.x); }
            }
        }
        Text { id: vt; text: Math.round(sl.value); color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 10
               width: 26; horizontalAlignment: Text.AlignRight; anchors { right: parent.right; verticalCenter: parent.verticalCenter } }
    }

    // ── Backdrop: click outside closes ──
    MouseArea { anchors.fill: parent; onClicked: ctl.stop() }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 340
        height: col.implicitHeight + 40
        radius: Theme.radius
        color: Theme.bgPanel
        border.width: 1
        border.color: Theme.borderAccent
        focus: true
        Keys.onEscapePressed: ctl.stop()

        MouseArea { anchors.fill: parent }   // swallow clicks on the card

        Column {
            id: col
            x: 20; y: 20; width: parent.width - 40
            spacing: 14

            // ── Preview ──
            Rectangle {
                width: parent.width; height: 72; radius: 12
                color: Qt.rgba(win.rgb.r / 255, win.rgb.g / 255, win.rgb.b / 255, 1)
                border.width: 1; border.color: Theme.borderAccent
                Text { anchors.centerIn: parent; text: win.hexStr; font.family: Theme.fontFamily
                       font.pixelSize: 18; font.bold: true; font.letterSpacing: 2
                       color: CU.readable(win.rgb) }
            }

            // ── Values ──
            Column {
                width: parent.width
                spacing: 6
                Field { width: parent.width; ed: win; kind: "hex" }
                Field { width: parent.width; ed: win; kind: "rgb" }
                Field { width: parent.width; ed: win; kind: "hsl" }
            }

            // ── Sliders ──
            Column {
                width: parent.width
                spacing: 6
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
            }

            // ── Pick again (centered above history) ──
            Item {
                width: parent.width; height: 24
                Btn { anchors.horizontalCenter: parent.horizontalCenter; text: "Pick again"; onClicked: ctl.again() }
            }

            // ── History ──
            Item {
                width: parent.width; height: 22
                Text { anchors.verticalCenter: parent.verticalCenter
                       text: "HISTORY  " + ctl.history.length + "/" + ctl.historyLimit
                       color: Theme.textFaint; font.family: Theme.fontFamily
                       font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                Btn { anchors.right: parent.right; height: 22; radius: 11; text: "Clear"; onClicked: ctl.clearHistory() }
            }

            Grid {
                width: parent.width
                columns: 10; spacing: 5
                Repeater {
                    model: ctl.history
                    Rectangle {
                        required property string modelData
                        width: (col.width - 9 * 5) / 10; height: width; radius: 6
                        color: modelData
                        border.width: 1
                        border.color: hm.containsMouse ? Theme.text : Theme.borderAccent
                        scale: hm.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        MouseArea {
                            id: hm; anchors.fill: parent; hoverEnabled: true
                            onClicked: { var c = CU.parse(modelData); if (c) win.setRgb(c.r, c.g, c.b); }
                        }
                    }
                }
            }
            Text {
                visible: ctl.history.length === 0
                text: "Sampled colors appear here."; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10
            }

            // ── Hairline divider with centered toggle ──
            Item {
                width: parent.width; height: 14
                Rectangle {
                    anchors { left: parent.left; right: tgl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    height: 1; color: Theme.borderAccent; opacity: 0.6
                }
                Rectangle {
                    anchors { left: tgl.right; right: parent.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    height: 1; color: Theme.borderAccent; opacity: 0.6
                }
                Rectangle {
                    id: tgl
                    anchors.centerIn: parent
                    width: 30; height: 14; radius: 7
                    color: tm.containsMouse ? Theme.alpha(Theme.accent, 0.16) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: ctl.actionsHidden ? "▴" : "▾"
                        color: tm.containsMouse ? Theme.accent : Theme.textFaint
                        font.family: Theme.fontFamily; font.pixelSize: 9
                    }
                    MouseArea {
                        id: tm; anchors.fill: parent; hoverEnabled: true
                        onClicked: ctl.toggleActionsHidden()
                    }
                }
            }

            // ── Mouse actions
            Column {
                id: acts
                width: parent.width
                spacing: 6
                visible: !ctl.actionsHidden
                Repeater {
                    model: [
                        { label: "LMB", which: "left" },
                        { label: "MMB", which: "middle" },
                        { label: "RMB", which: "right" }
                    ]
                    Row {
                        id: ar
                        required property var modelData
                        readonly property string current:
                            modelData.which === "left" ? ctl.leftClick
                            : modelData.which === "middle" ? ctl.middleClick : ctl.rightClick
                        width: acts.width
                        spacing: 8
                        Text { text: ar.modelData.label; width: 30; height: 28
                               verticalAlignment: Text.AlignVCenter
                               color: Theme.textFaint; font.family: Theme.fontFamily
                               font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5 }
                        Rectangle {
                            id: seg
                            width: ar.width - 30 - ar.spacing
                            height: 28; radius: 8
                            color: Theme.bgCard
                            readonly property real segW: (width - 4) / ctl.actions.length
                            Repeater {
                                model: ctl.actions
                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool on: ar.current === modelData.id
                                    x: 2 + index * seg.segW; y: 2
                                    width: seg.segW; height: 24; radius: 6
                                    color: on ? Theme.accent
                                         : sm.containsMouse ? Theme.alpha(Theme.text, 0.08) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Theme.fontFamily; font.pixelSize: 10
                                        font.bold: parent.on
                                        color: parent.on ? CU.readable(Theme.accent) : Theme.textDim
                                    }
                                    MouseArea {
                                        id: sm; anchors.fill: parent; hoverEnabled: true
                                        onClicked: ctl.setAction(ar.modelData.which, modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}