import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../"
import "../../components"
import "../"

// Right column — scrollable quick-settings grid.

StatCard {
    id: root
    padding: 0
    focus: true

    // ─────────────────────────────────────────────────────────────────────────
    //  Wi-Fi
    // ─────────────────────────────────────────────────────────────────────────
    property bool   wifiOn:   false
    property string wifiSSID: ""

    Process { id: wifiRadioRead; command: ["bash", "-c", "nmcli radio wifi"]; running: false
        stdout: SplitParser { onRead: function(l) {
            root.wifiOn = l.trim() === "enabled"
            // Expose to ShellState
            ShellState.wifiOn = root.wifiOn
        } } }
    Process { id: wifiSSIDRead
        command: ["bash", "-c",
            "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1 | cut -d: -f2"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.wifiSSID = l.trim() } } }
    Process { id: wifiToggleProc; command: []; running: false
        onRunningChanged: if (!running) _wifiPoll() }
    function _wifiPoll() {
        wifiRadioRead.running = false; wifiRadioRead.running = true
        wifiSSIDRead.running  = false; wifiSSIDRead.running  = true
    }
    function _wifiToggle() {
        root.wifiOn = !root.wifiOn           // optimistic — tile updates now
        ShellState.wifiOn = root.wifiOn
        wifiToggleProc.command = ["bash", "-c",
            "nmcli radio wifi " + (root.wifiOn ? "on" : "off")]
        wifiToggleProc.running = false
        wifiToggleProc.running = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Bluetooth
    // ─────────────────────────────────────────────────────────────────────────
    property bool   btOn:     false
    property string btDevice: ""

    Process { id: btPowerRead
        command: ["bash", "-c",
            "bluetoothctl show 2>/dev/null | grep '^\\s*Powered:' | awk '{print $2}'"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.btOn = l.trim() === "yes" } } }
    Process { id: btDeviceRead
        command: ["bash", "-c",
            "bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.btDevice = l.trim() } } }
    Process { id: btToggleProc; command: []; running: false
        onRunningChanged: if (!running) {
            _btPoll()
            ShellState.btPowered = root.btOn
            if (!root.btOn) ShellState.btConnected = false
        }
    }        
    function _btPoll() {
        btPowerRead.running  = false; btPowerRead.running  = true
        btDeviceRead.running = false; btDeviceRead.running = true
    }
    function _btToggle() {
        var turningOn = !root.btOn
        root.btOn = turningOn                // optimistic
        // Mirror to ShellState immediately so Network.qml bar icon reacts
        ShellState.btPowered = turningOn
        if (!turningOn) ShellState.btConnected = false

        btToggleProc.command = ["bash", "-c",
            "bluetoothctl power " + (turningOn ? "on" : "off")]
        btToggleProc.running = false
        btToggleProc.running = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Night Light  (hyprsunset)
    // ─────────────────────────────────────────────────────────────────────────
    property bool nightLightOn: false

    Process { id: nlCheck; command: ["bash", "-c", "pgrep -x hyprsunset"]; running: false
        stdout: SplitParser { onRead: function(l) { if (l.trim() !== "") root.nightLightOn = true } } }
    Process { id: nlProc; command: ["hyprsunset", "-t", "5600"]; running: false }
    Process { id: nlKill; command: ["bash", "-c", "pkill hyprsunset"]; running: false }
    function _nightLightToggle() {
        if (root.nightLightOn) {
            nlProc.running = false; nlKill.running = false; nlKill.running = true
            root.nightLightOn = false
        } else { nlProc.running = true; root.nightLightOn = true }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Caffeine  (systemd-inhibit)
    // ─────────────────────────────────────────────────────────────────────────
    property bool caffeineOn: false

    Process { id: caffeineCheck
        command: ["bash", "-c", "pgrep -f 'systemd-inhibit.*Caffeine'"]; running: false
        stdout: SplitParser { onRead: function(l) { if (l.trim() !== "") root.caffeineOn = true } } }
    Process { id: caffeineProc
        command: ["systemd-inhibit","--what=idle:sleep",
                  "--who=Ghost","--why=Caffeine mode","sleep","infinity"]
        running: false }
    Process { id: caffeineKill
        command: ["bash", "-c", "pkill -f 'systemd-inhibit.*Caffeine'"]; running: false
        onRunningChanged: if (!running) root.caffeineOn = false }
    function _caffeineToggle() {
        if (root.caffeineOn) {
            caffeineProc.running = false
            caffeineKill.running = false; caffeineKill.running = true
        } else { caffeineProc.running = true; root.caffeineOn = true }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Do Not Disturb
    // ─────────────────────────────────────────────────────────────────────────
    function _dndToggle() {
        ShellState.dnd = !ShellState.dnd
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Focus Mode  (hyprctl gaps)
    // ─────────────────────────────────────────────────────────────────────────
    property int _savedGapsIn: 5; property int _savedGapsOut: 10

    Process { id: readGapsIn
        command: ["bash", "-c",
            "hyprctl getoption general:gaps_in -j | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('int',5))\""]
        running: false
        stdout: SplitParser { onRead: function(l) { var v=parseInt(l.trim()); if(!isNaN(v)) root._savedGapsIn=v } }
        onRunningChanged: if (!running) readGapsOut.running = true }
    Process { id: readGapsOut
        command: ["bash", "-c",
            "hyprctl getoption general:gaps_out -j | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('int',10))\""]
        running: false
        stdout: SplitParser { onRead: function(l) { var v=parseInt(l.trim()); if(!isNaN(v)) root._savedGapsOut=v } }
        onRunningChanged: if (!running) applyFocusGaps.running = true }
    Process { id: applyFocusGaps
        command: ["bash", "-c",
            "hyprctl keyword general:gaps_in 0 && hyprctl keyword general:gaps_out 10"]
        running: false; onRunningChanged: if (!running) ShellState.focusMode = true }
    Process { id: restoreGaps; command: []; running: false
        onRunningChanged: if (!running) ShellState.focusMode = false }
    function _focusToggle() {
        if (ShellState.focusMode) {
            restoreGaps.command = ["bash", "-c",
                "hyprctl keyword general:gaps_in "  + root._savedGapsIn  +
                " && hyprctl keyword general:gaps_out " + root._savedGapsOut]
            restoreGaps.running = false; restoreGaps.running = true
        } else { readGapsIn.running = false; readGapsIn.running = true }
    }
    
    Connections {
        target: IpcManager
        function onFocusToggleRequested() {
            root._focusToggle()
        }
    }

// ─────────────────────────────────────────────────────────────────────────
    //  Filter  (Native Hyprland Lua)
    //
    //  Tile click: runs bash `find`, opens picker popup above the tile.
    //  Picker has "Off" at top + all available shaders.
    //  Selecting a shader: resolves absolute path and uses `hyprctl eval hl.config()`
    //  Selecting the active shader or "Off": clears the shader in Hyprland.
    // ─────────────────────────────────────────────────────────────────────────
    property string currentFilter:    ""
    property var    filterList:       []
    property bool   filterPickerOpen: false
    
    // Add your standard shader directories here (space-separated)
    property string shaderPaths: "~/.config/hypr/shaders ~/.local/share/hypr/shaders /usr/share/hyprshade/shaders ~/.local/src/Ghost/src/config/shaders ~/.config/quickshell/src/config/shaders"

    // Check process stays exactly the same — it already reads cleanly from Hyprland!
    Process {
        id: filterCheckProc
        command: ["bash", "-c",
            "hyprctl getoption decoration:screen_shader -j 2>/dev/null" +
            " | python3 -c \"" +
            "import sys,json,os;" +
            "d=json.load(sys.stdin);" +
            "s=d.get('str','').strip();" +
            "print('' if s in ('','[[EMPTY]]') else os.path.splitext(os.path.basename(s))[0])\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentFilter = text.trim()
            }
        }
    }

    Process {
        id: filterApplyProc
        command: []
        running: false
        onRunningChanged: if (!running) {
            filterCheckProc.running = false
            filterCheckProc.running = true
        }
    }

    function _filterApply(name) {
        var turningOff = (name === "" || name === root.currentFilter)
        root.currentFilter = turningOff ? "" : name

        var isLua = ShellState.configProvider === "lua"

        // Handle DPMS toggling based on provider
        var damageCmd = isLua 
            ? ` && hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' && hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'`
            : ` && hyprctl dispatch dpms off && hyprctl dispatch dpms on`

        if (turningOff) {
            var offCmd = isLua 
                ? "hyprctl eval \"hl.config({ decoration = { screen_shader = '' } })\""
                : "hyprctl keyword decoration:screen_shader '[[EMPTY]]'"
                
            filterApplyProc.command = ["bash", "-c", offCmd + damageCmd]
        } else {
            var resolveCmd =
                "TARGET=$(find " + root.shaderPaths +
                " -maxdepth 1 -type f \\( -name '" + name + ".glsl' -o -name '" + name + ".frag' \\)" +
                " 2>/dev/null | head -n 1); "
                
            var onCmd = isLua
                ? "if [ -n \"$TARGET\" ]; then hyprctl eval \"hl.config({ decoration = { screen_shader = '$TARGET' } })\"" + damageCmd + "; fi"
                : "if [ -n \"$TARGET\" ]; then hyprctl keyword decoration:screen_shader \"$TARGET\"" + damageCmd + "; fi"

            filterApplyProc.command = ["bash", "-c", resolveCmd + onCmd]
        }

        filterApplyProc.running = false
        filterApplyProc.running = true
        root.filterPickerOpen = false
    }

    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) {
            filterCheckProc.running = false
            filterCheckProc.running = true
        }
    }

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen) root.filterPickerOpen = false
        }
    }

    Process {
        id: filterListProc
        // Replaces `hyprshade ls` by searching your directories and stripping the file extensions
        command: ["bash", "-c", "find " + root.shaderPaths + " -maxdepth 1 -type f \\( -name '*.glsl' -o -name '*.frag' \\) 2>/dev/null | rev | cut -d/ -f1 | rev | sed 's/\\.[^.]*$//' | sort -u"]
        running: false
        stdout: SplitParser {
            onRead: function(l) {
                var n = l.trim()
                if (n !== "") root.filterList = root.filterList.concat([n])
            }
        }
    }

    function _filterOpen() {
        root.filterList = []
        filterListProc.running = false
        filterListProc.running = true
        root.filterPickerOpen  = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Polling timer
    // ─────────────────────────────────────────────────────────────────────────
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            _wifiPoll(); _btPoll()
        }
    }

    Component.onCompleted: {
        _wifiPoll(); _btPoll()
        nlCheck.running         = true
        caffeineCheck.running   = true
        filterCheckProc.running = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  UI
    // ─────────────────────────────────────────────────────────────────────────
    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 0

        Text {
            id: qsLbl; width: parent.width
            text: "QUICK SETTINGS"; font.pixelSize: 9; font.weight: Font.Bold
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
        }
        Item { width: parent.width; height: 8 }

        // ── Tile grid ─────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: root.height - 12 - qsLbl.height - 8

            Flickable {
                id: flick
                anchors.fill:   parent
                contentWidth:   width
                contentHeight:  tileGrid.implicitHeight + 8
                clip:           true
                boundsBehavior: Flickable.StopAtBounds

                component TglBtn: Rectangle {
                    id: btn
                    required property bool   on
                    required property string icon
                    required property string label
                    property  string sublabel: ""
                    signal toggled()

                    radius: 10
                    color: on
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                        : bH.hovered
                            ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                            : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
                    border.color: on
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
                        : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    Rectangle {
                        anchors { top: parent.top; right: parent.right; margins: 8 }
                        width: 6; height: 6; radius: 3
                        color: btn.on ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.18)
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Column {
                        anchors { left: parent.left; bottom: parent.bottom; margins: 9 }
                        spacing: 2
                        Text {
                            text: btn.icon; font.pixelSize: 17
                            color: btn.on ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.40)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        Text {
                            text: btn.label; font.pixelSize: 9; font.weight: Font.Medium
                            color: btn.on ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        Text {
                            visible: btn.sublabel !== ""
                            text:    btn.sublabel
                            font.pixelSize: 8; font.family: Theme.fontMono
                            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.65)
                            width: btn.width - 18; elide: Text.ElideRight
                        }
                    }
                    HoverHandler { id: bH; cursorShape: Qt.PointingHandCursor }
                    MouseArea    { anchors.fill: parent; onClicked: btn.toggled() }
                }

                Grid {
                    id: tileGrid
                    width: flick.width
                    columns: 2; spacing: 6

                    readonly property real btnW: (width - spacing) / 2
                    readonly property real btnH: btnW * 0.85

                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.wifiOn
                        icon: root.wifiOn ? "󰤨" : "󰤭"; label: "Wi-Fi"
                        sublabel: root.wifiOn && root.wifiSSID !== "" ? root.wifiSSID : ""
                        onToggled: root._wifiToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.btOn; icon: root.btOn ? "󰂱" : "󰂲"; label: "Bluetooth"
                        sublabel: root.btOn && root.btDevice !== "" ? root.btDevice : ""
                        onToggled: root._btToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.nightLightOn; icon: "󰖐"; label: "Night Light"
                        onToggled: root._nightLightToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.caffeineOn; icon: "󰅶"; label: "Caffeine"
                        onToggled: root._caffeineToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: ShellState.focusMode
                        icon: ShellState.focusMode ? "󱃕" : "󰍻"; label: "Focus Mode"
                        onToggled: root._focusToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: ShellState.dnd; icon: ShellState.dnd ? "󰂛" : "󰂚"
                        label: "Do Not Disturb"
                        onToggled: root._dndToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on:    ShellState.screenRecord || ScreenRecService.recording
                        icon:  ScreenRecService.recording ? "⏹" : "󰻂"
                        label: ScreenRecService.recording ? "Recording" : "Screen Capture"
                        onToggled: {
                            if (ScreenRecService.recording) {
                                ScreenRecService.stopRecording()
                            } else if (ShellState.screenRecord) {
                                ScreenRecService.cancelSetup()
                            } else {
                                Popups.closeAll()
                                ShellState.screenRecord = true
                            }
                        }
                    }
                    // Filter tile — opens picker, does not toggle directly
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on:       root.currentFilter !== ""
                        icon:     "󱡓"
                        label:    "Filter"
                        sublabel: root.currentFilter !== "" ? root.currentFilter : ""
                        onToggled: root._filterOpen()
                    }
                }
            }
        }
    }

    // ── Filter picker popup ───────────────────────────────────────────────────
    // Floats above the bottom-right tile. z:20 renders it over the grid.
    // Anchored bottom-right of the StatCard's inner area.
    Rectangle {
        id: filterPicker
        visible:  root.filterPickerOpen
        z:        20
        
        onVisibleChanged: {
            if (visible) {
                forceActiveFocus()
            } else {
                root.forceActiveFocus()
            }
        }

        Keys.onEscapePressed: function(event) {
            root.filterPickerOpen = false
            event.accepted = true // <--- Prevents the dashboard from closing
        }

        anchors {
            right:        parent.right
            bottom:       parent.bottom
            rightMargin:  12
            bottomMargin: 12
        }

        width:  180
        // Height fits "Off" row + all shader rows, capped at 280
        height: Math.min(280, pickerCol.implicitHeight + 16)
        radius: Theme.cornerRadius

        color: Qt.rgba(
            Math.min(1, Theme.background.r + 0.05),
            Math.min(1, Theme.background.g + 0.05),
            Math.min(1, Theme.background.b + 0.05),
            0.98)
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
        border.width: 1

        // Subtle entrance scale + fade
        opacity: root.filterPickerOpen ? 1 : 0
        scale:   root.filterPickerOpen ? 1 : 0.95
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        transformOrigin: Item.BottomRight

        // Dismiss when clicking outside the picker
        MouseArea {
            anchors.fill: parent
            // Swallow clicks so they don't fall through to tiles below
            onClicked: {} // intentionally empty — keeps picker open on internal clicks
        }

        Flickable {
            anchors { fill: parent; margins: 8 }
            contentWidth:   width
            contentHeight:  pickerCol.implicitHeight
            clip:           true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: pickerCol
                width: parent.width
                spacing: 2

                // Header label
                Text {
                    width: parent.width
                    text: "SHADER"
                    font.pixelSize: 9; font.weight: Font.Bold
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                    leftPadding: 4
                    bottomPadding: 4
                }

                // "Off" row — always first
                Rectangle {
                    width:  parent.width
                    height: 28
                    radius: 6
                    property bool isActive: root.currentFilter === ""
                    color: isActive
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                        : offH.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text {
                            text:           parent.parent.isActive ? "●" : "○"
                            font.pixelSize: 9
                            color: parent.parent.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.30)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            text:           "Off"
                            font.pixelSize: 12
                            color: parent.parent.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.65)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }
                    HoverHandler { id: offH; cursorShape: Qt.PointingHandCursor }
                    TapHandler   { onTapped: root._filterApply("") }
                }

                // Divider
                Rectangle {
                    width: parent.width; height: 1
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
                }

                // Shader rows — populated by hyprshade ls
                Repeater {
                    model: root.filterList
                    delegate: Rectangle {
                        required property string modelData
                        property bool isActive: root.currentFilter === modelData

                        width:  pickerCol.width
                        height: 28
                        radius: 6
                        color: isActive
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                            : itemH.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            Text {
                                text:           parent.parent.isActive ? "●" : "○"
                                font.pixelSize: 9
                                color: parent.parent.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.30)
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                text:           modelData
                                font.pixelSize: 12
                                color: parent.parent.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.65)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: pickerCol.width - 38
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }
                        HoverHandler { id: itemH; cursorShape: Qt.PointingHandCursor }
                        TapHandler   { onTapped: root._filterApply(modelData) }
                    }
                }

                // Empty state — shown while hyprshade ls is still running
                Text {
                    width:   parent.width
                    visible: root.filterList.length === 0
                    text:    "Loading…"
                    font.pixelSize: 11
                    color:   Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 4
                }
            }
        }
    }

    // Tap outside the picker to close it
    TapHandler {
        enabled: root.filterPickerOpen
        onTapped: root.filterPickerOpen = false
    }
}
