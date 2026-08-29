import React, { useState } from 'react';
import { Lock, X } from 'lucide-react';

interface AccessCodeModalProps {
  onSubmit: (code: string) => void;
  onCancel: () => void;
  error?: string;
  loading?: boolean;
}

export const AccessCodeModal: React.FC<AccessCodeModalProps> = ({
  onSubmit,
  onCancel,
  error,
  loading = false,
}) => {
  const [code, setCode] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (code.trim()) {
      onSubmit(code.trim());
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (value.length <= 20) {
      setCode(value);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-2xl max-w-md w-full p-6">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="bg-emerald-100 p-3 rounded-full">
              <Lock className="text-emerald-600" size={24} />
            </div>
            <h2 className="text-xl font-bold text-gray-900">
              Código de Acceso
            </h2>
          </div>
          <button
            onClick={onCancel}
            className="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        <p className="text-gray-700 mb-6">
          Ingresa el código de acceso para unirte o editar esta partida.
        </p>

        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Código de Acceso
            </label>
            <input
              type="text"
              value={code}
              onChange={handleInputChange}
              placeholder="Código"
              className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:border-emerald-500 focus:outline-none text-center text-2xl font-bold tracking-wider font-mono"
              autoFocus
              maxLength={20}
              disabled={loading}
            />
            <p className="text-xs text-gray-500 mt-2 text-center">
              Codigo de 4 caracteres
            </p>
          </div>

          {error && (
            <div className="bg-red-50 border-l-4 border-red-500 p-3 rounded mb-4">
              <p className="text-red-700 text-sm">{error}</p>
            </div>
          )}

          <div className="flex gap-3">
            <button
              type="button"
              onClick={onCancel}
              disabled={loading}
              className="flex-1 bg-gray-200 hover:bg-gray-300 disabled:opacity-50 text-gray-800 font-semibold py-3 rounded-lg transition-colors"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading || code.length < 4}
              className="flex-1 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold py-3 rounded-lg transition-colors"
            >
              {loading ? 'Verificando...' : 'Acceder'}
            </button>
          </div>
        </form>

        <div className="mt-6 pt-4 border-t border-gray-200">
          <p className="text-xs text-gray-600 text-center">
            El código de acceso es proporcionado por el creador de la partida.
            Todas las clasificaciones son públicas.
          </p>
        </div>
      </div>
    </div>
  );
};
