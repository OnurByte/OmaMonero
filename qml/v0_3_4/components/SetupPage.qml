pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
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
        text: root.available ? "Everything runs in your user account. No administrator password is needed. A Monero node is optional for price viewing." : "Open the downloaded OmaMonero installer to prepare native setup. It will open this bar panel."
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
        text: "Remove the bar widget and stop its background service? Your configuration and additional user data will be kept."
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
