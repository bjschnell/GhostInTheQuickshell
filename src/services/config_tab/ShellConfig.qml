import QtQuick
import "../"
import "../../"
import "../../components"

Item {
    id: root

    property string _page: "themes"

    readonly property var _tabs: [
        { key: "themes",   icon: "󰏘", label: "Themes"   },
        { key: "keybinds", icon: "󰌌", label: "Keybinds" },
    ]

    Row {
        anchors {
            fill:    parent
            margins: 8
        }
        spacing: 12

        // ── Left: tab column (30%) ────────────────────────────────────────────
        Rectangle {
            width:  Math.floor((parent.width - parent.spacing) * 0.30)
            height: parent.height
            radius: Theme.cornerRadius
            color:  Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            TabSwitcher {
                orientation: "vertical"
                anchors {
                    top:              parent.top
                    bottom:           parent.bottom
                    left:             parent.left
                    right:            parent.right
                    topMargin:        8
                    bottomMargin:     8
                    leftMargin:       6
                    rightMargin:      6
                }
                currentPage: root._page
                model:       root._tabs
                onPageChanged: function(key) { root._page = key }
            }
        }

        // ── Right: content area (70%) ─────────────────────────────────────────
        Item {
            width:  parent.width - Math.floor((parent.width - parent.spacing) * 0.30) - parent.spacing
            height: parent.height

            Item {
                anchors.fill: parent
                visible: root._page === "themes"
                ThemesPage { anchors.fill: parent }
            }
            Item {
                anchors.fill: parent
                visible: root._page === "keybinds"
                KeybindsPage { anchors.fill: parent }
            }
        }
    }
}
