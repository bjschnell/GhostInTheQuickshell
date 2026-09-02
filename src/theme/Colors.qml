pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    // ── Palette selection ─────────────────────────────────────────────────────
    // Palettes.dynamicName ("wallpaper") follows the wallpaper: matugen rewrites
    // ~/.cache/ghost/colors.json on every apply and ColorLoader picks it up live.
    // Any other name defined in Palettes.qml pins the shell to that fixed palette
    // and ignores matugen — the wallpaper still changes, the shell colors do not.
    //
    // Set through setPalette() rather than assigned directly, so the choice is
    // persisted. Read it through Theme.palette.
    property string palette: Palettes.dynamicName

    // null while following the wallpaper.
    readonly property var _static: Palettes.get(root.palette)

    readonly property string configPath:
        Quickshell.env("HOME") + "/.config/Ghost/src/user_data/theme.json"

    // ── Selection API ─────────────────────────────────────────────────────────
    function setPalette(name) {
        if (!Palettes.isKnown(name) || name === root.palette) return
        root.palette = name
        root._save()
    }

    // Steps through Palettes.names — handy for a single toggle keybind.
    function cyclePalette() {
        var n = Palettes.names
        var i = n.indexOf(root.palette)
        root.setPalette(n[(i + 1) % n.length])
    }

    // ── Color loader — watches matugen output and updates live ────────────────
    // Use a unique ID to avoid namespace collision with the 'Colors' singleton.
    // Kept instantiated even while a static palette is active, so switching back
    // to the dynamic palette snaps straight to the wallpaper colors with no reload.
    property var _loader: ColorLoader { id: internalLoader }

    // ── Persistence — user_data/theme.json ────────────────────────────────────
    property var _cfgFile: FileView {
        id: themeFile
        path: root.configPath
        watchChanges: true
        // A missing file is the normal default (no palette chosen yet), not an
        // error worth logging on every cold start.
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._parseConfig(themeFile.text())
    }

    function _parseConfig(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var obj = JSON.parse(raw)
            // Unknown names are ignored so a stale config cannot strand the
            // shell on a palette this build no longer defines.
            if (obj.palette && Palettes.isKnown(obj.palette))
                root.palette = obj.palette
        } catch (e) {
            // Malformed JSON — keep the current selection
        }
    }

    property var _saveProc: Process {}

    function _save() {
        var json = JSON.stringify({ palette: root.palette })
        // printf so the content is never reinterpreted as shell commands.
        root._saveProc.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname '" + root.configPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.configPath + "'"
        ]
        root._saveProc.running = true
    }

    // ── Colors — static palette when one is selected, else the live loader ────
    property color background: _static ? _static.background : internalLoader.background
    property color active:     _static ? _static.active     : internalLoader.active
    property color text:       _static ? _static.text       : internalLoader.text
    property color subtext:    _static ? _static.subtext    : internalLoader.subtext
    property color icon:       _static ? _static.icon       : internalLoader.icon
    property color border:     _static ? _static.border     : internalLoader.border
    property color iconFont:   _static ? _static.iconFont   : internalLoader.iconFont

    // --- Workspace Visuals ---
    // Never matugen-driven; a static palette may still restyle them.
    property color wsBackground: _static ? _static.wsBackground : "#20000000"
    property color wsActive:     _static ? _static.wsActive     : "#FFFFFF"
    property color wsOccupied:   _static ? _static.wsOccupied   : "#80FFFFFF"
    property color wsEmpty:      _static ? _static.wsEmpty      : "#30FFFFFF"
    property color wsOverlay:    _static ? _static.wsOverlay    : "#CC1e1e2e"
    property color wsUrgent:     _static ? _static.wsUrgent     : "#fa6b94"
}
