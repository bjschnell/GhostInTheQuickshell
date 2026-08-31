import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"
import "../services/"

// Unified confirmation modal — replaces GfxWarning.qml.
// Driven entirely by Popups.confirm* props.
// Call Popups.showConfirm() to open, Popups.cancelConfirm() to close.
//
// Supported confirmAction values — all routed through scripts/PowerControl.sh:
//   "shutdown"        → hyprshutdown --post-cmd "systemctl poweroff"
//   "reboot"          → hyprshutdown --post-cmd "systemctl reboot"
//   "logout"          → hyprshutdown
//   "lock"            → loginctl lock-session
//   "suspend"         → systemctl suspend

PanelWindow {
    id: root

    color: "transparent"

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    visible: Popups.confirmOpen

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ── Processes ─────────────────────────────────────────────────────────────
    Process {
        id: proc
        property var pendingCmd: []
        command: pendingCmd
    }

    // ── Action dispatch ───────────────────────────────────────────────────────
    function confirm() {
        const powerScript = Quickshell.shellDir + "/src/scripts/PowerControl.sh"

        switch (Popups.confirmAction) {
            case "shutdown":
                Popups.cancelConfirm()
                proc.pendingCmd = ["bash", powerScript, "shutdown"]
                proc.running = true
                break
            case "reboot":
                Popups.cancelConfirm()
                proc.pendingCmd = ["bash", powerScript, "reboot"]
                proc.running = true
                break
            case "logout":
                Popups.cancelConfirm()
                proc.pendingCmd = ["bash", powerScript, "logout"]
                proc.running = true
                break
            case "lock":
                Popups.cancelConfirm()
                proc.pendingCmd = ["loginctl", "lock-session"]
                proc.running = true
                break
            case "suspend":
                Popups.cancelConfirm()
                proc.pendingCmd = ["systemctl", "suspend"]
                proc.running = true
                break
        }
    }

    function cancel() {
        Popups.cancelConfirm()
    }

    // ── Dim overlay ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#99000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    // ── Confirm dialog ────────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width:  360
        height: col.implicitHeight + 48
        radius: Theme.notchRadius
        color:  Theme.background
        visible: Popups.confirmOpen

        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors {
                top:         parent.top
                left:        parent.left
                right:       parent.right
                topMargin:   24
                leftMargin:  24
                rightMargin: 24
            }
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    switch (Popups.confirmAction) {
                        case "shutdown":        return "⏻"
                        case "reboot":          return "↺"
                        case "logout":          return "⎋"
                        default:                return "⚠️"
                    }
                }
                font.pixelSize: 32
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           Popups.confirmTitle
                color:          Theme.text
                font.pixelSize: 15
                font.bold:      true
            }

            Text {
                width:          parent.width
                text:           Popups.confirmMessage
                color:          Qt.rgba(1, 1, 1, 0.65)
                font.pixelSize: 12
                wrapMode:       Text.WordWrap
                textFormat:     Text.RichText
                lineHeight:     1.4
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    width:  130
                    height: 38
                    radius: Theme.cornerRadius
                    color:  cancelHov.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text:           "Cancel"
                        color:          Theme.text
                        font.pixelSize: 13
                    }

                    HoverHandler { id: cancelHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.cancel() }
                }

                Rectangle {
                    width:  130
                    height: 38
                    radius: Theme.cornerRadius
                    color:  confirmHov.hovered ? "#cc3a3a" : "#993030"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text:           Popups.confirmLabel
                        color:          "white"
                        font.pixelSize: 13
                        font.bold:      true
                    }

                    HoverHandler { id: confirmHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.confirm() }
                }
            }
        }
    }

    // Escape / Enter
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onReturnPressed: root.confirm()
        Keys.onEscapePressed: root.cancel()
    }
}
