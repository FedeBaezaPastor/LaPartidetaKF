import React from 'react';
import { X, Sparkles, Users, Trophy, Shield, Star } from 'lucide-react';

interface CreateGroupComingSoonModalProps {
  onClose: () => void;
}

export default function CreateGroupComingSoonModal({ onClose }: CreateGroupComingSoonModalProps) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-card rounded-2xl shadow-card max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <div className="p-6">
          <div className="flex justify-between items-start mb-6">
            <div className="flex items-center gap-3">
              <div className="bg-gradient-to-br from-blue-500 to-purple-600 p-3 rounded-xl">
                <Sparkles className="w-6 h-6 text-white" />
              </div>
              <h2 className="text-2xl font-bold text-ink">
                Próximamente...
              </h2>
            </div>
            <button
              onClick={onClose}
              className="text-ink-4 hover:text-ink-3 transition-colors"
            >
              <X size={24} />
            </button>
          </div>

          <div className="space-y-6">
            <div className="bg-gradient-to-br from-blue-50 to-purple-50 rounded-xl p-5 border-2 border-blue-200">
              <p className="text-lg text-ink-2 leading-relaxed">
                Estamos puliendo los últimos detalles para que puedas crear tus propias Multipartidetas.
                Muy pronto tendrás el control total.
              </p>
            </div>

            <div>
              <h3 className="text-lg font-bold text-ink mb-4 flex items-center gap-2">
                <Trophy className="w-5 h-5 text-yellow-500" />
                Con tus Multipartidetas podrás:
              </h3>

              <div className="space-y-4">
                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                    <Users className="w-5 h-5 text-blue-600" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-ink">Crea grupos personalizados</h4>
                    <p className="text-sm text-ink-3">
                      Organiza tus grupos de amigos, compañeros de club o torneos privados.
                    </p>
                  </div>
                </div>

                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 bg-accent-soft rounded-lg flex items-center justify-center">
                    <Star className="w-5 h-5 text-accent-ink" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-ink">Rankings y estadísticas exclusivos</h4>
                    <p className="text-sm text-ink-3">
                      Cada grupo tendrá su propio ranking histórico y estadísticas detalladas.
                    </p>
                  </div>
                </div>

                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                    <Shield className="w-5 h-5 text-purple-600" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-ink">Controla quién participa</h4>
                    <p className="text-sm text-ink-3">
                      Código de acceso privado para que solo tus amigos puedan unirse.
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-accent-soft rounded-xl p-5 border-2 border-accent-ring">
              <p className="text-center text-ink-2 font-medium">
                Mientras tanto, prueba una Partideta Rápida o únete a grupos existentes.
                <br />
                <span className="text-accent-ink font-bold">El golf es ahora.</span>
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="w-full mt-6 bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-4 rounded-xl hover:from-blue-700 hover:to-purple-700 transition-all font-semibold text-lg shadow-card"
          >
            Entendido
          </button>
        </div>
      </div>
    </div>
  );
}
