import QtQuick
import "../"
import "surface.js" as Surface

Canvas {
    id: root
    anchors.fill: parent

    // These are set by TopBar.qml with the real clamped widths.
    // They default to the Theme constraints so the shape is never empty.
    property int leftWidth:   Theme.lNotchMinWidth
    property int centerWidth: Theme.cNotchMinWidth
    property int rightWidth:  Theme.rNotchMinWidth

    property int notchHeight:     Theme.notchHeight
    property int radius:          Theme.notchRadius
    property int topBorderWidth:  Theme.borderWidth

    // The bar's own fill, not the shared background role: the style may paint
    // it translucent, while popups and borders stay opaque.
    property color color:         Theme.barFill

    // Hairline along the silhouette. A translucent surface reads as washed out
    // without one — the lit edge is what makes it read as a material rather
    // than a faded slab. The solid style asks for none and none is drawn.
    property color rimColor:      Theme.barRim
    property int   rimWidth:      Theme.barRimWidth

    // How far each notch hangs below the top edge, in px.
    // notchHeight = fully out, topBorderWidth = fully retracted (drawn as a
    // flat run of top edge, so the other two are untouched).
    property real leftDepth:      Theme.notchHeight
    property real centerDepth:    Theme.notchHeight
    property real rightDepth:     Theme.notchHeight

    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()
    onLeftWidthChanged:   requestPaint()
    onCenterWidthChanged: requestPaint()
    onRightWidthChanged:  requestPaint()
    onLeftDepthChanged:   requestPaint()
    onCenterDepthChanged: requestPaint()
    onRightDepthChanged:  requestPaint()
    onColorChanged:       requestPaint()
    onRimColorChanged:    requestPaint()
    onRimWidthChanged:    requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        var leftW   = root.leftWidth
        var centerW = root.centerWidth
        var rightW  = root.rightWidth

        var r = root.radius
        var h = root.notchHeight
        var b = root.topBorderWidth
        var w = width

        // Calculated positions
        var centerStart = (w / 2) - (centerW / 2)
        var centerEnd   = (w / 2) + (centerW / 2)
        var rightStart  = w - rightW

        ctx.beginPath();

        // Every notch retracts by depth, not by width, so it melts into the
        // top edge instead of shrinking to a sliver. A notch's corner radius
        // is clamped to whatever vertical room is left, otherwise its two arcs
        // overlap and Canvas draws a knot on the way down.
        function depthOf(d)       { return Math.max(b, Math.min(h, d)) }
        function radiusOf(d, wid) { return Math.max(0, Math.min(r, (d - b) / 2, wid / 2)) }

        var hl = depthOf(root.leftDepth)
        var hc = depthOf(root.centerDepth)
        var hr = depthOf(root.rightDepth)

        var lr = radiusOf(hl, leftW)
        var cr = radiusOf(hc, centerW)
        var rr = radiusOf(hr, rightW)

        // ============================
        // 1. LEFT NOTCH
        // ============================
        if (hl > b) {
            ctx.moveTo(0, hl);
            ctx.lineTo(leftW - lr, hl);
            ctx.arcTo(leftW, hl, leftW, hl - lr, lr);
            ctx.lineTo(leftW, b + lr);
            ctx.arcTo(leftW, b, leftW + lr, b, lr);
        } else {
            // Fully retracted: start on the top edge and let section 2 run
            // straight out from the corner.
            ctx.moveTo(0, b);
        }

        // ============================
        // 2. + 3. GAP 1 → CENTER NOTCH
        // ============================
        if (hc > b) {
            ctx.lineTo(centerStart - cr, b);
            ctx.arcTo(centerStart, b, centerStart, b + cr, cr);
            ctx.lineTo(centerStart, hc - cr);
            ctx.arcTo(centerStart, hc, centerStart + cr, hc, cr);
            ctx.lineTo(centerEnd - cr, hc);
            ctx.arcTo(centerEnd, hc, centerEnd, hc - cr, cr);
            ctx.lineTo(centerEnd, b + cr);
            ctx.arcTo(centerEnd, b, centerEnd + cr, b, cr);
        }
        // Fully retracted: fall through to section 4, which runs the top edge
        // straight across from the left notch to the right one.

        // ============================
        // 4. GAP 2 (Center → Right) + 5. RIGHT NOTCH
        // ============================
        if (hr > b) {
            ctx.lineTo(rightStart - rr, b);
            ctx.arcTo(rightStart, b, rightStart, b + rr, rr);
            ctx.lineTo(rightStart, hr - rr);
            ctx.arcTo(rightStart, hr, rightStart + rr, hr, rr);
            ctx.lineTo(w, hr);
        } else {
            // Fully retracted: run the top edge out to the right corner.
            ctx.lineTo(w, b);
        }

        // ============================
        // 6. CLOSE LOOP
        // ============================
        ctx.lineTo(w, 0);
        ctx.lineTo(0, 0);
        ctx.closePath();

        // Fill and rim, both onto the path we just built.
        Surface.finish(ctx, root.color, root.rimColor, root.rimWidth);
    }
}
