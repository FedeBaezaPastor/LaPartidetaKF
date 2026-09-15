import { useCallback, useEffect, useRef, useState } from "react";
import { Copy } from "lucide-react";
import {
  messageService,
  type Inbox,
  type InboxItem,
} from "../services/messageService";
import { NavigationButton } from "./NavigationButton";
export function MessageInbox({
  userId,
  onRead,
}: {
  userId: string | null;
  onRead: () => void;
}) {
  const [inbox, setInbox] = useState<Inbox>({
      messages: [],
      total: 0,
      unread: 0,
    }),
    [boxId, setBoxId] = useState(""),
    [page, setPage] = useState(0),
    [opened, setOpened] = useState<InboxItem | null>(null),
    [busy, setBusy] = useState(false),
    [loading, setLoading] = useState(true),
    [error, setError] = useState(""),
    [copied, setCopied] = useState(false);
  const request = useRef(0),
    identity = useRef(userId),
    alive = useRef(true);
  identity.current = userId;
  const load = useCallback(async () => {
    const current = ++request.current;
    try {
      const data = await messageService.inbox(userId, page);
      if (current === request.current) {
        setInbox(data);
        setBoxId(data.boxId || "");
        setError("");
      }
    } catch {
      if (current === request.current)
        setError("No se pudo cargar el buzón. Puedes reintentarlo.");
    } finally {
      if (current === request.current) setLoading(false);
    }
  }, [userId, page]);
  useEffect(() => {
    alive.current = true;
    void load();
    const tick = () => void load();
    const timer = window.setInterval(tick, 30000);
    window.addEventListener("focus", tick);
    return () => {
      alive.current = false;
      // Invalidate asynchronous requests; this ref is a counter, not a DOM node.
      // eslint-disable-next-line react-hooks/exhaustive-deps
      request.current++;
      window.clearInterval(timer);
      window.removeEventListener("focus", tick);
    };
  }, [load]);
  return (
    <section className="space-y-3 mb-7 text-ink">
      <h2 className="font-bold text-lg">Mensajes</h2>
      {!userId && boxId && (
        <div className="bg-card border border-line rounded-xl p-3">
          <p className="text-sm">Identificador de este buzón Express</p>
          <div className="flex gap-2 items-center">
            <code className="text-xs break-all flex-1">{boxId}</code>
            <button
              type="button"
              title="Copiar identificador"
              aria-label="Copiar identificador del buzón"
              className="w-11 h-11 shrink-0 border border-line rounded-full flex items-center justify-center"
              onClick={async () => {
                try {
                  await navigator.clipboard.writeText(boxId);
                  setCopied(true);
                } catch {
                  setError(
                    "No se pudo copiar. Selecciona el identificador para copiarlo.",
                  );
                }
              }}
            >
              <Copy size={18} />
            </button>
          </div>
          {copied && (
            <p role="status" className="text-sm">
              Identificador copiado.
            </p>
          )}
          <p className="text-xs text-ink-3 mt-2">
            Este buzón pertenece a este navegador. Si borras sus datos perderás
            el acceso. Al iniciar sesión verás el buzón de tu cuenta.
          </p>
        </div>
      )}
      {error && (
        <p role="alert" className="text-red-600">
          {error}
        </p>
      )}
      <button
        disabled={busy}
        className="border border-line rounded-xl p-2"
        onClick={() => void load()}
      >
        Actualizar mensajes
      </button>
      {opened ? (
        <article className="bg-card border border-line rounded-xl p-4">
          <NavigationButton onClick={() => setOpened(null)} />
          <p className="text-sm text-ink-3 mt-3">
            {opened.sender_label || "Administración"} · {new Date(opened.sent_at).toLocaleString("es-ES")}
          </p>
          <h3 className="font-bold text-lg break-words">{opened.title}</h3>
          <p className="whitespace-pre-wrap break-words mt-3">{opened.body}</p>
          <p className="text-xs text-ink-3 mt-3">
            Este mensaje no admite respuestas.
          </p>
        </article>
      ) : (
        <>
          {loading ? (
            <p role="status">Cargando mensajes…</p>
          ) : (
            inbox.messages.map((m) => (
              <button
                key={m.id}
                disabled={busy}
                className="w-full text-left bg-card border border-line rounded-xl p-4"
                onClick={async () => {
                  if (busy) return;
                  setBusy(true);
                  try {
                    const data = await messageService.open(userId, m.id);
                    if (!alive.current || identity.current !== userId) return;
                    setOpened(data);
                    onRead();
                    await load();
                  } catch {
                    if (alive.current && identity.current === userId)
                      setError(
                        "No se pudo abrir el mensaje. Inténtalo de nuevo.",
                      );
                  } finally {
                    if (alive.current) setBusy(false);
                  }
                }}
              >
                <span className="block text-xs text-ink-3">
                  {m.sender_label || "Administración"} · {new Date(m.sent_at).toLocaleString("es-ES")}
                </span>
                <span className="block font-semibold break-words">
                  {!m.read_at ? "● " : ""}
                  {m.title}
                </span>
                <span className="text-xs">
                  {m.read_at ? "Leído" : "No leído"}
                </span>
              </button>
            ))
          )}
          {!loading && !inbox.messages.length && !error && (
            <p className="text-ink-3">No tienes mensajes.</p>
          )}
          {inbox.total > 25 && (
            <div className="flex gap-3 items-center">
              <button
                disabled={page === 0 || busy}
                onClick={() => setPage((p) => p - 1)}
                className="border rounded-xl p-2"
              >
                Anterior
              </button>
              <span>Página {page + 1}</span>
              <button
                disabled={(page + 1) * 25 >= inbox.total || busy}
                onClick={() => setPage((p) => p + 1)}
                className="border rounded-xl p-2"
              >
                Siguiente
              </button>
            </div>
          )}
        </>
      )}
    </section>
  );
}
