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
    property string endpoint: "http://127.0.0.1:18081"
    property bool marketEnabled: true
    property var marketSource: ({name:"Kraken",url:"",price_pointer:"/price",points_pointer:"/points",timestamp_pointer:"/timestamp",point_price_pointer:"/price",interval_secs:3600})
    property bool pending: false
    property bool available: false
    property bool busy: false
    property bool advancedOpen: false
    property bool maintenanceOpen: false
    property bool useCustomSource: false
    property bool confirmLegacy: false
    property bool confirmingRemoval: false
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    signal applyRequested(string endpoint, bool marketEnabled, var marketSource)
    signal removeRequested()
    signal legacyCleanupRequested()
    signal closeRequested()
    onMarketSourceChanged: useCustomSource = !!marketSource.url
    spacing: root.spaces.md
    Keys.onEscapePressed: root.closeRequested()
    Text {
        text: "Settings"
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.heading
    }
    Ui.Toggle {
        Layout.fillWidth: true
        enabled: root.available && !root.busy
        label: "Public XMR/USD prices"
        description: "Price and 24h chart in your bar. Pause whenever you want."
        checked: root.marketEnabled
        onClicked: root.marketEnabled = !root.marketEnabled
    }
    Text {
        Layout.fillWidth: true
        text: "Source · " + (root.marketSource.url ? root.marketSource.name : "Kraken")
        color: Commons.Color.foreground
        opacity: 0.65
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
    Ui.Button {
        Layout.fillWidth: true
        text: "Advanced settings"
        selected: root.advancedOpen
        focusable: true
        onClicked: root.advancedOpen = !root.advancedOpen
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.advancedOpen
        enabled: root.available && !root.busy
        spacing: root.spaces.sm
        Text { text: "Node · optional"; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.body }
        Ui.TextField {
            Layout.fillWidth: true
            text: root.endpoint
            placeholderText: "Node address · http://127.0.0.1:18081"
            onTextEdited: root.endpoint = text
        }
        Text { text: "Connection policy"; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.bodySmall; opacity:0.65 }
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: [{value:"local",label:"Local"},{value:"direct",label:"HTTPS"},{value:"tor",label:"Tor"},{value:"i2p",label:"I2P"}]
                Ui.Button {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    selected: root.transport === modelData.value
                    focusable: true
                    onClicked: { root.transport=modelData.value; if(root.transport === "local" || root.transport === "direct")root.proxy="" }
                }
            }
        }
        Ui.TextField {
            Layout.fillWidth: true
            visible: root.transport === "tor" || root.transport === "i2p"
            text: root.proxy
            placeholderText: "socks5h://127.0.0.1:9050"
            onTextEdited: root.proxy = text
        }
        Text {
            Layout.fillWidth: true
            text: "Tor/I2P covers node and price requests and never falls back to a direct connection. Wallet and mining connections stay local."
            wrapMode: Text.WordWrap
            color: Commons.Color.foreground
            opacity: 0.6
            font.family: root.typography.family
            font.pixelSize: root.typography.bodySmall
        }
        Text { text: "Monero network"; color: Commons.Color.foreground; font.family: root.typography.family; font.pixelSize: root.typography.bodySmall; opacity:0.65 }
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["mainnet", "testnet", "stagenet"]
                Ui.Button { required property string modelData; Layout.fillWidth: true; text: modelData; selected: root.network === modelData; focusable:true; onClicked:root.network=modelData }
            }
        }
        Ui.PanelSeparator { Layout.fillWidth: true }
        Ui.Toggle {
            Layout.fillWidth: true
            label: "Custom price source"
            description: "Use your own HTTPS market API instead of Kraken."
            checked: root.useCustomSource
            onClicked: {
                root.useCustomSource = !root.useCustomSource
                if(!root.useCustomSource)root.marketSource=({name:"Kraken",url:"",price_pointer:"/price",points_pointer:"/points",timestamp_pointer:"/timestamp",point_price_pointer:"/price",interval_secs:3600})
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.useCustomSource
            spacing: root.spaces.sm
            Ui.TextField { Layout.fillWidth:true; text:root.marketSource.name; placeholderText:"Source name"; onTextEdited:root.marketSource.name=text }
            Ui.TextField { Layout.fillWidth:true; text:root.marketSource.url; placeholderText:"https://api.example/market.json"; onTextEdited:root.marketSource.url=text }
            Text { Layout.fillWidth:true; text:"JSON Pointers map the current USD price and an ordered history covering at least 24 hours. Sample timestamps must be Unix seconds."; wrapMode:Text.WordWrap; color:Commons.Color.foreground; opacity:0.65; font.family:root.typography.family; font.pixelSize:root.typography.bodySmall }
            Ui.TextField { Layout.fillWidth:true; text:root.marketSource.price_pointer; placeholderText:"Price pointer · /price"; onTextEdited:root.marketSource.price_pointer=text }
            Ui.TextField { Layout.fillWidth:true; text:root.marketSource.points_pointer; placeholderText:"History pointer · /points"; onTextEdited:root.marketSource.points_pointer=text }
            Ui.TextField { Layout.fillWidth:true; text:root.marketSource.timestamp_pointer; placeholderText:"Sample time pointer · /timestamp"; onTextEdited:root.marketSource.timestamp_pointer=text }
            Ui.TextField { Layout.fillWidth:true; text:root.marketSource.point_price_pointer; placeholderText:"Sample price pointer · /price"; onTextEdited:root.marketSource.point_price_pointer=text }
            RowLayout {
                Layout.fillWidth:true
                Repeater {
                    model:[{seconds:300,label:"5m"},{seconds:900,label:"15m"},{seconds:1800,label:"30m"},{seconds:3600,label:"1h"}]
                    Ui.Button { required property var modelData; Layout.fillWidth:true; text:modelData.label; selected:root.marketSource.interval_secs===modelData.seconds; focusable:true; onClicked:root.marketSource.interval_secs=modelData.seconds }
                }
            }
        }
        Text { Layout.fillWidth:true; text:"Public providers can see your IP unless a proxy is configured. No wallet or node data is sent to the price provider."; wrapMode:Text.WordWrap; color:Commons.Color.foreground; opacity:0.6; font.family:root.typography.family; font.pixelSize:root.typography.bodySmall }
    }
    Ui.Button {
        Layout.fillWidth: true
        enabled: root.available && !root.busy
        text: root.busy ? "Saving…" : "Save settings"
        bordered: true
        focusable: true
        onClicked: root.applyRequested(root.endpoint,root.marketEnabled,root.marketSource)
    }
    Ui.PanelSeparator { Layout.fillWidth: true }
    Ui.Button {
        text: "Maintenance"
        selected: root.maintenanceOpen
        focusable: true
        onClicked: root.maintenanceOpen=!root.maintenanceOpen
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.maintenanceOpen
        spacing: root.spaces.sm
        Ui.Button {
            Layout.fillWidth:true
            text: root.confirmLegacy ? "Cancel old service cleanup" : "Previous version: stop old service"
            enabled: root.available && !root.busy
            focusable:true
            onClicked:root.confirmLegacy=!root.confirmLegacy
        }
        Text { Layout.fillWidth:true; visible:root.confirmLegacy; text:"Stop and disable the old omamonero user service? Your settings, Monero node and wallet remain in place."; wrapMode:Text.WordWrap; color:Commons.Color.foreground; font.family:root.typography.family; font.pixelSize:root.typography.bodySmall }
        Ui.Button { visible:root.confirmLegacy; text:"Confirm: stop old service"; enabled:!root.busy; focusable:true; onClicked:{root.confirmLegacy=false;root.legacyCleanupRequested()} }
        Ui.PanelSeparator { Layout.fillWidth: true }
        Ui.Button {
            Layout.fillWidth:true
            visible:!root.confirmingRemoval
            enabled:root.available && !root.busy
            text:"Remove OmaMonero"
            foreground:Commons.Color.urgent
            focusable:true
            onClicked:root.confirmingRemoval=true
        }
        Text { Layout.fillWidth:true; visible:root.confirmingRemoval; text:"Remove this widget? Settings are kept. Any owned payment-link handler is restored first."; wrapMode:Text.WordWrap; color:Commons.Color.foreground; font.family:root.typography.family; font.pixelSize:root.typography.bodySmall }
        RowLayout {
            visible:root.confirmingRemoval
            Ui.Button { text:"Cancel"; focusable:true; onClicked:root.confirmingRemoval=false }
            Ui.Button { text:"Remove"; enabled:!root.busy; foreground:Commons.Color.urgent; bordered:true; focusable:true; onClicked:{root.confirmingRemoval=false;root.removeRequested()} }
        }
    }
}
