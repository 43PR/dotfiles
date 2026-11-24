import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Keeps a monitor you disabled in the Display page off, but only while another
// monitor is actually available (Windows-style):
//   - external connected    -> monitors marked disabled in display.json are switched off
//   - external gone/off     -> they are switched back on, so you are never left with no screen
// The saved "disabled" choice is never changed here, so plugging the external monitor
// back in turns the laptop panel off again.
// Event driven: runs only at startup and when Hyprland adds/removes a monitor.
Scope {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/display.json"

    function evalLine(lua) { return "hyprctl eval '" + lua + "'" }

    function check() {
        if (!listProc.running) listProc.running = true
        else recheck.restart()
    }

    Process {
        id: listProc
        // saved display state, a separator, then every monitor Hyprland knows (disabled ones too)
        command: ["sh", "-c",
            "cat \"$1\" 2>/dev/null || echo '{}'; echo; echo '@@SPLIT@@'; hyprctl monitors all -j",
            "sh", root.statePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("@@SPLIT@@")
                if (parts.length < 2) return

                let saved = {}
                try { saved = JSON.parse(parts[0]).monitors || {} } catch (e) {}

                let list = []
                try { list = JSON.parse(parts[1]) } catch (e) { return }

                const off = {}
                Object.keys(saved).forEach(n => {
                    if (saved[n] && saved[n].disabled === true) off[n] = true
                })
                if (Object.keys(off).length === 0) return

                // monitors that are not meant to be off and are really on
                const restActive = list.filter(m => !off[m.name] && !m.disabled)

                const cmds = []
                for (let i = 0; i < list.length; i++) {
                    const m = list[i]
                    if (!off[m.name]) continue

                    if (restActive.length > 0 && !m.disabled) {
                        cmds.push(root.evalLine("hl.monitor({output=\"" + m.name + "\",disabled=true})"))
                    } else if (restActive.length === 0 && m.disabled) {
                        const e = saved[m.name] || {}
                        const mode = typeof e.mode === "string" ? e.mode : "preferred"
                        const scale = typeof e.scale === "number" ? e.scale : 1
                        const transform = typeof e.transform === "number" ? e.transform : 0
                        cmds.push(root.evalLine("hl.monitor({output=\"" + m.name + "\",mode=\"" + mode
                            + "\",position=\"auto\",scale=" + scale + ",transform=" + transform + ",disabled=false})"))
                    }
                }
                if (cmds.length > 0)
                    Quickshell.execDetached(["sh", "-c", cmds.join("; ")])
            }
        }
    }

    // Debounce: a plug/unplug fires several events in a row.
    Timer { id: recheck; interval: 1000; onTriggered: root.check() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/^monitor(added|removed)/.test(event.name))
                recheck.restart()
        }
    }

    // First check shortly after the shell starts (monitors are up by then).
    Timer { interval: 1500; running: true; onTriggered: root.check() }
}
