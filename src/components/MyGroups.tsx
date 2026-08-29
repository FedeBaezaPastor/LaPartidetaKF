import React, { useEffect, useState } from 'react';
import { Users, Copy, Check, ArrowLeft, LogOut, Trash2, Crown } from 'lucide-react';
import { supabase } from '../services/supabaseClient';
import { Group } from '../types';
import { ConfirmModal } from './ConfirmModal';
import { PremiumModal } from './PremiumModal';
import { useSubscription } from '../hooks/useSubscription';

interface MyGroupsProps {
  onBack: () => void;
  onGroupSelected: (group: Group) => void;
  onLogout: () => void;
}

interface GroupWithCode {
  id: string;
  name: string;
  group_code: string;
  created_at: string;
  created_by?: string;
  user_auth_id?: string;
}

export default function MyGroups({ onBack, onGroupSelected, onLogout }: MyGroupsProps) {
  const [groups, setGroups] = useState<GroupWithCode[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [copiedCode, setCopiedCode] = useState<string | null>(null);
  const [userEmail, setUserEmail] = useState('');
  const [groupToDelete, setGroupToDelete] = useState<string | null>(null);
  
  // ─── PREMIUM ───
  const [showPremium, setShowPremium] = useState(false);
  const { isPremium, loading: subLoading } = useSubscription();
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    loadGroups();
    
    // Obtener usuario logueado para el modal Premium
    supabase.auth.getUser().then(({ data }) => {
      setUser(data.user);
    });
  }, []);

  const loadGroups = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();

      if (!user) {
        setError('No hay sesión activa');
        return;
      }

      setUserEmail(user.email || '');

      const { data, error: fetchError } = await supabase
        .from('groups')
        .select('id, name, group_code, created_at, created_by, user_auth_id')
        .eq('user_auth_id', user.id)
        .order('created_at', { ascending: false });

      if (fetchError) throw fetchError;

      setGroups(data || []);
    } catch (err: any) {
      setError(err.message || 'Error al cargar los grupos');
    } finally {
      setLoading(false);
    }
  };

  const handleCopyCode = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(code);
    setTimeout(() => setCopiedCode(null), 2000);
  };

  const handleDeleteGroup = (groupId: string) => {
    setGroupToDelete(groupId);
  };

  const confirmDeleteGroup = async () => {
    if (!groupToDelete) return;

    try {
      const { error: deleteError } = await supabase
        .from('groups')
        .delete()
        .eq('id', groupToDelete);

      if (deleteError) throw deleteError;

      setGroups(groups.filter(g => g.id !== groupToDelete));
      setGroupToDelete(null);
    } catch (err: any) {
      setError(err.message || 'Error al eliminar el grupo');
      setGroupToDelete(null);
    }
  };

  const cancelDeleteGroup = () => {
    setGroupToDelete(null);
  };

  const handleSelectGroup = async (groupWithCode: GroupWithCode) => {
    const group: Group = {
      id: groupWithCode.id,
      name: groupWithCode.name,
      group_code: groupWithCode.group_code,
      created_at: groupWithCode.created_at,
      created_by: groupWithCode.user_auth_id || groupWithCode.created_by,
    };
    onGroupSelected(group);
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    onLogout();
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-green-50 to-emerald-100 p-4 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-green-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Cargando tus grupos...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-emerald-100 p-4">
      <div className="max-w-2xl mx-auto">
        <div className="bg-white rounded-2xl shadow-xl p-6 mb-4">
          <div className="flex items-center justify-between mb-4">
            <button
              onClick={onBack}
              className="flex items-center gap-2 text-gray-600 hover:text-gray-800 transition-colors"
            >
              <ArrowLeft size={20} />
              Volver
            </button>
            
            {/* ─── ICONOS SUPERIOR DERECHA ─── */}
            <div className="flex items-center gap-2">
              {/* Icono Premium (solo si NO es premium y terminó de cargar) */}
              {!subLoading && !isPremium && (
                <button
                  onClick={() => setShowPremium(true)}
                  className="relative group bg-amber-500/10 hover:bg-amber-500/20 border border-amber-500/30 rounded-full p-2 transition-all hover:scale-110"
                  title="Hazte Premium"
                >
                  <Crown size={18} className="text-amber-500" />
                  <span className="absolute -bottom-8 left-1/2 transform -translate-x-1/2 bg-slate-800 text-amber-300 text-[10px] font-bold px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none">
                    Premium
                  </span>
                </button>
              )}
              
              {/* Icono Premium activo (verde, decorativo) */}
              {isPremium && (
                <div 
                  className="bg-emerald-500/10 border border-emerald-500/30 rounded-full p-2" 
                  title="Premium activo"
                >
                  <Crown size={18} className="text-emerald-500" />
                </div>
              )}
              
              <button
                onClick={handleLogout}
                className="flex items-center gap-2 text-red-600 hover:text-red-700 transition-colors text-sm font-medium"
              >
                <LogOut size={18} />
                Cerrar Sesión
              </button>
            </div>
          </div>

          <div className="text-center mb-6">
            <div className="inline-flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mb-3">
              <Users className="w-8 h-8 text-green-600" />
            </div>
            <h1 className="text-2xl font-bold text-gray-900 mb-1">Mis Grupos</h1>
            <p className="text-sm text-gray-600">{userEmail}</p>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl mb-4">
              {error}
            </div>
          )}

          {groups.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-gray-500 mb-4">Aún no has creado ningún grupo</p>
              <button
                onClick={onBack}
                className="text-green-600 hover:text-green-700 font-medium"
              >
                Crear tu primer grupo
              </button>
            </div>
          ) : (
            <div className="space-y-3">
              {groups.map((group) => (
                <div
                  key={group.id}
                  className="bg-gray-50 rounded-xl p-4 hover:bg-gray-100 transition-colors border border-gray-200"
                >
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-semibold text-gray-900 text-lg">{group.name}</h3>
                    <button
                      onClick={() => handleDeleteGroup(group.id)}
                      className="p-2 text-red-500 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors"
                      title="Eliminar grupo"
                    >
                      <Trash2 size={18} />
                    </button>
                  </div>

                  <div className="flex items-center gap-3 mb-3">
                    <div className="flex-1 bg-white rounded-lg px-4 py-3 border border-gray-300">
                      <p className="text-xs text-gray-500 mb-1">Código de acceso</p>
                      <p className="text-xl font-mono font-bold text-green-600 tracking-wider">
                        {group.group_code}
                      </p>
                    </div>
                    <button
                      onClick={() => handleCopyCode(group.group_code)}
                      className="px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors flex items-center gap-2"
                      title="Copiar código"
                    >
                      {copiedCode === group.group_code ? (
                        <>
                          <Check size={18} />
                          Copiado
                        </>
                      ) : (
                        <>
                          <Copy size={18} />
                          Copiar
                        </>
                      )}
                    </button>
                  </div>

                  <button
                    onClick={() => handleSelectGroup(group)}
                    className="w-full bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium"
                  >
                    Seleccionar Grupo
                  </button>

                  <p className="text-xs text-gray-500 mt-2">
                    Creado el {new Date(group.created_at).toLocaleDateString()}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {groupToDelete && (
        <ConfirmModal
          message="¿Estás seguro de que quieres eliminar este grupo? Esta acción no se puede deshacer."
          onConfirm={confirmDeleteGroup}
          onCancel={cancelDeleteGroup}
        />
      )}

      {/* ─── MODAL PREMIUM ─── */}
      {showPremium && (
        <PremiumModal
          isOpen={showPremium}
          onClose={() => setShowPremium(false)}
          userId={user?.id || ''}
        />
      )}
    </div>
  );
}