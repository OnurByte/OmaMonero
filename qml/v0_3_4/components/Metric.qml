import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

RowLayout {
    id: root
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing
    property string label: ""
    property string value: ""
    spacing: root.spaces.md
    Text {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        text: root.label
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        opacity: 0.65
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
    Text {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        horizontalAlignment: Text.AlignRight
        text: root.value
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.body
    }
}
