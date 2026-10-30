import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import "Plugin" as Oma
import "Plugin/components" as Components

// Non-visual integration harness; no ShellRoot and no desktop/bar instance.
QtObject {
  property Item testContent: Item {
    id: root
    property int stage: 0
    property string controlCalls: ""
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/control-calls"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.controlCalls = text()
    }
    property int ticks: 0
    property int updates: 0
    property int lastHeight: 0
    Oma.BarWidget { id: widget }
    property Item chartCheck: Components.Sparkline {
        width: 300
        height: 180
        detailed: true
        axisLow: 575
        axisHigh: 636
        points: [{timestamp: 1, price: 575}, {timestamp: 2, price: 636}]
    }
    property Item narrowChartCheck: Components.Sparkline {
        width: 140
        height: 180
        detailed: true
        axisLow: 575
        axisHigh: 636
        points: [{timestamp: 1, price: 575}, {timestamp: 2, price: 636}]
    }
  property Item navigationCheck: Item {
    width: Style.space(430)
    height: Style.space(44)
    property real usedWidth: tabs.implicitWidth
    RowLayout {
      id: tabs
      width: parent.width
      spacing: Style.spacing.sm
      Ui.Button { text: "Overview"; focusable: true }
      Ui.Button { text: "Receive"; focusable: true }
      Ui.Button { text: "Modules"; focusable: true }
      Ui.Button { text: "Settings"; focusable: true }
      Ui.Button { text: "Diag"; tooltipText: "Diagnostics"; focusable: true }
    }
  }
    Component.onCompleted: {
        if (widget.opened || widget.implicitWidth <= 0) throw new Error("Invalid widget initialization")
        widget.close()
        widget.refresh()
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.ticks++
            if (root.ticks === 2 && (root.chartCheck.axisLabels.join(",") !== "$641,$623,$606,$588,$570" || root.chartCheck.axisTickCount !== 5 || !root.chartCheck.axesFit || !root.narrowChartCheck.axesFit)) {
                console.error("OMAMONERO_RUNTIME_FAIL: chart axis labels exceed available width: " + root.chartCheck.axisLabels.join(",") + " / wide " + root.chartCheck.axesFit + " / narrow " + root.narrowChartCheck.axesFit)
                Qt.quit()
            }
            if (root.ticks === 2 && root.navigationCheck.usedWidth > root.navigationCheck.width) {
                console.error("OMAMONERO_RUNTIME_FAIL: panel navigation width " + root.navigationCheck.usedWidth + " exceeds available " + root.navigationCheck.width)
                Qt.quit()
            }
            if (root.ticks === 10) {
                Oma.StatusStore.setup = {state: "running"}
                Oma.StatusStore.command("info")
                Oma.StatusStore.command("save", "http://127.0.0.1:18081", false)
            }
            if (root.ticks === 30 && root.controlCalls.trim() !== "info") {
                console.error("OMAMONERO_RUNTIME_FAIL: abandoned-job recovery command was blocked or a mutation bypassed the lock")
                Qt.quit()
            }
            var view = Oma.StatusStore.view
            if (view.node && view.node.height && root.lastHeight !== view.node.height) {
                root.lastHeight = view.node.height
                root.updates++
            }
            if (root.stage === 0 && view.state === "online") root.stage = 1
            if (root.stage === 1 && view.node && view.node.height === 300) root.stage = 2
            if (root.stage === 2 && view.state === "invalid") root.stage = 3
        if (root.stage === 3 && view.state === "missing" && root.updates >= 4 && root.controlCalls.trim() === "info") {
                console.log("OMAMONERO_RUNTIME_PASS: native widget load, late file creation, repeated atomic replacement, corrupt JSON, deletion")
                Qt.quit()
            }
            if (root.ticks > 400) {
                console.error("OMAMONERO_RUNTIME_FAIL: stage " + root.stage + " state " + view.state + " updates " + root.updates + " control calls " + JSON.stringify(root.controlCalls))
                Qt.quit()
            }
        }
    }
}

}
