import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

ColumnLayout {
    id: root
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    property var percent: null
    spacing: root.spaces.sm
    Metric { Layout.fillWidth: true; label: "Synchronization"; value: root.percent === null ? "Target unknown" : root.percent.toFixed(2) + "%" }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.space(4)
        radius: height / 2
        color: Qt.alpha(Commons.Color.foreground, 0.12)
        Rectangle {
            height: parent.height
            width: parent.width * (root.percent === null ? 0 : root.percent / 100)
            radius: parent.radius
            color: Commons.Color.accent
        }
    }
}
