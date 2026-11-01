pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
    property string appVersion: "0.4.2"
    property string priceSource: "Kraken"
    property string connection: "local"
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    spacing:root.spaces.md
    RowLayout {
        Layout.fillWidth:true
        spacing:root.spaces.md
        Image {Layout.preferredWidth:Style.space(60);Layout.preferredHeight:Style.space(60);source:Qt.resolvedUrl("../assets/OmaMonero-logo.svg");fillMode:Image.PreserveAspectFit;Accessible.name:"OmaMonero logo"}
        ColumnLayout {
            Layout.fillWidth:true
            spacing:root.spaces.xs
            Text {text:"OmaMonero";color:Commons.Color.foreground;font.family:root.typography.family;font.pixelSize:root.typography.heading;font.bold:true}
            Text {text:"Monero, in your Omarchy bar.";color:Commons.Color.foreground;opacity:0.85;font.family:root.typography.family;font.pixelSize:root.typography.body}
            Text {text:"Version "+root.appVersion+" · Native plugin";color:Commons.Color.foreground;opacity:0.8;font.family:root.typography.family;font.pixelSize:root.typography.bodySmall}
        }
    }
    Ui.PanelSeparator {Layout.fillWidth:true}
    Text {text:"Market & privacy";color:Commons.Color.foreground;font.family:root.typography.family;font.pixelSize:root.typography.body;font.bold:true}
    Text {
        Layout.fillWidth:true
        text:"XMR/USD prices, market candles and a 24h chart. Public prices are on by default and can be paused in Settings. The provider sees your IP unless you choose a proxy."
        textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Commons.Color.foreground;opacity:0.9;font.family:root.typography.family;font.pixelSize:root.typography.body
    }
    Metric {Layout.fillWidth:true;label:"Price source";value:root.priceSource}
    Metric {Layout.fillWidth:true;label:"Connection policy";value:root.connection==="tor"?"Tor · no direct fallback":root.connection==="i2p"?"I2P · no direct fallback":root.connection==="direct"?"HTTPS":"Local node · public prices"}
    Ui.PanelSeparator {Layout.fillWidth:true}
    Text {text:"Your keys stay yours";color:Commons.Color.foreground;font.family:root.typography.family;font.pixelSize:root.typography.body;font.bold:true}
    Text {Layout.fillWidth:true;text:"Create receive QR codes, preview payment links and verify proofs. OmaMonero never sends payments or asks for private keys. Wallet, mining and node connections are optional.";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Commons.Color.foreground;opacity:0.9;font.family:root.typography.family;font.pixelSize:root.typography.body}
    Metric {Layout.fillWidth:true;label:"Created by";value:"OnurByte"}
    Metric {Layout.fillWidth:true;label:"License";value:"MIT"}
    Text {Layout.fillWidth:true;text:"Marketplace verification is specific to a reviewed commit. Local checks and a release tag do not confer that status.";wrapMode:Text.WordWrap;color:Commons.Color.foreground;opacity:0.8;font.family:root.typography.family;font.pixelSize:root.typography.bodySmall}
    RowLayout {
        Layout.fillWidth:true
        Ui.Button {Layout.fillWidth:true;text:"GitHub";focusable:true;onClicked:Qt.openUrlExternally("https://github.com/OnurByte/OmaMonero")}
        Ui.Button {Layout.fillWidth:true;text:"Report an issue";focusable:true;onClicked:Qt.openUrlExternally("https://github.com/OnurByte/OmaMonero/issues/new")}
        Ui.Button {Layout.fillWidth:true;text:"X · @OnurStirner";focusable:true;onClicked:Qt.openUrlExternally("https://x.com/OnurStirner")}
    }
}
