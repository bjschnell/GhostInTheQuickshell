pragma Singleton
import QtQuick

// ============================================================
// Palettes — named static color palettes.
//
// A palette is an alternative to the matugen pipeline, not a layer on top
// of it: it supplies every role ColorLoader would otherwise read out of
// ~/.cache/ghost/colors.json, so nothing silently falls back to a
// wallpaper-derived value. Colors.qml selects one by name.
//
// The name in `dynamicName` is reserved: it means "no static palette, follow
// the wallpaper" and is what ships as the default.
//
// To add a palette: define it below, then add its name to `names`.
// ============================================================

QtObject {
    id: root

    // Reserved name meaning "follow the wallpaper via matugen".
    readonly property string dynamicName: "wallpaper"

    // Selectable names, in the order the UI lists them.
    readonly property var names: [ root.dynamicName, "dracula" ]

    // ── Dracula — https://draculatheme.com ────────────────────────────────────
    // Roles map onto the official palette as:
    //   background  Background      #282a36
    //   border      Current Line    #44475a
    //   text/icon   Foreground      #f8f8f2
    //   subtext     Comment         #6272a4
    //   active      Purple          #bd93f9
    //   iconFont    Cyan            #8be9fd
    //   wsActive    Green           #50fa7b
    //   wsUrgent    Red             #ff5555
    readonly property var dracula: ({
        "background": "#282a36",
        "active":     "#bd93f9",
        "text":       "#f8f8f2",
        "subtext":    "#6272a4",
        "icon":       "#f8f8f2",
        "border":     "#44475a",
        "iconFont":   "#8be9fd",

        // Workspace dots keep the shape of the dynamic defaults — a translucent
        // capsule, the foreground at three opacities, an accent for focus — and
        // only swap pure white for Dracula's foreground.
        "wsBackground": "#20000000",
        "wsActive":     "#50fa7b",
        "wsOccupied":   "#80f8f8f2",
        "wsEmpty":      "#30f8f8f2",
        "wsOverlay":    "#cc282a36",
        "wsUrgent":     "#ff5555"
    })

    readonly property var _byName: ({ "dracula": root.dracula })

    // Returns the named palette, or null to mean "follow the wallpaper".
    // Unknown names resolve to null so a bad config value degrades to the
    // dynamic pipeline rather than to an unpainted shell.
    function get(name) {
        if (!name || name === "" || name === root.dynamicName) return null
        var p = root._byName[name]
        return p !== undefined ? p : null
    }

    // True only for a name this file actually defines.
    function isKnown(name) {
        return name === root.dynamicName || root._byName[name] !== undefined
    }
}
