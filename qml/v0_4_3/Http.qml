import QtQuick
import Quickshell.Io
// Request contents travel only over stdin. One bounded request at a time.
QtObject {
    id: root
    property var queue: []
    property var current: null
    property string output: ""
    property bool active: false
    function send(spec, callback) {
        if (queue.length >= 24) { callback(null); return }
        queue = queue.concat([{spec:spec, callback:callback}])
        pump.restart()
    }
    function cancel() {
        queue = []
        pump.stop()
        if (worker.running) worker.running = false
    }
    function next() {
        if (active || !queue.length) return
        current = queue[0]; queue = queue.slice(1); output = ""; active = true
        worker.stdinEnabled = true
        worker.command = current.spec.argv
        worker.running = true
    }
    property Timer pump: Timer { interval: 1; onTriggered: root.next() }
    property Process worker: Process {
        stdinEnabled: true
        clearEnvironment: true
        // qmllint disable incompatible-type
        environment: ({LANG:"C.UTF-8",PATH:"/usr/bin:/bin"})
        // qmllint enable incompatible-type
        onStarted: { write(root.current.spec.stdin); stdinEnabled = false }
        stdout: StdioCollector { onStreamFinished: root.output = text }
        stderr: StdioCollector {} // Never forward endpoint or proof diagnostics into logs.
        onExited: function(code, status) {
            const job = root.current
            root.active = false; root.current = null
            if (job) job.callback(code === 0 && root.output.length <= 1048600 ? root.output : null)
            root.pump.restart()
        }
    }
}
