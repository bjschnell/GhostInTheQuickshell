import QtQuick
import Quickshell.Io

// AMD iGPU: utilization and clock from amdgpu sysfs. The card index is not
//           stable across boots, so the node is discovered by driver name.
// NVIDIA dGPU: nvidia-smi, polled whenever the service is active.
//
// Exposes:
//   igpu.active       — false when no amdgpu node exposes gpu_busy_percent
//   igpu.usagePercent — 0–100, straight from gpu_busy_percent
//   igpu.curMhz       — active pp_dpm_sclk step, e.g. "600 MHz"
//   igpu.maxMhz       — highest pp_dpm_sclk step, e.g. "2200 MHz"
//
//   dgpu.active       — true once nvidia-smi reports a device
//   dgpu.usagePercent — 0–100
//   dgpu.usedVram     — e.g. "2048 MB"
//   dgpu.totalVram    — e.g. "4096 MB"

QtObject {
    id: root

    property bool   active:   true

    property QtObject igpu: QtObject {
        property bool   active:       false
        property real   usagePercent: 0.0
        property string curMhz:       "— MHz"
        property string maxMhz:       "— MHz"
    }

    property QtObject dgpu: QtObject {
        property bool   active:       false
        property real   usagePercent: 0.0
        property string usedVram:     "— MB"
        property string totalVram:    "— MB"
    }

    // ── AMD iGPU — one shell pass emits "busy cur max" ───────────────────────
    // pp_dpm_sclk lists clock steps, the active one flagged with "*":
    //     0: 600Mhz *
    //     1: 700Mhz
    //     2: 2200Mhz
    property var _igpuProc: Process {
        command: ["sh", "-c",
            "for u in /sys/class/drm/card*/device/uevent; do grep -q '^DRIVER=amdgpu$' \"$u\" 2>/dev/null || continue; " +
            "d=$(dirname \"$u\"); [ -r \"$d/gpu_busy_percent\" ] || continue; " +
            "busy=$(cat \"$d/gpu_busy_percent\" 2>/dev/null); cur=$(awk '/\\*/ {gsub(/[Mm]hz/, \"\", $2); " +
            "print $2; exit}' \"$d/pp_dpm_sclk\" 2>/dev/null); max=$(awk '{gsub(/[Mm]hz/, \"\", $2); " +
            "if ($2+0>m) m=$2+0} END {print m}' \"$d/pp_dpm_sclk\" 2>/dev/null); " +
            "printf '%s %s %s\\n' \"${busy:-0}\" \"${cur:-0}\" \"${max:-0}\"; " +
            "break; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line === "") { root.igpu.active = false; return }

                var p = line.split(/\s+/)
                if (p.length < 3) { root.igpu.active = false; return }

                var busy = parseFloat(p[0]), cur = parseFloat(p[1]), max = parseFloat(p[2])
                if (isNaN(busy)) { root.igpu.active = false; return }

                root.igpu.active       = true
                root.igpu.usagePercent = Math.round(busy)
                if (!isNaN(cur) && cur > 0) root.igpu.curMhz = cur + " MHz"
                if (!isNaN(max) && max > 0) root.igpu.maxMhz = max + " MHz"
            }
        }
    }

    // ── NVIDIA dGPU ───────────────────────────────────────────────────────────
    property var _nvProc: Process {
        command: [
            "nvidia-smi",
            "--query-gpu=utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line  = text.trim()
                if (line === "") return
                var parts = line.split(",").map(function(s) { return s.trim() })
                if (parts.length < 3) return
                root.dgpu.active       = true
                root.dgpu.usagePercent = parseFloat(parts[0]) || 0
                root.dgpu.usedVram     = parts[1] + " MB"
                root.dgpu.totalVram    = parts[2] + " MB"
            }
        }
    }

    // ── Poll timers ───────────────────────────────────────────────────────────
    property var _igpuTimer: Timer {
        interval: 1000
        running:  root.active
        repeat:   true
        onTriggered: {
            _igpuProc.running = false
            _igpuProc.running = true
        }
    }

    property var _nvTimer: Timer {
        interval: 1000
        running:  root.active
        repeat:   true
        onTriggered: {
            _nvProc.running = false
            _nvProc.running = true
        }
    }

    Component.onCompleted: {
        _igpuProc.running = true
        _nvProc.running   = true
    }
}
