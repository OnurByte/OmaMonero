pragma ComponentBehavior: Bound
import QtQuick
import "../Status.js" as Status
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
    property var modules: null
    property string walletRpc: ""
    property bool watchOnlyConfirmed: false
    property bool notifyPayments: false
    property string xmrigUrl: ""
    property string p2poolDirectory: ""
    property bool configuring: false
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    signal settingsRequested()
    signal refreshRequested()
    signal configRequested(string wallet_rpc, bool confirmed, string xmrig_url, string p2pool_directory, bool notify_payments)
    spacing: root.spaces.sm
    function stateLabel(value) {
        if (!value || value.state === "disabled") return "Disabled · configure to enable"
        if (value.state === "confirmation_required") return "Confirm your wallet is watch-only in settings"
        if (value.state === "unavailable") return value.error || "Unavailable"
        if (value.state === "stale") return "Stale · check P2Pool"
        if (value.state === "ready") return "Connected"
        return "Unavailable"
    }
    function amount(value) { return Status.atomicLabel(value) }
    function number(value, suffix) { return value === null || value === undefined ? "—" : value + (suffix || "") }
    Text {
        text: "Wallet & mining"
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.heading
    }
    Metric { Layout.fillWidth: true; label: "Watch-only wallet"; value: root.stateLabel(root.modules ? root.modules.wallet : null) }
    Metric { Layout.fillWidth: true; label: "Balance · account 0"; value: root.amount(root.modules && root.modules.wallet ? root.modules.wallet.balance_atomic : null) }
    Metric { Layout.fillWidth: true; label: "Unlocked"; value: root.amount(root.modules && root.modules.wallet ? root.modules.wallet.unlocked_balance_atomic : null) }
    Text {
        Layout.fillWidth: true
        text: "Watch-only is your confirmation, not independently verified. Outgoing payments may be missing without imported key images, so balances may overstate spendable funds. OmaMonero never sends payments or reads keys."
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        opacity: 0.7
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
    Text {
        Layout.fillWidth: true
        text: root.modules && root.modules.wallet && root.modules.wallet.incoming_error ? root.modules.wallet.incoming_error : (root.modules && root.modules.wallet && root.modules.wallet.coverage_from_height !== null && root.modules.wallet.coverage_from_height !== undefined ? "Latest 20 incoming payments · recent 720-block window from height " + root.modules.wallet.coverage_from_height + " and current pool. Earlier history is not loaded." : "Recent incoming payments unavailable")
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        opacity: 0.7
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
    Repeater {
        model: root.modules && root.modules.wallet ? root.modules.wallet.incoming : []
        delegate: ColumnLayout {
            id: incomingRow
            required property var modelData
            Layout.fillWidth: true
            Metric { Layout.fillWidth: true; label: incomingRow.modelData.in_pool ? "Incoming · pool" : "Incoming"; value: root.amount(incomingRow.modelData.amount_atomic) }
            Text {
                Layout.fillWidth: true
                text: incomingRow.modelData.txid + "\nConfirmations: " + root.number(incomingRow.modelData.confirmations)
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Commons.Color.foreground
                opacity: 0.7
                font.family: root.typography.family
                font.pixelSize: root.typography.bodySmall
            }
        }
    }
    Metric { Layout.fillWidth: true; label: "XMRig"; value: root.stateLabel(root.modules ? root.modules.xmrig : null) }
    Metric { Layout.fillWidth: true; label: "Hashrate · 10s"; value: root.number(root.modules && root.modules.xmrig ? root.modules.xmrig.hashrate : null, " H/s") }
    Metric { Layout.fillWidth: true; label: "Accepted / total shares"; value: root.modules && root.modules.xmrig ? root.number(root.modules.xmrig.shares_good) + " / " + root.number(root.modules.xmrig.shares_total) : "—" }
    Metric { Layout.fillWidth: true; label: "P2Pool"; value: root.stateLabel(root.modules ? root.modules.p2pool : null) }
    Metric { Layout.fillWidth: true; label: "Hashrate · 15m"; value: root.number(root.modules && root.modules.p2pool ? root.modules.p2pool.hashrate_15m : null, " H/s") }
    Metric { Layout.fillWidth: true; label: "Shares found"; value: root.number(root.modules && root.modules.p2pool ? root.modules.p2pool.shares_found : null) }
    Metric { Layout.fillWidth: true; label: "P2Pool updated"; value: root.modules && root.modules.p2pool && root.modules.p2pool.updated_at ? new Date(root.modules.p2pool.updated_at * 1000).toLocaleString() : "—" }
    RowLayout {
        Ui.Button { text: "Refresh"; onClicked: root.refreshRequested() }
        Ui.Button { text: root.configuring ? "Hide setup" : "Configure modules"; onClicked: { root.configuring = !root.configuring; root.settingsRequested() } }
    }
    ColumnLayout {
        visible: root.configuring
        Layout.fillWidth: true
        spacing: root.spaces.sm
        Text {
            Layout.fillWidth: true
            text: "Use existing local services. Leave a field empty to disable it. Authentication is unsupported. Services are never installed or started automatically."
            wrapMode: Text.WordWrap
            color: Commons.Color.foreground
            font.family: root.typography.family
            font.pixelSize: root.typography.bodySmall
        }
        Ui.TextField { id: walletField; Layout.fillWidth: true; text: root.walletRpc; placeholderText: "Wallet RPC · http://127.0.0.1:18082" }
        Ui.Toggle {
            Layout.fillWidth: true
            label: "I confirm this wallet is watch-only"
            description: "Do not connect a wallet holding spend keys. Only account 0 is displayed."
            checked: root.watchOnlyConfirmed
            onClicked: root.watchOnlyConfirmed = !root.watchOnlyConfirmed
        }
        Ui.Toggle {
            Layout.fillWidth: true
            label: "Local payment notifications"
            description: "Notify about new incoming payments after the first wallet scan. No address or amount is put in notifications."
            checked: root.notifyPayments
            onClicked: root.notifyPayments = !root.notifyPayments
        }
        Ui.TextField { id: minerField; Layout.fillWidth: true; text: root.xmrigUrl; placeholderText: "XMRig HTTP API · http://127.0.0.1:18088" }
        Ui.TextField { id: poolField; Layout.fillWidth: true; text: root.p2poolDirectory; placeholderText: "Absolute P2Pool data API directory" }
        Text {
            Layout.fillWidth: true
            text: "P2Pool needs its data API and local API enabled. The local/stratum file is read; files older than two minutes are marked stale."
            wrapMode: Text.WordWrap
            color: Commons.Color.foreground
            opacity: 0.7
            font.family: root.typography.family
            font.pixelSize: root.typography.bodySmall
        }
        Ui.Button { text: "Save modules"; onClicked: root.configRequested(walletField.text, root.watchOnlyConfirmed, minerField.text, poolField.text, root.notifyPayments) }
    }
}
