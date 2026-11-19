import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import QtQuick.Shapes
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
Scope {
    id: root
    readonly property var defaults: ({
        position: "left", style: "islands", thickness: 22, margin: 4, insetH: 11, insetV: 4,
        reserveSpace: true, allScreens: true, dragModules: true,
        scale: 0.9, barScale: 0.75, bgOpacity: 0.1, border: true, borderOpacity: 0.1, radius: 15, calRadius: 15, calScale: 0.9,
        tooltips: true, tooltipHints: true, tooltipBorder: true, tipDelay: 450, tooltipScale: 0.85,
        modPad: 3, islandGap: 4, wsDot: 15, wsGap: 10, wsScroll: true, wsStyle: "minimal",
        tasksScale: 0.75, tasksGap: 2, tasksColor: "accent",
        statsRing: true, statsNumbers: false, statsPercent: false, statsIcons: false, statsScale: 1, statsBorder: false, statsRadius: 24, statsGap: 0, statsWarn: 85, tempWarn: 85, batLowPct: 15,
        batNumber: false, batPercent: false, batRing: true, batLabel: false,
        volStep: 5, volMax: 100, volNumber: false, volPercent: false, volRing: true, volLabel: false,
        trayArrow: true, lightIcons: "star", brightStep: 5, nightStep: 100, brightRing: true, nightRing: true,
        clock24: true, clockSeconds: false, clockPadHour: true, clockAmPm: true, clockDate: true, clockDay: false, clockCase: "normal", dateOrder: "md", weekMonday: true,
        weatherIcon: false, weatherF: false, weatherCity: "", weatherCase: "upper", weatherSymbol: true,
        clockPrimary: "calendar", clockSecondary: "settings", clockTertiary: "barsettings",
        settingsPrimary: "settings", settingsSecondary: "barsettings", settingsTertiary: "none",
        hidden: "gputemp,gpu,settings,bright,night,wall",
        startMods: "cputemp,ram,cpu,gpu,gputemp",
        midLeftMods: "tasks,tray,ws",
        centerMods: "clock",
        midRightMods: "media",
        endMods: "volume,net,bt,notif,power,bright,night,battery,settings,wall"
    })
    readonly property var positions: ["top", "right", "bottom", "left"]
    readonly property var styles: ["floating", "joined", "strip", "islands"]
    readonly property var sections: ["start", "midLeft", "center", "midRight", "end"]
    readonly property var config: cfg; Component.onCompleted: BluetoothState.init()
    FileView {
        id: cfgFile; path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"; printErrors: false
        watchChanges: true; onFileChanged: reload()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        adapter: JsonAdapter {
            id: cfg; property string position: root.defaults.position; property string style: root.defaults.style
            property int thickness: root.defaults.thickness; property int margin: root.defaults.margin
            property int insetH: root.defaults.insetH; property int insetV: root.defaults.insetV
            property bool reserveSpace: root.defaults.reserveSpace; property bool allScreens: root.defaults.allScreens
            property bool dragModules: root.defaults.dragModules; property real scale: root.defaults.scale
            property real barScale: root.defaults.barScale; property real bgOpacity: root.defaults.bgOpacity
            property bool border: root.defaults.border; property real borderOpacity: root.defaults.borderOpacity
            property int radius: root.defaults.radius; property int calRadius: root.defaults.calRadius
            property real calScale: root.defaults.calScale; property bool tooltips: root.defaults.tooltips
            property bool tooltipHints: root.defaults.tooltipHints
            property bool tooltipBorder: root.defaults.tooltipBorder; property int tipDelay: root.defaults.tipDelay
            property real tooltipScale: root.defaults.tooltipScale; property int modPad: root.defaults.modPad; property int islandGap: root.defaults.islandGap
            property int wsDot: root.defaults.wsDot; property int wsGap: root.defaults.wsGap
            property bool wsScroll: root.defaults.wsScroll; property string wsStyle: root.defaults.wsStyle
            property real tasksScale: root.defaults.tasksScale; property int tasksGap: root.defaults.tasksGap
            property string tasksColor: root.defaults.tasksColor; property bool statsRing: root.defaults.statsRing
            property bool statsNumbers: root.defaults.statsNumbers
            property bool statsPercent: root.defaults.statsPercent; property bool statsIcons: root.defaults.statsIcons
            property real statsScale: root.defaults.statsScale; property bool statsBorder: root.defaults.statsBorder
            property int statsRadius: root.defaults.statsRadius; property int statsGap: root.defaults.statsGap
            property int statsWarn: root.defaults.statsWarn; property int tempWarn: root.defaults.tempWarn
            property int batLowPct: root.defaults.batLowPct; property bool batNumber: root.defaults.batNumber
            property bool batPercent: root.defaults.batPercent; property bool batRing: root.defaults.batRing
            property bool batLabel: root.defaults.batLabel; property bool volRing: root.defaults.volRing
            property bool volLabel: root.defaults.volLabel; property int volStep: root.defaults.volStep
            property int volMax: root.defaults.volMax; property bool volNumber: root.defaults.volNumber
            property bool volPercent: root.defaults.volPercent; property int brightStep: root.defaults.brightStep
            property int nightStep: root.defaults.nightStep; property bool brightRing: root.defaults.brightRing
            property bool trayArrow: root.defaults.trayArrow
            property bool nightRing: root.defaults.nightRing; property string lightIcons: root.defaults.lightIcons
            property bool clock24: root.defaults.clock24; property bool clockSeconds: root.defaults.clockSeconds
            property bool clockPadHour: root.defaults.clockPadHour; property bool clockAmPm: root.defaults.clockAmPm
            property bool clockDate: root.defaults.clockDate
            property bool clockDay: root.defaults.clockDay; property string clockCase: root.defaults.clockCase
            property string dateOrder: root.defaults.dateOrder; property bool weekMonday: root.defaults.weekMonday
            property string clockPrimary: root.defaults.clockPrimary
            property string clockSecondary: root.defaults.clockSecondary
            property string clockTertiary: root.defaults.clockTertiary
            property string settingsPrimary: root.defaults.settingsPrimary
            property string settingsSecondary: root.defaults.settingsSecondary
            property string settingsTertiary: root.defaults.settingsTertiary
            property bool weatherIcon: root.defaults.weatherIcon; property bool weatherF: root.defaults.weatherF
            property string weatherCity: root.defaults.weatherCity; property string weatherCase: root.defaults.weatherCase
            property bool weatherSymbol: root.defaults.weatherSymbol
            property string hidden: root.defaults.hidden; property string startMods: root.defaults.startMods
            property string midLeftMods: root.defaults.midLeftMods
            property string centerMods: root.defaults.centerMods
            property string midRightMods: root.defaults.midRightMods; property string endMods: root.defaults.endMods
        }
    }
    Timer { id: saveTimer; interval: 300; onTriggered: cfgFile.writeAdapter() }
    function save() { saveTimer.restart(); }
    function resetSettings() { for (const k in defaults) cfg[k] = defaults[k]; }
    readonly property bool modified: Object.keys(defaults).some(k => cfg[k] !== defaults[k])
    readonly property bool vertical: cfg.position === "left" || cfg.position === "right"
    readonly property bool strip: cfg.style === "strip"; readonly property bool islands: cfg.style === "islands"
    readonly property bool joined: cfg.style === "joined" || cfg.style === "strip"
    readonly property real bs: cfg.barScale
    readonly property int panelThick: Math.round((vertical ? cfg.thickness + 12 : cfg.thickness) * bs)
    readonly property int effEdge: strip ? 0 : Math.round(cfg.margin * bs)
    readonly property int effGap: strip ? 0 : Math.round(6 * bs)
    readonly property int alongMargin: strip || islands ? 0 : Math.round(14 * bs)
    readonly property int barInset: vertical ? cfg.insetV : cfg.insetH
    readonly property int modPadPx: Math.round(cfg.modPad * bs)
    readonly property int islandGapPx: Math.round(cfg.islandGap * bs)
    readonly property var selfPadded: ["cpu", "ram", "gpu", "cputemp", "gputemp", "ws", "tasks", "clock", "media"]

    readonly property int wsBoxPx: Math.max(3, Math.round(cfg.wsDot * bs))
    readonly property int wsGapPx: Math.round(cfg.wsGap * bs)
    readonly property real barRadius: strip ? 0 : cfg.radius
    readonly property color bgColor: Qt.alpha(Theme.bg, cfg.bgOpacity)
    readonly property color borderColor: Qt.alpha(Theme.accent, cfg.borderOpacity)
    function s(n) { return Math.round(n * cfg.scale * cfg.barScale); }
    readonly property var sz: ({
        stat: s(12), clock: s(12), marquee: s(12),
        icon: s(16), batText: s(12), power: s(16), taskIcon: s(18)
    })
    readonly property int sizeIconGap: Math.round(12 * bs); readonly property int iconYOffset: 1
    readonly property int taskIconPx: Math.max(8, Math.min(Math.round(sz.taskIcon * cfg.tasksScale), panelThick - 2))
    readonly property int taskGapPx: Math.round(cfg.tasksGap * bs)
    readonly property int trayIconPx: Math.max(8, Math.round(taskIconPx * IconTune.resolve("tray", vertical).trayScale))
    readonly property bool hasTray: SystemTray.items.values.some(i => i.status !== Status.Passive)
    readonly property int trayEdge: vertical ? (cfg.position === "left" ? Edges.Right : Edges.Left)
    : (cfg.position === "top" ? Edges.Bottom : Edges.Top)
    function trayChevron(flip) {
        const down = trayEdge === Edges.Bottom, up = trayEdge === Edges.Top, right = trayEdge === Edges.Right;
        if (flip) return down ? "\uf077" : up ? "\uf078" : right ? "\uf053" : "\uf054";
        return down ? "\uf078" : up ? "\uf077" : right ? "\uf054" : "\uf053";
    }
    function trayHostOf(item) {
        let p = item;
        while (p) {
            if (p.isTrayHost === true) return p;
            p = p.parent;
        }
        return null;
    }
    function edgeMargin(side) {
        if (cfg.position === side) return effEdge;
        const alongBar = vertical ? (side === "top" || side === "bottom")
                                  : (side === "left" || side === "right");
        return alongBar ? alongMargin : 0;
    }
    function snapStep(cur, step, dir) {
        return dir > 0 ? (Math.floor(cur / step) + 1) * step : (Math.ceil(cur / step) - 1) * step;
    }
    function desktopEntry(appId) {
        const id = appId ?? "";
        try {
            return DesktopEntries.heuristicLookup(id)
                ?? DesktopEntries.heuristicLookup(id.toLowerCase())
                ?? DesktopEntries.byId(id)
                ?? DesktopEntries.byId(id.toLowerCase());
        } catch (e) { return null; }
    }
    function iconFor(appId) {
        const id = appId ?? "";
        const low = id.toLowerCase();
        const cands = [];
        const add = c => { if (c && cands.indexOf(c) < 0) cands.push(c); };
        const entry = desktopEntry(id);
        if (entry) {
            add(entry.icon);
            add(entry.id);
            add((entry.id ?? "").toLowerCase());
        }
        add(id);
        add(low);
        add(low.replace(/\s+/g, "-"));
        add(low.replace(/[._\s]+/g, "-"));
        const parts = low.split(".");
        if (parts.length > 1) {
            add(parts[parts.length - 1]);
            add(parts.slice(-2).join("-"));
        }
        const dash = low.split("-");
        if (dash.length > 1) add(dash[0]);
        for (const c of cands) {
            if (c.startsWith("/")) return "file://" + c;
            if (c.startsWith("file://") || c.startsWith("image://")) return c;
            const p = Quickshell.iconPath(c, true);
            if (p !== "") return p;
        }
        return Quickshell.iconPath("application-x-executable", true)
            || Quickshell.iconPath("application-default-icon", true)
            || Quickshell.iconPath("image-missing");
    }
    function appName(appId) {
        const entry = desktopEntry(appId);
        return entry && entry.name ? entry.name : (appId ?? "");
    }
    function pad2(n) { return String(n).padStart(2, "0"); }
    function applyCase(v) {
        return cfg.clockCase === "upper" ? v.toUpperCase()
             : cfg.clockCase === "lower" ? v.toLowerCase() : v;
    }
    function hourText(d) {
        const h = cfg.clock24 ? d.getHours() : (d.getHours() % 12 || 12);
        return cfg.clockPadHour ? pad2(h) : String(h);
    }
    function ampmText(d) { return applyCase(d.getHours() >= 12 ? "PM" : "AM"); }
    function dayText(d) { return applyCase(Qt.formatDate(d, "ddd")); }
    function clockParts(d) {
        const p = [hourText(d), pad2(d.getMinutes())];
        if (cfg.clockSeconds) p.push(pad2(d.getSeconds()));
        return p;
    }
    function clockText(d) {
        const t = clockParts(d).join(":");
        return cfg.clock24 || !cfg.clockAmPm ? t : t + " " + ampmText(d);
    }
    function clockVText(d) {
        const p = clockParts(d);
        if (!cfg.clock24 && cfg.clockAmPm) p.push(ampmText(d));
        return p.join("\n");
    }
    function clockBarText(d) {
        const t = clockText(d);
        if (!cfg.clockDate) return t;
        return t + "  \u2022  " + (cfg.clockDay ? dayText(d) + ", " : "")
             + Qt.formatDate(d, cfg.dateOrder === "md" ? "MM/dd" : "dd/MM");
    }
    function clockBarVText(d) {
        const t = clockVText(d);
        if (!cfg.clockDate) return t;
        const dd = Qt.formatDate(d, "dd"), mm = Qt.formatDate(d, "MM");
        return t + "\n\u2022\n" + (cfg.clockDay ? dayText(d) + "\n" : "")
             + (cfg.dateOrder === "md" ? mm + "\n" + dd : dd + "\n" + mm);
    }
    property bool batTest: false
    property int batTestPct: 60
    property bool batTestCharging: false
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)
    readonly property bool hasBattery: batTest || battery !== null
    readonly property int batPct: batTest ? batTestPct
                                          : battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batCharging: batTest ? batTestCharging
        : battery !== null
          && (battery.state === UPowerDeviceState.Charging
              || battery.state === UPowerDeviceState.PendingCharge
              || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batLow: hasBattery && !batCharging && batPct <= cfg.batLowPct
    readonly property var batGlyphsV: [
        "\uDB80\uDC8E", "\uDB80\uDC7A", "\uDB80\uDC7B", "\uDB80\uDC7C", "\uDB80\uDC7D", "\uDB80\uDC7E",
        "\uDB80\uDC7F", "\uDB80\uDC80", "\uDB80\uDC81", "\uDB80\uDC82", "\uDB80\uDC79"
    ]
    readonly property string batGlyphV: batGlyphsV[Math.max(0, Math.min(10, Math.round(batPct / 10)))]
    function fmtTime(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }
    readonly property string batTip: {
        if (batTest)
            return "Battery " + batPct + "% · " + (batCharging ? "charging" : "on battery") + " · test mode";
        if (battery === null) return "";
        const t = batCharging ? battery.timeToFull : battery.timeToEmpty;
        const st = battery.state === UPowerDeviceState.FullyCharged ? "fully charged"
                 : batCharging ? "charging" : "on battery";
        return "Battery " + batPct + "% · " + st
            + (t > 0 ? " · " + fmtTime(t) + (batCharging ? " to full" : " left") : "");
    }
    readonly property bool hasBt: Bluetooth.defaultAdapter !== null
    readonly property bool btOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    function btDevices() {
        const a = Bluetooth.defaultAdapter;
        if (!a || !a.enabled || !a.devices) return [];
        return a.devices.values !== undefined ? a.devices.values : a.devices;
    }
    readonly property var btConnectedNames: {
        const out = [];
        for (const d of btDevices()) {
            if (d.state !== BluetoothDeviceState.Connected) continue;
            let n = d.name || d.deviceName || d.address;
            if (d.batteryAvailable) n += " " + Math.round(d.battery * 100) + "%";
            out.push(n);
        }
        return out;
    }
    readonly property bool btConnecting: btDevices().some(d => d.state === BluetoothDeviceState.Connecting)
    readonly property string btGlyph: !btOn ? "\uf294"
    : btConnectedNames.length > 0 ? "\uDB80\uDCB1"
    : "\uf294"
    readonly property string btTip: !btOn ? "Bluetooth: off"
    : btConnecting ? "Bluetooth: connecting…"
    : btConnectedNames.length > 0 ? "Bluetooth: " + btConnectedNames.join(", ")
    : "Bluetooth: on, no devices connected"
    readonly property var moduleDefs: [
        { id: "clock",    l: "Clock" },
        { id: "cpu",      l: "CPU" },
        { id: "ram",      l: "RAM" },
        { id: "gpu",      l: "GPU" },
        { id: "cputemp",  l: "CPU temperature" },
        { id: "gputemp",  l: "GPU temperature" },
        { id: "ws",       l: "Workspaces" },
        { id: "tasks",    l: "Open apps" },
        { id: "tray",     l: "System tray" },
        { id: "media",    l: "Media" },
        { id: "volume",   l: "Volume" },
        { id: "bright",   l: "Brightness" },
        { id: "night",    l: "Night light" },
        { id: "battery",  l: "Battery" },
        { id: "bt",       l: "Bluetooth" },
        { id: "net",      l: "Network" },
        { id: "weather",  l: "Weather" },
        { id: "notif",    l: "Notifications", cmd: "qs ipc call notifications toggle", g: "\uDB80\uDC9C",
                                              tip: "Notifications", hint: "Toggle notification panel" },
        { id: "wall",     l: "Wallpapers",    cmd: "qs -n -p ~/.config/quickshell/hyprquickpaper", g: "\uDB80\uDEE9",
                                              tip: "Wallpapers", hint: "Open wallpaper picker" },
        { id: "settings", l: "Settings",      cmd: "qs ipc call settings toggle", g: "\uDB81\uDC93",
                                              tip: "Settings", hint: "Open settings" },
        { id: "power",    l: "Power",         cmd: "qs ipc call powermenu toggle", g: "\u23FB",
                                              tip: "Power menu", hint: "Open" }
    ]
    readonly property var moduleIds: moduleDefs.map(d => d.id)
    readonly property var defMap: moduleDefs.reduce((m, d) => { m[d.id] = d; return m; }, {})
    readonly property var comps: ({
        cpu: cpuC, ram: ramC, gpu: gpuC, cputemp: cpuTempC, gputemp: gpuTempC,
        ws: wsMinimal ? wsMinC : wsDotsC, tasks: tasksC, tray: trayC, media: mediaC, volume: volumeC,
        bright: brightC, night: nightC, battery: batteryC,
        bt: btC, net: netC, weather: weatherC, clock: clockC, icon: iconC
    })
    function csv(str) {
        if (str === "") return [];
        const out = [];
        for (const x of str.split(","))
            x === "stats" ? out.push("cpu", "ram")
          : x === "temp"  ? out.push("cputemp", "gputemp")
          : x === "light" ? out.push("bright", "night")
          : out.push(x);
        return out;
    }
    function valid(id) { return moduleIds.indexOf(id) >= 0; }
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
        case "media":   return Marquee.player !== null && Marquee.title !== "";
        case "battery": return hasBattery;
        case "bt":      return hasBt;
        case "tray":    return cfg.trayArrow ? SystemTray.items.values.length > 0 : hasTray;
        default:        return true;
        }
    }
    readonly property var startList: csv(cfg.startMods).filter(valid)
    readonly property var midLeftList: csv(cfg.midLeftMods).filter(valid)
    readonly property var centerList: csv(cfg.centerMods).filter(valid)
    readonly property var midRightList: csv(cfg.midRightMods).filter(valid)
    readonly property var endList: {
        const a = csv(cfg.endMods).filter(valid);
        return a.concat(moduleIds.filter(x =>
            startList.indexOf(x) < 0 && midLeftList.indexOf(x) < 0 && centerList.indexOf(x) < 0
            && midRightList.indexOf(x) < 0 && a.indexOf(x) < 0));
    }
    function listOf(sec) {
        return (sec === "start" ? startList
              : sec === "midLeft" ? midLeftList
              : sec === "center" ? centerList
              : sec === "midRight" ? midRightList : endList).slice();
    }
    function setList(sec, a) { cfg[sec + "Mods"] = a.join(","); }
    function sectionOf(id) { return sections.find(k => listOf(k).indexOf(id) >= 0) ?? "end"; }
    readonly property var statIds: ["cpu", "ram", "gpu", "cputemp", "gputemp"]
    function groupsOf(ids) {
        if (!islands) return [ids];
        const out = [];
        let last = "";
        for (const id of ids) {
            if (!isOn(id)) continue;
            const key = statIds.indexOf(id) >= 0 ? "stats" : id;
            if (out.length > 0 && key === last) out[out.length - 1].push(id);
            else out.push([id]);
            last = key;
        }
        return out;
    }
    function moveToIndex(id, sec, idx) {
        const next = {};
        for (const k of sections) next[k] = listOf(k);
        const from = next[sec].indexOf(id);
        for (const k of sections) next[k] = next[k].filter(x => x !== id);
        if (from >= 0 && from < idx) idx -= 1;
        idx = Math.max(0, Math.min(idx, next[sec].length));
        next[sec].splice(idx, 0, id);
        for (const k of sections) setList(k, next[k]);
    }
    function moveTo(id, sec) { moveToIndex(id, sec, listOf(sec).length); }
    function shiftBy(id, d) {
        const sec = sectionOf(id), a = listOf(sec), i = a.indexOf(id), j = i + d;
        if (j < 0 || j >= a.length) return;
        [a[i], a[j]] = [a[j], a[i]];
        setList(sec, a);
    }
    function slotOf(item) {
        let p = item;
        while (p) {
            if (p.isSlot === true) return p;
            p = p.parent;
        }
        return null;
    }
    property bool barVisible: true; property bool barLive: true
    function rebuildBar() { barLive = false; rebuildTimer.restart(); }
    Timer { id: rebuildTimer; interval: 80; onTriggered: root.barLive = true }
    Connections {
        target: cfg
        function onPositionChanged() { root.rebuildBar(); }
        function onStyleChanged() { root.rebuildBar(); }
    }
    function openSettings() { run("qs ipc call settings bar"); }
    function actionHint(a) {
        return a === "calendar" ? "Side panel"
             : a === "settings" ? "Settings"
             : a === "barsettings" ? "Bar settings"
             : a === "quickactions" ? "Quick actions" : "";
    }
    function doAction(a) {
        if (a === "calendar") openSidepanelAt(null);
        else if (a === "settings") run("qs ipc call settings toggle");
        else if (a === "barsettings") openSettings();
        else if (a === "quickactions") run("qs ipc call qa toggle");
    }
    function openSidepanelAt(item) {
        const win = item && item.QsWindow ? item.QsWindow.window : null;
        if (!win || !win.screen) {
            Quickshell.execDetached(["qs", "ipc", "call", "sidepanel", "toggle"]);
            return;
        }
        const c = item.mapToItem(win.contentItem, item.width / 2, item.height / 2);
        const along = Math.round(root.vertical ? c.y : c.x);
        const edge = root.panelThick + root.effEdge;
        Quickshell.execDetached([
            "qs", "ipc", "call", "sidepanel", "toggleAt",
            win.screen.name, cfg.position, String(along), String(edge)
        ]);
    }
    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
        function setTrayArrow(on: bool): void { cfg.trayArrow = on; root.save(); }
        function setPosition(pos: string): void {
            if (root.positions.indexOf(pos) >= 0) { cfg.position = pos; root.save(); }
        }
        function cyclePosition(): void {
            cfg.position = root.positions[(root.positions.indexOf(cfg.position) + 1) % 4];
            root.save();
        }
        function setStyle(st: string): void {
            if (root.styles.indexOf(st) >= 0) { cfg.style = st; root.save(); }
        }
        function customize(): void { root.openSettings(); }
        function moveModule(id: string, section: string): void {
            if (root.valid(id) && root.sections.indexOf(section) >= 0) { root.moveTo(id, section); root.save(); }
        }
        function shiftModule(id: string, delta: int): void {
            if (root.valid(id)) { root.shiftBy(id, delta); root.save(); }
        }
        function batteryTest(on: bool): void { root.batTest = on; }
        function batteryLevel(pct: int): void { root.batTestPct = Math.max(0, Math.min(100, pct)); }
        function batteryCharging(on: bool): void { root.batTestCharging = on; }
    }
    StatsSubscription { active: root.barVisible && root.isOn("cpu");  keys: ["cpu"] }
    StatsSubscription { active: root.barVisible && root.isOn("ram");  keys: ["mem"] }
    StatsSubscription { active: root.barVisible && root.isOn("gpu");  keys: ["gpu"] }
    StatsSubscription { active: root.barVisible && (root.isOn("cputemp") || root.isOn("gputemp")); keys: ["temp"] }
    readonly property int cpuUsage: Math.round(SystemStats.cpuUsage)
    readonly property int memPercent: Math.round(SystemStats.memPercent)
    readonly property real memUsedG: SystemStats.memUsedG; readonly property real memTotalG: SystemStats.memTotalG
    readonly property int gpuUsage: SystemStats.gpuUsage; readonly property bool gpuHasUsage: SystemStats.gpuHasUsage
    readonly property int cpuTemp: SystemStats.cpuTemp; readonly property int gpuTemp: SystemStats.gpuTemp
    function tempText(v) { return v >= 0 ? v + "" : "–"; }
    function tempTip(name, v) {
        return name + " temperature: " + (v >= 0 ? v + "°C" : "no sensor detected");
    }
    property bool wxOk: false; property real wxTempC: 0; property int wxCode: 0; property bool wxDay: true
    property bool wxHave: false; property real wxLat: 0; property real wxLon: 0
    property string wxReal: ""
    readonly property var wxNames: ({
        0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
        45: "Fog", 48: "Fog", 51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
        56: "Freezing drizzle", 57: "Freezing drizzle", 61: "Light rain", 63: "Rain", 65: "Heavy rain",
        66: "Freezing rain", 67: "Freezing rain", 71: "Light snow", 73: "Snow", 75: "Heavy snow",
        77: "Snow grains", 80: "Rain showers", 81: "Rain showers", 82: "Heavy showers",
        85: "Snow showers", 86: "Snow showers", 95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm"
    })
    readonly property string wxDesc: wxNames[wxCode] ?? ""
    function wxGlyph(c) {
        if (c === 0 || c === 1) return wxDay ? "\uDB81\uDD99" : "\uDB81\uDD94";
        if (c === 2) return wxDay ? "\uDB81\uDD95" : "\uDB83\uDF31";
        if (c === 3) return "\uDB81\uDD90";
        if (c === 45 || c === 48) return "\uDB81\uDD91";
        if (c >= 95) return "\uDB81\uDE7E";
        if (c === 56 || c === 57 || c === 66 || c === 67) return "\uDB81\uDE7F";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "\uDB81\uDD98";
        if (c === 65 || c === 82) return "\uDB81\uDD96";
        return "\uDB81\uDD97";
    }
    readonly property string wxTemp: wxOk
        ? Math.round(cfg.weatherF ? wxTempC * 9 / 5 + 32 : wxTempC) + (cfg.weatherSymbol ? "°" : "") : "–"
    readonly property string wxText: cfg.weatherCase === "upper" ? wxDesc.toUpperCase()
                                   : cfg.weatherCase === "lower" ? wxDesc.toLowerCase() : wxDesc
    function wxDeg(c) { return Math.round(cfg.weatherF ? c * 9 / 5 + 32 : c) + "°" + (cfg.weatherF ? "F" : "C"); }
    readonly property string wxTip: wxOk ? (wxReal !== "" ? wxReal : wxDesc) + " · " + wxDeg(wxTempC)
                                         : "Weather: unavailable"
    function fetchWx() {
        if (!wxProc.running) wxProc.running = true;
        if (!wxRealProc.running) wxRealProc.running = true;
    }
    function refreshWeather() {
        if (wxHave) fetchWx();
        else if (!geoProc.running) geoProc.running = true;
    }
    Process {
        id: geoProc
        command: cfg.weatherCity === ""
            ? ["curl", "-sf", "-m", "10", "http://ip-api.com/json/?fields=status,lat,lon"]
            : ["curl", "-sf", "-m", "10",
               "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(cfg.weatherCity)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const r = cfg.weatherCity === "" ? j : j.results[0];
                    root.wxLat = r.lat ?? r.latitude; root.wxLon = r.lon ?? r.longitude;
                    root.wxHave = true;
                    root.fetchWx();
                } catch (e) {}
            }
        }
    }
    Process {
        id: wxProc
        command: ["curl", "-sf", "-m", "15",
                  "https://api.open-meteo.com/v1/forecast?latitude=" + root.wxLat + "&longitude=" + root.wxLon
                  + "&current=temperature_2m,weather_code,is_day&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).current;
                    root.wxTempC = c.temperature_2m; root.wxCode = c.weather_code;
                    root.wxDay = c.is_day === 1; root.wxOk = true;
                } catch (e) {}
            }
        }
    }
    Process {
        id: wxRealProc
        command: ["curl", "-sf", "-m", "15", "https://wttr.in/" + root.wxLat + "," + root.wxLon + "?format=%25C"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t !== "" && t.length < 40 && t.indexOf("<") < 0) root.wxReal = t;
            }
        }
    }
    Timer {
        interval: 900000; repeat: true; triggeredOnStart: true
        running: root.barVisible && root.isOn("weather"); onTriggered: root.refreshWeather()
    }
    Timer { id: wxRecheck; interval: 800; onTriggered: root.refreshWeather() }
    Connections { target: cfg; function onWeatherCityChanged() { root.wxHave = false; wxRecheck.restart(); } }
    property string netState: "disconnected"; property string netName: ""; property bool wifiOn: true
    readonly property bool netOff: !wifiOn && netState === "disconnected"
    readonly property string netGlyph: netState === "wifi" ? "\uDB81\uDDA9"
                                     : netState === "ethernet" ? "\uDB80\uDE00" : "\uDB81\uDDAA"
    readonly property string netTip: {
        const w = wifiOn ? "" : " · Wi-Fi off";
        if (netState === "ethernet") return "Ethernet" + (netName !== "" ? ": " + netName : "") + w;
        if (netState === "wifi") return "Wi-Fi" + (netName !== "" ? ": " + netName : "");
        return wifiOn ? "Disconnected" : "Wi-Fi: off";
    }
    function toggleWifi() {
        wifiOn = !wifiOn;
        run("nmcli radio wifi " + (wifiOn ? "on" : "off"));
        netRecheck.restart();
    }
    function refreshNet() {
        if (!netProc.running) netProc.running = true;
        if (!netRadioProc.running) netRadioProc.running = true;
    }
    Timer { id: netRecheck; interval: 900; onTriggered: root.refreshNet() }
    Process {
        id: netProc; command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let st = "disconnected", name = "";
                for (const l of text.split("\n")) {
                    const p = l.split(":");
                    if (p.length < 2) continue;
                    const n = p.slice(2).join(":").replace(/\\:/g, ":");
                    if (p[0] === "ethernet" && p[1] === "connected") { st = "ethernet"; name = n; break; }
                    if (p[0] === "wifi" && p[1] === "connected") { st = "wifi"; name = n; }
                }
                if (st !== root.netState) root.netState = st;
                if (name !== root.netName) root.netName = name;
            }
        }
    }
    Process {
        id: netRadioProc; command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiOn = text.trim() === "enabled"
        }
    }
    Timer {
        interval: 10000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: root.refreshNet()
    }
    property int notifCount: 0; property bool notifDnd: false
    readonly property string notifTip: (notifCount > 0 ? "Notifications: " + notifCount : "No notifications")
                                       + (notifDnd ? " · Do Not Disturb" : "")
    FileView {
        path: Quickshell.env("HOME") + "/.cache/43pr/notifications.json"; printErrors: false; watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.notifCount = JSON.parse(text()).length; }
            catch (e) { root.notifCount = 0; }
        }
        onLoadFailed: root.notifCount = 0
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/state/sidepanel-state.json"; printErrors: false
        watchChanges: true; onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.notifDnd = j.dnd === true;
                root.nightOn = j.night === true;
                if (typeof j.nightTemp === "number") root.nightTemp = j.nightTemp;
            } catch (e) { root.notifDnd = false; }
        }
        onLoadFailed: root.notifDnd = false
    }
    function toggleDnd() {
        notifDnd = !notifDnd;
        run("qs ipc call notifications dnd");
    }
    property real brightness: -1; property bool nightOn: false; property int nightTemp: 4500
    readonly property bool hasBacklight: brightness >= 0
    readonly property int brightPct: Math.round(Math.max(0, brightness) * 100)
    readonly property real brightLevel: hasBacklight ? brightness : 0
    readonly property real nightLevel: nightOn ? (6500 - nightTemp) / 4000 : 0
    readonly property string brightTip: hasBacklight ? "Brightness: " + brightPct + "%"
                                                     : "Brightness: no backlight detected"
    readonly property string nightTip: "Night light: " + (nightOn ? "on" : "off") + " · " + nightTemp + " K"
    function qa(args) { Quickshell.execDetached(["qs", "ipc", "call", "qa"].concat(args)); }
    Process {
        id: brightProc; command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim().split(",")[3]);
                if (!isNaN(v)) root.brightness = v / 100;
            }
        }
    }
    function refreshBright() { if (!brightProc.running) brightProc.running = true; }
    Timer { id: brightRecheck; interval: 400; onTriggered: root.refreshBright() }
    Timer {
        interval: 5000; repeat: true; triggeredOnStart: true; running: root.barVisible && root.isOn("bright")
        onTriggered: root.refreshBright()
    }
    function brightAdjust(dir) {
        if (!hasBacklight) return;
        const step = Math.max(1, cfg.brightStep);
        const next = Math.max(1, Math.min(100, snapStep(Math.round(brightness * 100), step, dir)));
        brightness = next / 100;
        Quickshell.execDetached(["brightnessctl", "set", next + "%"]);
        brightRecheck.restart();
    }
    function toggleNight() { nightOn = !nightOn; qa(["nightToggle"]); }
    function nightAdjust(dir) {
        const delta = dir * Math.max(50, cfg.nightStep);
        nightTemp = Math.max(2500, Math.min(6500, nightTemp + delta));
        qa(["nightAdjust", String(delta)]);
    }
    property var wheelAcc: ({})
    function notch(key, delta) {
        const a = (wheelAcc[key] ?? 0) + delta;
        if (Math.abs(a) < 120) { wheelAcc[key] = a; return 0; }
        wheelAcc[key] = 0;
        return a > 0 ? 1 : -1;
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
    readonly property string wsHints: "Scroll: Previous / next workspace"
    readonly property bool wsMinimal: cfg.wsStyle === "minimal"
    readonly property bool wsNumbers: cfg.wsStyle === "numbers"
    function wsWheel(dy) {
        run("hyprctl dispatch 'hl.dsp.focus({workspace=\"e" + (dy > 0 ? "+1" : "-1") + "\"})'");
    }
    component Lane: GridLayout {
        property int gap: 0; flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight; rowSpacing: gap
        columnSpacing: gap
    }
    component DMouseArea: MouseArea {
        id: dm; property bool suppressClick: false; property bool dragging: false
        property point startScene: Qt.point(0, 0); property var owner: null
        onPressed: mouse => {
            suppressClick = false;
            dragging = false;
            owner = root.slotOf(dm);
            startScene = dm.mapToItem(null, mouse.x, mouse.y);
        }
        onPositionChanged: mouse => {
            if (!pressed || owner === null || !owner.dragAllowed) return;
            const sp = dm.mapToItem(null, mouse.x, mouse.y);
            const dx = sp.x - startScene.x, dy = sp.y - startScene.y;
            if (!dragging) {
                if (Math.abs(root.vertical ? dy : dx) < 10) return;
                dragging = true;
                suppressClick = true;
                owner.dragging = true;
            }
            owner.dragDx = root.vertical ? 0 : dx;
            owner.dragDy = root.vertical ? dy : 0;
        }
        onReleased: mouse => {
            if (!dragging) return;
            dragging = false;
            const sp = dm.mapToItem(null, mouse.x, mouse.y);
            if (owner !== null) owner.finishDrag(sp.x, sp.y);
        }
        onCanceled: {
            if (!dragging) return;
            dragging = false;
            if (owner !== null) owner.cancelDrag();
        }
    }
    component Tip: Item {
        id: tp; property Item target: parent; property bool hot: false; property string title: ""
        property string hints: ""; property bool shown: false; property bool suppressed: false
        readonly property bool usable: cfg.tooltips && !suppressed && (title !== "" || hints !== ""); width: 0
        height: 0; onHotChanged: if (!hot) { shown = false; suppressed = false; }
        function dismiss() { suppressed = true; shown = false; }
        Timer {
            interval: cfg.tipDelay; running: tp.hot && tp.usable && !tp.shown; onTriggered: tp.shown = true
        }
        LazyLoader {
            active: tp.shown && tp.usable
            PopupWindow {
                readonly property real k: cfg.tooltipScale; readonly property var win: tp.target.QsWindow.window
                readonly property point p: win.contentItem.mapFromItem(tp.target, 0, 0); anchor.window: win
                anchor.adjustment: PopupAdjustment.Slide
                anchor.rect.x: root.vertical
                    ? (cfg.position === "left" ? p.x + tp.target.width + 6 : p.x - implicitWidth - 6)
                    : p.x + (tp.target.width - implicitWidth) / 2
                anchor.rect.y: root.vertical
                    ? p.y + (tp.target.height - implicitHeight) / 2
                    : (cfg.position === "top" ? p.y + tp.target.height + 6 : p.y - implicitHeight - 6)
                implicitWidth: tcol.implicitWidth + Math.round(20 * k)
                implicitHeight: tcol.implicitHeight + Math.round(14 * k); color: "transparent"; visible: true
                Rectangle {
                    anchors.fill: parent; radius: Math.min(cfg.radius, height / 2); color: root.bgColor
                    border.width: cfg.tooltipBorder ? 1 : 0; border.color: root.borderColor
                    Column {
                        id: tcol; anchors.centerIn: parent; spacing: Math.round(3 * k)
                        Text {
                            visible: tp.title !== ""; text: tp.title; color: Theme.text; font.family: Theme.iconFont
                            font.pixelSize: Math.max(6, Math.round(12 * k)); font.bold: true
                        }
                        Text {
                            visible: tp.hints !== ""; text: tp.hints; color: Theme.textDim
                            font.family: Theme.iconFont; font.pixelSize: Math.max(6, Math.round(11 * k))
                        }
                    }
                }
            }
        }
    }
    component Interactive: Item {
        id: it; property string mid: ""; property string tip: ""; property string primaryHint: ""
        property string secondaryHint: ""; property string tertiaryHint: ""; property string scrollHint: ""
        property string disabledReason: ""; property bool active: false; property bool warning: false
        property bool disabled: false; property bool interactive: true; property bool noTip: false
        property bool noSecondary: false; property bool noHints: false
        signal primary()
        signal secondary()
        signal tertiary()
        signal scrolled(real delta)
        readonly property bool hovered: ma.containsMouse && !disabled
        readonly property string hintText: {
            if (disabled) return disabledReason;
            if (!cfg.tooltipHints || noHints) return "";
            const l = [];
            if (primaryHint !== "") l.push("Left click: " + primaryHint);
            if (!noSecondary) l.push("Right click: " + (secondaryHint !== "" ? secondaryHint : "Quick actions"));
            if (tertiaryHint !== "") l.push("Middle click: " + tertiaryHint);
            if (scrollHint !== "") l.push("Scroll: " + scrollHint);
            return l.join("\n");
        }
        function secondaryAction() {
            if (noSecondary) return;
            if (secondaryHint !== "") secondary();
            else root.openSettings();
        }
        opacity: disabled ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Rectangle {
            anchors.fill: parent; anchors.margins: 1; anchors.verticalCenterOffset: 3; radius: Theme.radius
            color: ma.pressed && it.interactive && !it.disabled ? IconTune.color(it.mid, "pressed")
                 : it.active ? IconTune.color(it.mid, "activeBg")
                 : it.warning ? IconTune.color(it.mid, "warnBg")
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        DMouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: it.interactive && !it.disabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: tipper.dismiss()
            onClicked: mouse => {
                if (it.disabled || ma.suppressClick) return;
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
            id: tipper; target: it; hot: !it.noTip && ma.containsMouse; title: it.tip; hints: it.hintText
        }
    }
    component RingGauge: Item {
        id: rg; property real level: 0; property string glyph: ""; property string glyphFont: Theme.iconFont
        property string mid: ""; property color fg: IconTune.color(mid, "normal"); property bool warning: false
        property int size: 0; property real strokeRatio: 0.09; property real minStroke: 1.5
        readonly property int diameter: size > 0 ? size
            : Math.max(10, Math.min(root.panelThick - 4, Math.round(root.sz.icon * 1.5)))
        readonly property real stroke: Math.max(minStroke, diameter * strokeRatio)
        property real shownLevel: Math.max(0, Math.min(1, level))
        Behavior on shownLevel { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
        implicitWidth: diameter; implicitHeight: diameter
        Shape {
            anchors.fill: parent; preferredRendererType: Shape.CurveRenderer; layer.enabled: true; layer.samples: 4
            ShapePath {
                strokeColor: IconTune.color(rg.mid, "ringTrack"); strokeWidth: rg.stroke; fillColor: "transparent"
                PathAngleArc {
                    centerX: rg.width / 2; centerY: rg.height / 2; radiusX: (rg.width - rg.stroke) / 2
                    radiusY: (rg.height - rg.stroke) / 2; startAngle: -90; sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: rg.shownLevel <= 0 ? "transparent"
                           : rg.warning ? IconTune.color(rg.mid, "ringWarn")
                                        : IconTune.color(rg.mid, "ringArc")
                strokeWidth: rg.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: rg.width / 2; centerY: rg.height / 2; radiusX: (rg.width - rg.stroke) / 2
                    radiusY: (rg.height - rg.stroke) / 2; startAngle: -90
                    sweepAngle: Math.min(359.9, 360 * rg.shownLevel)
                }
            }
        }
        Text {
            anchors.centerIn: parent; text: rg.glyph; color: rg.fg; font.family: rg.glyphFont
            font.pixelSize: Math.round(rg.diameter * 0.5); renderType: Text.NativeRendering
        }
    }
    component Mod: Interactive {
        id: mod; property string text: ""; property string vtext: text; property string glyph: ""
        property string vglyph: glyph; property Component iconComp: null; property bool meter: false
        property bool ringOn: false; property bool labelOn: false; property string labelText: ""
        property string numText: ""; property real ringLevel: 0; property string ringGlyph: ""
        property string plainGlyph: ""; property Component plainIcon: null
        readonly property bool asLabel: meter && labelOn && !ringOn
        property real glyphSize: meter ? root.sz.icon - 2 : 16; property real baseSize: meter ? root.sz.batText : 11
        property string tone: "normal"; property bool bold: false; property real xOffset: 0; property real yOffset: 0
        property real iconX: 0; property real iconY: 0; property real textX: 0; property real textY: 0
        property real glyphXScale: 1; property int spacing: meter ? Math.round(4 * root.bs) : root.sizeIconGap
        property int padX: 0; property string variant: ""
        readonly property var tn: IconTune.resolve(mid, root.vertical, variant)
        readonly property real iconYEff: meter && ringOn && tn.ringIconY !== null ? tn.ringIconY : tn.iconY
        readonly property real padEff: padX + tn.pad
        readonly property real basePad: root.selfPadded.indexOf(mid) >= 0 ? 0 : Math.round(8 * root.bs)
        readonly property color fg: IconTune.color(mid, warning ? "warning" : active ? "active" : tone)
        readonly property string shown: !meter ? (root.vertical ? vtext : text)
            : asLabel ? (numText !== "" ? labelText + (root.vertical ? "\n" : " ") + numText : labelText)
            : numText
        readonly property string shownGlyph: !meter ? (root.vertical ? vglyph : glyph)
            : (ringOn || asLabel ? "" : plainGlyph)
        readonly property Component shownIcon: !meter ? iconComp : ringOn ? ringC : asLabel ? null : plainIcon
        Component {
            id: ringC
            RingGauge {
                size: mod.tn.ringSize !== 0
                      ? Math.max(10, Math.min(root.panelThick - 4, Math.round(root.sz.icon * 1.5) + mod.tn.ringSize))
                      : 0
                mid: mod.mid; level: mod.ringLevel; glyph: mod.ringGlyph; fg: mod.fg; warning: mod.warning
            }
        }
        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.vertical ? root.panelThick : content.implicitWidth + padEff + basePad
        implicitHeight: root.vertical ? Math.max(20, content.implicitHeight + Math.round(padEff * 0.4))
                                      : Math.max(root.panelThick - 2, content.implicitHeight)
        GridLayout {
            id: content; anchors.centerIn: parent
            anchors.verticalCenterOffset: root.vertical ? mod.tn.y : mod.yOffset + mod.tn.y
            anchors.horizontalCenterOffset: mod.xOffset + mod.tn.x
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight; rowSpacing: 2
            columnSpacing: mod.spacing + mod.tn.spacing
            Loader {
                id: iconLoader; active: mod.shownIcon !== null; visible: active; Layout.alignment: Qt.AlignCenter
                sourceComponent: mod.shownIcon
                transform: [
                    Translate { x: mod.iconX + mod.tn.iconX; y: mod.iconY + mod.iconYEff },
                    Scale {
                        xScale: mod.tn.scaleX; yScale: mod.tn.scaleY; origin.x: iconLoader.width / 2
                        origin.y: iconLoader.height / 2
                    },
                    Rotation {
                        angle: mod.tn.rotation; origin.x: iconLoader.width / 2; origin.y: iconLoader.height / 2
                    }
                ]
            }
            Text {
                id: glyphText; visible: mod.shownGlyph !== ""; Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter; text: mod.shownGlyph; color: mod.fg
                font.family: Theme.iconFont; font.pixelSize: mod.glyphSize + mod.tn.glyphSize
                renderType: Text.NativeRendering
                transform: [
                    Translate { x: mod.iconX + mod.tn.iconX; y: mod.iconY + mod.iconYEff },
                    Scale {
                        xScale: mod.glyphXScale * mod.tn.scaleX; yScale: mod.tn.scaleY; origin.x: glyphText.width / 2
                        origin.y: glyphText.height / 2
                    },
                    Rotation {
                        angle: mod.tn.rotation; origin.x: glyphText.width / 2; origin.y: glyphText.height / 2
                    }
                ]
            }
            Text {
                visible: mod.shown !== ""; Layout.alignment: Qt.AlignCenter; horizontalAlignment: Text.AlignHCenter
                text: mod.shown; color: mod.fg; font.family: Theme.iconFont; font.bold: mod.bold
                font.pixelSize: mod.baseSize + mod.tn.textSize; renderType: Text.NativeRendering
                transform: Translate { x: mod.textX + mod.tn.textX; y: mod.textY + mod.tn.textY }
            }
        }
    }
    component StatBadge: Interactive {
        id: stat; anchors.verticalCenterOffset: 1; property string label: ""; property string icon: ""
        property string iconFont: Theme.iconFont; property int pct: 0; property bool known: true
        property bool isTemp: false; property string valueText: known ? String(pct) : "–"
        property string unit: known ? (isTemp ? "°C" : "%") : ""; property real level: known ? pct / 100 : 0
        warning: known && pct >= (isTemp ? cfg.tempWarn : cfg.statsWarn)
        readonly property bool ring: cfg.statsRing && icon !== ""
        readonly property bool useIcon: cfg.statsIcons && icon !== ""
        readonly property string shownLabel: useIcon ? icon : label
        readonly property string shownValue: valueText + (cfg.statsPercent ? unit : "")
        readonly property color fg: IconTune.color(mid, warning ? "warning" : "normal")
        readonly property int maxCross: Math.max(8, root.panelThick - (cfg.border ? 2 : 0))
        readonly property int crossPad: root.vertical ? 8 : 6
        readonly property int wantedPx: Math.max(4, Math.round(10 * cfg.statsScale * cfg.scale * cfg.barScale))
        readonly property int labelWantedPx: useIcon ? wantedPx + 2 : Math.max(4, wantedPx - 1)
        readonly property string sampleValue: "100" + (cfg.statsPercent ? "%" : "")
        readonly property real contentCross: root.vertical
            ? Math.max(mLabel.width, mValue.width)
            : Math.max(mLabel.height, mValue.height)
        readonly property int fontPx: contentCross + crossPad > maxCross
            ? Math.max(4, Math.floor(wantedPx * (maxCross - crossPad) / contentCross))
            : wantedPx
        readonly property int ringPx: Math.max(10, Math.min(maxCross - 2, Math.round(wantedPx * 2.3)))
        secondaryHint: "Open system settings"
        onSecondary: root.run("qs ipc call settings system")
        TextMetrics {
            id: mLabel; text: stat.shownLabel; font.family: stat.useIcon ? stat.iconFont : Theme.iconFont
            font.pixelSize: stat.labelWantedPx
        }
        TextMetrics {
            id: mValue; text: cfg.statsNumbers ? stat.sampleValue : ""; font.family: Theme.iconFont; font.bold: true
            font.pixelSize: stat.wantedPx
        }
        Layout.alignment: Qt.AlignCenter; implicitWidth: root.vertical ? root.panelThick : badge.width + cfg.statsGap
        implicitHeight: root.vertical ? badge.height + cfg.statsGap
                                      : Math.min(root.panelThick, Math.max(root.panelThick - 2, badge.height + 4))
        interactive: false
        Rectangle {
            id: badge; anchors.centerIn: parent
            width: root.vertical
                   ? Math.min(stat.maxCross, statRow.implicitWidth + 8)
                   : statRow.implicitWidth + 12
            height: root.vertical
                    ? statRow.implicitHeight + 8
                    : Math.min(stat.maxCross, statRow.implicitHeight + 4)
            clip: true; radius: Math.min(cfg.statsRadius, Math.min(width, height) / 2); color: "transparent"
            border.width: cfg.statsBorder ? 1 : 0; border.color: Qt.alpha(stat.fg, 0.18)
            GridLayout {
                id: statRow; anchors.centerIn: parent
                flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight; rowSpacing: stat.ring ? 2 : 0
                columnSpacing: stat.ring ? 4 : 3
                RingGauge {
                    mid: stat.mid; visible: stat.ring; Layout.alignment: Qt.AlignCenter; size: stat.ringPx
                    strokeRatio: 0.08; minStroke: 1.2; level: stat.level; glyph: stat.icon; glyphFont: stat.iconFont
                    fg: stat.fg; warning: stat.warning
                }
                Text {
                    visible: !stat.ring; Layout.alignment: Qt.AlignCenter; text: stat.shownLabel
                    color: Qt.alpha(stat.fg, 0.75); font.family: stat.useIcon ? stat.iconFont : Theme.iconFont
                    font.pixelSize: stat.useIcon ? stat.fontPx + 2 : Math.max(4, stat.fontPx - 1)
                    renderType: Text.NativeRendering
                }
                Text {
                    visible: cfg.statsNumbers; Layout.alignment: Qt.AlignCenter; text: stat.shownValue; color: stat.fg
                    font.family: Theme.iconFont; font.bold: true; font.pixelSize: stat.fontPx
                    renderType: Text.NativeRendering
                }
            }
        }
    }
    component Slot: Loader {
        id: slot
        required property string modelData
        readonly property bool isSlot: true; readonly property bool dragAllowed: cfg.dragModules
        property bool dragging: false; property real dragDx: 0; property real dragDy: 0
        signal droppedAt(real sx, real sy)
        function cancelDrag() { dragging = false; dragDx = 0; dragDy = 0; }
        function finishDrag(sx, sy) { cancelDrag(); droppedAt(sx, sy); }
        visible: root.modVisible(modelData); Layout.alignment: Qt.AlignCenter; z: dragging ? 100 : 0
        opacity: dragging ? 0.75 : 1; transform: Translate { x: slot.dragDx; y: slot.dragDy }
        sourceComponent: root.comps[modelData] ?? root.comps.icon
        onLoaded: if (item.mid !== undefined) item.mid = modelData
    }
    component Panel: Rectangle {
        id: panel; property var model: []; property bool dragActive: false; readonly property Item lane: laneItem
        signal dropped(string modId, real sx, real sy)
        readonly property bool hasVisible: model.some(id => root.modVisible(id)); visible: hasVisible
        readonly property var visIds: model.filter(id => root.modVisible(id))
        readonly property int padAlong: root.islands ? 0 : 4
        z: dragActive ? 100 : 0
        width: root.vertical ? root.panelThick : laneItem.implicitWidth + padAlong
        height: root.vertical ? laneItem.implicitHeight + padAlong : root.panelThick
        radius: root.barRadius; color: root.joined || root.islands ? "transparent" : root.bgColor
        border.width: cfg.border && !root.joined && !root.islands ? 1 : 0; border.color: root.borderColor
        Lane {
            id: laneItem; anchors.centerIn: parent; gap: root.islands ? root.effGap + root.islandGapPx : 0
            Repeater {
                model: root.groupsOf(panel.model)
                delegate: Rectangle {
                    id: isl
                    required property var modelData
                    readonly property Item lane: islLane; readonly property int pad: root.islands ? 4 + root.modPadPx : 0
                    property bool dragActive: false; visible: modelData.some(id => root.modVisible(id))
                    z: dragActive ? 100 : 0; Layout.alignment: Qt.AlignCenter
                    implicitWidth: root.vertical ? root.panelThick : islLane.implicitWidth + pad
                    implicitHeight: root.vertical ? islLane.implicitHeight + pad : root.panelThick
                    radius: root.barRadius; color: root.islands ? root.bgColor : "transparent"
                    border.width: root.islands && cfg.border ? 1 : 0; border.color: root.borderColor
                    onDragActiveChanged: panel.dragActive = dragActive
                    Lane {
                        id: islLane; anchors.centerIn: parent; gap: root.modPadPx
                        Repeater {
                            model: isl.modelData
                            delegate: Slot {
                                id: slotD; onDroppedAt: (sx, sy) => panel.dropped(slotD.modelData, sx, sy)
                                onDraggingChanged: isl.dragActive = dragging
                            }
                        }
                    }
                }
            }
        }
    }
    component MarqueeStrip: Item {
        id: strip
        readonly property int glyphGap: 9
        // widest of both glyphs, so toggling play/pause never shifts the title
        readonly property real glyphW: Math.ceil(Math.max(gPlay.width, gPause.width))
        readonly property real titleW: Math.min(Marquee.textW, Marquee.maxW)
        readonly property real totalW: glyphW + glyphGap + titleW
        TextMetrics { id: gPlay;  text: "\uDB81\uDC0A"; font.family: Theme.iconFont; font.pixelSize: root.sz.marquee }
        TextMetrics { id: gPause; text: "\uDB80\uDFE4"; font.family: Theme.iconFont; font.pixelSize: root.sz.marquee }

        // fixed icon
        Item {
            id: iconBox
            width: strip.glyphW; height: parent.height
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.vertical ? 0 : root.iconYOffset
                text: Marquee.glyph; color: Theme.text; font.family: Theme.iconFont
                font.pixelSize: root.sz.marquee
                renderType: root.vertical ? Text.QtRendering : Text.NativeRendering
            }
        }
        // scrolling title
        Item {
            x: strip.glyphW + strip.glyphGap; width: strip.titleW; height: parent.height; clip: true
            Row {
                x: Marquee.animating ? Marquee.x : 0; spacing: Marquee.gap
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: root.vertical ? 0 : root.iconYOffset
                Repeater {
                    model: Marquee.animating ? 2 : 1
                    delegate: Text {
                        required property int index
                        text: Marquee.text; color: Theme.text; font.family: Theme.iconFont
                        font.pixelSize: root.sz.marquee
                        renderType: root.vertical ? Text.QtRendering : Text.NativeRendering
                        width: index === 0 ? (Marquee.animating ? Marquee.textW : strip.titleW)
                                           : implicitWidth
                        elide: index === 0 && !Marquee.animating ? Text.ElideRight : Text.ElideNone
                    }
                }
            }
        }
    }
    Component {
        id: iconC
        Mod {
            id: ic; property var def: root.defMap[mid] ?? ({}); readonly property bool isNotif: mid === "notif"
            readonly property bool isSettings: mid === "settings"
            readonly property bool isPower: mid === "power"                                   // NEW
            baseSize: mid === "power" ? root.sz.power - 3 : root.sz.icon - 2
            text: isNotif && root.notifDnd ? "\uec08" : (def.g ?? ""); tip: isNotif ? root.notifTip : (def.tip ?? "")
            primaryHint: isSettings ? root.actionHint(cfg.settingsPrimary) : (def.hint ?? "")
            secondaryHint: isSettings ? root.actionHint(cfg.settingsSecondary)
                         : isNotif ? (root.notifDnd ? "Turn off Do Not Disturb" : "Turn on Do Not Disturb")
                         : isPower ? "Appearance settings"                                    // NEW
                         : ""
            tertiaryHint: isSettings ? root.actionHint(cfg.settingsTertiary) : ""
            noSecondary: isSettings && cfg.settingsSecondary === "none"
            onPrimary: {
                if (isSettings)
                root.doAction(cfg.settingsPrimary);
                else if (isNotif)
                root.openSidepanelAt(null);   // same placement as the clock (centred)
                else if (def.cmd)
                root.run(def.cmd);
            }
            onSecondary: {
                if (isSettings) root.doAction(cfg.settingsSecondary);
                else if (isNotif) root.toggleDnd();
                else if (isPower) root.run("qs ipc call settings appearance");                // NEW
             }
            onTertiary: if (isSettings) root.doAction(cfg.settingsTertiary)
            Rectangle {
                visible: ic.isNotif && root.notifCount > 0; anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenterOffset: Math.round(root.sz.icon / 2)
                anchors.verticalCenterOffset: -Math.round(root.sz.icon / 2) + 1
                width: Math.max(height, badgeText.implicitWidth + 6)
                height: Math.max(11, badgeText.implicitHeight + 1); radius: height / 2
                color: Qt.alpha(Theme.bg, cfg.bgOpacity)
                Text {
                    id: badgeText; anchors.centerIn: parent; text: root.notifCount > 9 ? "9+" : root.notifCount
                    color: Theme.text; font.family: Theme.iconFont; font.pixelSize: Math.max(8, root.s(8))
                    font.bold: true; renderType: Text.NativeRendering
                }
            }
        }
    }
    Component {
        id: clockC
        Mod {
            id: clockMod
            padX: root.joined ? 0 : Math.round((root.vertical ? 28 : 16) * root.bs)
            function act(a) {
                if (a === "calendar") root.openSidepanelAt(clockMod);
                else root.doAction(a);
            }
            bold: true; baseSize: root.sz.clock; text: root.clockBarText(clk.date)
            vtext: root.clockBarVText(clk.date); tip: Qt.formatDate(clk.date, "dddd, d MMMM yyyy")
            primaryHint: root.actionHint(cfg.clockPrimary); secondaryHint: root.actionHint(cfg.clockSecondary)
            tertiaryHint: root.actionHint(cfg.clockTertiary); noSecondary: secondaryHint === ""
            onPrimary: act(cfg.clockPrimary); onSecondary: act(cfg.clockSecondary); onTertiary: act(cfg.clockTertiary)
        }
    }
    SystemClock {
        id: clk; enabled: root.isOn("clock"); precision: cfg.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
    Component {
        id: weatherC
        Mod {
            glyph: cfg.weatherIcon ? root.wxGlyph(root.wxCode) : ""
            vglyph: root.wxGlyph(root.wxCode)
            text: cfg.weatherIcon || !root.wxOk ? root.wxTemp : root.wxText + "  " + root.wxTemp
            vtext: root.wxTemp
            glyphSize: root.sz.icon - 2; baseSize: root.sz.clock; bold: true
            tip: root.wxTip; primaryHint: "Refresh"; secondaryHint: "Bar settings"
            onPrimary: root.refreshWeather(); onSecondary: root.openSettings()
        }
    }
    Component {
        id: netC
        Mod {
            glyphSize: root.sz.icon - 2; glyph: root.netGlyph; tone: root.netOff ? "off" : "ok"
            warning: root.netState === "disconnected" && root.wifiOn; tip: root.netTip
            primaryHint: "Open network settings"; secondaryHint: root.wifiOn ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
            onPrimary: root.run("qs ipc call settings network"); onSecondary: root.toggleWifi()
        }
    }
    Component {
        id: btC
        Mod {
            glyphSize: root.sz.icon - 2; glyph: root.btGlyph
            tone: !root.btOn ? "off" : root.btConnectedNames.length > 0 ? "connected" : "idle"; disabled: !root.hasBt
            disabledReason: "No Bluetooth adapter"; tip: root.btTip; primaryHint: "Open Bluetooth settings"
            secondaryHint: root.btOn ? "Turn Bluetooth off" : "Turn Bluetooth on"
            onPrimary: root.run("qs ipc call settings bluetooth"); onSecondary: BluetoothState.togglePower()
        }
    }
    Component {
        id: cpuC
        StatBadge {
            label: "CPU"; icon: "\uEF8E"; iconFont: Theme.tablerFont; pct: root.cpuUsage
            tip: "CPU usage: " + root.cpuUsage + "%"
        }
    }
    Component {
        id: ramC
        StatBadge {
            label: "RAM"; icon: "\uD800\uDEB7"; iconFont: Theme.tablerFont; pct: root.memPercent
            tip: "Memory: " + root.memUsedG.toFixed(1) + " / " + root.memTotalG.toFixed(1)
                 + " GiB (" + root.memPercent + "%)"
        }
    }
    Component {
        id: gpuC
        StatBadge {
            label: "GPU"; icon: "\uD800\uDE99"; iconFont: Theme.tablerFont; known: root.gpuHasUsage
            pct: root.gpuUsage; tip: root.gpuHasUsage ? "GPU usage: " + root.gpuUsage + "%" : "GPU usage: unavailable"
        }
    }
    Component {
        id: cpuTempC
        StatBadge {
            label: "CPUT"; icon: "\uEB38"; iconFont: Theme.tablerFont
            isTemp: true; known: root.cpuTemp >= 0; pct: root.cpuTemp; tip: root.tempTip("CPU", root.cpuTemp)
        }
    }
    Component {
        id: gpuTempC
        StatBadge {
            label: "GPUT"; icon: "\uEB38"; iconFont: Theme.tablerFont
            isTemp: true; known: root.gpuTemp >= 0; pct: root.gpuTemp; tip: root.tempTip("GPU", root.gpuTemp)
        }
    }
    Component {
        id: wsDotsC
        Item {
            implicitWidth: root.vertical ? root.panelThick : wsLane.implicitWidth + 12
            implicitHeight: wsLane.implicitHeight + (root.vertical ? 12 : 0)
            Lane {
                id: wsLane; anchors.centerIn: parent; gap: root.wsGapPx
                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        id: dot
                        required property var modelData
                        readonly property bool wide: modelData.focused && !root.wsNumbers
                        visible: modelData.id > 0
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: !root.vertical && wide ? Math.round(root.wsBoxPx * 3.2) : root.wsBoxPx
                        implicitHeight: root.vertical && wide ? Math.round(root.wsBoxPx * 2.4) : root.wsBoxPx
                        radius: root.wsBoxPx / 2
                        color: modelData.urgent ? Theme.danger
                             : modelData.focused ? Qt.alpha(Theme.accent2, 0.5)
                             : dotMa.containsMouse ? Theme.accent2
                             : Qt.alpha(Theme.text, 0.2)
                        Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                        Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                        Loader {
                            anchors.centerIn: parent
                            active: root.wsNumbers
                            sourceComponent: Text {
                                text: dot.modelData.id; color: Theme.text; font.family: Theme.iconFont
                                font.pixelSize: Math.round(root.wsBoxPx * 0.62); font.bold: dot.modelData.focused
                                renderType: Text.NativeRendering
                            }
                        }
                        DMouseArea {
                            id: dotMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton; onPressed: dotTip.dismiss()
                            onClicked: mouse => {
                                if (dotMa.suppressClick) return;
                                if (mouse.button === Qt.RightButton) root.openSettings();
                                else Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.modelData.id + " })");
                            }
                        }
                        Tip {
                            id: dotTip; hot: dotMa.containsMouse
                            title: "Workspace " + dot.modelData.id
                                   + (dot.modelData.urgent ? " · urgent" : dot.modelData.focused ? " · focused" : "")
                            hints: cfg.tooltipHints ? root.wsHints : ""
                        }
                    }
                }
            }
            WheelHandler {
                enabled: cfg.wsScroll; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => root.wsWheel(e.angleDelta.y)
            }
        }
    }
Component {
    id: wsC
    Loader { sourceComponent: root.wsMinimal ? wsMinC : wsDotsC }
}
Component {
    id: wsMinC
    Item {
        id: wm
        readonly property int dotPx: Math.max(2, Math.round(3 * root.bs))
        readonly property int hit: dotPx + 2
        readonly property int circle: root.vertical
            ? Math.max(8, Math.min(Math.round(root.wsBoxPx * 1.5), root.panelThick - hit - 2))
            : Math.max(8, Math.min(Math.round(root.wsBoxPx * 1.5), root.panelThick - 4))
        readonly property var focusedWs: Hyprland.focusedWorkspace
        readonly property int focusedId: focusedWs ? focusedWs.id : 0
        readonly property int perRow: Math.max(1, Math.floor((root.panelThick - 6) / hit))
        readonly property int perCol: Math.max(1, Math.floor((root.panelThick - 4) / hit))
        readonly property int wsCount: Math.max(1, Hyprland.workspaces.values.length)
        implicitWidth: root.vertical ? root.panelThick : lay.implicitWidth + 12
        implicitHeight: root.vertical ? lay.implicitHeight + 4 : root.panelThick

        GridLayout {
            id: lay; anchors.centerIn: parent
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: root.vertical ? 0 : 2; columnSpacing: 3

            Rectangle {
                Layout.alignment: Qt.AlignCenter
                implicitWidth: wm.circle
                implicitHeight: root.vertical ? Math.ceil(wsNum.implicitHeight) : wm.circle
                radius: width / 2
                color: "transparent"; border.width: 0
                Text {
                    id: wsNum
                    readonly property var ct: IconTune.resolve("clock", root.vertical)
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: root.vertical ? 0 : ct.y + ct.textY
                    text: wm.focusedId > 0 ? wm.focusedId : ""
                    color: wmMa.containsMouse ? Theme.accent2 : Theme.text
                    font.family: Theme.iconFont; font.bold: true
                    font.pixelSize: root.sz.clock + ct.textSize
                    renderType: Text.NativeRendering
                }
            }
            Grid {
                Layout.alignment: Qt.AlignCenter
                flow: root.vertical ? Grid.LeftToRight : Grid.TopToBottom
                rows: 2
                columns: root.vertical
                    ? Math.max(1, Math.min(wm.perRow, Math.ceil(wm.wsCount / 2)))
                    : Math.max(1, Math.ceil(wm.wsCount / 2))
                spacing: 0
                Repeater {
                    model: Hyprland.workspaces
                    delegate: Item {
                        id: wd
                        required property var modelData
                        visible: modelData.id > 0
                        width: wm.hit; height: wm.hit
                        // purely visual: no mouse input
                        Rectangle {
                            anchors.centerIn: parent; width: wm.dotPx; height: wm.dotPx; radius: width / 2
                            color: wd.modelData.urgent ? Theme.danger
                                 : wd.modelData.focused ? Theme.accent2
                                 : Qt.alpha(Theme.text, 0.3)
                        }
                    }
                }
            }
        }
        // single mouse area over the whole module: drag from anywhere, right-click = settings
        DMouseArea {
            id: wmMa; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onPressed: wmTip.dismiss()
            onClicked: mouse => {
                if (wmMa.suppressClick) return;
                if (mouse.button === Qt.RightButton) root.openSettings();
            }
        }
        Tip {
            id: wmTip; hot: wmMa.containsMouse
            title: "Workspace " + wm.focusedId
            hints: cfg.tooltipHints ? root.wsHints : ""
        }
        WheelHandler {
            enabled: cfg.wsScroll; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => root.wsWheel(e.angleDelta.y)
        }
    }
}
    Component {
        id: tasksC
        Lane {
            gap: root.taskGapPx
            Repeater {
                model: ToplevelManager.toplevels
                delegate: Interactive {
                    id: task
                    required property var modelData
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth: root.vertical ? root.panelThick : root.taskIconPx + 10
                    implicitHeight: root.vertical ? root.taskIconPx + 10
                                                  : Math.max(root.panelThick - 2, root.taskIconPx + 6)
                    mid: "tasks"; active: modelData.activated; tip: root.appName(modelData.appId); noHints: true
                    primaryHint: "Focus window"; tertiaryHint: "Close window"; onPrimary: modelData.activate()
                    onTertiary: modelData.close()
                    Image {
                        id: appIcon; anchors.centerIn: parent; width: root.taskIconPx; height: root.taskIconPx
                        sourceSize: Qt.size(width, height); asynchronous: true; smooth: true; visible: false
                        source: root.iconFor(task.modelData.appId)
                    }
                    MultiEffect {
                        anchors.fill: appIcon; source: appIcon; colorization: cfg.tasksColor === "accent" ? 1.0 : 0.0
                        colorizationColor: IconTune.color("tasks", task.modelData.activated ? "taskActive" : "normal")
                        opacity: task.modelData.activated ? 1 : 0.5
                        scale: IconTune.resolve("tasks", root.vertical).taskScale
                    }
                }
            }
        }
    }
Component {
    id: trayIconC
    Interactive {
        id: ti
        required property var modelData
        readonly property bool flyout: cfg.trayArrow
        readonly property bool attention: modelData.status === Status.NeedsAttention
        function hostItem() { return root.trayHostOf(ti); }
        function openMenu() { if (modelData.hasMenu) menuAnchor.open(); }

        visible: flyout || modelData.status !== Status.Passive
        Layout.alignment: Qt.AlignCenter
        implicitWidth: flyout ? root.trayIconPx + 14 : (root.vertical ? root.panelThick : root.trayIconPx + 10)
        implicitHeight: flyout ? root.trayIconPx + 10
                      : root.vertical ? root.trayIconPx + 8
                                      : Math.max(root.panelThick - 4, root.trayIconPx + 4)
        mid: "tray"; warning: attention; noTip: flyout
        tip: modelData.tooltipTitle !== "" ? modelData.tooltipTitle
           : modelData.title !== "" ? modelData.title : modelData.id
        primaryHint: "Activate"; secondaryHint: "Open menu"
        tertiaryHint: "Secondary action"; scrollHint: "Scroll action"
        noSecondary: !modelData.hasMenu

        onPrimary: {
            if (modelData.onlyMenu && modelData.hasMenu) openMenu();
            else {
                modelData.activate();
                const h = hostItem();
                if (h) h.dismiss();
            }
        }
        onSecondary: openMenu()
        onTertiary: modelData.secondaryActivate()
        onScrolled: delta => {
            const d = root.notch("tray:" + modelData.id, delta);
            if (d !== 0) modelData.scroll(d * 120, false);
        }

        QsMenuAnchor {
            id: menuAnchor
            menu: ti.modelData.menu
            anchor.item: ti
            anchor.edges: root.trayEdge
            anchor.gravity: root.trayEdge
            anchor.adjustment: PopupAdjustment.Slide
            onOpened: { const h = ti.hostItem(); if (h) h.menuOpen = true; }
            onClosed: { const h = ti.hostItem(); if (h) h.menuOpen = false; }
        }
        Image {
            anchors.centerIn: parent
            width: root.trayIconPx; height: root.trayIconPx
            sourceSize: Qt.size(width, height)
            asynchronous: true; smooth: true; fillMode: Image.PreserveAspectFit
            source: ti.modelData.icon
        }
    }
}

Component {
    id: trayArrowC
    Mod {
        id: arrow
        property bool open: false
        mid: "tray"; glyphSize: root.sz.icon - 2; glyph: root.trayChevron(open)
        tip: "System tray"; primaryHint: open ? "Hide tray" : "Show tray"
        noSecondary: true; noTip: open
        onPrimary: open = !open

        LazyLoader {
            active: arrow.open && SystemTray.items.values.length > 0
            PopupWindow {
                id: pop
                readonly property var win: arrow.QsWindow.window
                readonly property point p: win.contentItem.mapFromItem(arrow, 0, 0)
                readonly property int gap: 8 + root.effEdge
                readonly property int count: Math.max(1, SystemTray.items.values.length)
                anchor.window: win
                anchor.adjustment: PopupAdjustment.Slide
                anchor.rect.x: root.vertical
                ? (cfg.position === "left" ? p.x + arrow.width + gap : p.x - implicitWidth - gap)
                : p.x + (arrow.width - implicitWidth) / 2
                anchor.rect.y: root.vertical
                ? p.y + (arrow.height - implicitHeight) / 2
                : (cfg.position === "top" ? p.y + arrow.height + gap : p.y - implicitHeight - gap)
                implicitWidth: card.implicitWidth; implicitHeight: card.implicitHeight
                color: "transparent"; visible: true
                HyprlandFocusGrab {
                    windows: [pop, arrow.QsWindow.window]
                    active: !card.menuOpen
                    onCleared: arrow.open = false
                    }
                    Rectangle {
                        id: card
                        readonly property bool isTrayHost: true
                        property bool menuOpen: false
                        function dismiss() { arrow.open = false; }
                        anchors.fill: parent
                        implicitWidth: root.vertical ? arrow.width : grid.implicitWidth + 12
                        implicitHeight: root.vertical ? grid.implicitHeight + 12 : arrow.height
                        radius: Math.min(cfg.radius, Math.min(width, height) / 2); color: root.bgColor
                        border.width: cfg.border ? 1 : 0; border.color: root.borderColor
                        GridLayout {
                            id: grid; anchors.centerIn: parent
                            columns: root.vertical ? 1 : pop.count
                            rowSpacing: 2; columnSpacing: 2
                            Repeater { model: SystemTray.items; delegate: trayIconC }
                        }
                    }
                }
            }
        }
    }


Component {
    id: trayC
    Lane {
        gap: root.taskGapPx
        Loader {
            active: cfg.trayArrow; visible: active
            Layout.alignment: Qt.AlignCenter
            sourceComponent: trayArrowC
        }
        Repeater {
            model: cfg.trayArrow ? null : SystemTray.items
            delegate: trayIconC
        }
    }
}
    Component {
        id: mediaC
        Interactive {
            readonly property bool playing: Marquee.player !== null && Marquee.player.isPlaying === true
            readonly property real len: strip.totalW
            implicitWidth: root.vertical ? root.panelThick : len + 20; implicitHeight: root.vertical ? len + 20 : 18
            tip: Marquee.text; primaryHint: playing ? "Pause" : "Play"; secondaryHint: "Next track"
            tertiaryHint: "Previous track"; onPrimary: root.mediaAct("toggle"); onSecondary: root.mediaAct("next")
            onTertiary: root.mediaAct("prev")
            MarqueeStrip {
                id: strip
                anchors.centerIn: parent; width: totalW; height: 18
                rotation: root.vertical ? (cfg.position === "left" ? -90 : 90) : 0
            }
        }
    }
    Component {
        id: volumeC
        Mod {
            id: vol; meter: true; readonly property var sink: Pipewire.defaultAudioSink
            readonly property bool ready: !!(sink && sink.audio)
            readonly property real level: ready ? sink.audio.volume : 0
            readonly property bool muted: ready ? sink.audio.muted : false
            readonly property string speaker: muted || level <= 0 ? "\uDB81\uDD81" : "\uDB81\uDD7E"
            ringOn: cfg.volRing; labelOn: cfg.volLabel; labelText: "VOL"
            numText: cfg.volNumber && ready
                ? String(muted ? 0 : Math.round(level * 100)) + (cfg.volPercent ? "%" : "") : ""
            ringLevel: muted ? 0 : level; ringGlyph: speaker; plainGlyph: speaker; warning: muted; disabled: !ready
            disabledReason: "No audio output available"
            tip: !ready ? "Volume" : muted ? "Volume: muted" : "Volume: " + Math.round(level * 100) + "%"
            primaryHint: "Open sound settings"; secondaryHint: "Mute / unmute"; scrollHint: "Adjust volume"
            onPrimary: root.run("qs ipc call settings sound")
            onSecondary: root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
            onScrolled: delta => {
                if (!ready) return;
                const dir = root.notch("vol", delta);
                if (dir === 0) return;
                const next = root.snapStep(Math.round(sink.audio.volume * 100), Math.max(1, cfg.volStep), dir);
                sink.audio.volume = Math.max(0, Math.min(cfg.volMax, next)) / 100;
            }
        }
    }
    Component {
        id: batteryC
        Mod {
            id: bat; meter: true; ringOn: cfg.batRing; labelOn: cfg.batLabel; labelText: "BAT"
            numText: cfg.batNumber ? String(root.batPct) + (cfg.batPercent ? "%" : "") : ""
            ringLevel: root.batPct / 100; ringGlyph: "\uDB80\uDC79"; plainGlyph: root.vertical ? "" : root.batGlyphV
            plainIcon: root.vertical ? batHoriz : null; warning: root.batLow; tip: root.batTip
            Component {
                id: batHoriz
                Item {
                    id: ico
                    transform: Scale {
                        xScale: 0.9; yScale: 1.0; origin.x: ico.width / 2; origin.y: ico.height / 2
                    }
                    readonly property int bodyW: Math.round(bat.glyphSize * 1.25)
                    readonly property int bodyH: Math.round(bat.glyphSize * 0.68); readonly property int nubW: 2
                    TextMetrics {
                        id: refGlyph; text: "\uDB81\uDD7E"; font.family: Theme.iconFont; font.pixelSize: bat.glyphSize
                    }
                    implicitWidth: bodyW + nubW; implicitHeight: Math.max(refGlyph.height, bodyH)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter; width: ico.bodyW; height: ico.bodyH; radius: 2
                        color: "transparent"; border.width: 1; border.color: Qt.alpha(bat.fg, 0.9)
                        Rectangle {
                            x: 2; y: 2; height: parent.height - 4
                            width: root.batPct > 0
                                   ? Math.max(1, Math.round((parent.width - 4) * Math.min(100, root.batPct) / 100))
                                   : 0
                            radius: 1; color: bat.fg
                        }
                    }
                    Rectangle {
                        x: ico.bodyW; anchors.verticalCenter: parent.verticalCenter; width: ico.nubW
                        height: Math.round(ico.bodyH * 0.4); radius: 1; color: Qt.alpha(bat.fg, 0.9)
                    }
                }
            }
        }
    }
    Component {
        id: brightC
        Mod {
            id: br; meter: true; readonly property string look: cfg.lightIcons === "star" ? "star" : "normal"
            ringOn: cfg.brightRing; ringLevel: root.brightLevel; ringGlyph: look === "star" ? "\u2726" : "\uf185"
            plainGlyph: ringGlyph; variant: look; disabled: !root.hasBacklight
            disabledReason: "No backlight detected"; tip: root.brightTip; primaryHint: "Quick actions"
            secondaryHint: "Bar settings"; scrollHint: "Adjust brightness"; onPrimary: root.qa(["toggle"])
            onSecondary: root.openSettings()
            onScrolled: delta => { const d = root.notch("bright", delta); if (d !== 0) root.brightAdjust(d); }
        }
    }
    Component {
        id: nightC
        Mod {
            id: ng; meter: true; readonly property string look: cfg.lightIcons === "star" ? "star" : "normal"
            ringOn: cfg.nightRing; ringLevel: root.nightLevel; ringGlyph: look === "star" ? "\u2727" : "\uf186"
            plainGlyph: ringGlyph; variant: look; active: root.nightOn; tip: root.nightTip
            primaryHint: root.nightOn ? "Turn night light off" : "Turn night light on"; secondaryHint: "Quick actions"
            scrollHint: "Adjust temperature"; onPrimary: root.toggleNight(); onSecondary: root.qa(["toggle"])
            onScrolled: delta => { const d = root.notch("night", delta); if (d !== 0) root.nightAdjust(d); }
        }
    }
    Variants {
        model: root.barLive
            ? (cfg.allScreens ? Quickshell.screens : Quickshell.screens.slice(0, 1))
            : []
        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            anchors {
                top: cfg.position !== "bottom"; bottom: cfg.position !== "top"; left: cfg.position !== "right"
                right: cfg.position !== "left"
            }
            implicitWidth: root.vertical ? root.panelThick + root.effEdge : 0
            implicitHeight: root.vertical ? 0 : root.panelThick + root.effEdge
            exclusionMode: cfg.reserveSpace ? ExclusionMode.Auto : ExclusionMode.Ignore; color: "transparent"
            visible: root.barVisible
            function dropModule(modId, sx, sy) {
                const pt = frame.mapFromItem(null, sx, sy);
                const pos = root.vertical ? pt.y : pt.x;
                const panels = {
                    start: startPanel, midLeft: midLeftPanel, center: clockPanel,
                    midRight: midRightPanel, end: endPanel
                };
                let sec = null;
                for (const k of root.sections) {
                    const p = panels[k];
                    if (!p.visible) continue;
                    const a = root.vertical ? p.y : p.x;
                    const b = a + (root.vertical ? p.height : p.width);
                    if (pos >= a && pos <= b) { sec = k; break; }
                }
                if (sec === null) {
                    const targets = {
                        start: startPanel.visible ? (frame.startBeg + frame.startEnd) / 2 : 0,
                        midLeft: frame.midLeftC,
                        center: frame.axisLen / 2,
                        midRight: frame.midRightC,
                        end: endPanel.visible ? (frame.endBeg + frame.endFin) / 2 : frame.axisLen
                    };
                    let best = Infinity;
                    for (const k of root.sections) {
                        const d = Math.abs(pos - targets[k]);
                        if (d < best) { best = d; sec = k; }
                    }
                }
                const panel = panels[sec];
                const list = root.listOf(sec);
                const slots = {};
                for (const isl of panel.lane.children) {
                    if (!isl.lane) continue;
                    for (const ch of isl.lane.children)
                        if (ch.isSlot === true) slots[ch.modelData] = ch;
                }
                let idx = 0;
                for (let i = 0; i < list.length; i++) {
                    const sl = slots[list[i]];
                    if (list[i] === modId || !sl || !sl.visible) continue;
                    const c = sl.mapToItem(frame, sl.width / 2, sl.height / 2);
                    if ((root.vertical ? c.y : c.x) < pos) idx = i + 1;
                }
                root.moveToIndex(modId, sec, idx);
                root.save();
            }
            Item {
                id: frame
                anchors {
                    fill: parent; topMargin: root.edgeMargin("top"); bottomMargin: root.edgeMargin("bottom")
                    leftMargin: root.edgeMargin("left"); rightMargin: root.edgeMargin("right")
                }
                readonly property real axisLen: root.vertical ? height : width
                readonly property real startBeg: root.vertical ? startPanel.y : startPanel.x
                readonly property real startEnd: startPanel.visible
                    ? (root.vertical ? startPanel.y + startPanel.height : startPanel.x + startPanel.width) : 0
                readonly property real centerBeg: clockPanel.visible
                    ? (root.vertical ? clockPanel.y : clockPanel.x) : axisLen / 2
                readonly property real centerFin: clockPanel.visible
                    ? (root.vertical ? clockPanel.y + clockPanel.height : clockPanel.x + clockPanel.width) : axisLen / 2
                readonly property real endBeg: endPanel.visible
                    ? (root.vertical ? endPanel.y : endPanel.x) : axisLen
                readonly property real endFin: root.vertical ? endPanel.y + endPanel.height : endPanel.x + endPanel.width
                readonly property real midLeftC: (startEnd + centerBeg) / 2
                readonly property real midRightC: (centerFin + endBeg) / 2
                Rectangle {
                    visible: root.joined; anchors.fill: parent; radius: root.barRadius; color: root.bgColor
                    border.width: cfg.border ? 1 : 0; border.color: root.borderColor
                }
                Panel {
                    id: startPanel; model: root.startList
                    x: root.vertical ? 0 : root.barInset
                    y: root.vertical ? root.barInset : 0
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }
                Panel {
                    id: midLeftPanel; model: root.midLeftList
                    x: root.vertical ? 0
                                     : Math.max(0, Math.min(frame.axisLen - width, frame.midLeftC - width / 2))
                    y: root.vertical ? Math.max(0, Math.min(frame.axisLen - height, frame.midLeftC - height / 2))
                                     : 0
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }
                Panel {
                    id: clockPanel; model: root.centerList
                    anchors.horizontalCenter: root.vertical ? undefined : frame.horizontalCenter
                    anchors.verticalCenter: root.vertical ? frame.verticalCenter : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }
                Panel {
                    id: midRightPanel; model: root.midRightList
                    x: root.vertical ? 0
                    : Math.max(root.barInset,
                    Math.min(frame.axisLen - width - root.barInset,
                    frame.midRightC - width / 2))
                    y: root.vertical
                    ? Math.max(root.barInset,
                    Math.min(frame.axisLen - height - root.barInset,
                    frame.midRightC - height / 2))
                    : 0
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }
                Panel {
                    id: endPanel; model: root.endList; anchors.right: root.vertical ? undefined : frame.right
                    anchors.bottom: root.vertical ? frame.bottom : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined
                    anchors.rightMargin: root.vertical ? 0 : root.barInset
                    anchors.bottomMargin: root.vertical ? root.barInset : 0
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }
            }
        }
    }
}