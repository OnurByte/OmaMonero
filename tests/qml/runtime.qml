import QtQuick
import Quickshell
import "Plugin" as Oma
import "Plugin/components" as Components
QtObject {
    property bool started: Oma.StatusStore.ready
    property int ticks: 0
    property int stage: 0
    property Item widget: Oma.BarWidget {}
    property Item panelCheck: Oma.Panel {}
    property Item chart: Components.Sparkline {width:300;height:180;detailed:true;axisLow:575;axisHigh:636;points:[{timestamp:1,price:575},{timestamp:2,price:636}]}
    property Timer check: Timer {
        interval:100;running:true;repeat:true
        onTriggered: {
            ticks++
            const s=Oma.StatusStore
            if(stage===0 && s.view.state==="online" && s.modulesData.wallet.state==="ready" && s.modulesData.wallet.incoming.length===1 && s.modulesData.xmrig.state==="ready" && s.modulesData.p2pool.state==="ready") {
                if(s.modulesData.wallet.balance_atomic!=="18446744073709551615"){console.error("OMAMONERO_RUNTIME_FAIL: Atomic precision lost");Qt.quit();return}
                s.command("receive",undefined,undefined,{address:s.modulesData.wallet.address,amount:"1.250000000000",label:"Invoice #1"})
                if(!s.paymentData.qr_svg || s.paymentData.uri.indexOf("tx_amount=1.25")<0){console.error("OMAMONERO_RUNTIME_FAIL: Payment failed");Qt.quit();return}
                s.command("receive",undefined,undefined,{address:"invalid"})
                if(s.paymentData.uri){console.error("OMAMONERO_RUNTIME_FAIL: Invalid request retained successful QR");Qt.quit();return}
                s.command("receive",undefined,undefined,{address:s.modulesData.wallet.address})
                s.command("proof",undefined,undefined,{txid:"a".repeat(64),address:s.modulesData.wallet.address,message:"private message",signature:"proof"})
                stage=1
            }
            if(stage===1 && s.setupData.proof && s.setupData.proof.good) {
                s.command("proof",undefined,undefined,{txid:"bad",address:"invalid",message:"",signature:"proof"})
                if(s.setupData.proof){console.error("OMAMONERO_RUNTIME_FAIL: Invalid proof retained success");Qt.quit();return}
                if(chart.axisLabels.length!==5 || !chart.axesFit){console.error("OMAMONERO_RUNTIME_FAIL: Chart axes do not fit");Qt.quit();return}
                s.command("save",s.config.endpoint,false,{transport:"local",proxy:"",network:"mainnet",market_source:s.config.market_source})
                stage=2
            }
            if(stage===2 && s.setupData.message==="Settings saved." && s.incomingRequests.length===1) {
                s.command("wallet",undefined,undefined,{wallet:"feather"})
                if(s.setup.state==="running"){console.error("OMAMONERO_RUNTIME_FAIL: Wallet launch locks the UI until wallet exits");Qt.quit();return}
                console.log("OMAMONERO_RUNTIME_PASS: native widget and panel, TS bundle, direct RPC, u64 wallet, bounded history, XMRig, P2Pool, QR, proof, private config save, URI inbox")
                Qt.quit()
            }
            if(ticks>200){console.error("OMAMONERO_RUNTIME_FAIL",stage,s.view.state,JSON.stringify(s.modulesData),JSON.stringify(s.setup));Qt.quit()}
        }
    }
}
