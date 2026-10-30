import QtQuick
import "Status.js" as Status
import "components" as Components
import qs.Commons
import qs.Ui as Ui

Ui.BarWidget {
    id: root
    moduleName: "io.github.onurbyte.omamonero"
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    property var barWidgetRegistry: null
    readonly property var view: StatusStore.view
    readonly property var market: view.market
    readonly property bool marketReady: market.state === "ready"
    readonly property color trendColor: Status.trendColor(marketReady ? market.change_percent : NaN)
    readonly property bool opened: popup.opened
    readonly property bool popoutSwitchClosing: popup.popoutSwitchClosing
    readonly property real openPanelIndicatorWidth: barLabel.implicitWidth + Style.space(18)
    readonly property real openPanelIndicatorHeight: Style.space(10)

    function open() { popup.open() }
    function close() { popup.close() }
    function togglePanel() { popup.toggle() }
    function closeForPopoutSwitch() { popup.closeForPopoutSwitch() }
    function refresh() { StatusStore.refresh() }

    implicitWidth: button.implicitWidth + (vertical ? 0 : Style.space(20)) + (marketReady && !vertical ? Style.space(64) : 0)
    implicitHeight: button.implicitHeight

    Ui.WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.vertical ? "XMR" : root.marketReady ? "XMR $" + root.market.price.toFixed(2) + " " + Status.changeLabel(root.market.change_percent) : "XMR · " + (root.view.state === "online" ? "Online" : root.view.state === "syncing" ? "Syncing" : root.view.state === "offline" ? "Offline" : root.view.state === "missing" ? "Backend missing" : root.view.state === "stale" ? "Stale" : root.view.state === "stopped" ? "Stopped" : "Error")
        tooltipText: root.view.message + (root.marketReady ? " · " + root.market.source + " XMR/USD · 24h " + Status.changeLabel(root.market.change_percent) : "")
        labelVisible: false
        Image {
            visible: !root.vertical
            anchors.left: parent.left
            anchors.leftMargin: Style.space(5)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(16)
            height: width
            source: Qt.resolvedUrl("assets/OmaMonero-logo.svg")
            fillMode: Image.PreserveAspectFit
            smooth: false
        }
        Row {
            id: barLabel
            anchors.left: parent.left
            anchors.leftMargin: root.vertical ? 0 : Style.space(26)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)
            Text {
                text: "XMR"
                textFormat: Text.PlainText
                font.family: button.fontFamily
                font.pixelSize: root.vertical ? button.fontSize * 0.75 : button.fontSize
                color: "#ffffff"
            }
            Text {
                visible: !root.vertical
                text: root.marketReady ? "$" + root.market.price.toFixed(2) + " " + Status.changeLabel(root.market.change_percent) : root.view.message
                textFormat: Text.PlainText
                font.family: button.fontFamily
                font.pixelSize: button.fontSize
                color: root.marketReady ? root.trendColor : button.foreground
            }
        }
        Components.Sparkline {
            visible: root.marketReady && !root.vertical
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(52)
            height: Math.max(Style.space(12), button.height * 0.5)
            points: root.marketReady ? root.market.points : []
            lineColor: root.trendColor
        }
        active: !root.marketReady && ["online", "syncing"].indexOf(root.view.state) < 0
        onPressed: function(button) {
            if (button === Qt.LeftButton) root.togglePanel()
            else if (button === Qt.RightButton) root.refresh()
        }
    }
    Panel {
        id: popup
        bar: root.bar
        anchorItem: button
        hostWidget: root
        settings: root.settings
    }
}
