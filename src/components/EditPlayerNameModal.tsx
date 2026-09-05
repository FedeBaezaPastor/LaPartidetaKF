import React, { useState } from 'react';
import { X } from 'lucide-react';

interface EditPlayerNameModalProps {
  currentName: string;
  onConfirm: (newName: string) => void;
  onCancel: () => void;
}

export const EditPlayerNameModal: React.FC<EditPlayerNameModalProps> = ({
  currentName,
  onConfirm,
  onCancel,
}) => {
  const [newName, setNewName] = useState(currentName);
  const [error, setError] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!newName.trim()) {
      setError('El nombre no puede estar vacío');
      return;
    }

    if (newName.trim() === currentName.trim()) {
      setError('El nombre no ha cambiado');
      return;
    }

    onConfirm(newName.trim());
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-card rounded-lg shadow-card max-w-md w-full p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-ink">Editar Nombre</h2>
          <button
            onClick={onCancel}
            className="text-ink-4 hover:text-ink-3 transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-semibold text-ink-2 mb-2">
              Nombre del Jugador
            </label>
            <input
              type="text"
              value={newName}
              onChange={(e) => {
                setNewName(e.target.value);
                setError('');
              }}
              className="w-full px-4 py-3 border-2 border-line-2 rounded-lg focus:outline-none focus:border-accent transition-colors"
              autoFocus
            />
          </div>

          {error && (
            <div className="bg-red-50 border-l-4 border-red-500 p-3 rounded">
              <p className="text-red-700 text-sm">{error}</p>
            </div>
          )}

          <div className="flex gap-3">
            <button
              type="button"
              onClick={onCancel}
              className="flex-1 px-4 py-3 bg-neutral hover:bg-neutral-hover text-ink font-semibold rounded-lg transition-colors"
            >
              Cancelar
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-3 bg-accent hover:bg-accent-hover text-on-accent font-semibold rounded-lg transition-colors"
            >
              Guardar
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
