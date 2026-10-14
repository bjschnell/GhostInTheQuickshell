import QtQuick
import "../"

// Flash-in/hold/fade-out container for transient, center-screen overlays —
// the workspace-switch HUD today, a volume/brightness OSD tomorrow.
//
// Universal behavior lives here: reveal, hold, and a two-phase dismiss. The
// two phases are decoupled on purpose — the surface only unmaps once the
// content fade has actually finished (driven by the fade animation itself),
// not after a second timer guessing how long the first one takes.
//
// Each caller wires its own event into reveal() and supplies content — see
// WorkspaceHUD for the reference usage. Follows the same shape as
// PopupSlide: a plain Item wrapper, not a PopupWindow itself, so it composes
// inside whatever anchor/window setup the caller already has.
//
// Usage:
//   HudFlash {
//       id: flash
//       anchors.fill: parent
//       // content
//   }
//   (bind PopupWindow.visible to flash.windowVisible, call flash.reveal()
//   whenever the transient state should show)

Item {
    id: root

    // ── Timing — sourced from Theme's HUD numbers, override per-instance ──────
    property int holdDuration: Theme.hudHoldDuration
    property int fadeDuration: Theme.hudFadeDuration

    // ── Output ──────────────────────────────────────────────────────────────
    // Bind PopupWindow.visible to this.
    property bool windowVisible: false

    // True while the card is held open. Exposed so callers can react to it
    // (e.g. cross-fade between two pieces of content), but the card chrome
    // below already drives its own opacity/scale off it.
    property bool showing: false

    default property alias content: inner.data

    // A burst of events (cycling several workspaces quickly) reads as one
    // reveal — restarting holdTimer mid-hold just extends it.
    function reveal() {
        root.windowVisible = true
        root.showing       = true
        holdTimer.restart()
    }

    Timer {
        id:          holdTimer
        interval:    root.holdDuration
        onTriggered: root.showing = false
    }

    // ── Card ────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.hudRadius
        color:  Theme.surface
        border.width: Theme.barRimWidth
        border.color: Theme.surfaceRim

        opacity: root.showing ? 1 : 0
        scale:   root.showing ? 1 : 0.85

        // Phase 2 of the dismiss: only unmap the surface once this animation
        // has actually stopped running, not on a fixed delay that has to
        // guess the same duration as `fadeDuration` below.
        Behavior on opacity {
            NumberAnimation {
                duration: root.fadeDuration
                onRunningChanged: if (!running && !root.showing) root.windowVisible = false
            }
        }
        Behavior on scale {
            NumberAnimation { duration: root.fadeDuration; easing.type: Easing.OutCubic }
        }

        Item {
            id: inner
            anchors.fill: parent
        }
    }
}
