import QtQuick
import "../../"
import "../../components"

// ScreenRecCard — full screen-record controls, given their own dedicated
// Home section instead of the icon-only trigger in the right bar. Restores
// the capture-target / audio-source pickers and the discard button that the
// old center-notch strip (CenterContent, removed) had — just laid out for a
// card instead of a thin bar strip.
StatCard {
    id: root
    padding: 12

    readonly property bool recording: ScreenRecService.recording

    Column {
        anchors.fill: parent
        spacing: 12

        // ── Header ────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: 20

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Text {
                    text: "⏺"
                    font.pixelSize: 14
                    color: root.recording ? Qt.rgba(1, 0.3, 0.3, 1) : Theme.active
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: root.recording
                        loops:   Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: "Screen Record"
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.recording
                text: ScreenRecService.elapsedDisplay
                font.family: Theme.fontMono
                font.pixelSize: 12
                font.bold: true
                color: Theme.text
            }
        }

        // ── Idle — pickers + Record button ───────────────────────────────────
        Column {
            width:   parent.width
            spacing: 12
            visible: !root.recording

            Column {
                width: parent.width
                spacing: 5

                Text { text: "CAPTURE"; font.pixelSize: 10; font.bold: true; color: Qt.rgba(1,1,1,0.4) }

                Row {
                    spacing: 6
                    Repeater {
                        model: ["screen", "window", "region"]
                        delegate: OptionPill {
                            required property string modelData
                            icon:     ScreenRecService._captureIcons[modelData]  ?? ""
                            selected: ScreenRecService.captureTarget === modelData
                            onClicked: ScreenRecService.captureTarget = modelData
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 5

                Text { text: "AUDIO"; font.pixelSize: 10; font.bold: true; color: Qt.rgba(1,1,1,0.4) }

                Row {
                    spacing: 6
                    Repeater {
                        model: ["mic", "system", "none"]
                        delegate: OptionPill {
                            required property string modelData

                            readonly property var _icons: ({ mic: "󰍬", system: "󰕾", none: "󰖁" })
                            icon: _icons[modelData] ?? ""
                            selected: {
                                if (modelData === "none")   return !ScreenRecService.audioMic && !ScreenRecService.audioSystem
                                if (modelData === "mic")    return ScreenRecService.audioMic
                                return ScreenRecService.audioSystem
                            }
                            onClicked: {
                                if (modelData === "none") {
                                    ScreenRecService.audioMic    = false
                                    ScreenRecService.audioSystem = false
                                } else if (modelData === "mic") {
                                    ScreenRecService.audioMic = !ScreenRecService.audioMic
                                } else {
                                    ScreenRecService.audioSystem = !ScreenRecService.audioSystem
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width:  parent.width
                height: 30
                radius: height / 2
                color:  recordHover.hovered ? Qt.rgba(0.9, 0.2, 0.2, 0.85) : Qt.rgba(0.8, 0.1, 0.1, 0.7)
                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle { width: 7; height: 7; radius: 4; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Record"; font.pixelSize: 12; font.weight: Font.Medium; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: recordHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Popups.closeAll()
                        ScreenRecService.startRecording()
                    }
                }
            }
        }

        // ── Recording — Stop / Discard ───────────────────────────────────────
        Row {
            width:   parent.width
            spacing: 8
            visible: root.recording

            Rectangle {
                width:  (parent.width - parent.spacing) / 2
                height: 30
                radius: height / 2
                color:  stopHover.hovered ? Qt.rgba(0.9, 0.2, 0.2, 0.55) : Qt.rgba(0.8, 0.1, 0.1, 0.32)
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "Stop"; font.pixelSize: 12; color: "#ff9999" }
                HoverHandler { id: stopHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ScreenRecService.stopRecording() }
            }

            Rectangle {
                width:  (parent.width - parent.spacing) / 2
                height: 30
                radius: height / 2
                color:  discardHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                    anchors.centerIn: parent
                    text: "Discard"
                    font.pixelSize: 12
                    color: discardHover.hovered ? Qt.rgba(1, 0.4, 0.4, 1.0) : Qt.rgba(1, 1, 1, 0.5)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                HoverHandler { id: discardHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ScreenRecService.discardRecording() }
            }
        }
    }

    // ── Option pill — icon-only, highlight shows selection ───────────────────
    component OptionPill: Item {
        id: pill

        property string icon:     ""
        property bool   selected: false
        signal clicked()

        width:  28
        height: 28

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: pill.selected
                   ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                   : pillHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            border.color: pill.selected
                          ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                          : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            Behavior on color        { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }

        Text {
            anchors.centerIn: parent
            text:  pill.icon
            font.pixelSize: 13
            color: pill.selected ? Theme.active : Qt.rgba(1, 1, 1, 0.6)
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: pill.clicked() }
    }
}
