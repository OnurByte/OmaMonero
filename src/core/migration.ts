import {parse} from 'smol-toml';
import {validateConfig,Dict} from './privacy';
export function legacyConfig(raw:string):Dict {const c=parse(raw) as Dict;if(c.proxy===null)delete c.proxy;return validateConfig(c);}
