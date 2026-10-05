import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: root

    readonly property int sizeCpuRam: 12
    readonly property int sizeClock: 12
    readonly property int sizeMarquee: 11
    readonly property int sizeNetIcon: 14
    readonly property int sizeVolIcon: 18
    readonly property int sizeVolText: 12
    readonly property int sizeBatIcon: 13
    readonly property int sizeBatText: 12
    readonly property int sizePowerIcon: 13
    readonly property real hoverScale: 1.2
    readonly property int sizeIconGap: 12
    readonly property int iconYOffset: 1

    readonly property int sizeCalTime: 30
    readonly property int sizeCalDate: 12
    readonly property int sizeCalMonth: 13
    readonly property int sizeCalArrow: 16
    readonly property int sizeCalWeekday: 11
    readonly property int sizeCalDay: 12

    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)
    readonly property int batPct: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batCharging: battery !== null
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge
            || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batLow: battery !== null && !batCharging && batPct <= 15
    readonly property var batIcons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
    readonly property string batIcon: batIcons[batPct >= 90 ? 4 : batPct >= 65 ? 3 : batPct >= 40 ? 2 : batPct >= 15 ? 1 : 0]

    property bool barVisible: true
    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
    }

    property int cpuUsage: 0
    property int memPercent: 0
    property string netState: "disconnected"
    property real _prevTotal: 0
    property real _prevIdle: 0

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            const dT = total - root._prevTotal;
            const dI = idle - root._prevIdle;
            if (root._prevTotal > 0 && dT > 0)
                root.cpuUsage = Math.round(100 * (dT - dI) / dT);
            root._prevTotal = total;
            root._prevIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => Number(t.match(new RegExp(k + ":\\s+(\\d+)"))[1]);
            root.memPercent = Math.round(100 * (kb("MemTotal") - kb("MemAvailable")) / kb("MemTotal"));
        }
    }

    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = "disconnected";
                for (const l of text.split("\n")) {
                    if (l === "ethernet:connected") { s = "ethernet"; break; }
                    if (l === "wifi:connected") s = "wifi";
                }
                if (s !== root.netState) root.netState = s;
            }
        }
    }

    Timer {
        interval: 2000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: { statFile.reload(); memFile.reload(); }
    }

    Timer {
        interval: 10000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Process { id: runner }
    function run(cmd) {
        runner.command = ["sh", "-c", cmd];
        runner.running = true;
    }

    component Panel: Rectangle {
        height: 20
        radius: Theme.radius
        color: Theme.bg
    }

    component Mod: Item {
        id: mod
        property string text: ""
        property string glyph: ""
        property real glyphSize: 16
        property real baseSize: 11
        property color color: Theme.text
        property bool bold: false
        property bool hoverGrow: true
        property real yOffset: 0
        signal clicked(var mouse)
        signal scrolled(real delta)

        implicitWidth: content.implicitWidth + 20
        implicitHeight: 18

        Row {
            id: content
            anchors.centerIn: parent
            anchors.verticalCenterOffset: mod.yOffset
            spacing: root.sizeIconGap

            Text {
                visible: mod.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: mod.glyph
                color: mod.color
                font.family: Theme.iconFont
                font.pixelSize: mod.glyphSize
                renderType: Text.NativeRendering
            }

            Text {
                visible: mod.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: mod.text
                color: mod.color
                font.family: Theme.iconFont
                font.bold: mod.bold
                font.pixelSize: mod.baseSize
                renderType: Text.NativeRendering
                scale: mod.hoverGrow && ma.containsMouse ? root.hoverScale : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => mod.clicked(mouse)
            onWheel: wheel => mod.scrolled(wheel.angleDelta.y)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: 24
            color: "transparent"
            visible: root.barVisible

            Panel {
                anchors { left: parent.left; top: parent.top; leftMargin: 6; topMargin: 4 }
                width: leftRow.implicitWidth + 4

                Row {
                    id: leftRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 2

                    Mod { baseSize: root.sizeCpuRam; text: "CPU " + root.cpuUsage + "%" }
                    Mod { baseSize: root.sizeCpuRam; text: "RAM " + root.memPercent + "%" }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 4
                        rightPadding: 8
                        spacing: 8

                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Rectangle {
                                id: dot
                                required property var modelData
                                visible: modelData.id > 0
                                width: modelData.focused ? 32 : 10
                                height: 10
                                radius: 5
                                color: modelData.urgent ? Theme.danger
                                     : modelData.focused ? Qt.alpha(Theme.accent, 0.2)
                                     : dotMa.containsMouse ? Theme.accent2
                                     : Qt.alpha(Theme.textFaint, 0.5)

                                Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }

                                MouseArea {
                                    id: dotMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: dot.modelData.activate()
                                }
                            }
                        }

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: e => root.run(e.angleDelta.y > 0
                                ? "hyprctl dispatch 'hl.dsp.focus({workspace=\"e+1\"})'"
                                : "hyprctl dispatch 'hl.dsp.focus({workspace=\"e-1\"})'")
                        }
                    }
                }
            }

            Panel {
                id: clockPanel
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 4 }
                width: clockMod.implicitWidth + 4

                property bool calOpen: false
                property int monthOffset: 0

                SystemClock { id: clk; precision: SystemClock.Minutes }

                Mod {
                    id: clockMod
                    anchors.centerIn: parent
                    bold: true
                    baseSize: root.sizeClock
                    text: Qt.formatDateTime(clk.date, "HH:mm")
                    onClicked: mouse => {
                        if (mouse.button !== Qt.LeftButton) return;
                        clockPanel.monthOffset = 0;
                        clockPanel.calOpen = !clockPanel.calOpen;
                    }
                }

                LazyLoader {
                    active: clockPanel.calOpen

                    PopupWindow {
                        anchor.window: bar
                        anchor.rect.x: clockPanel.x + (clockPanel.width - implicitWidth) / 2
                        anchor.rect.y: clockPanel.y + clockPanel.height + 4
                        implicitWidth: calBox.gridW + 2 * calBox.pad
                        implicitHeight: calCol.implicitHeight + 2 * calBox.pad
                        color: "transparent"
                        visible: true

                        Rectangle {
                            id: calBox
                            anchors.fill: parent
                            radius: 4
                            color: Theme.bg

                            readonly property int firstDay: 1
                            readonly property int cellW: 36
                            readonly property int cellH: 30
                            readonly property int pad: 16
                            readonly property int gridW: cellW * 7

                            readonly property date now: clk.date
                            readonly property date view: new Date(now.getFullYear(), now.getMonth() + clockPanel.monthOffset, 1)

                            readonly property var cells: {
                                const first = (view.getDay() - firstDay + 7) % 7;
                                const y = view.getFullYear(), m = view.getMonth();
                                const ty = now.getFullYear(), tm = now.getMonth(), td = now.getDate();
                                const out = [];
                                for (let i = 0; i < 42; i++) {
                                    const d = new Date(y, m, i - first + 1);
                                    out.push({
                                        n: d.getDate(),
                                        inMonth: d.getMonth() === m,
                                        today: d.getFullYear() === ty && d.getMonth() === tm && d.getDate() === td
                                    });
                                }
                                return out;
                            }

                            WheelHandler {
                                onWheel: e => clockPanel.monthOffset += (e.angleDelta.y > 0 ? -1 : 1)
                            }

                            Column {
                                id: calCol
                                anchors.centerIn: parent
                                spacing: 12

                                Column {
                                    spacing: 2
                                    Text {
                                        text: Qt.formatTime(calBox.now, "HH:mm")
                                        color: Theme.text
                                        font.family: Theme.iconFont
                                        font.pixelSize: root.sizeCalTime
                                        font.bold: true
                                    }
                                    Text {
                                        text: Qt.formatDate(calBox.now, "dddd, d MMMM yyyy")
                                        color: Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: root.sizeCalDate
                                    }
                                }

                                Rectangle {
                                    width: calBox.gridW
                                    height: 1
                                    color: Qt.alpha(Theme.text, 0.12)
                                }

                                Item {
                                    width: calBox.gridW
                                    height: 26

                                    Item {
                                        width: 28; height: parent.height
                                        anchors.left: parent.left
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uDB80\uDD41"
                                            color: prevMa.containsMouse ? Theme.accent : Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sizeCalArrow
                                        }
                                        MouseArea {
                                            id: prevMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: clockPanel.monthOffset -= 1
                                        }
                                    }

                                    Item {
                                        anchors.centerIn: parent
                                        width: monthTitle.implicitWidth + 16
                                        height: parent.height
                                        Text {
                                            id: monthTitle
                                            anchors.centerIn: parent
                                            text: Qt.formatDate(calBox.view, "MMMM yyyy")
                                            color: titleMa.containsMouse ? Theme.accent : Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sizeCalMonth
                                            font.bold: true
                                        }
                                        MouseArea {
                                            id: titleMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: clockPanel.monthOffset = 0
                                        }
                                    }

                                    Item {
                                        width: 28; height: parent.height
                                        anchors.right: parent.right
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uDB80\uDD42"
                                            color: nextMa.containsMouse ? Theme.accent : Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sizeCalArrow
                                        }
                                        MouseArea {
                                            id: nextMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: clockPanel.monthOffset += 1
                                        }
                                    }
                                }

                                Row {
                                    Repeater {
                                        model: 7
                                        delegate: Text {
                                            required property int index
                                            width: calBox.cellW
                                            horizontalAlignment: Text.AlignHCenter
                                            text: Qt.locale().dayName((index + calBox.firstDay) % 7, Locale.ShortFormat)
                                            color: Theme.textDim
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sizeCalWeekday
                                        }
                                    }
                                }

                                Grid {
                                    columns: 7
                                    Repeater {
                                        model: calBox.cells
                                        delegate: Item {
                                            required property var modelData
                                            width: calBox.cellW
                                            height: calBox.cellH

                                            Rectangle {
                                                visible: parent.modelData.today
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                radius: Theme.radius
                                                color: Qt.alpha(Theme.accent, 0.45)
                                                border.width: 1
                                                border.color: Theme.accent
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.modelData.n
                                                color: parent.modelData.inMonth ? Theme.text : Theme.textFaint
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sizeCalDay
                                                font.bold: parent.modelData.today
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Panel {
                anchors { right: parent.right; top: parent.top; rightMargin: 6; topMargin: 4 }
                width: rightRow.implicitWidth + 4

                Row {
                    id: rightRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 2

                    Item {
                        visible: Marquee.player !== null && Marquee.title !== ""
                        width: visible ? Math.min(Marquee.textW, Marquee.maxW) + 20 : 0
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            clip: true

                            Row {
                                x: Marquee.animating ? Marquee.x : 0
                                spacing: Marquee.gap
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: root.iconYOffset

                                Text {
                                    text: Marquee.text
                                    color: Theme.text
                                    font.family: Theme.iconFont
                                    font.pixelSize: root.sizeMarquee
                                    renderType: Text.NativeRendering
                                    width: Marquee.animating ? Marquee.textW
                                                             : Math.min(Marquee.textW, Marquee.maxW)
                                    elide: Marquee.animating ? Text.ElideNone : Text.ElideRight
                                }

                                Text {
                                    visible: Marquee.animating
                                    text: Marquee.text
                                    color: Theme.text
                                    font.family: Theme.iconFont
                                    font.pixelSize: root.sizeMarquee
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                const p = Marquee.player;
                                if (!p) return;
                                if (mouse.button === Qt.LeftButton) p.togglePlaying();
                                else if (mouse.button === Qt.RightButton) p.next();
                                else p.previous();
                            }
                        }
                    }

                    Mod {
                        readonly property var sink: Pipewire.defaultAudioSink
                        readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
                        readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
                        baseSize: root.sizeVolText
                        glyphSize: root.sizeVolIcon
                        glyph: muted || vol <= 0 ? "\uDB81\uDF5F"
                             : vol > 0.66 ? "\uDB81\uDD7E"
                             : vol > 0.33 ? "\uDB81\uDD80" : "\uDB81\uDD7F"
                        text: muted ? "Muted" : Math.round(vol * 100) + "%"
                        color: muted ? Theme.danger : Theme.text
                        onScrolled: delta => {
                            if (!sink || !sink.audio) return;
                            const v = sink.audio.volume + (delta / 120) * 0.02;
                            sink.audio.volume = Math.max(0, Math.min(1.0, v));
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
                            else
                                root.run("qs ipc call settings sound");
                        }
                    }

                    Mod {
                        visible: root.battery !== null
                        baseSize: root.sizeBatText
                        glyphSize: root.sizeBatIcon
                        glyph: (root.batCharging ? "\uf0e7 " : "") + root.batIcon
                        text: root.batPct + "%"
                        color: root.batLow ? Theme.danger : Theme.text
                    }

                    Mod {
                        baseSize: root.sizeNetIcon
                        yOffset: root.iconYOffset
                        text: root.netState === "wifi" ? "\uDB81\uDDA9"
                            : root.netState === "ethernet" ? "\uDB80\uDE00" : "\uDB81\uDDAA"
                        onClicked: root.run("qs ipc call settings network")
                    }

                    Mod {
                        baseSize: root.sizePowerIcon
                        hoverGrow: false
                        yOffset: root.iconYOffset
                        text: "\u23FB"
                        onClicked: root.run("qs ipc call powermenu toggle")
                    }
                }
            }
        }
    }
}
