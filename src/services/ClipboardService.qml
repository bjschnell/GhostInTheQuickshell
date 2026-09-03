pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Clipboard history — replaces cliphist.
//
// The capture path is ported from Omarchy 4's clipboard plugin (MIT, Copyright
// David Heinemeier Hansson): wl-paste --watch feeds src/scripts/
// clipboard-capture.sh, which emits one JSON entry per line. Owning the capture
// is the whole point — it is the only place a selection can be refused, and
// cliphist stores everything it is handed.
//
// Text history is held in memory and never written to disk. Ghost already
// wiped cliphist on shell close and at logout, so nothing is lost by not
// persisting, and a session's clipboard now cannot outlive the process that
// held it. Images have to be files, so they live in ~/.cache/ghost/
// clipboard-images and are removed on shutdown.
//
// Pins are the exception and are still persisted: those are explicitly chosen.
//
// Entry shape:
//   { id, preview, isImage, text, imagePath, mime }
//   id        — monotonic, assigned here; stable for as long as the entry lives
//   preview   — single-line display string
//   text      — full content for text entries
//   imagePath — file on disk for image entries

QtObject {
    id: root

    property var  entries: []
    property var  pinned:  []
    // Kept for the UI's spinner binding; capture is push-based, so there is
    // never a fetch in flight to wait on.
    readonly property bool loading: false

    readonly property int maxEntries: 100

    readonly property string _pinsPath:
        Quickshell.env("HOME") + "/.config/Ghost/src/user_data/clipboard_pins.json"
    readonly property string _imageDir:
        Quickshell.env("HOME") + "/.cache/ghost/clipboard-images"
    readonly property string _captureScript:
        Quickshell.shellDir + "/src/scripts/clipboard-capture.sh"

    property int _nextId: 1

    // ── Capture ───────────────────────────────────────────────────────────────
    // setpriv --pdeathsig TERM ties each watcher's life to the shell's, so a
    // crashed or replaced shell cannot leave a watcher recording into nothing.

    property var _textWatcher: Process {
        running: true
        command: ["setpriv", "--pdeathsig", "TERM",
                  "wl-paste", "--type", "text", "--watch", root._captureScript, "text"]
        stdout: SplitParser { onRead: function(line) { root._ingest(line) } }
    }

    property var _imageWatcher: Process {
        running: true
        command: ["setpriv", "--pdeathsig", "TERM",
                  "wl-paste", "--type", "image/png", "--watch", root._captureScript, "image/png"]
        stdout: SplitParser { onRead: function(line) { root._ingest(line) } }
    }

    function _previewFor(entry) {
        if (entry.type === "image") return "Image"
        // Collapse to one line; the list shows a single row per entry.
        return String(entry.text || "").replace(/\s+/g, " ").trim()
    }

    function _ingest(line) {
        var raw = String(line || "").trim()
        if (raw === "") return

        var parsed
        try { parsed = JSON.parse(raw) } catch (e) { return }
        if (!parsed || !parsed.type) return

        var isImage = parsed.type === "image"
        if (!isImage && String(parsed.text || "").trim() === "") return
        if (isImage && !parsed.path) return

        var entry = {
            id:        String(root._nextId++),
            preview:   root._previewFor(parsed),
            isImage:   isImage,
            text:      isImage ? "" : String(parsed.text || ""),
            imagePath: isImage ? String(parsed.path) : "",
            mime:      isImage ? String(parsed.mime || "image/png") : "text/plain"
        }
        if (entry.preview === "") return

        // Re-copying something already in the list moves it to the top rather
        // than adding a duplicate.
        var key = isImage ? entry.imagePath : entry.text
        var next = [entry]
        for (var i = 0; i < root.entries.length && next.length < root.maxEntries; i++) {
            var e = root.entries[i]
            if ((e.isImage ? e.imagePath : e.text) === key) continue
            next.push(e)
        }
        root.entries = next
    }

    function _find(id) {
        for (var i = 0; i < root.entries.length; i++)
            if (root.entries[i].id === String(id)) return root.entries[i]
        return null
    }

    // Push-based capture means there is nothing to poll for; kept so callers
    // that refresh on popup open keep working.
    function load() {}

    // ── Copy ──────────────────────────────────────────────────────────────────

    property var _copyProc: Process { command: []; running: false }

    function _run(cmd) {
        _copyProc.command = ["bash", "-c", cmd]
        _copyProc.running = false
        _copyProc.running = true
    }

    function copyEntry(id) {
        var e = root._find(id)
        if (!e) return
        if (e.isImage) root._run("wl-copy < '" + e.imagePath.replace(/'/g, "'\\''") + "'")
        else root.copyText(e.text)
    }

    function copyText(t) {
        root._run("printf '%s' '" + String(t).replace(/'/g, "'\\''") + "' | wl-copy")
    }

    // ── Type: copy first, then wtype after the popup closes ───────────────────

    property var _wtypeProc: Process { command: []; running: false }

    function typeFromClipboard() {
        _wtypeProc.command = ["bash", "-c", "sleep 0.35 && wl-paste -n | wtype -"]
        _wtypeProc.running = false
        _wtypeProc.running = true
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    property var _rmProc: Process { command: []; running: false }

    function deleteEntry(id) {
        var next = []
        var removed = null
        for (var i = 0; i < root.entries.length; i++) {
            if (root.entries[i].id === String(id)) removed = root.entries[i]
            else next.push(root.entries[i])
        }
        root.entries = next

        // An image entry owns its file, so dropping the row drops the file too.
        if (removed && removed.isImage && removed.imagePath !== "") {
            _rmProc.command = ["rm", "-f", removed.imagePath]
            _rmProc.running = false
            _rmProc.running = true
        }
    }

    // ── Pins ──────────────────────────────────────────────────────────────────
    // Format is unchanged from the cliphist era so existing pins still load:
    //   { text, preview, id, timestamp }

    property var _loadPinsProc: Process {
        command: ["bash", "-c",
            "[ -f '" + root._pinsPath + "' ] && cat '" + root._pinsPath + "' || " +
            "(mkdir -p \"$(dirname '" + root._pinsPath + "')\" && echo '[]')"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try   { root.pinned = JSON.parse(text.trim()) }
                catch (e) { root.pinned = [] }
            }
        }
    }

    property var _savePinsProc: Process { command: []; running: false }

    function _savePins() {
        var json = JSON.stringify(root.pinned)
        _savePinsProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root._pinsPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root._pinsPath + "'"]
        _savePinsProc.running = false
        _savePinsProc.running = true
    }

    // The full text is already in hand, so pinning no longer needs to shell out
    // to decode the entry first.
    function pinEntry(id, preview) {
        var e = root._find(id)
        if (!e || e.isImage || e.text === "") return

        var list = root.pinned.filter(function(p) { return p.text !== e.text })
        list.unshift({
            text:      e.text,
            preview:   preview !== undefined && preview !== "" ? preview : e.preview,
            id:        e.id,
            timestamp: new Date().getTime()
        })
        root.pinned = list
        root._savePins()
    }

    function unpinAt(index) {
        var list = root.pinned.slice()
        list.splice(index, 1)
        root.pinned = list
        root._savePins()
    }

    // ── Wipe ──────────────────────────────────────────────────────────────────

    property var _wipeImagesProc: Process { command: []; running: false }

    function _wipeImages() {
        _wipeImagesProc.command = ["bash", "-c",
            "rm -f '" + root._imageDir + "'/* 2>/dev/null || true"]
        _wipeImagesProc.running = false
        _wipeImagesProc.running = true
    }

    function wipeHistory() {
        root.entries = []
        root._wipeImages()
    }

    Component.onCompleted: {
        _loadPinsProc.running = true
        // Anything left from a previous session was never meant to outlive it.
        _wipeImages()
    }

    Component.onDestruction: {
        // Text history dies with the process; the image files do not, so they
        // are removed synchronously rather than through a Process that would
        // not outlive shutdown.
        Quickshell.execDetached(["bash", "-c",
            "rm -f '" + root._imageDir + "'/* 2>/dev/null || true"])
    }
}
