import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import ts from 'typescript';
const source = await readFile(new URL('../src/services/adminService.ts', import.meta.url), 'utf8');
function service(mock) {
 const exports = {};
 const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
 new Function('require','exports',js)(() => ({supabase:mock}),exports);
 return exports.adminService;
}
test('account classification fails closed for admin identities and permission errors',async()=>{
 const player={id:'player',app_metadata:{},user_metadata:{app_account_type:'administrator'}};
 const admin={id:'admin',app_metadata:{app_account_type:'administrator'}};
 let result={data:null,error:null};
 const api=service({rpc:async()=>result});
 assert.equal(await api.getAccount(player),null);
 await assert.rejects(api.getAccount(admin),/configuración/);
 result={data:null,error:{code:'PGRST202'}};
 assert.equal(await api.getAccount(player),null);
 await assert.rejects(api.getAccount(admin),/permisos/);
 result={data:null,error:{code:'network'}};
 await assert.rejects(api.getAccount(player),/permisos/);
 result={data:{user_id:'other',status:'active'},error:null};
 await assert.rejects(api.getAccount(admin),/sesión/);
 for(const status of ['invited','active','disabled']){
 result={data:{user_id:'admin',alias:'AdminF',status},error:null};
 assert.equal((await api.getAccount(admin)).status,status);
 }
});
test('alias authentication establishes only the server-provided session; recovery sends no player email',async()=>{
 const calls=[];const tokens={access_token:'access',refresh_token:'refresh'};
 const api=service({functions:{invoke:async(name,{body})=>{calls.push({name,body});return {data:{session:tokens},error:null};}},auth:{setSession:async session=>{assert.deepEqual(session,tokens);return {data:{user:{id:'admin'}},error:null};}}});
 assert.equal((await api.login('AdminF','secret')).id,'admin');
 await api.recover('AdminF');
 assert.deepEqual(calls,[{name:'admin-auth',body:{action:'login',alias:'AdminF',password:'secret'}},{name:'admin-auth',body:{action:'recover',alias:'AdminF'}}]);
});
