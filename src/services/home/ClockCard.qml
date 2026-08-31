import QtQuick
import "../../"
import "../../components"

// ClockCard — wall clock. HH stacked over MM with seconds beside the stack.

StatCard {
    id: root
    padding: 0

    property string _hStr: "00"
    property string _mStr: "00"
    property string _sec:  "00"

    function _zp(n) { return n < 10 ? "0" + n : "" + n }

    function _tick() {
        var d = new Date()
        _hStr = _zp(d.getHours())
        _mStr = _zp(d.getMinutes())
        _sec  = _zp(d.getSeconds())
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root._tick()
    }

    Component.onCompleted: _tick()

    Item {
        anchors.fill: parent

        Row {
            anchors.centerIn: parent
            spacing: 10

            // HH stacked above MM with diagonal offset
            Item {
                anchors.verticalCenter: parent.verticalCenter
                // Width fits both texts plus the one-char offset
                readonly property int charOffset: 40
                width:  hhText.implicitWidth + charOffset
                height: hhText.implicitHeight + mmText.implicitHeight - 8

                Text {
                    id: hhText
                    anchors.left: parent.left
                    anchors.top:  parent.top
                    text: root._hStr
                    font.pixelSize: 72; font.weight: Font.Bold
                    font.family: Theme.fontMono; font.letterSpacing: -4
                    color: Theme.text
                }
                Text {
                    id: mmText
                    anchors.left: parent.left
                    anchors.leftMargin: parent.charOffset
                    anchors.top:  hhText.bottom
                    anchors.topMargin: -8
                    text: root._mStr
                    font.pixelSize: 72; font.weight: Font.Bold
                    font.family: Theme.fontMono; font.letterSpacing: -4
                    color: Theme.active
                }
            }

            // Seconds — vertically centered beside the stack
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root._sec
                font.pixelSize: 22; font.weight: Font.Medium
                font.family: Theme.fontMono
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
            }
        }
    }
}
