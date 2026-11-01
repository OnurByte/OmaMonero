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
    property bool chartExpanded: false
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    readonly property var view: StatusStore.view
    readonly property bool hasMetrics: view.state === "online" || view.state === "syncing"
    readonly property bool busy: StatusStore.setup.state === "running"

    function open() {
        selectedAction = 0
        if (StatusStore.pendingSetup) page = "settings"
        StatusStore.refresh()
        if (StatusStore.controlsAvailable) StatusStore.command("info")
        controller.show()
    }
    function openAbout() {
        root.page = StatusStore.pendingSetup ? "settings" : "about"
        root.open()
    }
    function showSettings(advanced) {
        setupForm.advancedOpen = advanced === true
        page = "settings"
        setupForm.endpoint = StatusStore.setupData.endpoint || "http://127.0.0.1:18081"
        setupForm.transport = StatusStore.setupData.transport || "local"
        setupForm.proxy = StatusStore.setupData.proxy || ""
        setupForm.network = StatusStore.setupData.network || "mainnet"
        setupForm.marketEnabled = StatusStore.setupData.market_enabled === true
        setupForm.marketSource = Object.assign({},StatusStore.setupData.market_source || ({name:"Kraken",url:"",price_pointer:"/price",points_pointer:"/points",timestamp_pointer:"/timestamp",point_price_pointer:"/price",interval_secs:3600}))
        if (StatusStore.controlsAvailable) StatusStore.command("info")
    }
    function navigate(destination) {
        page = destination
        if (StatusStore.controlsAvailable) StatusStore.command("info")
    }
    function activate() { navigate(selectedAction === 0 ? "overview" : selectedAction === 1 ? "receive" : "tools") }
    function moveAction(direction) { selectedAction = (selectedAction + (direction < 0 ? 2 : 1)) % 3 }

    Connections {
        target: StatusStore
        function onPaymentDataChanged() {
            const requestId = StatusStore.paymentData && StatusStore.paymentData.request_id ? StatusStore.paymentData.request_id : ""
            if (requestId !== "" && requestId !== root.lastAutomaticRequest) {
                root.lastAutomaticRequest = requestId
                root.page = "receive"
            }
        }
        function onSetupDataChanged() {
            setupForm.endpoint = StatusStore.setupData.endpoint || "http://127.0.0.1:18081"
        setupForm.transport = StatusStore.setupData.transport || "local"
        setupForm.proxy = StatusStore.setupData.proxy || ""
        setupForm.network = StatusStore.setupData.network || "mainnet"
            setupForm.marketEnabled = StatusStore.setupData.market_enabled === true
            setupForm.marketSource = Object.assign({},StatusStore.setupData.market_source || ({name:"Kraken",url:"",price_pointer:"/price",points_pointer:"/points",timestamp_pointer:"/timestamp",point_price_pointer:"/price",interval_secs:3600}))
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
        contentWidth: fittedContentWidth(Style.space(root.chartExpanded && root.page === "overview" ? 760 : 560))
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
                            Layout.preferredWidth: brandMark.implicitWidth + Style.space(16)
                            Layout.preferredHeight: Style.space(34)
                            text: ""
                            tooltipText: "About OmaMonero"
                            focusable: true
                            Accessible.name: "About OmaMonero"
                            onClicked: root.page="about"
                            Row {
                                id:brandMark
                                anchors.centerIn:parent
                                spacing:Style.space(6)
                                Image {width:Style.space(22);height:width;anchors.verticalCenter:parent.verticalCenter;source:Qt.resolvedUrl("assets/OmaMonero-logo.svg");fillMode:Image.PreserveAspectFit;smooth:false}
                                Text {text:"OmaMonero";anchors.verticalCenter:parent.verticalCenter;color:Commons.Color.foreground;font.family:root.typography.family;font.pixelSize:root.typography.heading}
                            }
                        }
                        Item {Layout.fillWidth:true}
                        Ui.Button { text: "Close"; focusable: true; onClicked: root.close() }
                    }
                    Components.PanelNavigation {
                        Layout.fillWidth: true
                        page: root.page
                        cursorIndex: root.page === "overview" ? root.selectedAction : -1
                        onPageRequested: function(destination) { root.navigate(destination) }
                    }
                    Ui.Button {
                        visible: ["overview", "receive", "tools"].indexOf(root.page) < 0
                        text: "Back to More"
                        focusable: true
                        onClicked: root.page = "tools"
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.busy || StatusStore.setup.state === "error" || (root.page !== "overview" && !!StatusStore.setupData.message)
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
                        Components.MarketChart {
                            Layout.fillWidth:true
                            market:root.view.market
                            busy:StatusStore.marketBusy
                            customSource:!!StatusStore.config.market_source.url
                            selectedInterval:StatusStore.chartIntervalSecs
                            expanded:root.chartExpanded
                            onIntervalRequested:function(seconds){StatusStore.selectChartInterval(seconds)}
                            onExpandRequested:root.chartExpanded=!root.chartExpanded
                        }
                        Ui.Button {
                            Layout.fillWidth: !root.view.market || root.view.market.state !== "ready"
                            text: root.view.market.state === "disabled" ? "Resume prices" : root.view.market.state === "loading" ? "Loading prices…" : root.view.market.state === "ready" ? "Refresh" : "Try again"
                            enabled: StatusStore.controlsAvailable && !root.busy && root.view.market.state !== "loading"
                            bordered: root.view.market.state !== "ready"
                            focusable: true
                            onClicked: { if(root.view.market.state === "disabled")StatusStore.command("market-enable");else StatusStore.refresh(true) }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "tools"
                        spacing: root.spaces.sm
                        Text { text: "Optional tools"; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.bodySmall; opacity: 0.6 }
                        Ui.Button { Layout.fillWidth: true; text: "Wallet & mining"; focusable: true; onClicked: root.navigate("modules") }
                        Ui.Button { Layout.fillWidth: true; text: "Monero node"; focusable: true; onClicked: root.navigate("node") }
                        Ui.PanelSeparator { Layout.fillWidth: true }
                        Ui.Button { Layout.fillWidth: true; text: "Settings"; focusable: true; onClicked: root.showSettings() }
                        Ui.Button { Layout.fillWidth: true; text: "Diagnostics"; focusable: true; onClicked: {root.page="diagnostics";StatusStore.command("diagnostics")} }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "node"
                        spacing: root.spaces.md
                        Text { text: "Monero node"; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.heading }
                        Text {
                            Layout.fillWidth: true
                            text: root.hasMetrics ? root.view.message : "No node connected · optional"
                            color: Commons.Color.foreground
                            font.family: root.typography.family
                            font.pixelSize: root.typography.body
                        }
                        Text { Layout.fillWidth: true; visible: !root.hasMetrics; text: "Prices and payment QR codes work without a node. Connect one to follow its sync and network status."; wrapMode: Text.WordWrap; color: Commons.Color.foreground; opacity:0.65; font.family:root.typography.family; font.pixelSize:root.typography.bodySmall }
                        Components.SyncProgress { Layout.fillWidth: true; visible: root.hasMetrics; percent: root.hasMetrics ? root.view.node.sync_percent : null }
                        Components.NodeStatus { Layout.fillWidth: true; visible: root.hasMetrics; node: root.hasMetrics ? root.view.node : null }
                        Components.PrivacyStatus { Layout.fillWidth: true; privacy: root.view.privacy }
                        Ui.Button { text: "Connection settings"; focusable:true; onClicked:root.showSettings(true) }
                    }
                    Components.AboutPage {
                        Layout.fillWidth: true
                        visible: root.page === "about"
                        appVersion: root.hostWidget && root.hostWidget.manifest ? root.hostWidget.manifest.version : "0.4.2"
                        priceSource: StatusStore.config.market_source.url ? StatusStore.config.market_source.name : "Kraken"
                        connection: StatusStore.config.transport
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
                        pending: StatusStore.pendingSetup
                        available: StatusStore.controlsAvailable
                        busy: root.busy
                        onApplyRequested: function(endpoint, marketEnabled, marketSource) { StatusStore.command(StatusStore.pendingSetup ? "install" : "save", endpoint, marketEnabled, {market_source: marketSource,transport:setupForm.transport,proxy:setupForm.proxy,network:setupForm.network}) }
                        onRemoveRequested: StatusStore.command("remove")
                        onLegacyCleanupRequested: StatusStore.command("legacy-cleanup")
                        onCloseRequested: root.close()
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "diagnostics"
                        Text {
                            Layout.fillWidth: true
                            text: "Prices: " + root.view.market.state + "\nNode: " + (root.hasMetrics ? root.view.message : "Not connected · optional") + "\nConnection: " + StatusStore.config.transport
                            wrapMode: Text.WordWrap
                            color: Commons.Color.foreground
                            font.family: root.typography.family
                            font.pixelSize: root.typography.body
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Checks are read-only. They never start a node or send a payment."
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
