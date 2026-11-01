import {ensure,integer,Dict} from './privacy';
export function node(v:Dict,network:string,latency:number):Dict {
    ensure(v.status==='OK' && v.nettype===network,'Network mismatch or invalid node response');
    for(const k of ['height','target_height','incoming_connections_count','outgoing_connections_count'])ensure(integer(v[k]));
    ensure(v.height>0 && typeof v.synchronized==='boolean' && typeof v.busy_syncing==='boolean' && typeof v.untrusted==='boolean');
    ensure(v.version===undefined || v.version===null || typeof v.version==='string' && /^[A-Za-z0-9._+\-]{0,64}$/.test(v.version));
    for(const k of ['database_size','free_space'])ensure(v[k]===undefined || v[k]===null || integer(v[k]));
    const synced=v.synchronized && !v.busy_syncing;
    return {state:synced?'online':'syncing',height:v.height,target_height:v.target_height,incoming_peers:v.incoming_connections_count,outgoing_peers:v.outgoing_connections_count,network,latency_ms:Math.max(0,Math.floor(latency)),untrusted:v.untrusted,version:v.version||null,database_bytes:v.database_size??null,free_bytes:v.free_space??null,sync_percent:synced?100:v.target_height>0?Math.min(100,v.height/v.target_height*100):null};
}
