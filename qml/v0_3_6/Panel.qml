import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "components" as Components

Ui.Panel {
    id: root
    moduleName: "io.github.onurbyte.omamonero"
    manageIpc: false
    property var anchorItem: null
    property var hostWidget: null
    property string page: "overview"
    property string lastAutomaticRequest: ""
    property int selectedAction: 0
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    readonly property var view: StatusStore.view
    readonly property bool hasMetrics: view.state === "online" || view.state === "syncing"
    readonly property bool busy: StatusStore.setup.state === "running"

    function open() {
        selectedAction = 0
        if (StatusStore.needsInstall) page = "settings"
        StatusStore.refresh()
        if (StatusStore.controlsAvailable) StatusStore.command("info")
        controller.show()
    }
    function openAbout() {
        root.page = StatusStore.needsInstall ? "settings" : "about"
        root.open()
    }
    function showSettings() {
        page = "settings"
        setupForm.endpoint = StatusStore.setupData.endpoint || "http://127.0.0.1:18081"
        setupForm.marketEnabled = StatusStore.setupData.market_enabled === true
        setupForm.marketSource = StatusStore.setupData.market_source || ({name:"Kraken",url:"",price_pointer:"/price",points_pointer:"/points",timestamp_pointer:"/timestamp",point_price_pointer:"/price",interval_secs:3600})
        if (StatusStore.controlsAvailable) StatusStore.command("info")
    }
    function activate() {
        if (selectedAction === 0) StatusStore.refresh()
        else if (selectedAction === 1) root.showSettings()
        else root.close()
    }
    function moveAction(direction) { selectedAction = (selectedAction + (direction < 0 ? 2 : 1)) % 3 }

    Connections {
        target: StatusStore
        function onNeedsInstallChanged() {
            if (StatusStore.needsInstall && root.opened) root.showSettings()
        }
        function onPaymentDataChanged() {
            const requestId = StatusStore.paymentData && StatusStore.paymentData.request_id ? StatusStore.paymentData.request_id : ""
            if (requestId !== "" && requestId !== root.lastAutomaticRequest) {
                root.lastAutomaticRequest = requestId
                root.page = "receive"
            }
        }
        function onSetupDataChanged() {
            setupForm.endpoint = StatusStore.setupData.endpoint || "http://127.0.0.1:18081"
            setupForm.marketEnabled = StatusStore.setupData.market_enabled === true
            setupForm.marketSource = StatusStore.setupData.market_source || ({name:"Kraken",url:"",price_pointer:"/price",points_pointer:"/points",timestamp_pointer:"/timestamp",point_price_pointer:"/price",interval_secs:3600})
            const config = StatusStore.setupData.modules || {}
            modulesForm.walletRpc = config.wallet_rpc || ""
            modulesForm.watchOnlyConfirmed = config.watch_only_confirmed === true
            modulesForm.notifyPayments = config.notify_payments === true
            modulesForm.xmrigUrl = config.xmrig_url || ""
            modulesForm.p2poolDirectory = config.p2pool_directory || ""
        }
    }
    Ui.KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: catcher
        contentWidth: fittedContentWidth(Style.space(430))
        contentHeight: fittedContentHeight(content.implicitHeight)
        Ui.PanelKeyCatcher {
            id: catcher
            anchors.fill: parent
            blocked: root.page !== "overview"
            Keys.onEscapePressed: root.close()
            onCloseRequested: root.close()
            onMoveRequested: function(dx, dy) { root.moveAction(dx || dy) }
            onTabRequested: function(direction) { root.moveAction(direction) }
            onActivateRequested: root.activate()
            onTextKey: function(text) { if (text.toLowerCase() === "r") StatusStore.refresh(); else if (text.toLowerCase() === "s") root.showSettings() }
            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: content
                    width: parent.width
                    spacing: root.spaces.md
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(30)
                            horizontalPadding: Style.space(30)
                            verticalPadding: 0
                            leftAlign: true
                            text: "OmaMonero"
                            tooltipText: "About OmaMonero"
                            fontSize: root.typography.heading
                            focusable: true
                            Accessible.name: "About OmaMonero"
                            onClicked: root.page = "about"
                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(5)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Style.space(22)
                                height: width
                                source: Qt.resolvedUrl("assets/OmaMonero-logo.svg")
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                            }
                        }
                        Ui.Button { text: "Reload"; hasCursor: root.page === "overview" && root.selectedAction === 0; focusable: true; onClicked: StatusStore.refresh() }
                        Ui.Button { text: "Close"; hasCursor: root.page === "overview" && root.selectedAction === 2; focusable: true; onClicked: root.close() }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.Button { text: "Overview"; selected: root.page === "overview"; focusable: true; onClicked: root.page = "overview" }
                        Ui.Button { text: "Receive"; selected: root.page === "receive"; focusable: true; onClicked: { root.page = "receive"; if (StatusStore.controlsAvailable) StatusStore.command("info") } }
                        Ui.Button { text: "Modules"; selected: root.page === "modules"; focusable: true; onClicked: { root.page = "modules"; if (StatusStore.controlsAvailable) StatusStore.command("info") } }
                        Ui.Button { text: "Settings"; selected: root.page === "settings"; hasCursor: root.page === "overview" && root.selectedAction === 1; focusable: true; onClicked: root.showSettings() }
                        Ui.Button {
                            text: "Diag"
                            tooltipText: "Diagnostics"
                            selected: root.page === "diagnostics"
                            focusable: true
                            onClicked: { root.page = "diagnostics"; if (StatusStore.controlsAvailable && !root.busy) StatusStore.command("diagnostics") }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.busy || StatusStore.setup.state === "error" || !!StatusStore.setupData.message
                        text: root.busy ? "Working…" : StatusStore.setup.state === "error" ? StatusStore.setup.message || "The action could not complete." : StatusStore.setupData.message || ""
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        color: StatusStore.setup.state === "error" ? Commons.Color.urgent : Commons.Color.foreground
                        font.family: root.typography.family
                        font.pixelSize: root.typography.body
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "overview"
                        spacing: root.spaces.md
                        Components.MarketChart { Layout.fillWidth: true; market: root.view.market }
                        Ui.PanelSeparator { Layout.fillWidth: true }
                        Text {
                            Layout.fillWidth: true
                            text: root.view.message
                            wrapMode: Text.WordWrap
                            color: root.hasMetrics ? Commons.Color.accent : Commons.Color.urgent
                            font.family: root.typography.family
                            font.pixelSize: root.typography.body
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: !root.hasMetrics
                            text: root.view.state === "offline" ? "The node is not reachable. Prices work independently; check the node address in Settings."
                                : root.view.state === "missing" ? "Open Settings to download and install the matching backend."
                                : "Open Diagnostics to check the background service."
                            wrapMode: Text.WordWrap
                            color: Commons.Color.foreground
                            opacity: 0.7
                            font.family: root.typography.family
                            font.pixelSize: root.typography.body
                        }
                        Components.SyncProgress { Layout.fillWidth: true; visible: root.hasMetrics; percent: root.hasMetrics ? root.view.node.sync_percent : null }
                        Components.NodeStatus { Layout.fillWidth: true; visible: root.hasMetrics; node: root.hasMetrics ? root.view.node : null }
                        Ui.PanelSeparator { Layout.fillWidth: true }
                        Components.PrivacyStatus { Layout.fillWidth: true; privacy: root.view.privacy }
                    }
                    Components.AboutPage {
                        Layout.fillWidth: true
                        visible: root.page === "about"
                    }
                    Components.PaymentsPage {
                        Layout.fillWidth: true
                        visible: root.page === "receive"
                        details: StatusStore.setupData
                        payment: StatusStore.paymentData
                        incomingRequests: StatusStore.incomingRequests
                        modules: root.view.modules || null
                        busy: root.busy
                        onActionRequested: function(action, payload) { StatusStore.command(action, undefined, undefined, payload) }
                        onRequestSelected: function(payment) { StatusStore.paymentData = payment }
                        onCloseRequested: root.close()
                    }
                    Components.ModulesPage {
                        id: modulesForm
                        Layout.fillWidth: true
                        visible: root.page === "modules"
                        modules: root.view.modules || null
                        onRefreshRequested: StatusStore.refresh()
                        onConfigRequested: function(walletRpc, confirmed, xmrigUrl, directory, notify) {
                            StatusStore.command("module-config",undefined,undefined,{wallet_rpc:walletRpc.trim(),watch_only_confirmed:confirmed,xmrig_url:xmrigUrl.trim(),p2pool_directory:directory.trim(),notify_payments:notify})
                        }
                    }
                    Components.SetupPage {
                        id: setupForm
                        Layout.fillWidth: true
                        visible: root.page === "settings"
                        pending: StatusStore.needsInstall
                        available: StatusStore.controlsAvailable
                        busy: root.busy
                        onApplyRequested: function(endpoint, marketEnabled, marketSource) { StatusStore.command(StatusStore.needsInstall ? "install" : "save", endpoint, marketEnabled, {market_source: marketSource}) }
                        onRemoveRequested: StatusStore.command("remove")
                        onCloseRequested: root.close()
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "diagnostics"
                        Text {
                            Layout.fillWidth: true
                            text: "Node: " + root.view.message + "\nBackend: " + (root.view.state === "stale" ? "Heartbeat stale" : root.view.state === "missing" ? "Not installed / inactive" : "Status received") + "\nP2P route: unverified"
                            wrapMode: Text.WordWrap
                            color: Commons.Color.foreground
                            font.family: root.typography.family
                            font.pixelSize: root.typography.body
                        }
                        Text {
                            Layout.fillWidth: true
                            text: StatusStore.setupData.diagnostics ? "Live RPC: " + StatusStore.setupData.diagnostics.rpc.node.state + "\nStored status: " + StatusStore.setupData.diagnostics.snapshot.state : StatusStore.setupData.message || "Checks are read-only and do not start the node or require administrator access."
                            wrapMode: Text.WordWrap
                            color: Commons.Color.foreground
                            opacity: 0.7
                            font.family: root.typography.family
                            font.pixelSize: root.typography.body
                        }
                        Ui.Button { text: "Check now"; enabled: StatusStore.controlsAvailable && !root.busy; focusable: true; onClicked: StatusStore.command("diagnostics") }
                    }
                }
            }
        }
    }
}
