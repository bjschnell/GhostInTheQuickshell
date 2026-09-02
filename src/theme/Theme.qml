pragma Singleton
import QtQuick
import "."

QtObject {
    // ── Bindings to Modular Singletons ────────────────────────────────────────
    // Note: property alias cannot point to other singletons, so we use direct bindings.
    
    // Palette selection — the shell either follows the wallpaper (matugen) or
    // pins a fixed palette from Palettes.qml. Exposed here so UI code only ever
    // touches Theme. Read-only by design: go through setPalette so the choice
    // is persisted to user_data/theme.json.
    readonly property string palette:  Colors.palette
    readonly property var    palettes: Palettes.names
    readonly property string dynamicPalette: Palettes.dynamicName

    function setPalette(name) { Colors.setPalette(name) }
    function cyclePalette()   { Colors.cyclePalette() }

    // Colors
    property color background: Colors.background
    property color active:     Colors.active
    property color text:       Colors.text
    property color subtext:    Colors.subtext
    property color icon:       Colors.icon
    property color border:     Colors.border
    property color iconFont:   Colors.iconFont

    property color wsBackground: Colors.wsBackground
    property color wsActive:     Colors.wsActive
    property color wsOccupied:   Colors.wsOccupied
    property color wsEmpty:      Colors.wsEmpty
    property color wsOverlay:    Colors.wsOverlay
    property color wsUrgent:     Colors.wsUrgent

    // Metrics
    property bool barEnabled: Metrics.barEnabled
    
    property int borderWidth:   Metrics.borderWidth
    property int cornerRadius:  Metrics.cornerRadius
    property int notchRadius:   Metrics.notchRadius
    property int notchHeight:   Metrics.notchHeight
    property int exclusionGap:  Metrics.exclusionGap
    property int spacing:       Metrics.spacing

    property int notchPadding:           Metrics.notchPadding
    property int notchHorizontalPadding: Metrics.notchHorizontalPadding
    property int notchVerticalPadding:   Metrics.notchVerticalPadding
    property int notchSideMargin:        Metrics.notchSideMargin

    property int lNotchMinWidth: Metrics.lNotchMinWidth
    property int lNotchMaxWidth: Metrics.lNotchMaxWidth
    property int cNotchMinWidth: Metrics.cNotchMinWidth
    property int cNotchMaxWidth: Metrics.cNotchMaxWidth

    property bool centerAutoHide:    Metrics.centerAutoHide
    property int  centerRevealWidth: Metrics.centerRevealWidth
    property int  centerHideDelay:   Metrics.centerHideDelay

    property int rNotchMinWidth: Metrics.rNotchMinWidth
    property int rNotchMaxWidth: Metrics.rNotchMaxWidth

    property int dashboardWidth:  Metrics.dashboardWidth
    property int dashboardHeight: Metrics.dashboardHeight

    property int notificationsWidth: Metrics.notificationsWidth
    property int notificationToastWidth: Metrics.notificationToastWidth
    property int networkPopupWidth:  Metrics.networkPopupWidth

    property int popupMinWidth:   Metrics.popupMinWidth
    property int popupMaxWidth:   Metrics.popupMaxWidth
    property int popupMinHeight:   Metrics.popupMinHeight
    property int popupMaxHeight:  Metrics.popupMaxHeight
    property int popupPadding:     Metrics.popupPadding

    property int wsDotSize:     Metrics.wsDotSize
    property int wsActiveWidth: Metrics.wsActiveWidth
    property int wsSpacing:     Metrics.wsSpacing
    property int wsPadding:     Metrics.wsPadding
    property int wsRadius:      Metrics.wsRadius

    property int animDuration: Metrics.animDuration

    // Typography
    // The nerd-patched family is a superset of plain JetBrains Mono, so one
    // name covers both text and glyph use. The unpatched plain family is NOT
    // provided by ttf-jetbrains-mono-nerd, so asking for it by that name
    // silently fell back to the default sans.
    property string fontMono: 'JetBrainsMono Nerd Font'
}
