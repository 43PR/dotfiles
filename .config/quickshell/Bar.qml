import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: root

    // ───────────────────────── Config ─────────────────────────
    // Single source of truth for defaults (used by the adapter AND reset).
    readonly property var defaults: ({
        // layout
        position: "left", style: "joined", thickness: 20, margin: 4,
        reserveSpace: true, allScreens: true,
        // appearance
        scale: 1.0, bgOpacity: 0.5, border: false, radius: Theme.radius, calRadius: 15,
        // tooltips
        tooltips: true, tooltipHints: true, tipDelay: 450,
        // modules
        modPad: 20, wsDot: 10, wsGap: 8, wsScroll: true,
        statsMode: "compact", statsWarn: 85, batLowPct: 15,
        volStep: 2, volMax: 100,
        // clock / calendar
        clock24: true, clockSeconds: false, weekMonday: true,
        // module placement
        hidden: "stats,wall,settings,tasks",
        startMods: "stats,ws",
        centerMods: "clock",
        endMods: "media,volume,battery,net,notif,wall,settings,power"
    })
    readonly property var positions: ["top", "right", "bottom", "left"]
    readonly property var styles: ["floating", "joined", "strip"]
    readonly property var sections: ["start", "center", "end"]
    readonly property var statsModes: ["default", "compact"]

    Component.onCompleted: BluetoothState.init()

    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        adapter: JsonAdapter {
            id: cfg
            property string position: root.defaults.position
            property string style: root.defaults.style
            property int thickness: root.defaults.thickness
            property int margin: root.defaults.margin
            property bool reserveSpace: root.defaults.reserveSpace   // push windows away from the bar
            property bool allScreens: root.defaults.allScreens       // false → first screen only
            property real scale: root.defaults.scale
            property real bgOpacity: root.defaults.bgOpacity
            property bool border: root.defaults.border
            property int radius: root.defaults.radius            // bar corner radius
            property int calRadius: root.defaults.calRadius      // calendar popup corner radius
            property bool tooltips: root.defaults.tooltips
            property bool tooltipHints: root.defaults.tooltipHints // show "Left click: ..." lines in tooltips
            property int tipDelay: root.defaults.tipDelay        // ms before a tooltip appears
            property int modPad: root.defaults.modPad            // horizontal padding of text modules
            property int wsDot: root.defaults.wsDot              // workspace dot size
            property int wsGap: root.defaults.wsGap              // gap between workspace dots
            property bool wsScroll: root.defaults.wsScroll       // scroll on workspaces to switch
            property string statsMode: root.defaults.statsMode   // "default" | "compact"
            property int statsWarn: root.defaults.statsWarn      // CPU/RAM % that turns red
            property int batLowPct: root.defaults.batLowPct      // battery % that turns red
            property int volStep: root.defaults.volStep          // % per scroll notch
            property int volMax: root.defaults.volMax            // max volume %
            property bool clock24: root.defaults.clock24
            property bool clockSeconds: root.defaults.clockSeconds
            property bool weekMonday: root.defaults.weekMonday   // calendar week starts on Monday
            property string hidden: root.defaults.hidden         // comma list of disabled modules
            property string startMods: root.defaults.startMods
            property string centerMods: root.defaults.centerMods
            property string endMods: root.defaults.endMods
        }
    }

    Timer { id: saveTimer; interval: 300; onTriggered: cfgFile.writeAdapter() }

    function resetSettings() { for (const k in defaults) cfg[k] = defaults[k]; }
    readonly property bool modified: Object.keys(defaults).some(k => cfg[k] !== defaults[k])

    // ───────────────────────── Derived layout ─────────────────────────
    readonly property bool vertical: cfg.position === "left" || cfg.position === "right"
    readonly property bool joined: cfg.style !== "floating"
    readonly property bool strip: cfg.style === "strip"
    readonly property int panelThick: vertical ? cfg.thickness + 12 : cfg.thickness
    readonly property int effEdge: strip ? 0 : cfg.margin
    readonly property int effGap: strip ? 0 : 6
    readonly property real barRadius: strip ? 0 : cfg.radius
    readonly property color bgColor: Qt.alpha(Theme.bg, cfg.bgOpacity)
    readonly property color borderColor: Qt.alpha(Theme.accent, 0.25)

    function s(n) { return Math.round(n * cfg.scale); }

    readonly property var sz: ({
        stat: s(12), clock: s(12), marquee: s(11),
        icon: s(16), batIcon: s(13), batText: s(12), power: s(13),
        taskIcon: s(18),
        calTime: s(30), calDate: s(12), calMonth: s(13), calArrow: s(16),
        calWeekday: s(11), calDay: s(12)
    })
    readonly property int sizeIconGap: 12
    readonly property int iconYOffset: 1

    // margin for one side of the bar frame
    function edgeMargin(side) {
        if (cfg.position === side) return effEdge;
        const alongBar = vertical ? (side === "top" || side === "bottom")
                                  : (side === "left" || side === "right");
        return alongBar ? effGap : 0;
    }

    // ───────────────────────── Clock formatting ─────────────────────────
    function clockText(d) {
        const h24 = d.getHours();
        const h12 = h24 % 12 || 12;
        const mm = String(d.getMinutes()).padStart(2, "0");
        const ss = String(d.getSeconds()).padStart(2, "0");
        if (cfg.clock24)
        return (cfg.clockSeconds
        ? String(h24).padStart(2, "0") + ":" + mm + ":" + ss
        : String(h24).padStart(2, "0") + ":" + mm);
        const suffix = h24 >= 12 ? "PM" : "AM";
        return cfg.clockSeconds
        ? h12 + ":" + mm + ":" + ss + " " + suffix
        : h12 + ":" + mm + " " + suffix;
    }
    function clockVText(d) {
        const h24 = d.getHours();
        const h = cfg.clock24
        ? String(h24).padStart(2, "0")
        : String(h24 % 12 || 12);
        const mm = String(d.getMinutes()).padStart(2, "0");
        const parts = [h, mm];
        if (cfg.clockSeconds)
        parts.push(String(d.getSeconds()).padStart(2, "0"));
        if (!cfg.clock24)
        parts.push(h24 >= 12 ? "PM" : "AM");
        return parts.join("\n");
    }

    // ───────────────────────── Battery ─────────────────────────
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)
    readonly property int batPct: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batCharging: battery !== null
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge
            || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batLow: battery !== null && !batCharging && batPct <= cfg.batLowPct
    readonly property var batIcons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
    readonly property string batIcon: batIcons[batPct >= 90 ? 4 : batPct >= 65 ? 3 : batPct >= 40 ? 2 : batPct >= 15 ? 1 : 0]

    function fmtTime(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    readonly property string batTip: {
        if (battery === null) return "";
        const t = batCharging ? battery.timeToFull : battery.timeToEmpty;
        const st = battery.state === UPowerDeviceState.FullyCharged ? "fully charged"
                 : batCharging ? "charging" : "on battery";
        return "Battery " + batPct + "% · " + st
            + (t > 0 ? " · " + fmtTime(t) + (batCharging ? " to full" : " left") : "");
    }

    // ───────────────────────── Module registry ─────────────────────────
    // Modules with `cmd` are rendered by the generic iconC component:
    //   g = glyph, tip = tooltip title, hint = left-click description.
    // Modules without it have a dedicated Component below (see `comps`).
    readonly property var moduleDefs: [
        { id: "stats",    l: "CPU / RAM" },
        { id: "ws",       l: "Workspaces" },
        { id: "tasks",    l: "Open apps" },
        { id: "media",    l: "Media" },
        { id: "volume",   l: "Volume" },
        { id: "battery",  l: "Battery" },
        { id: "net",      l: "Network",       cmd: "qs ipc call settings network",
                                              hint: "Open network settings" },
        { id: "notif",    l: "Notifications", cmd: "qs ipc call notifications toggle", g: "\uDB80\uDC9C",
                                              tip: "Notifications", hint: "Toggle notification panel" },
        { id: "wall",     l: "Wallpapers",    cmd: "qs -n -p ~/.config/quickshell/hyprquickpaper", g: "\uDB80\uDEE9",
                                              tip: "Wallpapers", hint: "Open wallpaper picker" },
        { id: "settings", l: "Settings",      cmd: "qs ipc call settings toggle", g: "\uDB81\uDC93",
                                              tip: "Settings", hint: "Open settings" },
        { id: "power",    l: "Power",         cmd: "qs ipc call powermenu toggle", g: "\u23FB",
                                              tip: "Power menu", hint: "Open", fixed: true }
    ]
    readonly property var moduleIds: moduleDefs.map(d => d.id)
    readonly property var defMap: moduleDefs.reduce((m, d) => { m[d.id] = d; return m; }, {})
    readonly property var comps: ({
        stats: statsC, ws: wsC, tasks: tasksC, media: mediaC, volume: volumeC, battery: batteryC, icon: iconC
    })

    function csv(str) { return str === "" ? [] : str.split(","); }
    function valid(id) { return moduleIds.indexOf(id) >= 0; }

    // enable / disable
    readonly property var hiddenList: csv(cfg.hidden)
    function isOn(id) { return hiddenList.indexOf(id) < 0; }
    function setOn(id, on) {
        const h = hiddenList.filter(x => x !== id);
        if (!on) h.push(id);
        cfg.hidden = h.join(",");
    }

    function modVisible(id) {
        if (!isOn(id)) return false;
        switch (id) {
        case "stats":   return !vertical || cfg.statsMode === "compact";   // compact fits vertical bars
        case "media":   return Marquee.player !== null && Marquee.title !== "";
        case "battery": return battery !== null;
        default:        return true;
        }
    }

    // sections
    readonly property var startList: csv(cfg.startMods).filter(valid)
    readonly property var centerList: {
        const a = csv(cfg.centerMods).filter(x => x === "clock" || valid(x));
        return a.indexOf("clock") >= 0 ? a : ["clock"].concat(a);
    }
    readonly property var endList: {
        const a = csv(cfg.endMods).filter(valid);
        return a.concat(moduleIds.filter(x =>
            startList.indexOf(x) < 0 && centerList.indexOf(x) < 0 && a.indexOf(x) < 0));
    }

    function listOf(sec) { return (sec === "start" ? startList : sec === "center" ? centerList : endList).slice(); }
    function setList(sec, a) { cfg[sec + "Mods"] = a.join(","); }
    function sectionOf(id) { return sections.find(k => listOf(k).indexOf(id) >= 0) ?? "end"; }

    function moveTo(id, sec) {
        const next = {};
        for (const k of sections) next[k] = listOf(k).filter(x => x !== id);
        next[sec].push(id);
        for (const k of sections) setList(k, next[k]);
    }

    function canShift(id, d) {
        const a = listOf(sectionOf(id)), j = a.indexOf(id) + d;
        return j >= 0 && j < a.length;
    }

    function shiftBy(id, d) {
        if (!canShift(id, d)) return;
        const sec = sectionOf(id), a = listOf(sec), i = a.indexOf(id), j = i + d;
        [a[i], a[j]] = [a[j], a[i]];
        setList(sec, a);
    }

    // ───────────────────────── State / IPC ─────────────────────────
    property bool barVisible: true
    property bool settingsOpen: false
    property bool barLive: true

    function rebuildBar() { barLive = false; rebuildTimer.restart(); }
    Timer { id: rebuildTimer; interval: 80; onTriggered: root.barLive = true }
    Connections {
        target: cfg
        function onPositionChanged() { root.rebuildBar(); }
        function onStyleChanged() { root.rebuildBar(); }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
        function setPosition(pos: string): void { if (root.positions.indexOf(pos) >= 0) cfg.position = pos; }
        function cyclePosition(): void {
            cfg.position = root.positions[(root.positions.indexOf(cfg.position) + 1) % 4];
        }
        function setStyle(st: string): void { if (root.styles.indexOf(st) >= 0) cfg.style = st; }
        function setStatsMode(mode: string): void { if (root.statsModes.indexOf(mode) >= 0) cfg.statsMode = mode; }
        function customize(): void { root.settingsOpen = !root.settingsOpen; }
        function moveModule(id: string, section: string): void {
            if (root.valid(id) && root.sections.indexOf(section) >= 0) root.moveTo(id, section);
        }
        function shiftModule(id: string, delta: int): void { if (root.valid(id)) root.shiftBy(id, delta); }
    }

    // ───────────────────────── System stats ─────────────────────────
    property int cpuUsage: 0
    property int memPercent: 0
    property real memUsedG: 0
    property real memTotalG: 0
    property string netState: "disconnected"
    property real _prevTotal: 0
    property real _prevIdle: 0

    readonly property string netGlyph: netState === "wifi" ? "\uDB81\uDDA9"
                                     : netState === "ethernet" ? "\uDB80\uDE00" : "\uDB81\uDDAA"
    readonly property string netTip: netState === "wifi" ? "Wi-Fi connected"
                                   : netState === "ethernet" ? "Ethernet connected" : "Disconnected"

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            const dT = total - root._prevTotal, dI = idle - root._prevIdle;
            if (root._prevTotal > 0 && dT > 0) root.cpuUsage = Math.round(100 * (dT - dI) / dT);
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
            const total = kb("MemTotal"), used = total - kb("MemAvailable");
            root.memPercent = Math.round(100 * used / total);
            root.memUsedG = used / 1048576;
            root.memTotalG = total / 1048576;
        }
    }

    // Notification count: the notifications panel persists its history here
    property int notifCount: 0
    readonly property string notifTip: notifCount > 0 ? "Notifications: " + notifCount : "No notifications"

    FileView {
        id: notifFile
        path: Quickshell.env("HOME") + "/.cache/43pr/notifications.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.notifCount = JSON.parse(text()).length; }
            catch (e) { root.notifCount = 0; }
        }
        onLoadFailed: root.notifCount = 0
    }

    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let st = "disconnected";
                for (const l of text.split("\n")) {
                    if (l === "ethernet:connected") { st = "ethernet"; break; }
                    if (l === "wifi:connected") st = "wifi";
                }
                if (st !== root.netState) root.netState = st;
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
    function run(cmd) { runner.command = ["sh", "-c", cmd]; runner.running = true; }

    function mediaAct(kind) {
        const p = Marquee.player;
        if (!p) return;
        if (kind === "toggle") p.togglePlaying();
        else if (kind === "next") p.next();
        else p.previous();
    }

    readonly property string wsHints: "Left click: Switch to workspace\nRight click: Bar settings\nScroll: Previous / next workspace"

    // ───────────────────────── Interaction model ─────────────────────────
    // Convention used by every bar module:
    //   Left click   → primary action
    //   Right click  → secondary action (falls back to "Bar settings" if the module has none)
    //   Middle click → tertiary action (optional)
    //   Scroll       → adjust a value (optional)
    // Hints declared on a module are shown automatically in its tooltip.
    // States: hover · pressed · active (accent) · warning (danger) · disabled.

    component Lane: GridLayout {
        property int gap: 0
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: gap
        columnSpacing: gap
    }

    // Hover tooltip, anchored next to `target` on the side facing away from the bar edge.
    component Tip: Item {
        id: tp
        property Item target: parent
        property bool hot: false
        property string title: ""
        property string hints: ""
        property bool shown: false
        property bool suppressed: false   // set on click; cleared when the pointer leaves
        readonly property bool usable: cfg.tooltips && !suppressed && (title !== "" || hints !== "")

        width: 0
        height: 0
        onHotChanged: if (!hot) { shown = false; suppressed = false; }

        Timer {
            interval: cfg.tipDelay
            running: tp.hot && tp.usable && !tp.shown
            onTriggered: tp.shown = true
        }

        LazyLoader {
            active: tp.shown && tp.usable

            PopupWindow {
                readonly property var win: tp.target.QsWindow.window
                readonly property point p: win.contentItem.mapFromItem(tp.target, 0, 0)

                anchor.window: win
                anchor.adjustment: PopupAdjustment.Slide
                anchor.rect.x: root.vertical
                    ? (cfg.position === "left" ? p.x + tp.target.width + 6 : p.x - implicitWidth - 6)
                    : p.x + (tp.target.width - implicitWidth) / 2
                anchor.rect.y: root.vertical
                    ? p.y + (tp.target.height - implicitHeight) / 2
                    : (cfg.position === "top" ? p.y + tp.target.height + 6 : p.y - implicitHeight - 6)
                implicitWidth: tcol.implicitWidth + 20
                implicitHeight: tcol.implicitHeight + 14
                color: "transparent"
                visible: true

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: root.bgColor
                    border.width: 1
                    border.color: root.borderColor

                    Column {
                        id: tcol
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            visible: tp.title !== ""
                            text: tp.title
                            color: Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            visible: tp.hints !== ""
                            text: tp.hints
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    // Behaviour + visual states shared by every interactive bar element.
    component Interactive: Item {
        id: it
        property string tip: ""
        property string primaryHint: ""
        property string secondaryHint: ""      // empty → right click opens bar settings
        property string tertiaryHint: ""
        property string scrollHint: ""
        property string disabledReason: ""
        property bool active: false            // accent tint (e.g. calendar open)
        property bool warning: false           // danger tint (e.g. low battery, muted)
        property bool disabled: false          // dimmed, ignores input, tooltip explains why
        property bool interactive: true        // false → informational only (no hover tint / pointer)
        property bool noTip: false             // never show a tooltip for this element
        signal primary()
        signal secondary()
        signal tertiary()
        signal scrolled(real delta)

        readonly property bool hovered: ma.containsMouse && !disabled
        readonly property string hintText: {
            if (disabled) return disabledReason;
            if (!cfg.tooltipHints) return "";
            const l = [];
            if (primaryHint !== "") l.push("Left click: " + primaryHint);
            l.push("Right click: " + (secondaryHint !== "" ? secondaryHint : "Bar settings"));
            if (tertiaryHint !== "") l.push("Middle click: " + tertiaryHint);
            if (scrollHint !== "") l.push("Scroll: " + scrollHint);
            return l.join("\n");
        }

        function secondaryAction() {
            if (secondaryHint !== "") secondary();
            else root.settingsOpen = !root.settingsOpen;
        }

        opacity: disabled ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // state layer: pressed > active > warning, with a hover overlay
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radius
            color: ma.pressed && it.interactive && !it.disabled ? Qt.alpha(Theme.accent, 0.35)
                 : it.active ? Qt.alpha(Theme.accent, 0.22)
                 : it.warning ? Qt.alpha(Theme.danger, 0.16)
                 : Qt.alpha(Theme.text, 0)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: it.hovered && it.interactive ? Qt.alpha(Theme.text, 0.1) : Qt.alpha(Theme.text, 0)
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: it.interactive && !it.disabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: { tipper.suppressed = true; tipper.shown = false; }
            onClicked: mouse => {
                if (it.disabled) return;
                if (mouse.button === Qt.LeftButton) it.primary();
                else if (mouse.button === Qt.MiddleButton) it.tertiary();
                else it.secondaryAction();
            }
            onWheel: wheel => {
                wheel.accepted = it.scrollHint !== "" && !it.disabled;
                if (wheel.accepted) it.scrolled(wheel.angleDelta.y);
            }
        }

        Tip {
            id: tipper
            target: it
            hot: !it.noTip && ma.containsMouse
            title: it.tip
            hints: it.hintText
        }
    }

    // Icon / text module built on Interactive
    component Mod: Interactive {
        id: mod
        property string mid: ""          // set by Slot; used by generic icon modules
        property string text: ""
        property string vtext: text
        property string glyph: ""
        property string vglyph: glyph
        property real glyphSize: 16
        property real baseSize: 11
        property color color: Theme.text
        property bool bold: false
        property real yOffset: 0
        property int spacing: root.sizeIconGap
        property int padX: cfg.modPad

        readonly property color fg: warning ? Theme.danger : active ? Theme.accent : color
        readonly property string shown: root.vertical ? vtext : text
        readonly property string shownGlyph: root.vertical ? vglyph : glyph

        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.vertical ? root.panelThick : content.implicitWidth + padX
        implicitHeight: root.vertical ? Math.max(20, content.implicitHeight + 8)
                                      : Math.max(root.panelThick - 2, content.implicitHeight)

        GridLayout {
            id: content
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.vertical ? 0 : mod.yOffset
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 2
            columnSpacing: mod.spacing

            Text {
                visible: mod.shownGlyph !== ""
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: mod.shownGlyph
                color: mod.fg
                font.family: Theme.iconFont
                font.pixelSize: mod.glyphSize
                renderType: Text.NativeRendering
            }
            Text {
                visible: mod.shown !== ""
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: mod.shown
                color: mod.fg
                font.family: Theme.iconFont
                font.bold: mod.bold
                font.pixelSize: mod.baseSize
                renderType: Text.NativeRendering
            }
        }
    }

    component Slot: Loader {
        required property string modelData
        property Component clockComp: null
        visible: root.modVisible(modelData)
        Layout.alignment: Qt.AlignCenter
        sourceComponent: modelData === "clock" ? clockComp : (root.comps[modelData] ?? root.comps.icon)
        onLoaded: if (item.mid !== undefined) item.mid = modelData
    }

    // One of the three bar sections: a rounded panel holding a Lane of Slots
    component Panel: Rectangle {
        id: panel
        property var model: []
        property Component clockComp: null
        readonly property Item lane: laneItem

        visible: (root.vertical ? laneItem.implicitHeight : laneItem.implicitWidth) > 0
        width: root.vertical ? root.panelThick : laneItem.implicitWidth + 4
        height: root.vertical ? laneItem.implicitHeight + 4 : root.panelThick
        radius: root.barRadius
        color: root.joined ? "transparent" : root.bgColor
        border.width: cfg.border && !root.joined ? 1 : 0
        border.color: root.borderColor

        Lane {
            id: laneItem
            anchors.centerIn: parent
            Repeater {
                model: panel.model
                delegate: Slot { clockComp: panel.clockComp }
            }
        }
    }

    // ───────────────────────── Settings-window widgets ─────────────────────────
    // Same look as the power-menu settings: section headers, label + value
    // sliders, toggle rows, pill buttons and in-window hover hints.

    component Rule: Rectangle {
        height: 1
        color: Qt.alpha(Theme.text, 0.12)
    }

    // Small hover hint drawn inside the settings window (no extra popup
    // surface). Respects the "Tooltips" setting. The host row raises its own
    // z while `shown` so the hint isn't covered by the rows below it.
    component SetTip: Rectangle {
        id: stp
        property string text: ""
        property bool hovered: false
        property bool shown: false
        readonly property bool wanted: cfg.tooltips && text !== "" && hovered

        onWantedChanged: {
            if (wanted) {
                stDelay.restart();
            } else {
                stDelay.stop();
                shown = false;
            }
        }
        Timer { id: stDelay; interval: cfg.tipDelay; onTriggered: stp.shown = stp.wanted }

        z: 1000
        x: 0
        y: parent.height + 2
        width: stText.implicitWidth + 16
        height: stText.implicitHeight + 10
        radius: 6
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 1)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.15)
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            id: stText
            anchors.centerIn: parent
            text: stp.text
            font.family: Theme.iconFont
            font.pixelSize: 10
            color: Theme.text
        }
    }

    component SectionHeader: Item {
        property string text: ""
        Layout.fillWidth: true
        implicitHeight: 32

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: parent.text
            font.family: Theme.iconFont
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
            color: Theme.textDim
        }
    }

    // Pure switch visual with its own click handling.
    component ToggleSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled(bool v)
        width: 36; height: 20; radius: 10
        color: checked ? Theme.accent : "transparent"
        border.width: 1
        border.color: checked ? Theme.accent : Qt.alpha(Theme.text, 0.3)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: 14; height: 14; radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Theme.bg : Theme.text
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled(!sw.checked)
        }
    }

    // Segmented control (position, style, section …)
    component SegControl: Rectangle {
        id: seg
        property var options: []
        property string current: ""
        signal picked(string v)
        implicitWidth: segRow.implicitWidth + 4
        implicitHeight: 24
        radius: 12
        opacity: enabled ? 1 : 0.4
        color: Qt.alpha(Theme.text, 0.08)

        Row {
            id: segRow
            anchors.centerIn: parent
            Repeater {
                model: seg.options
                delegate: Rectangle {
                    id: opt
                    required property string modelData
                    implicitWidth: optText.implicitWidth + 14
                    width: implicitWidth
                    height: 20
                    radius: 10
                    color: modelData === seg.current ? Qt.alpha(Theme.accent, 0.4)
                         : optMa.containsMouse ? Qt.alpha(Theme.text, 0.14) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        id: optText
                        anchors.centerIn: parent
                        text: opt.modelData
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                        font.capitalization: Font.Capitalize
                        color: opt.modelData === seg.current ? Theme.text : Theme.textDim
                    }
                    MouseArea {
                        id: optMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(opt.modelData)
                    }
                }
            }
        }
    }

    component ArrowBtn: Rectangle {
        id: arb
        property string glyph: ""
        signal clicked()
        implicitWidth: 22
        implicitHeight: 22
        radius: 6
        opacity: enabled ? 1 : 0.35
        color: Qt.alpha(Theme.text, arbMa.containsMouse && enabled ? 0.18 : 0.08)
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            anchors.centerIn: parent
            text: arb.glyph
            font.pixelSize: 9
            color: Theme.text
        }
        MouseArea {
            id: arbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arb.clicked()
        }
    }

    component ToggleRow: Item {
        id: tr
        property string label: ""
        property string tip: ""
        property bool checked: false
        signal toggled(bool v)

        Layout.fillWidth: true
        implicitHeight: 34
        z: trTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -8
            anchors.rightMargin: -8
            radius: 8
            color: trMa.containsMouse && tr.enabled ? Qt.alpha(Theme.text, 0.06) : "transparent"
        }

        Text {
            anchors.left: parent.left
            anchors.right: trSw.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            elide: Text.ElideRight
            font.family: Theme.iconFont
            font.pixelSize: 12
            font.bold: true
            color: Theme.text
        }

        MouseArea {
            id: trMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tr.toggled(!tr.checked)
        }

        ToggleSwitch {
            id: trSw
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: tr.checked
            onToggled: v => tr.toggled(v)
        }

        SetTip { id: trTip; text: tr.tip; hovered: trMa.containsMouse }
    }

    // Label on the left, segmented choice on the right.
    component SegRow: Item {
        id: sgr
        property string label: ""
        property string tip: ""
        property var options: []
        property string current: ""
        signal picked(string v)

        Layout.fillWidth: true
        implicitHeight: 38
        z: sgTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4

        MouseArea { id: sgMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

        RowLayout {
            anchors.fill: parent
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: sgr.label
                elide: Text.ElideRight
                font.family: Theme.iconFont
                font.pixelSize: 12
                font.bold: true
                color: Theme.text
            }
            SegControl {
                options: sgr.options
                current: sgr.current
                onPicked: v => sgr.picked(v)
            }
        }

        SetTip { id: sgTip; text: sgr.tip; hovered: sgMa.containsMouse }
    }

    // Label + value on top, track below. Writes through `moved`; the
    // adapter debounces saving, so nothing to do on release.
    component SliderRow: Item {
        id: sr
        property string label: ""
        property string tip: ""
        property real from: 0
        property real to: 1
        property real step: 1
        property real value: 0
        property string unit: ""
        property real displayScale: 1
        property int decimals: 0
        signal moved(real v)

        readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

        Layout.fillWidth: true
        implicitHeight: 44
        z: srTip.shown ? 100 : 0
        opacity: enabled ? 1 : 0.4

        Text {
            anchors.left: parent.left
            y: 6
            text: sr.label
            font.family: Theme.iconFont
            font.pixelSize: 12
            font.bold: true
            color: Theme.text
        }

        Text {
            anchors.right: parent.right
            y: 6
            text: (sr.value * sr.displayScale).toFixed(sr.decimals) + sr.unit
            font.family: Theme.iconFont
            font.pixelSize: 11
            color: Theme.textDim
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            y: 30
            height: 4
            radius: 2
            color: Qt.alpha(Theme.text, 0.15)

            Rectangle {
                width: knob.x + knob.width / 2
                height: parent.height
                radius: 2
                color: Theme.accent
            }
            Rectangle {
                id: knob
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: sr.ratio * (track.width - width)
                color: Theme.text
            }
        }

        MouseArea {
            id: srMa
            anchors.fill: parent
            anchors.topMargin: 20
            hoverEnabled: true
            // keeps the page from scrolling while a slider is being dragged
            preventStealing: true
            cursorShape: Qt.PointingHandCursor

            function apply(mx) {
                const usable = track.width - knob.width;
                if (usable <= 0) return;
                const r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable));
                const v = sr.from + r * (sr.to - sr.from);
                sr.moved(sr.step > 0 ? +(Math.round(v / sr.step) * sr.step).toFixed(3) : v);
            }
            onPressed: m => apply(m.x)
            onPositionChanged: m => { if (pressed) apply(m.x); }
        }

        SetTip { id: srTip; text: sr.tip; hovered: srMa.containsMouse && !srMa.pressed }
    }

    // One row of the "Modules" list: enable · section · move earlier / later
    component ModuleRow: Item {
        id: mr
        property var def: ({})
        Layout.fillWidth: true
        implicitHeight: 38

        RowLayout {
            anchors.fill: parent
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: mr.def.l ?? ""
                elide: Text.ElideRight
                font.family: Theme.iconFont
                font.pixelSize: 12
                font.bold: true
                color: Theme.text
            }
            ToggleSwitch {
                enabled: !mr.def.fixed
                opacity: enabled ? 1 : 0.4
                checked: !!mr.def.fixed || root.isOn(mr.def.id)
                onToggled: v => root.setOn(mr.def.id, v)
            }
            SegControl {
                options: root.sections
                current: root.sectionOf(mr.def.id)
                onPicked: v => root.moveTo(mr.def.id, v)
            }
            ArrowBtn {
                glyph: root.vertical ? "\u25B2" : "\u25C0"
                enabled: root.canShift(mr.def.id, -1)
                onClicked: root.shiftBy(mr.def.id, -1)
            }
            ArrowBtn {
                glyph: root.vertical ? "\u25BC" : "\u25B6"
                enabled: root.canShift(mr.def.id, 1)
                onClicked: root.shiftBy(mr.def.id, 1)
            }
        }
    }

    component ActionButton: Rectangle {
        id: ab
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitWidth: abText.implicitWidth + 28
        width: implicitWidth
        height: 30
        radius: 15
        opacity: enabled ? 1 : 0.4
        color: primary
            ? Theme.accent
            : Qt.alpha(Theme.text, abArea.containsMouse ? 0.18 : 0.1)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: abText
            anchors.centerIn: parent
            text: ab.label
            font.family: Theme.iconFont
            font.pixelSize: 11
            font.bold: true
            color: ab.primary ? Theme.bg : Theme.text
        }
        MouseArea {
            id: abArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: ab.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.clicked()
        }
    }

    // One line of the controls cheat-sheet: description left, chip right.
    component KeyRow: Item {
        id: kr
        property string keys: ""
        property string desc: ""

        Layout.fillWidth: true
        implicitHeight: 26

        Text {
            anchors.left: parent.left
            anchors.right: chip.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: kr.desc
            elide: Text.ElideRight
            font.family: Theme.iconFont
            font.pixelSize: 11
            color: Theme.text
        }
        Rectangle {
            id: chip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + 14
            height: 18
            radius: 5
            color: Qt.alpha(Theme.text, 0.08)
            Text {
                id: chipText
                anchors.centerIn: parent
                text: kr.keys
                font.family: Theme.iconFont
                font.pixelSize: 10
                font.bold: true
                color: Theme.textDim
            }
        }
    }


    // ───────────────────────── Bar helper components ─────────────────────────
    component Arrow: Item {
        id: ar
        property string glyph: ""
        signal clicked()
        width: 28
        height: 26
        Text {
            anchors.centerIn: parent
            text: ar.glyph
            color: arMa.containsMouse ? Theme.accent : Theme.text
            font.family: Theme.iconFont
            font.pixelSize: root.sz.calArrow
        }
        MouseArea {
            id: arMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ar.clicked()
        }
    }

    // Scrolling now-playing text. Rotated 90° by its parent on vertical bars.
    component MarqueeStrip: Item {
        clip: true
        Row {
            x: Marquee.animating ? Marquee.x : 0
            spacing: Marquee.gap
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.vertical ? 0 : root.iconYOffset

            Repeater {
                model: Marquee.animating ? 2 : 1
                delegate: Text {
                    required property int index
                    text: Marquee.text
                    color: Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: root.sz.marquee
                    renderType: root.vertical ? Text.QtRendering : Text.NativeRendering
                    // first copy is width-limited/elided when not scrolling
                    width: index === 0 ? (Marquee.animating ? Marquee.textW
                                                            : Math.min(Marquee.textW, Marquee.maxW))
                                       : implicitWidth
                    elide: index === 0 && !Marquee.animating ? Text.ElideRight : Text.ElideNone
                }
            }
        }
    }

    // ───────────────────────── Module components ─────────────────────────
    // Generic icon button: net / notif / wall / settings / power (driven by moduleDefs)
    Component {
        id: iconC
        Mod {
            property var def: root.defMap[mid] ?? ({})
            readonly property bool isNet: mid === "net"
            baseSize: mid === "power" ? root.sz.power : root.sz.icon
            yOffset: root.iconYOffset
            text: isNet ? root.netGlyph : (def.g ?? "")
            tip: isNet ? root.netTip : mid === "notif" ? root.notifTip : (def.tip ?? "")
            primaryHint: def.hint ?? ""
            warning: isNet && root.netState === "disconnected"
            onPrimary: if (def.cmd) root.run(def.cmd)
        }
    }

    // CPU / RAM — "default": `CPU 12%`   "compact": small icon + `12%`
    Component {
        id: statsC
        Lane {
            Repeater {
                model: ["CPU", "RAM"]
                delegate: Mod {
                    required property string modelData
                    readonly property bool isCpu: modelData === "CPU"
                    readonly property bool compact: cfg.statsMode === "compact"
                    readonly property int val: isCpu ? root.cpuUsage : root.memPercent

                    baseSize: root.sz.stat
                    glyphSize: root.sz.stat + 2
                    glyph: compact ? (isCpu ? "\uDB81\uDE1A" : "\uDB80\uDF5B") : ""
                    text: compact ? val + "%" : modelData + " " + val + "%"
                    spacing: compact ? 4 : root.sizeIconGap
                    padX: compact ? Math.max(0, cfg.modPad - 8) : cfg.modPad

                    interactive: false
                    warning: val >= cfg.statsWarn
                    tip: isCpu ? "CPU usage: " + val + "%"
                               : "Memory: " + root.memUsedG.toFixed(1) + " / " + root.memTotalG.toFixed(1)
                                 + " GiB (" + val + "%)"
                }
            }
        }
    }

    Component {
        id: wsC
        Item {
            implicitWidth: root.vertical ? root.panelThick : wsLane.implicitWidth + 12
            implicitHeight: wsLane.implicitHeight + (root.vertical ? 12 : 0)

            Lane {
                id: wsLane
                anchors.centerIn: parent
                gap: cfg.wsGap

                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        id: dot
                        required property var modelData
                        visible: modelData.id > 0
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: root.vertical ? cfg.wsDot
                                     : (modelData.focused ? Math.round(cfg.wsDot * 3.2) : cfg.wsDot)
                        implicitHeight: root.vertical ? (modelData.focused ? Math.round(cfg.wsDot * 2.4) : cfg.wsDot)
                                                      : cfg.wsDot
                        radius: cfg.wsDot / 2
                        color: modelData.urgent ? Theme.danger
                             : modelData.focused ? Qt.alpha(Theme.accent, 0.2)
                             : dotMa.containsMouse ? Theme.accent2
                             : Qt.alpha(Theme.textFaint, 0.5)

                        Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                        Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }

                        MouseArea {
                            id: dotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: { dotTip.suppressed = true; dotTip.shown = false; }
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) root.settingsOpen = !root.settingsOpen;
                                else dot.modelData.activate();
                            }
                        }

                        Tip {
                            id: dotTip
                            hot: dotMa.containsMouse
                            title: "Workspace " + dot.modelData.id
                                   + (dot.modelData.urgent ? " · urgent" : dot.modelData.focused ? " · focused" : "")
                            hints: cfg.tooltipHints ? root.wsHints : ""
                        }
                    }
                }
            }

            WheelHandler {
                enabled: cfg.wsScroll
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => root.run("hyprctl dispatch 'hl.dsp.focus({workspace=\"e"
                                       + (e.angleDelta.y > 0 ? "+1" : "-1") + "\"})'")
            }
        }
    }
    Component {
        id: tasksC
        Lane {
            gap: 2
            Repeater {
                model: ToplevelManager.toplevels
                delegate: Interactive {
                    id: task
                    required property var modelData
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData.appId)
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth: root.vertical ? root.panelThick : root.sz.taskIcon + 10
                    implicitHeight: root.vertical ? root.sz.taskIcon + 10
                                                  : Math.max(root.panelThick - 2, root.sz.taskIcon + 6)
                    active: modelData.activated
                    tip: modelData.title !== "" ? modelData.title : modelData.appId
                    primaryHint: "Focus window"
                    tertiaryHint: "Close window"
                    onPrimary: modelData.activate()
                    onTertiary: modelData.close()
                    Image {
                        anchors.centerIn: parent
                        width: root.sz.taskIcon
                        height: root.sz.taskIcon
                        sourceSize: Qt.size(width, height)
                        asynchronous: true
                        smooth: true
                        opacity: task.modelData.activated ? 1 : 0.75
                        source: Quickshell.iconPath(task.entry?.icon ?? task.modelData.appId.toLowerCase(),
                                                    "application-x-executable")
                    }
                }
            }
        }
    }
    Component {
        id: mediaC
        Interactive {
            readonly property bool playing: Marquee.player !== null && Marquee.player.isPlaying === true
            readonly property real len: Math.min(Marquee.textW, Marquee.maxW)   // visible text length

            implicitWidth: root.vertical ? root.panelThick : len + 20
            implicitHeight: root.vertical ? len + 20 : 18

            tip: Marquee.text
            primaryHint: playing ? "Pause" : "Play"
            secondaryHint: "Next track"
            tertiaryHint: "Previous track"
            onPrimary: root.mediaAct("toggle")
            onSecondary: root.mediaAct("next")
            onTertiary: root.mediaAct("prev")

            // On vertical bars the same marquee is rotated: reads bottom→top on the left, top→bottom on the right.
            MarqueeStrip {
                anchors.centerIn: parent
                width: parent.len
                height: 18
                rotation: root.vertical ? (cfg.position === "left" ? -90 : 90) : 0
            }
        }
    }

    Component {
        id: volumeC
        Mod {
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property bool ready: !!(sink && sink.audio)
            readonly property real vol: ready ? sink.audio.volume : 0
            readonly property bool muted: ready ? sink.audio.muted : false

            glyphSize: root.sz.icon
            glyph: muted || vol <= 0 ? "\uDB81\uDF5F" : "\uDB81\uDD7E"
            warning: muted
            disabled: !ready
            disabledReason: "No audio output available"
            tip: !ready ? "Volume" : muted ? "Volume: muted" : "Volume: " + Math.round(vol * 100) + "%"
            primaryHint: "Open sound settings"
            secondaryHint: "Mute / unmute"
            scrollHint: "Adjust volume"

            onPrimary: root.run("qs ipc call settings sound")
            onSecondary: root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
            onScrolled: delta => {
                if (!ready) return;
                sink.audio.volume = Math.max(0, Math.min(cfg.volMax / 100,
                    sink.audio.volume + (delta / 120) * (cfg.volStep / 100)));
            }
        }
    }

    Component {
        id: batteryC
        Mod {
            glyphSize: root.sz.icon
            glyph: root.batIcon
            warning: root.batLow
            active: root.batCharging
            tip: root.batTip
        }
    }

    // ───────────────────────── Settings window ─────────────────────────
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: settingsWin
            // Fixed height: content scrolls inside the Flickable instead of
            // resizing the window.
            implicitWidth: 420
            implicitHeight: Math.min(640, (screen?.height ?? 800) * 0.85)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "bar-settings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: Theme.bg
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.12)
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.settingsOpen = false

                // header (pinned)
                Item {
                    id: head
                    anchors.top: parent.top
                    width: parent.width
                    height: 60

                    Text {
                        x: 20; y: 12
                        text: "Bar settings"
                        font.family: Theme.iconFont
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.text
                    }
                    Text {
                        x: 20; y: 34
                        text: "Changes apply instantly and are saved automatically."
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: Theme.textDim
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        y: 10
                        width: 24; height: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "×"
                        font.pixelSize: 22
                        color: closeArea.containsMouse ? Theme.text : Theme.textDim
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.settingsOpen = false
                        }
                    }
                }

                // body: mouse wheel / touchpad scroll natively; sliders keep
                // their drag via preventStealing
                Flickable {
                    id: flick
                    anchors.top: head.bottom
                    anchors.topMargin: 4
                    anchors.bottom: foot.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    contentWidth: width
                    contentHeight: col.implicitHeight + 16
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: col
                        x: 20
                        width: flick.width - 48
                        spacing: 0

                        // ── Hints ──
                        SectionHeader { text: "Hints" }
                        ToggleRow {
                            label: "Show tooltips"
                            checked: cfg.tooltips
                            onToggled: v => cfg.tooltips = v
                        }
                        ToggleRow {
                            label: "Hints in tooltips"
                            checked: cfg.tooltipHints
                            enabled: cfg.tooltips
                            onToggled: v => cfg.tooltipHints = v
                        }
                        SliderRow {
                            label: "Tooltip delay"
                            enabled: cfg.tooltips
                            from: 0; to: 1500; step: 50; unit: " ms"
                            value: cfg.tipDelay
                            onMoved: v => cfg.tipDelay = v
                        }

                        // ── Layout ──
                        SectionHeader { text: "Layout" }
                        SegRow {
                            label: "Position"
                            options: root.positions
                            current: cfg.position
                            onPicked: v => cfg.position = v
                        }
                        SegRow {
                            label: "Style"
                            options: root.styles
                            current: cfg.style
                            onPicked: v => cfg.style = v
                        }
                        SliderRow {
                            label: "Thickness"
                            from: 16; to: 40; step: 1; unit: " px"
                            value: cfg.thickness
                            onMoved: v => cfg.thickness = v
                        }
                        SliderRow {
                            label: "Edge margin"
                            enabled: !root.strip
                            from: 0; to: 16; step: 1; unit: " px"
                            value: cfg.margin
                            tip: "Gap between the bar and the screen edge"
                            onMoved: v => cfg.margin = v
                        }
                        ToggleRow {
                            label: "Reserve screen space"
                            checked: cfg.reserveSpace
                            tip: "Off: windows may overlap the bar"
                            onToggled: v => cfg.reserveSpace = v
                        }
                        ToggleRow {
                            label: "Show on all monitors"
                            checked: cfg.allScreens
                            onToggled: v => cfg.allScreens = v
                        }

                        // ── Appearance ──
                        SectionHeader { text: "Appearance" }
                        SliderRow {
                            label: "Background opacity"
                            from: 0; to: 1; step: 0.05; unit: "%"; displayScale: 100
                            value: cfg.bgOpacity
                            onMoved: v => cfg.bgOpacity = v
                        }
                        SliderRow {
                            label: "Corner radius"
                            enabled: !root.strip
                            from: 0; to: 24; step: 1; unit: " px"
                            value: cfg.radius
                            onMoved: v => cfg.radius = v
                        }
                        SliderRow {
                            label: "Calendar radius"
                            from: 0; to: 32; step: 1; unit: " px"
                            value: cfg.calRadius
                            onMoved: v => cfg.calRadius = v
                        }
                        SliderRow {
                            label: "Text scale"
                            from: 0.8; to: 1.5; step: 0.05; unit: "×"; decimals: 2
                            value: cfg.scale
                            onMoved: v => cfg.scale = v
                        }
                        ToggleRow {
                            label: "Border"
                            checked: cfg.border
                            onToggled: v => cfg.border = v
                        }

                        // ── Clock & calendar ──
                        SectionHeader { text: "Clock & calendar" }
                        ToggleRow {
                            label: "24-hour clock"
                            checked: cfg.clock24
                            onToggled: v => cfg.clock24 = v
                        }
                        ToggleRow {
                            label: "Show seconds"
                            checked: cfg.clockSeconds
                            onToggled: v => cfg.clockSeconds = v
                        }
                        SegRow {
                            label: "Week starts on"
                            options: ["monday", "sunday"]
                            current: cfg.weekMonday ? "monday" : "sunday"
                            onPicked: v => cfg.weekMonday = (v === "monday")
                        }

                        // ── Modules ──
                        SectionHeader { text: "Module appearance" }
                        SliderRow {
                            label: "Module padding"
                            from: 0; to: 40; step: 2; unit: " px"
                            value: cfg.modPad
                            tip: "Horizontal space around text modules"
                            onMoved: v => cfg.modPad = v
                        }
                        SliderRow {
                            label: "Workspace dot size"
                            from: 6; to: 18; step: 1; unit: " px"
                            value: cfg.wsDot
                            onMoved: v => cfg.wsDot = v
                        }
                        SliderRow {
                            label: "Workspace dot spacing"
                            from: 0; to: 20; step: 1; unit: " px"
                            value: cfg.wsGap
                            onMoved: v => cfg.wsGap = v
                        }
                        ToggleRow {
                            label: "Scroll to switch workspace"
                            checked: cfg.wsScroll
                            onToggled: v => cfg.wsScroll = v
                        }
                        SegRow {
                            label: "CPU / RAM style"
                            options: root.statsModes
                            current: cfg.statsMode
                            onPicked: v => cfg.statsMode = v
                        }
                        SliderRow {
                            label: "High CPU / RAM warning"
                            from: 50; to: 100; step: 5; unit: "%"
                            value: cfg.statsWarn
                            tip: "Usage at or above this turns red"
                            onMoved: v => cfg.statsWarn = v
                        }
                        SliderRow {
                            label: "Low battery warning"
                            from: 5; to: 50; step: 5; unit: "%"
                            value: cfg.batLowPct
                            onMoved: v => cfg.batLowPct = v
                        }
                        SliderRow {
                            label: "Volume scroll step"
                            from: 1; to: 10; step: 1; unit: "%"
                            value: cfg.volStep
                            onMoved: v => cfg.volStep = v
                        }
                        SliderRow {
                            label: "Maximum volume"
                            from: 100; to: 150; step: 5; unit: "%"
                            value: cfg.volMax
                            tip: "Above 100% may distort on some speakers"
                            onMoved: v => cfg.volMax = v
                        }

                        // ── Module list ──
                        SectionHeader { text: "Modules" }
                        Repeater {
                            model: root.moduleDefs
                            delegate: ModuleRow {
                                required property var modelData
                                def: modelData
                            }
                        }
                    }
                }

                // scrollbar (outside the content so it doesn't scroll away)
                Rectangle {
                    visible: flick.contentHeight > flick.height
                    x: flick.x + flick.width - 14
                    y: flick.y
                    width: 4
                    height: flick.height
                    radius: 2
                    color: Qt.alpha(Theme.text, 0.08)
                }

                Rectangle {
                    id: sbHandle
                    visible: flick.contentHeight > flick.height
                    x: flick.x + flick.width - 14
                    y: flick.y + flick.visibleArea.yPosition * flick.height
                    width: 4
                    height: Math.max(24, flick.height * flick.visibleArea.heightRatio)
                    radius: 2
                    color: Theme.text
                    opacity: sbMa.containsMouse || sbMa.pressed || flick.moving ? 0.7 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea {
                        id: sbMa
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        preventStealing: true
                        property real grabY: 0

                        // drive contentY directly (drag.target would break the y binding)
                        onPressed: m => {
                            grabY = mapToItem(flick, m.x, m.y).y - flick.visibleArea.yPosition * flick.height;
                        }
                        onPositionChanged: m => {
                            if (!pressed) return;
                            const span = flick.height - sbHandle.height;
                            if (span <= 0) return;
                            const r = Math.max(0, Math.min(1, (mapToItem(flick, m.x, m.y).y - grabY) / span));
                            flick.contentY = r * (flick.contentHeight - flick.height);
                        }
                    }
                }

                // footer (pinned)
                Item {
                    id: foot
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 58

                    Rule { width: parent.width }

                    ActionButton {
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Reset all"
                        enabled: root.modified
                        onClicked: root.resetSettings()
                    }
                    ActionButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Done"
                        primary: true
                        onClicked: root.settingsOpen = false
                    }
                }
            }
        }
    }

    // ───────────────────────── The bar ─────────────────────────
    Variants {
        model: root.barLive
            ? (cfg.allScreens ? Quickshell.screens : Quickshell.screens.slice(0, 1))
            : []

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: cfg.position !== "bottom"
                bottom: cfg.position !== "top"
                left: cfg.position !== "right"
                right: cfg.position !== "left"
            }
            implicitWidth: root.vertical ? root.panelThick + root.effEdge : 0
            implicitHeight: root.vertical ? 0 : root.panelThick + root.effEdge
            exclusionMode: cfg.reserveSpace ? ExclusionMode.Auto : ExclusionMode.Ignore
            color: "transparent"
            visible: root.barVisible

            Item {
                id: frame
                anchors {
                    fill: parent
                    topMargin: root.edgeMargin("top")
                    bottomMargin: root.edgeMargin("bottom")
                    leftMargin: root.edgeMargin("left")
                    rightMargin: root.edgeMargin("right")
                }

                Rectangle {
                    visible: root.joined
                    anchors.fill: parent
                    radius: root.barRadius
                    color: root.bgColor
                    border.width: cfg.border ? 1 : 0
                    border.color: root.borderColor
                }

                Panel {
                    model: root.startList
                    anchors.left: frame.left
                    anchors.top: frame.top
                }

                Panel {
                    id: clockPanel
                    model: root.centerList
                    clockComp: clockC
                    anchors.horizontalCenter: root.vertical ? undefined : frame.horizontalCenter
                    anchors.verticalCenter: root.vertical ? frame.verticalCenter : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined

                    property bool calOpen: false
                    property int monthOffset: 0

                    SystemClock {
                        id: clk
                        precision: cfg.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
                    }

                    Component {
                        id: clockC
                        Mod {
                            bold: true
                            baseSize: root.sz.clock
                            text: root.clockText(clk.date)
                            vtext: root.clockVText(clk.date)
                            active: clockPanel.calOpen
                            tip: Qt.formatDate(clk.date, "dddd, d MMMM yyyy")
                            primaryHint: clockPanel.calOpen ? "Close calendar" : "Open calendar"
                            tertiaryHint: "Settings"
                            onPrimary: {
                                clockPanel.monthOffset = 0;
                                clockPanel.calOpen = !clockPanel.calOpen;
                            }
                            onTertiary: root.run("qs ipc call settings toggle")
                        }
                    }
                    LazyLoader {
                        active: clockPanel.calOpen

                        PopupWindow {
                            readonly property point p: bar.contentItem.mapFromItem(clockPanel, 0, 0)

                            anchor.window: bar
                            anchor.rect.x: root.vertical
                                ? (cfg.position === "left" ? p.x + clockPanel.width + 6
                                                           : p.x - implicitWidth - 6)
                                : p.x + (clockPanel.width - implicitWidth) / 2
                            anchor.rect.y: root.vertical
                                ? p.y + (clockPanel.height - implicitHeight) / 2
                                : (cfg.position === "top" ? p.y + clockPanel.height + 4
                                                          : p.y - implicitHeight - 4)
                            implicitWidth: calBox.gridW + 2 * calBox.pad
                            implicitHeight: calCol.implicitHeight + 2 * calBox.pad
                            color: "transparent"
                            visible: true

                            Rectangle {
                                id: calBox
                                anchors.fill: parent
                                radius: cfg.calRadius
                                color: root.bgColor
                                border.width: cfg.border ? 1 : 0
                                border.color: root.borderColor

                                readonly property int firstDay: cfg.weekMonday ? 1 : 0
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
                                    return Array.from({ length: 42 }, (_, i) => {
                                        const d = new Date(y, m, i - first + 1);
                                        return {
                                            n: d.getDate(),
                                            inMonth: d.getMonth() === m,
                                            today: d.getFullYear() === ty && d.getMonth() === tm && d.getDate() === td
                                        };
                                    });
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
                                            text: root.clockText(calBox.now)
                                            color: Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sz.calTime
                                            font.bold: true
                                        }
                                        Text {
                                            text: Qt.formatDate(calBox.now, "dddd, d MMMM yyyy")
                                            color: Theme.textDim
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sz.calDate
                                        }
                                    }

                                    Rule { width: calBox.gridW }

                                    Item {
                                        width: calBox.gridW
                                        height: 26

                                        Arrow {
                                            anchors.left: parent.left
                                            glyph: "\uDB80\uDD41"
                                            onClicked: clockPanel.monthOffset -= 1
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
                                                font.pixelSize: root.sz.calMonth
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: titleMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: clockPanel.monthOffset = 0
                                            }
                                        }

                                        Arrow {
                                            anchors.right: parent.right
                                            glyph: "\uDB80\uDD42"
                                            onClicked: clockPanel.monthOffset += 1
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
                                                font.pixelSize: root.sz.calWeekday
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
                                                    font.pixelSize: root.sz.calDay
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
                    model: root.endList
                    anchors.right: root.vertical ? undefined : frame.right
                    anchors.bottom: root.vertical ? frame.bottom : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined
                }
            }
        }
    }
}