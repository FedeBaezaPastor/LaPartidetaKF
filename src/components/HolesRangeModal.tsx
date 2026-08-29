import React, { useState } from 'react';
import { X } from 'lucide-react';

interface HolesRangeModalProps {
  onConfirm: (range: '1-9' | '10-18') => void;
  onCancel: () => void;
}

export const HolesRangeModal: React.FC<HolesRangeModalProps> = ({ onConfirm, onCancel }) => {
  const [selectedRange, setSelectedRange] = useState<'1-9' | '10-18'>('1-9');

  const handleConfirm = () => {
    onConfirm(selectedRange);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-bold text-gray-800">Selecciona Hoyos</h2>
          <button
            onClick={onCancel}
            className="text-gray-500 hover:text-gray-700 transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        <p className="text-gray-600 mb-6">
          ¿Qué 9 hoyos quieres jugar?
        </p>

        <div className="space-y-3 mb-6">
          <button
            onClick={() => setSelectedRange('1-9')}
            className={`w-full py-4 rounded-lg font-bold transition-all ${
              selectedRange === '1-9'
                ? 'bg-emerald-600 text-white shadow-lg'
                : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
            }`}
          >
            Hoyos 1-9 (Front Nine)
          </button>
          <button
            onClick={() => setSelectedRange('10-18')}
            className={`w-full py-4 rounded-lg font-bold transition-all ${
              selectedRange === '10-18'
                ? 'bg-emerald-600 text-white shadow-lg'
                : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
            }`}
          >
            Hoyos 10-18 (Back Nine)
          </button>
        </div>

        <div className="flex gap-3">
          <button
            onClick={onCancel}
            className="flex-1 px-4 py-3 bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold rounded-lg transition-colors"
          >
            Cancelar
          </button>
          <button
            onClick={handleConfirm}
            className="flex-1 px-4 py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-lg transition-colors"
          >
            Confirmar
          </button>
        </div>
      </div>
    </div>
  );
};
