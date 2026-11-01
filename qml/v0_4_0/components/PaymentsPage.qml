pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
    property var details: ({})
    property var payment: ({})
    property var incomingRequests: []
    property var modules: null
    property bool busy: false
    property string mode: "receive"
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    signal actionRequested(string action, var payload)
    signal requestSelected(var payment)
    signal closeRequested()
    spacing: root.spaces.md
    Keys.onEscapePressed: root.closeRequested()
    RowLayout {
        Ui.Button { text: "Receive / QR"; selected: root.mode === "receive"; focusable: true; onClicked: root.mode = "receive" }
        Ui.Button { text: "Payment link"; selected: root.mode === "link"; focusable: true; onClicked: root.mode = "link" }
        Ui.Button { text: "Proof"; selected: root.mode === "proof"; focusable: true; onClicked: root.mode = "proof" }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.mode === "receive"
        Text { text: "Receive XMR"; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.heading }
        Text {
            Layout.fillWidth: true
            text: "Paste your public receiving address from your wallet. Never enter a seed or private key. The QR is created locally."
            wrapMode: Text.WordWrap
            color: Commons.Color.foreground
            opacity: 0.7
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
        Ui.TextField { id: address; Layout.fillWidth: true; onTextEdited: root.actionRequested("clear-payment", {}); placeholderText: "Public Monero address"; text: root.details.receive_address || ""; enabled: !root.busy; Keys.onEscapePressed: root.closeRequested() }
        Ui.Button {
            visible: !!root.modules && !!root.modules.wallet && !!root.modules.wallet.address
            text: "Use watch-only wallet address"
            focusable: true
            onClicked: address.text = root.modules.wallet.address
        }
        Ui.TextField { id: amount; Layout.fillWidth: true; onTextEdited: root.actionRequested("clear-payment", {}); placeholderText: "Optional amount · XMR (up to 12 decimal places)"; enabled: !root.busy; Keys.onEscapePressed: root.closeRequested() }
        Ui.TextField { id: label; Layout.fillWidth: true; onTextEdited: root.actionRequested("clear-payment", {}); placeholderText: "Optional recipient label"; enabled: !root.busy; Keys.onEscapePressed: root.closeRequested() }
        Ui.Button {
            text: "Create receive QR"
            bordered: true
            focusable: true
            enabled: !root.busy && address.text.length > 0
            onClicked: root.actionRequested("receive", {address: address.text.trim(), amount: amount.text.trim(), label: label.text})
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.mode === "link"
        Ui.TextField { id: uri; Layout.fillWidth: true; onTextEdited: root.actionRequested("clear-payment", {}); placeholderText: "Paste monero: payment link"; enabled: !root.busy; Keys.onEscapePressed: root.closeRequested() }
        Ui.Button { text: "Preview payment link"; bordered: true; focusable: true; enabled: !root.busy && uri.text.length > 0; onClicked: root.actionRequested("preview-uri", {uri: uri.text.trim()}) }
        Ui.Button { text: root.details.uri_handler ? "monero: links open here" : "Open monero: links in this bar"; focusable: true; enabled: !root.busy && !root.details.uri_handler; onClicked: root.actionRequested("register-uri", {}) }
        Text { Layout.fillWidth: true; visible: root.incomingRequests.length > 0; text: "Recent payment links · stored privately in this session"; color: Commons.Color.foreground; opacity: 0.7; font.family: root.typography.family; font.pixelSize: root.typography.bodySmall }
        Repeater {
            model: root.incomingRequests
            delegate: Ui.Button {
                required property var modelData
                Layout.fillWidth: true
                focusable: true
                text: (modelData.payment.amount ? modelData.payment.amount + " XMR" : "Payment link") + " · " + Qt.formatDateTime(new Date(modelData.created_at * 1000), "MMM d, hh:mm")
                onClicked: root.requestSelected(modelData.payment)
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.mode === "proof"
        Text { Layout.fillWidth: true; text: "Verify transaction proof through your configured local watch-only RPC. This never spends funds or retrieves wallet keys."; wrapMode: Text.WordWrap; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.body }
        Ui.TextField { id: txid; Layout.fillWidth: true; enabled: !root.busy; onTextEdited: root.actionRequested("clear-proof", {}); placeholderText: "Transaction ID"; Keys.onEscapePressed: root.closeRequested() }
        Ui.TextField { id: proofAddress; Layout.fillWidth: true; enabled: !root.busy; onTextEdited: root.actionRequested("clear-proof", {}); placeholderText: "Recipient public address"; Keys.onEscapePressed: root.closeRequested() }
        Ui.TextField { id: message; Layout.fillWidth: true; enabled: !root.busy; onTextEdited: root.actionRequested("clear-proof", {}); placeholderText: "Message (if supplied with proof)"; Keys.onEscapePressed: root.closeRequested() }
        Ui.TextField { id: signature; Layout.fillWidth: true; enabled: !root.busy; onTextEdited: root.actionRequested("clear-proof", {}); placeholderText: "Transaction proof signature"; Keys.onEscapePressed: root.closeRequested() }
        Ui.Button { text: "Verify proof"; bordered: true; focusable: true; enabled: !root.busy && txid.text.length === 64 && proofAddress.text.length > 0 && signature.text.length > 0; onClicked: root.actionRequested("proof",{txid:txid.text,address:proofAddress.text.trim(),message:message.text,signature:signature.text.trim()}) }
        Text {
            Layout.fillWidth: true
            visible: !!root.details.proof
            text: root.details.proof ? root.details.proof.good ? "Proof valid · confirmations: " + root.details.proof.confirmations : "Proof does not match this transaction/address/message" : ""
            wrapMode: Text.WordWrap
            color: root.details.proof && root.details.proof.good ? "#22c55e" : "#ef4444"
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !!root.payment.error
        text: root.payment.error || ""
        wrapMode: Text.WordWrap
        color: Commons.Color.urgent
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.mode !== "proof" && !!root.payment.uri
        Text {
            Layout.fillWidth: true
            text: root.payment.incoming_request ? "Incoming payment request · review in your wallet" : "Your receive request"
            wrapMode: Text.WordWrap
            color: Commons.Color.foreground
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Style.space(210)
            Layout.preferredHeight: Style.space(210)
            source: root.payment.qr_svg ? "data:image/svg+xml;charset=utf-8," + encodeURIComponent(root.payment.qr_svg) : ""
            fillMode: Image.PreserveAspectFit
            smooth: false
        }
        Text { Layout.fillWidth: true; text: root.payment.address || ""; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.bodySmall }
        Text { text: root.payment.amount ? "Amount: " + root.payment.amount + " XMR" : "No fixed amount"; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.body }
        RowLayout {
            Ui.Button { text: "Copy address"; focusable: true; onClicked: Quickshell.clipboardText = root.payment.address }
            Ui.Button { text: "Copy monero: link"; focusable: true; onClicked: Quickshell.clipboardText = root.payment.uri }
        }
    }
    Ui.PanelSeparator { Layout.fillWidth: true }
    RowLayout {
        Ui.Button {
            text: "Open Feather"
            enabled: !root.busy && !!root.details.wallets && root.details.wallets.feather
            focusable: true
            onClicked: { if (root.payment.uri) Quickshell.clipboardText = root.payment.uri; root.actionRequested("wallet", {wallet: "feather"}) }
        }
        Ui.Button {
            text: "Open Monero GUI"
            enabled: !root.busy && !!root.details.wallets && root.details.wallets.monero_gui
            focusable: true
            onClicked: { if (root.payment.uri) Quickshell.clipboardText = root.payment.uri; root.actionRequested("wallet", {wallet: "monero_gui"}) }
        }
    }
    Text { Layout.fillWidth: true; text: "Wallet launch is explicit. Requests are copied for pasting into the wallet; nothing is sent automatically."; wrapMode: Text.WordWrap; color: Commons.Color.foreground; opacity: 0.6; font.family: root.typography.family; font.pixelSize: root.typography.bodySmall }
}
