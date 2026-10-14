import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../"

// AgentsPopup — AI agent launcher, floating center-screen. Pulled out of
// Dashboard's tab set the same way LauncherPopup was, in the same spirit as
// WorkspaceHUD.
//
// PanelWindow, not PopupWindow: this needs real keyboard focus on Wayland —
// see Dashboard.qml, which this focus/timer wiring mirrors.

PanelWindow {
    id: root

    // Named so BlurService's ^ghost- rule can reach it.
    WlrLayershell.namespace: "ghost-agents"

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int popupWidth:  480
    // Grown from actual content rather than a fixed constant, so the card
    // always contains the compose section + whatever's below it.
    readonly property int popupHeight: launcherContent.contentHeight + 16

    color:   "transparent"
    visible: windowVisible

    anchors.top:    true
    anchors.left:   true
    anchors.right:  true
    anchors.bottom: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    property bool wantsFocus: false
    WlrLayershell.keyboardFocus: wantsFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: focusGrabTimer
        interval: 15
        onTriggered: if (root.windowVisible && Popups.agentsOpen) root.wantsFocus = true
    }

    property bool windowVisible: false

    Connections {
        target: Popups
        function onAgentsOpenChanged() {
            if (Popups.agentsOpen) {
                closeTimer.stop()
                root.windowVisible = true
                focusGrabTimer.restart()
            } else {
                root.wantsFocus = false
                focusGrabTimer.stop()
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.animDuration + 20
        onTriggered: root.windowVisible = false
    }

    // ── Backdrop — closes popup when clicking outside the card ────────────────
    MouseArea {
        anchors.fill: parent
        onClicked:    Popups.agentsOpen = false
    }

    // ── Card — floats dead-center rather than growing out of a notch ─────────
    Item {
        id: sizer
        anchors.centerIn: parent
        width:  root.popupWidth
        height: root.popupHeight

        opacity: Popups.agentsOpen ? 1 : 0
        scale:   Popups.agentsOpen ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on scale   { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked:    {}
        }

        Rectangle {
            anchors.fill: parent
            radius:       Theme.cornerRadius
            color:        Theme.surface
            border.width: Theme.barRimWidth
            border.color: Theme.surfaceRim
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.margins: 8
            focus: true

            AgentLauncher {
                id: launcherContent
                anchors.fill: parent
                visible: Popups.agentsOpen
            }

            Keys.onEscapePressed: Popups.agentsOpen = false
        }
    }
}
