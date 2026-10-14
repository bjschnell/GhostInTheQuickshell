import QtQuick
import Quickshell.Io
import "../"
import "../../components"
import "../../"

// Dashboard Home tab — layout only.
//
//  ┌──────────────┬───────────────────────────┬──────────────┐
//  │ ProfileCard  │  ClockCard (off by default)│              │
//  ├──────────────┤                           │ ScreenRecCard│
//  │ CalendarCard │  PlayerCard               │ (QuickSettings│
//  │              │                           │  if re-enabled)│
//  └──────────────┴───────────────────────────┴──────────────┘
//
// dashboardClockEnabled hides ClockCard (center column reflows to fill the
// space). The right column always holds something now — QuickSettings when
// dashboardQuickSettingsEnabled is on, ScreenRecCard otherwise — so the
// center column's right edge no longer needs to react to that flag itself.

Item {
    id: root

    readonly property int colW:    210
    readonly property int gap:       8
    readonly property int profileH: 160
    readonly property int clockH:   220

    // ── Avatar path ───────────────────────────────────────────────────────────
    property string _avatarPath: ""
    property string _staticJpg:  ""   // resolved once: $HOME/.curr_wall_static.jpg

    // Resolve $HOME once, then set the fixed path.
    // Both gif (magick frame) and non-gif (symlink) cases now land at the
    // same ~/.curr_wall_static.jpg so no readlink resolution is needed.
    Process {
        command: ["bash", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var h = line.trim()
                if (h === "") return
                root._staticJpg  = h + "/.curr_wall_static.jpg"
                root._avatarPath = root._staticJpg
            }
        }
    }

    // Re-arm the image on every successful apply.
    // Because the path never changes, Qt's image cache would serve the old
    // texture. Clearing _avatarPath for one frame then restoring it forces
    // the Image to re-read the file from disk.
    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) {
            root._avatarPath = ""
            reloadTimer.restart()
        }
    }

    Timer {
        id: reloadTimer
        interval: 0
        repeat:   false
        onTriggered: root._avatarPath = root._staticJpg
    }

    // ── Left column ───────────────────────────────────────────────────────────
    Item {
        id: leftCol
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: root.gap }
        width: root.colW

        ProfileCard {
            id: profileCard
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: root.profileH
            avatarPath: root._avatarPath
        }

        CalendarCard {
            anchors {
                left: parent.left; right: parent.right
                top: profileCard.bottom; topMargin: root.gap
                bottom: parent.bottom
            }
        }
    }

    // ── Right column — always occupied ────────────────────────────────────────
    // QuickSettings' two used tiles have their own keybinds now, so it stays
    // off by default (Metrics.dashboardQuickSettingsEnabled) in favor of
    // ScreenRecCard, which took over the slot when the center notch's
    // record strip was removed.
    Item {
        id: rightCard
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: root.gap }
        width: root.colW

        QuickSettings {
            anchors.fill: parent
            visible: Theme.dashboardQuickSettingsEnabled
        }

        ScreenRecCard {
            anchors.fill: parent
            visible: !Theme.dashboardQuickSettingsEnabled
        }
    }

    // ── Center column ─────────────────────────────────────────────────────────
    Item {
        id: centerCol
        anchors {
            left:  leftCol.right;  leftMargin:  root.gap
            right: rightCard.left; rightMargin: root.gap
            top:   parent.top;     bottom:      parent.bottom
            topMargin: root.gap
        }

        // Off by default (see Metrics.dashboardClockEnabled) — duplicates the
        // clock already in the right bar. PlayerCard below fills the space.
        ClockCard {
            id: clockCard
            visible: Theme.dashboardClockEnabled
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: root.clockH
        }

        PlayerCard {
            anchors {
                left:   parent.left;  right:  parent.right
                top:    Theme.dashboardClockEnabled ? clockCard.bottom : parent.top
                topMargin: Theme.dashboardClockEnabled ? root.gap : 0
                bottom: parent.bottom
            }
        }
    }
}
