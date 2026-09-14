import { useEffect, useRef, useState } from "react";
import {
  messageService,
  type MessageDraft,
  type MessageSummary,
  type Recipient,
} from "../../services/messageService";
import { NavigationButton } from "../NavigationButton";
const input = "w-full bg-card text-ink border border-line rounded-xl p-3";
const errorText = (e: unknown) =>
  e && typeof e === "object" && "message" in e
    ? String(e.message)
    : "No se pudo completar la operación.";
const when = (v: string) => new Date(v).toLocaleString("es-ES");
export function AdminMessages() {
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
    messageService
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
  }, [page, revision]);
  const open = async (id: string) => {
    setLoading(true);
    try {
      setDraft(await messageService.detail(id));
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
        onBack={() => {
          setDraft(null);
          setRevision((v) => v + 1);
        }}
      />
    );
  return (
    <section className="space-y-4">
      <div className="flex flex-wrap justify-between gap-3">
        <h2 className="font-bold text-xl">Mensajes</h2>
        <button
          disabled={loading}
          className="bg-accent text-on-accent rounded-xl p-3"
          onClick={() =>
            setDraft({
              id: crypto.randomUUID(),
              title: "",
              body: "",
              status: "draft",
              revision: 0,
              recipients: [],
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
        Avisos de Administración, sin respuestas. Los borradores no se envían
        automáticamente.
      </p>
      <button
        disabled={loading}
        className="border border-line rounded-xl p-2"
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
            <strong className="block">{m.title}</strong>
            <span className="block">
              {m.status === "sent" ? "Enviado" : "Borrador"} ·{" "}
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
      <div className="flex gap-3 items-center">
        <button
          disabled={loading || page === 0}
          className="border rounded-xl p-2 disabled:opacity-40"
          onClick={() => setPage((v) => v - 1)}
        >
          Anterior
        </button>
        <span>
          Página {page + 1} · {total} mensajes
        </span>
        <button
          disabled={loading || (page + 1) * 25 >= total}
          className="border rounded-xl p-2 disabled:opacity-40"
          onClick={() => setPage((v) => v + 1)}
        >
          Siguiente
        </button>
      </div>
    </section>
  );
}
function MessageEditor({
  initial,
  onBack,
}: {
  initial: MessageDraft;
  onBack: () => void;
}) {
  const [draft, setDraft] = useState(initial),
    [search, setSearch] = useState(""),
    [found, setFound] = useState<Recipient[]>([]),
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
      messageService
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
  }, [search]);
  const sent = draft.status === "sent";
  const valid =
    draft.title.trim().length > 0 &&
    draft.title.length <= 120 &&
    draft.body.trim().length > 0 &&
    draft.body.length <= 4000 &&
    draft.recipients.length > 0 &&
    draft.recipients.length <= 100;
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
      const saved = await messageService.save(draft);
      setDraft(saved);
      setPreview(review);
      setNotice(
        review
          ? "Revisa el mensaje y la lista completa antes de confirmar."
          : "Borrador guardado. Todavía no se ha enviado.",
      );
    });
  return (
    <section className="space-y-4">
      <NavigationButton onClick={onBack} disabled={busy} />
      <h2 className="text-xl font-bold">
        {sent
          ? "Mensaje enviado"
          : preview
            ? "Revisar envío"
            : "Redactar mensaje"}
      </h2>
      {!sent && draft.revision > 0 && (
        <button
          disabled={busy}
          className="border rounded-xl p-2"
          onClick={() =>
            void run(async () => {
              setDraft(await messageService.detail(draft.id));
              setPreview(false);
              setNotice(
                "Borrador recargado. Se han descartado los cambios locales.",
              );
            })
          }
        >
          Recargar borrador (descarta cambios locales)
        </button>
      )}
      {error && (
        <p role="alert" className="text-red-600">
          {error}
        </p>
      )}
      {notice && <p role="status">{notice}</p>}
      {preview || sent ? (
        <article className="bg-card border border-line rounded-xl p-4">
          <p className="text-sm text-ink-3">Administración</p>
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
          <label className="block">
            Añadir destinatarios
            <input
              className={input}
              disabled={busy || draft.recipients.length >= 100}
              maxLength={200}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Correo, nick, UUID de usuario o UUID de buzón Express"
            />
          </label>
          <p className="text-sm text-ink-3">
            Los buzones Express se encuentran por su UUID completo, disponible
            en Notificaciones del dispositivo.
          </p>
          {searching && <p role="status">Buscando…</p>}
          {!searching && search.trim().length >= 2 && !found.length && (
            <p>No se encontraron destinatarios.</p>
          )}
          {found.map((r) => {
            const selected = draft.recipients.some(
              (v) => v.kind === r.kind && v.id === r.id,
            );
            return (
              <button
                key={r.kind + r.id}
                disabled={busy || selected || draft.recipients.length >= 100}
                className="w-full text-left border border-line rounded-xl p-3 disabled:opacity-40 break-words"
                onClick={() => {
                  setDraft({ ...draft, recipients: [...draft.recipients, r] });
                  setSearch("");
                }}
              >
                {r.kind === "user"
                  ? "Cuenta registrada"
                  : "Dispositivo Express"}{" "}
                · {r.label}
                {selected ? " · Añadido" : " · Añadir"}
              </button>
            );
          })}
        </div>
      )}
      <h3 className="font-bold">
        Destinatarios: {draft.recipients.length} / 100
      </h3>
      <ul className="space-y-2">
        {draft.recipients.map((r) => (
          <li
            key={r.kind + r.id}
            className="bg-card border border-line rounded-xl p-3 flex justify-between gap-3"
          >
            <div className="min-w-0 break-words">
              <span className="block">
                {r.kind === "user" ? "Registrado" : "Express"} · {r.label}
              </span>
              <span className="text-xs break-all">{r.id}</span>
              {sent && (
                <p className="text-sm">
                  {draft.deliveries?.find(
                    (d) => d.kind === r.kind && d.recipient_id === r.id,
                  )?.read_at
                    ? `Leído: ${when(draft.deliveries.find((d) => d.kind === r.kind && d.recipient_id === r.id)!.read_at!)}`
                    : "No leído"}
                </p>
              )}
            </div>
            {!sent && !preview && (
              <button
                disabled={busy}
                className="text-red-600"
                onClick={() =>
                  setDraft({
                    ...draft,
                    recipients: draft.recipients.filter(
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
      {sent ? (
        <button
          disabled={busy}
          className="border rounded-xl p-3"
          onClick={() =>
            void run(async () =>
              setDraft(await messageService.detail(draft.id)),
            )
          }
        >
          Actualizar lecturas
        </button>
      ) : (
        <div className="flex flex-wrap gap-3">
          {preview ? (
            <>
              <button
                disabled={busy}
                className="border rounded-xl p-3"
                onClick={() => setPreview(false)}
              >
                Volver a editar
              </button>
              <button
                disabled={busy}
                className="bg-accent text-on-accent rounded-xl p-3"
                onClick={() =>
                  void run(async () => {
                    const result = await messageService.send(
                      draft.id,
                      draft.revision,
                    );
                    setDraft(result);
                    setPreview(false);
                    setNotice("Mensaje enviado.");
                    setDraft(await messageService.detail(result.id));
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
                className="border rounded-xl p-3 disabled:opacity-40"
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
