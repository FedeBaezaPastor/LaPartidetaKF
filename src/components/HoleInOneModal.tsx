import React from 'react';
import { Trophy } from 'lucide-react';

interface HoleInOneModalProps {
  playerName: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export const HoleInOneModal: React.FC<HoleInOneModalProps> = ({
  playerName,
  onConfirm,
  onCancel,
}) => {
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-2xl max-w-md w-full p-6 animate-fadeIn">
        <div className="flex items-center gap-3 mb-4">
          <div className="bg-yellow-100 p-3 rounded-full">
            <Trophy className="text-yellow-600" size={32} />
          </div>
          <h2 className="text-2xl font-bold text-gray-900">¡Hoyo en Uno!</h2>
        </div>

        <p className="text-gray-700 mb-6 text-lg">
          ¿<strong>{playerName}</strong> realmente hizo hoyo en uno (1 golpe)?
        </p>

        <div className="flex gap-3">
          <button
            onClick={onCancel}
            className="flex-1 bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-3 px-4 rounded-lg transition-colors"
          >
            No, corregir
          </button>
          <button
            onClick={onConfirm}
            className="flex-1 bg-yellow-500 hover:bg-yellow-600 text-white font-semibold py-3 px-4 rounded-lg transition-colors flex items-center justify-center gap-2"
          >
            <Trophy size={20} />
            ¡Sí, hole-in-one!
          </button>
        </div>
      </div>
    </div>
  );
};
