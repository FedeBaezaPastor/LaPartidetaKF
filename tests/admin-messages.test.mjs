import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { PGlite } from "@electric-sql/pglite";

test("messages: transactional publishing, authorization, private Express boxes and read-only accounts", async () => {
  const db = new PGlite();
  const A = randomUUID(),
    B = randomUUID(),
    U = randomUUID(),
    V = randomUUID(),
    W = randomUUID();
  try {
    await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role; CREATE SCHEMA auth;
   CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('request.uid',true),'')::uuid$$;
   CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,raw_app_meta_data jsonb DEFAULT '{}');
   CREATE TABLE user_profiles(user_id uuid PRIMARY KEY,nick text,display_name text);
   CREATE TABLE groups(id uuid PRIMARY KEY,name text,group_code text,user_auth_id uuid);
   CREATE TABLE group_members(group_id uuid,user_id uuid,role text);
   CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
   CREATE FUNCTION is_app_user_read_only() RETURNS boolean LANGUAGE sql AS $$SELECT auth.uid()='${U}'::uuid$$;
   CREATE TABLE app_administrators(user_id uuid PRIMARY KEY,alias text,status text);
   CREATE FUNCTION is_app_administrator() RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT EXISTS(SELECT 1 FROM public.app_administrators WHERE user_id=auth.uid() AND status='active')$$;
   CREATE TABLE app_admin_audit(id bigint GENERATED ALWAYS AS IDENTITY,actor_user_id uuid,actor_alias text,action text,details jsonb);
   INSERT INTO auth.users(id,email) VALUES('${A}','private-admin@example.test'),('${B}','disabled@example.test'),('${U}','player@example.test'),('${V}','other@example.test'),('${W}','pending@example.test');
   INSERT INTO user_profiles(user_id,nick) VALUES('${U}','PlayerNick');
   INSERT INTO app_administrators VALUES('${A}','AdminF','active'),('${B}','AdminK','disabled');
   CREATE TABLE business_scores(score integer);
   CREATE FUNCTION business_guard() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF auth.uid()='${U}'::uuid THEN RAISE EXCEPTION 'Solo lectura'; END IF; RETURN NEW; END$$;
   CREATE TRIGGER blocked BEFORE INSERT OR UPDATE OR DELETE ON business_scores FOR EACH STATEMENT EXECUTE FUNCTION business_guard();
   GRANT USAGE ON SCHEMA public,auth TO authenticated,anon,service_role;
   GRANT SELECT,INSERT,UPDATE,DELETE ON business_scores TO authenticated;`);
    await db.exec(
      await readFile(
        new URL(
          "../supabase/migrations/20260915190000_inapp_messages.sql",
          import.meta.url,
        ),
        "utf8",
      ),
    );
    await db.exec(
      await readFile(
        new URL(
          "../supabase/migrations/20260915210000_group_messages.sql",
          import.meta.url,
        ),
        "utf8",
      ),
    );
    const as = async (id, role = id ? "authenticated" : "anon") => {
      await db.exec("RESET ROLE");
      await db.query("SELECT set_config('request.uid',$1,false)", [id || ""]);
      await db.exec(`SET ROLE ${role}`);
    };
    const rpc = async (
      name,
      args = [],
      placeholders = args.map((_, i) => `$${i + 1}`).join(","),
    ) =>
      (await db.query(`SELECT ${name}(${placeholders}) AS d`, args)).rows[0].d;
    const save = (
      id,
      recipients,
      revision = 0,
      title = "Aviso",
      body = "Primera línea\nSegunda línea",
    ) =>
      rpc("admin_save_message", [
        id,
        title,
        body,
        JSON.stringify(recipients),
        revision,
      ]);
    const user = (id) => ({ kind: "user", id });
    for (const id of [null, U, B]) {
      await as(id);
      await assert.rejects(
        rpc("admin_list_messages"),
        /denegado|permission denied/,
      );
      await assert.rejects(
        save(randomUUID(), [user(U)]),
        /denegado|permission denied/,
      );
      await assert.rejects(
        rpc("admin_send_message", [randomUUID(), 1]),
        /denegado|permission denied/,
      );
      await assert.rejects(
        rpc("admin_message_recipients", ["player"]),
        /denegado|permission denied/,
      );
      await assert.rejects(
        rpc("register_message_box", ["a".repeat(64)]),
        /permission denied/,
      );
      await assert.rejects(
        rpc("message_inbox", ["user", U, 0]),
        /permission denied/,
      );
      await assert.rejects(
        db.exec("SELECT * FROM app_messages"),
        /permission denied/,
      );
      await assert.rejects(
        db.exec("UPDATE app_message_deliveries SET read_at=now()"),
        /permission denied/,
      );
    }
    await as(null, "service_role");
    const box = await rpc("register_message_box", ["a".repeat(64)]);
    assert.equal(await rpc("register_message_box", ["a".repeat(64)]), box);
    const otherBox = await rpc("register_message_box", ["b".repeat(64)]);
    await assert.rejects(
      rpc("express_message_request", [box, "b".repeat(64)]),
      /Buzón no disponible/,
    );
    await as(A);
    for (const search of ["player@example.test", "PlayerNick", U])
      assert.equal((await rpc("admin_message_recipients", [search]))[0].id, U);
    assert.equal(
      (await rpc("admin_message_recipients", [W]))[0].id,
      W,
      "incomplete profiles are valid accounts",
    );
    assert.equal(
      (await rpc("admin_message_recipients", [box]))[0].kind,
      "express",
    );
    assert.deepEqual(await rpc("admin_message_recipients", [A]), []);
    assert.deepEqual(await rpc("admin_message_recipients", [B]), []);
    const id = randomUUID(),
      targets = [user(U), { kind: "express", id: box }, user(U)];
    let draft = await save(id, targets);
    assert.equal(draft.recipients.length, 2);
    assert.equal(draft.status, "draft");
    assert.equal((await rpc("admin_get_message", [id])).deliveries.length, 0);
    assert.equal(
      (await save(id, targets)).revision,
      1,
      "lost save response can be retried",
    );
    await assert.rejects(
      save(id, targets, 0, "Changed"),
      /borrador ha cambiado/,
    );
    for (const [title, body] of [
      ["", "text"],
      ["a".repeat(121), "text"],
      ["Ok", "x".repeat(4001)],
      ["Ok", " ".repeat(4001) + "x"],
    ])
      await assert.rejects(
        save(randomUUID(), targets, 0, title, body),
        /Revisa/,
      );
    await assert.rejects(save(randomUUID(), []), /entre 1 y 100/);
    await assert.rejects(
      save(randomUUID(), Array(101).fill(user(U))),
      /entre 1 y 100/,
    );
    await assert.rejects(save(randomUUID(), [user(A)]), /destinatario/);
    await assert.rejects(
      rpc("admin_send_message", [id, 99]),
      /borrador ha cambiado/,
    );
    draft = await rpc("admin_send_message", [id, 1]);
    assert.equal(draft.sent_by, A);
    assert.equal(draft.sent_by_alias, "AdminF");
    assert.equal(
      (await rpc("admin_send_message", [id, 1])).sent_at,
      draft.sent_at,
    );
    await assert.rejects(save(id, targets, 1), /no se puede modificar/);
    assert.equal((await rpc("admin_get_message", [id])).deliveries.length, 2);
    await db.exec("RESET ROLE");
    assert.equal(
      Number(
        (
          await db.query(
            "SELECT count(*) n FROM app_admin_audit WHERE action='message.sent'",
          )
        ).rows[0].n,
      ),
      1,
    );
    await db.query("UPDATE user_profiles SET nick='NewNick' WHERE user_id=$1", [
      U,
    ]);
    await as(U);
    let inbox = await rpc("my_message_inbox");
    assert.equal(inbox.unread, 1);
    assert.equal(inbox.total, 1);
    assert.equal(inbox.messages[0].body, undefined);
    const delivery = inbox.messages[0].id;
    const opened = await rpc("my_message_open", [delivery]);
    assert.equal(opened.body, "Primera línea\nSegunda línea");
    assert.equal(
      (await rpc("my_message_open", [delivery])).read_at,
      opened.read_at,
    );
    assert.equal(JSON.stringify(opened).includes("private-admin"), false);
    assert.equal((await rpc("my_message_inbox")).unread, 0);
    assert.equal((await rpc("my_message_inbox")).total, 1);
    await assert.rejects(
      db.exec("INSERT INTO business_scores VALUES(4)"),
      /Solo lectura/,
    );
    await as(V);
    assert.equal((await rpc("my_message_inbox")).total, 0);
    await assert.rejects(
      rpc("my_message_open", [delivery]),
      /Mensaje no encontrado/,
    );
    await as(null);
    await assert.rejects(rpc("my_message_inbox"), /permission denied/);
    await assert.rejects(
      rpc("express_message_request", [box, "a".repeat(64)]),
      /permission denied/,
    );
    await as(null, "service_role");
    inbox = await rpc("express_message_request", [box, "a".repeat(64)]);
    assert.equal(inbox.unread, 1);
    await assert.rejects(
      rpc("express_message_request", [
        otherBox,
        "b".repeat(64),
        inbox.messages[0].id,
      ]),
      /Mensaje no encontrado/,
    );
    await rpc("express_message_request", [
      box,
      "a".repeat(64),
      inbox.messages[0].id,
    ]);
    assert.equal(
      (await rpc("express_message_request", [box, "a".repeat(64)])).unread,
      0,
    );
    await as(A);
    assert.equal(
      (await rpc("admin_get_message", [id])).deliveries.filter((d) => d.read_at)
        .length,
      2,
    );
    assert.equal((await rpc("admin_message_recipients", ["NewNick"]))[0].id, U);
    const invalid = randomUUID();
    await save(invalid, [user(U), user(W)]);
    await db.exec("RESET ROLE");
    await db.query("DELETE FROM auth.users WHERE id=$1", [W]);
    await as(A);
    await assert.rejects(
      rpc("admin_send_message", [invalid, 1]),
      /destinatario/,
    );
    const failed = await rpc("admin_get_message", [invalid]);
    assert.equal(failed.status, "draft");
    assert.equal(failed.deliveries.length, 0);
    // A whole 100-recipient selection is accepted, and list/inbox pagination is server-side.
    await db.exec("RESET ROLE");
    const hundred = Array.from({ length: 100 }, () => randomUUID());
    await db.query(
      "INSERT INTO auth.users(id,email) SELECT x::uuid,'test@example.test' FROM jsonb_array_elements_text($1::jsonb)x",
      [JSON.stringify(hundred)],
    );
    await as(A);
    const bulk = await save(randomUUID(), hundred.map(user));
    await rpc("admin_send_message", [bulk.id, bulk.revision]);
    assert.equal(
      (await rpc("admin_get_message", [bulk.id])).deliveries.length,
      100,
    );
    for (let i = 0; i < 26; i++) {
      const d = await save(randomUUID(), [user(U)], 0, `Pagination ${i}`);
      await rpc("admin_send_message", [d.id, d.revision]);
    }
    assert.equal((await rpc("admin_list_messages", [0])).messages.length, 25);
    assert.equal((await rpc("admin_list_messages", [1])).messages.length, 4);
    await as(U);
    assert.equal((await rpc("my_message_inbox", [0])).messages.length, 25);
    assert.equal((await rpc("my_message_inbox", [1])).messages.length, 2);
    await assert.rejects(rpc("my_message_inbox", [-1]), /Página inválida/);
    await as(A);
    await db.exec("RESET ROLE");
    await db.query(
      "UPDATE app_administrators SET status='disabled' WHERE user_id=$1",
      [A],
    );
    await as(A);
    await assert.rejects(rpc("admin_send_message", [id, 1]), /denegado/);
  } finally {
    await db.close();
  }
});
