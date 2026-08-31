import Quickshell
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

    exclusiveZone: ShellState.focusMode ? 0 : Theme.exclusionGap
    Behavior on exclusiveZone {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
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

    // ── Center island auto-hide ──────────────────────────────────────────────
    // The center notch stays retracted into the top edge until the pointer
    // enters the reveal strip above it. It only ever carried the active window
    // title, which Hyprland already tells you by highlighting the window.
    //
    // Pinned open whenever the notch holds controls you must be able to reach
    // without hunting for them: the dashboard anchors to it, and the screen
    // recorder puts its record / stop / discard buttons inside it.
    readonly property bool centerPinned: Popups.dashboardOpen
                                         || ShellState.screenRecord
                                         || ScreenRecService.recording

    property bool centerHovered: false

    readonly property bool centerRevealed: !Theme.centerAutoHide
                                           || root.centerPinned
                                           || root.centerHovered

    // Grace period so a pointer clipping the strip edge does not make the
    // island stutter, and so you can travel into it without it retracting.
    Timer {
        id: centerHideTimer
        interval: Theme.centerHideDelay
        onTriggered: root.centerHovered = false
    }

    // Reveal strip — a little wider than the notch so the edges are forgiving.
    // Declared before the content layer so it sits underneath it and never
    // intercepts taps meant for CenterContent.
    Item {
        id: centerRevealZone
        width:  Theme.centerRevealWidth
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top

        HoverHandler {
            enabled: !ShellState.focusMode
            onHoveredChanged: {
                if (hovered) {
                    centerHideTimer.stop()
                    root.centerHovered = true
                } else {
                    centerHideTimer.restart()
                }
            }
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

            centerDepth: root.centerRevealed ? Theme.notchHeight : Theme.borderWidth
            Behavior on centerDepth {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
            }
        }

        Item {
            id:           leftNotch
            width:        root.lWidth
            height:       Theme.notchHeight
            anchors.left: parent.left

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

            // Fades faster than the notch retracts so the text is gone before
            // the shape behind it is. visible gates hit-testing, so a retracted
            // island cannot be tapped or scrolled by accident.
            opacity: root.centerRevealed ? 1 : 0
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