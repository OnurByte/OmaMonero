pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
    readonly property var typography: Style.font
    readonly property var spaces: Style.spacing

    spacing: root.spaces.md

    Image {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Style.space(112)
        Layout.preferredHeight: Style.space(112)
        source: Qt.resolvedUrl("../assets/OmaMonero-logo.svg")
        fillMode: Image.PreserveAspectFit
        smooth: false
        Accessible.name: "OmaMonero logo"
    }

    Text {
        Layout.fillWidth: true
        text: "OmaMonero"
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        color: Commons.Color.foreground
        font.family: root.typography.family
        font.pixelSize: root.typography.heading
    }

    Text {
        Layout.fillWidth: true
        text: "A native Monero companion for Omarchy."
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        color: Commons.Color.foreground
        opacity: 0.7
        font.family: root.typography.family
        font.pixelSize: root.typography.bodySmall
    }

    Ui.PanelSeparator { Layout.fillWidth: true }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Made by"
            textFormat: Text.PlainText
            color: Commons.Color.foreground
            opacity: 0.7
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
        Text {
            text: "OnurByte"
            textFormat: Text.PlainText
            color: Commons.Color.foreground
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "License"
            textFormat: Text.PlainText
            color: Commons.Color.foreground
            opacity: 0.7
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
        Text {
            text: "MIT"
            textFormat: Text.PlainText
            color: Commons.Color.foreground
            font.family: root.typography.family
            font.pixelSize: root.typography.body
        }
    }

    Ui.Button {
        Layout.fillWidth: true
        text: "GitHub · OmaMonero repository"
        tooltipText: "github.com/OnurByte/OmaMonero"
        foreground: Commons.Color.accent
        focusable: true
        onClicked: Qt.openUrlExternally("https://github.com/OnurByte/OmaMonero")
    }

    Ui.Button {
        Layout.fillWidth: true
        text: "X · @OnurStirner"
        tooltipText: "x.com/OnurStirner"
        foreground: Commons.Color.accent
        focusable: true
        onClicked: Qt.openUrlExternally("https://x.com/OnurStirner")
    }
}
