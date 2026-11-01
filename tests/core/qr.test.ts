import {it,expect} from 'vitest';
import jsQR from 'jsqr';
import {payment} from '../../src/core/index';
it('independent QR decoder reads the canonical Monero URI',()=>{
 const address='44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';
 const p=payment({address,amount:'0.000000000001',label:'İstanbul #1'},'mainnet');
 const size=+(/viewBox="0 0 (\d+) \d+"/.exec(p.qr_svg)![1]);
 const pixels=new Uint8ClampedArray(size*size*4).fill(255);
 // Rasterize only the emitted SVG's square path geometry; decode independently.
 const path=/\bd="([^"]+)"/.exec(p.qr_svg)![1];
 const squares=Array.from(path.matchAll(/M(\d+),(\d+)l(\d+),0 0,\d+ -\d+,0 0,-\d+z/g));
 expect(squares.length).toBeGreaterThan(100);
 for(const square of squares){const x=+square[1],y=+square[2],width=+square[3];for(let dy=0;dy<width;dy++)for(let dx=0;dx<width;dx++){const offset=((y+dy)*size+x+dx)*4;pixels[offset]=pixels[offset+1]=pixels[offset+2]=0;}}
 expect(jsQR(pixels,size,size)?.data).toBe(p.uri);
});
