import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import ts from 'typescript';
import {PGlite} from '@electric-sql/pglite';

test('pending invitations do not depend on an Auth-to-profile REST relationship',async()=>{
 const source=await readFile(new URL('../src/services/userService.ts',import.meta.url),'utf8');
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={},calls=[];
 let failedProfiles=false,failedInvitations=false;
 const invitations=[{id:'invite',invited_by:'owner',invited_user_id:'player',status:'pending',group:{name:'La Partideta'}}];
 const client={from:table=>{calls.push(table);return {select:selection=>{
  assert.ok(!selection.includes('user_profiles!invited_by'));
  if(table==='user_profiles')return {in:async(key,ids)=>{assert.equal(key,'user_id');assert.deepEqual(ids,['owner']);return failedProfiles?{error:new Error('profile unavailable')}:{data:[{user_id:'owner',nick:'Creator'}]};}};
  const query={eq:(key,value)=>{if(key==='invited_user_id')assert.equal(value,'player');return query;},order:async()=>failedInvitations?{error:new Error('invitation lookup failed')}:{data:invitations}};return query;
 }};},rpc:async(name,args)=>{calls.push({name,args});return {};}};
 new Function('require','exports',js)(name=>name.includes('supabaseClient')?{supabase:client}:{},exports);
 const service=exports.userService;
 assert.equal((await service.getPendingInvitations('player'))[0].inviter_profile.nick,'Creator');
 failedProfiles=true;assert.equal((await service.getPendingInvitations('player'))[0].id,'invite');
 failedInvitations=true;await assert.rejects(service.getPendingInvitations('player'),/lookup failed/);
 await service.respondToInvitation('invite','accepted');
 assert.deepEqual(calls.at(-1),{name:'respond_to_group_invitation',args:{p_invitation:'invite',p_status:'accepted'}});
});

test('invitation response creates membership atomically, preserves roles, rejects outsiders and respects blocking',async()=>{
 const db=new PGlite();const [U,O,G,I,J,K,L]=Array.from({length:7},()=>randomUUID());
 try{
  await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
   CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('request.uid',true),'')::uuid$$;
   CREATE TABLE app_user_restrictions(user_id uuid PRIMARY KEY,read_only boolean);
   CREATE FUNCTION is_app_user_read_only() RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT coalesce((SELECT read_only FROM public.app_user_restrictions WHERE user_id=auth.uid()),false)$$;
   CREATE TABLE group_members(group_id uuid,user_id uuid,role text,invited_by uuid,PRIMARY KEY(group_id,user_id));
   CREATE TABLE group_invitations(id uuid PRIMARY KEY,group_id uuid,invited_user_id uuid,invited_by uuid,status text,responded_at timestamptz);
   INSERT INTO group_invitations VALUES('${I}','${G}','${U}','${O}','pending',NULL),('${J}','${J}','${U}','${O}','pending',NULL),('${K}','${K}','${U}','${O}','pending',NULL),('${L}','${L}','${U}','${O}','pending',NULL);
   INSERT INTO group_members VALUES('${K}','${U}','admin','${O}');
   CREATE FUNCTION fail_membership() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.group_id='${L}'::uuid THEN RAISE EXCEPTION 'membership failure'; END IF; RETURN NEW; END$$;
   CREATE TRIGGER test_failure BEFORE INSERT ON group_members FOR EACH ROW EXECUTE FUNCTION fail_membership();
   GRANT USAGE ON SCHEMA public,auth TO anon,authenticated;`);
  await db.exec(await readFile(new URL('../supabase/migrations/20260916100000_atomic_group_invitation_response.sql',import.meta.url),'utf8'));
  const as=async(id)=>{await db.exec('RESET ROLE');await db.query("SELECT set_config('request.uid',$1,false)",[id||'']);await db.exec(`SET ROLE ${id?'authenticated':'anon'}`);};
  const respond=(id,status='accepted')=>db.query('SELECT respond_to_group_invitation($1,$2)',[id,status]);
  const state=async(id)=>{await db.exec('RESET ROLE');return (await db.query('SELECT * FROM group_invitations WHERE id=$1',[id])).rows[0];};
  await as(null);await assert.rejects(respond(I),/permission denied/);
  await as(O);await assert.rejects(respond(I),/no disponible/);
  await as(U);await assert.rejects(respond(I,'pending'),/no válida/);
  await respond(I);const first=await state(I);assert.equal(first.status,'accepted');assert.ok(first.responded_at);
  const membership=(await db.query('SELECT * FROM group_members WHERE group_id=$1',[G])).rows[0];assert.equal(membership.user_id,U);assert.equal(membership.invited_by,O);assert.equal(membership.role,'member');
  await as(U);await respond(I);assert.deepEqual((await state(I)).responded_at,first.responded_at);
  await as(U);await assert.rejects(respond(I,'rejected'),/otra respuesta/);
  await respond(J,'rejected');assert.equal((await state(J)).status,'rejected');assert.equal((await db.query('SELECT * FROM group_members WHERE group_id=$1',[J])).rows.length,0);
  await as(U);await respond(K);await state(K);assert.equal((await db.query('SELECT role FROM group_members WHERE group_id=$1',[K])).rows[0].role,'admin');
  await as(U);await assert.rejects(respond(L),/membership failure/);assert.equal((await state(L)).status,'pending');
  await db.query('INSERT INTO app_user_restrictions VALUES($1,true)',[U]);
  await as(U);await assert.rejects(respond(L),/permiso/);assert.equal((await state(L)).status,'pending');
 }finally{await db.close();}
});
