import {it,expect} from 'vitest';
import {nativePath} from '../../src/core/index';
it.each(['file:///home/user%20name/plugin/native.sh','qs:///home/user%20name/plugin/native.sh','qs:/home/user%20name/plugin/native.sh'])('resolves real Quickshell native helper URL %s',url=>expect(nativePath(url)).toBe('/home/user name/plugin/native.sh'));
it.each(['qs://foreign/secret','qrc:/plugin/native.sh','file:///tmp/a%00b','relative/native.sh'])('rejects non-local helper location %s',url=>expect(()=>nativePath(url)).toThrow());
