import React from 'react';
import { X, Sparkles, Users, Trophy, Shield, Star } from 'lucide-react';

interface CreateGroupComingSoonModalProps {
  onClose: () => void;
}

export default function CreateGroupComingSoonModal({ onClose }: CreateGroupComingSoonModalProps) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <div className="p-6">
          <div className="flex justify-between items-start mb-6">
            <div className="flex items-center gap-3">
              <div className="bg-gradient-to-br from-blue-500 to-purple-600 p-3 rounded-xl">
                <Sparkles className="w-6 h-6 text-white" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900">
                Próximamente...
              </h2>
            </div>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600 transition-colors"
            >
              <X size={24} />
            </button>
          </div>

          <div className="space-y-6">
            <div className="bg-gradient-to-br from-blue-50 to-purple-50 rounded-xl p-5 border-2 border-blue-200">
              <p className="text-lg text-gray-700 leading-relaxed">
                Estamos puliendo los últimos detalles para que puedas crear tus propias Multipartidetas.
                Muy pronto tendrás el control total.
              </p>
            </div>

            <div>
              <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Trophy className="w-5 h-5 text-yellow-500" />
                Con tus Multipartidetas podrás:
              </h3>

              <div className="space-y-4">
                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                    <Users className="w-5 h-5 text-blue-600" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-gray-900">Crea grupos personalizados</h4>
                    <p className="text-sm text-gray-600">
                      Organiza tus grupos de amigos, compañeros de club o torneos privados.
                    </p>
                  </div>
                </div>

                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                    <Star className="w-5 h-5 text-green-600" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-gray-900">Rankings y estadísticas exclusivos</h4>
                    <p className="text-sm text-gray-600">
                      Cada grupo tendrá su propio ranking histórico y estadísticas detalladas.
                    </p>
                  </div>
                </div>

                <div className="flex gap-4">
                  <div className="flex-shrink-0 w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                    <Shield className="w-5 h-5 text-purple-600" />
                  </div>
                  <div>
                    <h4 className="font-semibold text-gray-900">Controla quién participa</h4>
                    <p className="text-sm text-gray-600">
                      Código de acceso privado para que solo tus amigos puedan unirse.
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-r from-green-50 to-emerald-50 rounded-xl p-5 border-2 border-green-200">
              <p className="text-center text-gray-700 font-medium">
                Mientras tanto, prueba una Partideta Rápida o únete a grupos existentes.
                <br />
                <span className="text-green-600 font-bold">El golf es ahora.</span>
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="w-full mt-6 bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-4 rounded-xl hover:from-blue-700 hover:to-purple-700 transition-all font-semibold text-lg shadow-lg"
          >
            Entendido
          </button>
        </div>
      </div>
    </div>
  );
}
