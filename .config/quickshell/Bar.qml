import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
        reserveSpace: true, allScreens: true, dragModules: true,
        // appearance
        scale: 1.0, barScale: 0.9, bgOpacity: 0.35, border: false, radius: 16, calRadius: 15, calScale: 0.9,
        // tooltips
        tooltips: true, tooltipHints: false, tooltipBorder: false, tipDelay: 450,
        // modules
        modPad: 18, wsDot: 16, wsGap: 8, wsScroll: true, wsNumbers: true,
        tasksScale: 0.85, tasksGap: 2, tasksColor: "normal",
        statsPercent: false, statsScale: 1.1, statsBorder: false, statsRadius: 24, statsGap: 1, statsWarn: 85, tempWarn: 85, batLowPct: 15,
        volStep: 2, volMax: 100,
        // clock / calendar
        clock24: true, clockSeconds: false, clockPadHour: true, clockDate: true, clockDay: false, clockCase: "normal", weekMonday: true,
        // clock click binds: "calendar" | "quickactions" | "settings" | "barsettings" | "none"
        clockPrimary: "calendar", clockSecondary: "settings", clockTertiary: "quickactions",
        // settings button click binds: "quickactions" | "settings" | "barsettings" | "none"
        settingsPrimary: "settings", settingsSecondary: "barsettings", settingsTertiary: "none",
        // module placement
        hidden: "wall,settings,ram",
        startMods: "notif,cpu,ram,gpu,temp",
        midLeftMods: "ws",
        centerMods: "clock",
        midRightMods: "tasks",
        endMods: "media,battery,wall,settings,volume,net,power"
    })
    readonly property var positions: ["top", "right", "bottom", "left"]
    readonly property var styles: ["floating", "joined", "strip"]
    // Five zones along the bar: start · midLeft · center · midRight · end
    //   midLeft  is centered between the start zone and the center zone
    //   midRight is centered between the center zone and the end zone
    readonly property var sections: ["start", "midLeft", "center", "midRight", "end"]

    // Live config object, edited by BarPage (the settings page).
    readonly property var config: cfg

    Component.onCompleted: BluetoothState.init()

    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        watchChanges: true                 // BarPage writes this file; pick its changes up live
        onFileChanged: reload()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        adapter: JsonAdapter {
            id: cfg
            property string position: root.defaults.position
            property string style: root.defaults.style
            property int thickness: root.defaults.thickness
            property int margin: root.defaults.margin
            property bool reserveSpace: root.defaults.reserveSpace   // push windows away from the bar
            property bool allScreens: root.defaults.allScreens       // false → first screen only
            property bool dragModules: root.defaults.dragModules     // drag modules on the bar to reorder / move them
            property real scale: root.defaults.scale                 // text scale
            property real barScale: root.defaults.barScale           // whole-bar scale (thickness, margins, padding, dots, text)
            property real bgOpacity: root.defaults.bgOpacity
            property bool border: root.defaults.border
            property int radius: root.defaults.radius            // bar corner radius
            property int calRadius: root.defaults.calRadius      // calendar popup corner radius
            property real calScale: root.defaults.calScale       // calendar popup scale
            property bool tooltips: root.defaults.tooltips
            property bool tooltipHints: root.defaults.tooltipHints // show "Left click: ..." lines in tooltips
            property bool tooltipBorder: root.defaults.tooltipBorder // outline around tooltips
            property int tipDelay: root.defaults.tipDelay        // ms before a tooltip appears
            property int modPad: root.defaults.modPad            // horizontal padding of text modules
            property int wsDot: root.defaults.wsDot              // workspace dot size
            property int wsGap: root.defaults.wsGap              // gap between workspace dots
            property bool wsScroll: root.defaults.wsScroll       // scroll on workspaces to switch
            property bool wsNumbers: root.defaults.wsNumbers     // show the workspace number inside each dot
            property real tasksScale: root.defaults.tasksScale   // open-apps icon scale
            property int tasksGap: root.defaults.tasksGap        // space between open-apps icons
            property string tasksColor: root.defaults.tasksColor // open-apps icon tint: "normal" | "accent"
            property bool statsPercent: root.defaults.statsPercent // show the % / °C symbols on CPU / RAM / GPU / TEMP
            property real statsScale: root.defaults.statsScale   // text scale of the CPU / RAM / GPU / TEMP badges
            property bool statsBorder: root.defaults.statsBorder // outline around the stat badges
            property int statsRadius: root.defaults.statsRadius  // badge corner radius (24 = full pill)
            property int statsGap: root.defaults.statsGap        // space between neighbouring stat badges
            property int statsWarn: root.defaults.statsWarn      // CPU/RAM/GPU % that turns red
            property int tempWarn: root.defaults.tempWarn        // CPU/GPU °C that turns red
            property int batLowPct: root.defaults.batLowPct      // battery % that turns red
            property int volStep: root.defaults.volStep          // % per scroll notch
            property int volMax: root.defaults.volMax            // max volume %
            property bool clock24: root.defaults.clock24
            property bool clockSeconds: root.defaults.clockSeconds
            property bool clockPadHour: root.defaults.clockPadHour // leading zero on the hour: 02:20 vs 2:20
            property bool clockDate: root.defaults.clockDate     // minimal date next to the clock, e.g. "Thu, 29/10"
            property bool clockDay: root.defaults.clockDay       // weekday (Mon/Tue) in front of the date
            property string clockCase: root.defaults.clockCase   // day name + AM/PM letters: "normal" | "upper" | "lower"
            property bool weekMonday: root.defaults.weekMonday   // calendar week starts on Monday
            property string clockPrimary: root.defaults.clockPrimary     // clock left click
            property string clockSecondary: root.defaults.clockSecondary // clock right click
            property string clockTertiary: root.defaults.clockTertiary   // clock middle click
            property string settingsPrimary: root.defaults.settingsPrimary     // settings button left click
            property string settingsSecondary: root.defaults.settingsSecondary // settings button right click
            property string settingsTertiary: root.defaults.settingsTertiary   // settings button middle click
            property string hidden: root.defaults.hidden         // comma list of disabled modules
            property string startMods: root.defaults.startMods
            property string midLeftMods: root.defaults.midLeftMods
            property string centerMods: root.defaults.centerMods
            property string midRightMods: root.defaults.midRightMods
            property string endMods: root.defaults.endMods
        }
    }

    // Only the bar's own changes (IPC / drag & drop) are saved from here; BarPage saves its own.
    Timer { id: saveTimer; interval: 300; onTriggered: cfgFile.writeAdapter() }
    function save() { saveTimer.restart(); }

    function resetSettings() { for (const k in defaults) cfg[k] = defaults[k]; }
    readonly property bool modified: Object.keys(defaults).some(k => cfg[k] !== defaults[k])

    // ───────────────────────── Derived layout ─────────────────────────
    readonly property bool vertical: cfg.position === "left" || cfg.position === "right"
    readonly property bool joined: cfg.style !== "floating"
    readonly property bool strip: cfg.style === "strip"
    readonly property real bs: cfg.barScale
    readonly property int panelThick: Math.round((vertical ? cfg.thickness + 12 : cfg.thickness) * bs)
    readonly property int effEdge: strip ? 0 : Math.round(cfg.margin * bs)
    readonly property int effGap: strip ? 0 : Math.round(6 * bs)
    readonly property int modPadPx: Math.round(cfg.modPad * bs)
    readonly property int wsDotPx: Math.max(3, Math.round(cfg.wsDot * bs))
    readonly property int wsGapPx: Math.round(cfg.wsGap * bs)
    // the dot size slider drives the box in both modes; with numbers on, the digit scales with it
    readonly property int wsBoxPx: wsDotPx
    readonly property real barRadius: strip ? 0 : cfg.radius
    readonly property color bgColor: Qt.alpha(Theme.bg, cfg.bgOpacity)
    readonly property color borderColor: Theme.accent

    function s(n) { return Math.round(n * cfg.scale * cfg.barScale); }
    function cs(n) { return Math.round(n * cfg.scale * cfg.calScale); }   // calendar text sizes
    function cl(n) { return Math.round(n * cfg.calScale); }               // calendar layout sizes

    readonly property var sz: ({
        stat: s(12), clock: s(12), marquee: s(11),
        icon: s(16), batIcon: s(13), batText: s(12), power: s(14),
        taskIcon: s(18),
        calTime: cs(30), calDate: cs(12), calMonth: cs(13), calArrow: cs(16),
        calWeekday: cs(11), calDay: cs(12)
    })
    readonly property int sizeIconGap: Math.round(12 * bs)
    readonly property int iconYOffset: 1

    // Open-apps icon size: the base size times the user's scale, never larger than the bar itself.
    readonly property int taskIconPx: Math.max(8, Math.min(Math.round(sz.taskIcon * cfg.tasksScale), panelThick - 2))
    readonly property int taskGapPx: Math.round(cfg.tasksGap * bs)

    // margin for one side of the bar frame
    function edgeMargin(side) {
        if (cfg.position === side) return effEdge;
        const alongBar = vertical ? (side === "top" || side === "bottom")
                                  : (side === "left" || side === "right");
        return alongBar ? effGap : 0;
    }

    // ───────────────────────── App icon resolution ─────────────────────────
    // Resolves an icon for ANY window (rofi, Steam, Electron apps, XWayland
    // classes, Flatpaks, reverse-DNS app ids, absolute icon paths, ...).
    // Tries many candidates and returns the first that actually exists.
    function iconFor(appId) {
        const id = appId ?? "";
        const low = id.toLowerCase();
        const cands = [];
        const add = c => { if (c && c !== "" && cands.indexOf(c) < 0) cands.push(c); };

        // 1) desktop entry (matches StartupWMClass, id, name, ...)
        let entry = null;
        try {
            entry = DesktopEntries.heuristicLookup(id)
                 ?? DesktopEntries.heuristicLookup(low)
                 ?? DesktopEntries.byId(id)
                 ?? DesktopEntries.byId(low);
        } catch (e) { entry = null; }
        if (entry) {
            add(entry.icon);
            add(entry.id);
            add((entry.id ?? "").toLowerCase());
        }

        // 2) the app id itself, in several spellings
        add(id);
        add(low);
        add(low.replace(/\s+/g, "-"));
        add(low.replace(/[._\s]+/g, "-"));
        const parts = low.split(".");
        if (parts.length > 1) {
            add(parts[parts.length - 1]);          // org.gnome.Nautilus → nautilus
            add(parts.slice(-2).join("-"));
        }
        const dash = low.split("-");
        if (dash.length > 1) add(dash[0]);         // google-chrome-stable → google

        // 3) first candidate that resolves wins
        for (const c of cands) {
            if (c.startsWith("/")) return "file://" + c;      // absolute path in .desktop
            if (c.startsWith("file://") || c.startsWith("image://")) return c;
            const p = Quickshell.iconPath(c, true);            // true → "" when missing
            if (p !== "") return p;
        }

        // 4) generic fallbacks
        return Quickshell.iconPath("application-x-executable", true)
            || Quickshell.iconPath("application-default-icon", true)
            || Quickshell.iconPath("image-missing");
    }

    // Short, friendly app name for the open-apps tooltip (desktop entry name, else the app id).
    function appName(appId) {
        const id = appId ?? "";
        let entry = null;
        try {
            entry = DesktopEntries.heuristicLookup(id) ?? DesktopEntries.heuristicLookup(id.toLowerCase());
        } catch (e) { entry = null; }
        return entry && entry.name ? entry.name : id;
    }

    // ───────────────────────── Clock formatting ─────────────────────────
    function pad2(n) { return String(n).padStart(2, "0"); }

    // hour with or without a leading zero (02:20 / 2:20), 24h or 12h
    function hourText(d) {
        const h = cfg.clock24 ? d.getHours() : (d.getHours() % 12 || 12);
        return cfg.clockPadHour ? pad2(h) : String(h);
    }
    // AM/PM: "normal" and "lower" → pm / am, "upper" → PM / AM
    function ampmText(d) {
        const v = d.getHours() >= 12 ? "PM" : "AM";
        return cfg.clockCase === "upper" ? v : v.toLowerCase();
    }
    // short weekday: normal → Tue, upper → TUE, lower → tue
    function dayText(d) {
        const v = Qt.formatDate(d, "ddd");
        return cfg.clockCase === "upper" ? v.toUpperCase()
             : cfg.clockCase === "lower" ? v.toLowerCase() : v;
    }

    function clockText(d) {
        let t = hourText(d) + ":" + pad2(d.getMinutes());
        if (cfg.clockSeconds) t += ":" + pad2(d.getSeconds());
        return cfg.clock24 ? t : t + " " + ampmText(d);
    }
    function clockVText(d) {
        const parts = [hourText(d), pad2(d.getMinutes())];
        if (cfg.clockSeconds) parts.push(pad2(d.getSeconds()));
        if (!cfg.clock24) parts.push(ampmText(d));
        return parts.join("\n");
    }

    // Date goes to the right of / below the time and starts with a dot.
    // The calendar popup keeps using clockText() (no date).
    function clockBarText(d) {
        const t = clockText(d);
        if (!cfg.clockDate) return t;
        return t + "  \u2022  " + (cfg.clockDay ? dayText(d) + ", " : "") + Qt.formatDate(d, "dd/MM");
    }
    // Vertical: dot, weekday, day and month each on their own line (no "/").
    function clockBarVText(d) {
        const t = clockVText(d);
        if (!cfg.clockDate) return t;
        return t + "\n\u2022\n" + (cfg.clockDay ? dayText(d) + "\n" : "")
                 + Qt.formatDate(d, "dd") + "\n" + Qt.formatDate(d, "MM");
    }

    // ───────────────────────── Battery ─────────────────────────
    // ── TEST MODE ──
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
    readonly property var batIcons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
    readonly property string batIcon: batIcons[batPct >= 90 ? 4 : batPct >= 65 ? 3 : batPct >= 40 ? 2 : batPct >= 15 ? 1 : 0]

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

    // ───────────────────────── Module registry ─────────────────────────
    // Modules with `cmd` are rendered by the generic iconC component:
    //   g = glyph, tip = tooltip title, hint = left-click description.
    // Modules without it have a dedicated Component below (see `comps`).
    readonly property var moduleDefs: [
        { id: "clock",    l: "Clock" },
        { id: "cpu",      l: "CPU" },
        { id: "ram",      l: "RAM" },
        { id: "gpu",      l: "GPU" },
        { id: "temp",     l: "Temperatures" },
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
        cpu: cpuC, ram: ramC, gpu: gpuC, temp: tempC,
        ws: wsC, tasks: tasksC, media: mediaC, volume: volumeC, battery: batteryC, icon: iconC
    })

    // The old combined "stats" module is migrated to "cpu" + "ram" in saved configs.
    function csv(str) {
        if (str === "") return [];
        const out = [];
        for (const x of str.split(","))
        x === "stats" ? out.push("cpu", "ram") : out.push(x);
        return out;
    }
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
        case "media":   return Marquee.player !== null && Marquee.title !== "";
        case "battery": return hasBattery;
        default:        return true;
        }
    }

    // sections
    readonly property var startList: csv(cfg.startMods).filter(valid)
    readonly property var midLeftList: csv(cfg.midLeftMods).filter(valid)
    readonly property var centerList: {
        // The clock is a regular module now: it may live in any section (or be hidden),
        // so the center section can be empty.
        return csv(cfg.centerMods).filter(valid);
    }
    readonly property var midRightList: csv(cfg.midRightMods).filter(valid)
    readonly property var endList: {
        // Modules that are not placed anywhere (e.g. newly added ones) fall back to the end section.
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
    // config keys: startMods · midLeftMods · centerMods · midRightMods · endMods
    function setList(sec, a) { cfg[sec + "Mods"] = a.join(","); }
    function sectionOf(id) { return sections.find(k => listOf(k).indexOf(id) >= 0) ?? "end"; }

    function moveTo(id, sec) {
        const next = {};
        for (const k of sections) next[k] = listOf(k).filter(x => x !== id);
        next[sec].push(id);
        for (const k of sections) setList(k, next[k]);
    }

    // Move a module to a specific position of a section (used by drag & drop).
    // `idx` is an index into the section's list *before* the module is removed from it.
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

    // Walks up from any bar element to the Slot (module container) that owns it.
    function slotOf(item) {
        let p = item;
        while (p) {
            if (p.isSlot === true) return p;
            p = p.parent;
        }
        return null;
    }

    // ───────────────────────── State / IPC ─────────────────────────
    property bool barVisible: true
    property bool barLive: true

    function rebuildBar() { barLive = false; rebuildTimer.restart(); }
    Timer { id: rebuildTimer; interval: 80; onTriggered: root.barLive = true }
    Connections {
        target: cfg
        function onPositionChanged() { root.rebuildBar(); }
        function onStyleChanged() { root.rebuildBar(); }
    }

    // Bar settings now live on the BarPage of the settings app.
    // Adjust the IPC call below if your settings app names the page differently.
    function openSettings() { run("qs ipc call settings bar"); }

    // Shared click actions (clock + settings button binds)
    // "settings" | "barsettings" | "quickactions" | "none"
    function actionHint(a) {
        return a === "settings" ? "Settings"
             : a === "barsettings" ? "Bar settings"
             : a === "quickactions" ? "Quick actions" : "";
    }
    function doAction(a) {
        if (a === "settings") run("qs ipc call settings toggle");
        else if (a === "barsettings") openSettings();
        else if (a === "quickactions") run("qs ipc call qa toggle");
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
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
        // section: start | midLeft | center | midRight | end
        function moveModule(id: string, section: string): void {
            if (root.valid(id) && root.sections.indexOf(section) >= 0) { root.moveTo(id, section); root.save(); }
        }
        function shiftModule(id: string, delta: int): void {
            if (root.valid(id)) { root.shiftBy(id, delta); root.save(); }
        }

        // Battery test mode (not saved to the config file)
        function batteryTest(on: bool): void { root.batTest = on; }
        function batteryLevel(pct: int): void { root.batTestPct = Math.max(0, Math.min(100, pct)); }
        function batteryCharging(on: bool): void { root.batTestCharging = on; }
    }

    // ───────────────────────── System stats ─────────────────────────
    property int cpuUsage: 0
    property int memPercent: 0
    property real memUsedG: 0
    property real memTotalG: 0
    property string netState: "disconnected"
    property real _prevTotal: 0
    property real _prevIdle: 0

    // GPU / temperatures (-1 = unavailable)
    property int gpuUsage: 0
    property bool gpuHasUsage: false
    property int cpuTemp: -1
    property int gpuTempProbe: -1       // from nvidia-smi / sysfs hwmon
    property int gpuTempSensors: -1     // fallback from `sensors`
    readonly property int gpuTemp: gpuTempProbe >= 0 ? gpuTempProbe : gpuTempSensors

    function tempText(v) { return v >= 0 ? v + "" : "–"; }
    function tempTip(name, v) { return v >= 0 ? name + " temperature: " + v + "°C" : name + " temperature: unavailable"; }

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

    // ── GPU probe (vendor-agnostic, no root needed) ──
    // Prints "<usage%> <tempC>"; a field is "-" when unavailable.
    //   1. NVIDIA  : nvidia-smi
    //   2. AMD     : sysfs gpu_busy_percent (largest-VRAM card wins)
    //   3. Intel   : intel_gpu_top (only if permitted, 3s timeout)
    //   4. Intel/other fallback: GPU clock estimate (act_freq / max_freq)
    // Temperature: nvidia-smi, else any DRM card hwmon temp, else `sensors`.
    readonly property string gpuProbeScript: `
u=-; t=-
isnum() { case "$1" in ''|*[!0-9.]*) return 1;; *) return 0;; esac; }

# 1. NVIDIA
if command -v nvidia-smi >/dev/null 2>&1; then
  o=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
  if [ -n "$o" ]; then
    a=$(echo "$o" | cut -d, -f1 | tr -d ' ')
    b=$(echo "$o" | cut -d, -f2 | tr -d ' ')
    isnum "$a" && u="$a"
    isnum "$b" && t="$b"
  fi
fi

# 2. AMD (amdgpu sysfs)
if [ "$u" = "-" ]; then
  best=""; bestmem=-1
  for d in /sys/class/drm/card[0-9]*/device; do
    [ -r "$d/gpu_busy_percent" ] || continue
    m=$(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0)
    isnum "$m" || m=0
    if [ "$m" -gt "$bestmem" ]; then best="$d"; bestmem="$m"; fi
  done
  if [ -n "$best" ]; then
    a=$(cat "$best/gpu_busy_percent" 2>/dev/null)
    isnum "$a" && u="$a"
    if [ "$t" = "-" ]; then
      for h in "$best"/hwmon/hwmon*/temp1_input; do
        if [ -r "$h" ]; then t=$(( $(cat "$h") / 1000 )); break; fi
      done
    fi
  fi
fi

# 3. Intel via intel_gpu_top (needs CAP_PERFMON / root; silently skipped otherwise)
if [ "$u" = "-" ] && command -v intel_gpu_top >/dev/null 2>&1; then
    v=$(timeout 4 intel_gpu_top -J -s 1000 -n 2 2>/dev/null | awk 'index($0,"Render/3D"){f=1;next} f==1 && /busy/{x=$0;gsub(/[^0-9.]/,"",x);f=2;next} f==2{if(/sema/)last=x;f=0} END{print last}')
    isnum "$v" && u="$v"
fi

# 4. Unprivileged fallback: GPU clock as a load estimate (i915 / xe)
if [ "$u" = "-" ]; then
  for c in /sys/class/drm/card[0-9]*; do
    [ -d "$c" ] || continue
    for pair in \
      "$c/gt/gt0/rps_act_freq_mhz:$c/gt/gt0/rps_max_freq_mhz" \
      "$c/gt/gt0/rps_cur_freq_mhz:$c/gt/gt0/rps_max_freq_mhz" \
      "$c/gt_act_freq_mhz:$c/gt_max_freq_mhz" \
      "$c/gt_cur_freq_mhz:$c/gt_max_freq_mhz" \
      "$c/device/tile0/gt0/freq0/act_freq:$c/device/tile0/gt0/freq0/max_freq"; do
      f1=\${pair%%:*}; f2=\${pair#*:}
      [ -r "$f1" ] && [ -r "$f2" ] || continue
      cur=$(cat "$f1" 2>/dev/null); max=$(cat "$f2" 2>/dev/null)
      if isnum "$cur" && isnum "$max" && [ "$max" -gt 0 ]; then
        u=$(( cur * 100 / max )); [ "$u" -gt 100 ] && u=100
        break 2
      fi
    done
  done
fi

# Temperature fallback: any DRM card hwmon (i915 / xe / nouveau / amdgpu)
if [ "$t" = "-" ]; then
  for h in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/temp1_input; do
    if [ -r "$h" ]; then
      r=$(cat "$h" 2>/dev/null)
      if isnum "$r"; then t=$(( r / 1000 )); break; fi
    fi
  done
fi

echo "$u $t"
`

    property real _gpuAvg: -1
    function updateGpuFromProbe(out) {
        const p = out.trim().split(/\s+/);
        const u = parseFloat(p[0]), t = parseFloat(p[1]);
        gpuHasUsage = !isNaN(u);
        if (gpuHasUsage) {
            const v = Math.max(0, Math.min(100, u));
            _gpuAvg = _gpuAvg < 0 ? v : _gpuAvg * 0.6 + v * 0.4;
            gpuUsage = Math.round(_gpuAvg);
        } else {
            _gpuAvg = -1;
        }
        gpuTempProbe = isNaN(t) ? -1 : Math.round(t);
    }

    // First `sensors` line starting with one of the keys (tried in priority order) → °C, or -1.
    function tempFromSensors(lines, keys) {
        for (const k of keys) {
            for (const l of lines) {
                const line = l.trim();
                if (line.indexOf(k) !== 0) continue;
                const m = line.match(/([+-]?\d+(?:\.\d+)?)\s*°/);
                if (m) return Math.round(parseFloat(m[1]));
            }
        }
        return -1;
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", root.gpuProbeScript]
        stdout: StdioCollector { onStreamFinished: root.updateGpuFromProbe(text) }
    }

    Process {
        // single `sensors` call serves CPU temp and the GPU temp fallback
        id: sensorsProc
        command: ["sensors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.cpuTemp = root.tempFromSensors(lines, ["Package id 0:", "Tctl:", "Tdie:"]);
                root.gpuTempSensors = root.tempFromSensors(lines, ["GPU Temp:", "edge:", "junction:"]);
            }
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

    // CPU / RAM sampling (only while one of those modules is enabled)
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.barVisible && (root.isOn("cpu") || root.isOn("ram"))
        onTriggered: { statFile.reload(); memFile.reload(); }
    }
    // GPU usage / temps (only while the GPU or temperature module is enabled)
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.barVisible && (root.isOn("gpu") || root.isOn("temp"))
        onTriggered: { if (!gpuProc.running) gpuProc.running = true; }
    }
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.barVisible && root.isOn("temp")
        onTriggered: { if (!sensorsProc.running) sensorsProc.running = true; }
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

    readonly property string wsHints: "Left click: Switch to workspace\nRight click: Quick actions\nScroll: Previous / next workspace"

    // ───────────────────────── Interaction model ─────────────────────────
    // Convention used by every bar module:
    //   Left click   → primary action
    //   Right click  → secondary action (falls back to "Bar settings" if the module has none)
    //   Middle click → tertiary action (optional)
    //   Scroll       → adjust a value (optional)
    //   Drag         → move the module (reorder, or drop it in another section)
    // Hints declared on a module are shown automatically in its tooltip.
    // States: hover · pressed · active (accent) · warning (danger) · disabled.

    component Lane: GridLayout {
        property int gap: 0
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: gap
        columnSpacing: gap
    }

    // MouseArea that also lets the user drag the whole module (its Slot) along the bar.
    // A press that moves further than a small threshold along the bar axis starts a drag;
    // the click that would normally follow the release is suppressed (see `suppressClick`).
    // Handlers using this must check `suppressClick` in onClicked.
    component DMouseArea: MouseArea {
        id: dm
        property bool suppressClick: false
        property bool dragging: false
        property point startScene: Qt.point(0, 0)
        property var owner: null

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
                    radius: Math.min(cfg.radius, height / 2)
                    color: root.bgColor
                    border.width: cfg.tooltipBorder ? 1 : 0
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
        property bool noSecondary: false       // right click does nothing (and is not listed in the tooltip)
        property bool noHints: false           // never list click / scroll hints in the tooltip (title only)
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

        DMouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: it.interactive && !it.disabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: { tipper.suppressed = true; tipper.shown = false; }
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
        property real xOffset: 0         // horizontal nudge (negative → left), applies to vertical and horizontal bars
        property real glyphScaleY: 1.0
        property int spacing: root.sizeIconGap
        property int padX: root.modPadPx

        readonly property color fg: warning ? Theme.danger : active ? Theme.accent : color
        readonly property string shown: root.vertical ? vtext : text
        readonly property string shownGlyph: root.vertical ? vglyph : glyph

        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.vertical ? root.panelThick : content.implicitWidth + padX
        implicitHeight: root.vertical ? Math.max(20, content.implicitHeight + Math.round(padX * 0.4))
                                      : Math.max(root.panelThick - 2, content.implicitHeight)
        GridLayout {
            id: content
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.vertical ? 0 : mod.yOffset
            anchors.horizontalCenterOffset: mod.xOffset
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
                transform: Scale {
                    yScale: mod.glyphScaleY
                    origin.y: height / 2
                }
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

    // Rounded stat badge (CPU / RAM / GPU / temperatures), informational only.
    // Capsule with label + value ("CPU 12" / stacked on vertical bars).
    // `unit` ("%" or "°C") is appended when the "show unit symbols" option is on.
    component StatBadge: Interactive {
        id: stat
        property string label: ""
        property string valueText: ""
        property string unit: ""
        readonly property string shownValue: valueText + (cfg.statsPercent ? unit : "")
        readonly property color fg: warning ? Theme.danger : Theme.text

        // ── Never outgrow the bar ──
        // `maxCross` is the room across the bar (height on horizontal bars, width on vertical
        // ones), minus the bar border when it is on. The badge, its border and its tint layer are
        // kept inside it, and the text shrinks (down to 6px) when the text scale or a thin bar
        // would otherwise make the badge bigger than the bar background.
        readonly property int maxCross: Math.max(8, root.panelThick - (cfg.border ? 2 : 0))
        readonly property int crossPad: root.vertical ? 8 : 6
        readonly property int wantedPx: Math.max(6, Math.round(root.sz.taskIcon * 0.5 * cfg.statsScale))
        // worst-case value ("100" / "100%") so the font does not jump while the numbers change
        readonly property string sampleValue: "100" + (cfg.statsPercent ? "%" : "")
        readonly property real contentCross: root.vertical
            ? Math.max(mLabel.width, mValue.width)
            : Math.max(mLabel.height, mValue.height)
        readonly property int fontPx: contentCross + crossPad > maxCross
            ? Math.max(6, Math.floor(wantedPx * (maxCross - crossPad) / contentCross))
            : wantedPx

        // measured at the wanted size (not the final one) so there is no binding loop
        TextMetrics {
            id: mLabel
            text: stat.label
            font.family: Theme.iconFont
            font.pixelSize: stat.wantedPx - 1
        }
        TextMetrics {
            id: mValue
            text: stat.sampleValue
            font.family: Theme.iconFont
            font.bold: true
            font.pixelSize: stat.wantedPx
        }

        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.vertical ? root.panelThick : badge.width + cfg.statsGap
        // the item (and its warning tint) stays inside the bar thickness
        implicitHeight: root.vertical ? badge.height + cfg.statsGap
                                      : Math.min(root.panelThick, Math.max(root.panelThick - 2, badge.height + 6))
        interactive: false

        Rectangle {
            id: badge
            anchors.centerIn: parent
            width: root.vertical ? Math.min(stat.maxCross, Math.max(root.sz.taskIcon + 6, statRow.implicitWidth + 8))
                                 : statRow.implicitWidth + 14
            height: root.vertical ? statRow.implicitHeight + 10
                                  : Math.min(stat.maxCross, Math.max(root.sz.taskIcon, statRow.implicitHeight + 6))
            clip: true                       // last resort: text can never paint outside the badge
            radius: Math.min(cfg.statsRadius, Math.min(width, height) / 2)   // clamped: large values give the pill shape
            color: Qt.alpha(stat.fg, 0.045)
            border.width: cfg.statsBorder ? 1 : 0
            border.color: Qt.alpha(stat.fg, 0.18)

            GridLayout {
                id: statRow
                anchors.centerIn: parent
                flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: 0
                columnSpacing: 4

                Text {
                    Layout.alignment: Qt.AlignCenter
                    text: stat.label
                    color: Qt.alpha(stat.fg, 0.75)
                    font.family: Theme.iconFont
                    font.pixelSize: stat.fontPx - 1
                    renderType: Text.NativeRendering
                }
                Text {
                    Layout.alignment: Qt.AlignCenter
                    text: stat.shownValue
                    color: stat.fg
                    font.family: Theme.iconFont
                    font.bold: true
                    font.pixelSize: stat.fontPx
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // Container for one module. Also owns the drag state while the module is being dragged:
    // the module follows the pointer visually (transform only, layout is untouched) and,
    // on release, `droppedAt` tells the bar where it was dropped.
    component Slot: Loader {
        id: slot
        required property string modelData
        property Component clockComp: null

        readonly property bool isSlot: true
        readonly property bool dragAllowed: cfg.dragModules
        property bool dragging: false
        property real dragDx: 0
        property real dragDy: 0
        signal droppedAt(real sx, real sy)

        function finishDrag(sx, sy) {
            dragging = false;
            dragDx = 0;
            dragDy = 0;
            droppedAt(sx, sy);
        }
        function cancelDrag() {
            dragging = false;
            dragDx = 0;
            dragDy = 0;
        }

        visible: root.modVisible(modelData)
        Layout.alignment: Qt.AlignCenter
        z: dragging ? 100 : 0
        opacity: dragging ? 0.75 : 1
        transform: Translate { x: slot.dragDx; y: slot.dragDy }
        sourceComponent: modelData === "clock" ? clockComp : (root.comps[modelData] ?? root.comps.icon)
        onLoaded: if (item.mid !== undefined) item.mid = modelData
    }

    // One of the five bar sections: a rounded panel holding a Lane of Slots
    component Panel: Rectangle {
        id: panel
        property var model: []
        property Component clockComp: null
        property bool dragActive: false          // a module of this panel is being dragged
        readonly property Item lane: laneItem
        signal dropped(string modId, real sx, real sy)

        // Visibility must NOT depend on the lane's implicit size: an invisible panel never
        // re-polishes its layout, so the size would stay 0 and the panel could never come back
        // (e.g. re-enabling the clock in an otherwise empty section).
        readonly property bool hasVisible: model.some(id => root.modVisible(id))
        visible: hasVisible
        z: dragActive ? 100 : 0                  // keep the dragged module above the other panels
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
                delegate: Slot {
                    id: slotD
                    clockComp: panel.clockComp
                    onDroppedAt: (sx, sy) => panel.dropped(slotD.modelData, sx, sy)
                    onDraggingChanged: panel.dragActive = dragging
                }
            }
        }
    }

    // ───────────────────────── Bar helper components ─────────────────────────
    component Rule: Rectangle {
        height: 1
        color: Qt.alpha(Theme.text, 0.12)
    }

    component Arrow: Item {
        id: ar
        property string glyph: ""
        signal clicked()
        width: root.cl(28)
        height: root.cl(26)
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
            id: ic
            property var def: root.defMap[mid] ?? ({})
            readonly property bool isNet: mid === "net"
            readonly property bool isNotif: mid === "notif"
            readonly property bool isSettings: mid === "settings"
            baseSize: mid === "power" ? root.sz.power - 1 : root.sz.icon
            yOffset: mid === "power" ? 0 : isNotif && !root.vertical ? root.iconYOffset - 0.5 : root.iconYOffset
            xOffset: !root.vertical ? 0 : isNet ? -2 : (mid === "power" || isSettings) ? -1 : 0
            text: isNet ? root.netGlyph : (def.g ?? "")
            tip: isNet ? root.netTip : mid === "notif" ? root.notifTip : (def.tip ?? "")
            // The settings button has configurable click binds (see Bar page → Settings button)
            primaryHint: isSettings ? root.actionHint(cfg.settingsPrimary) : (def.hint ?? "")
            secondaryHint: isSettings ? root.actionHint(cfg.settingsSecondary) : ""
            tertiaryHint: isSettings ? root.actionHint(cfg.settingsTertiary) : ""
            noSecondary: isSettings && cfg.settingsSecondary === "none"
            warning: isNet && root.netState === "disconnected"
            onPrimary: {
                if (isSettings) root.doAction(cfg.settingsPrimary);
                else if (def.cmd) root.run(def.cmd);
            }
            onSecondary: if (isSettings) root.doAction(cfg.settingsSecondary)
            onTertiary: if (isSettings) root.doAction(cfg.settingsTertiary)

            // Notification count badge (top-right of the icon)
            Rectangle {
                visible: ic.isNotif && root.notifCount > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenterOffset: Math.round(root.sz.icon / 2)
                anchors.verticalCenterOffset: -Math.round(root.sz.icon / 2) + 1
                width: Math.max(height, badgeText.implicitWidth + 6)
                height: Math.max(11, badgeText.implicitHeight + 1)
                radius: height / 2
                color: Theme.bg

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.notifCount > 9 ? "9+" : root.notifCount
                    color: Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: Math.max(8, root.s(8))
                    font.bold: true
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // CPU usage
    Component {
        id: cpuC
        StatBadge {
            label: "CPU"
            unit: "%"
            valueText: String(root.cpuUsage)
            warning: root.cpuUsage >= cfg.statsWarn
            tip: "CPU usage: " + root.cpuUsage + "%"
        }
    }

    // RAM usage
    Component {
        id: ramC
        StatBadge {
            label: "RAM"
            unit: "%"
            valueText: String(root.memPercent)
            warning: root.memPercent >= cfg.statsWarn
            tip: "Memory: " + root.memUsedG.toFixed(1) + " / " + root.memTotalG.toFixed(1)
                 + " GiB (" + root.memPercent + "%)"
        }
    }

    // GPU usage
    Component {
        id: gpuC
        StatBadge {
            label: "GPU"
            unit: root.gpuHasUsage ? "%" : ""
            valueText: root.gpuHasUsage ? String(root.gpuUsage) : "–"
            warning: root.gpuHasUsage && root.gpuUsage >= cfg.statsWarn
            tip: root.gpuHasUsage ? "GPU usage: " + root.gpuUsage + "%" : "GPU usage: unavailable"
        }
    }

    // CPU + GPU temperatures (two badges)
    Component {
        id: tempC
        Lane {
            gap: 2
            StatBadge {
                label: "TEMP"
                unit: root.cpuTemp >= 0 ? "°" : ""
                valueText: root.tempText(root.cpuTemp)
                warning: root.cpuTemp >= cfg.tempWarn
                tip: root.tempTip("CPU", root.cpuTemp)
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
                gap: root.wsGapPx

                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        id: dot
                        required property var modelData
                        visible: modelData.id > 0
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: root.vertical ? root.wsBoxPx
                                     : (modelData.focused && !cfg.wsNumbers ? Math.round(root.wsBoxPx * 3.2) : root.wsBoxPx)
                        implicitHeight: root.vertical ? (modelData.focused && !cfg.wsNumbers ? Math.round(root.wsBoxPx * 2.4) : root.wsBoxPx)
                                                      : root.wsBoxPx
                        radius: root.wsBoxPx / 2
                        color: modelData.urgent ? Theme.danger
                             : modelData.focused ? Qt.alpha(Theme.accent, 0.2)
                             : dotMa.containsMouse ? Theme.accent2
                             : Qt.alpha(Theme.textFaint, 0.5)

                        Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                        Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }

                        // workspace number (only instantiated while the option is on)
                        Loader {
                            anchors.centerIn: parent
                            active: cfg.wsNumbers
                            sourceComponent: Text {
                                text: dot.modelData.id
                                color: dot.modelData.focused ? Theme.accent : Theme.text
                                font.family: Theme.iconFont
                                font.pixelSize: Math.round(root.wsBoxPx * 0.62)
                                font.bold: dot.modelData.focused
                                renderType: Text.NativeRendering
                            }
                        }

                        DMouseArea {
                            id: dotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: { dotTip.suppressed = true; dotTip.shown = false; }
                            onClicked: mouse => {
                                if (dotMa.suppressClick) return;
                                if (mouse.button === Qt.RightButton) root.openSettings();
                                else Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.modelData.id + " })");
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

    // Open apps — icons resolved by root.iconFor() so every app gets one.
    // Options (Bar page → Open apps): icon scale, spacing, normal / accent colour.
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
                    active: modelData.activated
                    // minimal tooltip: just the app name, no hint lines
                    tip: root.appName(modelData.appId)
                    noHints: true
                    primaryHint: "Focus window"
                    tertiaryHint: "Close window"
                    onPrimary: modelData.activate()
                    onTertiary: modelData.close()
                    Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: root.taskIconPx
                        height: root.taskIconPx
                        sourceSize: Qt.size(width, height)
                        asynchronous: true
                        smooth: true
                        visible: false          // rendered through the tint effect below
                        source: root.iconFor(task.modelData.appId)
                    }
                    // "normal": the app's own icon colours.
                    // "accent": flat monochrome icon in Theme.text (accent2 when the window is focused).
                    MultiEffect {
                        anchors.fill: appIcon
                        source: appIcon
                        colorization: cfg.tasksColor === "accent" ? 1.0 : 0.0
                        colorizationColor: task.modelData.activated ? Theme.accent2 : Theme.text
                        opacity: task.modelData.activated ? 1 : 0.75
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
            yOffset: root.iconYOffset + 0.25
            xOffset: root.vertical ? -1 : 0
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
            glyphScaleY: 1.12
            yOffset: root.iconYOffset
            // Nudge the battery glyph left. Increase a number for a bigger shift.
            //   vertical bars   → 3
            //   horizontal bars → 2
            xOffset: -Math.round((root.vertical ? 2 : 3) * root.bs)
            glyph: root.batIcon
            warning: root.batLow
            tip: root.batTip
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

            // Drag & drop: (sx, sy) is the pointer position in window coordinates at release.
            // Section: if the pointer landed on a visible panel, that panel's section wins.
            // Otherwise the nearest of the five zones (start · midLeft · center · midRight · end)
            // is used, so empty zones are still valid drop targets. The position inside the
            // section is the slot after the last visible module whose centre lies before the pointer.
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
                    const mid = frame.axisLen / 2;
                    const targets = {
                        start: startPanel.visible ? (frame.startBeg + frame.startEnd) / 2 : 0,
                        midLeft: frame.midLeftC,
                        center: mid,
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
                const kids = panel.lane.children;
                for (let j = 0; j < kids.length; j++) {
                    const ch = kids[j];
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
                    fill: parent
                    topMargin: root.edgeMargin("top")
                    bottomMargin: root.edgeMargin("bottom")
                    leftMargin: root.edgeMargin("left")
                    rightMargin: root.edgeMargin("right")
                }

                // ── Geometry along the bar axis (x on horizontal bars, y on vertical ones) ──
                // The two middle zones sit centered in the gap between their neighbours:
                //   midLeft  → between the end of the start panel and the start of the center panel
                //   midRight → between the end of the center panel and the start of the end panel
                // Hidden (empty) neighbours fall back to the bar's start / middle / end.
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
                    visible: root.joined
                    anchors.fill: parent
                    radius: root.barRadius
                    color: root.bgColor
                    border.width: cfg.border ? 1 : 0
                    border.color: root.borderColor
                }

                // 1 · start
                Panel {
                    id: startPanel
                    model: root.startList
                    clockComp: clockC
                    anchors.left: frame.left
                    anchors.top: frame.top
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }

                // 2 · between start and center
                Panel {
                    id: midLeftPanel
                    model: root.midLeftList
                    clockComp: clockC
                    x: root.vertical ? 0
                                     : Math.max(0, Math.min(frame.axisLen - width, frame.midLeftC - width / 2))
                    y: root.vertical ? Math.max(0, Math.min(frame.axisLen - height, frame.midLeftC - height / 2))
                                     : 0
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }

                // 3 · center (also hosts the clock logic + calendar popup, wherever the clock is placed)
                Panel {
                    id: clockPanel
                    model: root.centerList
                    clockComp: clockC
                    anchors.horizontalCenter: root.vertical ? undefined : frame.horizontalCenter
                    anchors.verticalCenter: root.vertical ? frame.verticalCenter : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)

                    property bool calOpen: false
                    property int monthOffset: 0
                    property Item clockItem: null     // the live clock module (wherever it was placed)

                    // The popup window stays mounted for a moment after the calendar is
                    // closed so the close animation can play (same idea as the
                    // notification panel). Must outlast the longest calendar animation.
                    property bool calMounted: false
                    Timer {
                        id: calUnmountTimer
                        interval: 260
                        onTriggered: clockPanel.calMounted = false
                    }
                    onCalOpenChanged: {
                        if (calOpen) {
                            calUnmountTimer.stop();
                            calMounted = true;
                        } else {
                            calUnmountTimer.restart();
                        }
                    }

                    // The clock is only needed while the module is enabled.
                    SystemClock {
                        id: clk
                        enabled: root.isOn("clock")
                        precision: cfg.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
                    }

                    Component {
                        id: clockC
                        Mod {
                            id: clockMod

                            // "calendar" | "quickactions" | "settings" | "barsettings" | "none"
                            function hintFor(a) {
                                return a === "calendar" ? (clockPanel.calOpen ? "Close calendar" : "Open calendar")
                                                        : root.actionHint(a);
                            }
                            function act(a) {
                                if (a === "calendar") {
                                    clockPanel.monthOffset = 0;
                                    clockPanel.calOpen = !clockPanel.calOpen;
                                } else {
                                    root.doAction(a);
                                }
                            }

                            bold: true
                            baseSize: root.sz.clock
                            text: root.clockBarText(clk.date)
                            vtext: root.clockBarVText(clk.date)
                            active: clockPanel.calOpen
                            tip: Qt.formatDate(clk.date, "dddd, d MMMM yyyy")
                            primaryHint: hintFor(cfg.clockPrimary)
                            secondaryHint: hintFor(cfg.clockSecondary)
                            tertiaryHint: hintFor(cfg.clockTertiary)
                            noSecondary: secondaryHint === ""
                            onPrimary: act(cfg.clockPrimary)
                            onSecondary: act(cfg.clockSecondary)
                            onTertiary: act(cfg.clockTertiary)

                            onVisibleChanged: if (!visible) clockPanel.calOpen = false   // clock hidden → close calendar
                            Component.onCompleted: clockPanel.clockItem = clockMod
                            Component.onDestruction: if (clockPanel.clockItem === clockMod) clockPanel.clockItem = null
                        }
                    }
                    LazyLoader {
                        active: clockPanel.calMounted && root.isOn("clock") && clockPanel.clockItem !== null

                        PopupWindow {
                            id: calWin
                            readonly property Item ci: clockPanel.clockItem
                            readonly property point p: bar.contentItem.mapFromItem(ci, 0, 0)

                            // The window can be created with the calendar already open; bind
                            // `reveal` one tick later so the open animation still plays.
                            property bool reveal: false
                            Component.onCompleted: {
                                Qt.callLater(function () {
                                    calWin.reveal = Qt.binding(function () { return clockPanel.calOpen; });
                                });
                            }

                            anchor.window: bar
                            anchor.rect.x: root.vertical
                                ? (cfg.position === "left" ? p.x + ci.width + 6
                                                           : p.x - implicitWidth - 6)
                                : p.x + (ci.width - implicitWidth) / 2
                            anchor.rect.y: root.vertical
                                ? p.y + (ci.height - implicitHeight) / 2
                                : (cfg.position === "top" ? p.y + ci.height + 4
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

                                // Grows out of the edge facing the bar (and shrinks back into
                                // it on close), so it works for every bar position:
                                //   top    → from the top edge, centered
                                //   bottom → from the bottom edge, centered
                                //   left   → from the left edge, centered
                                //   right  → from the right edge, centered
                                property real grow: calWin.reveal ? 1 : 0.3
                                Behavior on grow {
                                    NumberAnimation {
                                        duration: calWin.reveal ? 220 : 140
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                opacity: calWin.reveal ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: calWin.reveal ? 180 : 120
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                                transform: Scale {
                                    origin.x: root.vertical ? (cfg.position === "left" ? 0 : calBox.width)
                                                            : calBox.width / 2
                                    origin.y: root.vertical ? calBox.height / 2
                                                            : (cfg.position === "top" ? 0 : calBox.height)
                                    xScale: calBox.grow
                                    yScale: calBox.grow
                                }

                                readonly property int firstDay: cfg.weekMonday ? 1 : 0
                                readonly property int cellW: root.cl(36)
                                readonly property int cellH: root.cl(30)
                                readonly property int pad: root.cl(16)
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
                                    spacing: root.cl(12)

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
                                        height: root.cl(26)

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

                // 4 · between center and end
                Panel {
                    id: midRightPanel
                    model: root.midRightList
                    clockComp: clockC
                    x: root.vertical ? 0
                                     : Math.max(0, Math.min(frame.axisLen - width, frame.midRightC - width / 2))
                    y: root.vertical ? Math.max(0, Math.min(frame.axisLen - height, frame.midRightC - height / 2))
                                     : 0
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }

                // 5 · end
                Panel {
                    id: endPanel
                    model: root.endList
                    clockComp: clockC
                    anchors.right: root.vertical ? undefined : frame.right
                    anchors.bottom: root.vertical ? frame.bottom : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined
                    onDropped: (modId, sx, sy) => bar.dropModule(modId, sx, sy)
                }
            }
        }
    }
}