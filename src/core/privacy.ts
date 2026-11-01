/** URL validation deliberately does not depend on browser-only URL APIs. */
export type Dict = Record<string, any>;
export function ensure(ok: unknown, message = 'Invalid response'): asserts ok { if (!ok) throw Error(message); }
export function integer(v: unknown): v is number { return typeof v === 'number' && Number.isSafeInteger(v) && v >= 0; }
export function origin(raw: string): {scheme:string;host:string;port:string;url:string} {
    ensure(typeof raw === 'string' && raw.length <= 2048, 'Invalid endpoint');
    const m = /^(https?):\/\/(\[[0-9a-fA-F:]+\]|[a-zA-Z0-9.-]+)(?::([0-9]{1,5}))?\/?$/.exec(raw);
    ensure(m && (!m[3] || (+m[3] > 0 && +m[3] <= 65535)), 'Use an HTTP(S) origin without credentials, paths or queries');
    return {scheme:m[1],host:m[2].toLowerCase(),port:m[3] || '',url:raw.replace(/\/$/,'')};
}
export function loopback(host:string) { return host === '[::1]' || /^127\.(?:\d{1,3}\.){2}\d{1,3}$/.test(host) && host.split('.').every(v=>+v<=255); }
export function localOrigin(raw:string) { const o=origin(raw);ensure(o.scheme==='http' && loopback(o.host),'Use a numeric loopback HTTP origin');return o.url; }
export function defaults(): Dict { return {endpoint:'http://127.0.0.1:18081',network:'mainnet',transport:'local',proxy:'',market_enabled:false,poll_interval_secs:5,timeout_ms:3000,market_source:{name:'Kraken',url:'',price_pointer:'/price',points_pointer:'/points',timestamp_pointer:'/timestamp',point_price_pointer:'/price',interval_secs:3600},modules:{wallet_rpc:'',watch_only_confirmed:false,notify_payments:false,xmrig_url:'',p2pool_directory:''}}; }
export function publicUrl(raw:string) { ensure(typeof raw==='string' && /^https:\/\/[A-Za-z0-9.-]+(?::[0-9]{1,5})?(?:\/[A-Za-z0-9._~!$&'()*+,;=:@%/?-]*)?$/.test(raw) && raw.length<=2048,'Use a public HTTPS URL without credentials or fragment');return raw; }
export function validateConfig(input:Dict):Dict {
    const d=defaults(); const c:Dict={...d,...input,market_source:{...d.market_source,...input.market_source},modules:{...d.modules,...input.modules}};
    ensure(['local','direct','tor','i2p'].includes(c.transport),'Invalid transport');ensure(['mainnet','testnet','stagenet'].includes(c.network),'Invalid network');
    c.endpoint=origin(c.endpoint).url;
    const o=origin(c.endpoint);
    if(c.transport==='local') localOrigin(c.endpoint);
    if(c.transport==='direct') ensure(o.scheme==='https','Direct remote RPC requires HTTPS');
    if(c.transport==='tor' || c.transport==='i2p') { ensure(typeof c.proxy==='string' && /^socks5h:\/\/(?:127\.(?:\d{1,3}\.){2}\d{1,3}|\[::1\]):\d{1,5}$/.test(c.proxy),'Choose a local SOCKS5h proxy');const p=origin(c.proxy.replace('socks5h:','http:'));ensure(loopback(p.host),'Proxy must be numeric loopback'); }
    else ensure(!c.proxy,'Proxy requires Tor or I2P transport');
    ensure(typeof c.market_enabled==='boolean','Invalid market choice');
    ensure(integer(c.poll_interval_secs) && c.poll_interval_secs>=1 && c.poll_interval_secs<=300,'Invalid polling interval');
    ensure(integer(c.timeout_ms) && c.timeout_ms>=50 && c.timeout_ms<=30000,'Invalid timeout');
    const s=c.market_source;ensure(typeof s.name==='string' && s.name.trim().length>0 && s.name.length<=48,'Invalid source name');if(s.url) publicUrl(s.url);
    ensure([300,900,1800,3600].includes(s.interval_secs),'Invalid interval');
    for(const k of ['price_pointer','points_pointer','timestamp_pointer','point_price_pointer']) ensure(typeof s[k]==='string' && s[k].startsWith('/') && s[k].length<=256,'Invalid JSON pointer');
    const m=c.modules;for(const k of ['wallet_rpc','xmrig_url']) if(m[k]) m[k]=localOrigin(m[k]);
    ensure(typeof m.watch_only_confirmed==='boolean' && typeof m.notify_payments==='boolean','Invalid module confirmation');
    ensure(typeof m.p2pool_directory==='string' && (!m.p2pool_directory || m.p2pool_directory.startsWith('/') && !/[\x00-\x1f]/.test(m.p2pool_directory)),'P2Pool directory must be absolute');
    return c;
}
/** Quote curl config values, including embedded request JSON; never shell syntax. */
function quote(s:string){return '"'+s.replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/\n/g,'\\n').replace(/\r/g,'\\r').replace(/\t/g,'\\t')+'"';}
export function request(config:Dict,url:string,method?:string,params:Dict={},local=false) {
    const c=validateConfig(config);
    ensure(typeof url==='string' && !/[\x00-\x20\x7f"\\]/.test(url),'Invalid request URL');
    if(local) localOrigin(url.replace(/\/(?:json_rpc|2\/summary)$/,''));
    const proxy=local?'':c.proxy;
    const lines=['silent','fail','globoff','max-time = '+(method==='get_info'?c.timeout_ms/1000:local?4:8),'connect-timeout = '+Math.min(3,c.timeout_ms/1000),'max-filesize = 1048576','proto = "=http,https"','max-redirs = 0','write-out = "\\n%{http_code}"','noproxy = '+quote(proxy?'':'*'),'proxy = '+quote(proxy),'url = '+quote(url)];
    if(method) {ensure(['get_info','get_balance','get_address','get_height','get_transfers','check_tx_proof'].includes(method),'Unsupported RPC method');lines.push('header = "Content-Type: application/json"','data-binary = '+quote(JSON.stringify({jsonrpc:'2.0',id:'omamonero',method,params})));}
    // -q is first: ignore ~/.curlrc. No redirects, retries, insecure TLS or env proxy fallback.
    return {argv:['/usr/bin/curl','-q','--config','-'],stdin:lines.join('\n')+'\n'};
}
/** Preserve u64 tokens before JSON.parse can round wallet atomic amounts. */
export function parseJson(raw:string):Dict {
    ensure(typeof raw==='string' && raw.length<=1048576,'Response too large');
    const safe=raw.replace(/"(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g,token=> /^[1-9]\d{15,}$/.test(token)?'"'+token+'"':token);
    const v=JSON.parse(safe);ensure(v && typeof v==='object' && !Array.isArray(v));return v;
}
export function rpcResult(v:Dict) {ensure(v.jsonrpc==='2.0' && v.id==='omamonero' && !v.error && v.result && typeof v.result==='object');return v.result as Dict;}
export function httpBody(raw:string):Dict {const split=raw.lastIndexOf('\n');ensure(split>=0 && /^2[0-9]{2}$/.test(raw.slice(split+1)), 'HTTP request failed');return parseJson(raw.slice(0,split));}
