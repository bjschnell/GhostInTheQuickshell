pragma Singleton
import QtQuick

QtObject {
    // --Bar Toggle--
    property bool barEnabled: false

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

    // -- Center Island Auto-Hide --
    // The center island stays retracted into the top edge until the pointer
    // enters the reveal strip. Set centerAutoHide false for the old always-on
    // behaviour. Overridden while the dashboard is open or a screen recording
    // is being set up / is running (see TopBar.centerPinned).
    property bool centerAutoHide:    true
    property int  centerRevealWidth: 340   // width of the top-center hover strip
    property int  centerHideDelay:   400   // ms of no-hover before it retracts

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
