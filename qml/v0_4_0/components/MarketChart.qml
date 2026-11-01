pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import qs.Commons as Commons
import "../Status.js" as Status

ColumnLayout {
    id: root
    property var market: ({state: "disabled"})
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    readonly property bool ready: market.state === "ready"
    readonly property color trendColor: Status.trendColor(ready ? market.change_percent : NaN)
    property int rangeHours: 24
    readonly property var rangePoints: visiblePoints(ready ? market.points : [], rangeHours)
    readonly property var extrema: priceBounds(rangePoints)
    function visiblePoints(points, hours) {
        if (!points || points.length < 2) return []
        var cutoff = points[points.length - 1].timestamp - hours * 3600
        var result = []
        for (var i = 0; i < points.length; i++) {
            if (points[i].timestamp < cutoff) continue
            if (result.length === 0 && i > 0 && points[i].timestamp > cutoff) {
                var previous = points[i - 1]
                var ratio = (cutoff - previous.timestamp) / (points[i].timestamp - previous.timestamp)
                result.push({timestamp: cutoff, price: previous.price + (points[i].price - previous.price) * ratio})
            }
            result.push(points[i])
        }
        return result
    }
    function priceBounds(points) {
        var low = Infinity, high = -Infinity
        for (var i = 0; i < points.length; i++) { low = Math.min(low, points[i].price); high = Math.max(high, points[i].price) }
        return {low: low, high: high}
    }
    spacing: root.spaces.md
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "XMR / USD"
            textFormat: Text.PlainText
            color: Commons.Color.foreground
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
        Text {
            text: root.ready ? Status.changeLabel(root.market.change_percent) + " · 24h" : ""
            textFormat: Text.PlainText
            color: root.trendColor
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
    }
    Text {
        text: root.ready ? "$" + root.market.price.toFixed(2) : root.market.state === "disabled" ? "Price display is off" : root.market.state === "stale" ? "Price data is stale" : "Price data unavailable"
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.heading
    }
    RowLayout {
        visible: root.ready
        Layout.fillWidth: true
        Repeater {
            model: [6, 12, 24]
            Ui.Button {
                required property int modelData
                text: modelData + "h"
                selected: root.rangeHours === modelData
                focusable: true
                onClicked: root.rangeHours = modelData
            }
        }
        Item { Layout.fillWidth: true }
    }
    Text {
        Layout.fillWidth: true
        visible: root.ready
        text: root.rangePoints.length > 1 ? root.rangeHours + "h low $" + root.extrema.low.toFixed(2) + "  ·  high $" + root.extrema.high.toFixed(2) : ""
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        opacity: 0.65
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
    Sparkline {
        id: chart
        Layout.fillWidth: true
        Layout.preferredHeight: root.ready ? Style.space(180) : 0
        visible: root.ready
        points: root.rangePoints
        lineColor: root.trendColor
        area: true
        detailed: true
        axisLow: root.extrema.low
        axisHigh: root.extrema.high
    }
    Text {
        Layout.fillWidth: true
        visible: root.ready
        text: chart.hoverPoint ? Qt.formatDateTime(new Date(chart.hoverPoint.timestamp * 1000), "ddd dd MMM HH:mm") + "  ·  $" + chart.hoverPoint.price.toFixed(2) : "Move over the chart to inspect a sample"
        textFormat: Text.PlainText
        color: chart.hoverPoint ? root.trendColor : Commons.Color.foreground
        opacity: chart.hoverPoint ? 1 : 0.5
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
    Text {
        Layout.fillWidth: true
        text: root.ready ? root.market.source + " · " + (root.market.sample_interval_secs < 3600 ? Math.round(root.market.sample_interval_secs / 60) + "-minute" : "hourly") + " samples · updated " + Qt.formatTime(new Date(root.market.fetched_at * 1000), "HH:mm") + "\n24h range boundaries are interpolated; times are local."
            : root.market.state === "disabled" ? "Enable public prices in OmaMonero settings. Node monitoring stays local."
            : "The provider cannot supply fresh prices. No old price is shown as current."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Commons.Color.foreground
        opacity: 0.6
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }
}
