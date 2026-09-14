import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../components"
import "../modules/Center/"
import "../modules/Right/"
import "../modules/Left/"
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

    Binding { target: ShellState; property: "topBarLWidth"; value: root.lWidth }
    Binding { target: ShellState; property: "topBarCWidth"; value: root.cWidth }
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

    readonly property int _leftMaskWidth: leftReveal.revealed
        ? Math.max(Theme.leftRevealWidth, root.lWidth)
        : Theme.leftRevealWidth

    readonly property int _centerMaskWidth: centerReveal.revealed
        ? Math.max(Theme.centerRevealWidth, root.cWidth)
        : Theme.centerRevealWidth

    readonly property int _rightMaskWidth: rightReveal.revealed
        ? Math.max(Theme.rightRevealWidth, root.rWidth)
        : Theme.rightRevealWidth

    mask: Region {
        Region {
            x:      0
            y:      0
            width:  root._leftMaskWidth
            height: root._maskHeight(leftReveal.revealed)
        }
        Region {
            x:      Math.round((root.width - root._centerMaskWidth) / 2)
            y:      0
            width:  root._centerMaskWidth
            height: root._maskHeight(centerReveal.revealed)
        }
        Region {
            x:      root.width - root._rightMaskWidth
            y:      0
            width:  root._rightMaskWidth
            height: root._maskHeight(rightReveal.revealed)
        }
    }

    readonly property int lWidth: Math.max(
        Theme.lNotchMinWidth,
        Math.min(Theme.lNotchMaxWidth,
                 leftContent.implicitWidth + Theme.notchPadding * 2)
    )

    // cWidth uses Popups.dashboardPageWidth when the dashboard is open,
    // so the center notch tracks the active tab's declared width.
    property int cWidth: Popups.dashboardOpen
        ? Popups.dashboardPageWidth
        : Math.max(
            Theme.cNotchMinWidth,
            Math.min(Theme.cNotchMaxWidth,
                     centerContent.implicitWidth + Theme.notchPadding * 2)
          )
    Behavior on cWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
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

    // Left — workspaces, layout, the Arch menu trigger. Comes out on its own
    // whenever the focused workspace changes (see the Hyprland listener below),
    // which is the moment you actually want to know which one you landed on.
    NotchReveal {
        id: leftReveal
        width:  Theme.leftRevealWidth
        height: parent.height
        anchors.left: parent.left
        anchors.top:  parent.top

        autoHide:  Theme.leftAutoHide
        hideDelay: Theme.leftHideDelay
        pinned:    Popups.archMenuOpen || Popups.archMenuTriggerHovered
    }

    // Center — only ever carried the active window title, which Hyprland
    // already tells you by highlighting the window. The dashboard anchors to
    // it, and the screen recorder puts its record / stop / discard buttons
    // inside it, so both pin it open.
    NotchReveal {
        id: centerReveal
        width:  Theme.centerRevealWidth
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top

        autoHide:  Theme.centerAutoHide
        hideDelay: Theme.centerHideDelay
        pinned:    Popups.dashboardOpen
                   || ShellState.screenRecord
                   || ScreenRecService.recording
    }

    // Right — network, audio, clock, tray, notifications. Every popup that
    // drops out of this notch pins it, and so does an incoming toast, which is
    // what makes a notification arrive rather than merely be available.
    NotchReveal {
        id: rightReveal
        width:  Theme.rightRevealWidth
        height: parent.height
        anchors.right: parent.right
        anchors.top:   parent.top

        autoHide:  Theme.rightAutoHide
        hideDelay: Theme.rightHideDelay
        pinned:    Popups.networkOpen || Popups.notificationsOpen
                   || Popups.audioOpen || Popups.quickOpen
                   || Popups.trayMenuOpen || Popups.notificationToastOpen
                   || Popups.networkTriggerHovered
                   || Popups.audioTriggerHovered
                   || Popups.notificationsTriggerHovered
    }

    // ── Workspace switches pull the left notch out ───────────────────────────
    // The dots carry no numbers, so a switch is the one moment the left notch
    // is worth looking at. Reveal state is per-screen (one TopBar per monitor),
    // so only the bar on the monitor that actually changed comes out.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            var monitorScoped = event.name === "focusedmon"
                                || event.name === "focusedmonv2"
                                || event.name === "activemonitor"

            var isWorkspaceEvent = monitorScoped
                                   || event.name === "workspace"
                                   || event.name === "workspacev2"
                                   || event.name === "activespecial"
                                   || event.name === "activespecialv2"

            if (!isWorkspaceEvent) return

            // Monitor events name their monitor up front. Workspace events do
            // not, so ask Hyprland which monitor is focused.
            var monitor = monitorScoped
                ? String(event.data).split(",")[0]
                : (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")

            // An unnamed monitor reveals on every bar rather than none — a
            // stray flash beats a notch that never answers.
            if (monitor !== "" && root.screenName !== "" && monitor !== root.screenName)
                return

            leftReveal.reveal()
        }
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
            leftWidth:   root.lWidth
            centerWidth: root.cWidth
            rightWidth:  root.rWidth

            leftDepth:   leftReveal.revealed   ? Theme.notchHeight : Theme.borderWidth
            centerDepth: centerReveal.revealed ? Theme.notchHeight : Theme.borderWidth
            rightDepth:  rightReveal.revealed  ? Theme.notchHeight : Theme.borderWidth

            Behavior on leftDepth {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
            }
            Behavior on centerDepth {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
            }
            Behavior on rightDepth {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
            }
        }

        Item {
            id:           leftNotch
            width:        root.lWidth
            height:       Theme.notchHeight
            anchors.left: parent.left

            // Content fades faster than the notch retracts, so it is gone
            // before the shape behind it is. visible gates hit-testing, so a
            // retracted notch cannot be clicked or scrolled by accident.
            opacity: leftReveal.revealed ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Math.round(Theme.animDuration * 0.6)
                    easing.type: Easing.InOutCubic
                }
            }

            LeftContent {
                id: leftContent
                anchors.centerIn: parent
            }
        }

        Item {
            id:               centerNotch
            width:            root.cWidth
            height:           Theme.notchHeight
            anchors.centerIn: parent

            opacity: centerReveal.revealed ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Math.round(Theme.animDuration * 0.6)
                    easing.type: Easing.InOutCubic
                }
            }

            CenterContent {
                id: centerContent
                anchors.centerIn: parent
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