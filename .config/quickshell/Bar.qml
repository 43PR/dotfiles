// Bar.qml — top bar (one per screen). Uses Theme.qml and Marquee.qml singletons.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: root

    // Nerd Font glyphs sit slightly high in their line box; nudge down (px).
    // Raise to 2 if icons still look high, set to 0 to disable.
    readonly property int iconYOffset: 1

    // ---------- Battery (laptops only) ----------
    // null on desktops (no laptop battery known to UPower) -> module hides itself.
    // Prefer a device flagged as a laptop battery; fall back to UPower's combined
    // "display device" when it reports a present battery.
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)

    // TEMPORARY DEBUG: prints what UPower sees 3s after start. Delete when done.
    Timer {
        interval: 3000; running: true; repeat: false
        onTriggered: {
            const ds = UPower.devices.values;
            console.log("[UPower] devices:", ds.length);
            for (const d of ds)
                console.log("[UPower]  dev", d.nativePath, "type", d.type,
                            "laptopBattery", d.isLaptopBattery, "present", d.isPresent,
                            "pct", d.percentage, "state", d.state);
            const dd = UPower.displayDevice;
            console.log("[UPower] display: present", dd ? dd.isPresent : null,
                        "type", dd ? dd.type : null, "pct", dd ? dd.percentage : null);
            console.log("[UPower] chosen battery:", root.battery);
        }
    }
    readonly property int batPct: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batCharging: battery !== null
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge)
    readonly property bool batLow: battery !== null && !batCharging && batPct <= 15
    // nf-fa battery empty / quarter / half / three-quarters / full
    readonly property var batIcons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
    readonly property string batIcon: batIcons[batPct >= 90 ? 4 : batPct >= 65 ? 3 : batPct >= 40 ? 2 : batPct >= 15 ? 1 : 0]

    // ---------- Show / hide (qs ipc call bar toggle|show|hide) ----------
    property bool barVisible: true
    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
    }

    // ---------- Shared state ----------
    property int cpuUsage: 0
    property int memPercent: 0
    property string netState: "disconnected" // wifi | ethernet | disconnected

    property real _prevTotal: 0
    property real _prevIdle: 0

    // ---------- Data sources ----------
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
            const total = kb("MemTotal");
            const avail = kb("MemAvailable");
            root.memPercent = Math.round(100 * (total - avail) / total);
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
                root.netState = s;
            }
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
        }
    }

    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Fire-and-forget command runner
    Process { id: runner }
    function run(cmd) {
        runner.command = ["sh", "-c", cmd];
        runner.running = true;
    }

    // ---------- Reusable module ----------
    component Mod: Item {
        id: mod
        property string text: ""
        property real baseSize: 11
        property color color: Theme.text
        property bool bold: false
        property bool hoverGrow: true
        property real yOffset: 0
        signal clicked(var mouse)
        signal scrolled(real delta)

        implicitWidth: label.implicitWidth + 20
        implicitHeight: 18

        Text {
            id: label
            anchors.centerIn: parent
            anchors.verticalCenterOffset: mod.yOffset
            verticalAlignment: Text.AlignVCenter
            text: mod.text
            color: mod.color
            font.family: Theme.iconFont
            font.bold: mod.bold
            font.pixelSize: (mod.hoverGrow && ma.containsMouse) ? 15 : mod.baseSize
            Behavior on font.pixelSize { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
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

    // ---------- Bar (one per screen) ----------
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

            // ===== LEFT =====
            Rectangle {
                anchors { left: parent.left; top: parent.top; leftMargin: 6; topMargin: 4 }
                height: 20
                width: leftRow.implicitWidth + 4
                radius: Theme.radius
                color: Theme.bg

                Row {
                    id: leftRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    spacing: 0

                    Mod { text: "CPU " + root.cpuUsage + "%" }
                    Mod { text: "RAM " + root.memPercent + "%" }

                    // Workspaces
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
                                Behavior on color { ColorAnimation { duration: Theme.animMed } }

                                MouseArea {
                                    id: dotMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: dot.modelData.activate()
                                }
                            }
                        }

                        // Scroll to switch workspace
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: e => root.run(e.angleDelta.y > 0
                                ? "hyprctl dispatch 'hl.dsp.focus({workspace=\"e+1\"})'"
                                : "hyprctl dispatch 'hl.dsp.focus({workspace=\"e-1\"})'")
                        }
                    }
                }
            }

            // ===== CENTER =====
            Rectangle {
                id: clockPanel
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 4 }
                height: 20
                width: clockMod.implicitWidth + 4
                radius: Theme.radius
                color: Theme.bg

                SystemClock { id: clk; precision: SystemClock.Minutes }

                Mod {
                    id: clockMod
                    anchors.centerIn: parent
                    bold: true
                    text: Qt.formatDateTime(clk.date, "HH:mm")
                }

                // ---- Popup open/close: stays open while the pointer is on the
                // clock OR on the popup (so the month arrows are clickable) ----
                HoverHandler { id: clockHover }

                property bool calOpen: false
                readonly property bool hoverAny: clockHover.hovered || calHover.hovered
                onHoverAnyChanged: {
                    if (hoverAny) { closeTimer.stop(); calOpen = true; }
                    else closeTimer.restart();
                }
                Timer {
                    id: closeTimer
                    interval: 200
                    onTriggered: { clockPanel.calOpen = false; calBox.monthOffset = 0; }
                }

                // ---- Calendar popup ----
                PopupWindow {
                    id: calendar
                    anchor.window: bar
                    anchor.rect.x: clockPanel.x + (clockPanel.width - calendar.implicitWidth) / 2
                    anchor.rect.y: clockPanel.y + clockPanel.height + 4
                    implicitWidth: calBox.gridW + 2 * calBox.pad
                    implicitHeight: calCol.implicitHeight + 2 * calBox.pad
                    color: "transparent"
                    visible: clockPanel.calOpen

                    Rectangle {
                        id: calBox
                        anchors.fill: parent
                        radius: 4                 // rectangular; raise for softer corners
                        color: Theme.bg

                        HoverHandler { id: calHover }

                        // ---- config ----
                        readonly property int firstDay: 1     // 0 = Sunday-first, 1 = Monday-first
                        readonly property int cellW: 36
                        readonly property int cellH: 30
                        readonly property int pad: 16
                        readonly property int gridW: cellW * 7

                        // ---- state ----
                        property int monthOffset: 0           // months away from the current one
                        readonly property date now: clk.date
                        readonly property date view: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
                        readonly property int offset: (view.getDay() - firstDay + 7) % 7

                        // scroll over the popup to change month
                        WheelHandler {
                            onWheel: e => calBox.monthOffset += (e.angleDelta.y > 0 ? -1 : 1)
                        }

                        Column {
                            id: calCol
                            anchors.centerIn: parent
                            spacing: 12

                            // ---- Time + date header ----
                            Item {
                                width: calBox.gridW
                                height: headCol.implicitHeight

                                Column {
                                    id: headCol
                                    spacing: 2
                                    Text {
                                        text: Qt.formatTime(calBox.now, "HH:mm")
                                        color: Theme.text
                                        font.family: Theme.iconFont
                                        font.pixelSize: 30
                                        font.bold: true
                                    }
                                    Text {
                                        text: Qt.formatDate(calBox.now, "dddd, d MMMM yyyy")
                                        color: Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            // ---- Divider ----
                            Rectangle {
                                width: calBox.gridW
                                height: 1
                                color: Qt.alpha(Theme.text, 0.12)
                            }

                            // ---- Month navigation ----
                            Item {
                                width: calBox.gridW
                                height: 26

                                Item {
                                    id: prevBtn
                                    width: 28; height: parent.height
                                    anchors.left: parent.left
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uDB80\uDD41"   // nf-md chevron_left
                                        color: prevMa.containsMouse ? Theme.accent : Theme.text
                                        font.family: Theme.iconFont
                                        font.pixelSize: 16
                                    }
                                    MouseArea {
                                        id: prevMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: calBox.monthOffset -= 1
                                    }
                                }

                                // Month title; click to jump back to today
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
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: titleMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: calBox.monthOffset = 0
                                    }
                                }

                                Item {
                                    id: nextBtn
                                    width: 28; height: parent.height
                                    anchors.right: parent.right
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uDB80\uDD42"   // nf-md chevron_right
                                        color: nextMa.containsMouse ? Theme.accent : Theme.text
                                        font.family: Theme.iconFont
                                        font.pixelSize: 16
                                    }
                                    MouseArea {
                                        id: nextMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: calBox.monthOffset += 1
                                    }
                                }
                            }

                            // ---- Weekday headers ----
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
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            // ---- Days (always 6 rows: height never jumps) ----
                            Grid {
                                columns: 7
                                Repeater {
                                    model: 42
                                    delegate: Item {
                                        id: dayCell
                                        required property int index
                                        readonly property date d: new Date(calBox.view.getFullYear(),
                                            calBox.view.getMonth(), index - calBox.offset + 1)
                                        readonly property bool inMonth: d.getMonth() === calBox.view.getMonth()
                                        readonly property bool today:
                                            d.getFullYear() === calBox.now.getFullYear()
                                            && d.getMonth() === calBox.now.getMonth()
                                            && d.getDate() === calBox.now.getDate()
                                        width: calBox.cellW
                                        height: calBox.cellH

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            radius: Theme.radius
                                            color: dayCell.today ? Qt.alpha(Theme.accent, 0.45)
                                                 : dayMa.containsMouse ? Qt.alpha(Theme.text, 0.08)
                                                 : "transparent"
                                            border.width: dayCell.today ? 1 : 0
                                            border.color: Theme.accent
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: dayCell.d.getDate()
                                            color: dayCell.inMonth ? Theme.text : Theme.textFaint
                                            font.family: Theme.iconFont
                                            font.pixelSize: 12
                                            font.bold: dayCell.today
                                        }
                                        MouseArea {
                                            id: dayMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ===== RIGHT =====
            Rectangle {
                anchors { right: parent.right; top: parent.top; rightMargin: 6; topMargin: 4 }
                height: 20
                width: rightRow.implicitWidth + 4
                radius: Theme.radius
                color: Theme.bg

                Row {
                    id: rightRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    spacing: 0

                    // MPRIS marquee (state + ticker live in Marquee.qml)
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
                                    font.pixelSize: 11
                                    renderType: Text.NativeRendering
                                    width: Marquee.animating ? Marquee.textW
                                                             : Math.min(Marquee.textW, Marquee.maxW)
                                    elide: Marquee.animating ? Text.ElideNone : Text.ElideRight
                                }

                                // Second copy only while scrolling (seamless wrap)
                                Text {
                                    visible: Marquee.animating
                                    text: Marquee.text
                                    color: Theme.text
                                    font.family: Theme.iconFont
                                    font.pixelSize: 11
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

                    // Volume
                    Mod {
                        readonly property var sink: Pipewire.defaultAudioSink
                        readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
                        readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
                        baseSize: 12
                        // nf-md volume_off / low / medium / high
                        readonly property string icon: muted || vol <= 0 ? "\uDB81\uDF5F"
                            : vol > 0.66 ? "\uDB81\uDD7E"
                            : vol > 0.33 ? "\uDB81\uDD80" : "\uDB81\uDD7F"
                        text: muted ? icon + "  Muted" : icon + "  " + Math.round(vol * 100) + "%"
                        color: muted ? Theme.danger : Theme.text

                        // Wheel while hovering: 2% per notch, capped at 100%
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

                    // Network (nf-md wifi / ethernet / wifi_off)
                    Mod {
                        baseSize: 13
                        yOffset: root.iconYOffset
                        text: root.netState === "wifi" ? "\uDB81\uDDA9"
                            : root.netState === "ethernet" ? "\uDB80\uDE00" : "\uDB81\uDDAA"
                        onClicked: root.run("qs ipc call settings network")
                    }

                    // Battery (hidden unless a laptop battery exists)
                    Mod {
                        visible: root.battery !== null
                        baseSize: 12
                        text: (root.batCharging ? "\uf0e7 " : "") + root.batIcon + "  " + root.batPct + "%"
                        color: root.batLow ? Theme.danger : Theme.text
                    }

                    // Power
                    Mod {
                        baseSize: 15
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