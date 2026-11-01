import {keccak256} from 'js-sha3';
import qrcode from 'qrcode-generator';
import {ensure,Dict} from './privacy';
const alphabet='123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const sizes=[0,2,3,5,6,7,9,10,11];
/** Monero block Base58: each 8-byte big-endian block encodes independently. */
export function validateAddress(address:string,network:string) {
    ensure(typeof address==='string' && [95,106].includes(address.length),'Invalid Monero address');
    const bytes:number[]=[];
    for(let offset=0;offset<address.length;offset+=11) {
        const block=address.slice(offset,offset+11), n=sizes.indexOf(block.length);ensure(n>0,'Invalid Base58 block');
        const decoded=new Array<number>(n).fill(0);
        for(const char of block){let carry=alphabet.indexOf(char);ensure(carry>=0,'Invalid Base58 character');for(let i=n-1;i>=0;i--){carry+=decoded[i]*58;decoded[i]=carry&255;carry=Math.floor(carry/256);}ensure(carry===0,'Base58 overflow');}
        bytes.push(...decoded);
    }
    const prefixes:Dict={mainnet:[18,19,42],testnet:[53,54,63],stagenet:[24,25,36]};
    ensure(prefixes[network] && prefixes[network].includes(bytes[0]),'The address belongs to a different Monero network');
    ensure(bytes.length===(bytes[0]===prefixes[network][1]?77:69),'Invalid address length');
    const payload=new Uint8Array(bytes.slice(0,-4)),hash=keccak256.array(payload);
    ensure(bytes.slice(-4).every((b,i)=>b===hash[i]),'Invalid Monero address checksum');return true;
}
function text(value:unknown) {if(value===undefined || value===null || value==='')return null;ensure(typeof value==='string' && unescape(encodeURIComponent(value)).length<=160 && !/[\x00-\x1f\x7f-\x9f\ufffd]/.test(value),'Request text is invalid');return value;}
function amount(raw:unknown){if(raw===undefined || raw===null || raw==='')return null;ensure(typeof raw==='string' && raw.length<=32 && /^\d+(?:\.\d{1,12})?$/.test(raw),'Invalid XMR amount; use at most 12 decimal places');const parts=raw.split('.'),whole=parts[0].replace(/^0+(?=\d)/,'');ensure(+whole<=1000000000,'XMR amount too large');const fraction=(parts[1]||'').replace(/0+$/,'');ensure(+whole>0 || fraction.length>0,'Amount must be positive, or left empty');return whole+(fraction?'.'+fraction:'');}
export function payment(input:Dict,network:string):Dict {
    let address=input.address,rawAmount=input.amount,label=input.label,description:unknown;
    ensure(Object.keys(input).every(k=>['address','amount','label','uri'].includes(k)),'Unsupported payment field');
    if(input.uri!==undefined){ensure(address===undefined && rawAmount===undefined && label===undefined && typeof input.uri==='string' && input.uri.length<=2048,'Ambiguous payment request');const m=/^monero:([^/?#]+)(?:\?([^#]*))?$/i.exec(input.uri);ensure(m,'Only monero: payment links are supported');address=m[1];const seen:string[]=[];for(const pair of (m[2]||'').split('&').filter(Boolean)){const split=pair.indexOf('=');ensure(split>0,'Invalid payment parameter');const decode=(v:string)=>decodeURIComponent(v.replace(/\+/g,' '));const k=decode(pair.slice(0,split)),v=decode(pair.slice(split+1));ensure(!seen.includes(k),'Duplicate payment parameter');seen.push(k);if(k==='tx_amount')rawAmount=v;else if(k==='recipient_name')label=v;else if(k==='tx_description')description=v;else throw Error('Unsupported payment parameter');}}
    validateAddress(address,network);const a=amount(rawAmount),l=text(label),d=text(description),pairs:string[]=[];
    for(const [k,v] of [['tx_amount',a],['recipient_name',l],['tx_description',d]]) if(v!==null)pairs.push(k+'='+encodeURIComponent(v));
    const uri='monero:'+address+(pairs.length?'?'+pairs.join('&'):'');ensure(uri.length<=2048,'Request too long');
    const qr=qrcode(0,'M');qr.addData(uri,'Byte');qr.make();
    return {address,amount:a,label:l,description:d,uri,qr_svg:qr.createSvgTag({cellSize:4,margin:16,scalable:true})};
}
export function proofParams(p:Dict,network:string){ensure(typeof p.txid==='string' && /^[a-fA-F0-9]{64}$/.test(p.txid),'Invalid transaction ID');validateAddress(p.address,network);ensure(typeof p.message==='string' && p.message.length<=4096 && typeof p.signature==='string' && /^[a-zA-Z0-9]{1,8192}$/.test(p.signature),'Invalid transaction proof input');return {txid:p.txid,address:p.address,message:p.message,signature:p.signature};}
