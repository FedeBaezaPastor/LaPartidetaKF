import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { PGlite } from "@electric-sql/pglite";

test("group messages: scoped managers, membership changes, exact deliveries and existing read-only protection", async () => {
  const db = new PGlite();
  const [A, O, M, U, V, G, H, EMPTY] = Array.from({ length: 8 }, () =>
    randomUUID(),
  );
  try {
    await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role BYPASSRLS;CREATE SCHEMA auth;
  CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,created_at timestamptz DEFAULT now(),encrypted_password text,raw_app_meta_data jsonb DEFAULT '{}',raw_user_meta_data jsonb DEFAULT '{}');
  CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql AS $$SELECT current_setting('request.jwt.claims',true)::jsonb$$;
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT (auth.jwt()->>'sub')::uuid$$;
  CREATE TABLE user_profiles(user_id uuid UNIQUE,nick text UNIQUE,display_name text,avatar_url text,exact_handicap numeric,default_tee text,accepted_terms boolean,updated_at timestamptz DEFAULT now());
  CREATE TABLE user_subscriptions(user_id uuid UNIQUE,plan_type text NOT NULL,status text,payment_hash text,current_period_start timestamptz,current_period_end timestamptz,updated_at timestamptz);
  CREATE TABLE groups(id uuid PRIMARY KEY,name text,group_code text,user_auth_id uuid REFERENCES auth.users(id));
  CREATE TABLE group_members(group_id uuid REFERENCES groups(id) ON DELETE CASCADE,user_id uuid REFERENCES auth.users(id),role text CHECK(role IN ('admin','member')),PRIMARY KEY(group_id,user_id));
  CREATE TABLE golf_rounds(id integer,score integer);INSERT INTO golf_rounds VALUES(1,42);
  INSERT INTO auth.users(id,email) VALUES('${A}','private-admin@example.test'),('${O}','owner@example.test'),('${M}','manager-private@example.test'),('${U}','user-private@example.test'),('${V}','outsider@example.test');
  INSERT INTO user_profiles(user_id,nick,display_name) VALUES('${O}','Owner','Owner'),('${M}','Manager','Manager'),('${U}','Player','Player');
  INSERT INTO groups VALUES('${G}','Golf Amigos','AMIGOS','${O}'),('${H}','Otro grupo','OTRO','${V}'),('${EMPTY}','Sin cuentas','EMPTY',NULL);
  INSERT INTO group_members VALUES('${G}','${O}','admin'),('${G}','${M}','admin'),('${G}','${U}','member'),('${H}','${V}','admin');
  GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
  GRANT ALL ON groups,group_members,golf_rounds,user_profiles,user_subscriptions TO anon,authenticated;
  ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
  CREATE FUNCTION is_group_admin(g uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id=g AND user_id=auth.uid() AND role='admin')$$;
  CREATE POLICY members_read ON group_members FOR SELECT USING(true);
  CREATE POLICY members_insert ON group_members FOR INSERT TO authenticated WITH CHECK(auth.uid()=user_id AND (role='member' OR EXISTS(SELECT 1 FROM groups g WHERE g.id=group_id AND g.user_auth_id=auth.uid())));
  CREATE POLICY members_update ON group_members FOR UPDATE TO authenticated USING(is_group_admin(group_id)) WITH CHECK(is_group_admin(group_id));
  CREATE POLICY members_delete ON group_members FOR DELETE TO authenticated USING(user_id=auth.uid() OR is_group_admin(group_id));`);
    const migrate = async (name) =>
      db.exec(
        await readFile(
          new URL(`../supabase/migrations/${name}.sql`, import.meta.url),
          "utf8",
        ),
      );
    await migrate("20260910190000_create_app_administration");
    await db.query("SELECT bootstrap_app_administrator($1,$2)", [A, "AdminF"]);
    await db.query(
      "UPDATE auth.users SET encrypted_password='set' WHERE id=$1",
      [A],
    );
    await migrate("20260911190000_app_user_management");
    await migrate("20260915190000_inapp_messages");
    await migrate("20260915210000_group_messages");
    const as = async (id, role = id ? "authenticated" : "anon") => {
      await db.exec("RESET ROLE");
      await db.query("SELECT set_config('request.jwt.claims',$1,false)", [
        JSON.stringify({ sub: id, role }),
      ]);
      await db.exec(`SET ROLE ${role}`);
    };
    const rpc = async (name, args = []) =>
      (
        await db.query(
          `SELECT ${name}(${args.map((_, i) => `$${i + 1}`).join(",")}) AS d`,
          args,
        )
      ).rows[0].d;
    const save = (targets, group = null, id = randomUUID(), revision = 0) =>
      rpc("save_message_v2", [
        id,
        "Aviso del grupo",
        "Primera línea\nSegunda línea",
        JSON.stringify(targets),
        revision,
        group,
      ]);
    const target = (kind, id) => ({ kind, id });
    await as(null);
    await assert.rejects(rpc("message_groups"), /permission denied/);
    await as(U);
    assert.deepEqual(await rpc("message_groups", ["", true]), []);
    await assert.rejects(save([target("group", G)], G), /permiso/);
    await assert.rejects(save([target("user", U)]), /denegado/);
    await assert.rejects(
      rpc("group_message_recipients", [G, "Player"]),
      /administras/,
    );
    await assert.rejects(
      db.query("UPDATE groups SET user_auth_id=$1 WHERE id=$2", [U, G]),
      /propietario/,
    );
    await assert.rejects(
      db.query("INSERT INTO groups VALUES($1,$2,$3,$4)", [
        randomUUID(),
        "Spoof",
        "SPOOF",
        O,
      ]),
      /propietario/,
    );
    await as(M);
    const managed = await rpc("message_groups", ["", true]);
    assert.equal(managed.length, 1);
    assert.equal(managed[0].id, G);
    const members = await rpc("group_message_recipients", [
      G,
      "user-private@example.test",
    ]);
    assert.equal(members[0].id, U);
    assert.equal(members[0].label, "Player");
    assert.deepEqual(
      await rpc("group_message_recipients", [G, "outsider@example.test"]),
      [],
    );
    await assert.rejects(save([target("group", H)], G), /tu grupo/);
    await assert.rejects(save([target("user", V)], G), /tu grupo/);
    await assert.rejects(save([target("group", G)], H), /permiso/);
    await assert.rejects(
      db.query(
        "UPDATE group_members SET user_id=$1 WHERE group_id=$2 AND user_id=$3",
        [V, G, M],
      ),
      /trasladar/,
    );
    await assert.rejects(
      db.query(
        "UPDATE group_members SET group_id=$1 WHERE group_id=$2 AND user_id=$3",
        [H, G, M],
      ),
      /trasladar/,
    );
    let draft = await save([target("group", G), target("user", U)], G);
    assert.equal(draft.recipients.length, 3);
    assert.equal(draft.recipient_selection.length, 2);
    assert.equal(draft.sender_label, "Grupo · Golf Amigos");
    assert.equal(draft.sender_kind, "group");
    assert.equal(JSON.stringify(draft).includes("@example.test"), false);
    assert.equal(
      (await save([target("group", G), target("user", U)], G, draft.id))
        .revision,
      1,
      "save retry",
    );
    await as(O);
    await assert.rejects(rpc("get_group_message", [draft.id]), /no disponible/);
    assert.equal(
      (await rpc("list_group_messages", [G])).total,
      0,
      "drafts remain private to the author",
    );
    await assert.rejects(
      save([target("group", G)], G, draft.id, 1),
      /modificar/,
    );
    await as(A);
    await assert.rejects(rpc("admin_send_message", [draft.id, 1]), /permiso/);
    await assert.rejects(
      save([target("user", U)], null, draft.id, 1),
      /modificar/,
    );
    await as(M);
    const sent = await rpc("send_message_v2", [draft.id, 1]);
    assert.equal(sent.sent_by, M);
    assert.equal(
      (await rpc("send_message_v2", [draft.id, 1])).sent_at,
      sent.sent_at,
    );
    await assert.rejects(
      save([target("group", G)], G, draft.id, 1),
      /no se puede modificar/,
    );
    await as(O);
    assert.equal(
      (await rpc("get_group_message", [draft.id])).deliveries.length,
      3,
    );
    await as(U);
    const inbox = await rpc("my_message_inbox");
    assert.equal(inbox.messages[0].sender_label, "Grupo · Golf Amigos");
    const opened = await rpc("my_message_open", [inbox.messages[0].id]);
    assert.equal(opened.sender_label, "Grupo · Golf Amigos");
    assert.equal(JSON.stringify(opened).includes("@example.test"), false);
    await as(V);
    assert.equal((await rpc("my_message_inbox")).total, 0);
    await assert.rejects(rpc("get_group_message", [draft.id]), /no disponible/);
    await as(A);
    const all = await rpc("message_groups", ["AMIGOS"]);
    assert.equal(all[0].member_count, 3);
    assert.equal(all[0].admin_count, 2);
    const admins = await save([target("group_admins", G)]);
    assert.equal(admins.recipients.length, 2);
    assert.equal(admins.sender_label, "Administración");
    await rpc("send_message_v2", [admins.id, 1]);
    const combined = await save([
      target("group", G),
      target("group", H),
      target("user", U),
    ]);
    assert.equal(combined.recipients.length, 4);
    await assert.rejects(
      save([target("group", EMPTY)]),
      /no tiene destinatarios/,
    );
    // Membership changes force a fresh review, even when the app admin is the sender.
    const changed = await save([target("group", G)]);
    await as(V);
    await db.query("INSERT INTO group_members VALUES($1,$2,'member')", [G, V]);
    await as(A);
    await assert.rejects(
      rpc("send_message_v2", [changed.id, 1]),
      /miembros.*cambiado/,
    );
    assert.equal(
      (await rpc("admin_get_message", [changed.id])).deliveries.length,
      0,
    );
    const revised = await save([target("group", G)], null, changed.id, 1);
    assert.equal(revised.recipients.length, 4);
    await rpc("send_message_v2", [changed.id, revised.revision]);
    await as(M);
    const departed = await save([target("user", V)], G);
    await as(V);
    await db.query(
      "DELETE FROM group_members WHERE group_id=$1 AND user_id=$2",
      [G, V],
    );
    await as(M);
    await assert.rejects(
      rpc("send_message_v2", [departed.id, 1]),
      /ya no pertenece/,
    );
    // Active sessions lose authority immediately when the group role is revoked.
    const revoked = await save([target("group", G)], G);
    await as(O);
    await db.query(
      "UPDATE group_members SET role='member' WHERE group_id=$1 AND user_id=$2",
      [G, M],
    );
    await as(M);
    await assert.rejects(rpc("send_message_v2", [revoked.id, 1]), /permiso/);
    await assert.rejects(
      rpc("get_group_message", [revoked.id]),
      /no disponible/,
    );
    await as(O);
    await db.query(
      "UPDATE group_members SET role='admin' WHERE group_id=$1 AND user_id=$2",
      [G, M],
    );
    // Real restrictions migration: can read, cannot publish or write business data.
    await as(A);
    await db.exec("RESET ROLE");
    await db.query(
      "INSERT INTO app_user_restrictions(user_id,read_only) VALUES($1,true)",
      [M],
    );
    await as(M);
    await assert.rejects(rpc("send_message_v2", [revoked.id, 1]), /permiso/);
    await assert.rejects(save([target("group", G)], G), /permiso/);
    const blockedInbox = await rpc("my_message_inbox");
    await rpc("my_message_open", [blockedInbox.messages[0].id]);
    assert.ok((await rpc("list_group_messages", [G])).total > 0);
    await assert.rejects(
      db.exec("UPDATE golf_rounds SET score=99"),
      /solo lectura/,
    );
    await as(A);
    await db.exec("RESET ROLE");
    await db.query(
      "UPDATE app_user_restrictions SET read_only=false WHERE user_id=$1",
      [M],
    );
    await as(M);
    await rpc("send_message_v2", [revoked.id, 1]);
    // Removing the group preserves delivered mail without granting it to a new group.
    await as(O);
    await db.query("DELETE FROM groups WHERE id=$1", [G]);
    await as(M);
    await assert.rejects(rpc("get_group_message", [draft.id]), /no disponible/);
    assert.ok((await rpc("my_message_inbox")).total > 0);
    await as(V);
    await db.query("INSERT INTO groups VALUES($1,$2,$3,$4)", [
      G,
      "Replacement",
      "NEW",
      V,
    ]);
    assert.equal((await rpc("list_group_messages", [G])).total, 0);
    await as(A);
    const history = await rpc("admin_get_message", [draft.id]);
    assert.equal(history.source_group_id, null);
    assert.equal(history.sender_kind, "group");
    assert.equal(history.sender_label, "Grupo · Golf Amigos");
    const audit = (
      await db.query(
        "SELECT * FROM list_app_admin_audit() WHERE action='group.message.sent'",
      )
    ).rows;
    assert.equal(audit.length, 2);
    assert.ok(audit.every((e) => e.actor_user_id === M));
    // The limit applies after expansion and deduplication, not to the number of groups.
    await db.exec("RESET ROLE");
    const hundred = Array.from({ length: 100 }, () => randomUUID());
    await db.query(
      "INSERT INTO auth.users(id,email) SELECT x::uuid,'bulk@example.test' FROM jsonb_array_elements_text($1::jsonb)x",
      [JSON.stringify(hundred)],
    );
    await db.query(
      "INSERT INTO group_members(group_id,user_id,role) SELECT $1,x::uuid,'member' FROM jsonb_array_elements_text($2::jsonb)x",
      [H, JSON.stringify(hundred)],
    );
    await as(A);
    await assert.rejects(save([target("group", H)]), /100 destinatarios/);
    await db.exec("RESET ROLE");
    await db.query(
      "DELETE FROM group_members WHERE group_id=$1 AND user_id=$2",
      [H, hundred[0]],
    );
    await as(A);
    const bulk = await save([target("group", H), target("user", V)]);
    assert.equal(bulk.recipients.length, 100);
    await rpc("send_message_v2", [bulk.id, 1]);
    assert.equal(
      (await rpc("admin_get_message", [bulk.id])).deliveries.length,
      100,
    );
    await as(V);
    const groupAdmins = await save([target("group_admins", H)], H);
    assert.equal(groupAdmins.recipients.length, 1);
    assert.equal(groupAdmins.recipients[0].id, V);
  } finally {
    await db.close();
  }
});
