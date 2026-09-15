import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import ts from 'typescript';

test('group roster lists Auth memberships independently of game players and optional profile lookup',async()=>{
 const source=await readFile(new URL('../src/services/userService.ts',import.meta.url),'utf8');
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={},calls=[];
 const members=[{id:'a',user_id:'owner',group_id:'group',role:'admin'},{id:'b',user_id:'fede',group_id:'group',role:'member'}];
 let profileError=false,memberError=false;
 const mock={from:table=>{calls.push(table);assert.ok(['group_members','user_profiles'].includes(table));return {select:selection=>{
  assert.equal(selection,'*');
  if(table==='user_profiles')return {in:async(key,ids)=>{assert.equal(key,'user_id');assert.deepEqual(ids,['owner','fede']);return profileError?{error:new Error('profile unavailable')}:{data:[{user_id:'owner',nick:'FedeTeam'},{user_id:'fede',nick:'Fede'}]};}};
  return {eq:(key,value)=>{assert.equal(key,'group_id');assert.equal(value,'group');return {order:async()=>memberError?{error:new Error('membership unavailable')}:{data:members}};}};
 }};}};
 new Function('require','exports',js)(name=>name.includes('supabaseClient')?{supabase:mock}:{},exports);
 const service=exports.userService;
 const roster=await service.getGroupMembers('group');
 assert.equal(roster.length,2);assert.equal(roster[1].profile.nick,'Fede');assert.equal(roster[1].role,'member');assert.equal(roster[0].profile.nick,'FedeTeam');
 assert.deepEqual(calls,['group_members','user_profiles']);
 profileError=true;assert.equal((await service.getGroupMembers('group')).length,2,'missing profiles must not hide membership');
 memberError=true;await assert.rejects(service.getGroupMembers('group'),/membership unavailable/);
});
