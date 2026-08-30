import React, { useEffect, useState } from 'react';
import { ArrowLeft, Save, User, ShieldCheck } from 'lucide-react';
import { supabase } from '../services/supabaseClient';
import { UserTier } from '../types';
import { PremiumModal } from './PremiumModal';

interface ProfileScreenProps {
  authUser: any;
  onBack: () => void;
  onUserUpdated: (user: any) => void;
  onLogout: () => void;
}

const tierOptions: UserTier[] = ['Express', 'Player', 'Team'];

export default function ProfileScreen({ authUser, onBack, onUserUpdated, onLogout }: ProfileScreenProps) {
  const [selectedTier, setSelectedTier] = useState<UserTier>('Express');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [showUpgradeModal, setShowUpgradeModal] = useState(false);
  const [pendingTier, setPendingTier] = useState<UserTier | null>(null);

  useEffect(() => {
    const currentTier = (authUser?.user_metadata?.user_tier || authUser?.user_metadata?.tier || 'Express') as UserTier;
    setSelectedTier(currentTier);
  }, [authUser]);

  const applyTier = async (tier: UserTier) => {
    if (!authUser?.id) return;

    setLoading(true);
    setError('');
    setMessage('');

    try {
      const { data, error: updateError } = await supabase.auth.updateUser({
        data: {
          user_tier: tier,
          tier,
        },
      });

      if (updateError) throw updateError;

      onUserUpdated(data.user);
      setMessage(`Tu tier se ha actualizado a ${tier}.`);
      setShowUpgradeModal(false);
      setPendingTier(null);
    } catch (err: any) {
      setError(err.message || 'No se pudo guardar el tier');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    const currentTier = (authUser?.user_metadata?.user_tier || authUser?.user_metadata?.tier || 'Express') as UserTier;

    if (selectedTier === currentTier) {
      setMessage(`Ya tienes el tier ${selectedTier}.`);
      return;
    }

    if (selectedTier === 'Express') {
      await applyTier(selectedTier);
      return;
    }

    setPendingTier(selectedTier);
    setShowUpgradeModal(true);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-emerald-100 p-4 flex items-center justify-center">
      <div className="max-w-md w-full bg-white rounded-2xl shadow-xl p-8">
        <button
          onClick={onBack}
          className="flex items-center gap-2 text-gray-600 hover:text-gray-800 mb-6 transition-colors"
        >
          <ArrowLeft size={20} />
          Volver
        </button>

        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mb-4">
            <User className="w-8 h-8 text-green-600" />
          </div>
          <h2 className="text-3xl font-bold text-gray-900 mb-2">Mis Datos</h2>
          <p className="text-gray-600">Gestiona tu perfil y tu tier</p>
        </div>

        <div className="space-y-6">
          <div className="bg-gray-50 rounded-xl p-4 border border-gray-200">
            <p className="text-xs font-semibold uppercase tracking-wide text-gray-500">Correo</p>
            <p className="mt-2 text-sm text-gray-900 font-medium break-all">{authUser?.email || 'Sin email'}</p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-3">
              Tipo de usuario
            </label>
            <div className="grid grid-cols-3 gap-2">
              {tierOptions.map((tier) => {
                const isSelected = selectedTier === tier;

                return (
                  <button
                    key={tier}
                    type="button"
                    onClick={() => setSelectedTier(tier)}
                    className={`px-3 py-2 rounded-xl border text-sm font-medium transition-colors ${
                      isSelected
                        ? 'border-green-600 bg-green-50 text-green-700'
                        : 'border-gray-200 bg-white text-gray-600 hover:border-gray-300'
                    }`}
                  >
                    {tier}
                  </button>
                );
              })}
            </div>
          </div>

          {message && (
            <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-xl text-sm">
              {message}
            </div>
          )}

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm">
              {error}
            </div>
          )}

          <div className="flex gap-3">
            <button
              type="button"
              onClick={handleSave}
              disabled={loading}
              className="flex-1 flex items-center justify-center gap-2 bg-green-600 text-white px-4 py-3 rounded-xl hover:bg-green-700 transition-colors font-semibold disabled:opacity-60"
            >
              <Save size={18} />
              {loading ? 'Guardando...' : 'Guardar'}
            </button>

            <button
              type="button"
              onClick={onLogout}
              className="flex items-center justify-center gap-2 bg-red-50 text-red-600 px-4 py-3 rounded-xl hover:bg-red-100 transition-colors font-semibold"
            >
              <ShieldCheck size={18} />
              Salir
            </button>
          </div>
        </div>
      </div>

      {showUpgradeModal && pendingTier && (
        <PremiumModal
          isOpen={showUpgradeModal}
          onClose={() => {
            setShowUpgradeModal(false);
            setPendingTier(null);
          }}
          userId={authUser?.id || ''}
          targetTier={pendingTier}
          onSuccess={async (tier) => {
            if (tier) {
              await applyTier(tier);
            }
          }}
        />
      )}
    </div>
  );
}
