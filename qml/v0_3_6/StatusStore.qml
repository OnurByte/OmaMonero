pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Status.js" as Status

QtObject {
    id: root
    property string raw: ""
    property double now: Date.now() / 1000
    readonly property var view: Status.classify(raw, now)
    readonly property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR")
    readonly property string statusPath: runtimeDirectory ? runtimeDirectory + "/omamonero/status.json" : ""

    readonly property string dataDirectory: Quickshell.env("HOME") + "/.local/share/omamonero"
    readonly property string pluginControl: decodeURIComponent(String(Qt.resolvedUrl("../../installer/control.py")).replace(/^file:\/\//, ""))
    property bool pendingSetup: false
    property bool installedControls: false
    property bool pluginControls: false
    readonly property bool needsInstall: pendingSetup || (!installedControls && pluginControls)
    readonly property bool controlsAvailable: pendingSetup || installedControls || pluginControls
    property var setup: ({state: "idle"})
    property var setupData: ({})
    property var paymentData: ({})
    property var incomingRequests: []
    function command(action, endpoint, marketEnabled, payload) {
        if (!controlsAvailable || ["info", "install", "save", "diagnostics", "remove", "receive", "preview-uri", "wallet", "register-uri", "module-config", "proof"].indexOf(action) < 0 || (setup.state === "running" && action !== "info")) return
        if (["receive", "preview-uri"].indexOf(action) >= 0) paymentData = ({})
        var helper = pendingSetup ? dataDirectory + "/pending/installer/control.py" : installedControls ? dataDirectory + "/installer/control.py" : pluginControl
        var args = ["/usr/bin/python3", helper, action]
        if (action === "save" || action === "install") args = args.concat(["--endpoint", endpoint || "http://127.0.0.1:18081", "--market", marketEnabled ? "true" : "false"])
        if (payload) args = args.concat(["--payload", JSON.stringify(payload)])
        // Explicit user action only; survives plugin reload/removal. No polling process.
        Quickshell.execDetached(args)
    }
    function refresh() {
        if (statusPath !== "") { file.reload(); setupFile.reload(); paymentFile.reload(); incomingFile.reload() }
        pendingFile.reload()
        receiptFile.reload()
    }
    property FileView setupFile: FileView {
        path: root.runtimeDirectory ? root.runtimeDirectory + "/omamonero/setup.json" : ""
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const result = JSON.parse(text())
                if (["running", "done", "error"].indexOf(result.state) >= 0) {
                    root.setup = result
                    if (result.data) {
                        root.setupData = result.data
                    }
                }
            } catch (e) { root.setup = {state: "error", message: "Invalid setup state"} }
        }
    }
    property FileView paymentFile: FileView {
        path: root.runtimeDirectory ? root.runtimeDirectory + "/omamonero/payment.json" : ""
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const result = JSON.parse(text())
                if (result.state === "ready" && result.payment) root.paymentData = result.payment
                else if (result.state === "error") root.paymentData = {error: result.message || "Payment link could not be opened."}
                else if (result.state === "pending") root.paymentData = ({})
            } catch (e) { root.paymentData = ({}) }
        }
        onLoadFailed: root.paymentData = ({})
    }
    property FileView incomingFile: FileView {
        path: root.runtimeDirectory ? root.runtimeDirectory + "/omamonero/incoming.json" : ""
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const result = JSON.parse(text())
                root.incomingRequests = Array.isArray(result.requests) ? result.requests : []
            } catch (e) { root.incomingRequests = [] }
        }
        onLoadFailed: root.incomingRequests = []
    }
    property FileView pendingFile: FileView {
        path: root.dataDirectory + "/pending/bundle.json"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.pendingSetup = !!JSON.parse(text()).version } catch (e) { root.pendingSetup = false } }
        onLoadFailed: root.pendingSetup = false
    }
    property FileView receiptFile: FileView {
        path: root.dataDirectory + "/installation.json"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const record = JSON.parse(text())
                root.installedControls = !!(record.installed_files && record.installed_files[root.dataDirectory + "/installer/control.py"])
            } catch (e) { root.installedControls = false }
        }
        onLoadFailed: root.installedControls = false
    }
    property FileView pluginControlFile: FileView {
        path: root.pluginControl
        preload: true
        printErrors: false
        onLoaded: root.pluginControls = true
        onLoadFailed: root.pluginControls = false
    }

    // One store per engine, shared by all monitor widgets. No processes or RPC.
    property FileView file: FileView {
        path: root.statusPath
        watchChanges: true
        preload: true
        printErrors: false
        onLoaded: root.raw = text()
        onFileChanged: reload()
        onLoadFailed: root.raw = ""
    }
    property Timer clock: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now() / 1000
    }
    // Recovers missed rename events and creation after an absent parent directory.
    // A shared local file read every five seconds; never an external command.
    property Timer recovery: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
