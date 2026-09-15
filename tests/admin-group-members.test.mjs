import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import ts from 'typescript';

test('roster uses the scoped server operation and mutations carry both expected versions',async()=>{
 const source=await readFile(new URL('../src/services/userService.ts',import.meta.url),'utf8');
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={},calls=[];
 const member={id:'m',user_id:'fede',group_id:'g',member_revision:2,player_revision:3,profile:{nick:'Fede'}};
 let failure=false;
 const mock={rpc:async(name,args)=>{calls.push({name,args});return failure?{error:new Error('server unavailable')}:{data:[member]};}};
 new Function('require','exports',js)(name=>name.includes('supabaseClient')?{supabase:mock}:{},exports);
 assert.deepEqual(await exports.userService.getGroupMembers('g'),[member]);
 assert.deepEqual(calls[0],{name:'list_identified_group_members',args:{p_group:'g'}});
 await exports.userService.manageGroupMember(member,'handicap',0);
 assert.deepEqual(calls[1],{name:'manage_group_member',args:{p_group:'g',p_user:'fede',p_member_revision:2,p_player_revision:3,p_action:'handicap',p_handicap_18:0}});
 failure=true;await assert.rejects(exports.userService.getGroupMembers('g'),/server unavailable/);
});
