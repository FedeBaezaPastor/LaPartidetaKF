import React, { useEffect, useState } from 'react';
import { ArrowLeft, Bell, Check, X, Users, Clock } from 'lucide-react';
import { userService } from '../services/userService';
import { supabase } from '../services/supabaseClient';
import { GroupInvitation } from '../types';

interface NotificationsBellProps {
  userId: string;
  onBack: () => void;
  onInvitationResolved: () => void;
}

export const NotificationsBell: React.FC<NotificationsBellProps> = ({ userId, onBack, onInvitationResolved }) => {
  const [invitations, setInvitations] = useState<GroupInvitation[]>([]);
  const [loading, setLoading] = useState(true);
  const [responding, setResponding] = useState<string | null>(null);

  const load = async () => {
    try {
      const data = await userService.getPendingInvitations(userId);
      setInvitations(data);
    } catch {
      setInvitations([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [userId]);

  const handleRespond = async (invitationId: string, status: 'accepted' | 'rejected') => {
    setResponding(invitationId);
    try {
      await userService.respondToInvitation(invitationId, status);

      if (status === 'accepted') {
        const invitation = invitations.find(i => i.id === invitationId);
        if (invitation) {
          await userService.addGroupMember(invitation.group_id, userId, 'member', invitation.invited_by);
        }
      }

      setInvitations(invitations.filter(i => i.id !== invitationId));
      onInvitationResolved();
    } catch {
      // ignore
    } finally {
      setResponding(null);
    }
  };

  return (
    <div className="min-h-screen bg-app transition-colors">
      <div className="max-w-lg mx-auto px-4 py-6">
        <button onClick={onBack} className="flex items-center gap-2 text-ink-3 hover:text-ink mb-6">
          <ArrowLeft size={20} />
          Volver
        </button>

        <div className="flex items-center gap-3 mb-6">
          <Bell size={24} className="text-ink-2" />
          <h1 className="text-2xl font-bold text-ink">Notificaciones</h1>
        </div>

        {loading ? (
          <div className="text-center py-12">
            <div className="w-8 h-8 border-2 border-line-2 border-t-accent rounded-full animate-spin mx-auto mb-3" />
            <p className="text-ink-3 text-sm">Cargando...</p>
          </div>
        ) : invitations.length === 0 ? (
          <div className="bg-card rounded-2xl shadow-card p-8 text-center">
            <Bell size={32} className="text-ink-4 mx-auto mb-3" />
            <p className="text-ink-3">No tienes notificaciones pendientes</p>
          </div>
        ) : (
          <div className="space-y-3">
            {invitations.map(inv => (
              <div key={inv.id} className="bg-card rounded-2xl shadow-card p-5">
                <div className="flex items-start gap-3 mb-4">
                  <div className="w-10 h-10 bg-amber-100 rounded-full flex items-center justify-center shrink-0">
                    <Users size={18} className="text-amber-600" />
                  </div>
                  <div className="flex-1">
                    <p className="font-semibold text-ink text-sm">
                      {inv.inviter_profile?.nick || 'Alguien'} te ha invitado
                    </p>
                    <p className="text-sm text-ink-3 mt-0.5">
                      Quieres meterte en el grupo <strong>{inv.group?.name}</strong> donde te han invitado?
                    </p>
                    <p className="text-xs text-ink-4 mt-1 flex items-center gap-1">
                      <Clock size={12} />
                      {new Date(inv.created_at).toLocaleDateString()}
                    </p>
                  </div>
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleRespond(inv.id, 'accepted')}
                    disabled={responding === inv.id}
                    className="flex-1 flex items-center justify-center gap-2 bg-accent hover:bg-accent-hover text-on-accent font-semibold py-2.5 rounded-xl transition-colors disabled:opacity-50"
                  >
                    <Check size={16} />
                    Aceptar
                  </button>
                  <button
                    onClick={() => handleRespond(inv.id, 'rejected')}
                    disabled={responding === inv.id}
                    className="flex-1 flex items-center justify-center gap-2 bg-card-2 hover:bg-neutral-hover text-ink-2 font-semibold py-2.5 rounded-xl transition-colors disabled:opacity-50"
                  >
                    <X size={16} />
                    Rechazar
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
