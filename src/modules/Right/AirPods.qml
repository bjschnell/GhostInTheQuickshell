import QtQuick
import Quickshell.Io
import "../../"

// AirPods — one-click connect/disconnect for the first paired device whose
// name matches _match. Hidden when the adapter is off or nothing matches.
Item {
    id: root

    readonly property var _match: /airpod/i

    property string _mac:       ""
    property bool   _connected: false
    property bool   _busy:      false

    implicitWidth:  icon.implicitWidth + 4
    implicitHeight: icon.implicitHeight
    visible: _mac !== ""

    Process {
        id: pollProc
        command: [
            "bash", "-c",
            "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' || exit 0; " +
            "echo 'PAIRED:';    bluetoothctl devices Paired    2>/dev/null; " +
            "echo 'CONNECTED:'; bluetoothctl devices Connected 2>/dev/null"
        ]
        running: false
        stdout: StdioCollector { onStreamFinished: root._parse(text) }
    }

    Process {
        id: actionProc
        command: []
        running: false
        onRunningChanged: if (!running) { root._busy = false; root._poll() }
    }

    Timer { interval: 5000; repeat: true; running: true; onTriggered: root._poll() }
    Component.onCompleted: _poll()

    function _poll() {
        if (pollProc.running || actionProc.running) return
        pollProc.running = true
    }

    function _parse(raw) {
        var lines = raw.split("\n")
        var mode = ""; var mac = ""; var conn = false
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "PAIRED:")    { mode = "paired";    continue }
            if (line === "CONNECTED:") { mode = "connected"; continue }
            var m = line.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/)
            if (!m || !root._match.test(m[2])) continue
            if (mode === "paired" && mac === "") mac = m[1]
            if (mode === "connected" && m[1] === mac) conn = true
        }
        root._mac       = mac
        root._connected = conn
    }

    function _toggle() {
        if (_busy || _mac === "") return
        _busy = true
        actionProc.command = ["bluetoothctl", _connected ? "disconnect" : "connect", _mac]
        actionProc.running = true
    }

    HoverHandler { id: hov }

    Text {
        id: icon
        anchors.centerIn: parent
        text:           root._connected ? "󱡏" : "󱡐"
        font.pixelSize: 15
        color: root._connected ? (hov.hovered ? Theme.active : Theme.text) : Qt.rgba(1,1,1,0.32)
        Behavior on color { ColorAnimation { duration: 200 } }

        SequentialAnimation on opacity {
            running: root._busy; loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 500; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) icon.opacity = 1
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root._toggle()
    }
}
