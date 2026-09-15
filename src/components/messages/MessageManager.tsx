import { useEffect, useMemo, useRef, useState } from "react";
import {
  messageService,
  type MessageDraft,
  type MessageSummary,
  type MessageTarget,
  type MessageGroup,
} from "../../services/messageService";
import { NavigationButton } from "../NavigationButton";

const input = "w-full bg-card text-ink border border-line rounded-xl p-3";
const button = "border border-line rounded-xl p-3 disabled:opacity-40";
const when = (v: string) => new Date(v).toLocaleString("es-ES");
const errorText = (e: unknown) =>
  e && typeof e === "object" && "message" in e
    ? String(e.message)
    : "No se pudo completar la operación.";
const kindName = (kind: MessageTarget["kind"]) =>
  ({
    user: "Cuenta registrada",
    express: "Dispositivo Express",
    group: "Todo el grupo",
    group_admins: "Administradores del grupo",
  })[kind];

export function MessageManager({
  group,
  readOnly = false,
}: {
  group?: MessageGroup;
  readOnly?: boolean;
}) {
  const groupId = group?.id ?? null;
  const api = useMemo(
    () => ({
      list: (page: number) =>
        groupId
          ? messageService.groupList(groupId, page)
          : messageService.list(page),
      detail: (id: string) =>
        groupId ? messageService.groupDetail(id) : messageService.detail(id),
      save: (draft: MessageDraft) => messageService.save(draft, groupId),
      recipients: (search: string) =>
        groupId
          ? messageService.groupRecipients(groupId, search)
          : messageService.recipients(search),
    }),
    [groupId],
  );
  const [items, setItems] = useState<MessageSummary[]>([]),
    [total, setTotal] = useState(0),
    [page, setPage] = useState(0),
    [revision, setRevision] = useState(0);
  const [draft, setDraft] = useState<MessageDraft | null>(null),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(false);
  useEffect(() => {
    let live = true;
    setLoading(true);
    api
      .list(page)
      .then((d) => {
        if (live) {
          setItems(d.messages);
          setTotal(d.total);
          setError("");
        }
      })
      .catch((e) => {
        if (live) {
          setError(errorText(e));
          setItems([]);
        }
      })
      .finally(() => {
        if (live) setLoading(false);
      });
    return () => {
      live = false;
    };
  }, [api, page, revision]);
  const open = async (id: string) => {
    setLoading(true);
    try {
      setDraft(await api.detail(id));
      setError("");
    } catch (e) {
      setError(errorText(e));
    } finally {
      setLoading(false);
    }
  };
  if (draft)
    return (
      <MessageEditor
        key={draft.id}
        initial={draft}
        api={api}
        group={group}
        readOnly={readOnly || (!group && draft.sender_kind === "group")}
        onBack={() => {
          setDraft(null);
          setRevision((v) => v + 1);
        }}
      />
    );
  return (
    <section className="space-y-4 text-ink">
      <div className="flex flex-wrap justify-between gap-3">
        <h2 className="font-bold text-xl">
          {group ? `Mensajes · ${group.name}` : "Mensajes"}
        </h2>
        <button
          disabled={loading || readOnly}
          className="bg-accent text-on-accent rounded-xl p-3 disabled:opacity-40"
          onClick={() =>
            setDraft({
              id: crypto.randomUUID(),
              title: "",
              body: "",
              status: "draft",
              revision: 0,
              recipients: [],
              recipient_selection: group
                ? [{ kind: "group", id: group.id, label: group.name }]
                : [],
              sender_label: group ? `Grupo · ${group.name}` : "Administración",
              author_alias: "",
              created_at: new Date().toISOString(),
              sent_at: null,
            })
          }
        >
          Nuevo mensaje
        </button>
      </div>
      <p className="text-ink-3">
        {group
          ? "Avisos para las cuentas registradas de este grupo."
          : "Avisos de Administración y consulta de envíos de los grupos."}{" "}
        Sin respuestas ni envíos automáticos.
      </p>
      {readOnly && (
        <p role="status">
          Cuenta en modo solo lectura: puedes consultar el historial.
        </p>
      )}
      <button
        disabled={loading}
        className={button}
        onClick={() => setRevision((v) => v + 1)}
      >
        Actualizar
      </button>
      {error && (
        <p role="alert" className="text-red-600">
          {error}
        </p>
      )}
      {loading ? (
        <p role="status">Cargando…</p>
      ) : (
        items.map((m) => (
          <button
            key={m.id}
            onClick={() => void open(m.id)}
            className="w-full text-left bg-card border border-line rounded-xl p-4"
          >
            <strong className="block break-words">{m.title}</strong>
            <span className="block">
              {m.sender_label || "Administración"} ·{" "}
              {m.status === "sent" ? "Enviado" : "Borrador"}
            </span>
            <span className="block">
              {m.recipient_count} destinatarios · {m.read_count} leídos
            </span>
            <span className="text-sm text-ink-3">
              {m.sent_by_alias || m.author_alias} ·{" "}
              {when(m.sent_at || m.created_at)}
            </span>
          </button>
        ))
      )}
      {!loading && !items.length && !error && <p>No hay mensajes.</p>}
      <div className="flex flex-wrap gap-3 items-center">
        <button
          disabled={loading || page === 0}
          className={button}
          onClick={() => setPage((v) => v - 1)}
        >
          Anterior
        </button>
        <span>
          Página {page + 1} · {total} mensajes
        </span>
        <button
          disabled={loading || (page + 1) * 25 >= total}
          className={button}
          onClick={() => setPage((v) => v + 1)}
        >
          Siguiente
        </button>
      </div>
    </section>
  );
}

type EditorApi = {
  detail: (id: string) => Promise<MessageDraft>;
  save: (draft: MessageDraft) => Promise<MessageDraft>;
  recipients: (search: string) => Promise<MessageTarget[]>;
};
function MessageEditor({
  initial,
  onBack,
  api,
  group,
  readOnly,
}: {
  initial: MessageDraft;
  onBack: () => void;
  api: EditorApi;
  group?: MessageGroup;
  readOnly: boolean;
}) {
  const [draft, setDraft] = useState(initial),
    [search, setSearch] = useState(""),
    [found, setFound] = useState<MessageTarget[]>([]),
    [searching, setSearching] = useState(false);
  const [preview, setPreview] = useState(false),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [notice, setNotice] = useState("");
  const running = useRef(false);
  useEffect(() => {
    let live = true;
    setFound([]);
    if (search.trim().length < 2) {
      setSearching(false);
      return;
    }
    setSearching(true);
    const timer = setTimeout(() => {
      api
        .recipients(search.trim())
        .then((d) => {
          if (live) setFound(d);
        })
        .catch((e) => {
          if (live) setError(errorText(e));
        })
        .finally(() => {
          if (live) setSearching(false);
        });
    }, 250);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [api, search]);
  const selection = draft.recipient_selection ?? draft.recipients;
  const sent = draft.status === "sent",
    frozen = sent || readOnly,
    showContent = preview || frozen;
  const valid =
    draft.title.trim().length > 0 &&
    draft.title.length <= 120 &&
    draft.body.trim().length > 0 &&
    draft.body.length <= 4000 &&
    selection.length > 0 &&
    selection.length <= 100;
  const add = (target: MessageTarget) => {
    if (selection.some((t) => t.kind === target.kind && t.id === target.id))
      return;
    const retained =
      target.kind === "group" || target.kind === "group_admins"
        ? selection.filter(
            (t) =>
              t.id !== target.id ||
              (t.kind !== "group" && t.kind !== "group_admins"),
          )
        : selection;
    setDraft({ ...draft, recipient_selection: [...retained, target] });
    setNotice("");
    setSearch("");
  };
  const run = async (task: () => Promise<void>) => {
    if (running.current) return;
    running.current = true;
    setBusy(true);
    setError("");
    setNotice("");
    try {
      await task();
    } catch (e) {
      setError(errorText(e));
    } finally {
      running.current = false;
      setBusy(false);
    }
  };
  const save = (review: boolean) =>
    void run(async () => {
      const saved = await api.save(draft);
      setDraft(saved);
      setPreview(review);
      setNotice(
        review
          ? "Comprueba el contenido y cada destinatario antes de confirmar."
          : "Borrador guardado. Todavía no se ha enviado.",
      );
    });
  return (
    <section className="space-y-4 text-ink">
      <NavigationButton onClick={onBack} disabled={busy} />
      <h2 className="text-xl font-bold">
        {sent
          ? "Mensaje enviado"
          : readOnly
            ? "Consultar borrador"
            : preview
              ? "Revisar envío"
              : "Redactar mensaje"}
      </h2>
      {readOnly && !sent && (
        <p>Este borrador está disponible solo para consulta.</p>
      )}
      {draft.revision > 0 && (
        <button
          disabled={busy}
          className={button}
          onClick={() =>
            void run(async () => {
              setDraft(await api.detail(draft.id));
              setPreview(false);
              setNotice(
                "Mensaje actualizado. Se han descartado los cambios locales.",
              );
            })
          }
        >
          {sent
            ? "Actualizar lecturas"
            : "Recargar borrador (descarta cambios locales)"}
        </button>
      )}
      {error && (
        <p role="alert" className="text-red-600">
          {error}
        </p>
      )}
      {notice && <p role="status">{notice}</p>}
      {showContent ? (
        <article className="bg-card border border-line rounded-xl p-4">
          <p className="text-sm text-ink-3">
            {draft.sender_label || "Administración"}
          </p>
          <h3 className="font-bold text-lg break-words">{draft.title}</h3>
          <p className="whitespace-pre-wrap break-words mt-3">{draft.body}</p>
          {draft.sent_at && (
            <p className="mt-3 text-sm">
              Enviado por {draft.sent_by_alias}: {when(draft.sent_at)}
            </p>
          )}
        </article>
      ) : (
        <div className="space-y-4">
          <p className="text-sm">
            Remitente: {draft.sender_label || "Administración"}
          </p>
          <label className="block">
            Título obligatorio (máximo 120)
            <input
              className={input}
              required
              maxLength={120}
              disabled={busy}
              value={draft.title}
              onChange={(e) => setDraft({ ...draft, title: e.target.value })}
            />
          </label>
          <label className="block">
            Mensaje obligatorio (máximo 4.000)
            <textarea
              className={input}
              rows={7}
              required
              maxLength={4000}
              disabled={busy}
              value={draft.body}
              onChange={(e) => setDraft({ ...draft, body: e.target.value })}
            />
          </label>
          {group ? (
            <div className="flex flex-wrap gap-2">
              <button
                disabled={busy || selection.length >= 100}
                className={button}
                onClick={() =>
                  add({ kind: "group", id: group.id, label: group.name })
                }
              >
                Todo el grupo
              </button>
              <button
                disabled={busy || selection.length >= 100}
                className={button}
                onClick={() =>
                  add({ kind: "group_admins", id: group.id, label: group.name })
                }
              >
                Solo administradores
              </button>
            </div>
          ) : (
            <GroupPicker
              disabled={busy || selection.length >= 100}
              onAdd={add}
            />
          )}
          <label className="block">
            {group
              ? "Añadir miembros concretos"
              : "Añadir cuentas o buzones Express"}
            <input
              className={input}
              disabled={busy || selection.length >= 100}
              maxLength={200}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={
                group
                  ? "Correo, nick o UUID de un miembro"
                  : "Correo, nick, UUID de usuario o buzón Express"
              }
            />
          </label>
          <p className="text-sm text-ink-3">
            Los grupos incluyen solo cuentas registradas, no invitaciones
            pendientes ni jugadores anónimos. El envío admite hasta 100 personas
            únicas.
          </p>
          {searching && <p role="status">Buscando…</p>}
          {!searching && search.trim().length >= 2 && !found.length && (
            <p>No se encontraron destinatarios.</p>
          )}
          {found.map((r) => {
            const selected = selection.some(
              (v) => v.kind === r.kind && v.id === r.id,
            );
            return (
              <button
                key={r.kind + r.id}
                disabled={busy || selected || selection.length >= 100}
                className={`${button} w-full text-left break-words`}
                onClick={() => add(r)}
              >
                {kindName(r.kind)} · {r.label}
                {selected ? " · Añadido" : " · Añadir"}
              </button>
            );
          })}
        </div>
      )}
      <h3 className="font-bold">Selección de destinatarios</h3>
      <ul className="space-y-2">
        {selection.map((r) => (
          <li
            key={r.kind + r.id}
            className="bg-card border border-line rounded-xl p-3 flex justify-between gap-3"
          >
            <div className="min-w-0 break-words">
              <span className="block">
                {kindName(r.kind)} · {r.label}
              </span>
              <span className="text-xs break-all">{r.id}</span>
            </div>
            {!showContent && (
              <button
                disabled={busy}
                className="text-red-600"
                onClick={() =>
                  setDraft({
                    ...draft,
                    recipient_selection: selection.filter(
                      (v) => !(v.kind === r.kind && v.id === r.id),
                    ),
                  })
                }
              >
                Quitar
              </button>
            )}
          </li>
        ))}
      </ul>
      {showContent ? (
        <>
          <h3 className="font-bold">
            Destinatarios reales: {draft.recipients.length} / 100
          </h3>
          <ul className="space-y-2">
            {draft.recipients.map((r) => (
              <li
                key={r.kind + r.id}
                className="bg-card border border-line rounded-xl p-3 break-words"
              >
                <p>{r.label}</p>
                <p className="text-xs break-all">{r.id}</p>
                {sent && (
                  <p className="text-sm">
                    {draft.deliveries?.find(
                      (d) => d.kind === r.kind && d.recipient_id === r.id,
                    )?.read_at
                      ? `Leído: ${when(draft.deliveries.find((d) => d.kind === r.kind && d.recipient_id === r.id)!.read_at!)}`
                      : "No leído"}
                  </p>
                )}
              </li>
            ))}
          </ul>
        </>
      ) : (
        <p className="text-sm text-ink-3">
          Al guardar y revisar se resolverán los miembros actuales y se
          eliminarán los duplicados. Si cambian antes de enviar, tendrás que
          revisar de nuevo.
        </p>
      )}
      {!frozen && (
        <div className="flex flex-wrap gap-3">
          {preview ? (
            <>
              <NavigationButton
                disabled={busy}
                aria-label="Volver a editar"
                title="Volver a editar"
                onClick={() => setPreview(false)}
              />
              <button
                disabled={busy}
                className="bg-accent text-on-accent rounded-xl p-3 disabled:opacity-40"
                onClick={() =>
                  void run(async () => {
                    const result = await messageService.send(
                      draft.id,
                      draft.revision,
                    );
                    setDraft(result);
                    setPreview(false);
                    setNotice("Mensaje enviado.");
                    setDraft(await api.detail(result.id));
                  })
                }
              >
                {busy
                  ? "Enviando…"
                  : `Confirmar envío a ${draft.recipients.length}`}
              </button>
            </>
          ) : (
            <>
              <button
                disabled={busy || !valid}
                className={button}
                onClick={() => save(false)}
              >
                Guardar borrador
              </button>
              <button
                disabled={busy || !valid}
                className="bg-accent text-on-accent rounded-xl p-3 disabled:opacity-40"
                onClick={() => save(true)}
              >
                Revisar envío
              </button>
            </>
          )}
        </div>
      )}
    </section>
  );
}

function GroupPicker({
  disabled,
  onAdd,
}: {
  disabled: boolean;
  onAdd: (target: MessageTarget) => void;
}) {
  const [search, setSearch] = useState(""),
    [groups, setGroups] = useState<MessageGroup[]>([]),
    [loading, setLoading] = useState(false),
    [error, setError] = useState("");
  useEffect(() => {
    let live = true;
    setGroups([]);
    if (search.trim().length < 2) {
      setLoading(false);
      return;
    }
    setLoading(true);
    const timer = setTimeout(() => {
      messageService
        .groups(search.trim())
        .then((data) => {
          if (live) {
            setGroups(data);
            setError("");
          }
        })
        .catch((e) => {
          if (live) setError(errorText(e));
        })
        .finally(() => {
          if (live) setLoading(false);
        });
    }, 250);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [search]);
  return (
    <div className="space-y-2">
      <label className="block">
        Añadir un grupo
        <input
          className={input}
          disabled={disabled}
          value={search}
          maxLength={200}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Nombre, código o UUID del grupo"
        />
      </label>
      {loading && <p role="status">Buscando grupos…</p>}
      {error && <p role="alert">{error}</p>}
      {!loading && search.trim().length >= 2 && !groups.length && !error && (
        <p>No se encontraron grupos.</p>
      )}
      {groups.map((g) => (
        <div key={g.id} className="border border-line rounded-xl p-3 space-y-2">
          <p className="break-words">
            {g.name} · {g.group_code}
          </p>
          <div className="flex flex-wrap gap-2">
            <button
              disabled={disabled || g.member_count === 0}
              className={button}
              onClick={() => {
                onAdd({ kind: "group", id: g.id, label: g.name });
                setSearch("");
              }}
            >
              Todo el grupo ({g.member_count})
            </button>
            <button
              disabled={disabled || g.admin_count === 0}
              className={button}
              onClick={() => {
                onAdd({ kind: "group_admins", id: g.id, label: g.name });
                setSearch("");
              }}
            >
              Solo administradores ({g.admin_count})
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
