import QtQuick
import "../"

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
    property color color:         Theme.background

    // How far the center notch hangs below the top edge, in px.
    // notchHeight = fully out, topBorderWidth = fully retracted (drawn as a
    // flat run of top edge, so left and right stay untouched).
    property real centerDepth:    Theme.notchHeight

    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()
    onLeftWidthChanged:   requestPaint()
    onCenterWidthChanged: requestPaint()
    onRightWidthChanged:  requestPaint()
    onCenterDepthChanged: requestPaint()
    onColorChanged:       requestPaint()

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
        ctx.fillStyle = root.color;

        // ============================
        // 1. LEFT NOTCH
        // ============================
        ctx.moveTo(0, h);
        ctx.lineTo(leftW - r, h);
        ctx.arcTo(leftW, h, leftW, h - r, r);
        ctx.lineTo(leftW, b + r);
        ctx.arcTo(leftW, b, leftW + r, b, r);

        // ============================
        // 2. + 3. GAP 1 → CENTER NOTCH
        // ============================
        // The center notch retracts by depth, not by width, so it melts into
        // the top edge instead of shrinking to a sliver. Its corner radius is
        // clamped to whatever vertical room is left, otherwise the two arcs
        // overlap and Canvas draws a knot on the way down.
        var hc = Math.max(b, Math.min(h, root.centerDepth))
        var cr = Math.max(0, Math.min(r, (hc - b) / 2, centerW / 2))

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
        // 4. GAP 2 (Center → Right)
        // ============================
        ctx.lineTo(rightStart - r, b);

        // ============================
        // 5. RIGHT NOTCH
        // ============================
        ctx.arcTo(rightStart, b, rightStart, b + r, r);
        ctx.lineTo(rightStart, h - r);
        ctx.arcTo(rightStart, h, rightStart + r, h, r);
        ctx.lineTo(w, h);

        // ============================
        // 6. CLOSE LOOP
        // ============================
        ctx.lineTo(w, 0);
        ctx.lineTo(0, 0);
        ctx.lineTo(0, h);

        ctx.fill();
    }
}
