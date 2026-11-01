pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../generated/Core.js" as Generated

Item {
    id: root
    property var candles: []
    property var points: []
    property bool candleMode: true
    property int intervalSecs: 900
    property real currentPrice: 0
    property color lineColor: "#22c55e"
    property int barsVisible: 97
    property int endOffset: 0
    property int hoverIndex: -1
    property real hoverY: 0
    property int previousLength: 0
    readonly property var typography: Style.font
    readonly property color labelColor: Commons.Color.foreground
    readonly property real labelSize: Math.max(typography.bodySmall,Style.space(11))
    readonly property var series: candles.length ? candles : points
    readonly property var windowData: Generated.api().chartWindow(series,barsVisible,endOffset)
    readonly property var rows: windowData.rows
    readonly property var hoverPoint: hoverIndex >= 0 && hoverIndex < rows.length ? rows[hoverIndex] : null
    readonly property var latestPoint: rows.length ? rows[rows.length-1] : null
    readonly property bool hoverInPrice: !!hoverPoint && hoverY >= plotTop && hoverY <= priceBottom
    readonly property bool atLatest: windowData.offset === 0
    readonly property bool hasVolume: candles.length > 0
    readonly property real plotLeft: Style.space(8)
    readonly property real axisWidth: Math.max(Style.space(76),typography.bodySmall*7)
    readonly property real plotRight: Math.max(plotLeft+Style.space(48),width-axisWidth)
    readonly property real plotWidth: plotRight-plotLeft
    readonly property real plotTop: Style.space(12)
    readonly property real timeHeight: Style.space(26)
    readonly property real volumeHeight: hasVolume ? Style.space(45) : 0
    readonly property real priceBottom: Math.max(plotTop+8,height-timeHeight-volumeHeight-Style.space(8))
    readonly property real volumeBottom: height-timeHeight
    readonly property real step: plotWidth/Math.max(1,rows.length)
    readonly property int timeTickCount: plotWidth < Style.space(360) ? 3 : 5
    readonly property var axisLabels: {
        const labels=[]
        for(let i=0;i<5;i++)labels.push(formatPrice(windowData.high-(windowData.high-windowData.low)*i/4))
        return labels
    }
    readonly property bool axesFit: width>=Style.space(180) && plotRight+axisWidth<=width+1
    function formatPrice(value) {
        if(value>=1000000)return "$"+(value/1000000).toFixed(2)+"m"
        if(value>=10000)return "$"+(value/1000).toFixed(1)+"k"
        return "$"+value.toFixed(value<1?4:2)
    }
    function closeOf(row) { return row.close === undefined ? row.price : row.close }
    function xAt(index) {
        if(rows.length<2)return plotLeft+plotWidth/2
        const duration=rows[rows.length-1].timestamp-rows[0].timestamp
        return plotLeft+step/2+(rows[index].timestamp-rows[0].timestamp)/Math.max(1,duration)*(plotWidth-step)
    }
    function yAt(value) { return priceBottom-(value-windowData.low)/(windowData.high-windowData.low)*(priceBottom-plotTop) }
    function setWindow(count,offset) {
        const w=Generated.api().chartWindow(series,count,offset)
        barsVisible=w.count || Math.round(86400/intervalSecs)+1
        endOffset=w.offset
        hoverIndex=-1
    }
    function zoom(factor,anchor) {
        const next=Generated.api().chartZoom(series.length,windowData.count,windowData.offset,factor,anchor)
        setWindow(next.count,next.offset)
    }
    function pan(bars) { setWindow(windowData.count,windowData.offset+bars) }
    function resetView() { barsVisible=Math.round(86400/intervalSecs)+1;endOffset=0;hoverIndex=-1 }
    function timeLabel(fraction) {
        if(rows.length<2)return ""
        const span=rows[rows.length-1].timestamp-rows[0].timestamp
        const stamp=rows[0].timestamp+span*fraction
        return Qt.formatDateTime(new Date(stamp*1000),span>172800?"dd MMM":"HH:mm")
    }
    onSeriesChanged: { if(previousLength===0 && series.length)resetView();previousLength=series.length;hoverIndex=-1;plot.requestPaint() }
    onIntervalSecsChanged: resetView()
    onWindowDataChanged: plot.requestPaint()
    onCandleModeChanged: plot.requestPaint()
    onLineColorChanged: plot.requestPaint()
    onLabelColorChanged: plot.requestPaint()
    onHoverIndexChanged: plot.requestPaint()
    onHoverYChanged: plot.requestPaint()
    onWidthChanged: plot.requestPaint()
    onHeightChanged: plot.requestPaint()
    activeFocusOnTab: true
    Accessible.role: Accessible.Graphic
    Accessible.name: "XMR/USD price chart"
    Accessible.description: "Scroll or plus and minus to zoom. Drag or arrow keys to pan. Home resets the view."
    Keys.onPressed: function(event) {
        if(event.key===Qt.Key_Plus || event.key===Qt.Key_Equal)zoom(.8,.5)
        else if(event.key===Qt.Key_Minus)zoom(1.25,.5)
        else if(event.key===Qt.Key_Left)pan(Math.max(1,Math.round(windowData.count*.1)))
        else if(event.key===Qt.Key_Right)pan(-Math.max(1,Math.round(windowData.count*.1)))
        else if(event.key===Qt.Key_Home)resetView()
        else {event.accepted=false;return}
        event.accepted=true
    }
    Component.onCompleted: resetView()
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Commons.Color.foreground,0.025)
        radius: Style.cornerRadius
        border.width: 1
        border.color: root.activeFocus ? Commons.Color.accent : Qt.alpha(Commons.Color.foreground,0.12)
    }
    Canvas {
        id: plot
        anchors.fill: parent
        onPaint: {
            const ctx=getContext("2d")
            ctx.reset()
            if(root.rows.length<2 || root.plotWidth<=0)return
            for(let i=0;i<5;i++) {
                const y=root.plotTop+(root.priceBottom-root.plotTop)*i/4
                ctx.beginPath();ctx.moveTo(root.plotLeft,y);ctx.lineTo(root.plotRight,y)
                ctx.strokeStyle=String(Qt.alpha(root.labelColor,0.12));ctx.lineWidth=1;ctx.stroke()
            }
            for(let t=0;t<root.timeTickCount;t++) {
                const x=root.plotLeft+root.plotWidth*t/(root.timeTickCount-1)
                ctx.beginPath();ctx.moveTo(x,root.plotTop);ctx.lineTo(x,root.volumeBottom)
                ctx.strokeStyle=String(Qt.alpha(root.labelColor,0.07));ctx.lineWidth=1;ctx.stroke()
            }
            ctx.save();ctx.beginPath();ctx.rect(root.plotLeft,root.plotTop,root.plotWidth,root.priceBottom-root.plotTop);ctx.clip()
            if(root.candleMode && root.candles.length) {
                const bodyWidth=Math.max(1,Math.min(Style.space(12),root.step*.68))
                for(let j=0;j<root.rows.length;j++) {
                    const c=root.rows[j],x=root.xAt(j),color=c.close<c.open?"#ef4444":"#22c55e"
                    ctx.strokeStyle=color;ctx.lineWidth=Math.max(1,Style.spaceReal(1))
                    ctx.beginPath();ctx.moveTo(x,root.yAt(c.high));ctx.lineTo(x,root.yAt(c.low));ctx.stroke()
                    ctx.fillStyle=color
                    ctx.fillRect(x-bodyWidth/2,Math.min(root.yAt(c.open),root.yAt(c.close)),bodyWidth,Math.max(1,Math.abs(root.yAt(c.open)-root.yAt(c.close))))
                }
            } else {
                ctx.beginPath()
                for(let j=0;j<root.rows.length;j++){const x=root.xAt(j),y=root.yAt(root.closeOf(root.rows[j]));if(j===0)ctx.moveTo(x,y);else ctx.lineTo(x,y)}
                ctx.strokeStyle=String(root.lineColor);ctx.lineWidth=Style.spaceReal(2);ctx.lineJoin="round";ctx.stroke()
                ctx.lineTo(root.xAt(root.rows.length-1),root.priceBottom);ctx.lineTo(root.xAt(0),root.priceBottom);ctx.closePath()
                const gradient=ctx.createLinearGradient(0,root.plotTop,0,root.priceBottom)
                gradient.addColorStop(0,String(Qt.alpha(root.lineColor,0.18)));gradient.addColorStop(1,String(Qt.alpha(root.lineColor,0.015)));ctx.fillStyle=gradient;ctx.fill()
            }
            if(root.atLatest && root.currentPrice>0){const y=root.yAt(root.currentPrice);ctx.beginPath();ctx.moveTo(root.plotLeft,y);ctx.lineTo(root.plotRight,y);ctx.strokeStyle=String(Qt.alpha(root.lineColor,.45));ctx.lineWidth=1;ctx.stroke()}
            ctx.restore()
            if(root.hasVolume && root.windowData.maxVolume>0) {
                for(let j=0;j<root.rows.length;j++) {
                    const c=root.rows[j],h=c.volume/root.windowData.maxVolume*Math.max(1,root.volumeHeight-Style.space(10))
                    ctx.fillStyle=String(Qt.alpha(c.close<c.open?"#ef4444":"#22c55e",.4))
                    ctx.fillRect(root.xAt(j)-root.step*.34,root.volumeBottom-h,Math.max(1,root.step*.68),h)
                }
            }
            if(root.hoverPoint) {
                const x=root.xAt(root.hoverIndex),y=Math.max(root.plotTop,Math.min(root.priceBottom,root.hoverY))
                ctx.beginPath();ctx.moveTo(x,root.plotTop);ctx.lineTo(x,root.volumeBottom);if(root.hoverInPrice){ctx.moveTo(root.plotLeft,y);ctx.lineTo(root.plotRight,y)}
                ctx.strokeStyle=String(Qt.alpha(root.labelColor,.55));ctx.lineWidth=1;ctx.stroke()
            }
        }
    }
    Repeater {
        model: root.axisLabels
        Text {
            required property int index
            required property string modelData
            x: root.plotRight+Style.space(6)
            y: root.plotTop+(root.priceBottom-root.plotTop)*index/4-height/2
            width: root.axisWidth-Style.space(8)
            text: modelData
            textFormat: Text.PlainText
            color: root.labelColor
            opacity: 0.95
            elide: Text.ElideRight
            font.family: root.typography.family
            font.pixelSize: root.labelSize
        }
    }
    Repeater {
        model: root.timeTickCount
        Text {
            required property int index
            readonly property real fraction: index/(root.timeTickCount-1)
            x: Math.max(root.plotLeft,Math.min(root.plotRight-width,root.plotLeft+root.plotWidth*fraction-width/2))
            y: root.height-root.timeHeight+Style.space(5)
            text: root.timeLabel(fraction)
            textFormat: Text.PlainText
            color: root.labelColor
            opacity: 0.9
            font.family: root.typography.family
            font.pixelSize: root.labelSize
        }
    }
    Text {
        visible: root.hasVolume
        x: root.plotLeft+Style.space(4)
        y: root.priceBottom+Style.space(5)
        text: "Volume · XMR"
        color: root.labelColor
        opacity: 0.8
        font.family: root.typography.family
        font.pixelSize: root.labelSize
    }
    Rectangle {
        visible: root.atLatest && root.currentPrice>0 && !root.hoverPoint
        x: root.plotRight+Style.space(2)
        y: Math.max(0,Math.min(root.priceBottom-height/2,root.yAt(root.currentPrice)-height/2))
        width: root.axisWidth-Style.space(3)
        height: currentText.implicitHeight+Style.space(6)
        color: root.lineColor
        radius: Style.space(2)
        Text { id:currentText;anchors.centerIn:parent;text:root.formatPrice(root.currentPrice);color:"#101318";font.family:root.typography.family;font.pixelSize:root.labelSize;font.bold:true }
    }
    Rectangle {
        visible: root.hoverInPrice
        x: root.plotRight+Style.space(2)
        y: Math.max(0,Math.min(root.priceBottom-height/2,root.hoverY-height/2))
        width: root.axisWidth-Style.space(3)
        height: crossText.implicitHeight+Style.space(6)
        color: root.labelColor
        radius: Style.space(2)
        Text {
            id:crossText
            anchors.centerIn:parent
            text: root.formatPrice(root.windowData.high-(Math.max(root.plotTop,Math.min(root.priceBottom,root.hoverY))-root.plotTop)/(root.priceBottom-root.plotTop)*(root.windowData.high-root.windowData.low))
            color: Commons.Color.background
            font.family:root.typography.family
            font.pixelSize:root.labelSize
        }
    }
    MouseArea {
        anchors.left: parent.left
        width: root.plotRight
        height: root.volumeBottom
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.CrossCursor
        property real dragStartX: 0
        property int dragOffset: 0
        onPressed: function(mouse){root.forceActiveFocus();dragStartX=mouse.x;dragOffset=root.windowData.offset}
        onPositionChanged: function(mouse){
            if(root.rows.length<2)return
            if(pressed)root.setWindow(root.windowData.count,dragOffset+Math.round((mouse.x-dragStartX)/Math.max(1,root.step)))
            let nearest=0
            for(let i=1;i<root.rows.length;i++)if(Math.abs(root.xAt(i)-mouse.x)<Math.abs(root.xAt(nearest)-mouse.x))nearest=i
            root.hoverIndex=nearest;root.hoverY=mouse.y
        }
        onWheel: function(wheel){root.zoom(wheel.angleDelta.y > 0 ? 0.8 : 1.25,Math.max(0,Math.min(1,(wheel.x-root.plotLeft)/root.plotWidth)));wheel.accepted=true}
        onDoubleClicked: root.resetView()
        onExited: root.hoverIndex=-1
    }
}
