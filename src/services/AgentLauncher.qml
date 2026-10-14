import QtQuick
import Quickshell.Io
import Quickshell
import "../"

// AgentLauncher — live status + one-click launch for AI agent sessions,
// both routed through herdr (https://herdr.dev).
// Lives inside AgentsPopup.qml, its own floating popup.
//
// Edit the `agents` list below to match your actual setup (hosts, CLI
// names). "kind" agents are started via `herdr agent start --kind …`
// (tracked lifecycle: idle/working/blocked/done). "cmd" agents just run
// a shell command in a fresh pane (e.g. ssh to a remote host) — herdr
// still shows the pane, but without kind-specific lifecycle detection.

Item {
    id: root

    readonly property var agents: [
        {
            name:     "Claude",
            subtitle: "herdr · claude",
            icon:     "󰚩",
            mode:     "--kind",
            target:   "claude"
        },
        {
            name:     "Codex",
            subtitle: "herdr · codex",
            icon:     "󰘦",
            mode:     "--kind",
            target:   "codex"
        },
        {
            name:     "Hermes",
            subtitle: "odin · ssh",
            icon:     "󰒍",
            mode:     "--cmd",
            target:   "ssh -t odin hermes"
        }
    ]

    readonly property var kindAgents: root.agents.filter(function(a) { return a.mode === "--kind" })

    readonly property string _scriptDir: Quickshell.shellDir + "/src/scripts"

    // Natural (unclipped) height of all content below, so AgentsPopup can
    // size its background to actually contain it instead of guessing a
    // fixed constant.
    readonly property alias contentHeight: mainColumn.implicitHeight

    property int  composeIndex:       0
    property bool composeDropdownOpen: false

    // ── Launch ────────────────────────────────────────────────────────────────
    function launch(agent, promptText) {
        Quickshell.execDetached([
            "bash", root._scriptDir + "/agent_launch.sh",
            agent.name, agent.mode, agent.target, promptText || ""
        ])
        Popups.agentsOpen = false
    }

    function _submitCompose() {
        var agent = root.kindAgents[root.composeIndex]
        if (!agent) return
        var text = promptInput.text.trim()
        if (text === "") return
        root.launch(agent, text)
        promptInput.text = ""
    }

    onVisibleChanged: {
        if (!root.visible) return
        focusPromptTimer.restart()
    }

    Timer {
        id: focusPromptTimer
        interval: 60
        onTriggered: promptInput.forceActiveFocus()
    }

    // ── Live status ───────────────────────────────────────────────────────────
    property var liveAgents: []

    Process {
        id: statusProc
        command: ["herdr", "agent", "list"]
        running: false
        stdout: StdioCollector {
            id: statusBuf
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(statusBuf.text)
                    root.liveAgents = parsed.result.agents || []
                } catch (e) {
                    root.liveAgents = []
                }
            }
        }
    }

    function _statusColor(status) {
        switch (status) {
        case "working": return Qt.rgba(0.95, 0.72, 0.25, 1)
        case "idle":    return Qt.rgba(0.42, 0.85, 0.5,  1)
        case "done":    return Theme.active
        case "blocked": return Qt.rgba(0.95, 0.35, 0.35, 1)
        default:        return Qt.rgba(1, 1, 1, 0.35)
        }
    }

    function _focus(workspaceId) {
        Quickshell.execDetached(["bash", root._scriptDir + "/agent_focus.sh", workspaceId])
        Popups.agentsOpen = false
    }

    Timer {
        interval: 3000; running: root.visible; repeat: true
        triggeredOnStart: true
        onTriggered: { statusProc.running = false; statusProc.running = true }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Column {
        id: mainColumn
        anchors.fill: parent
        spacing: 14

        // Compose — pick an agent kind, write a prompt, launch straight into it
        Column {
            id: composeSection
            width: parent.width
            spacing: 6

            Text {
                text: "PROMPT"
                font.pixelSize: 11; font.weight: Font.DemiBold
                color: Qt.rgba(1,1,1,0.35)
            }

            // Kind selector
            Rectangle {
                id: kindButton
                width:  parent.width
                height: 40
                radius: 10
                color:        kindButtonH.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.05)
                border.width: 1
                border.color: Qt.rgba(1,1,1,0.10)
                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors {
                        left: parent.left; leftMargin: 12
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 8

                    Text {
                        text:  root.kindAgents.length > 0 ? root.kindAgents[root.composeIndex].icon : "󰚩"
                        color: Theme.active
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.kindAgents.length > 0
                              ? root.kindAgents[root.composeIndex].name
                              : "No agents configured"
                        color: Theme.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        width: parent.width - 14 - 8 - 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text:  root.composeDropdownOpen ? "󰅃" : "󰅀"
                        color: Qt.rgba(1,1,1,0.4)
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: kindButtonH; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.kindAgents.length > 0
                    onClicked: root.composeDropdownOpen = !root.composeDropdownOpen
                }
            }

            // Prompt box
            Rectangle {
                width:  parent.width
                height: 84
                radius: 12
                color:        Qt.rgba(1,1,1,0.06)
                border.width: 1
                border.color: promptInput.activeFocus
                              ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.50)
                              : Qt.rgba(1,1,1,0.12)
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Flickable {
                    id: promptFlick
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    contentWidth:  width
                    contentHeight: Math.max(height, promptInput.contentHeight)
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: promptInput
                        width:    promptFlick.width
                        wrapMode: TextEdit.Wrap
                        color:    Theme.text
                        font.pixelSize: 13
                        selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)

                        Keys.onReturnPressed: function(event) {
                            if (event.modifiers & Qt.ShiftModifier) event.accepted = false
                            else                                     root._submitCompose()
                        }
                        Keys.onEnterPressed: function(event) {
                            if (event.modifiers & Qt.ShiftModifier) event.accepted = false
                            else                                     root._submitCompose()
                        }
                        Keys.onEscapePressed: function(event) {
                            if (text !== "") { text = ""; event.accepted = true }
                            else               event.accepted = false
                        }

                        onCursorRectangleChanged: {
                            var r = cursorRectangle
                            if (promptFlick.contentY >= r.y)
                                promptFlick.contentY = r.y
                            else if (promptFlick.contentY + promptFlick.height <= r.y + r.height)
                                promptFlick.contentY = r.y + r.height - promptFlick.height
                        }
                    }
                }

                Text {
                    anchors { left: parent.left; leftMargin: 10; top: parent.top; topMargin: 10 }
                    text:  root.kindAgents.length > 0 ? "Ask an agent to… (Enter to launch)" : "No agents configured"
                    color: root.kindAgents.length > 0
                           ? Qt.rgba(1,1,1,0.22)
                           : Qt.rgba(0.95,0.35,0.35,0.55)
                    font.pixelSize: 13
                    visible: promptInput.text === ""
                }
            }
        }

        // Active sessions
        Column {
            width: parent.width
            spacing: 6
            visible: root.liveAgents.length > 0

            Text {
                text: "ACTIVE"
                font.pixelSize: 11; font.weight: Font.DemiBold
                color: Qt.rgba(1,1,1,0.35)
            }

            Repeater {
                model: root.liveAgents

                delegate: Rectangle {
                    required property var modelData

                    width:  parent.width
                    height: 44
                    radius: 10
                    color:        liveH.hovered ? Qt.rgba(1,1,1,0.06) : Qt.rgba(1,1,1,0.03)
                    border.color: Qt.rgba(1,1,1,0.06)
                    border.width: 1

                    Row {
                        anchors {
                            left: parent.left; leftMargin: 12
                            right: parent.right; rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 10

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: root._statusColor(modelData.agent_status)
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: modelData.agent + " · " + modelData.agent_status
                                font.pixelSize: 13
                                color: Theme.text
                            }
                            Text {
                                text: modelData.cwd
                                font.pixelSize: 11
                                font.family: Theme.fontMono
                                color: Qt.rgba(1,1,1,0.4)
                                elide: Text.ElideMiddle
                                width: 300
                            }
                        }
                    }

                    HoverHandler { id: liveH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root._focus(modelData.workspace_id)
                    }
                }
            }
        }

        // Launch
        Column {
            width: parent.width
            spacing: 6

            Text {
                text: "LAUNCH"
                font.pixelSize: 11; font.weight: Font.DemiBold
                color: Qt.rgba(1,1,1,0.35)
            }

            Repeater {
                model: root.agents

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool _blockedByCompose: modelData.mode === "--kind" && promptInput.text.trim() !== ""

                    width:  parent.width
                    height: 64
                    radius: 12

                    color:        rowH.hovered ? Qt.rgba(1,1,1,0.06) : Qt.rgba(1,1,1,0.04)
                    border.color: rowH.hovered
                                  ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                                  : Qt.rgba(1,1,1,0.07)
                    border.width: 1
                    opacity: _blockedByCompose ? 0.35 : 1

                    Behavior on color        { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                    Behavior on opacity      { NumberAnimation { duration: 100 } }

                    Row {
                        anchors {
                            left:   parent.left;  leftMargin:  14
                            right:  parent.right; rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 14

                        Rectangle {
                            width: 40; height: 40
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text:           modelData.icon
                                font.pixelSize: 18
                                color:          Theme.active
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text:           modelData.name
                                font.pixelSize: 14; font.weight: Font.DemiBold
                                color:          Theme.text
                            }
                            Text {
                                text:           modelData.subtitle
                                font.pixelSize: 12
                                font.family:    Theme.fontMono
                                color:          Qt.rgba(1,1,1,0.4)
                            }
                        }
                    }

                    HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !_blockedByCompose
                        onClicked: root.launch(modelData)
                    }
                }
            }
        }
    }

    // ── Kind dropdown overlay ─────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        visible: root.composeDropdownOpen
        onClicked: root.composeDropdownOpen = false
    }

    Rectangle {
        id: kindDropdownPanel
        visible: root.composeDropdownOpen
        x: composeSection.x + kindButton.x
        y: composeSection.y + kindButton.y + kindButton.height + 4
        width:  kindButton.width
        height: kindCol.implicitHeight + 8
        radius: 10
        color:        Theme.surface
        border.width: 1
        border.color: Qt.rgba(1,1,1,0.10)

        Column {
            id: kindCol
            x: 4; y: 4
            width:   parent.width - 8
            spacing: 2

            Repeater {
                model: root.kindAgents

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width:  parent.width
                    height: 34
                    radius: 8
                    color: kindOptH.hovered ? Qt.rgba(1,1,1,0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: modelData.icon; color: Theme.active; font.pixelSize: 13 }
                        Text { text: modelData.name; color: Theme.text;   font.pixelSize: 13 }
                    }

                    HoverHandler { id: kindOptH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.composeIndex = index
                            root.composeDropdownOpen = false
                        }
                    }
                }
            }
        }
    }
}
