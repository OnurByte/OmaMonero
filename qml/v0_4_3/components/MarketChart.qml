pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "../generated/Core.js" as Generated

ColumnLayout {
    id: root
    property var market: ({state:"loading"})
    property bool busy: false
    property bool customSource: false
    property int selectedInterval: 900
    property bool expanded: false
    property string chartMode: "candles"
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    readonly property bool ready: market.state === "ready"
    readonly property bool hasCandles: ready && Array.isArray(market.candles) && market.candles.length>1
    readonly property color trendColor: Generated.api().trendColor(ready?market.change_percent:NaN)
    readonly property var detailPoint: chart.hoverPoint || chart.latestPoint
    signal intervalRequested(int seconds)
    signal expandRequested()
    spacing: root.spaces.sm
    Text { text:"XMR / USD";color:Commons.Color.foreground;opacity:0.8;font.family:root.typography.family;font.pixelSize:root.typography.body }
    RowLayout {
        Layout.fillWidth:true
        Text {
            Layout.fillWidth:true
            text:root.ready?"$"+root.market.price.toFixed(2):root.market.state==="disabled"?"Prices paused":root.market.state==="loading"?"Loading XMR/USD…":"Price unavailable"
            color:Commons.Color.foreground
            font.family:root.typography.family
            font.pixelSize:root.typography.heading*1.65
            font.bold:true
        }
        ColumnLayout {
            visible:root.ready
            spacing:0
            Text { text:root.ready?Generated.api().changeLabel(root.market.change_percent):"";color:root.trendColor;font.family:root.typography.family;font.pixelSize:root.typography.heading }
            Text { Layout.alignment:Qt.AlignRight;text:"24h change";color:Commons.Color.foreground;opacity:0.8;font.family:root.typography.family;font.pixelSize:Math.max(root.typography.bodySmall,Style.space(11)) }
        }
    }
    RowLayout {
        Layout.fillWidth:true
        visible:root.ready
        Repeater {
            model:root.customSource?[]:[{seconds:300,label:"5m"},{seconds:900,label:"15m"},{seconds:3600,label:"1h"}]
            Ui.Button { required property var modelData;text:modelData.label;selected:root.selectedInterval===modelData.seconds;enabled:!root.busy;focusable:true;onClicked:root.intervalRequested(modelData.seconds) }
        }
        Item {Layout.fillWidth:true}
        Ui.Button {text:"Candles";selected:root.chartMode==="candles" && root.hasCandles;enabled:root.hasCandles;focusable:true;onClicked:root.chartMode="candles"}
        Ui.Button {text:"Line";selected:root.chartMode==="line" || !root.hasCandles;focusable:true;onClicked:root.chartMode="line"}
        Ui.Button {text:root.expanded?"Compact":"Expand";focusable:true;onClicked:root.expandRequested()}
    }
    Text {
        Layout.fillWidth:true
        visible:root.ready
        text:root.detailPoint ? root.hasCandles ? "O "+root.detailPoint.open.toFixed(2)+"   H "+root.detailPoint.high.toFixed(2)+"   L "+root.detailPoint.low.toFixed(2)+"   C "+root.detailPoint.close.toFixed(2) : "Price · $"+root.detailPoint.price.toFixed(2) : ""
        textFormat:Text.PlainText
        color:Commons.Color.foreground
        opacity:0.95
        elide:Text.ElideRight
        font.family:root.typography.family
        font.pixelSize:Math.max(root.typography.bodySmall,Style.space(11))
    }
    TradingChart {
        id:chart
        Layout.fillWidth:true
        Layout.preferredHeight:root.ready?Style.space(root.expanded?350:270):0
        visible:root.ready
        candles:root.hasCandles?root.market.candles:[]
        points:root.ready?root.market.points:[]
        candleMode:root.chartMode==="candles" && root.hasCandles
        currentPrice:root.ready?root.market.price:0
        intervalSecs:root.ready?root.market.sample_interval_secs:root.selectedInterval
        lineColor:root.trendColor
    }
    RowLayout {
        Layout.fillWidth:true
        visible:root.ready
        Text {
            Layout.fillWidth:true
            text:root.detailPoint?Qt.formatDateTime(new Date(root.detailPoint.timestamp*1000),"dd MMM HH:mm")+(root.hasCandles?" · "+root.detailPoint.volume.toFixed(2)+" XMR volume":"")+(root.hasCandles && root.detailPoint.complete===false?" · Current candle":""):""
            textFormat:Text.PlainText
            color:Commons.Color.foreground
            opacity:0.9
            elide:Text.ElideRight
            font.family:root.typography.family
            font.pixelSize:Math.max(root.typography.bodySmall,Style.space(11))
        }
        Ui.Button {text:"Reset";focusable:true;onClicked:chart.resetView()}
    }
    Text {
        Layout.fillWidth:true
        visible:root.ready
        text:"Scroll to zoom · Drag to pan · Double-click to reset"
        color:Commons.Color.foreground
        opacity:0.8
        font.family:root.typography.family
        font.pixelSize:Math.max(root.typography.bodySmall,Style.space(11))
        wrapMode:Text.WordWrap
    }
    Text {
        Layout.fillWidth:true
        text:root.ready?root.market.source+" · Updated "+Qt.formatTime(new Date(root.market.fetched_at*1000),"HH:mm")+(root.busy?" · Updating…":"")
            :root.market.state==="disabled"?"Resume public XMR/USD prices whenever you want."
            :root.market.state==="loading"?"Fetching the latest price and 24h chart."
            :"A fresh price is not available yet. You can try again below."
        textFormat:Text.PlainText
        color:Commons.Color.foreground
        opacity:0.85
        font.family:root.typography.family
        font.pixelSize:Math.max(root.typography.bodySmall,Style.space(11))
        wrapMode:Text.WordWrap
    }
}
