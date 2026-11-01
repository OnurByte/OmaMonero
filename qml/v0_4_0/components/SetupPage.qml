pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
    property string transport: "local"
    property string proxy: ""
    property string network: "mainnet"
    property bool confirmLegacy: false
    property string endpoint: "http://127.0.0.1:18081"
    property bool marketEnabled: false
    property var marketSource: ({name:"Kraken",url:"",price_pointer:"/price",points_pointer:"/points",timestamp_pointer:"/timestamp",point_price_pointer:"/price",interval_secs:3600})
    property bool pending: false
    property bool available: false
    property bool busy: false
    property bool confirmingRemoval: false
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    signal applyRequested(string endpoint, bool marketEnabled, var marketSource)
    signal removeRequested()
    signal legacyCleanupRequested()
    signal closeRequested()
    spacing: root.spaces.md
    Keys.onEscapePressed: root.closeRequested()
    Text {
        Layout.fillWidth: true
        text: root.pending ? "Install in your Omarchy bar" : "Settings"
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.heading
    }
    Text {
        Layout.fillWidth: true
        text: root.available ? "TypeScript runs inside this bar. No OmaMonero backend, installer or service is needed. The Monero node is optional." : "Preparing private settings…"
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        opacity: 0.7
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
    Text {
        text: "Node RPC address"
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
    Ui.TextField {
        id: endpointField
        Layout.fillWidth: true
        enabled: root.available && !root.busy
        text: root.endpoint
        placeholderText: "http://127.0.0.1:18081"
        onTextEdited: root.endpoint = text
        Keys.onEscapePressed: root.closeRequested()
    }
    Text { text: "Connection policy"; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.body }
    RowLayout {
        Repeater {
            model: ["local", "direct", "tor", "i2p"]
            Ui.Button { required property string modelData; text: modelData; selected: root.transport === modelData; enabled: root.available && !root.busy; onClicked: {root.transport=modelData;if(modelData === "local" || modelData === "direct")root.proxy=""} }
        }
    }
    Ui.TextField { Layout.fillWidth: true; visible: root.transport === "tor" || root.transport === "i2p"; text: root.proxy; placeholderText: "socks5h://127.0.0.1:9050"; onTextEdited: root.proxy=text }
    Text { Layout.fillWidth: true; text: "Tor/I2P uses the selected SOCKS5h proxy for node and market requests. Failure never falls back to a direct connection. Wallet and XMRig always stay on numeric loopback."; wrapMode: Text.WordWrap; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.bodySmall }
    RowLayout {
        Repeater {
            model: ["mainnet", "testnet", "stagenet"]
            Ui.Button { required property string modelData; text: modelData; selected: root.network === modelData; enabled: root.available && !root.busy; onClicked: root.network=modelData }
        }
    }
    Ui.Toggle {
        Layout.fillWidth: true
        enabled: root.available && !root.busy
        label: "XMR / USD · 24h"
        description: "Enable public XMR/USD prices every two minutes. Requests use your configured proxy. Node and wallet data are never sent."
        checked: root.marketEnabled
        onClicked: root.marketEnabled = !root.marketEnabled
    }
    Text {
        Layout.fillWidth: true
        text: "Price source · leave the address empty for Kraken"
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
    Ui.TextField {
        Layout.fillWidth: true
        enabled: root.available && !root.busy && root.marketEnabled
        text: root.marketSource.name || "Kraken"
        placeholderText: "Source name, e.g. My Exchange"
        onTextEdited: root.marketSource.name = text
    }
    Ui.TextField {
        Layout.fillWidth: true
        enabled: root.available && !root.busy && root.marketEnabled
        text: root.marketSource.url || ""
        placeholderText: "https://api.example/market.json (empty = Kraken)"
        onTextEdited: root.marketSource.url = text
    }
    Text {
        Layout.fillWidth: true
        text: "For custom APIs, enter JSON Pointers for the current price, history array, each sample’s Unix timestamp (seconds), and sample price. The response must include at least 24 hours of ordered XMR/USD samples."
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        opacity: 0.65
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
    Text {
        Layout.fillWidth: true
        text: 'Example JSON: {"price":124,"points":[{"timestamp":186400,"price":124}]} · numeric values or numeric strings are accepted.'
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        opacity: 0.55
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
    Ui.TextField {
        Layout.fillWidth: true
        enabled: root.available && !root.busy && root.marketEnabled && !!root.marketSource.url
        text: root.marketSource.price_pointer || "/price"
        placeholderText: "Current price pointer, e.g. /data/price"
        onTextEdited: root.marketSource.price_pointer = text
    }
    Ui.TextField {
        Layout.fillWidth: true
        enabled: root.available && !root.busy && root.marketEnabled && !!root.marketSource.url
        text: root.marketSource.points_pointer || "/points"
        placeholderText: "History array pointer, e.g. /data/history"
        onTextEdited: root.marketSource.points_pointer = text
    }
    RowLayout {
        Layout.fillWidth: true
        enabled: root.available && !root.busy && root.marketEnabled && !!root.marketSource.url
        Ui.TextField {
            Layout.fillWidth: true
            text: root.marketSource.timestamp_pointer || "/timestamp"
            placeholderText: "Sample time pointer"
            onTextEdited: root.marketSource.timestamp_pointer = text
        }
        Ui.TextField {
            Layout.fillWidth: true
            text: root.marketSource.point_price_pointer || "/price"
            placeholderText: "Sample price pointer"
            onTextEdited: root.marketSource.point_price_pointer = text
        }
    }
    RowLayout {
        Layout.fillWidth: true
        enabled: root.available && !root.busy && !!root.marketSource.url
        Repeater {
            model: [{seconds:300,label:"5m"},{seconds:900,label:"15m"},{seconds:1800,label:"30m"},{seconds:3600,label:"1h"}]
            Ui.Button {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label
                selected: root.marketSource.interval_secs === modelData.seconds
                focusable: true
                onClicked: root.marketSource.interval_secs = modelData.seconds
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Remote direct node connections require HTTPS. Existing Tor/I2P proxy policy is retained.\n\nTested locally · Not officially marketplace-verified."
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        opacity: 0.6
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
    Ui.Button {
        Layout.fillWidth: true
        enabled: root.available && !root.busy
        text: root.busy ? "Working…" : root.pending ? "Install OmaMonero" : "Save settings"
        bordered: true
        focusable: true
        onClicked: root.applyRequested(root.endpoint, root.marketEnabled, root.marketSource)
    }
    Ui.Button { text: root.confirmLegacy ? "Cancel old service cleanup" : "Previous version: stop old user service"; enabled: root.available && !root.busy; onClicked: root.confirmLegacy=!root.confirmLegacy }
    Text { Layout.fillWidth: true; visible: root.confirmLegacy; text: "Stop and disable only the old omamonero user service? Your settings, Monero node and wallet remain in place."; wrapMode: Text.WordWrap; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.bodySmall }
    Ui.Button { visible: root.confirmLegacy; text: "Confirm: stop old service"; enabled: !root.busy; onClicked: { root.confirmLegacy=false; root.legacyCleanupRequested() } }
    Ui.PanelSeparator { Layout.fillWidth: true }
    Ui.Button {
        Layout.fillWidth: true
        visible: !root.confirmingRemoval
        enabled: root.available && !root.busy
        text: "Remove OmaMonero"
        foreground: Commons.Color.urgent
        focusable: true
        onClicked: root.confirmingRemoval = true
    }
    Text {
        Layout.fillWidth: true
        visible: root.confirmingRemoval
        text: "Remove this widget through the Omarchy plugin manager? Settings are kept. Any owned payment-link handler is restored first."
        wrapMode: Text.WordWrap
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
    RowLayout {
        visible: root.confirmingRemoval
        Layout.fillWidth: true
        Ui.Button { text: "Cancel"; focusable: true; onClicked: root.confirmingRemoval = false }
        Ui.Button {
            text: "Remove"
            enabled: !root.busy
            foreground: Commons.Color.urgent
            bordered: true
            focusable: true
            onClicked: { root.confirmingRemoval = false; root.removeRequested() }
        }
    }
}
