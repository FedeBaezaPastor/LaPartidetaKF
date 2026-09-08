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
    <div className="min-h-screen bg-gradient-to-b from-slate-50 to-emerald-50">
      <div className="max-w-lg mx-auto px-4 py-6">
        <button onClick={onBack} className="flex items-center gap-2 text-gray-600 hover:text-gray-800 mb-6">
          <ArrowLeft size={20} />
          Volver
        </button>

        <div className="flex items-center gap-3 mb-6">
          <Bell size={24} className="text-gray-700" />
          <h1 className="text-2xl font-bold text-gray-900">Notificaciones</h1>
        </div>

        {loading ? (
          <div className="text-center py-12">
            <div className="w-8 h-8 border-2 border-gray-300 border-t-emerald-600 rounded-full animate-spin mx-auto mb-3" />
            <p className="text-gray-500 text-sm">Cargando...</p>
          </div>
        ) : invitations.length === 0 ? (
          <div className="bg-white rounded-2xl shadow-lg p-8 text-center">
            <Bell size={32} className="text-gray-300 mx-auto mb-3" />
            <p className="text-gray-500">No tienes notificaciones pendientes</p>
          </div>
        ) : (
          <div className="space-y-3">
            {invitations.map(inv => (
              <div key={inv.id} className="bg-white rounded-2xl shadow-lg p-5">
                <div className="flex items-start gap-3 mb-4">
                  <div className="w-10 h-10 bg-amber-100 rounded-full flex items-center justify-center shrink-0">
                    <Users size={18} className="text-amber-600" />
                  </div>
                  <div className="flex-1">
                    <p className="font-semibold text-gray-900 text-sm">
                      {inv.inviter_profile?.nick || 'Alguien'} te ha invitado
                    </p>
                    <p className="text-sm text-gray-600 mt-0.5">
                      Quieres meterte en el grupo <strong>{inv.group?.name}</strong> donde te han invitado?
                    </p>
                    <p className="text-xs text-gray-400 mt-1 flex items-center gap-1">
                      <Clock size={12} />
                      {new Date(inv.created_at).toLocaleDateString()}
                    </p>
                  </div>
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleRespond(inv.id, 'accepted')}
                    disabled={responding === inv.id}
                    className="flex-1 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold py-2.5 rounded-xl transition-colors disabled:opacity-50"
                  >
                    <Check size={16} />
                    Aceptar
                  </button>
                  <button
                    onClick={() => handleRespond(inv.id, 'rejected')}
                    disabled={responding === inv.id}
                    className="flex-1 flex items-center justify-center gap-2 bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold py-2.5 rounded-xl transition-colors disabled:opacity-50"
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
