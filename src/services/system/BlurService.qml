pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../"

// ─── BlurService ────────────────────────────────────────────────────────────
// Asks Hyprland to blur the backdrop behind the bar while the active style
// wants it, so a translucent bar reads as frosted glass instead of a faded
// slab over whatever it is floating on.
//
// Quickshell can do this itself through Quickshell.Wayland.BackgroundEffect,
// which is the cleaner path — but that rides on the ext-background-effect-v1
// protocol, and Hyprland does not implement it (checked against 0.56). So the
// shell installs a layer rule instead, matched against the namespace TopBar
// stamps on its layer surface.
//
// ignorealpha keeps the blur inside the painted silhouette: pixels at or below
// the threshold are left alone, so the rounded notch corners and the gaps
// between the notches stay clear instead of the whole full-width strip
// blurring as one rectangle.
//
// The rule is installed, never withdrawn. A solid style paints at full alpha,
// which hides any blur behind it, so removing the rule would buy nothing — and
// `unset` is not a layer rule Hyprland reliably honours. It costs one hyprctl
// call the first time a blurred style is selected.
// ────────────────────────────────────────────────────────────────────────────

QtObject {
    id: root

    // Must match WlrLayershell.namespace on TopBar. TopBar reads it from here
    // so the two cannot drift apart.
    readonly property string layerNamespace: "ghost-bar"

    // Every Ghost layer surface is namespaced under this prefix, so one rule
    // covers the bar, the borders and the popups that own a surface. The
    // fullscreen dismiss overlay is deliberately NOT named this way: blurring
    // a screen-sized transparent layer would blur the whole desktop.
    readonly property string namespacePattern: "^ghost-"

    // Alpha at or below which a pixel is left unblurred.
    readonly property real ignoreAlpha: 0.1

    property bool _installed: false

    property Process _proc: Process {}

    function install() {
        // blur_popups matters as much as blur: most popups are xdg-popups of
        // a parent layer surface rather than surfaces of their own, so they
        // are blurred through their parent's rule, not their own.
        //
        // `hyprctl keyword` refuses to run under the Lua parser — it answers
        // "keyword can't work with non-legacy parsers. Use eval." — so each
        // config provider gets its own spelling of the same rule.
        if (ShellState.configProvider === "lua") {
            root._proc.command = [
                "hyprctl", "eval",
                'hl.layer_rule({ name = "ghost-surfaces"'
                    + ', match = { namespace = "' + root.namespacePattern + '" }'
                    + ', blur = true'
                    + ', blur_popups = true'
                    + ', ignore_alpha = ' + root.ignoreAlpha
                    + ' })'
            ]
        } else {
            // The conf parser takes one rule per keyword, so they are chained
            // into a single shell invocation rather than three Processes.
            var ns = root.namespacePattern
            root._proc.command = [
                "bash", "-c",
                "hyprctl keyword layerrule 'blur," + ns + "'; "
                + "hyprctl keyword layerrule 'blurpopups," + ns + "'; "
                + "hyprctl keyword layerrule 'ignorealpha " + root.ignoreAlpha + "," + ns + "'"
            ]
        }
        root._proc.running = true
        root._installed = true
    }

    function _sync() {
        if (Theme.barBlur && !root._installed) root.install()
    }

    property Connections _styleWatch: Connections {
        target: Theme
        function onBarBlurChanged() { root._sync() }
    }

    // Layer rules set at runtime are runtime state: a `hyprctl reload` drops
    // them and the bar would go clear without going frosted. Re-install when
    // Hyprland says it reloaded.
    property Connections _reloadWatch: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "configreloaded") return
            root._installed = false
            root._sync()
        }
    }

    Component.onCompleted: root._sync()
}
