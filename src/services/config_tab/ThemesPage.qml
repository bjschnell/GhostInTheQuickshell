import QtQuick
import QtQuick.Controls
import "../"
import "../../"

// ============================================================
// ThemesPage — picks the shell palette and the surface style.
//
// Both lists are driven straight off Theme (Palettes.names / Styles.names), so
// adding either is still a one-file change: it shows up here with its own
// preview and needs no edit in this file.
//
// The two are independent — a style says how surfaces are painted, a palette
// says in what colors — so they are separate sections rather than one list.
// ============================================================

Item {
    id: root


    function _label(name) {
        if (name === Theme.dynamicPalette) return "Wallpaper"
        return name.charAt(0).toUpperCase() + name.slice(1)
    }

    function _subtitle(name) {
        return name === Theme.dynamicPalette
            ? "Follows the wallpaper via matugen"
            : "Fixed palette"
    }

    function _styleLabel(name) {
        return name.charAt(0).toUpperCase() + name.slice(1)
    }

    function _styleSubtitle(name) {
        var s = Theme.styleSwatch(name)
        if (s.blur)            return "Translucent, blurred behind"
        if (s.bar.opacity < 1) return "Translucent"
        return "Opaque surface"
    }

    Flickable {
        anchors {
            fill:         parent
            leftMargin:   12
            rightMargin:  12
            topMargin:    6
            bottomMargin: 12
        }
        contentWidth:   width
        contentHeight:  _col.implicitHeight + 16
        clip:           true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 3; implicitHeight: 40; radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.22)
            }
            background: Item {}
        }

        Column {
            id: _col
            width:   parent.width - 12
            spacing: 6

            Item {
                width:  parent.width
                height: 22
                Text {
                    anchors.bottom:       parent.bottom
                    anchors.bottomMargin: 4
                    text:           "Palette"
                    font.pixelSize: 9
                    font.weight:    Font.Bold
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                }
            }

            Repeater {
                model: Theme.palettes
                delegate: PaletteRow {
                    required property string modelData
                    width: _col.width
                    name:  modelData
                }
            }

            Item {
                width:  parent.width
                height: 30
                Text {
                    anchors.bottom:       parent.bottom
                    anchors.bottomMargin: 4
                    text:           "Style"
                    font.pixelSize: 9
                    font.weight:    Font.Bold
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                }
            }

            Repeater {
                model: Theme.styles
                delegate: StyleRow {
                    required property string modelData
                    width: _col.width
                    name:  modelData
                }
            }
        }
    }

    // ── StyleRow ──────────────────────────────────────────────────────────────
    // Same shape as PaletteRow, with the swatch chip showing the treatment
    // instead of the colors: the surface is painted at the style's own opacity
    // and rim over a banded backdrop, so a translucent style visibly lets the
    // bands through and an opaque one hides them.
    component StyleRow: Rectangle {
        id: sr

        property string name: ""

        readonly property bool selected: Theme.style === sr.name
        readonly property var  treatment: Theme.styleSwatch(sr.name).bar

        height: 58
        radius: 8

        color: sr.selected
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.10)
            : (_sh.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03))

        border.color: sr.selected
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.38)
            : Qt.rgba(1, 1, 1, 0.07)
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Rectangle {
            id: _schip
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            width:  60
            height: 36
            radius: 6
            clip:   true
            color:  "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1

            // Backdrop the preview surface sits on — stand-in for the window
            // content the real bar floats over.
            Row {
                anchors.fill: parent
                Repeater {
                    model: [ Theme.active, Theme.iconFont, Theme.active, Theme.iconFont ]
                    delegate: Rectangle {
                        required property color modelData
                        width:  _schip.width / 4
                        height: _schip.height
                        color:  Qt.rgba(modelData.r, modelData.g, modelData.b, 0.55)
                    }
                }
            }

            // The surface itself, at this style's opacity and rim.
            Rectangle {
                anchors.centerIn: parent
                width:   parent.width - 10
                height:  18
                radius:  5
                // Same arithmetic the real surface uses, gain included, so the
                // chip previews the actual colour and not just its alpha.
                color:   Qt.rgba(Math.min(1, Theme.background.r * sr.treatment.gain),
                                 Math.min(1, Theme.background.g * sr.treatment.gain),
                                 Math.min(1, Theme.background.b * sr.treatment.gain),
                                 sr.treatment.opacity)
                border.color: Qt.rgba(1, 1, 1, sr.treatment.rim)
                border.width: sr.treatment.rim > 0 ? 1 : 0
            }
        }

        Column {
            anchors {
                left:           _schip.right
                leftMargin:     12
                right:          _scheck.left
                rightMargin:    8
                verticalCenter: parent.verticalCenter
            }
            spacing: 3

            Text {
                width:          parent.width
                elide:          Text.ElideRight
                text:           root._styleLabel(sr.name)
                font.pixelSize: 12
                color: sr.selected ? Theme.active : Qt.rgba(1, 1, 1, 0.85)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                width:          parent.width
                elide:          Text.ElideRight
                text:           root._styleSubtitle(sr.name)
                font.pixelSize: 9
                color: Qt.rgba(1, 1, 1, 0.38)
            }
        }

        Text {
            id: _scheck
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text:           "󰄬"
            font.pixelSize: 14
            color:          Theme.active
            opacity:        sr.selected ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        HoverHandler { id: _sh; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onClicked: Theme.setStyle(sr.name)
        }
    }

    // ── PaletteRow ────────────────────────────────────────────────────────────
    component PaletteRow: Rectangle {
        id: pr

        property string name: ""

        readonly property bool selected: Theme.palette === pr.name
        readonly property var  swatch:   Theme.paletteSwatch(pr.name)

        height: 58
        radius: 8

        color: pr.selected
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.10)
            : (_h.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03))

        border.color: pr.selected
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.38)
            : Qt.rgba(1, 1, 1, 0.07)
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Swatch chip — the palette's own background with three of its roles on top
        Rectangle {
            id: _chip
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            width:  60
            height: 36
            radius: 6
            color:  pr.swatch.background
            border.color: pr.swatch.border
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 5
                Repeater {
                    model: [ pr.swatch.active, pr.swatch.text, pr.swatch.iconFont ]
                    delegate: Rectangle {
                        required property color modelData
                        width: 10; height: 10; radius: 5
                        color: modelData
                    }
                }
            }
        }

        Column {
            anchors {
                left:           _chip.right
                leftMargin:     12
                right:          _check.left
                rightMargin:    8
                verticalCenter: parent.verticalCenter
            }
            spacing: 3

            Text {
                width:          parent.width
                elide:          Text.ElideRight
                text:           root._label(pr.name)
                font.pixelSize: 12
                color: pr.selected ? Theme.active : Qt.rgba(1, 1, 1, 0.85)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                width:          parent.width
                elide:          Text.ElideRight
                text:           root._subtitle(pr.name)
                font.pixelSize: 9
                color: Qt.rgba(1, 1, 1, 0.38)
            }
        }

        Text {
            id: _check
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text:           "󰄬"
            font.pixelSize: 14
            color:          Theme.active
            opacity:        pr.selected ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        HoverHandler { id: _h; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onClicked: Theme.setPalette(pr.name)
        }
    }
}
