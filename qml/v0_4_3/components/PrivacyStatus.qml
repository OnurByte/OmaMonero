import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

ColumnLayout {
    id: root
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    property var privacy: null
    spacing: root.spaces.sm
    Metric { Layout.fillWidth: true; label: "RPC transport policy"; value: root.privacy ? root.privacy.transport.toUpperCase() : "Unknown" }
    Text {
        Layout.fillWidth: true
        text: "Monerod P2P route is unverified. RPC reachability does not prove Tor or I2P privacy."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Commons.Color.foreground
        opacity: 0.65
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
}
