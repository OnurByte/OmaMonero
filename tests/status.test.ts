import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
const qml=path.dirname(JSON.parse(fs.readFileSync('manifest.json','utf8')).entryPoints.barWidget);
const context: any=vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(qml,'generated/Core.js'),'utf8').replace(/^\.pragma library\s*/,''),context);
const presentation: any = context.OmaCore;
function market(): any{return {state:'ready',source:'Kraken',currency:'USD',fetched_at:1000,stale_after_secs:360,sample_interval_secs:3600,price:124,change_percent:24,points:[{timestamp:1,price:100},{timestamp:1000,price:124}]};}
test('market freshness and invalid data are explicit',()=>{
 assert.equal(presentation.marketView(market(),1001).state,'ready');assert.equal(presentation.marketView(market(),1361).state,'stale');
 for(const mutate of [(m: any)=>m.price=-1,(m: any)=>m.currency='EUR',(m: any)=>m.fetched_at=2000,(m: any)=>m.points[1].timestamp=0,(m: any)=>m.source='',(m: any)=>m.points=Array(401).fill({timestamp:1,price:1})]){const m=market();mutate(m);assert.equal(presentation.marketView(m,1001).state,'invalid');}
 assert.equal(presentation.marketView({state:'disabled'},1001).state,'disabled');assert.equal(presentation.marketView({state:'unavailable'},1001).state,'unavailable');
});
test('all supported chart intervals work with truthful source',()=>{for(const interval of [300,900,1800,3600]){const m=market();m.source='My Exchange';m.sample_interval_secs=interval;assert.equal(presentation.marketView(m,1001).source,'My Exchange');}});
test('market trend colors follow user preference and label values are exact',()=>{
 assert.equal(presentation.trendColor(-1),'#ef4444');assert.equal(presentation.trendColor(0),'#22c55e');assert.equal(presentation.trendColor(1),'#22c55e');assert.equal(presentation.trendColor(NaN),'#9ca3af');
 assert.equal(presentation.changeLabel(-1.234),'−1.23%');assert.equal(presentation.changeLabel(1),'+1.00%');assert.equal(presentation.changeLabel(0),'0.00%');assert.equal(presentation.changeLabel(NaN),'—');
});
test('wallet atomic amounts never lose precision',()=>{assert.equal(presentation.atomicLabel('18446744073709551615'),'18446744.073709551615 XMR');assert.equal(presentation.atomicLabel('1'),'0.000000000001 XMR');assert.equal(presentation.atomicLabel(1e20),'Unavailable');assert.equal(presentation.atomicLabel(null),'—');});
test('primary navigation has three clear destinations and no default Offline label',()=>{const nav=fs.readFileSync(path.join(qml,'components/PanelNavigation.qml'),'utf8');assert.match(nav,/label:"Price"/);assert.match(nav,/label:"Receive"/);assert.match(nav,/label:"More"/);assert.doesNotMatch(fs.readFileSync(path.join(qml,'BarWidget.qml'),'utf8'),/Offline|nodeLabel/);});
test('settings edits use copies rather than mutating live source before Save',()=>{const panel=fs.readFileSync(path.join(qml,'Panel.qml'),'utf8');assert.equal((panel.match(/setupForm\.marketSource = Object\.assign\(\{\},StatusStore\.setupData\.market_source/g)||[]).length,2);});

test('the bar reports market state independently of optional node connectivity',()=>{assert.equal(presentation.marketLabel({state:'loading'}),'Loading…');assert.equal(presentation.marketLabel({state:'disabled'}),'Paused');assert.equal(presentation.marketLabel({state:'unavailable'}),'—');assert.equal(presentation.marketLabel(market()),'$124.00 +24.00%');});
test('malformed OHLC cannot enter the production renderer',()=>{const m=market();m.candles=[{timestamp:1,open:100,high:90,low:80,close:110,volume:1,complete:true},{timestamp:1000,open:100,high:101,low:99,close:100,volume:1,complete:false}];assert.equal(presentation.marketView(m,1001).state,'invalid');});
