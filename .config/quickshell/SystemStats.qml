pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared system stats (CPU, memory, GPU, temperatures, network).
//
// ONE set of files / processes / timers for the whole shell. The bar and the
// settings pages read the same values, so they can never disagree and the
// system is only polled once, no matter how many places show the numbers.
//
// Nothing is polled unless somebody asks for it. Consumers declare what they
// need with a StatsSubscription; when the last subscriber of a key goes away
// (module turned off, page hidden, ...) the polling for that key stops.
//
//   StatsSubscription { active: root.barVisible; keys: ["cpu", "gpu"] }
//
// Keys: "cpu"  CPU usage
//       "mem"  memory usage
//       "gpu"  GPU usage (+ GPU name probe)
//       "temp" CPU / GPU temperatures
//       "net"  network speed and totals
//       "info" one-shot hardware info (CPU name, GPU name, RAM speed)
Singleton {
    id: root

    readonly property int historyLength: 60

    // ── CPU ───────────────────────────────────────────────────
    property real cpuUsage: 0                  // 0..100
    property var cpuHistory: []
    property string cpuName: "Loading..."      // needs "info"
    property int cpuTempSensors: -1            // from `sensors`
    property int cpuTempProbe: -1              // from sysfs (works without lm_sensors)
    readonly property int cpuTemp: cpuTempSensors >= 0 ? cpuTempSensors : cpuTempProbe   // -1 = unavailable

    // ── Memory ────────────────────────────────────────────────
    property real memPercent: 0                // 0..100
    property real memUsedKb: 0
    property real memTotalKb: 0
    readonly property real memUsedG: memUsedKb / 1048576
    readonly property real memTotalG: memTotalKb / 1048576
    property var memHistory: []
    property string ramSpeed: "Loading..."     // needs "info" (+ sudoers rule for dmidecode)

    // ── GPU ───────────────────────────────────────────────────
    property int gpuUsage: 0                   // smoothed, 0..100
    property bool gpuHasUsage: false
    property var gpuHistory: []
    property string gpuName: "Loading..."      // needs "info"
    property int gpuTempProbe: -1              // nvidia-smi / sysfs hwmon
    property int gpuTempSensors: -1            // fallback from `sensors`
    // GPUs without a sensor of their own (e.g. Intel iGPUs) stay at -1.
    readonly property int gpuTemp: gpuTempProbe >= 0 ? gpuTempProbe : gpuTempSensors

    // ── Network (bytes / second, bytes) ───────────────────────
    property real netDown: 0
    property real netUp: 0
    property real netTotalDown: 0
    property real netTotalUp: 0
    property var netDownHistory: []
    property var netUpHistory: []

    // ── Subscriptions ─────────────────────────────────────────
    property var _need: ({ cpu: 0, mem: 0, gpu: 0, temp: 0, net: 0, info: 0 })
    property int _fast: 0                      // subscribers that want 1 s updates (live graphs)
    property bool _infoStarted: false

    function acquire(keys, fast) {
        const n = Object.assign({}, _need);
        for (const k of keys) {
            if (n[k] === undefined) continue;
            if (n[k] === 0) _firstUser(k);
            n[k]++;
        }
        _need = n;
        if (fast) _fast++;
    }

    function release(keys, fast) {
        const n = Object.assign({}, _need);
        for (const k of keys)
            if (n[k] !== undefined) n[k] = Math.max(0, n[k] - 1);
        _need = n;
        if (fast) _fast = Math.max(0, _fast - 1);
    }

    // Restart the delta-based readings so the first sample after a pause isn't an average over the pause.
    function _firstUser(k) {
        if (k === "cpu") { _prevTotal = 0; _prevIdle = 0; }
        else if (k === "net") _netPrev = null;
        else if (k === "gpu") _gpuAvg = -1;
        else if (k === "info") _loadInfo();
    }

    function _push(arr, v) { return arr.concat([v]).slice(-historyLength); }
    function _run(proc) { if (!proc.running) proc.running = true; }

    // ── CPU usage ─────────────────────────────────────────────
    property real _prevTotal: 0
    property real _prevIdle: 0

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            // user nice system idle iowait irq softirq steal
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            const dT = total - root._prevTotal, dI = idle - root._prevIdle;
            if (root._prevTotal > 0 && dT > 0) {
                const v = Math.max(0, Math.min(100, 100 * (dT - dI) / dT));
                root.cpuUsage = v;
                if (root._need.cpu > 0) root.cpuHistory = root._push(root.cpuHistory, v);
            }
            root._prevTotal = total;
            root._prevIdle = idle;
        }
    }

    // ── Memory ────────────────────────────────────────────────
    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => Number((t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")) || [])[1]);
            const total = kb("MemTotal"), used = total - kb("MemAvailable");
            if (!(total > 0) || isNaN(used)) return;
            root.memTotalKb = total;
            root.memUsedKb = used;
            root.memPercent = 100 * used / total;
            if (root._need.mem > 0) root.memHistory = root._push(root.memHistory, root.memPercent);
        }
    }

    // ── Network ───────────────────────────────────────────────
    property var _netPrev: null

    // Sums rx/tx over all physical-looking interfaces (loopback and
    // container / virtual bridges are skipped).
    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            const lines = text().split("\n");
            let rx = 0, tx = 0;
            for (let i = 2; i < lines.length; i++) {
                const c = lines[i].indexOf(":");
                if (c < 0) continue;
                if (/^(lo|veth|docker|br-|virbr)/.test(lines[i].substring(0, c).trim())) continue;
                const f = lines[i].substring(c + 1).trim().split(/\s+/);
                rx += Number(f[0] || 0);
                tx += Number(f[8] || 0);
            }

            const now = Date.now();
            const p = root._netPrev;
            if (p && now > p.t) {
                const dt = (now - p.t) / 1000;
                root.netDown = Math.max(0, (rx - p.rx) / dt);
                root.netUp = Math.max(0, (tx - p.tx) / dt);
                root.netDownHistory = root._push(root.netDownHistory, root.netDown);
                root.netUpHistory = root._push(root.netUpHistory, root.netUp);
            }
            root.netTotalDown = rx;
            root.netTotalUp = tx;
            root._netPrev = { t: now, rx: rx, tx: tx };
        }
    }

    // ── GPU / temperatures ────────────────────────────────────
    // Vendor-agnostic, no root needed. Prints "<gpu usage%> <gpu tempC> <cpu tempC>";
    // a field is "-" when unavailable.
    //   1. NVIDIA  : nvidia-smi
    //   2. AMD     : sysfs gpu_busy_percent (largest-VRAM card wins)
    //   3. Intel   : intel_gpu_top (only if permitted, 4 s timeout)
    //   4. Intel/other fallback: GPU clock estimate (act_freq / max_freq)
    // GPU temperature: nvidia-smi, else any DRM card hwmon temp, else `sensors`.
    // CPU temperature: sysfs hwmon / thermal zones, else `sensors`.
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

# CPU temperature straight from sysfs (works even without lm_sensors)
c=-
for h in /sys/class/hwmon/hwmon*; do
  n=$(cat "$h/name" 2>/dev/null)
  case "$n" in
    coretemp|k10temp|zenpower|cpu_thermal)
      r=$(cat "$h/temp1_input" 2>/dev/null)
      if isnum "$r"; then c=$(( r / 1000 )); break; fi
      ;;
  esac
done
if [ "$c" = "-" ]; then
  for z in /sys/class/thermal/thermal_zone*; do
    case "$(cat "$z/type" 2>/dev/null)" in
      x86_pkg_temp|cpu*|soc*)
        r=$(cat "$z/temp" 2>/dev/null)
        if isnum "$r"; then c=$(( r / 1000 )); break; fi
        ;;
    esac
  done
fi

echo "$u $t $c"
`

    property real _gpuAvg: -1

    function updateGpuFromProbe(out) {
        const p = out.trim().split(/\s+/);
        const u = parseFloat(p[0]), t = parseFloat(p[1]), c = parseFloat(p[2]);
        gpuHasUsage = !isNaN(u);
        if (gpuHasUsage) {
            const v = Math.max(0, Math.min(100, u));
            // exponential average (0.6 old / 0.4 new) so the numbers don't jump around
            _gpuAvg = _gpuAvg < 0 ? v : _gpuAvg * 0.6 + v * 0.4;
            gpuUsage = Math.round(_gpuAvg);
            if (_need.gpu > 0) gpuHistory = _push(gpuHistory, gpuUsage);
        } else {
            _gpuAvg = -1;
        }
        gpuTempProbe = isNaN(t) ? -1 : Math.round(t);
        cpuTempProbe = isNaN(c) ? -1 : Math.round(c);
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
        // single `sensors` call serves the CPU temp and the GPU temp fallback
        id: sensorsProc
        command: ["sensors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.cpuTempSensors = root.tempFromSensors(lines, ["Package id 0:", "Tctl:", "Tdie:"]);
                root.gpuTempSensors = root.tempFromSensors(lines, ["GPU Temp:", "GPU core:", "edge:", "junction:"]);
            }
        }
    }

    // ── Hardware info (read once, only when somebody asks) ────
    function _loadInfo() {
        if (_infoStarted) return;
        _infoStarted = true;
        cpuInfoFile.path = "/proc/cpuinfo";
        gpuNameProc.running = true;
        ramProc.running = true;
    }

    FileView {
        id: cpuInfoFile
        onLoaded: {
            const m = text().match(/^model name\s*:\s*(.+)$/m);
            root.cpuName = m ? m[1].trim() : "Unknown";
        }
    }

    Process {
        // GPU name: prefer a discrete NVIDIA/AMD/Arc card over a plain iGPU
        id: gpuNameProc
        command: ["sh", "-c",
            "l=$(lspci 2>/dev/null | grep -Ei 'VGA|3D|Display'); " +
            "g=$(echo \"$l\" | grep -Ei 'NVIDIA|AMD|ATI|Arc' | head -n1); " +
            "[ -n \"$g\" ] || g=$(echo \"$l\" | head -n1); " +
            "echo \"$g\" | sed -E 's/.*: //; s/ \\(rev.*\\)//'"]
        stdout: StdioCollector { onStreamFinished: root.gpuName = text.trim() || "Unknown" }
    }

    Process {
        // needs a NOPASSWD sudoers rule for dmidecode
        id: ramProc
        command: ["sudo", "-n", "/usr/bin/dmidecode", "-t", "memory"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/^\s*Configured Memory Speed:\s*(\d+)\s*(\S+)/m)
                       || text.match(/^\s*Speed:\s*(\d+)\s*(\S+)/m);
                root.ramSpeed = m ? m[1] + " " + m[2] : "Unknown";
            }
        }
    }

    // ── Polling ───────────────────────────────────────────────
    // CPU and network are rate readings: 1 s while a live graph is open, otherwise 2 s.
    Timer {
        interval: root._fast > 0 ? 1000 : 2000
        repeat: true; triggeredOnStart: true
        running: root._need.cpu > 0 || root._need.net > 0
        onTriggered: {
            if (root._need.cpu > 0) statFile.reload();
            if (root._need.net > 0) netFile.reload();
        }
    }

    // Memory, GPU and temperatures: every 2 s.
    Timer {
        interval: 2000
        repeat: true; triggeredOnStart: true
        running: root._need.mem > 0 || root._need.gpu > 0 || root._need.temp > 0
        onTriggered: {
            if (root._need.mem > 0) memFile.reload();
            if (root._need.gpu > 0 || root._need.temp > 0) root._run(gpuProc);
            if (root._need.temp > 0) root._run(sensorsProc);
        }
    }
}
