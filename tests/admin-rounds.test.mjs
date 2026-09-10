import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";
const migration = await readFile(
  new URL(
    "../supabase/migrations/20260912190000_app_round_management.sql",
    import.meta.url,
  ),
  "utf8",
);
const A = "00000000-0000-4000-8000-000000000001",
  P = "00000000-0000-4000-8000-000000000002",
  R = "00000000-0000-4000-8000-000000000003",
  G = "00000000-0000-4000-8000-000000000004";
test("round administration: transitions, audit, permissions, preserved scores and Express slots", async () => {
  const db = new PGlite();
  try {
    await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('request.uid',true),'')::uuid$$;
 CREATE TABLE app_administrators(user_id uuid,alias text,status text);
 CREATE FUNCTION is_app_administrator() RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT EXISTS(SELECT 1 FROM public.app_administrators WHERE user_id=auth.uid() AND status='active')$$;
 CREATE TABLE app_admin_audit(id bigint GENERATED ALWAYS AS IDENTITY,actor_user_id uuid,actor_alias text,action text,details jsonb);
 CREATE TABLE golf_courses(id uuid PRIMARY KEY,name text);
 CREATE TABLE golf_rounds(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),reference_number integer,course_id uuid,user_id text,group_id uuid,game_mode text,num_holes integer,status text,completed_at timestamptz,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now());
 CREATE TABLE round_players(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),round_id uuid REFERENCES golf_rounds(id) ON DELETE CASCADE,name text,created_at timestamptz DEFAULT now());
 CREATE TABLE round_scores(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),round_id uuid REFERENCES golf_rounds(id) ON DELETE CASCADE,player_id uuid,hole_number integer,gross_strokes integer);
 INSERT INTO app_administrators VALUES('${A}','AdminF','active');
 INSERT INTO golf_rounds(id,reference_number,user_id,status,game_mode,num_holes) VALUES('${R}',1,'anon_device','active','stableford',9);
 INSERT INTO golf_rounds(id,reference_number,user_id,status,group_id) VALUES('${G}',2,'anon_device','active','${G}');
 INSERT INTO golf_rounds(reference_number,user_id,status) SELECT i,'anon_device','deleted' FROM generate_series(3,5)i;
 INSERT INTO round_players(round_id,name) VALUES('${R}','Jugador');
 INSERT INTO round_scores(round_id,player_id,hole_number,gross_strokes) SELECT '${R}',id,1,4 FROM round_players;
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
 GRANT SELECT,INSERT,UPDATE,DELETE ON golf_rounds,round_players,round_scores TO authenticated,anon;`);
    await db.exec(migration);
    const as = async (id) => {
      await db.exec("RESET ROLE");
      await db.query("SELECT set_config('request.uid',$1,false)", [id || ""]);
      await db.exec(`SET ROLE ${id ? "authenticated" : "anon"}`);
    };
    const detail = async (id) =>
      (await db.query("SELECT admin_get_app_round($1) AS d", [id])).rows[0].d;
    const change = async (action, expected) => {
      const d = await detail(R);
      return (
        await db.query("SELECT admin_change_app_round($1,$2,$3,$4) AS d", [
          R,
          action,
          "Prueba administrativa",
          expected || d.round.updated_at,
        ])
      ).rows[0].d;
    };
    const count = async () =>
      (
        await db.query(
          "SELECT count_available_quick_rounds('anon_device') AS n",
        )
      ).rows[0].n;
    await as(P);
    await assert.rejects(detail(R), /denegado/);
    await assert.rejects(db.exec("SELECT admin_list_app_rounds()"), /denegado/);
    await assert.rejects(
      db.query("SELECT admin_change_app_round($1,$2,$3,$4)", [
        R,
        "withdraw",
        "Prueba",
        new Date(),
      ]),
      /denegado/,
    );
    await as(A);
    assert.equal(Number(await count()), 4);
    const original = await detail(R);
    let d = await change("complete");
    assert.equal(d.round.status, "completed");
    assert.ok(d.round.completed_at);
    assert.equal(d.scores[0].gross_strokes, 4);
    await assert.rejects(
      change("reopen", original.round.updated_at),
      /ha cambiado/,
    );
    d = await change("reopen");
    assert.equal(d.round.status, "active");
    assert.equal(d.round.completed_at, null);
    d = await change("withdraw");
    assert.equal(d.round.status, "deleted");
    assert.equal(d.round.admin_previous_status, "active");
    assert.equal(Number(await count()), 3);
    await as(P);
    await assert.rejects(
      db.query("UPDATE golf_rounds SET admin_withdrawn_at=NULL WHERE id=$1", [
        R,
      ]),
      /administración/,
    );
    await assert.rejects(
      db.query("UPDATE golf_rounds SET status='active' WHERE id=$1", [R]),
      /administración/,
    );
    await assert.rejects(
      db.query("UPDATE round_scores SET gross_strokes=9 WHERE round_id=$1", [
        R,
      ]),
      /administración/,
    );
    await assert.rejects(
      db.query("DELETE FROM round_players WHERE round_id=$1", [R]),
      /administración/,
    );
    await assert.rejects(
      db.query(
        "INSERT INTO golf_rounds(user_id,status,admin_withdrawn_at) VALUES('anon_device','active',now())",
      ),
      /denegado/,
    );
    await db.query(
      "INSERT INTO golf_rounds(reference_number,user_id,status) VALUES(6,'anon_device','active')",
    );
    await as(A);
    await assert.rejects(change("restore"), /otra partida/);
    await db.exec(
      "UPDATE golf_rounds SET status='completed' WHERE reference_number=6",
    );
    d = await change("restore");
    assert.equal(d.round.status, "active");
    assert.equal(d.round.admin_withdrawn_at, null);
    assert.equal(Number(await count()), 5);
    assert.deepEqual(d.scores, original.scores);
    assert.deepEqual(d.players, original.players);
    const g = await detail(G);
    await assert.rejects(
      db.query("SELECT admin_change_app_round($1,$2,$3,$4)", [
        G,
        "complete",
        "Prueba",
        g.round.updated_at,
      ]),
      /grupo/,
    );
    await assert.rejects(change("restore"), /no permitida/);
    await change("withdraw");
    const withdrawn = (
      await db.query("SELECT admin_list_app_rounds('', 'withdrawn') AS d")
    ).rows[0].d;
    assert.equal(withdrawn.total, 1);
    const groups = (
      await db.query("SELECT admin_list_app_rounds('', '', 'group') AS d")
    ).rows[0].d;
    assert.equal(groups.total, 1);
    await as(null);
    assert.equal(Number(await count()), 4);
    // Preserve the existing Express hard reset: a parent deletion cascades normally.
    await db.query("DELETE FROM golf_rounds WHERE id=$1", [R]);
    await db.exec("RESET ROLE");
    const logs = (await db.query("SELECT * FROM app_admin_audit")).rows;
    assert.equal(logs.length, 5);
    assert.ok(
      logs.every(
        (l) =>
          l.actor_user_id === A && l.details.round_id === R && l.details.reason,
      ),
    );
  } finally {
    await db.close();
  }
});
