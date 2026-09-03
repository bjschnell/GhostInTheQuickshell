import QtQuick
import "../theme"

// The polkit authentication card — padlock, password field, and the
// justification chip above it.
//
// Ported from Omarchy 4's shell/plugins/polkit/PolkitAgent.qml (MIT, Copyright
// David Heinemeier Hansson), split from the agent itself so the service owns
// the flow and this owns only how it looks, matching LockService/LockView.
//
// Holds no polkit state: everything comes in as a property and goes out as a
// signal, so the service can drive it and never has to reach into the UI.

Item {
    id: root

    property string message:          ""
    property bool   responseRequired: false
    property bool   responseVisible:  false
    property bool   submitted:        false
    property bool   errorFlash:       false
    property bool   fingerprintMode:  false
    property int    shakeOffset:      0

    readonly property int fieldHeight:   42
    readonly property int contentMargin: Theme.popupPadding

    // Password mode is a wide field; fingerprint mode collapses to a square that
    // just frames the centered sensor icon.
    readonly property int cardHeight: Math.min(fieldHeight + contentMargin * 2,
                                               Math.max(fieldHeight, root.height - Theme.spacing * 2))
    readonly property int cardWidth: fingerprintMode
        ? cardHeight
        : Math.min(312, Math.max(260, root.width - Theme.spacing * 2))

    readonly property color accent:     errorFlash ? Theme.wsUrgent : Theme.active
    readonly property color foreground: errorFlash ? Theme.wsUrgent : Theme.text
    readonly property color scrim:      Qt.rgba(0, 0, 0, 0.45)

    signal submit(string password)
    signal cancel()
    signal focusRequested()

    function clear() { passwordInput.text = "" }
    function focusField() {
        // In fingerprint mode there is no field to type into — park focus on the
        // key catcher so Escape still cancels; otherwise focus the password field.
        if (fingerprintMode) keyCatcher.forceActiveFocus()
        else passwordInput.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        color: root.scrim
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.focusRequested()
    }

    Rectangle {
        id: card
        width: root.cardWidth
        height: root.cardHeight
        radius: Theme.cornerRadius
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.shakeOffset
        color: Theme.background
        border.width: 2
        border.color: root.errorFlash ? Theme.wsUrgent : Theme.border

        MouseArea { anchors.fill: parent; onClicked: root.focusRequested() }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.cancel()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.responseRequired) root.submit(passwordInput.text)
                    event.accepted = true
                }
            }
        }

        // Fingerprint mode shows just the sensor icon, centered and alone — no
        // padlock, no field, no prompt text.
        Text {
            anchors.centerIn: parent
            visible: root.fingerprintMode
            text: "󰈷"
            color: root.accent
            font.family: Theme.fontMono
            font.pixelSize: Math.round(root.fieldHeight * 0.7)
        }

        Row {
            visible: !root.fingerprintMode
            anchors.fill: parent
            anchors.margins: root.contentMargin
            spacing: 14

            Text {
                text: ""
                color: root.accent
                font.family: Theme.fontMono
                font.pixelSize: 20
                width: 26
                height: root.fieldHeight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Item {
                width: parent.width - 40
                height: root.fieldHeight

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    activeFocusOnPress: true
                    clip: true
                    selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
                    selectedTextColor: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    // polkit asks for a visible response for some prompts (a PIN
                    // hint, say), so the echo mode follows the flow rather than
                    // always masking.
                    echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    color: root.foreground
                    cursorVisible: activeFocus && !root.submitted && !root.errorFlash
                    readOnly: root.submitted || root.errorFlash
                    onAccepted: root.submit(text)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            root.cancel()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.errorFlash ? "Wrong" : (root.submitted ? "Checking..." : "Enter password")
                    color: root.foreground
                    opacity: root.errorFlash ? 1 : 0.36
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    elide: Text.ElideRight
                    visible: passwordInput.text.length === 0
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: passwordInput.forceActiveFocus()
                }
            }
        }
    }

    // The justification sits above the card rather than inside it, so the card
    // stays the same size whatever polkit has to say.
    Rectangle {
        width: Math.min(justificationText.implicitWidth + 24, root.width - Theme.spacing * 2)
        height: 28
        anchors.horizontalCenter: card.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: 10
        radius: Theme.cornerRadius
        color: Theme.background
        visible: root.message.length > 0

        Text {
            id: justificationText
            textFormat: Text.PlainText
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: root.message
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideMiddle
        }
    }
}
