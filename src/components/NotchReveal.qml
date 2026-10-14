import QtQuick
import "../"

// ─── NotchReveal ────────────────────────────────────────────────────────────
// Decides whether one notch should be out of the top edge, and doubles as the
// hover strip that uncovers it.
//
// A notch comes out for three reasons:
//   pinned   — it holds something you must be able to reach without hunting
//              for it (an open popup, a recording control). Set by the parent.
//   hovered  — the pointer is inside this strip. The strip is meant to be
//              wider than the notch so the edges are forgiving.
//   held     — something the shell already knew about asked for it: call
//              reveal() and it stays out for holdDuration, then retracts.
//
// It carries no tap handling and its hover handler is non-blocking, so it
// never intercepts taps or hover meant for the content beneath it.
// ────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    // Above the notch content, not under it. Anything above a hover handler
    // that accepts hover (MouseArea with hoverEnabled or a cursorShape, other
    // HoverHandlers) steals hover from it; on top, with blocking off, this one
    // sees the pointer wherever it is and still lets the icons hover and click.
    z: 1000

    // Set autoHide false for the old always-on behaviour.
    property bool autoHide:     true
    property bool pinned:       false
    property int  hideDelay:    400
    property int  holdDuration: Theme.revealHoldDuration

    property bool hovered: false
    property bool held:    false

    readonly property bool revealed: !root.autoHide || root.pinned
                                     || root.hovered || root.held

    // Pull the notch out for holdDuration. Restarting mid-hold extends it, so
    // a burst of events (scrolling through workspaces) reads as one reveal.
    function reveal() {
        if (!root.autoHide) return
        root.held = true
        holdTimer.restart()
    }

    // Grace period so a pointer clipping the strip edge does not make the
    // notch stutter, and so you can travel into it without it retracting.
    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: root.hovered = false
    }

    Timer {
        id: holdTimer
        interval: root.holdDuration
        onTriggered: root.held = false
    }

    // Same mechanic as PopupSlide's self-hover (the mid-right sound control):
    // a passive HoverHandler that sees through child icons, a stable region
    // underneath it, and a close timer that absorbs edge flicker.
    // HoverHandlers block the handlers behind them by default (Qt 6.3+), so
    // every handler on a child icon must set `blocking: false` or hovering
    // that icon makes this one report a leave.
    HoverHandler {
        blocking: false
        enabled: !ShellState.focusMode
        onHoveredChanged: {
            if (hovered) {
                hideTimer.stop()
                root.hovered = true
            } else {
                hideTimer.restart()
            }
        }
    }

    // Focus mode fades the notches out entirely — drop any reveal that was in
    // flight so the bar does not come back the moment focus mode ends.
    Connections {
        target: ShellState
        function onFocusModeChanged() {
            if (ShellState.focusMode) {
                hideTimer.stop()
                holdTimer.stop()
                root.hovered = false
                root.held    = false
            }
        }
    }
}
