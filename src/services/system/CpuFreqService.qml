import QtQuick
import Quickshell.Io

// Reads the current CPU frequency.
//
//   cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq
//   → averages kHz across all cores → curFreqStr
//
// Exposes:
//   string curFreqStr  — average frequency e.g. "2.40 GHz"

QtObject {
    id: root

    property string curFreqStr: "— GHz"

    // ── Current frequency reader (all cores) ─────────────────────────────────
    // scaling_cur_freq is in kHz. Average across all cores → format as GHz.
    property var _freqProc: Process {
        command: ["sh", "-c", "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(function(l) { return l !== "" })
                if (lines.length === 0) return

                var sum = 0
                for (var i = 0; i < lines.length; i++)
                    sum += parseFloat(lines[i].trim())

                var avgGhz = (sum / lines.length) / 1e6
                root.curFreqStr = avgGhz.toFixed(2) + " GHz"
            }
        }
    }

    // ── Poll timer ────────────────────────────────────────────────────────────
    property var _pollTimer: Timer {
        interval: 2000
        running:  true
        repeat:   true
        onTriggered: root._poll()
    }

    function _poll() {
        _freqProc.running = false
        _freqProc.running = true
    }

    Component.onCompleted: _poll()
}
