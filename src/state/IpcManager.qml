pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ─────────────────────────────────────────────────────────────
// IpcManager — centralized entry point for all external IPC signals.
//
// Moving handlers here ensures that on multi-monitor setups (where 
// TopBar/PopupLayer are duplicated) only ONE handler reacts to a signal.
// ─────────────────────────────────────────────────────────────

QtObject {
    id: root

    // ── Dashboard Toggles ────────────────────────────────────
    
    property var dashboardHome: IpcHandler {
        target: "dashboard-home"
        function toggle() {
            if(Popups.anyOpen && !Popups.dashboardOpen){
                Popups.closeAll()
                Popups.dashboardOpen = true
                Popups.dashboardPage = "home"
            } else if(Popups.dashboardOpen && Popups.dashboardPage != "home") {
                Popups.dashboardPage = "home"
            } else {
                var next = !Popups.dashboardOpen
                Popups.closeAll()
                Popups.dashboardOpen = next
                if (next) Popups.dashboardPage = "home"
            }
        }
    }

    property var dashboardStats: IpcHandler {
        target: "dashboard-stats"
        function toggle() {
            if(Popups.anyOpen && !Popups.dashboardOpen){
                Popups.closeAll()
                Popups.dashboardOpen = true
                Popups.dashboardPage = "stats"
            } else if(Popups.dashboardOpen && Popups.dashboardPage != "stats") {
                Popups.dashboardPage = "stats"
            } else {
                var next = !Popups.dashboardOpen
                Popups.closeAll()
                Popups.dashboardOpen = next
                if (next) Popups.dashboardPage = "stats"
            }
        }
    }

    property var dashboardLauncher: IpcHandler {
        target: "dashboard-launcher"
        function toggle() {
            if(Popups.anyOpen && !Popups.dashboardOpen){
                Popups.closeAll()
                Popups.dashboardOpen = true
                Popups.dashboardPage = "launcher"
            } else if(Popups.dashboardOpen && Popups.dashboardPage != "launcher") {
                Popups.dashboardPage = "launcher"
            } else {
                var next = !Popups.dashboardOpen
                Popups.closeAll()
                Popups.dashboardOpen = next
                if (next) Popups.dashboardPage = "launcher"
            }
        }
    }

    property var dashboardConfig: IpcHandler {
        target: "dashboard-config"
        function toggle() {
            if(Popups.anyOpen && !Popups.dashboardOpen){
                Popups.closeAll()
                Popups.dashboardOpen = true
                Popups.dashboardPage = "config"
            } else if(Popups.dashboardOpen && Popups.dashboardPage != "config") {
                Popups.dashboardPage = "config"
            } else {
                var next = !Popups.dashboardOpen
                Popups.closeAll()
                Popups.dashboardOpen = next
                if (next) Popups.dashboardPage = "config"
            }
        }
    }

    // ── Audio Toggles ────────────────────────────────────────

    property var audioOut: IpcHandler {
        target: "audioOut-toggle"
        function toggle() {
            if(Popups.anyOpen && !Popups.audioOpen) {
                Popups.closeAll()
                Popups.audioPage = "output"
                Popups.audioOpen = true
            } else if (Popups.audioOpen && Popups.audioPage != "output") {
                Popups.audioPage = "output"
            } else {
                var next = !Popups.audioOpen
                Popups.closeAll()
                Popups.audioOpen = next
                if (next) Popups.audioPage = "output"
            }
        }
    }

    property var audioMix: IpcHandler {
        target: "audioMix-toggle"
        function toggle() {
            if(Popups.anyOpen && !Popups.audioOpen) {
                Popups.closeAll()
                Popups.audioPage = "mixer"
                Popups.audioOpen = true
            } else if (Popups.audioOpen && Popups.audioPage != "mixer") {
                Popups.audioPage = "mixer"
            } else {
                var next = !Popups.audioOpen
                Popups.closeAll()
                Popups.audioOpen = next
                if (next) Popups.audioPage = "mixer"
            }
        }
    }

    property var audioIn: IpcHandler {
        target: "audioIn-toggle"
        function toggle() {
            if(Popups.anyOpen && !Popups.audioOpen) {
                Popups.closeAll()
                Popups.audioPage = "input"
                Popups.audioOpen = true
            } else if (Popups.audioOpen && Popups.audioPage != "input") {
                Popups.audioPage = "input"
            } else {
                var next = !Popups.audioOpen
                Popups.closeAll()
                Popups.audioOpen = next
                if (next) Popups.audioPage = "input"
            }
        }
    }

    // ── Network Toggles ──────────────────────────────────────

    property var wifiToggle: IpcHandler {
        target: "wifi-toggle"
        function toggle() {
            if(Popups.anyOpen && !Popups.networkOpen) {
                Popups.closeAll()
                Popups.networkPage = "wifi"
                Popups.networkOpen = true
            } else if (Popups.networkOpen && Popups.networkPage != "wifi") {
                Popups.networkPage = "wifi"
            } else {
                var next = !Popups.networkOpen
                Popups.closeAll()
                Popups.networkOpen = next
                if (next) Popups.networkPage = "wifi"
            }
        }
    }

    property var btToggle: IpcHandler {
        target: "bluetooth-toggle"
        function toggle() {
            if(Popups.anyOpen && !Popups.networkOpen) {
                Popups.closeAll()
                Popups.networkPage = "bluetooth"
                Popups.networkOpen = true
            } else if (Popups.networkOpen && Popups.networkPage != "bluetooth") {
                Popups.networkPage = "bluetooth"
            } else {
                var next = !Popups.networkOpen
                Popups.closeAll()
                Popups.networkOpen = next
                if (next) Popups.networkPage = "bluetooth"
            }
        }
    }

    property var vpnToggle: IpcHandler {
        target: "vpn-toggle"
        function toggle() {
            if(Popups.anyOpen && !Popups.networkOpen) {
                Popups.closeAll()
                Popups.networkPage = "vpn"
                Popups.networkOpen = true
            } else if (Popups.networkOpen && Popups.networkPage != "vpn") {
                Popups.networkPage = "vpn"
            } else {
                var next = !Popups.networkOpen
                Popups.closeAll()
                Popups.networkOpen = next
                if (next) Popups.networkPage = "vpn"
            }
        }
    }

    // ── Misc Toggles ─────────────────────────────────────────

    property var notification: IpcHandler {
        target: "notification-toggle"
        function toggle() {
            var next = !Popups.notificationsOpen
            Popups.closeAll()
            Popups.notificationsOpen = next
        }
    }

    property var clipboard: IpcHandler {
        target: "clipboard-toggle"
        function toggle() {
            var next = !Popups.clipboardOpen
            Popups.closeAll()
            Popups.clipboardOpen = next
        }
    }

    property var wallpaper: IpcHandler {
        target: "wallpaper-toggle"
        function toggle() {
            var next = !Popups.wallpaperOpen
            Popups.closeAll()
            Popups.wallpaperOpen = next
        }
    }

    property var archMenu: IpcHandler {
        target: "PowerMenu-toggle"
        function toggle() {
            var next = !Popups.archMenuOpen
            Popups.closeAll()
            Popups.archMenuOpen = next
        }
    }

    property var screenRec: IpcHandler {
        target: "screenrec-on"
        function toggle() {
            if (ScreenRecService.recording) {
                 ScreenRecService.stopRecording()
             } else if (ShellState.screenRecord) {
                 ScreenRecService.cancelSetup()
             } else {
                 Popups.closeAll()
                 ShellState.screenRecord = true
             }
        }
    }

    // ── Theme ────────────────────────────────────────────────
    // qs ipc call theme list
    // qs ipc call theme set dracula
    // qs ipc call theme cycle      (bindable to a key)

    property var theme: IpcHandler {
        target: "theme"

        function set(name: string): string {
            Theme.setPalette(name)
            return Theme.palette
        }

        function cycle(): string {
            Theme.cyclePalette()
            return Theme.palette
        }

        function current(): string {
            return Theme.palette
        }

        function list(): string {
            return Theme.palettes.join("\n")
        }
    }

    // ── Clipboard ────────────────────────────────────────────
    // qs ipc call clipboard status  — counts only, never contents
    // qs ipc call clipboard wipe

    property var clipboardStatus: IpcHandler {
        target: "clipboard"

        // Deliberately reports no entry text: this is for checking that capture
        // is alive, and piping clipboard contents through IPC would undo the
        // point of refusing to store them.
        function status(): string {
            var images = 0
            for (var i = 0; i < ClipboardService.entries.length; i++)
                if (ClipboardService.entries[i].isImage) images += 1

            return JSON.stringify({
                entries: ClipboardService.entries.length,
                images:  images,
                pinned:  ClipboardService.pinned.length,
                limit:   ClipboardService.maxEntries
            })
        }

        function wipe(): string {
            ClipboardService.wipeHistory()
            return "ok"
        }
    }

    // ── Polkit ───────────────────────────────────────────────
    // qs ipc call polkit status
    // "registered": false means another agent has the session — check that
    // hyprpolkitagent is really gone.

    property var polkit: IpcHandler {
        target: "polkit"

        function status(): string {
            return PolkitService.statusJson()
        }
    }

    // ── Lock ─────────────────────────────────────────────────
    // qs ipc call lock lock
    // qs ipc call lock status
    // qs ipc call lock preview / hidePreview   (design the lock without locking)

    property var lockScreen: IpcHandler {
        target: "lock"

        // The reply matters: src/scripts/sleep-lock.sh reads "missing-pam" to
        // tell a lock that will never happen from one still in progress.
        function lock(): string {
            if (!LockService.passwordPamConfigured) return "missing-pam"
            if (!LockService.locked && !LockService.lock()) return "failed"
            return "ok"
        }

        function isLocked(): string {
            return LockService.locked ? "true" : "false"
        }

        function status(): string {
            return LockService.statusJson()
        }

        function preview(): string {
            LockService.refreshBackground()
            LockService.refreshFingerprintStatus()
            LockService.previewVisible = true
            return "ok"
        }

        function hidePreview(): string {
            LockService.previewVisible = false
            return "ok"
        }
    }

    // ── Idle ─────────────────────────────────────────────────
    // qs ipc call idle status
    // qs ipc call idle enable / disable / toggle

    property var idle: IpcHandler {
        target: "idle"

        function status(): string {
            return IdleService.statusJson()
        }

        function enable(): string {
            return IdleService.setEnabled(true) ? "enabled" : "disabled"
        }

        function disable(): string {
            return IdleService.setEnabled(false) ? "enabled" : "disabled"
        }

        function toggle(): string {
            return IdleService.setEnabled(!IdleService.enabled) ? "enabled" : "disabled"
        }
    }

    property var focusMode: IpcHandler {
        target: "focus-toggle"
        function toggle() {
            root.focusToggleRequested()
        }
    }
    
    signal focusToggleRequested()
}
