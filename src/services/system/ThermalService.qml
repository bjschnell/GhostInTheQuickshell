import QtQuick
import Quickshell.Io

// Runs `sensors` every 3s and parses CPU package temp + fan speeds.
// CPU temp label differs by vendor: Intel reports "Package id 0",
// AMD reports "Tctl" (k10temp), older AMD "Tdie". Tried in that order.
// Separately queries nvidia-smi for GPU temp every 3s.
//
// Exposes:
//   real   cpuTemp      — CPU package temp °C, 0 if unread
//   real   gpuTemp      — NVIDIA GPU temp °C, 0 if unread/off
//   int    fan1Rpm      — fan1 speed RPM, 0 if not present
//   int    fan2Rpm      — fan2 speed RPM, 0 if not present
//   int    fanCount     — number of fans detected (0, 1, or 2)
//   string cpuTempStr   — e.g. "52°C"
//   string gpuTempStr   — e.g. "65°C" or "—"
//   string fan1Str      — e.g. "2400 RPM" or "—"
//   string fan2Str      — e.g. "0 RPM"    or "—"

QtObject {
    id: root

    property bool   active:     true
    property real   cpuTemp:    0
    property real   gpuTemp:    0
    property int    fan1Rpm:    0
    property int    fan2Rpm:    0
    property int    fanCount:   0
    property string cpuTempStr: "—"
    property string gpuTempStr: "—"
    property string fan1Str:    "—"
    property string fan2Str:    "—"

    // ── sensors process ───────────────────────────────────────────────────────
    property var _proc: Process {
        command: ["sh", "-c", "sensors 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    // ── nvidia-smi GPU temp ───────────────────────────────────────────────────
    property var _nvProc: Process {
        command: [
            "nvidia-smi",
            "--query-gpu=temperature.gpu",
            "--format=csv,noheader,nounits"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = parseFloat(text.trim())
                if (!isNaN(t)) {
                    root.gpuTemp    = t
                    root.gpuTempStr = t.toFixed(0) + "°C"
                }
            }
        }
    }

    // ── Poll timer ────────────────────────────────────────────────────────────
    property var _timer: Timer {
        interval: 2000
        running:  root.active
        repeat:   true
        onTriggered: root._run()
    }

    function _run() {
        _proc.running   = false
        _proc.running   = true
        _nvProc.running = false
        _nvProc.running = true
    }

    function _parse(text) {
        var lines = text.split("\n")
        var intel = -1, tctl = -1, tdie = -1
        var fans  = []

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]

            // CPU temp — vendor-dependent label, all formatted "+52.0°C"
            var lm = line.match(/^\s*(Package id 0|Tctl|Tdie)\s*:/i)
            if (lm) {
                var m = line.match(/\+([0-9.]+)°C/)
                if (m) {
                    var v     = parseFloat(m[1])
                    var label = lm[1].toLowerCase()
                    if      (label === "package id 0") intel = v
                    else if (label === "tctl")         tctl  = v
                    else                               tdie  = v
                }
                continue
            }

            // Fan lines — "fan1:   2400 RPM" or "Fan Speed:  2400 RPM"
            var fm = line.match(/fan\d\s*:\s+([0-9]+)\s+RPM/i)
            if (fm) {
                fans.push(parseInt(fm[1]))
                continue
            }
        }

        // Intel first, then AMD's Tctl, then legacy Tdie
        var pkg = intel >= 0 ? intel : (tctl >= 0 ? tctl : tdie)

        if (pkg >= 0) {
            root.cpuTemp    = pkg
            root.cpuTempStr = pkg.toFixed(0) + "°C"
        }

        root.fanCount = fans.length
        root.fan1Rpm  = fans.length > 0 ? fans[0] : 0
        root.fan2Rpm  = fans.length > 1 ? fans[1] : 0
        root.fan1Str  = fans.length > 0 ? fans[0] + " RPM" : "—"
        root.fan2Str  = fans.length > 1 ? fans[1] + " RPM" : "—"
    }

    Component.onCompleted: _run()
}
