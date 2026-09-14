pragma Singleton
import QtQuick

// ============================================================
// Styles — named surface treatments.
//
// A style says HOW the shell's surfaces are painted; the palette says in what
// colors. The two are independent: every style works with every palette, and
// Colors.qml persists both side by side in user_data/theme.json.
//
// A style carries TWO treatments, because the bar and the popups have
// different budgets. The bar holds a handful of glyphs over whatever window it
// floats on and can afford to be thin. A popup holds notification bodies, a
// calendar grid, network lists — text that has to stay readable — so it stays
// closer to opaque. Same material, less of it.
//
// To add a style: define it below, then add its name to `names`.
// ============================================================

QtObject {
    id: root

    // The style that ships as the default — opaque surfaces, exactly what the
    // shell painted before styles existed.
    readonly property string defaultName: "solid"

    // Selectable names, in the order the UI lists them.
    readonly property var names: [ root.defaultName, "glass" ]

    // A surface is three numbers:
    //
    //   opacity  alpha the fill is painted at.
    //   gain     how much the palette background is lightened before that
    //            alpha is applied, as a MULTIPLIER. Thinning a dark surface
    //            over a dark backdrop changes almost nothing — measured at
    //            ~2/255 with a Dracula background over a dark wallpaper —
    //            because what shows through is as dark as what covers it, so
    //            a frosted material has to be lighter than the surface it
    //            replaces, not merely thinner.
    //
    //            It multiplies rather than adds because adding the same amount
    //            to every channel is adding grey: +0.05 on Dracula's #282a36
    //            drops its chroma from 25.9% to 21.0%, and the surface reads
    //            washed out rather than tinted. Scaling holds the ratio
    //            between channels, so the palette's cast survives intact.
    //   rim      alpha of the hairline stroked along the silhouette. Blur on
    //            its own reads as washed out; the lit edge is what makes a
    //            surface read as a material rather than a faded slab.
    //
    // And one flag, `blur`, which asks the compositor to blur the backdrop.
    // BlurService installs the layer rules that do it.

    readonly property var solid: ({
        "blur":  false,
        "bar":   { "opacity": 1.00, "gain": 1.00, "rim": 0.00 },
        "popup": { "opacity": 1.00, "gain": 1.00, "rim": 0.00 }
    })

    readonly property var glass: ({
        "blur":  true,
        "bar":   { "opacity": 0.55, "gain": 1.75, "rim": 0.22 },
        "popup": { "opacity": 0.74, "gain": 1.35, "rim": 0.14 }
    })

    readonly property var _byName: ({
        "solid": root.solid,
        "glass": root.glass
    })

    // Unknown names resolve to the default rather than to an unpainted shell,
    // so a stale config cannot strand the surfaces on a style this build
    // no longer defines.
    function get(name) {
        var s = root._byName[name]
        return s !== undefined ? s : root.solid
    }

    function isKnown(name) {
        return root._byName[name] !== undefined
    }
}
