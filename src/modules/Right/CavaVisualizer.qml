import QtQuick
import "../../"

// CavaVisualizer — small reactive bar-graph, pure eye candy.
// The center notch used to show this whenever media was playing, but it only
// ever revealed on hover/pin, so it went mostly unseen. This is a compact
// copy of the same CavaService feed, always visible in the right bar instead.
Item {
    id: root

    readonly property int _displayBars: 9
    readonly property real _barW: 3

    readonly property bool _playing: CavaService.isPlaying

    implicitWidth:  44
    implicitHeight: 20

    opacity: _playing ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Row {
        anchors.centerIn: parent
        spacing: Math.max(1, (root.width - root._barW * root._displayBars) / Math.max(1, root._displayBars - 1))

        Repeater {
            model: root._displayBars
            delegate: Item {
                required property int index
                width:  root._barW
                height: root.height

                // Sample evenly across CavaService's 32 bars.
                readonly property int _srcIndex: Math.floor(index * CavaService.barCount / root._displayBars)
                readonly property real _amp: (CavaService.bars[_srcIndex] || 0) / 100.0

                Rectangle {
                    anchors.centerIn: parent
                    width:  root._barW
                    height: Math.max(2, _amp * (root.height / 2) * 2)
                    radius: width / 2
                    color:  Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28 + _amp * 0.72)

                    Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
