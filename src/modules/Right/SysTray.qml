import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import "../../components"
import "../../windows"
import "../../"

RowLayout {
    id: root

    // Apps whose tray icon is menu-only: libappindicator / Ayatana
    // items that never implement a useful SNI Activate, so a plain
    // left-click activate() does nothing. For these we open the DBus
    // menu on left-click instead. Everything else keeps activate()
    // (e.g. blueman opens its applet). Right-click always shows the
    // menu when one exists. Matched against the item's `id` OR `title`
    // (case-insensitive) — some apps (e.g. Sunshine) use a random id
    // each launch but a stable title. Add entries to make more icons
    // menu-first.
    property var menuOnlyIds: ["steam", "sunshine", "nm-applet"]

    function isMenuOnly(item) {
        var keys = [item.id, item.title]
        for (var i = 0; i < menuOnlyIds.length; i++) {
            var want = menuOnlyIds[i].toLowerCase()
            for (var j = 0; j < keys.length; j++)
                if (keys[j] && keys[j].toLowerCase() === want) return true
        }
        return false
    }

    function openMenu(item, handle) {
        if (!handle) return
        Popups.closeAll()
        trayMenu.anchorItem = item
        trayMenu.menuHandle = handle
        Popups.trayMenuOpen = true
    }

    // Fallback for icons with no menu: launch the app by its desktop
    // entry (matched from id/title), falling back to running the name.
    function launchApp(item) {
        var names = [item.id, item.title].filter(function (n) { return !!n })
        for (var i = 0; i < names.length; i++) {
            var entry = DesktopEntries.heuristicLookup(names[i])
            if (entry) { entry.execute(); return }
        }
        if (names.length > 0) Quickshell.execDetached([names[0]])
    }

    // Themed context menu shared by all tray icons; repositioned to
    // whichever icon was clicked.
    TrayMenu { id: trayMenu }

    RowLayout {
        id: trayRow
        Layout.alignment: Qt.AlignVCenter

        // Custom state for toggling
        property bool isOpen: false

        // UX: Smooth fade and slide animation instead of abruptly disappearing
        visible: opacity > 0
        opacity: isOpen ? 1 : 0
        Layout.preferredWidth: isOpen ? implicitWidth : 0
        clip: true

        Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
        Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

        Repeater {
            model: SystemTray.items
            delegate: Rectangle {
                id: trayItem
                // UX: Larger 28x28 hit-box makes it easier to click than a 16x16 icon
                width: 26
                height: 26
                radius: 6
                color: trayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent" // Subtle hover effect

                readonly property bool menuOnly: root.isMenuOnly(modelData)

                Image {
                    width: 16
                    height: 16
                    anchors.centerIn: parent
                    source: modelData.icon
                    smooth: true
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor // Visual cue that it's clickable
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            if (trayItem.menuOnly && modelData.hasMenu) {
                                root.openMenu(trayItem, modelData.menu)
                            } else if (modelData.hasMenu) {
                                modelData.activate()
                            } else {
                                // No menu and no useful activation — open the app.
                                root.launchApp(modelData)
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu) {
                                root.openMenu(trayItem, modelData.menu)
                            } else {
                                root.launchApp(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // Tray Toggle Button
    IconBtn {
        Layout.alignment: Qt.AlignVCenter
        text: trayRow.isOpen ? "" : ""
        onClicked: trayRow.isOpen = !trayRow.isOpen
    }
}
