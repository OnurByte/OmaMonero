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
    readonly property string marketLabel: Status.marketLabel(market)
    readonly property bool ready: StatusStore.ready && StatusStore.configLoaded && !StatusStore.configError
    readonly property var view: StatusStore.view
    readonly property var market: view.market
    readonly property bool marketReady: market.state === "ready"
    readonly property color trendColor: Status.trendColor(marketReady ? market.change_percent : NaN)
    readonly property bool opened: popup.opened
    readonly property bool popoutSwitchClosing: popup.popoutSwitchClosing
    readonly property real openPanelIndicatorWidth: barLabel.implicitWidth + Style.space(18)
    readonly property real openPanelIndicatorHeight: Style.space(10)

    function open() { popup.open() }
    function openAbout() { popup.openAbout() }
    function close() { popup.close() }
    function togglePanel() { popup.toggle() }
    function closeForPopoutSwitch() { popup.closeForPopoutSwitch() }
    function refresh() { StatusStore.refresh(true) }

    implicitWidth: button.implicitWidth + (vertical ? 0 : Style.space(20)) + (marketReady && !vertical ? Style.space(64) : 0)
    implicitHeight: button.implicitHeight

    Ui.WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.vertical ? "$XMR" : "$XMR " + root.marketLabel
        tooltipText: root.marketReady ? root.market.source + " · XMR/USD · 24h " + Status.changeLabel(root.market.change_percent) : root.market.state === "loading" ? "Loading XMR/USD prices" : root.market.state === "disabled" ? "Public prices are paused" : "Fresh XMR/USD prices are unavailable · open to retry"

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
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    mouse.accepted = true
                    root.openAbout()
                }
            }
        }
        Row {
            id: barLabel
            anchors.left: parent.left
            anchors.leftMargin: root.vertical ? 0 : Style.space(26)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)
            Text {
                text: "$XMR"
                textFormat: Text.PlainText
                font.family: button.fontFamily
                font.pixelSize: root.vertical ? button.fontSize * 0.75 : button.fontSize
                color: "#ffffff"
            }
            Text {
                visible: !root.vertical
                text: root.marketLabel
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
        active: root.opened
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
