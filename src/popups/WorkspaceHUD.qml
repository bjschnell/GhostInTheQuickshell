import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../components"

// ─── WorkspaceHUD ───────────────────────────────────────────────────────────
// Replaces the old always-on corner widget. Nothing about workspace state is
// shown until you actually switch — then a numbered pill row flashes in
// center-screen and fades back out a beat later. Purely a readout: no click
// or scroll target, since switching here happens by keybind, not by mouse.
//
// The flash-in/hold/fade-out lifecycle itself lives in HudFlash — shared so a
// future volume/brightness OSD doesn't have to re-implement the same timers.
// ─────────────────────────────────────────────────────────────────────────────

PopupWindow {
    id: root

    required property var anchorWindow

    readonly property string screenName: root.anchorWindow.screenName

    property bool isScratchpad: false

    readonly property int cardWidth:  Math.max(workspaceRow.width, scratchpadLabel.implicitWidth) + Theme.hudPadding * 2
    readonly property int cardHeight: Theme.hudDotSize + Theme.hudPadding * 2

    implicitWidth:  cardWidth
    implicitHeight: cardHeight

    anchor.window: root.anchorWindow
    anchor.rect: Qt.rect(
        (root.anchorWindow.width - root.implicitWidth) / 2,
        (root.screen.height - root.implicitHeight) / 2 + Theme.hudCenterOffset,
        root.implicitWidth,
        root.implicitHeight
    )
    anchor.adjustment: PopupAdjustment.None

    color:   "transparent"
    visible: flash.windowVisible

    function reveal() { flash.reveal() }

    // ── Hyprland event listener ───────────────────────────────────────────────
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

            var monitor = monitorScoped
                ? String(event.data).split(",")[0]
                : (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")

            if (monitor !== "" && root.screenName !== "" && monitor !== root.screenName)
                return

            if (event.name === "activespecial" || event.name === "activespecialv2") {
                const wsName = String(event.data).split(',')[0]
                root.isScratchpad = (wsName !== "")
            }
            if (event.name === "destroyworkspace") {
                root.isScratchpad = false
            }

            root.reveal()
        }
    }

    // ── Card ───────────────────────────────────────────────────────────────
    HudFlash {
        id: flash
        anchors.fill: parent

        Row {
            id: workspaceRow
            anchors.centerIn: parent
            spacing: Theme.hudSpacing

            opacity: root.isScratchpad ? 0 : 1
            scale:   root.isScratchpad ? 0.8 : 1
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on scale   { NumberAnimation { duration: 200 } }

            Repeater {
                model: Hyprland.workspaces.values
                delegate: Rectangle {
                    id: pill

                    property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                    property bool isActive:   Hyprland.focusedWorkspace?.id === (index + 1)
                    property bool isOccupied: ws !== undefined
                    property bool isUrgent:   ws !== undefined && ws.urgent

                    height: Theme.hudDotSize
                    radius: height / 2
                    width:  isActive ? Theme.hudActiveWidth : Theme.hudDotSize

                    color: {
                        if (isActive)   return Theme.wsActive
                        if (isUrgent)   return Theme.wsUrgent
                        if (isOccupied) return Theme.wsOccupied
                        return Theme.wsEmpty
                    }

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    SequentialAnimation {
                        running: pill.isUrgent && !pill.isActive
                        loops:   Animation.Infinite

                        NumberAnimation {
                            target: pill; property: "scale"
                            to: 1.35; duration: 400
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: pill; property: "scale"
                            to: 1.0; duration: 400
                            easing.type: Easing.InOutSine
                        }
                    }

                    onIsUrgentChanged: {
                        if (!isUrgent) scale = 1.0
                    }
                }
            }
        }

        // ── Scratchpad label ─────────────────────────────────────────────────
        Text {
            id: scratchpadLabel
            anchors.centerIn: parent
            visible: opacity > 0
            opacity: root.isScratchpad ? 1 : 0
            text: "SCRATCHPAD"
            color: Theme.text
            font.family: Theme.fontMono
            font.bold: true
            font.pixelSize: 13

            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
}
