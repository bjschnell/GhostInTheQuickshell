pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Idle management — replaces hypridle.
//
// hypridle is a thin daemon over ext-idle-notify-v1, the same protocol
// Quickshell exposes as IdleMonitor, so each hypridle `listener` block maps
// onto one monitor here: `timeout` is the timeout, `on-timeout` fires when
// isIdle goes true, `on-resume` when it goes false.
//
// respectInhibitors honours the Wayland idle-inhibit protocol, so a fullscreen
// video holds the screen up. It does NOT see logind inhibitors, which is what
// the Caffeine toggle in QuickSettings takes — so every action is additionally
// guarded by _guard below.
//
// Timings and the master switch live in user_data/idle.json and can be changed
// without editing this file. Idle actions ship disabled, matching the state the
// old hypridle.conf was left in; turn them on with:
//
//   qs ipc call idle enable
//
// Exposes:
//   bool   enabled       — master switch, persisted
//   int    lockSecs      — seconds of idle before the screen locks
//   int    dpmsSecs      — seconds before displays are powered off
//   int    suspendSecs   — seconds before the system suspends
//   bool   idle          — true once the first stage has fired
//   string lastEvent     — most recent action, for `qs ipc call idle status`

QtObject {
    id: root

    // ── Configuration ─────────────────────────────────────────────────────────
    // Defaults carried over from src/config/hypridle.conf.
    property bool enabled:     false
    property int  lockSecs:    330   // 5.5 min
    property int  dpmsSecs:    360   // 6 min
    property int  suspendSecs: 900   // 15 min

    // Routed through IPC rather than calling LockService.lock() directly so the
    // Caffeine guard below applies to locking exactly as it does to the other
    // stages — a direct call could not be gated on an async pgrep.
    property string lockCommand:
        "qs -p '" + Quickshell.shellDir + "' ipc call lock lock"
    property string dpmsOffCommand: "hyprctl dispatch dpms off"
    property string dpmsOnCommand:  "hyprctl dispatch dpms on"
    property string suspendCommand: "systemctl suspend"

    readonly property string configPath:
        Quickshell.env("HOME") + "/.config/Ghost/src/user_data/idle.json"

    // ── Live state ────────────────────────────────────────────────────────────
    readonly property bool idle: lockMonitor.isIdle || dpmsMonitor.isIdle
    property string lastEvent:   "idle service ready"
    property string lastEventAt: ""

    // ── Actions ───────────────────────────────────────────────────────────────
    // Caffeine takes a logind idle inhibitor, which ext-idle-notify cannot see.
    // Checking for it at fire time rather than polling keeps this event-driven:
    // the toggle can flip at any point during a long idle and still be honoured.
    readonly property string _guard: "pgrep -f 'systemd-inhibit.*Caffeine' >/dev/null || "

    property var _actionProc: Process {}

    function _run(event, command) {
        root.lastEventAt = new Date().toISOString()
        root.lastEvent   = event
        console.log("Ghost idle " + root.lastEventAt + " " + event)

        // A stage firing while the previous one is still in flight would drop
        // the new command, so each action gets its own short-lived shell.
        Quickshell.execDetached(["bash", "-c", root._guard + command])
    }

    // ── Stages ────────────────────────────────────────────────────────────────
    // One monitor per stage. ext-idle-notify supports concurrent timeouts, and
    // each reports its own resume, so no timer arithmetic is needed to chain
    // them — this is exactly how hypridle drives its listener list.

    property var _lock: IdleMonitor {
        id: lockMonitor
        enabled: root.enabled && root.lockSecs > 0
        timeout: root.lockSecs
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root._run("lock", root.lockCommand)
    }

    property var _dpms: IdleMonitor {
        id: dpmsMonitor
        enabled: root.enabled && root.dpmsSecs > 0
        timeout: root.dpmsSecs
        respectInhibitors: true
        onIsIdleChanged: root._run(isIdle ? "dpms off" : "dpms on",
                                   isIdle ? root.dpmsOffCommand : root.dpmsOnCommand)
    }

    property var _suspend: IdleMonitor {
        id: suspendMonitor
        enabled: root.enabled && root.suspendSecs > 0
        timeout: root.suspendSecs
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root._run("suspend", root.suspendCommand)
    }

    // ── Persistence — user_data/idle.json ─────────────────────────────────────
    property var _cfgFile: FileView {
        id: idleFile
        path: root.configPath
        watchChanges: true
        // A missing file is the normal default on a fresh install, not an error.
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._parseConfig(idleFile.text())
    }

    function _parseConfig(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var obj = JSON.parse(raw)
            if (typeof obj.enabled === "boolean") root.enabled = obj.enabled
            // Zero disables a single stage while leaving the others running.
            if (obj.lock    >= 0) root.lockSecs    = obj.lock
            if (obj.dpms    >= 0) root.dpmsSecs    = obj.dpms
            if (obj.suspend >= 0) root.suspendSecs = obj.suspend
        } catch (e) {
            // Malformed JSON — keep the current settings
        }
    }

    property var _saveProc: Process {}

    function _save() {
        var json = JSON.stringify({
            enabled: root.enabled,
            lock:    root.lockSecs,
            dpms:    root.dpmsSecs,
            suspend: root.suspendSecs
        })
        // printf so the content is never reinterpreted as shell commands.
        root._saveProc.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname '" + root.configPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.configPath + "'"
        ]
        root._saveProc.running = true
    }

    function setEnabled(value) {
        var next = !!value
        if (next === root.enabled) return root.enabled

        root.enabled = next
        root._save()
        root._run(next ? "enabled" : "disabled", "true")

        // Leaving displays dark after the switch is flipped off would look like
        // a hang, and no resume event is coming — the monitors are gone.
        if (!next) root._run("dpms on", root.dpmsOnCommand)

        return root.enabled
    }

    function statusJson() {
        return JSON.stringify({
            enabled:     root.enabled,
            idle:        root.idle,
            lock:        root.lockSecs,
            dpms:        root.dpmsSecs,
            suspend:     root.suspendSecs,
            stages:      { lock: lockMonitor.isIdle, dpms: dpmsMonitor.isIdle, suspend: suspendMonitor.isIdle },
            lastEvent:   root.lastEvent,
            lastEventAt: root.lastEventAt
        })
    }
}
