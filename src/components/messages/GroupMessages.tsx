import { useEffect, useState } from "react";
import {
  messageService,
  type MessageGroup,
} from "../../services/messageService";
import { useReadOnly } from "../../context/ReadOnlyContext";
import { NavigationButton } from "../NavigationButton";
import { MessageManager } from "./MessageManager";

export function GroupMessages({ onBack }: { onBack: () => void }) {
  const readOnly = useReadOnly();
  const [groups, setGroups] = useState<MessageGroup[]>([]),
    [search, setSearch] = useState(""),
    [selected, setSelected] = useState<MessageGroup | null>(null),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(true);
  useEffect(() => {
    let active = true;
    let sequence = 0;
    const load = async () => {
      const request = ++sequence;
      try {
        const data = await messageService.groups(search, true);
        if (active && request === sequence) {
          setGroups(data);
          setError("");
        }
      } catch {
        if (active && request === sequence) {
          setGroups([]);
          setError("No se pudieron comprobar tus grupos. Vuelve a intentarlo.");
        }
      } finally {
        if (active && request === sequence) setLoading(false);
      }
    };
    const debounce = window.setTimeout(() => void load(), 250),
      timer = window.setInterval(() => void load(), 30000);
    const focus = () => void load();
    window.addEventListener("focus", focus);
    return () => {
      active = false;
      window.clearTimeout(debounce);
      window.clearInterval(timer);
      window.removeEventListener("focus", focus);
    };
  }, [search]);
  // Recheck the selected group independently of search/pagination and revoke UI
  // access on role loss. The RPCs enforce the same permission on every operation.
  const [allowed, setAllowed] = useState<string | null>(null);
  useEffect(() => {
    if (!selected) {
      setAllowed(null);
      return;
    }
    let active = true;
    const check = async () => {
      try {
        const result = await messageService.groups(selected.id, true);
        if (active)
          setAllowed(
            result.some((g) => g.id === selected.id) ? selected.id : null,
          );
      } catch {
        if (active) setAllowed(null);
      }
    };
    void check();
    const timer = window.setInterval(() => void check(), 30000);
    const focus = () => void check();
    window.addEventListener("focus", focus);
    return () => {
      active = false;
      window.clearInterval(timer);
      window.removeEventListener("focus", focus);
    };
  }, [selected]);
  if (selected)
    return (
      <section className="space-y-4">
        <NavigationButton
          onClick={() => {
            setSelected(null);
            setAllowed(null);
          }}
        />
        <h2 className="text-xl font-bold text-ink">Mensajes del grupo</h2>
        {allowed === selected.id ? (
          <MessageManager
            key={selected.id}
            group={selected}
            readOnly={readOnly}
          />
        ) : (
          <p role="status" className="text-ink">
            No se ha confirmado el permiso para gestionar este grupo. Puedes
            volver al listado.
          </p>
        )}
      </section>
    );
  return (
    <section className="space-y-4 text-ink">
      <NavigationButton onClick={onBack} />
      <h2 className="text-xl font-bold">Mensajes de mis grupos</h2>
      <p>
        Elige un grupo que administres. Cada mensaje se identificará con el
        nombre del grupo.
      </p>
      <label className="block">
        Buscar grupo
        <input
          className="w-full bg-card border border-line rounded-xl p-3"
          value={search}
          maxLength={200}
          onChange={(e) => {
            setLoading(true);
            setSearch(e.target.value);
          }}
          placeholder="Nombre, código o UUID"
        />
      </label>
      {error && <p role="alert">{error}</p>}
      {loading ? (
        <p role="status">Cargando…</p>
      ) : (
        groups.map((g) => (
          <button
            key={g.id}
            className="block w-full text-left bg-card border border-line rounded-xl p-4"
            onClick={() => setSelected(g)}
          >
            <strong>{g.name}</strong>
            <span className="block">
              {g.group_code} · {g.member_count} cuentas registradas
            </span>
          </button>
        ))
      )}
      {!loading && !groups.length && !error && (
        <p>No se encontraron grupos que administres.</p>
      )}
    </section>
  );
}
