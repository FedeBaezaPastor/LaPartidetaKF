import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';
import ts from 'typescript';
import { createGroupDatabase } from './helpers/group-database.mjs';

async function setup(withBeer=true) {
 const db = new PGlite();
 await createGroupDatabase(db);
 const [owner, member, outsider, group, otherGroup] = Array.from({length:5}, randomUUID);
 await db.query('INSERT INTO auth.users VALUES($1),($2),($3)', [owner, member, outsider]);
 await db.query("INSERT INTO user_profiles(user_id,nick,exact_handicap) VALUES($1,'Owner',18),($2,'Alex',18)", [owner,member]);
 await db.query('INSERT INTO groups VALUES($1,$2),($3,$2)', [group,owner,otherGroup]);
 await db.query("INSERT INTO group_members(group_id,user_id,role) VALUES($1,$2,'member')", [group,member]);
 await db.exec('GRANT USAGE ON SCHEMA public,auth TO anon,authenticated; GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO anon,authenticated;');
 // Exercise real award and beer function bodies, not replicas of the new SQL.
 await db.exec(`CREATE TABLE beer_stats(round_id uuid,player_id uuid,status text,position int); GRANT SELECT,INSERT,DELETE ON beer_stats TO authenticated;`);
 for (const file of ['20260103144321_fix_beer_stats_player_id_reference.sql','20260703215241_20260703_restore_missing_ranking_functions.sql']) {
  if (withBeer || !file.includes('beer_stats')) await db.exec(await readFile(new URL(`../supabase/migrations/${file}`,import.meta.url),'utf8'));
 }
 for (const file of ['20260917100000_group_member_players.sql','20260918100000_group_guest_players.sql']) {
  await db.exec(await readFile(new URL(`../supabase/migrations/${file}`,import.meta.url),'utf8'));
 }
 const as = async id => {
  await db.exec('RESET ROLE');
  await db.query("SELECT set_config('request.uid',$1,false)",[id || '']);
  await db.exec(`SET ROLE ${id ? 'authenticated' : 'anon'}`);
 };
 const round = async (mode='stableford', holes=18) => {
  const id=randomUUID();
  await db.query("INSERT INTO golf_rounds(id,group_id,num_holes,use_slope,status,game_mode) VALUES($1,$2,$3,false,'active',$4)",[id,group,holes,mode]);
  return id;
 };
 const add = async (id,name='Visitor',guest=true,player=null,hcp=9) => (await db.query('SELECT * FROM add_group_round_player($1,$2,$3,$4,$5,$6)',[group,id,name,hcp,guest,player])).rows[0];
 const archive = async (id,participants) => {
  await db.query("UPDATE golf_rounds SET status='completed' WHERE id=$1",[id]);
  const ranking=participants.map((p,i)=>({position:i+1,player_id:p.id,player_db_id:p.player_id,player_name:p.name,points:999,is_guest:false,hcp_juego:p.playing_handicap}));
  const stats=participants.map(p=>({player_id:p.id,player_name:p.name,is_guest:false,spanish_hands_count:99,total_holes_played:1,no_paso_rojas_count:1,beers_won:1,beers_paid:1}));
  const holes=participants.map(p=>({player_id:p.id,player_name:p.name,is_guest:false,hole_number:1,gross_strokes:4,net_strokes:4,stableford_points:2,par:4}));
  return (await db.query("INSERT INTO archived_rounds(group_id,course_name,played_at,source_round_id,final_ranking,player_stats,hole_scores) VALUES($1,'Test',now(),$2,$3,$4,$5) RETURNING *",[group,id,JSON.stringify(ranking),JSON.stringify(stats),JSON.stringify(holes)])).rows[0];
 };
 return {db,owner,member,outsider,group,otherGroup,as,round,add,archive};
}

test('guest snapshots preserve history, exclude guests from group results, and survive promotion', async()=>{
 const ctx=await setup();const {db,owner,member,group,as,round,add,archive}=ctx;
 try {
  await as(member);
  const roster=(await db.query('SELECT list_group_game_players($1) value',[group])).rows.map(r=>r.value);
  const alex=roster.find(p=>p.auth_user_id===member);
  assert.equal(alex.can_manage,false);
  const id=await round();
  const visitor=await add(id,'Alex');
  const registered=await add(id,'Alex',false,alex.id);
  assert.equal(visitor.is_guest,true);assert.notEqual(visitor.player_id,registered.player_id);
  assert.equal(visitor.user_id,null);assert.equal(Number(visitor.playing_handicap),18);
  await assert.rejects(db.query('UPDATE round_players SET is_guest=false WHERE id=$1',[visitor.id]),/inmutables/);
  await assert.rejects(db.query('UPDATE players SET is_guest=false WHERE id=$1',[visitor.player_id]),/permiso/);
  await db.query('INSERT INTO round_scores(round_id,player_id,stableford_points,spanish_hands) VALUES($1,$2,50,true),($1,$3,20,false)',[id,visitor.id,registered.id]);
  const saved=await archive(id,[visitor,registered]);
  assert.equal(saved.final_ranking.length,2);assert.equal(saved.final_ranking[0].is_guest,true);
  assert.equal(Number(saved.final_ranking[0].points),50,'rank must use trusted scores');
  assert.equal(saved.player_stats[0].is_guest,true);assert.equal(saved.hole_scores[0].is_guest,true);
  const filtered=(await db.query('SELECT * FROM group_statistics_rounds WHERE id=$1',[saved.id])).rows[0];
  assert.equal(filtered.final_ranking.length,1);assert.equal(filtered.final_ranking[0].position,1);
  assert.equal(filtered.final_ranking[0].player_id,registered.player_id);
  assert.equal(filtered.player_stats[0].beers_won,0);assert.equal(filtered.player_stats[0].beers_paid,0);
  assert.equal(filtered.hole_scores.length,1);
  const killer=(await db.query('SELECT * FROM get_killer_ranking($1)',[group])).rows[0];
  assert.equal(killer.player_id,registered.player_id);assert.equal(killer.best_score,20);
  const shark=(await db.query('SELECT * FROM get_shark_ranking($1)',[group])).rows;
  assert.equal(shark.length,1);assert.equal(shark[0].player_id,registered.player_id);
  await db.query('SELECT calculate_beer_stats_for_round($1)',[id]);
  const beers=(await db.query('SELECT * FROM beer_stats WHERE round_id=$1',[id])).rows;
  assert.equal(beers.length,1);assert.equal(beers[0].player_id,registered.player_id);assert.equal(beers[0].status,'neutral');
  const daily=(await db.query('SELECT * FROM daily_rankings')).rows;
  assert.equal(daily.length,1);assert.equal(daily[0].game_player_id,registered.player_id);
  assert.equal(daily[0].receives_beer,false);assert.equal(daily[0].pays_beer,false);
  assert.equal(Number((await db.query('SELECT exact_handicap FROM players WHERE id=$1',[visitor.player_id])).rows[0].exact_handicap),9);
  assert.equal((await db.query('SELECT * FROM handicap_adjustments WHERE player_id=$1',[visitor.player_id])).rows.length,0);
  await assert.rejects(db.query("UPDATE archived_rounds SET final_ranking='[]' WHERE id=$1",[saved.id]),/inmutables/);
  // Non-managers cannot promote the record, through the RPC or direct REST.
  const next=await round();await assert.rejects(add(next,'Alex',false,visitor.player_id),/permiso/);
  await as(owner);
  const promoted=await add(next,'Alex',false,visitor.player_id,8);
  assert.equal(promoted.is_guest,false);
  assert.equal((await db.query('SELECT is_guest FROM round_players WHERE id=$1',[visitor.id])).rows[0].is_guest,true);
  assert.equal((await db.query('SELECT * FROM group_statistics_rounds WHERE id=$1',[saved.id])).rows[0].final_ranking.length,1);
  // Subsequent member participation counts; the old guest round remains excluded.
  await db.query('INSERT INTO round_scores(round_id,player_id,stableford_points) VALUES($1,$2,10)',[next,promoted.id]);
  const later=await archive(next,[promoted]);
  assert.equal((await db.query('SELECT * FROM group_statistics_rounds WHERE id=$1',[later.id])).rows[0].final_ranking[0].player_id,visitor.player_id);
  await db.exec('RESET ROLE');
  assert.equal(Number((await db.query('SELECT count(*) n FROM group_write_permits')).rows[0].n),0);
 } finally {await db.close();}
});

test('guest operations enforce group scope, permissions, limits, and all-guest rounds stay out of statistics',async()=>{
 const {db,owner,member,outsider,group,otherGroup,as,round,add,archive}=await setup(false);
 try {
  await as(outsider);const id=await round();await assert.rejects(add(id),/permiso/);
  await as(null);await assert.rejects(add(id),/permission denied/);
  await as(member);
  await assert.rejects(add(id,'Member',false),/administrar/);
  await assert.rejects(db.query("INSERT INTO players(group_id,name,is_guest) VALUES($1,'Forged member',false)",[group]),/administrar/);
  await assert.rejects(add(id,'Invalid',true,null,28),/válido/);
  await assert.rejects(db.query('SELECT add_group_round_player($1,$2,$3,$4,$5)',[otherGroup,id,'Cross',9,true]),/permiso/);
  await db.query('INSERT INTO app_user_restrictions VALUES($1,true)',[member]);await assert.rejects(add(id),/permiso/);
  await db.query('DELETE FROM app_user_restrictions WHERE user_id=$1',[member]);
  const one=await add(id);
  await as(outsider);
  await assert.rejects(db.query('UPDATE players SET exact_handicap=0 WHERE id=$1',[one.player_id]),/permiso/);
  await assert.rejects(db.query('DELETE FROM players WHERE id=$1',[one.player_id]),/administrar/);
  await assert.rejects(db.query('UPDATE round_players SET name=$1 WHERE id=$2',['Forged',one.id]),/permiso/);
  await assert.rejects(db.query('DELETE FROM round_players WHERE id=$1',[one.id]),/permiso/);
  await as(member);
  await assert.rejects(add(id,'Visitor',true,one.player_id),/ya está/);
  const another=await round();await assert.rejects(add(another,'Visitor',true,one.player_id),/otra partida/);
  await assert.rejects(db.query('INSERT INTO round_players(round_id,player_id) VALUES($1,$2)',[another,one.player_id]),/otra partida/);
  const saved=await archive(id,[one]);
  assert.equal(saved.final_ranking.length,1);
  await assert.rejects(db.query('DELETE FROM archived_rounds WHERE id=$1',[saved.id]),/administrar/);
  assert.equal((await db.query('SELECT * FROM group_statistics_rounds WHERE id=$1',[saved.id])).rows.length,0);
  assert.equal((await db.query('SELECT * FROM daily_rankings')).rows.length,0);
  assert.equal((await db.query('SELECT handicap_adjusted FROM archived_rounds WHERE id=$1',[saved.id])).rows[0].handicap_adjusted,true);
  // Direct REST inserts cannot override guest identity or handicap snapshots.
  await db.query('INSERT INTO round_players(round_id,player_id,name,exact_handicap,playing_handicap,is_guest) VALUES($1,$2,$3,0,0,false)',[another,one.player_id,'Forged']);
  const direct=(await db.query('SELECT * FROM round_players WHERE round_id=$1',[another])).rows[0];
  assert.equal(direct.is_guest,true);assert.equal(direct.name,'Visitor');assert.equal(Number(direct.exact_handicap),9);
  await db.query('DELETE FROM round_players WHERE id=$1',[direct.id]);
  // Reuse preserves the reusable guest UUID and adapts its 9-hole snapshot.
  const reused=await add(another,'Visitor',true,null,7);assert.equal(reused.player_id,one.player_id);
  const match=await round('match',9);
  const a=await add(match,'A'),b=await add(match,'B');assert.equal(Number(a.playing_handicap),9);
  await assert.rejects(add(match,'C'),/más jugadores/);
  await assert.rejects(db.query("INSERT INTO archived_rounds(group_id,final_ranking) VALUES($1,$2)",[group,JSON.stringify([{player_name:'Import',is_guest:false}])]),/origen/);
  await as(owner);
  const ownRound=await round();
  const ownPlayer=await add(ownRound,'Counted member',false);
  await archive(ownRound,[ownPlayer]);
  const otherPlayer=(await db.query("INSERT INTO players(group_id,name,is_guest,exact_handicap) VALUES($1,'Elsewhere',true,5) RETURNING id",[otherGroup])).rows[0].id;
  const cross=await round();await assert.rejects(add(cross,'Elsewhere',true,otherPlayer),/disponible/);
  // The view must respect the archive RLS policies of its caller.
  await db.exec('RESET ROLE');
  await db.exec('ALTER TABLE archived_rounds ENABLE ROW LEVEL SECURITY; CREATE POLICY read_group_archives ON archived_rounds FOR SELECT TO authenticated USING(is_group_member(group_id) OR can_manage_group_messages(group_id));');
  await as(owner);assert.equal((await db.query('SELECT * FROM group_statistics_rounds')).rows.length,1);
  await as(outsider);assert.equal((await db.query('SELECT * FROM group_statistics_rounds')).rows.length,0);
  assert.equal(b.is_guest,true);
 } finally {await db.close();}
});

test('group player addition uses the atomic RPC and statistical reads use the member projection',async()=>{
 const source=await readFile(new URL('../src/services/golfService.ts',import.meta.url),'utf8');
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={},calls=[];let failure=false;
 const result={id:'participation',is_guest:true};
 const query={select(){return this;},order(){return this;},eq(){return this;},then(resolve){return Promise.resolve({data:[result]}).then(resolve);}};
 const mock={rpc:async(name,args)=>{calls.push({name,args});return failure?{error:new Error('unavailable')}:{data:result};},from:table=>{calls.push(table);return query;}};
 new Function('require','exports',js)(name=>name.includes('supabaseClient')?{supabase:mock}:{},exports);
 assert.deepEqual(await exports.golfService.addGroupRoundPlayer('g','r','Visitor',7,true),result);
 assert.deepEqual(calls[0],{name:'add_group_round_player',args:{p_group:'g',p_round:'r',p_name:'Visitor',p_handicap:7,p_is_guest:true,p_player:null}});
 await exports.golfService.getStatisticsRounds('g');assert.equal(calls[1],'group_statistics_rounds');
 await exports.golfService.getArchivedRounds('g');assert.equal(calls[2],'archived_rounds');
 failure=true;await assert.rejects(exports.golfService.addGroupRoundPlayer('g','r','Visitor',7,true),/unavailable/);
});

test('a day with only guests archives its rounds without member handicap writes',async()=>{
 const source=await readFile(new URL('../src/services/golfService.ts',import.meta.url),'utf8');
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={},tables=[],archived=[];
 const query={select(){return this;},eq(){return this;},gte(){return this;},lte(){return this;},then(resolve){return Promise.resolve({data:[{id:'guest-round'}]}).then(resolve);}};
 const mock={from:table=>{tables.push(table);return query;}};
 new Function('require','exports',js)(name=>name.includes('supabaseClient')?{supabase:mock}:name.includes('storage')?{storageUtils:{getCurrentGroupId:()=> 'group'}}:{},exports);
 exports.golfService.getDailyRankings=async()=>[{date:'2026-09-16',standings:[]}];
 exports.golfService.archiveRound=async id=>{archived.push(id);};
 await exports.golfService.updateHandicapsFromLastRanking();
 assert.deepEqual(archived,['guest-round']);assert.deepEqual(tables,['golf_rounds']);
});
