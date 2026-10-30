const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
test('diagnostics navigation label stays compact with a full tooltip',()=>{
 const panel=fs.readFileSync(path.join('qml',`v${JSON.parse(fs.readFileSync('manifest.json','utf8')).version.replaceAll('.','_')}`,'Panel.qml'),'utf8');
 assert.match(panel,/text: "Diag"/);
 assert.match(panel,/tooltipText: "Diagnostics"/);
});
const qml=path.dirname(JSON.parse(fs.readFileSync('manifest.json','utf8')).entryPoints.barWidget);
const context=vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(qml,'Status.js'),'utf8').replace(/^\.pragma library\s*/,''),context);
function good(){ return {api_version:1,generated_at:1000,stale_after_secs:15,node:{state:'online',height:10,target_height:10,sync_percent:100,incoming_peers:2,outgoing_peers:8,network:'mainnet',version:'0.18.4.0',latency_ms:2,untrusted:false},privacy:{transport:'local',p2p_verified:false}}; }
function classify(s,now=1001){return context.classify(typeof s==='string'?s:JSON.stringify(s),now);}
test('missing, corrupt and incompatible snapshots are explicit',()=>{
 assert.equal(classify('').state,'missing'); assert.equal(classify('{').state,'invalid');const s=good();s.api_version=2;assert.equal(classify(s).state,'incompatible');
});
test('fresh healthy node is online; stale/future state loses healthy metrics',()=>{
 assert.equal(classify(good()).state,'online');assert.equal(classify(good(),1016).state,'stale');assert.equal(classify(good(),900).state,'invalid');assert.equal(classify(good(),1016).node,null);
});
test('invalid nested fields cannot reach UI formatting',()=>{
 for(const change of [s=>delete s.node,s=>s.node.height='oops',s=>s.node.sync_percent="NaN",s=>s.node.state='invented',s=>s.privacy=null,s=>s.generated_at='1000',s=>s.stale_after_secs=999999,s=>s.node.version='<b>oops</b>'.repeat(200)]){
 let s=good();change(s);assert.equal(classify(s).state,'invalid'); }
});
test('offline and stopped snapshots do not show old success',()=>{
 let s=good();s.node={state:'offline',error:'timeout'};assert.equal(classify(s).state,'offline');assert.equal(classify(s).node.height,undefined);
 s.node={state:'stopped'};assert.equal(classify(s).state,'stopped');
});
test('syncing and unverified privacy are preserved',()=>{
 let s=good();s.node.state='syncing';s.node.sync_percent=50;assert.equal(classify(s).state,'syncing');assert.equal(classify(s).privacy.p2p_verified,false);
});
function market(){return {state:'ready',source:'Kraken',currency:'USD',fetched_at:1000,stale_after_secs:360,sample_interval_secs:3600,price:124,change_percent:24,points:[{timestamp:1,price:100},{timestamp:1000,price:124}]};}
test('market is independent from offline node, and invalid or stale data is hidden',()=>{
 let s=good();s.node={state:'offline',error:'connection'};s.market=market();assert.equal(classify(s).market.state,'ready');
 s.market.fetched_at=1;assert.equal(classify(s).market.state,'stale');
 s.market=market();s.market.price=-1;assert.equal(classify(s).market.state,'invalid');
 s.market=market();s.market.points[1].price='oops';assert.equal(classify(s).market.state,'invalid');
 s.market={state:'disabled'};assert.equal(classify(s).market.state,'disabled');
 s.market=market();s.generated_at=1;assert.notEqual(classify(s).market.state,'ready');
});
test('custom named market sources are accepted but an empty source label is not',()=>{
 let s=good();s.market=market();s.market.source='My Exchange';assert.equal(classify(s).market.source,'My Exchange');
 s.market.source=' ';assert.equal(classify(s).market.state,'invalid');
});
test('custom source sample intervals cover all native choices',()=>{
 for(const interval of [300,900,1800,3600]){const s=good();s.market=market();s.market.sample_interval_secs=interval;assert.equal(classify(s).market.state,'ready');}
});
test('change labels handle rises, falls and a flat market',()=>{
 assert.equal(context.changeLabel(1.234),'+1.23%');assert.equal(context.changeLabel(-2.5),'−2.50%');assert.equal(context.changeLabel(0),'0.00%');
});

test('classic market colors distinguish negative, positive, flat and unavailable',()=>{
 assert.equal(context.trendColor(-1),'#ef4444');assert.equal(context.trendColor(1),'#22c55e');assert.equal(context.trendColor(0),'#9ca3af');assert.equal(context.trendColor(NaN),'#9ca3af');
});

test('five-minute market history is accepted and bounded',()=>{
 const m=market();m.sample_interval_secs=300;m.points=Array.from({length:290},(_,i)=>({timestamp:i+1,price:100+i/100}));
 assert.equal(context.marketView(m,1001).state,'ready');
 m.points=Array.from({length:401},(_,i)=>({timestamp:i+1,price:100}));assert.equal(context.marketView(m,1001).state,'invalid');
 m.points=[{timestamp:1,price:100},{timestamp:1000,price:124}];m.sample_interval_secs=7;assert.equal(context.marketView(m,1001).state,'invalid');
});

test('atomic XMR amounts retain all 12 decimals above JS integer precision',()=>{
 assert.equal(context.atomicLabel('9007199254740993'),'9007.199254740993 XMR');assert.equal(context.atomicLabel('1'),'0.000000000001 XMR');assert.equal(context.atomicLabel('1000000000000'),'1 XMR');assert.equal(context.atomicLabel(9007199254740992),'Unavailable');
});
