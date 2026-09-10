import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import ts from 'typescript';
import {randomUUID} from 'node:crypto';
const source=await readFile(new URL('../src/services/tabAuthStorage.ts',import.meta.url),'utf8');
const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const channels=[];const messages=[];
class Channel {
 constructor(name){this.name=name;this.closed=false;channels.push(this);}
 postMessage(data){messages.push(data);for(const c of channels)if(c!==this&&!c.closed&&c.name===this.name)queueMicrotask(()=>c.onmessage?.({data}));}
 close(){this.closed=true;}
}
class Storage {
 constructor(other){this.items=new Map(other?.items);}
 get length(){return this.items.size;}
 key(i){return [...this.items.keys()][i]??null;}
 getItem(k){return this.items.get(k)??null;}
 setItem(k,v){this.items.set(k,v);}
 removeItem(k){this.items.delete(k);}
}
function tab(storage){const exports={};const start=channels.length;new Function('exports','crypto','window','BroadcastChannel',js)(exports,{randomUUID},{sessionStorage:storage,setTimeout},Channel);return {...exports,dispose(){for(const c of channels.slice(start))c.close();}};}
test('auth isolation: two tabs, reload, copied tab, scoped cleanup and private storage',async()=>{
 const storageA=new Storage(),storageB=new Storage();const a=tab(storageA),b=tab(storageB);
 assert.notEqual(a.authStorageKey,b.authStorageKey);
 await a.tabAuthStorage.setItem(a.authStorageKey,'admin-session');
 await b.tabAuthStorage.setItem(b.authStorageKey,'player-session');
 assert.equal(await a.tabAuthStorage.getItem(a.authStorageKey),'admin-session');
 assert.equal(await b.tabAuthStorage.getItem(b.authStorageKey),'player-session');
 // A newly duplicated tab must not reuse the live original's refresh token.
 const clone=tab(new Storage(storageA));
 assert.equal(await clone.tabAuthStorage.getItem(clone.authStorageKey),null);
 assert.equal(await a.tabAuthStorage.getItem(a.authStorageKey),'admin-session');
 await clone.tabAuthStorage.setItem(clone.authStorageKey,'new-independent-session');
 await clone.clearTabAuthSession();
 assert.equal(await a.tabAuthStorage.getItem(a.authStorageKey),'admin-session');
 await b.clearTabAuthSession();
 assert.equal(await a.tabAuthStorage.getItem(a.authStorageKey),'admin-session');
 assert.equal(await b.tabAuthStorage.getItem(b.authStorageKey),null);
 // Simulate original document unload while retaining its tab sessionStorage.
 channels.filter(c=>c.name==='golf-auth-tab-ownership-v1').forEach(c=>c.close());
 const reloaded=tab(storageA);
 assert.notEqual(reloaded.authStorageKey,a.authStorageKey);
 assert.equal(await reloaded.tabAuthStorage.getItem(reloaded.authStorageKey),'admin-session');
 await reloaded.tabAuthStorage.setItem(reloaded.authStorageKey+'-code-verifier','verifier');
 assert.equal(await reloaded.tabAuthStorage.getItem(reloaded.authStorageKey+'-code-verifier'),'verifier');
 assert.ok(!JSON.stringify(messages).includes('admin-session'));
 const privateTab=tab({setItem(){throw Error('storage disabled');}});
 await privateTab.tabAuthStorage.setItem(privateTab.authStorageKey,'private-session');
 assert.equal(await privateTab.tabAuthStorage.getItem(privateTab.authStorageKey),'private-session');
 await privateTab.clearTabAuthSession();
 assert.equal(await privateTab.tabAuthStorage.getItem(privateTab.authStorageKey),null);
 channels.forEach(c=>c.close());
});
