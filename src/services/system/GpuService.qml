import QtQuick
import Quickshell.Io

// NVIDIA dGPU stats via nvidia-smi, polled whenever the service is active.
//
// Exposes:
//   dgpu.active       — true once nvidia-smi reports a device
//   dgpu.usagePercent — 0–100
//   dgpu.usedVram     — e.g. "2048 MB"
//   dgpu.totalVram    — e.g. "4096 MB"

QtObject {
    id: root

    property bool   active:   true

    property QtObject dgpu: QtObject {
        property bool   active:       false
        property real   usagePercent: 0.0
        property string usedVram:     "— MB"
        property string totalVram:    "— MB"
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
        _nvProc.running = true
    }
}
