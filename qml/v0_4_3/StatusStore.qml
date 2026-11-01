pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "generated/Core.js" as Generated

QtObject {
    id: root
    readonly property var core: Generated.api()
    property var config: core.defaults()
    property double now: Date.now() / 1000
    property var nodeData: ({state:"offline",error:"connection"})
    property var marketData: ({state:"loading"})
    property var modulesData: ({wallet:{state:"disabled"},xmrig:{state:"disabled"},p2pool:{state:"disabled"}})
    property int nodeTime: 0
    property int epoch: 0
    property bool polling: false
    property double lastMarket: 0
    property int chartIntervalSecs: 900
    property bool marketBusy: false
    property bool ready: false
    property bool configLoaded: false
    property bool configError: false
    property bool jsonSeen: false
    readonly property bool pendingSetup: false
    readonly property bool controlsAvailable: ready
    property var setup: ({state:"idle"})
    property var setupData: ({})
    property var paymentData: ({})
    property var incomingRequests: []
    property var tracker: core.incomingTracker()
    readonly property string home: Quickshell.env("HOME")
    readonly property string configDirectory: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/omamonero"
    readonly property string dataDirectory: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/omamonero"
    readonly property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR") + "/omamonero-native"
    readonly property string helper: core.nativePath(String(Qt.resolvedUrl("native.sh")))
    readonly property var view: ({state:nodeTime && now-nodeTime>Math.max(15,config.poll_interval_secs*3)?"stale":nodeData.state,
        message:nodeTime && now-nodeTime>Math.max(15,config.poll_interval_secs*3)?"Node data is stale":nodeData.state==="online"?"Node online":nodeData.state==="syncing"?"Node syncing":"Node offline · optional",
        node:nodeTime && now-nodeTime>Math.max(15,config.poll_interval_secs*3)?null:nodeData,
        privacy:{transport:config.transport,p2p_verified:false},market:Generated.api().marketView(marketData,now),modules:visibleModules()})
    function visibleModules() {
        const out=Object.assign({},modulesData)
        for(const name of ["wallet","xmrig"]){const m=out[name];if(m && m.state==="ready" && now-m.updated_at>Math.max(30,config.poll_interval_secs*3))out[name]={state:"stale"}}
        if(out.p2pool && out.p2pool.state==="ready" && now-out.p2pool.updated_at>120)out.p2pool=Object.assign({},out.p2pool,{state:"stale"})
        return out
    }
    function details(message) {
        setupData = Object.assign({},config,{installed:true,receive_address:setupData.receive_address || "",uri_handler:setupData.uri_handler || false,wallets:{feather:true,monero_gui:true},message:message || "",proof:setupData.proof || null})
    }
    function fail(message) { setup={state:"error",message:message} }
    function request(url, method, params, local, callback) {
        const generation = epoch
        try {
            http.send(core.request(config,url,method,params || {},local),function(raw) {
                if (generation !== epoch) return
                let value = null
                if (raw !== null) { try { value=core.httpBody(raw); if(method) value=core.rpcResult(value) } catch(e) {} }
                callback(value)
            })
        } catch(e) { callback(null) }
    }
    function setModule(name,value) { const next=Object.assign({},modulesData);next[name]=value;modulesData=next }
    function pollWallet() {
        const m=config.modules
        if(!m.wallet_rpc) {setModule("wallet",{state:"disabled"});polling=false;return}
        if(!m.watch_only_confirmed) {setModule("wallet",{state:"confirmation_required"});polling=false;return}
        const rpc=m.wallet_rpc+"/json_rpc"
        request(rpc,"get_balance",{account_index:0},true,function(b) {
            if(!b){setModule("wallet",{state:"unavailable"});polling=false;return}
            request(rpc,"get_address",{account_index:0},true,function(a) {
                let w
                try { w=core.wallet(b,a,Math.floor(root.now),config.network) } catch(e) {setModule("wallet",{state:"unavailable"});polling=false;return}
                request(rpc,"get_height",{},true,function(h) {
                    if(!h || !core.integer(h.height)) {w.incoming_error="Recent incoming payments unavailable";setModule("wallet",w);polling=false;return}
                    w.coverage_from_height=Math.max(0,h.height-720)
                    request(rpc,"get_transfers",{"in":true,pool:true,out:false,pending:false,failed:false,account_index:0,filter_by_height:true,min_height:w.coverage_from_height,max_height:h.height},true,function(t) {
                        try {w.incoming=core.transfers(t)}catch(e){w.incoming_error="Recent incoming payments unavailable"}
                        setModule("wallet",w)
                        if(tracker.observe(w) && config.modules.notify_payments) Quickshell.execDetached(["notify-send","-a","OmaMonero","Incoming Monero payment","A new incoming payment was observed by your local watch-only wallet."])
                        polling=false
                    })
                })
            })
        })
    }
    function selectChartInterval(seconds) {
        if(marketBusy || config.market_source.url || [300,900,1800,3600].indexOf(seconds)<0)return
        chartIntervalSecs=seconds
        refresh(true)
    }
    function refreshMarket() {
        if(config.market_enabled && !marketBusy && now-lastMarket>=120) {
            lastMarket=now;marketBusy=true
            if(marketData.state!=="ready")marketData={state:"loading"}
            const source=config.market_source
            const interval=chartIntervalSecs
            const url=source.url || "https://api.kraken.com/0/public/OHLC?pair=XMRUSD&interval="+Math.round(interval/60)
            request(url,undefined,{},false,function(v){marketBusy=false;try{marketData=source.url?core.customMarket(v,Math.floor(root.now),source):core.krakenMarket(v,Math.floor(root.now),interval)}catch(e){marketData={state:"unavailable"}}})
        }
    }
    function refresh(forceMarket) {
        if(forceMarket === true)lastMarket=0
        if(!ready || !configLoaded || configError) return
        refreshMarket()
        if(polling)return
        polling=true
        const started=Date.now()
        request(config.endpoint+"/json_rpc","get_info",{},false,function(v) {
            try {nodeData=core.node(v,config.network,Date.now()-started)} catch(e){nodeData={state:"offline",error:"invalid_response"}}
            nodeTime=Math.floor(root.now)
            pollWallet()
        })
        if(config.modules.xmrig_url) request(config.modules.xmrig_url+"/2/summary",undefined,{},true,function(v){try{setModule("xmrig",core.xmrig(v,Math.floor(root.now)))}catch(e){setModule("xmrig",{state:"unavailable"})}})
        else setModule("xmrig",{state:"disabled"})
        if(config.modules.p2pool_directory && !poolReader.running){poolReader.generation=epoch;poolReader.output="";poolReader.command=["/bin/bash",helper,"p2pool",config.modules.p2pool_directory];poolReader.running=true}
        else if(!config.modules.p2pool_directory)setModule("p2pool",{state:"disabled"})
    }
    function applyConfig(next) {
        const checked=core.validateConfig(next)
        const revalidateIncoming=!configLoaded || config.network!==checked.network
        epoch++;http.cancel();poolReader.running=false;config=checked;configError=false;polling=false;marketBusy=false;lastMarket=0;nodeTime=0;nodeData={state:"offline",error:"connection"};marketData={state:config.market_enabled?"unavailable":"disabled"};modulesData={wallet:{state:"disabled"},xmrig:{state:"disabled"},p2pool:{state:"disabled"}};tracker=core.incomingTracker();setupData=Object.assign({},setupData,{proof:null});paymentData=({});if(revalidateIncoming)incomingRequests=[]
    }
    function save(next) {
        applyConfig(next)
        configFile.setText(JSON.stringify(config));details("Saving settings…");refresh()
    }
    function command(action, endpoint, marketEnabled, payload) {
        if(!ready || setup.state==="running")return
        payload=payload || {}
        if(action==="receive" || action==="preview-uri" || action==="clear-payment")paymentData=({})
        if(action==="proof" || action==="clear-proof")setupData=Object.assign({},setupData,{proof:null})
        try {
            if(action==="clear-proof" || action==="clear-payment")return
            if(action==="market-enable"){save(Object.assign({},config,{market_enabled:true}));setup={state:"done"};return}
            if(action==="info")details()
            else if(action==="save")save(Object.assign({},config,{endpoint:endpoint,market_enabled:marketEnabled,market_source:payload.market_source || config.market_source,transport:payload.transport || config.transport,proxy:payload.proxy===undefined?config.proxy:payload.proxy,network:payload.network || config.network}))
            else if(action==="module-config")save(Object.assign({},config,{modules:payload}))
            else if(action==="receive" || action==="preview-uri") {
                paymentData=core.payment(payload,config.network)
                if(action==="receive"){setupData=Object.assign({},setupData,{receive_address:paymentData.address});receiveFile.setText(JSON.stringify({address:paymentData.address}))}
            }
            else if(action==="proof") {
                if(!config.modules.wallet_rpc || !config.modules.watch_only_confirmed)throw Error("Configure and confirm a local watch-only wallet first")
                const params=core.proofParams(payload,config.network);setup={state:"running"}
                request(config.modules.wallet_rpc+"/json_rpc","check_tx_proof",params,true,function(v){try{setupData=Object.assign({},setupData,{proof:core.proofResult(v)});setup={state:"done"}}catch(e){fail("Proof verification unavailable or invalid response")}})
                return
            }
            else if(action==="wallet") {if(["feather","monero_gui"].indexOf(payload.wallet)<0)return;Quickshell.execDetached(["/bin/bash",helper,"wallet",payload.wallet]);details("Wallet launch requested. If it is not installed, use Omarchy’s application manager.")}
            else if(action==="register-uri" || action==="remove") {osAction(action);return}
            else if(action==="diagnostics") {details("Refreshing read-only connections. No node is started.");refresh(true)}
            setup={state:"done"}
        } catch(e) {fail(e.message || "Action could not complete")}
    }
    function osAction(action,arg) {
        setup={state:"running"}
        if(action==="remove"){Quickshell.execDetached(["/bin/bash",helper,"remove"]);return}
        actionJob.action=action
        actionJob.command=["/bin/bash",helper,action].concat(arg?[arg]:[])
        actionJob.running=true
    }
    function invalidateConfig(message) {
        epoch++;http.cancel();poolReader.running=false;polling=false;marketBusy=false
        nodeData={state:"offline",error:"invalid_response"};marketData={state:"unavailable"}
        modulesData={wallet:{state:"unavailable"},xmrig:{state:"unavailable"},p2pool:{state:"unavailable"}}
        configError=true;configLoaded=true
        fail(message)
    }
    function loadConfig() {
        jsonSeen=true
        try {const next=core.validateConfig(JSON.parse(configFile.text()));if(JSON.stringify(next)!==JSON.stringify(config))applyConfig(next);configError=false;configLoaded=true;details(setupData.message);refresh();refreshInbox()}
        catch(e){invalidateConfig("Settings are invalid. Requests are paused; correct the settings before saving.")}
    }
    property Http http: Http {}
    property Process initJob: Process {
        command:["/bin/bash",root.helper,"init"]
        running:true
        stdout:StdioCollector {}
        stderr:StdioCollector {}
        onExited:function(code){if(code!==0){root.marketData={state:"unavailable"};root.fail("Private settings directory could not be prepared");return}root.ready=true;configFile.reload();configFile.text()}
    }
    property FileView configFile: FileView {
        path:root.configDirectory+"/config.json"
        printErrors:false;watchChanges:true;preload:false
        onLoaded:root.loadConfig()
        onFileChanged:reload()
        onLoadFailed:function(error) {
            if(!root.ready)return
            if(error===FileViewError.FileNotFound && !root.jsonSeen){root.configLoaded=true;root.details();root.refresh();root.refreshInbox()}
            else root.invalidateConfig("Saved settings could not be read. Requests are paused to protect your connection policy.")
        }
        onSaved:root.details("Settings saved.")
        onSaveFailed:root.fail("Settings could not be saved. Your previous file was retained.")
    }
    property FileView uriOwnership: FileView {
        path:root.dataDirectory+"/native/uri-owned";printErrors:false;preload:true;watchChanges:true
        onFileChanged:reload()
        onLoaded:root.setupData=Object.assign({},root.setupData,{uri_handler:true})
        onLoadFailed:root.setupData=Object.assign({},root.setupData,{uri_handler:false})
    }
    property FileView receiveFile: FileView {
        path:root.configDirectory+"/receive.json";printErrors:false;preload:true
        onLoaded:{try{root.setupData=Object.assign({},root.setupData,{receive_address:JSON.parse(text()).address || ""})}catch(e){}}
    }
    function refreshInbox() {
        inbox.reload()
        if(inbox.loaded)readInbox(inbox.text())
    }
    function readInbox(raw) {
            const rows=raw.split("\n").filter(function(s){return !!s}).slice(-20), requests=[]
            for(let i=0;i<rows.length;i++) {const tab=rows[i].indexOf("\t");if(tab<1)continue;try{const p=core.payment({uri:rows[i].slice(tab+1)},root.config.network);p.incoming_request=true;p.request_id=rows[i].slice(0,tab);requests.push({id:p.request_id,created_at:Number(p.request_id)/1e9,payment:p})}catch(e){}}
            const previous=root.incomingRequests.length?root.incomingRequests[root.incomingRequests.length-1].id:""
            root.incomingRequests=requests
            if(requests.length && requests[requests.length-1].id!==previous)root.paymentData=requests[requests.length-1].payment
    }
    property FileView inbox: FileView {
        path:root.runtimeDirectory+"/inbox";printErrors:false;preload:true;watchChanges:true
        onFileChanged:reload()
        onLoaded:root.readInbox(text())
    }

    property Process actionJob: Process {
        property string action:""
        stdout:StdioCollector {}
        stderr:StdioCollector {}
        onExited:function(code){if(code!==0)root.fail(action==="remove"?"Removal could not complete. URI handler files were retained if restoration failed.":action==="wallet"?"Wallet could not be opened. Install it with Omarchy’s application manager.":"Action could not complete; existing data was retained.");else {root.setup={state:"done"};if(action==="register-uri")root.setupData=Object.assign({},root.setupData,{uri_handler:true});else root.details("Action completed.")}}
    }
    property FileView jobResult: FileView {
        path:root.runtimeDirectory+"/native-job.json";printErrors:false;watchChanges:true
        onFileChanged:reload()
        onLoaded:{try{root.setup=JSON.parse(text())}catch(e){root.fail("Removal status is invalid")}}
    }
    property Process poolReader: Process {
        property string output:""
        property int generation:0
        stdout:StdioCollector {onStreamFinished:poolReader.output=text}
        stderr:StdioCollector {}
        onExited:function(code){if(generation!==root.epoch)return;try{if(code!==0)throw Error();const split=output.indexOf("\n");root.setModule("p2pool",core.p2pool(core.parseJson(output.slice(split+1)),Number(output.slice(0,split)),Math.floor(root.now)))}catch(e){root.setModule("p2pool",{state:"unavailable"})}}
    }
    property Timer clock: Timer {interval:1000;running:true;repeat:true;onTriggered:root.now=Date.now()/1000}
    property Timer poller: Timer {interval:root.config.poll_interval_secs*1000;running:root.ready;repeat:true;onTriggered:root.refresh()}
}
