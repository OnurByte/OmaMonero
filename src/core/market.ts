import {ensure,integer,Dict} from './privacy';
type Point={timestamp:number;price:number};
function price(v:unknown){ensure((typeof v==='number' || typeof v==='string' && v.trim()!=='') && Number.isFinite(+v) && +v>0 && +v<=1e9);return +v;}
function pointer(v:Dict,path:string):any {let out:any=v;for(const key of path.slice(1).split('/').map(v=>v.replace(/~1/g,'/').replace(/~0/g,'~'))){ensure(out && typeof out==='object' && Object.prototype.hasOwnProperty.call(out,key));out=out[key];}return out;}
function quote(points:Point[],current:number,now:number,source:string,interval:number):Dict {
    ensure(points.length>=2 && points.length<=722);let prev=0;
    for(const p of points){ensure(integer(p.timestamp) && p.timestamp>prev && p.timestamp<=now && (prev===0 || p.timestamp-prev<=interval*2));price(p.price);prev=p.timestamp;}
    ensure(now-prev<=interval+180);if(prev<now)points.push({timestamp:now,price:current});else points[points.length-1].price=current;
    const cutoff=now-86400;let baseline:number|undefined;
    for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i];if(a.timestamp<=cutoff && b.timestamp>=cutoff){baseline=a.price+(b.price-a.price)*(cutoff-a.timestamp)/(b.timestamp-a.timestamp);break;}}
    ensure(baseline!==undefined && baseline>0);const day=[{timestamp:cutoff,price:baseline},...points.filter(p=>p.timestamp>cutoff)];ensure(day.length<=400);
    return {state:'ready',source,currency:'USD',fetched_at:now,stale_after_secs:360,sample_interval_secs:interval,price:current,change_percent:(current-baseline)/baseline*100,points:day};
}
export function customMarket(v:Dict,now:number,s:Dict):Dict {const rows=pointer(v,s.points_pointer);ensure(Array.isArray(rows) && rows.length>=2 && rows.length<=400);return quote(rows.map(r=>({timestamp:+pointer(r,s.timestamp_pointer),price:price(pointer(r,s.point_price_pointer))})),price(pointer(v,s.price_pointer)),now,s.name.trim(),s.interval_secs);}
export function krakenMarket(v:Dict,now:number,interval=3600):Dict {
    ensure(Array.isArray(v.error) && v.error.length===0);const rows=v.result?.XXMRZUSD;ensure(Array.isArray(rows) && rows.length>=2 && rows.length<=721);const points:Point[]=[];let previous=0;
    rows.forEach((r:any,i:number)=>{ensure(Array.isArray(r) && r.length===8 && integer(r[0]) && r[0]>previous && r[0]<=now && (!previous || r[0]-previous<=interval*2));previous=r[0];if(i===0)points.push({timestamp:r[0],price:price(r[1])});const end=i===rows.length-1?now:r[0]+interval;ensure(end<=now && (i!==rows.length-1 || now-r[0]<=interval+180));if(points[points.length-1]?.timestamp===end)points.pop();points.push({timestamp:end,price:price(r[4])});});
    return quote(points,points[points.length-1].price,now,'Kraken',interval);
}
