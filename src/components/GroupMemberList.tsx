import { useEffect, useState } from 'react';
import { Users } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { userService } from '../services/userService';
import type { GroupMember } from '../types';

export function GroupMemberList({ groupId }: { groupId: string }) {
  const { user } = useAuth();
  const userId = user?.id;
  const [state, setState] = useState<{ identity: string; members: GroupMember[] } | null>(null);
  const [error, setError] = useState('');
  const [refresh, setRefresh] = useState(0);
  const identity = `${userId ?? ''}:${groupId}`;
  useEffect(() => {
    if (!userId) return;
    let active = true;
    let sequence = 0;
    const load = async () => {
      const request = ++sequence;
      try {
        const members = await userService.getGroupMembers(groupId);
        if (active && request === sequence) {
          setState({ identity, members });
          setError('');
        }
      } catch {
        if (active && request === sequence) setError('No se pudieron cargar los miembros. Pulsa Actualizar miembros para reintentarlo.');
      }
    };
    void load();
    const focus = () => void load();
    const timer = window.setInterval(focus, 30000);
    window.addEventListener('focus', focus);
    return () => { active = false; window.clearInterval(timer); window.removeEventListener('focus', focus); };
  }, [groupId, userId, identity, refresh]);
  if (!userId) return null;
  const members = state?.identity === identity ? state.members : null;
  return <section className="space-y-3 mb-6 text-ink">
    <div className="flex flex-wrap items-center justify-between gap-3 bg-accent-soft p-4 rounded-lg">
      <h2 className="flex items-center gap-2 text-xl font-semibold text-title"><Users size={24} />Miembros del grupo{members && ` (${members.length})`}</h2>
      <button className="text-sm border border-line rounded-xl px-3 py-2" onClick={() => setRefresh(value => value + 1)}>Actualizar miembros</button>
    </div>
    <p className="text-sm text-ink-3">Cuentas incorporadas al grupo. Las invitaciones pendientes no aparecen hasta que se aceptan.</p>
    {error && <p role="alert" className="text-red-600">{error}</p>}
    {!members && !error && <p role="status">Cargando miembros…</p>}
    {members?.map(member => <article key={member.id} className="bg-card border border-line rounded-xl p-3">
      <p className="font-semibold break-words">{member.profile?.nick || member.profile?.display_name || 'Miembro'}</p>
      {member.profile?.nick && member.profile.display_name && <p className="text-sm break-words">{member.profile.display_name}</p>}
      <p className="text-sm text-ink-3">{member.role === 'admin' ? 'Administrador' : 'Miembro'}</p>
      <p className="text-xs text-ink-3 break-all">{member.user_id}</p>
    </article>)}
    {members?.length === 0 && !error && <p className="text-ink-3">No hay miembros visibles para esta cuenta.</p>}
  </section>;
}
