pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Ui as Ui

RowLayout {
    id: root
    property string page: "overview"
    property int cursorIndex: -1
    readonly property var tabs: [{label:"Price",page:"overview"},{label:"Receive",page:"receive"},{label:"More",page:"tools"}]
    readonly property string section: page === "overview" || page === "receive" ? page : "tools"
    signal pageRequested(string destination)
    Repeater {
        model: root.tabs
        Ui.Button {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            text: modelData.label
            selected: root.section === modelData.page
            hasCursor: root.cursorIndex === index
            focusable: true
            onClicked: root.pageRequested(modelData.page)
        }
    }
}
