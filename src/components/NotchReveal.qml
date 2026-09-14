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
// Place it BEFORE the notch content in the parent so it sits underneath and
// never intercepts taps meant for the content itself.
// ────────────────────────────────────────────────────────────────────────────

Item {
    id: root

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

    HoverHandler {
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
