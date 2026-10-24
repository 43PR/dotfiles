pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import QtQuick

Scope {
    id: root

    // ---- config / state ---------------------------------------------------
    property int topGap: 50
    property int sideGap: 16
    property int edgeGap: 0
    property int baseWidth: 340
    property int maxHistory: 100

    property bool dnd: false
    property bool soundEnabled: true
    property bool panelOpen: false
    property bool stateReady: false
    property bool dirsReady: false
    property bool historyReady: false
    property bool dragging: false
    property real offsetX: 0
    property real offsetY: 0
    property int menuSize: 100
    readonly property real ui: menuSize / 100
    readonly property int cardWidth: Math.round(baseWidth * ui)
    readonly property bool movedFromDefault: offsetX !== 0 || offsetY !== 0

    readonly property string home: Quickshell.env("HOME")

    // toast lifetimes (ms) when the app gives no timeout
    readonly property int normalTimeout: 6000
    readonly property int criticalTimeout: 20000

    // grouping state (collapsed groups are persisted, expanded entries are not)
    property var collapsedApps: ({})
    property var expandedSet: ({})
    property int groupCount: 0
    property bool allCollapsed: false

    // an expanded group shows at most `groupLimit` entries at a time; the
    // mouse wheel (or the pager arrows) scrolls through the rest

    property int groupLimit: 3

    property var groupOffsets: ({})
    property bool animateRows: false

    // Do Not Disturb normally lets critical notifications through. Many chat
    // apps (Discord and its clients) mark everything critical, so these apps
    // are muted by DND regardless of urgency. Lowercase substrings of appName.
    property var dndMuteCritical: ["discord", "vesktop", "webcord", "armcord"]
    Timer { id: animTimer; interval: 400; onTriggered: root.animateRows = false }

    // extra glyphs (Nerd Font / Material Design Icons, written as surrogate pairs)
    readonly property string icDown: "\uDB80\uDD40"
    readonly property string icRight: "\uDB80\uDD42"
    readonly property string icUp: "\uDB80\uDD43"
    readonly property string icCopy: "\uDB80\uDD8F"
    readonly property string icCheck: "\uDB80\uDD2C"

    signal rowsAboutToRebuild()
    signal rowsRebuilt()

    // ---- lifecycle: window is mounted only when needed ---------------------
    readonly property bool wanted: panelOpen || server.trackedNotifications.values.length > 0
    property bool mounted: false

    onWantedChanged: {
        if (wanted) {
            unmountTimer.stop();
            mounted = true;
        } else {
            unmountTimer.restart();
        }
    }

    // must outlast the longest fade (toast 200ms / panel 200ms)
    Timer {
        id: unmountTimer
        interval: 260
        onTriggered: root.mounted = false
    }

    onPanelOpenChanged: {
        if (!panelOpen) {
            dragging = false;
            // closing mid-drag never delivers a release event; persist anyway
            if (stateReady) stateTimer.restart();
        }
    }

    // ---- helpers (no window dependencies) ----------------------------------
    function px(n) { return Math.round(n * ui); }
    function imgSrc(p) { return !p ? "" : (p.startsWith("/") ? "file://" + p : p); }
    function canExpand(body) { return body.length > 70 || body.indexOf("\n") >= 0; }
    function groupKey(app) { return app && app !== "" ? app : "Other"; }

    function guessKind(app, summary) {
        const s = ((app || "") + " " + (summary || "")).toLowerCase();
        if (/todo|remind/.test(s)) return "reminder";
        if (/usb|disk|drive|device|mount|eject|removed|unplug|storage|udisks|udiskie/.test(s)) return "usb";
        if (/batter/.test(s)) return "battery";
        return "";
    }
    function resolveIcon(image, icon, app, summary) {
        const kind = guessKind(app, summary);
        if (kind === "reminder") return "";
        if (image && image !== "" && !String(image).startsWith("image://icon"))
            return imgSrc(image);
        const cands = [];
        if (icon && icon !== "") cands.push(icon);
        if (app && app !== "") {
            cands.push(app);
            cands.push(app.toLowerCase());
        }
        if (kind === "usb")
            cands.push("drive-removable-media-usb", "drive-removable-media", "media-removable", "usb-creator-gtk", "drive-harddisk-usb");
        else if (kind === "battery")
            cands.push("battery-caution", "battery");
        cands.push("dialog-information");

        for (let i = 0; i < cands.length; i++) {
            const c = cands[i];
            if (c.startsWith("/")) return "file://" + c;
            if (c.startsWith("image://")) return c;
            const p = String(Quickshell.iconPath(c, true) || "");
            // reject empty results and the "missing icon" placeholder
            if (p !== "" && p.indexOf("missing") === -1) return p;
        }
        return "";
    }

    // glyph shown when no icon could be resolved
    function glyphFor(app, summary) {
        return guessKind(app, summary) === "reminder" ? "󰂞" : "󰂚";
    }

    function fmtTime(ms) {
        const d = new Date(ms);
        return d.toDateString() === new Date().toDateString()
            ? Qt.formatDateTime(d, "HH:mm")
            : Qt.formatDateTime(d, "dd MMM HH:mm");
    }
    function copyText(s, b) { Quickshell.execDetached(["wl-copy", b !== "" ? s + "\n" + b : s]); }
    function copyRaw(s) { Quickshell.execDetached(["wl-copy", s]); }

    function toggleDnd() { dnd = !dnd; stateTimer.restart(); }
    function toggleSound() { soundEnabled = !soundEnabled; stateTimer.restart(); }
    function resetPosition() {
        offsetX = 0;
        offsetY = 0;
        stateTimer.restart();
    }

    // ---- history actions ------------------------------------------------------
    function removeHistory(i) {
        if (i < 0 || i >= history.count) return;
        history.remove(i);
        saveTimer.restart();
        scheduleRebuild();
    }
    function clearHistory() {
        history.clear();
        saveTimer.restart();
        scheduleRebuild();
    }
    function removeGroup(name) {
        for (let i = history.count - 1; i >= 0; i--)
            if (groupKey(history.get(i).appName) === name) history.remove(i);
        saveTimer.restart();
        scheduleRebuild();
    }

    function toggleCollapse(name) {
        const c = {};
        for (const k in collapsedApps) c[k] = collapsedApps[k];
        if (c[name]) delete c[name]; else c[name] = true;
        collapsedApps = c;
        stateTimer.restart();
        scheduleRebuild();
    }
    function toggleCollapseAll() {
        const c = {};
        if (!allCollapsed) {
            for (let i = 0; i < history.count; i++) c[groupKey(history.get(i).appName)] = true;
        }
        collapsedApps = c;
        stateTimer.restart();
        scheduleRebuild();
    }
    function groupSize(name) {
        let n = 0;
        for (let i = 0; i < history.count; i++)
            if (groupKey(history.get(i).appName) === name) n++;
        return n;
    }
    function makeItemRow(name, hi, total) {
        const e = history.get(hi);
        const key = e.time + "|" + e.summary;
        return {
            rowType: "item", groupName: name,
            summary: e.summary, body: e.body, appName: e.appName,
            appIcon: e.appIcon, image: e.image, time: e.time,
            hIndex: hi, grpCount: total, collapsed: false,
            expanded: expandedSet[key] === true, rowKey: key
        };
    }

    // Scrolls a group's window by `delta` entries. Returns true if it moved.
    // The model is patched in place (one row out, one row in) instead of being
    // rebuilt, so the ListView transitions can animate the movement.
    function scrollGroup(name, delta) {
        const idxs = [];
        for (let i = 0; i < history.count; i++)
            if (groupKey(history.get(i).appName) === name) idxs.push(i);
        const total = idxs.length;
        const maxOff = Math.max(0, total - groupLimit);
        const cur = Math.min(groupOffsets[name] || 0, maxOff);
        const next = Math.max(0, Math.min(maxOff, cur + delta));
        if (next === cur) return false;

        const o = {};
        for (const k in groupOffsets) o[k] = groupOffsets[k];
        o[name] = next;
        groupOffsets = o;

        // fall back to a full rebuild whenever an in-place patch isn't safe
        if (Math.abs(delta) !== 1 || rebuildTimer.running) { scheduleRebuild(); return true; }

        let h = -1;
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            if (r.rowType === "header" && r.groupName === name) { h = i; break; }
        }
        if (h < 0 || rows.get(h).collapsed) { scheduleRebuild(); return true; }

        let pager = h + 1;
        while (pager < rows.count && rows.get(pager).rowType === "item" && rows.get(pager).groupName === name) pager++;
        if (pager >= rows.count || rows.get(pager).rowType !== "pager" || pager - h - 1 !== groupLimit) {
            scheduleRebuild();
            return true;
        }

        animateRows = true;
        animTimer.restart();

        if (delta > 0) {
            rows.remove(h + 1);
            rows.insert(pager - 1, makeItemRow(name, idxs[next + groupLimit - 1], total));
        } else {
            rows.remove(pager - 1);
            rows.insert(h + 1, makeItemRow(name, idxs[next], total));
        }
        rows.setProperty(pager, "summary", (next + 1) + "–" + (next + groupLimit) + " of " + total);
        rows.setProperty(pager, "hIndex", next);
        return true;
    }
    function toggleExpand(rowIndex, key) {
        const s = {};
        for (const k in expandedSet) s[k] = expandedSet[k];
        if (s[key]) delete s[key]; else s[key] = true;
        expandedSet = s;
        rows.setProperty(rowIndex, "expanded", s[key] === true);
    }

    // ---- grouped view model (rebuilt from history) -------------------------------
    ListModel { id: rows }

    Timer {
        id: rebuildTimer
        interval: 20
        onTriggered: root.rebuildRows()
    }
    function scheduleRebuild() { rebuildTimer.restart(); }

    function rebuildRows() {
        rowsAboutToRebuild();
        rows.clear();

        const order = [];
        const groups = {};
        for (let i = 0; i < history.count; i++) {
            const k = groupKey(history.get(i).appName);
            if (!groups[k]) { groups[k] = []; order.push(k); }
            groups[k].push(i);
        }

        let collapsedN = 0;
        for (let g = 0; g < order.length; g++) {
            const name = order[g];
            const idxs = groups[name];
            const first = history.get(idxs[0]);
            const coll = collapsedApps[name] === true;
            if (coll) collapsedN++;

            rows.append({
                rowType: "header", groupName: name,
                summary: first.summary, body: "", appName: first.appName,
                appIcon: first.appIcon, image: "", time: first.time,
                hIndex: -1, grpCount: idxs.length, collapsed: coll,
                expanded: false, rowKey: ""
            });
            if (coll) continue;

            const total = idxs.length;
            const off = Math.max(0, Math.min(groupOffsets[name] || 0, Math.max(0, total - groupLimit)));
            const end = Math.min(total, off + groupLimit);

            for (let j = off; j < end; j++) {
                const e = history.get(idxs[j]);
                const key = e.time + "|" + e.summary;
                rows.append({
                    rowType: "item", groupName: name,
                    summary: e.summary, body: e.body, appName: e.appName,
                    appIcon: e.appIcon, image: e.image, time: e.time,
                    hIndex: idxs[j], grpCount: idxs.length, collapsed: false,
                    expanded: expandedSet[key] === true, rowKey: key
                });
            }

            // pager: only when the group has more entries than the limit
            if (total > groupLimit) {
                rows.append({
                    rowType: "pager", groupName: name,
                    summary: (off + 1) + "–" + end + " of " + total, body: "", appName: "",
                    appIcon: "", image: "", time: 0,
                    hIndex: off, grpCount: total, collapsed: false,
                    expanded: false, rowKey: ""
                });
            }
        }
        groupCount = order.length;
        allCollapsed = order.length > 0 && collapsedN === order.length;
        rowsRebuilt();
    }

    // ---- sound ----------------------------------------------------------------
    // Plays a freedesktop sound-theme file (package: sound-theme-freedesktop) via
    // pipewire/pulse; falls back to libcanberra if the file isn't there.
    function playSound(name) {
        if (!soundEnabled) return;
        Quickshell.execDetached([
            "sh", "-c",
            'f="/usr/share/sounds/freedesktop/stereo/$1.oga"; '
            + 'if [ -f "$f" ]; then pw-play "$f" 2>/dev/null || paplay "$f" 2>/dev/null; '
            + 'else canberra-gtk-play -i "$1" 2>/dev/null; fi',
            "sh", name
        ]);
    }

    function dndBlocks(n) {
        if (!dnd) return false;
        const app = (n.appName || "").toLowerCase();
        if (app === "battery") return false;              // always show battery alerts
        if (n.urgency !== NotificationUrgency.Critical) return true;
        for (let i = 0; i < dndMuteCritical.length; i++)
            if (app.indexOf(dndMuteCritical[i]) >= 0) return true;
        return false;
    }

    function soundFor(n) {
        if (n.appName === "Todo") return "alarm-clock-elapsed";
        if (n.urgency === NotificationUrgency.Critical) return "dialog-warning";
        return "message-new-instant";
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.panelOpen = !root.panelOpen; }
        function open(): void { root.panelOpen = true; }
        function close(): void { root.panelOpen = false; }
        function clear(): void { root.clearHistory(); }
        function dnd(): void { root.toggleDnd(); }
        function isDnd(): bool { return root.dnd; }
        function sound(): void { root.toggleSound(); }
        function collapseAll(): void { root.toggleCollapseAll(); }
    }

    // ---- persisted UI state -------------------------------------------------
    FileView {
        id: stateFile
        path: root.home + "/.config/quickshell/state/notifications-state.json"
        printErrors: false
        // Tiny file, written only on user actions: block so the write is on disk
        // before we return (nothing lost if the session is killed right after).
        blockWrites: true
        onSaveFailed: function (error) { console.warn("Notifications: could not save state: " + error); }
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (typeof s.dnd === "boolean") root.dnd = s.dnd;
                if (typeof s.soundEnabled === "boolean") root.soundEnabled = s.soundEnabled;
                if (typeof s.menuSize === "number") root.menuSize = Math.max(60, Math.min(200, Math.round(s.menuSize)));
                if (typeof s.offsetX === "number") root.offsetX = s.offsetX;
                if (typeof s.offsetY === "number") root.offsetY = s.offsetY;
                if (Array.isArray(s.collapsed)) {
                    const c = {};
                    for (let i = 0; i < s.collapsed.length; i++) c[String(s.collapsed[i])] = true;
                    root.collapsedApps = c;
                    root.scheduleRebuild();
                }
            } catch (e) { console.warn("Notifications: bad state file: " + e); }
            root.stateReady = true;
        }
        onLoadFailed: root.stateReady = true
    }

    // Writes use a temp file + rename, which fails if the directory is missing
    // (and errors were silent). Create the directories first and only write
    // once that has finished.
    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.home + "/.config/quickshell/state", root.home + "/.cache/43pr"]
        running: true
        onExited: root.dirsReady = true
    }

    Timer {
        id: stateTimer
        interval: 200
        onTriggered: {
            // not loaded yet / directories not created yet: try again shortly
            if (!root.stateReady || !root.dirsReady) { stateTimer.restart(); return; }
            const coll = [];
            for (const k in root.collapsedApps) if (root.collapsedApps[k]) coll.push(k);
            stateFile.setText(JSON.stringify({
                dnd: root.dnd,
                soundEnabled: root.soundEnabled,
                menuSize: root.menuSize,
                offsetX: root.offsetX,
                offsetY: root.offsetY,
                collapsed: coll
            }));
        }
    }

    // ---- history ------------------------------------------------------------
    ListModel { id: history }

    FileView {
        id: store
        path: root.home + "/.cache/43pr/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                const arr = JSON.parse(text());
                for (let i = 0; i < arr.length; i++) {
                    const e = arr[i];
                    // normalise so the delegate's required properties always exist
                    history.append({
                        summary: String(e.summary || ""),
                        body: String(e.body || ""),
                        appName: String(e.appName || ""),
                        appIcon: String(e.appIcon || ""),
                        image: String(e.image || ""),
                        time: Number(e.time) || 0
                    });
                }
            } catch (e) { console.warn("Notifications: bad history file: " + e); }
            root.historyReady = true;
            root.scheduleRebuild();
        }
        onLoadFailed: root.historyReady = true
    }
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            if (!root.historyReady) return;
            const out = [];
            for (let i = 0; i < history.count; i++) {
                const e = history.get(i);
                out.push({ summary: e.summary, body: e.body, appName: e.appName, appIcon: e.appIcon, image: e.image, time: e.time });
            }
            store.setText(JSON.stringify(out));
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = !root.dndBlocks(n);
            if (n.tracked) root.playSound(root.soundFor(n));
            if (n.transient) return;

            const img = (n.image && !String(n.image).startsWith("image://")) ? String(n.image) : "";
            // show the newest entries of that app again
            if (root.groupOffsets[root.groupKey(n.appName)]) {
                const o = {};
                for (const k in root.groupOffsets) o[k] = root.groupOffsets[k];
                delete o[root.groupKey(n.appName)];
                root.groupOffsets = o;
            }
            history.insert(0, {
                summary: n.summary || "",
                body: n.body || "",
                appName: n.appName || "",
                appIcon: n.appIcon || "",
                image: img,
                time: Date.now()
            });
            if (history.count > root.maxHistory) history.remove(root.maxHistory, history.count - root.maxHistory);
            saveTimer.restart();
            root.scheduleRebuild();
        }
    }

    // ---- battery alerts (event driven) ----------------------------------------
    property real lastBat: -1
    property bool bat20: false
    property bool bat15: false

    function notifyBat(urgency, icon, title, pct) {
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", urgency, "-i", icon, title, "Battery is at " + Math.round(pct) + "%"]);
    }

    function checkBattery() {
        if (!UPower.displayDevice.ready) return;
        const p = UPower.displayDevice.percentage;

        if (!UPower.onBattery) {
            bat20 = false;
            bat15 = false;
            lastBat = p;
            return;
        }
        if (lastBat < 0) { lastBat = p; return; }

        if (p > 20) bat20 = false;
        if (p > 15) bat15 = false;

        if (!bat20 && lastBat > 20 && p <= 20) { bat20 = true; notifyBat("normal", "battery-caution", "Battery Low", p); }
        if (!bat15 && lastBat > 15 && p <= 15) { bat15 = true; notifyBat("critical", "battery-empty", "Battery Critical", p); }
        lastBat = p;
    }

    Component.onCompleted: {
        checkBattery();
        scheduleRebuild();
    }
    Connections {
        target: UPower.displayDevice
        function onReadyChanged() { root.checkBattery(); }
        function onPercentageChanged() { root.checkBattery(); }
        function onStateChanged() { root.checkBattery(); }
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() { root.checkBattery(); }
    }

    // ---- reusable pieces ------------------------------------------------------
    component Lbl: Text {
        property real ui: 1
        property real sz: 10
        font.pixelSize: Math.round(sz * ui)
        color: Theme.text
        elide: Text.ElideRight
    }

    component Thumb: Rectangle {
        id: th
        property real ui: 1
        property real size: 40
        property string src: ""
        property string glyph: "󰂚"
        width: Math.round(size * ui)
        height: width
        radius: Math.round(8 * ui)
        clip: true
        Image {
            id: im
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // decode at display size (2x for HiDPI) instead of full resolution
            sourceSize: Qt.size(th.width * 2, th.height * 2)
            source: th.src
        }
        Text {
            anchors.centerIn: parent
            visible: im.status !== Image.Ready
            text: th.glyph
            font.family: Theme.iconFont
            font.pixelSize: Math.round(th.size * 0.45 * th.ui)
            color: Theme.text
        }
    }

    component IconBtn: Rectangle {
        id: b
        property real ui: 1
        property real base: 24
        property string icon: ""
        property string tip: ""
        property color tint: Theme.text
        property real rest: 0.08
        property real hot: 0.2
        property bool tipReady: false
        signal clicked()
        width: Math.round(base * ui)
        height: width
        radius: Math.round(base / 3 * ui)
        color: Theme.alpha(tint, area.containsMouse ? hot : rest)

        Text {
            anchors.centerIn: parent
            text: b.icon
            font.family: Theme.iconFont
            font.pixelSize: Math.round(b.base * 0.54 * b.ui)
            color: b.tint
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.clicked()
            onContainsMouseChanged: {
                b.tipReady = false;
                if (containsMouse) tipTimer.restart();
                else tipTimer.stop();
            }
        }
        Timer { id: tipTimer; interval: 400; onTriggered: b.tipReady = true }

        Rectangle {
            visible: b.tipReady && b.tip !== ""
            anchors.top: parent.bottom
            anchors.topMargin: 6
            anchors.right: parent.right
            z: 100
            width: tipText.implicitWidth + Math.round(14 * b.ui)
            height: tipText.implicitHeight + Math.round(8 * b.ui)
            radius: Math.round(7 * b.ui)
            color: Theme.bg
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.15)
            Lbl { id: tipText; anchors.centerIn: parent; ui: b.ui; sz: 9; text: b.tip }
        }
    }

    component SizeBtn: Text {
        id: sb
        signal clicked()
        height: 16
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: Theme.text
        MouseArea { anchors.fill: parent; onClicked: sb.clicked() }
    }

    // ---- the window: only exists while mounted --------------------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win

            // The window can be created with panelOpen already true; bind
            // `reveal` one tick later so the panel still fades in.
            property bool reveal: false

            anchors { top: true; bottom: true; right: true; left: true }
            implicitWidth: root.cardWidth + root.sideGap + 24
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "notifications"
            WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            mask: Region { item: root.panelOpen ? backdrop : stack }

            // Bounds that keep the panel on screen. These only shape what is
            // DISPLAYED (effX/effY); the saved offsets are never rewritten by them.
            readonly property real limMaxX: root.sideGap - root.edgeGap
            readonly property real limMinX: Math.min(limMaxX, root.cardWidth + root.sideGap + root.edgeGap - win.width)
            readonly property real limMinY: root.edgeGap + root.px(14) - root.topGap
            readonly property real limMaxY: Math.max(limMinY, win.height - panel.height - root.edgeGap - root.topGap)
            readonly property bool sized: win.width > 0 && win.height > 0
            readonly property real effX: sized ? Math.max(limMinX, Math.min(limMaxX, root.offsetX)) : root.offsetX
            readonly property real effY: sized ? Math.max(limMinY, Math.min(limMaxY, root.offsetY)) : root.offsetY

            function setSize(v) {
                root.menuSize = Math.max(60, Math.min(200, v));
                stateTimer.restart();
            }

            // Only called while the user is dragging (window is fully sized then).
            function setPosition(x, y) {
                if (!win.sized) return;
                root.offsetX = Math.max(win.limMinX, Math.min(win.limMaxX, x));
                root.offsetY = Math.max(win.limMinY, Math.min(win.limMaxY, y));
            }

            Component.onCompleted: {
                Qt.callLater(function () {
                    win.reveal = Qt.binding(function () { return root.panelOpen; });
                });
            }

            Item { anchors.fill: parent; focus: root.panelOpen; Keys.onEscapePressed: root.panelOpen = false }

            Item {
                id: backdrop
                anchors.fill: parent
                visible: root.panelOpen
                MouseArea {
                    anchors.fill: parent
                    enabled: root.panelOpen
                    onClicked: root.panelOpen = false
                }
            }

            // ======================= TOASTS ====================================
            Column {
                id: stack
                visible: !root.panelOpen
                anchors {
                    top: parent.top
                    topMargin: root.topGap + root.offsetY
                    right: parent.right
                    rightMargin: root.sideGap - root.offsetX
                }
                spacing: root.px(8)

                Repeater {
                    model: server.trackedNotifications

                    delegate: Item {
                        id: wrapper
                        required property var modelData
                        property bool shown: false
                        property bool leaving: false
                        property bool wasExpired: false
                        property bool expanded: false
                        property bool copied: false
                        readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                        width: root.cardWidth
                        height: card.height

                        function close(expired) {
                            if (leaving) return;
                            wasExpired = expired;
                            leaving = true;
                            shown = false;
                            gone.start();
                        }
                        Component.onCompleted: shown = true

                        Timer {
                            id: gone
                            interval: 220
                            onTriggered: {
                                const n = wrapper.modelData;
                                try {
                                    if (wrapper.wasExpired) n.expire(); else n.dismiss();
                                    // belt and braces: make sure it really leaves the tracked list
                                    if (n) n.tracked = false;
                                } catch (e) { }
                            }
                        }

                        Timer { id: copiedTimer; interval: 900; onTriggered: wrapper.copied = false }

                        // a replaced/updated notification gets a fresh lifetime
                        Connections {
                            target: wrapper.modelData
                            function onSummaryChanged() { progAnim.restart(); }
                            function onBodyChanged() { progAnim.restart(); }
                        }

                        Rectangle {
                            id: card
                            width: parent.width
                            height: Math.max(root.px(64), content.implicitHeight + root.px(24))
                            radius: root.px(16)
                            color: Theme.bg
                            border.width: wrapper.critical ? 1 : 0
                            border.color: Theme.danger
                            opacity: wrapper.shown ? 1 : 0

                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                            HoverHandler { id: hh }

                            // left click: dismiss, right click: copy
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        root.copyText(wrapper.modelData.summary, wrapper.modelData.body);
                                        wrapper.copied = true;
                                        copiedTimer.restart();
                                    } else {
                                        wrapper.close(false);
                                    }
                                }
                            }

                            // lifetime bar. It IS the timer: it pauses while the
                            // card is hovered or expanded, and closes the toast
                            // when it runs out.
                            Rectangle {
                                id: bar
                                x: root.px(16)
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: root.px(5)
                                height: 2
                                radius: 1
                                width: card.width - root.px(32)
                                color: wrapper.critical ? Theme.danger : Theme.alpha(Theme.text, 0.3)
                                opacity: wrapper.expanded ? 0.15 : 1

                                NumberAnimation on width {
                                    id: progAnim
                                    from: card.width - root.px(32)
                                    to: 0
                                    duration: wrapper.modelData.expireTimeout > 0
                                              ? wrapper.modelData.expireTimeout * 1000
                                              : (wrapper.critical ? root.criticalTimeout : root.normalTimeout)
                                    running: !wrapper.leaving
                                    paused: hh.hovered || wrapper.expanded
                                    onFinished: wrapper.close(true)
                                }
                            }

                            Row {
                                id: content
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: root.px(10) }
                                spacing: root.px(10)

                                Thumb {
                                    id: thumb
                                    ui: root.ui
                                    color: Theme.bg
                                    src: root.resolveIcon(wrapper.modelData.image, wrapper.modelData.appIcon,
                                                          wrapper.modelData.appName, wrapper.modelData.summary)
                                    glyph: root.glyphFor(wrapper.modelData.appName, wrapper.modelData.summary)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: root.px(3)
                                    width: parent.width - thumb.width - btnCol.width - parent.spacing * 2

                                    Lbl {
                                        ui: root.ui
                                        sz: 12
                                        font.bold: true
                                        width: parent.width
                                        text: wrapper.modelData.summary
                                        wrapMode: wrapper.expanded ? Text.WordWrap : Text.NoWrap
                                    }
                                    Lbl {
                                        ui: root.ui
                                        width: parent.width
                                        visible: text !== ""
                                        text: wrapper.modelData.body
                                        color: Theme.textDim
                                        textFormat: Text.PlainText
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: wrapper.expanded ? 200 : 3
                                    }
                                    Lbl { ui: root.ui; sz: 9; width: parent.width; text: wrapper.modelData.appName; color: Theme.textDim; opacity: 0.7 }

                                    Row {
                                        visible: wrapper.modelData.actions.length > 0
                                        spacing: root.px(6)

                                        Repeater {
                                            model: wrapper.modelData.actions
                                            delegate: Rectangle {
                                                id: actBtn
                                                required property var modelData
                                                height: root.px(20)
                                                width: label.implicitWidth + root.px(14)
                                                radius: root.px(7)
                                                color: Theme.alpha(Theme.text, btn.containsMouse ? 0.22 : 0.1)

                                                Lbl { id: label; anchors.centerIn: parent; ui: root.ui; sz: 9; text: actBtn.modelData.text }
                                                MouseArea {
                                                    id: btn
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: { actBtn.modelData.invoke(); wrapper.close(false); }
                                                }
                                            }
                                        }
                                    }
                                }

                                Column {
                                    id: btnCol
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: root.px(4)
                                    opacity: hh.hovered ? 1 : 0.45
                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    IconBtn {
                                        ui: root.ui
                                        base: 22
                                        icon: wrapper.copied ? root.icCheck : root.icCopy
                                        tip: "Copy"
                                        onClicked: {
                                            root.copyText(wrapper.modelData.summary, wrapper.modelData.body);
                                            wrapper.copied = true;
                                            copiedTimer.restart();
                                        }
                                    }
                                    IconBtn {
                                        ui: root.ui
                                        base: 22
                                        visible: root.canExpand(wrapper.modelData.body)
                                        icon: wrapper.expanded ? root.icUp : root.icDown
                                        tip: wrapper.expanded ? "Collapse" : "Expand"
                                        onClicked: wrapper.expanded = !wrapper.expanded
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ======================= PANEL =====================================
            Item {
                id: dragHandle
                visible: panel.visible
                opacity: panel.opacity
                height: root.px(14)
                anchors { bottom: panel.top; left: panel.left; right: panel.right }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.px(36)
                    height: root.px(4)
                    radius: height / 2
                    color: Theme.text
                    opacity: (dragArea.containsMouse || root.dragging) ? 0.35 : 0.1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: root.panelOpen
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property real pressX: 0
                    property real pressY: 0
                    property real startX: 0
                    property real startY: 0

                    onPressed: function (mouse) {
                        const p = dragArea.mapToItem(backdrop, mouse.x, mouse.y);
                        pressX = p.x;
                        pressY = p.y;
                        startX = win.effX;   // start from where the panel is actually shown
                        startY = win.effY;
                        root.dragging = true;
                    }

                    onPositionChanged: function (mouse) {
                        if (!root.dragging) return;
                        const p = dragArea.mapToItem(backdrop, mouse.x, mouse.y);
                        win.setPosition(startX + (p.x - pressX), startY + (p.y - pressY));
                    }

                    onReleased: {
                        if (!root.dragging) return;
                        root.dragging = false;
                        stateTimer.restart();
                    }

                    onCanceled: {
                        if (!root.dragging) return;
                        root.dragging = false;
                        stateTimer.restart();
                    }
                }
            }

            Rectangle {
                id: panel
                width: root.cardWidth
                height: panelCol.height + root.px(28)
                radius: root.px(20)
                color: Theme.bg
                anchors {
                    top: parent.top
                    topMargin: root.topGap + win.effY
                    right: parent.right
                    rightMargin: root.sideGap - win.effX
                }
                opacity: win.reveal ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                MouseArea { anchors.fill: parent }

                Column {
                    id: panelCol
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.px(14) }
                    spacing: root.px(10)

                    Item {
                        width: parent.width
                        height: root.px(24)
                        z: 10

                        Lbl {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            ui: root.ui
                            sz: 13
                            font.bold: true
                            text: "Notifications" + (history.count > 0 ? "  " + history.count : "")
                        }

                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: root.px(4)

                            IconBtn {
                                ui: root.ui
                                icon: root.soundEnabled ? "󰕾" : "󰖁"
                                tip: "Sound: " + (root.soundEnabled ? "ON" : "OFF")
                                rest: root.soundEnabled ? 0.08 : 0.3
                                onClicked: root.toggleSound()
                            }
                            IconBtn {
                                ui: root.ui
                                icon: root.dnd ? "󰂛" : "󰂚"
                                tip: "Do Not Disturb: " + (root.dnd ? "ON" : "OFF")
                                rest: root.dnd ? 0.3 : 0.08
                                onClicked: root.toggleDnd()
                            }
                            IconBtn {
                                ui: root.ui
                                visible: root.groupCount > 1
                                icon: root.allCollapsed ? root.icDown : root.icUp
                                tip: root.allCollapsed ? "Expand all groups" : "Collapse all groups"
                                onClicked: root.toggleCollapseAll()
                            }
                            IconBtn {
                                ui: root.ui
                                icon: "󰆴"
                                tip: "Clear all"
                                tint: Theme.danger
                                rest: 0.1
                                hot: 0.25
                                visible: history.count > 0
                                onClicked: root.clearHistory()
                            }
                            IconBtn { ui: root.ui; icon: "󰅖"; tip: "Close"; onClicked: root.panelOpen = false }
                        }
                    }

                    Lbl {
                        visible: history.count === 0
                        ui: root.ui
                        sz: 11
                        width: parent.width
                        height: root.px(40)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "No notifications"
                        color: Theme.textDim
                    }

                    ListView {
                        id: list
                        visible: history.count > 0
                        width: parent.width
                        height: Math.min(contentHeight, win.height - root.topGap - root.px(120))
                        clip: true
                        spacing: root.px(6)
                        model: rows
                        boundsBehavior: Flickable.StopAtBounds

                        // keep the scroll position when the grouped model is rebuilt
                        property real keepY: 0

        // Smooth scrolling inside a group: the leaving row fades out, the
        // entering row fades in, everything else glides into place. Only
        // active during a scroll so normal rebuilds don't flash.
        add: root.animateRows ? addTrans : null
        remove: root.animateRows ? removeTrans : null
        displaced: root.animateRows ? displacedTrans : null
        Transition {
            id: addTrans
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutCubic }
            }
        }
        Transition {
            id: removeTrans
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 160; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; to: 0.94; duration: 160; easing.type: Easing.InCubic }
            }
        }
        Transition {
            id: displacedTrans
            NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
        }
                        Connections {
                            target: root
                            function onRowsAboutToRebuild() { list.keepY = list.contentY; }
                            function onRowsRebuilt() {
                                Qt.callLater(function () {
                                    list.contentY = Math.max(0, Math.min(list.keepY, list.contentHeight - list.height));
                                });
                            }
                        }

                        delegate: Item {
                            id: rowItem
                            required property int index
                            required property string rowType
                            required property string groupName
                            required property string summary
                            required property string body
                            required property string appName
                            required property string appIcon
                            required property string image
                            required property real time
                            required property int hIndex
                            required property int grpCount
                            required property bool collapsed
                            required property bool expanded
                            required property string rowKey

                            readonly property bool isHeader: rowType === "header"
                            readonly property bool isPager: rowType === "pager"
                            property bool copied: false
                            readonly property real pad: (isHeader && index > 0) ? root.px(6) : 0

                            width: list.width
                            height: pad + (isHeader ? headerBox.height : (isPager ? pagerBox.height : itemBox.height))

                            Timer { id: copiedTimer; interval: 900; onTriggered: rowItem.copied = false }

                            // ---------- group header ----------
                            Rectangle {
                                id: headerBox
                                visible: rowItem.isHeader
                                y: rowItem.pad
                                width: parent.width
                                height: root.px(30)
                                radius: root.px(10)
                                color: Theme.alpha(Theme.text, hdrArea.containsMouse ? 0.1 : 0.04)

                                MouseArea {
                                    id: hdrArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.toggleCollapse(rowItem.groupName)
                                }

                                Text {
                                    id: chev
                                    anchors { left: parent.left; leftMargin: root.px(8); verticalCenter: parent.verticalCenter }
                                    text: rowItem.collapsed ? root.icRight : root.icDown
                                    font.family: Theme.iconFont
                                    font.pixelSize: root.px(13)
                                    color: Theme.textDim
                                }
                                Thumb {
                                    id: hThumb
                                    ui: root.ui
                                    size: 18
                                    color: "transparent"
                                    src: root.resolveIcon("", rowItem.appIcon, rowItem.appName, rowItem.summary)
                                    glyph: root.glyphFor(rowItem.appName, rowItem.summary)
                                    anchors { left: chev.right; leftMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                }
                                Lbl {
                                    id: hName
                                    anchors { left: hThumb.right; leftMargin: root.px(7); verticalCenter: parent.verticalCenter }
                                    ui: root.ui
                                    sz: 11
                                    font.bold: true
                                    text: rowItem.groupName
                                }
                                Rectangle {
                                    id: badge
                                    anchors { left: hName.right; leftMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                    width: Math.max(height, badgeTxt.implicitWidth + root.px(10))
                                    height: root.px(16)
                                    radius: height / 2
                                    color: Theme.alpha(Theme.text, 0.12)
                                    Lbl { id: badgeTxt; anchors.centerIn: parent; ui: root.ui; sz: 9; text: rowItem.grpCount }
                                }
                                // latest message as a preview while collapsed
                                Lbl {
                                    visible: rowItem.collapsed
                                    anchors {
                                        left: badge.right; leftMargin: root.px(8)
                                        right: hClear.left; rightMargin: root.px(6)
                                        verticalCenter: parent.verticalCenter
                                    }
                                    ui: root.ui
                                    sz: 9
                                    color: Theme.textDim
                                    text: rowItem.summary
                                }
                                IconBtn {
                                    id: hClear
                                    ui: root.ui
                                    base: 20
                                    icon: "󰆴"
                                    tip: "Clear " + rowItem.groupName
                                    tint: Theme.danger
                                    rest: 0.0
                                    hot: 0.25
                                    anchors { right: parent.right; rightMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                    onClicked: root.removeGroup(rowItem.groupName)
                                }
                            }

                            // ---------- pager (scroll through a long group) ----------
                            Item {
                                id: pagerBox
                                visible: rowItem.isPager
                                x: root.px(6)
                                width: parent.width - root.px(6)
                                height: root.px(22)

                                Lbl {
                                    anchors { left: parent.left; leftMargin: root.px(10); verticalCenter: parent.verticalCenter }
                                    ui: root.ui
                                    sz: 9
                                    color: Theme.textDim
                                    text: rowItem.summary + "  ·  scroll for more"
                                }
                                Row {
                                    anchors { right: parent.right; rightMargin: root.px(6); verticalCenter: parent.verticalCenter }
                                    spacing: root.px(4)
                                    IconBtn {
                                        ui: root.ui
                                        base: 18
                                        rest: 0.06
                                        icon: root.icUp
                                        tip: "Newer"
                                        opacity: rowItem.hIndex > 0 ? 1 : 0.3
                                        onClicked: root.scrollGroup(rowItem.groupName, -1)
                                    }
                                    IconBtn {
                                        ui: root.ui
                                        base: 18
                                        rest: 0.06
                                        icon: root.icDown
                                        tip: "Older"
                                        opacity: rowItem.hIndex + root.groupLimit < rowItem.grpCount ? 1 : 0.3
                                        onClicked: root.scrollGroup(rowItem.groupName, 1)
                                    }
                                }
                            }

                            // ---------- notification entry ----------
                            Rectangle {
                                id: itemBox
                                visible: rowItem.rowType === "item"
                                x: root.px(6)
                                width: parent.width - root.px(6)
                                height: Math.max(root.px(52), textCol.implicitHeight + root.px(20))
                                radius: root.px(12)
                                color: Theme.alpha(Theme.text, rowItem.copied ? 0.2 : 0.06)

                                // wheel scrolls through the group's entries; at either
                                // end the event is passed on so the whole list scrolls
                                WheelHandler {
                                    enabled: rowItem.grpCount > root.groupLimit
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: event => {
                                        const d = event.angleDelta.y;
                                        if (d === 0) { event.accepted = false; return; }
                                        event.accepted = root.scrollGroup(rowItem.groupName, d < 0 ? 1 : -1);
                                    }
                                }

                                Thumb {
                                    id: eThumb
                                    ui: root.ui
                                    size: 30
                                    color: Theme.alpha(Theme.text, 0.1)
                                    src: root.resolveIcon(rowItem.image, rowItem.appIcon, rowItem.appName, rowItem.summary)
                                    glyph: root.glyphFor(rowItem.appName, rowItem.summary)
                                    anchors { left: parent.left; leftMargin: root.px(10); top: parent.top; topMargin: root.px(10) }
                                }

                                Column {
                                    id: textCol
                                    anchors {
                                        left: eThumb.right; leftMargin: root.px(10)
                                        right: parent.right; rightMargin: root.px(8)
                                        top: parent.top; topMargin: root.px(10)
                                    }
                                    spacing: root.px(3)

                                    // title line + action buttons
                                    Item {
                                        width: parent.width
                                        height: Math.max(root.px(20), eTitle.implicitHeight)

                                        Lbl {
                                            id: eTitle
                                            anchors { left: parent.left; top: parent.top }
                                            width: parent.width - eBtns.width - root.px(6)
                                            ui: root.ui
                                            sz: 11
                                            font.bold: true
                                            text: rowItem.summary
                                            wrapMode: rowItem.expanded ? Text.WordWrap : Text.NoWrap
                                        }
                                        Row {
                                            id: eBtns
                                            anchors { right: parent.right; top: parent.top }
                                            spacing: root.px(2)

                                            IconBtn {
                                                ui: root.ui
                                                base: 20
                                                rest: 0.0
                                                visible: root.canExpand(rowItem.body)
                                                icon: rowItem.expanded ? root.icUp : root.icDown
                                                tip: rowItem.expanded ? "Collapse" : "Expand"
                                                onClicked: root.toggleExpand(rowItem.index, rowItem.rowKey)
                                            }
                                            IconBtn {
                                                ui: root.ui
                                                base: 20
                                                rest: 0.0
                                                icon: rowItem.copied ? root.icCheck : root.icCopy
                                                tip: "Copy"
                                                onClicked: {
                                                    root.copyText(rowItem.summary, rowItem.body);
                                                    rowItem.copied = true;
                                                    copiedTimer.restart();
                                                }
                                            }
                                            IconBtn {
                                                ui: root.ui
                                                base: 20
                                                rest: 0.0
                                                icon: "󰅖"
                                                tip: "Remove"
                                                tint: Theme.danger
                                                hot: 0.25
                                                onClicked: root.removeHistory(rowItem.hIndex)
                                            }
                                        }
                                    }

                                    // collapsed body (2 lines)
                                    Lbl {
                                        ui: root.ui
                                        width: parent.width
                                        visible: !rowItem.expanded && text !== ""
                                        text: rowItem.body
                                        color: Theme.textDim
                                        textFormat: Text.PlainText
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                    }

                                    // expanded body: selectable text. Selecting copies it
                                    // to the clipboard (Ctrl+C also works).
                                    TextEdit {
                                        id: bodyEdit
                                        visible: rowItem.expanded && rowItem.body !== ""
                                        width: parent.width
                                        height: visible ? implicitHeight : 0
                                        readOnly: true
                                        selectByMouse: true
                                        persistentSelection: true
                                        wrapMode: TextEdit.Wrap
                                        textFormat: TextEdit.PlainText
                                        text: rowItem.body
                                        color: Theme.text
                                        selectionColor: Theme.alpha(Theme.text, 0.3)
                                        selectedTextColor: Theme.text
                                        font.pixelSize: root.px(10)
                                        Keys.onEscapePressed: root.panelOpen = false
                                        onSelectedTextChanged: selTimer.restart()

                                        Timer {
                                            id: selTimer
                                            interval: 450
                                            onTriggered: {
                                                if (bodyEdit.selectedText !== "") {
                                                    root.copyRaw(bodyEdit.selectedText);
                                                    rowItem.copied = true;
                                                    copiedTimer.restart();
                                                }
                                            }
                                        }
                                    }

                                    Lbl {
                                        ui: root.ui
                                        sz: 9
                                        width: parent.width
                                        color: Theme.textDim
                                        opacity: 0.7
                                        text: (rowItem.appName !== "" ? rowItem.appName + " · " : "") + root.fmtTime(rowItem.time)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: sizeRow
                anchors { top: panel.bottom; topMargin: 6; left: panel.left }
                spacing: 2
                width: root.panelOpen ? implicitWidth : 0
                height: root.panelOpen ? implicitHeight : 0
                visible: root.panelOpen
                opacity: sizeHover.hovered ? 0.9 : 0.18

                Behavior on opacity { NumberAnimation { duration: 150 } }
                HoverHandler { id: sizeHover }

                SizeBtn { text: "−"; width: 16; font.pixelSize: 12; onClicked: win.setSize(root.menuSize - 10) }
                SizeBtn { text: "+"; width: 16; font.pixelSize: 12; onClicked: win.setSize(root.menuSize + 10) }
                SizeBtn {
                    text: "↺"
                    width: 16
                    font.pixelSize: 12
                    visible: root.movedFromDefault
                    onClicked: root.resetPosition()
                }
            }
        }
    }
}