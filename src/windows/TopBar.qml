import Quickshell
import Quickshell.Wayland
import QtQuick
import "../components"
import "../modules/Right/"
import "../"
import "../shapes/"

PanelWindow {
    id: root

    property string screenName: screen ? screen.name : ""

    // Its own layer namespace, so a style that wants a blurred backdrop can be
    // matched by BlurService's layer rule without catching the border strips,
    // which share the default quickshell namespace.
    WlrLayershell.namespace: BlurService.layerNamespace

    color: "transparent"

    anchors {
        top:   true
        left:  true
        right: true
    }

    Binding { target: ShellState; property: "topBarRWidth"; value: root.rWidth }

    // ── Height shrinks to a border strip in focus mode ───────────────────────
    // Safe to animate on PanelWindow (anchored, no position jank).
    // PopupWindow is the one that must never have animated implicitHeight.
    implicitHeight: ShellState.focusMode ? Theme.borderWidth : Theme.notchHeight
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    // A non-exclusive bar reserves nothing, so windows sit at full screen and a
    // revealed notch floats over them. Reserving space instead would mean every
    // reveal resized every tiled window and resized it back again.
    exclusiveZone: ShellState.barReservesSpace ? Theme.exclusionGap : 0
    Behavior on exclusiveZone {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    // ── Input mask ─────────────────────────────────────────────────
    // Without a mask the bar takes every click in the full-width strip it
    // covers. That was harmless while it reserved that strip from windows, but
    // a floating bar has window content underneath, and anything the mask
    // covers is a click that content never sees.
    //
    // So each side is trimmed to its trigger sliver while retracted — the
    // screen edge stops the pointer, so a few px catches every deliberate
    // reveal — and opens to the full notch height once revealed, taking
    // whichever is wider, the notch or its reveal strip.
    readonly property int _sliverHeight: ShellState.barReservesSpace
                                         ? Theme.notchHeight
                                         : Theme.revealStripHeight

    function _maskHeight(revealed) {
        return revealed ? Theme.notchHeight : root._sliverHeight
    }

    // Same width retracted or revealed, and the same as the hover strip: a mask
    // that changed width with `revealed` left part of the strip outside the
    // input region, so the pointer "left" while still visibly over the notch.
    readonly property int _rightMaskWidth: Math.max(rightReveal.width, root.rWidth)

    mask: Region {
        Region {
            x:      root.width - root._rightMaskWidth
            y:      0
            width:  root._rightMaskWidth
            height: root._maskHeight(rightReveal.revealed)
        }
    }

    // Width matches sizer open width: popupWidth + notchRadius (fw) in both popups
    property int rWidth: Math.max(
        Theme.rNotchMinWidth,
        Math.min(Theme.rNotchMaxWidth, rightContent.implicitWidth + Theme.notchPadding * 2)
    )

    // ── Notch auto-hide ──────────────────────────────────────────────────────
    // Each notch stays retracted into the top edge until it has something to
    // say. NotchReveal owns that decision and doubles as the hover strip; the
    // strips are declared before the content layer so they sit underneath it
    // and never intercept taps meant for the notch contents.
    //
    // A notch is pinned open whenever it holds controls you must be able to
    // reach without hunting for them — anything anchored to it that is open.

    // Right — arch menu trigger, layout indicator, network, audio, clock,
    // tray, notifications. Every popup that drops out of this notch pins it,
    // and so does an incoming toast, which is what makes a notification
    // arrive rather than merely be available.
    NotchReveal {
        id: rightReveal
        // Fixed at the widest the notch can ever get (rNotchMaxWidth), not
        // reactive to its own `revealed` — a revealed-dependent width here
        // caused a resize-triggers-hover-loss-triggers-un-reveal loop.
        width:  Math.max(Theme.rightRevealWidth, Theme.rNotchMaxWidth)
        height: parent.height
        anchors.right: parent.right
        anchors.top:   parent.top

        autoHide:  Theme.rightAutoHide
        hideDelay: Theme.rightHideDelay
        pinned:    Popups.networkOpen || Popups.notificationsOpen
                   || Popups.audioOpen || Popups.quickOpen
                   || Popups.trayMenuOpen || Popups.notificationToastOpen
                   || Popups.audioTriggerHovered
                   || Popups.notificationsTriggerHovered
                   || Popups.archMenuOpen || Popups.archMenuTriggerHovered
    }

    // ── Border strip (focus mode) ────────────────────────────────────────────
    // Painted behind the notch content layer. Visible only when focus mode
    // fades the notches out. Uses the same bar color so it reads as a thin
    // edge strip matching the side border strips.
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: ShellState.focusMode ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }
    }

    // ── Notch content (fades out in focus mode) ──────────────────────────────
    Item {
        anchors.fill: parent
        opacity: ShellState.focusMode ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }
        
        states: [
        State {
            name: "notifications"
            when: Popups.notificationsOpen
            PropertyChanges { target: root; rWidth: Theme.notificationsWidth + Theme.notchRadius }
        },
        State {
            name: "network"
            when: Popups.networkOpen && !Popups.notificationsOpen
            PropertyChanges { target: root; rWidth: Theme.networkPopupWidth + Theme.notchRadius }
        },
        State {
            name: "toast"
            when: Popups.notificationToastOpen && !Popups.notificationsOpen && !Popups.networkOpen
            PropertyChanges { target: root; rWidth: Theme.notificationToastWidth + Theme.notchRadius + Theme.notchPadding -3 }
        }
    ]

    transitions: [
        Transition {
            // This animation ONLY runs when switching between popups (and toasts) and the base state.
            NumberAnimation { property: "rWidth"; duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }
    ]

        SeamlessBarShape {
            id: barShape
            anchors.fill: parent
            leftWidth:   0
            centerWidth: 0
            rightWidth:  root.rWidth

            leftDepth:   Theme.borderWidth
            centerDepth: Theme.borderWidth
            rightDepth:  rightReveal.revealed  ? Theme.notchHeight : Theme.borderWidth

            Behavior on rightDepth {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
            }
        }

        Item {
            id:            rightNotch
            width:         root.rWidth
            height:        Theme.notchHeight
            anchors.right: parent.right

            opacity: rightReveal.revealed ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Math.round(Theme.animDuration * 0.6)
                    easing.type: Easing.InOutCubic
                }
            }

            clip: true

            RightContent {
                id: rightContent
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Theme.notchPadding
            }
        }
    }
}