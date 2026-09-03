pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../../theme"
import "../../windows"

// Polkit authentication agent — replaces hyprpolkitagent.
//
// Ported from Omarchy 4's shell/plugins/polkit/PolkitAgent.qml and
// PolkitModel.js (MIT, Copyright David Heinemeier Hansson). The dialog itself
// lives in windows/PolkitDialog.qml; this owns the flow.
//
// Quickshell registers as the session's org.freedesktop.PolicyKit1
// AuthenticationAgent, so nothing else may be running one — hyprpolkitagent has
// to be gone, not merely unused. isRegistered says whether the claim landed.
//
// Omarchy's clamshell gate is deliberately not ported: it exists to skip the
// fingerprint reader while the lid is shut, and depends on a laptop-closed
// helper Ghost has no equivalent of.

QtObject {
    id: root

    property bool   closing:          false
    property bool   submitted:        false
    property string currentMessage:   ""
    property bool   responseRequired: false
    property bool   responseVisible:  false
    property bool   failed:           false
    property bool   errorFlash:       false
    // pam_fprintd appears in the polkit PAM stack (a sensor is enrolled).
    property bool   fingerprintConfigured: false
    property int    shakeOffset:      0

    readonly property bool dialogVisible: polkitAgent.isActive || closing

    // One method at a time. Fingerprint owns the dialog while PAM is waiting on
    // the reader; the moment PAM asks for a password we switch to the field.
    readonly property bool fingerprintMode:
        fingerprintConfigured && dialogVisible && !responseRequired && !submitted && !errorFlash

    // ── Message shaping ───────────────────────────────────────────────────────

    // polkit's default wording buries the command in a sentence. Pull it out
    // when it is there, and otherwise show whatever polkit said verbatim.
    function authorizationLabel(message) {
        var text = String(message || "")
        var match = text.match(/^Authentication is (?:needed|required) to run [`']([^`']+)[`'] as /i)
        return match ? "Authorize running '" + match[1] + "'" : text
    }

    // Fingerprint is available whenever pam_fprintd appears anywhere in the auth
    // stack — it need not be the first module.
    function fingerprintConfiguredFromPamConfig(raw) {
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].replace(/^\s+|\s+$/g, "")
            if (!line || line.charAt(0) === "#") continue
            if (!line.match(/^auth\s+/)) continue
            if (line.indexOf("pam_fprintd.so") !== -1) return true
        }
        return false
    }

    // ── Flow ──────────────────────────────────────────────────────────────────

    function resetSnapshot() {
        currentMessage = ""
        responseRequired = false
        responseVisible = false
        failed = false
        errorFlash = false
        submitted = false
        dialog.clear()
    }

    function syncFromFlow() {
        var flow = polkitAgent.flow
        if (!flow) return

        currentMessage = root.authorizationLabel(flow.message || "Authentication is needed...")
        responseRequired = !!flow.isResponseRequired
        responseVisible = !!flow.responseVisible
        failed = !!flow.failed

        if (responseRequired) submitted = false
    }

    function beginFlow() {
        closeTimer.stop()
        closing = false
        submitted = false
        dialog.clear()
        syncFromFlow()
        Qt.callLater(refocus)
    }

    function refocus() {
        if (!dialogVisible) return
        dialog.focusField()
    }

    function submitResponse(password) {
        var flow = polkitAgent.flow
        if (!flow || !flow.isResponseRequired) return
        submitted = true
        errorFlash = false
        flow.submit(password)
        dialog.clear()
    }

    function cancelRequest() {
        var flow = polkitAgent.flow
        dialog.clear()
        submitted = false
        closing = true
        closeTimer.restart()
        if (flow) flow.cancelAuthenticationRequest()
    }

    function triggerFailureFeedback() {
        submitted = false
        errorFlash = true
        dialog.clear()
        errorTimer.restart()
        shakeAnimation.restart()
        Qt.callLater(refocus)
    }

    // ── Timers and feedback ───────────────────────────────────────────────────

    property var _closeTimer: Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.closing = false
            root.resetSnapshot()
        }
    }

    property var _errorTimer: Timer {
        id: errorTimer
        interval: 1200
        repeat: false
        onTriggered: root.errorFlash = false
    }

    property var _shake: SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 35; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to:  8; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to:  0; duration: 55; easing.type: Easing.OutQuad }
    }

    property var _pamFile: FileView {
        path: "/etc/pam.d/polkit-1"
        watchChanges: true
        printErrors: false
        onLoaded: root.fingerprintConfigured = root.fingerprintConfiguredFromPamConfig(text())
        onLoadFailed: root.fingerprintConfigured = false
        onFileChanged: reload()
    }

    // ── Agent ─────────────────────────────────────────────────────────────────

    property var _agent: PolkitAgent {
        id: polkitAgent
        path: "/org/ghost/PolkitAgent"

        onAuthenticationRequestStarted: root.beginFlow()
        onIsActiveChanged: {
            if (isActive) root.syncFromFlow()
            else if (!root.closing) root.resetSnapshot()
        }
        onIsRegisteredChanged: {
            if (isRegistered) console.log("Ghost polkit agent registered")
            else console.warn("Ghost polkit agent is not registered; another agent may be running")
        }
    }

    property var _flowConnections: Connections {
        target: polkitAgent.flow

        function onIsResponseRequiredChanged() {
            root.syncFromFlow()
            if (!polkitAgent.flow || !polkitAgent.flow.isResponseRequired) root.dialog.clear()
            Qt.callLater(root.refocus)
        }

        function onInputPromptChanged()        { root.syncFromFlow() }
        function onResponseVisibleChanged()    { root.syncFromFlow() }
        function onSupplementaryMessageChanged() { root.syncFromFlow() }
        function onFailedChanged()             { root.syncFromFlow() }

        function onAuthenticationFailed() {
            root.syncFromFlow()
            root.triggerFailureFeedback()
        }

        function onAuthenticationSucceeded() {
            root.closing = true
            closeTimer.restart()
        }

        function onAuthenticationRequestCancelled() {
            root.closing = true
            closeTimer.restart()
        }
    }

    // ── Window ────────────────────────────────────────────────────────────────

    readonly property alias dialog: dialogItem

    property var _panel: PanelWindow {
        visible: root.dialogVisible
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "ghost-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        PolkitDialog {
            id: dialogItem
            anchors.fill: parent
            message:          root.currentMessage
            responseRequired: root.responseRequired
            responseVisible:  root.responseVisible
            submitted:        root.submitted
            errorFlash:       root.errorFlash
            fingerprintMode:  root.fingerprintMode
            shakeOffset:      root.shakeOffset
            onSubmit: function(password) { root.submitResponse(password) }
            onCancel: root.cancelRequest()
            onFocusRequested: root.refocus()
        }
    }

    function statusJson() {
        return JSON.stringify({
            registered:  polkitAgent.isRegistered,
            active:      polkitAgent.isActive,
            visible:     root.dialogVisible,
            responseRequired: root.responseRequired,
            fingerprint: root.fingerprintConfigured,
            message:     root.currentMessage
        })
    }
}
