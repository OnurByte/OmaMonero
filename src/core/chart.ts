import {Dict,ensure} from './privacy';
function bounded(length:number,count:number,offset:number){
    ensure(Number.isSafeInteger(length) && length>=0 && length<=1000,'Invalid chart history');
    if(!length)return {count:0,offset:0};
    const n=Math.max(Math.min(12,length),Math.min(length,Math.round(Number.isFinite(count)?count:length)));
    return {count:n,offset:Math.max(0,Math.min(length-n,Math.round(Number.isFinite(offset)?offset:0)))};
}
export function chartWindow(series:Dict[],count:number,offset:number):Dict {
    ensure(Array.isArray(series),'Invalid chart series');
    const b=bounded(series.length,count,offset),end=series.length-b.offset,start=end-b.count,rows=series.slice(start,end);
    if(!rows.length)return {rows:[],count:0,offset:0,startIndex:0,endIndex:0,low:0,high:1,maxVolume:0};
    let low=Infinity,high=-Infinity,maxVolume=0;
    for(const row of rows){const l=row.low??row.price,h=row.high??row.price;ensure(typeof l==='number' && Number.isFinite(l) && l>0 && typeof h==='number' && Number.isFinite(h) && h>=l,'Invalid chart prices');low=Math.min(low,l);high=Math.max(high,h);if(typeof row.volume==='number' && Number.isFinite(row.volume) && row.volume>=0)maxVolume=Math.max(maxVolume,row.volume);}
    const margin=Math.max((high-low)*.08,high*.0001);
    return {...b,rows,startIndex:start,endIndex:end,low:Math.max(0,low-margin),high:high+margin,maxVolume};
}
export function chartZoom(length:number,count:number,offset:number,factor:number,anchor:number):{count:number;offset:number}{
    ensure(Number.isFinite(factor) && factor>0 && Number.isFinite(anchor),'Invalid chart zoom');
    const old=bounded(length,count,offset);if(!length)return old;
    const next=bounded(length,old.count*factor,0),a=Math.max(0,Math.min(1,anchor));
    const point=length-old.offset-old.count+(old.count-1)*a;
    const start=Math.max(0,Math.min(length-next.count,Math.round(point-(next.count-1)*a)));
    return {count:next.count,offset:length-start-next.count};
}
export function anchoredChartOffset(series:Dict[],count:number,timestamp:number):number {
    const b=bounded(series.length,count,0);
    if(!series.length || !Number.isFinite(timestamp))return 0;
    let index=0;
    for(let i=series.length-1;i>=0;i--){if(series[i].timestamp<=timestamp){index=i;break;}}
    return Math.max(0,Math.min(series.length-b.count,series.length-1-index));
}
