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

    // ── Style selection ───────────────────────────────────────────────────────
    // Independent of the palette: the style decides how surfaces are painted,
    // the palette decides in what colors. Set through setStyle() so the choice
    // is persisted beside the palette. Read it through Theme.style.
    property string style: Styles.defaultName

    readonly property var _style: Styles.get(root.style)

    readonly property string configPath:
        Quickshell.env("HOME") + "/.config/Ghost/src/user_data/theme.json"

    // ── Selection API ─────────────────────────────────────────────────────────
    function setPalette(name) {
        if (!Palettes.isKnown(name) || name === root.palette) return
        root.palette = name
        root._save()
    }

    function setStyle(name) {
        if (!Styles.isKnown(name) || name === root.style) return
        root.style = name
        root._save()
    }

    // Surface treatment for any style, selected or not, so the UI can preview
    // one before switching to it.
    function styleSwatch(name) {
        return Styles.get(name)
    }

    // Steps through Styles.names — handy for a single toggle keybind.
    function cycleStyle() {
        var n = Styles.names
        var i = n.indexOf(root.style)
        root.setStyle(n[(i + 1) % n.length])
    }

    // Steps through Palettes.names — handy for a single toggle keybind.
    function cyclePalette() {
        var n = Palettes.names
        var i = n.indexOf(root.palette)
        root.setPalette(n[(i + 1) % n.length])
    }

    // Swatch colors for any palette, whether or not it is the selected one, so
    // UI can preview a palette before switching to it. The dynamic palette reads
    // off the live loader — kept instantiated even while a static palette is
    // pinned — so its preview is never a stale snapshot.
    readonly property var _dynamicSwatch: ({
        "background": internalLoader.background,
        "active":     internalLoader.active,
        "text":       internalLoader.text,
        "subtext":    internalLoader.subtext,
        "icon":       internalLoader.icon,
        "border":     internalLoader.border,
        "iconFont":   internalLoader.iconFont
    })

    function swatch(name) {
        return Palettes.get(name) || root._dynamicSwatch
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
            if (obj.style && Styles.isKnown(obj.style))
                root.style = obj.style
        } catch (e) {
            // Malformed JSON — keep the current selection
        }
    }

    property var _saveProc: Process {}

    function _save() {
        var json = JSON.stringify({ palette: root.palette, style: root.style })
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

    // ── Styled surfaces — palette color, style treatment ──────────────────────
    // Surfaces get their own roles rather than using `background` directly:
    // that role doubles as a contrast color for text and icons drawn ON a
    // surface, and must stay opaque even when the surface it sits on does not.
    //
    // `bar` is the notch silhouette; `surface` is every popup.
    readonly property bool barBlur: root._style.blur

    // Scales the palette background rather than adding to it, so the ratio
    // between channels — and with it the palette's cast — survives being
    // lightened. See the note on `gain` in Styles.qml.
    function _fill(spec) {
        return Qt.rgba(Math.min(1, root.background.r * spec.gain),
                       Math.min(1, root.background.g * spec.gain),
                       Math.min(1, root.background.b * spec.gain),
                       spec.opacity)
    }

    readonly property color barFill:  root._fill(root._style.bar)
    readonly property color surface:  root._fill(root._style.popup)

    // Rims are white rather than a palette role: this is light catching an
    // edge, not a color the theme gets a say in.
    readonly property color barRim:     Qt.rgba(1, 1, 1, root._style.bar.rim)
    readonly property color surfaceRim: Qt.rgba(1, 1, 1, root._style.popup.rim)

    readonly property real barOpacity:     root._style.bar.opacity
    readonly property real surfaceOpacity: root._style.popup.opacity

    // --- Workspace Visuals ---
    // Never matugen-driven; a static palette may still restyle them.
    property color wsBackground: _static ? _static.wsBackground : "#20000000"
    property color wsActive:     _static ? _static.wsActive     : "#FFFFFF"
    property color wsOccupied:   _static ? _static.wsOccupied   : "#80FFFFFF"
    property color wsEmpty:      _static ? _static.wsEmpty      : "#30FFFFFF"
    property color wsOverlay:    _static ? _static.wsOverlay    : "#CC1e1e2e"
    property color wsUrgent:     _static ? _static.wsUrgent     : "#fa6b94"
}
