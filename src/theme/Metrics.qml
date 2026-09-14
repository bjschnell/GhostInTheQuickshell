pragma Singleton
import QtQuick

QtObject {
    // --Bar Toggle--
    property bool barEnabled: false

    // -- Bar Exclusion --
    // false: the bar never reserves screen space. Windows sit at full screen
    // and the notches float above them when revealed, so nothing ever reflows
    // — the price is that a revealed notch covers the top of whatever is under
    // it. true: the old behaviour, reserving exclusionGap px at the top edge.
    property bool barExclusive: false

    // Height of the live sliver left at the very top edge while a notch is
    // retracted. The screen edge stops the pointer, so a few px is enough to
    // catch a reveal — and little enough that clicks meant for a title bar or
    // tab strip underneath still get through. Only used when the bar is not
    // exclusive; an exclusive bar keeps the full-height strips, since there is
    // no window under it to steal from.
    property int revealStripHeight: 4

    // Width of the hairline rim stroked along the notch silhouette. Whether it
    // is drawn at all is the style's call (Styles.qml); this is only how thick
    // it is when a style asks for one.
    property int barRimWidth: 1

    // -- Bar Sizes --
    property int borderWidth:   0
    property int cornerRadius:  15
    property int notchRadius:   13
    property int notchHeight:   30
    property int exclusionGap:  34
    property int spacing:       10

    // -- Notch Content Padding --
    // Space added around the content inside each notch
    property int notchPadding:           16   // horizontal padding each side
    property int notchHorizontalPadding: 20
    property int notchVerticalPadding:   10
    property int notchSideMargin:        10

    // -- Notch Width Constraints --
    // Each notch sizes itself to its content, clamped between min and max.
    property int lNotchMinWidth: 180
    property int lNotchMaxWidth: 360

    property int cNotchMinWidth: 300
    property int cNotchMaxWidth: 360

    // -- Notch Auto-Hide --
    // Each notch stays retracted into the top edge until something asks for it
    // back: the pointer entering its reveal strip, a popup that lives in it
    // opening, or an event the shell already knows about (a workspace switch
    // pulls the left notch out — see TopBar). Set a side's autoHide false for
    // the old always-on behaviour.
    //
    // The reveal strips are wider than the notches they uncover so the edges
    // are forgiving; the hide delays stop a pointer clipping a strip edge from
    // making a notch stutter.
    property bool leftAutoHide:    true
    property int  leftRevealWidth: 260
    property int  leftHideDelay:   400

    property bool centerAutoHide:    true
    property int  centerRevealWidth: 340
    property int  centerHideDelay:   400

    property bool rightAutoHide:    true
    property int  rightRevealWidth: 260
    property int  rightHideDelay:   400

    // How long an event-driven reveal holds a notch out before it retracts,
    // in ms. Long enough to read a workspace switch, short enough that it is
    // gone before you stop caring.
    property int revealHoldDuration: 1500

    property int rNotchMinWidth: 180
    property int rNotchMaxWidth: 360

    // -- Dashboard Dimensions --
    // Target size the center notch expands to when the dashboard is open.
    property int dashboardWidth:  900
    property int dashboardHeight: 520

    // -- Notifications Popup Width --
    property int notificationsWidth: 400
    property int notificationToastWidth: notificationsWidth / 1.2
    property int networkPopupWidth:  480

    // -- Popup Size Constraints --
    property int popupMinWidth:   160
    property int popupMaxWidth:   420
    property int popupMinHeight:   80
    property int popupMaxHeight:  520
    property int popupPadding:     16

    // -- Workspace Dot Sizes --
    property int wsDotSize:     10
    property int wsActiveWidth: 24
    property int wsSpacing:     6
    property int wsPadding:     8
    property int wsRadius:      16

    // -- Animations --
    property int animDuration: 320
}
