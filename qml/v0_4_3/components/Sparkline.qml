pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
    id: root
    property var points: []
    property color lineColor: Commons.Color.accent
    property bool area: false
    property bool detailed: false
    property real axisLow: 0
    property real axisHigh: 0
    property int hoverIndex: -1
    readonly property var typography: Style.font
    readonly property var hoverPoint: hoverIndex >= 0 && hoverIndex < points.length ? points[hoverIndex] : null
    readonly property real axisWidth: Math.min(Math.max(Style.space(58), typography.bodySmall * 4 + Style.space(8)), Math.max(0, width - Style.space(76)))
    readonly property real plotRight: detailed ? Math.max(4, width - axisWidth) : width - 2
    readonly property real plotTop: detailed ? Style.space(10) : 2
    readonly property real plotBottom: detailed ? Math.max(plotTop + 2, height - Style.space(24)) : height - 2
    readonly property var axisLabels: {
        if (!detailed || !isFinite(axisLow) || !isFinite(axisHigh)) return []
        var padding = Math.max((axisHigh - axisLow) * 0.08, axisHigh * 0.0001)
        var low = axisLow - padding
        var high = axisHigh + padding
        var labels = []
        for (var tick = 0; tick <= 4; tick++)
            labels.push("$" + Math.round(high - (high - low) * tick / 4))
        return labels
    }
    readonly property int axisTickCount: axisTicks.count
    readonly property bool axesFit: {
        if (detailed && axisTicks.count === 0) return false
        for (var i = 0; i < axisTicks.count; i++) {
            var label = axisTicks.itemAt(i)
            if (!label || label.width <= 0 || label.x < plotRight || label.x + label.width > width) return false
        }
        return !detailed || (plotRight >= Style.space(48) && plotRight <= width)
    }
    onPointsChanged: { hoverIndex = -1; plot.requestPaint() }
    onLineColorChanged: plot.requestPaint()
    onAreaChanged: plot.requestPaint()
    onDetailedChanged: plot.requestPaint()
    onHoverIndexChanged: plot.requestPaint()
    onWidthChanged: plot.requestPaint()
    onHeightChanged: plot.requestPaint()
    Canvas {
        id: plot
        width: root.plotRight
        height: root.height
        onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (!root.points || root.points.length < 2 || width < 4 || height < 4) return
        var minimum = root.points[0].price
        var maximum = minimum
        for (var i = 1; i < root.points.length; i++) {
            minimum = Math.min(minimum, root.points[i].price)
            maximum = Math.max(maximum, root.points[i].price)
        }
        var margin = Math.max((maximum - minimum) * 0.08, maximum * 0.0001)
        var low = minimum - margin, high = maximum + margin
        var start = root.points[0].timestamp
        var duration = root.points[root.points.length - 1].timestamp - start
        if (duration <= 0) return
        function xAt(point) { return 2 + (point.timestamp - start) / duration * (root.plotRight - 2) }
        function yAt(value) { return root.plotBottom - (value - low) / (high - low) * (root.plotBottom - root.plotTop) }
        if (root.detailed) {
            for (var tick = 0; tick <= 4; tick++) {
                var value = high - (high - low) * tick / 4
                var y = yAt(value)
                ctx.beginPath(); ctx.moveTo(2, y); ctx.lineTo(root.plotRight, y)
                ctx.strokeStyle = Qt.alpha(Commons.Color.foreground, 0.12); ctx.lineWidth = 1; ctx.stroke()
            }
            ctx.fillStyle = String(Commons.Color.foreground)
            ctx.font = root.typography.bodySmall + "px " + root.typography.family
            ctx.textBaseline = "bottom"
            for (var t = 0; t <= 2; t++) {
                var stamp = start + duration * t / 2
                ctx.textAlign = t === 0 ? "left" : t === 2 ? "right" : "center"
                ctx.fillText(Qt.formatTime(new Date(stamp * 1000), "HH:mm"), 2 + (root.plotRight - 2) * t / 2, root.height)
            }
        }
        ctx.beginPath()
        for (var j = 0; j < root.points.length; j++) {
            if (j === 0) ctx.moveTo(xAt(root.points[j]), yAt(root.points[j].price))
            else ctx.lineTo(xAt(root.points[j]), yAt(root.points[j].price))
        }
        ctx.strokeStyle = root.lineColor
        ctx.lineWidth = Math.max(1, Style.spaceReal(detailed ? 2 : 1.5))
        ctx.lineJoin = "round"
        ctx.stroke()
        if (root.area) {
            ctx.lineTo(root.plotRight, root.plotBottom)
            ctx.lineTo(2, root.plotBottom)
            ctx.closePath()
            var gradient = ctx.createLinearGradient(0, root.plotTop, 0, root.plotBottom)
            gradient.addColorStop(0, Qt.alpha(root.lineColor, 0.24))
            gradient.addColorStop(1, Qt.alpha(root.lineColor, 0.02))
            ctx.fillStyle = gradient
            ctx.fill()
        }
        if (root.detailed && root.hoverPoint) {
            var point = root.hoverPoint, cx = xAt(point), cy = yAt(point.price)
            ctx.beginPath(); ctx.moveTo(cx, root.plotTop); ctx.lineTo(cx, root.plotBottom)
            ctx.moveTo(2, cy); ctx.lineTo(root.plotRight, cy)
            ctx.strokeStyle = Qt.alpha(Commons.Color.foreground, 0.45); ctx.lineWidth = 1; ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, Style.space(3), 0, Math.PI * 2)
            ctx.fillStyle = root.lineColor; ctx.fill()
        }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.detailed
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: function(mouse) {
                if (!root.points || root.points.length < 2) return
                var start = root.points[0].timestamp
                var end = root.points[root.points.length - 1].timestamp
                var target = start + Math.max(0, Math.min(1, (mouse.x - 2) / (root.plotRight - 2))) * (end - start)
                var nearest = 0
                for (var i = 1; i < root.points.length; i++) {
                    if (Math.abs(root.points[i].timestamp - target) < Math.abs(root.points[nearest].timestamp - target)) nearest = i
                }
                root.hoverIndex = nearest
            }
            onExited: root.hoverIndex = -1
        }
    }
    Repeater {
        id: axisTicks
        model: root.axisLabels
        delegate: Text {
            required property int index
            required property string modelData
            x: root.plotRight + Style.space(5)
            y: root.plotTop + (root.plotBottom - root.plotTop) * index / 4 - height / 2
            width: Math.max(0, root.width - x)
            height: Style.space(15)
            text: modelData
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: Commons.Color.foreground
            opacity: 0.85
            font.family: root.typography.family
            font.pixelSize: root.typography.bodySmall
        }
    }
}
