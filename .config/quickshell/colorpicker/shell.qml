import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "ColorUtil.js" as CU

ShellRoot {
    id: root

    // ───────── Configuration ─────────
    readonly property bool swapped: hist.swapped
    readonly property string leftClick: swapped ? "copy-close" : "copy-edit"
    readonly property string middleClick: swapped ? "copy-edit" : "copy-close"
    readonly property string rightClick: "cancel"
    readonly property int historyLimit: 20
    property string copyFormat: "hex"          // hex | rgb | hsl  (Tab cycles while picking)

    // ───────── State ─────────
    property string mode: "idle"               // idle | capturing | picking | editing
    property var picked: ({ r: 0, g: 0, b: 0 })
    property string curScreen: ""
    property string focusScreen: ""
    property real mx: 0
    property real my: 0
    property int zoomIndex: 3
    readonly property var zoomLevels: [41, 31, 21, 15, 11, 9, 7, 5]   // source pixels across the loupe
    readonly property var history: hist.items

    // ───────── Triggers ─────────
    // Start picking as soon as the process launches (the keybind runs `qs -n -p ...`).
    // The short delay lets Hyprland IPC connect so focusedMonitor is known.
    Timer {
        interval: 100
        running: true
        onTriggered: root.start()
    }

    GlobalShortcut {
        appid: "colorpicker"
        name: "pick"
        description: "Start the color picker"
        onPressed: root.start()
    }
    IpcHandler {
        target: "colorpicker"
        function toggle(): void { root.mode === "idle" ? root.start() : root.stop(); }
        function start(): void { root.start(); }
    }

    // ───────── Logic ─────────
    function screenByName(n) {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === n) return Quickshell.screens[i];
        return Quickshell.screens[0];
    }

    function start() {
        if (mode !== "idle") return;
        var fm = Hyprland.focusedMonitor;
        focusScreen = curScreen = fm ? fm.name : Quickshell.screens[0].name;
        var cmds = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var n = Quickshell.screens[i].name;
            cmds.push("grim -l 0 -o '" + n + "' '/tmp/qs-colorpicker-" + n + ".png'");
        }
        capture.command = ["sh", "-c", cmds.join(" & ") + " & wait"];
        mode = "capturing";
        capture.running = true;
    }

    // Close the picker and exit the process (nothing stays in the background)
    function stop() { mode = "idle"; Qt.quit(); }

    // Restart a pick without exiting the process
    function again() { mode = "idle"; start(); }

    function copyText(t) { Quickshell.execDetached(["wl-copy", t]); }

    function act(kind) {
        if (kind === "cancel") { stop(); return; }
        copyText(CU.format(picked, copyFormat));
        pushHistory(CU.hex(picked));
        if (kind === "copy-edit") mode = "editing"; else stop();
    }

    function pushHistory(h) {
        var a = [h];
        for (var i = 0; i < hist.items.length && a.length < historyLimit; i++)
            if (hist.items[i] !== h) a.push(hist.items[i]);
        hist.items = a;
        store.writeAdapter();
    }

    function clearHistory() { hist.items = []; store.writeAdapter(); }
    function toggleSwap() { hist.swapped = !hist.swapped; store.writeAdapter(); }

    function zoomIn()  { zoomIndex = Math.min(zoomLevels.length - 1, zoomIndex + 1); }
    function zoomOut() { zoomIndex = Math.max(0, zoomIndex - 1); }
    function cycleFormat() {
        var f = ["hex", "rgb", "hsl"];
        copyFormat = f[(f.indexOf(copyFormat) + 1) % 3];
    }

    // Move the real pointer by (dx, dy) logical pixels (keyboard fine-positioning)
    function nudge(dx, dy) {
        var s = screenByName(curScreen);
        var nx = Math.max(0, Math.min(s.width - 1, Math.floor(mx) + dx));
        var ny = Math.max(0, Math.min(s.height - 1, Math.floor(my) + dy));
        // update our own position so the loupe/sampler follow immediately,
        // and repeated presses accumulate
        mx = nx;
        my = ny;
        // also move the real cursor so it stays under the loupe
        Quickshell.execDetached(["hyprctl", "dispatch",
            "hl.dsp.cursor.move({ x = " + Math.round(s.x + nx) + ", y = " + Math.round(s.y + ny) + " })"]);
    }

    // ───────── Plumbing ─────────
    Process {
        id: capture
        onExited: (code, status) => {
            if (code === 0) root.mode = "picking";
            else {
                Quickshell.execDetached(["notify-send", "Color Picker", "Screen capture failed (is grim installed?)"]);
                root.stop();
            }
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("colorpicker-history.json")
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        onLoadFailed: error => writeAdapter()
        adapter: JsonAdapter {
            id: hist
            property list<string> items: []
            property bool swapped: false
        }
    }

    Variants {
        model: Quickshell.screens
        PickerOverlay {
            required property var modelData
            screen: modelData
            ctl: root
        }
    }

    EditorWindow { ctl: root }
}