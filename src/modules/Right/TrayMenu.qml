import QtQuick
import Quickshell
import "../../"

// ============================================================
// TrayMenu — a themed context menu for SystemTray items.
//
// Steam, Sunshine and nm-applet are libappindicator/Ayatana
// items that never implement the SNI Activate method — the only
// way to interact with them is their DBus menu. Quickshell's
// built-in QsMenuAnchor would render that menu, but only in
// QApplication mode. Instead we build the menu ourselves from
// QsMenuOpener so it matches the shell theme and needs no global
// app-mode change.
//
// A single instance lives in SysTray. On click it is pointed at
// the clicked icon (anchorItem) and fed that item's menu handle,
// then opened via Popups.trayMenuOpen so the existing PopupDismiss
// overlay closes it on click-outside / Escape / workspace change.
// ============================================================

PopupWindow {
    id: root

    // Set by SysTray right before opening.
    property Item anchorItem: null
    property var  menuHandle: null

    // The user's intent to have the menu shown.
    readonly property bool open: Popups.trayMenuOpen
        && anchorItem !== null && menuHandle !== null

    // Drop straight down from the clicked icon.
    anchor.item:    anchorItem
    anchor.edges:   Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6

    color: "transparent"

    implicitWidth:  Math.max(180, Math.min(340, col.implicitWidth))
    implicitHeight: card.implicitHeight

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    // ── Visibility gate (keeps window alive through the fade-out) ──
    property bool windowVisible: false
    visible: windowVisible
    mask: Region { item: card }

    Connections {
        target: Popups
        function onTrayMenuOpenChanged() {
            if (Popups.trayMenuOpen) {
                closeTimer.stop()
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }
    Timer {
        id: closeTimer
        interval: Theme.animDuration
        onTriggered: root.windowVisible = false
    }

    function activateEntry(entry) {
        if (!entry.enabled) return
        entry.triggered()
        Popups.trayMenuOpen = false
    }

    // Strip GTK ("_") / Qt ("&") mnemonic markers from labels.
    function cleanLabel(t) {
        if (!t) return ""
        return t.replace(/_/g, "")
                .replace(/&&/g, "￿")
                .replace(/&/g, "")
                .replace(/￿/g, "&")
    }

    // ── Themed card ───────────────────────────────────────────
    Rectangle {
        id: card
        width:  root.implicitWidth
        implicitHeight: col.implicitHeight + 12
        radius: Theme.cornerRadius
        color:  Theme.background
        border.width: 1
        border.color: Theme.border

        // Fade + slight rise on open/close.
        opacity: root.open ? 1 : 0
        transform: Translate { y: root.open ? 0 : -6 }
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

        Column {
            id: col
            y: 6
            width: parent.width

            Repeater {
                model: opener.children

                // Each top-level entry: a header row plus an optional
                // inline submenu, stacked so the menu reflows when a
                // submenu is expanded.
                delegate: Column {
                    id: entry
                    required property var modelData
                    width: col.width

                    property bool subExpanded: false

                    // ── Separator ─────────────────────────────
                    Item {
                        visible: entry.modelData.isSeparator
                        width: col.width
                        height: visible ? 7 : 0
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            height: 1
                            color: Theme.border
                            opacity: 0.6
                        }
                    }

                    // ── Normal entry row ──────────────────────
                    Rectangle {
                        id: rowBg
                        visible: !entry.modelData.isSeparator
                        width:  col.width
                        height: visible ? 30 : 0
                        radius: 6
                        color: rowMouse.containsMouse && entry.modelData.enabled
                            ? Theme.active : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin:  10
                            anchors.rightMargin: 10
                            spacing: 8

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width:  16
                                height: 16
                                visible: !!entry.modelData.icon
                                source: entry.modelData.icon || ""
                                smooth: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                       - (entry.modelData.icon ? 24 : 0)
                                       - (entry.modelData.hasChildren ? 16 : 0)
                                text: root.cleanLabel(entry.modelData.text)
                                color: entry.modelData.enabled ? Theme.text : Theme.subtext
                                opacity: entry.modelData.enabled ? 1 : 0.5
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entry.modelData.hasChildren
                                text: "›"
                                rotation: entry.subExpanded ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
                                color: Theme.subtext
                                font.family: Theme.fontMono
                                font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren)
                                    entry.subExpanded = !entry.subExpanded
                                else
                                    root.activateEntry(entry.modelData)
                            }
                        }
                    }

                    // ── Inline submenu (one level deep) ───────
                    Loader {
                        active: entry.subExpanded
                        visible: active
                        width: col.width

                        sourceComponent: Column {
                            width: col.width

                            QsMenuOpener {
                                id: subOpener
                                menu: entry.modelData
                            }

                            Repeater {
                                model: subOpener.children
                                delegate: Rectangle {
                                    id: subRow
                                    required property var modelData
                                    width:  col.width
                                    height: modelData.isSeparator ? 7 : 28
                                    radius: 6
                                    color: subMouse.containsMouse && modelData.enabled
                                        ? Theme.active : "transparent"

                                    Text {
                                        visible: !subRow.modelData.isSeparator
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 26
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        text: root.cleanLabel(subRow.modelData.text)
                                        color: subRow.modelData.enabled ? Theme.text : Theme.subtext
                                        opacity: subRow.modelData.enabled ? 1 : 0.5
                                        font.family: Theme.fontMono
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                    Rectangle {
                                        visible: subRow.modelData.isSeparator
                                        anchors.centerIn: parent
                                        width: parent.width - 20
                                        height: 1
                                        color: Theme.border
                                        opacity: 0.6
                                    }
                                    MouseArea {
                                        id: subMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: subRow.modelData.enabled && !subRow.modelData.isSeparator
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activateEntry(subRow.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
