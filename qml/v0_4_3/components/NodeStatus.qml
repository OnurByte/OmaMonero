import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../generated/Core.js" as Generated

ColumnLayout {
    id: root
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    property var node: null
    spacing: root.spaces.sm
    Metric { Layout.fillWidth: true; label: "Network"; value: root.node ? root.node.network : "—" }
    Metric { Layout.fillWidth: true; label: "Height / target"; value: root.node ? root.node.height + " / " + (root.node.target_height || "—") : "—" }
    Metric { Layout.fillWidth: true; label: "Peers · in / out"; value: root.node ? root.node.incoming_peers + " / " + root.node.outgoing_peers : "—" }
    Metric { Layout.fillWidth: true; label: "RPC latency"; value: root.node ? root.node.latency_ms + " ms" : "—" }
    Metric { Layout.fillWidth: true; label: "Daemon version"; value: root.node && root.node.version ? root.node.version : "Unavailable" }
    Metric { Layout.fillWidth: true; label: "Database size"; value: root.node ? Generated.api().bytes(root.node.database_bytes) : "—" }
    Metric { Layout.fillWidth: true; label: "Node disk free"; value: root.node ? Generated.api().bytes(root.node.free_bytes) : "—" }
    Text {
        Layout.fillWidth: true
        visible: !!root.node && root.node.untrusted === true
        text: "Bootstrap / untrusted RPC data"
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Commons.Color.urgent
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
}
