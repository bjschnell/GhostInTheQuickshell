.pragma library

// ─── surface.js ─────────────────────────────────────────────────────────────
// The shell's surface treatment, shared by every painted surface: the bar
// silhouette (SeamlessBarShape) and every popup (PopupShape).
//
// Both are Canvases that build a path and want the same finish on it, so the
// finish lives here rather than being written twice and drifting apart.
//
// Call finish() with the path already built and still current — it fills and
// rims that exact path, so everything lands inside the silhouette with no
// masking and no clipping of its own.
//
// What a style can ask for:
//   fill   the tinted surface color, alpha included
//   rim    color of the hairline stroked along the silhouette (alpha 0 draws
//          none). A translucent surface reads as washed out without one.
// ────────────────────────────────────────────────────────────────────────────

function finish(ctx, fill, rim, rimWidth) {
    ctx.fillStyle = fill
    ctx.fill()

    if (rimWidth > 0 && rim.a > 0) {
        // Centered on the path, so the outer half lands on transparent pixels
        // and reads as a soft halo rather than a drawn border.
        ctx.lineWidth = rimWidth
        ctx.strokeStyle = rim
        ctx.stroke()
    }
}
