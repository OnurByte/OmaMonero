import {describe,it,expect} from 'vitest';
import * as Core from '../../src/core/index';
const address='44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';
describe('payment safety',()=>{
 it('validates checksum and network',()=>{expect(Core.validateAddress(address,'mainnet')).toBe(true);expect(()=>Core.validateAddress(address,'testnet')).toThrow();expect(()=>Core.validateAddress(address.slice(0,-1)+'B','mainnet')).toThrow()});
 it('creates an offline QR and canonical URI',()=>{const p=Core.payment({address,amount:'1.250000000000',label:'Invoice #1'},'mainnet');expect(p.uri).toContain('tx_amount=1.25&recipient_name=Invoice%20%231');expect(p.qr_svg).toContain('<svg');expect(p.address).toBe(address)});
 it.each(['tx_amount=-1','tx_amount=0','tx_amount=1e3','tx_amount=1.0000000000001','req-unknown=1','tx_amount=1&tx_amount=2','payment_id=1','recipient_name=%0A','recipient_name=%FF'])('rejects %s',(q)=>expect(()=>Core.payment({uri:'monero:'+address+'?'+q},'mainnet')).toThrow());
 it('refuses ambiguous and oversized requests',()=>{expect(()=>Core.payment({uri:'monero:'+address,address},'mainnet')).toThrow();expect(()=>Core.payment({address,label:'x'.repeat(161)},'mainnet')).toThrow()});
});
describe('privacy transport',()=>{
 it('defaults to local node and enabled USD prices by user choice',()=>{expect(Core.defaults().market_enabled).toBe(true);expect(Core.validateConfig(Core.defaults()).transport).toBe('local')});
 it.each(['http://example.org','http://127.0.0.1@evil.org','http://localhost','file:///tmp/foo','http://127.0.0.1/a','http://127.0.0.1?x'])('rejects unsafe local origin %s',(url)=>expect(()=>Core.localOrigin(url)).toThrow());
 it('forces remote DNS and never bypasses configured proxy',()=>{const c=Core.validateConfig({...Core.defaults(),transport:'tor',endpoint:'http://node.onion:18081',proxy:'socks5h://127.0.0.1:9050'});const r=Core.request(c,c.endpoint+'/json_rpc','get_info',{});expect(r.stdin).toContain('proxy = "socks5h://127.0.0.1:9050"');expect(r.stdin).toContain('noproxy = ""');expect(r.argv.join(' ')).not.toContain('node.onion');expect(r.argv).not.toContain('--location');expect(()=>Core.validateConfig({...c,proxy:''})).toThrow()});
 it('keeps sensitive proof data out of arguments',()=>{const r=Core.request(Core.defaults(),'http://127.0.0.1:18082/json_rpc','check_tx_proof',{signature:'PRIVATE_PROOF'});expect(r.argv.join(' ')).not.toContain('PRIVATE_PROOF');expect(r.stdin).toContain('PRIVATE_PROOF');expect(r.stdin).toContain('max-filesize = 1048576')});
 it('rejects malformed JSON with leading-zero integer tokens',()=>expect(()=>Core.parseJson('{"balance":00000000000000001}')).toThrow());
 it('preserves atomic amounts above JS precision',()=>{expect(Core.parseJson('{"balance":18446744073709551615}').balance).toBe('18446744073709551615')});
});
describe('telemetry',()=>{
 it('validates network and node state',()=>{const v={height:100,target_height:200,synchronized:false,busy_syncing:true,nettype:'mainnet',incoming_connections_count:2,outgoing_connections_count:8,untrusted:false,status:'OK'};expect(Core.node(v,'mainnet',4).sync_percent).toBe(50);expect(()=>Core.node(v,'testnet',4)).toThrow();expect(()=>Core.node({...v,height:-1},'mainnet',4)).toThrow()});
 it('interpolates a true trailing day and rejects stale/gapped data',()=>{const now=200000, points=Array.from({length:26},(_,i)=>({timestamp:now-90000+i*3600,price:100+i}));const s=Core.defaults().market_source;const p=Core.customMarket({price:125,points},now,s);expect(p.points[0].timestamp).toBe(now-86400);expect(p.change_percent).toBeCloseTo(24/101*100);expect(()=>Core.customMarket({price:125,points:points.slice(2)},now,s)).toThrow()});
 it('requires watch-only confirmation and numeric loopback',()=>{expect(()=>Core.validateConfig({...Core.defaults(),modules:{wallet_rpc:'https://evil.org',watch_only_confirmed:true}})).toThrow()});
 it('validates proof before RPC',()=>{expect(()=>Core.proofParams({txid:'a'.repeat(64),address,message:'',signature:'proof'},'mainnet')).not.toThrow();expect(()=>Core.proofParams({txid:'x',address,message:'',signature:'proof'},'mainnet')).toThrow()});
});
// Vectors from monero-rs util/address.rs tests (the former Rust dependency).
describe('Monero address compatibility vectors',()=>{
 it.each(['4ADT1BtbxqEWeMKp9GgPr2NeyJXXtNxvoDawpyA4WpzFcGcoHUvXeijE66DNfohE9r1bQYaBiQjEtKE7CtkTdLwiDznFzra','4Byr22j9M2878Mtyb3fEPcBNwBZf5EXqn1Yi6VzR46618SFBrYysab2Cs1474CVDbsh94AJq7vuV3Z2DRq4zLcY3LHzo1Nbv3d8J6VhvCV','8AW7SotwFrqfAKnibspuuhfowW4g3asvpQvdrTmPcpNr2GmXPtBBSxUPZQATAt8Vw2hiX9GDyxB4tMNgHjwt8qYsCeFDVvn'])('accepts standard/integrated/subaddress %s',(a)=>expect(Core.validateAddress(a,'mainnet')).toBe(true));
 it.each(['http://[::ffff:127.0.0.1]','http://127.0.0.999','http://127.0.0.1:0','http://127.0.0.1:65536'])('rejects ambiguous or invalid numeric origin %s',(u)=>expect(()=>Core.localOrigin(u)).toThrow());
});
