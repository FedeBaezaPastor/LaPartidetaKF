import React, { useState } from 'react';
import { AlertTriangle } from 'lucide-react';

interface CourseChangeConfirmModalProps {
  currentCourseName: string;
  newCourseName: string;
  currentNumHoles: 9 | 18;
  onConfirm: (numHoles: 9 | 18) => void;
  onCancel: () => void;
}

export const CourseChangeConfirmModal: React.FC<CourseChangeConfirmModalProps> = ({
  currentCourseName,
  newCourseName,
  currentNumHoles,
  onConfirm,
  onCancel,
}) => {
  const [selectedHoles, setSelectedHoles] = useState<9 | 18>(currentNumHoles);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-2xl max-w-md w-full p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="bg-amber-100 p-2 rounded-full">
            <AlertTriangle className="text-amber-600" size={24} />
          </div>
          <h2 className="text-xl font-bold text-gray-900">¿Confirmar cambio de campo?</h2>
        </div>

        <div className="space-y-3 mb-6">
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-3">
            <p className="text-sm text-gray-700">
              <span className="font-semibold">Campo actual:</span>{' '}
              <span className="text-amber-700">{currentCourseName} ({currentNumHoles} hoyos)</span>
            </p>
            <p className="text-sm text-gray-700 mt-1">
              <span className="font-semibold">Nuevo campo:</span>{' '}
              <span className="text-emerald-700">{newCourseName}</span>
            </p>
          </div>

          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <p className="text-xs text-blue-800">
              Se recalcularán automáticamente todos los puntos Stableford según los pares y golpes
              recibidos del nuevo campo. Los golpes brutos se mantendrán sin cambios.
            </p>
          </div>
        </div>

        <div className="mb-6">
          <label className="block text-sm font-semibold text-gray-700 mb-2">
            Número de Hoyos
          </label>
          <div className="flex gap-3">
            <button
              onClick={() => setSelectedHoles(9)}
              className={`flex-1 py-3 rounded-lg font-bold transition-all ${
                selectedHoles === 9
                  ? 'bg-emerald-600 text-white shadow-md'
                  : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
              }`}
            >
              9 Hoyos
            </button>
            <button
              onClick={() => setSelectedHoles(18)}
              className={`flex-1 py-3 rounded-lg font-bold transition-all ${
                selectedHoles === 18
                  ? 'bg-emerald-600 text-white shadow-md'
                  : 'bg-gray-200 text-gray-800 hover:bg-gray-300'
              }`}
            >
              18 Hoyos
            </button>
          </div>
        </div>

        <div className="flex gap-3">
          <button
            onClick={onCancel}
            className="flex-1 px-4 py-3 bg-gray-200 hover:bg-gray-300 text-gray-800 rounded-lg font-semibold transition-colors"
          >
            Cancelar
          </button>
          <button
            onClick={() => onConfirm(selectedHoles)}
            className="flex-1 px-4 py-3 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg font-semibold transition-colors"
          >
            Confirmar Cambio
          </button>
        </div>
      </div>
    </div>
  );
};
