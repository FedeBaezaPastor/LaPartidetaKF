import React, { useState, useEffect } from 'react';
import { TrendingUp, X, AlertCircle, Info } from 'lucide-react';
import { golfService } from '../services/golfService';

interface HandicapUpdateModalProps {
  onClose: () => void;
  onSuccess: () => void;
}

interface PreviewRow {
  id: string;
  name: string;
  exact_handicap: number;
  exact_handicap_18: number;
  playing_handicap: number;
  new_value: number;
}

export const HandicapUpdateModal: React.FC<HandicapUpdateModalProps> = ({
  onClose,
  onSuccess,
}) => {
  const [preview, setPreview] = useState<PreviewRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        setLoading(true);
        setError('');
        const data = await golfService.getHandicapUpdatePreview();
        if (!cancelled) setPreview(data);
      } catch (err: any) {
        if (!cancelled) setError(err.message || 'Error cargando preview');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  const changedRows = preview.filter(
    (row) =>
      row.exact_handicap !== row.new_value ||
      row.exact_handicap_18 !== row.new_value ||
      row.playing_handicap !== row.new_value
  );

  const hasChanges = changedRows.length > 0;

  const handleUpdate = async () => {
    try {
      setUpdating(true);
      setError('');
      await golfService.applyHandicapUpdate();
      onSuccess();
    } catch (err: any) {
      setError(err.message || 'Error actualizando handicaps');
    } finally {
      setUpdating(false);
    }
  };

  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      e.stopPropagation();
    }
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-[9999]"
      onClick={handleBackdropClick}
    >
      <div
        className="bg-white rounded-lg shadow-2xl max-w-2xl w-full max-h-[85vh] overflow-hidden flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <div className="bg-blue-100 p-3 rounded-full">
              <TrendingUp className="text-blue-600" size={24} />
            </div>
            <div>
              <h2 className="text-xl font-bold text-gray-900">
                Actualizar Handicaps
              </h2>
              <p className="text-sm text-gray-500">
                Nivelar exact_handicap y exact_handicap_18 con playing_handicap
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 hover:bg-gray-100 p-2 rounded-lg transition-colors"
            title="Cerrar"
          >
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6">
          {loading && (
            <div className="text-center py-12">
              <p className="text-gray-600 text-lg">Cargando jugadores...</p>
            </div>
          )}

          {!loading && error && (
            <div className="bg-red-50 border-l-4 border-red-500 p-4 rounded mb-4">
              <p className="text-red-700">{error}</p>
            </div>
          )}

          {!loading && !error && preview.length === 0 && (
            <div className="text-center py-12">
              <p className="text-gray-600 text-lg">No hay jugadores registrados</p>
            </div>
          )}

          {!loading && !error && preview.length > 0 && !hasChanges && (
            <div className="text-center py-12">
              <AlertCircle className="mx-auto text-green-600 mb-3" size={32} />
              <p className="text-green-700 text-lg font-medium">
                Todos los handicaps ya están nivelados. No hay cambios pendientes.
              </p>
            </div>
          )}

          {!loading && !error && hasChanges && (
            <>
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-4 flex items-center gap-2">
                <Info className="text-blue-600 flex-shrink-0" size={18} />
                <p className="text-sm text-blue-700">
                  {changedRows.length} jugador{changedRows.length !== 1 ? 'es' : ''} con cambios pendientes.
                </p>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b-2 border-gray-300">
                      <th className="text-left py-3 px-3 font-semibold text-gray-700">
                        Jugador
                      </th>
                      <th className="text-center py-3 px-3 font-semibold text-gray-700">
                        exact_handicap
                      </th>
                      <th className="text-center py-3 px-3 font-semibold text-gray-700">
                        exact_handicap_18
                      </th>
                      <th className="text-center py-3 px-3 font-semibold text-gray-700">
                        playing_handicap
                      </th>
                      <th className="text-center py-3 px-3 font-semibold text-gray-700">
                        Nuevo valor
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {changedRows.map((row, index) => {
                      const changed =
                        row.exact_handicap !== row.new_value ||
                        row.exact_handicap_18 !== row.new_value ||
                        row.playing_handicap !== row.new_value;
                      return (
                        <tr
                          key={row.id}
                          className={index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}
                        >
                          <td className="py-3 px-3 font-medium text-gray-900">
                            {row.name}
                          </td>
                          <td className="text-center py-3 px-3 text-gray-700">
                            {row.exact_handicap.toFixed(1)}
                          </td>
                          <td className="text-center py-3 px-3 text-gray-700">
                            {row.exact_handicap_18.toFixed(1)}
                          </td>
                          <td className="text-center py-3 px-3 text-gray-700">
                            {row.playing_handicap.toFixed(1)}
                          </td>
                          <td
                            className={`text-center py-3 px-3 font-bold ${
                              changed ? 'text-blue-700' : 'text-gray-400'
                            }`}
                          >
                            {row.new_value.toFixed(1)}
                            {changed && (
                              <span className="ml-1 text-xs text-blue-500">
                                (cambia)
                              </span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              <p className="mt-4 text-sm text-gray-500">
                Al pulsar "Actualizar", los tres campos de handicap de cada jugador
                se igualarán al valor de <strong>playing_handicap</strong>.
              </p>
            </>
          )}
        </div>

        {!loading && !error && hasChanges && (
          <div className="flex gap-3 p-6 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              disabled={updating}
              className="flex-1 bg-gray-200 hover:bg-gray-300 disabled:opacity-50 text-gray-800 font-semibold py-3 rounded-lg transition-colors"
            >
              Cancelar
            </button>
            <button
              type="button"
              onClick={handleUpdate}
              disabled={updating || !hasChanges}
              className={`flex-1 font-semibold py-3 rounded-lg transition-colors flex items-center justify-center gap-2 ${
                updating || !hasChanges
                  ? 'bg-gray-400 text-gray-200 cursor-not-allowed'
                  : 'bg-blue-600 hover:bg-blue-700 text-white'
              }`}
            >
              {updating ? 'Actualizando...' : 'Actualizar'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
