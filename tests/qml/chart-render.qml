import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "Plugin/components" as Components
import "Plugin/generated/Core.js" as Generated

// Only run with the offscreen platform. Never creates a desktop surface.
QtObject {
    id: root
    readonly property var quote: {
        const now=200000,rows=[]
        for(let i=0;i<180;i++){
            const open=600+Math.sin(i*.24)*7+i*.035,close=open+Math.cos(i*.5)*2
            rows.push([now-300-(179-i)*900,String(open),String(Math.max(open,close)+1.2),String(Math.min(open,close)-1),String(close),String(open),String(30+Math.abs(Math.sin(i))*70),15])
        }
        return Generated.api().krakenMarket({error:[],result:{XXMRZUSD:rows}},now,900)
    }
    property Window window: Window {
        id:window
        width:600;height:720;visible:true;color:Commons.Color.background
        Item {
            id:card
            x:24;y:24;width:window.width-48;height:content.implicitHeight
            Rectangle {anchors.fill:parent;color:Commons.Color.background}
            ColumnLayout {
                id:content
                width:parent.width
                Components.MarketChart {Layout.fillWidth:true;market:root.quote;selectedInterval:900}
            }
        }
    }
    property Timer capture: Timer {
        interval:1800;running:true
        onTriggered:card.grabToImage(function(result){if(!result.saveToFile(Quickshell.env("OMAMONERO_QA_OUTPUT")))console.error("CHART_RENDER_FAIL");else console.log("CHART_RENDER_PASS");Qt.quit()})
    }
}
